//
//  RefreshManager.m
//  Vienna
//
//  Created by Steve on 7/19/05.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "RefreshManager.h"
#import "FeedCredentials.h"
#import "ActivityLog.h"
#import "FoldersTree.h"
#import "RichXMLParser.h"
#import "StringExtensions.h"
#import "Constants.h"
#import "ViennaApp.h"

// Singleton
static RefreshManager * _refreshManager = nil;

// Refresh types
typedef enum {
	MA_Refresh_NilType = -1,
	MA_Refresh_Feed,
	MA_Refresh_FavIcon,
	MA_Refresh_BloglinesList
} RefreshTypes;

// Private functions
@interface RefreshManager (Private)
	-(BOOL)isRefreshingFolder:(Folder *)folder ofType:(RefreshTypes)type;
	-(void)refreshFavIcon:(Folder *)folder;
	-(void)getCredentialsForFolder;
	-(void)pumpSubscriptionRefresh:(Folder *)folder;
	-(void)pumpFolderIconRefresh:(Folder *)folder;
	-(void)pumpBloglinesListRefresh;
	-(void)beginRefreshTimer;
	-(void)refreshPumper:(NSTimer *)aTimer;
	-(void)addConnection:(AsyncConnection *)conn;
	-(void)removeConnection:(AsyncConnection *)conn;
	-(void)folderIconRefreshCompleted:(AsyncConnection *)connector;
	-(void)bloglinesListRefreshCompleted:(AsyncConnection *)connector;
@end

// Single refresh item type
@interface RefreshItem : NSObject {
	Folder * folder;
	RefreshTypes type;
}

// Accessor functions
-(void)setFolder:(Folder *)newFolder;
-(void)setType:(RefreshTypes)newType;
-(Folder *)folder;
-(RefreshTypes)type;
@end

@implementation RefreshItem

/* init
 * Initialises an empty RefreshItem with default values.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		[self setFolder:nil];
		[self setType:MA_Refresh_NilType];
	}
	return self;
}

/* setFolder
 */
-(void)setFolder:(Folder *)newFolder
{
	[newFolder retain];
	[folder release];
	folder = newFolder;
}

/* folder
 */
-(Folder *)folder
{
	return folder;
}

/* setType
 */
-(void)setType:(RefreshTypes)newType
{
	type = newType;
}

/* type
 */
-(RefreshTypes)type
{
	return type;
}

/* dealloc
 * Clean up behind ourselves.
 */
-(void)dealloc
{
	[folder release];
	[super dealloc];
}
@end

@implementation RefreshManager

/* init
 * Initialise the class.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		maximumConnections = [[[NSUserDefaults standardUserDefaults] valueForKey:MAPref_RefreshThreads] intValue];
		totalConnections = 0;
		countOfNewArticles = 0;
		refreshArray = [[NSMutableArray alloc] initWithCapacity:10];
		connectionsArray = [[NSMutableArray alloc] initWithCapacity:maximumConnections];
		authQueue = [[NSMutableArray alloc] init];
		hasStarted = YES;

		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleGotAuthenticationForFolder:) name:@"MA_Notify_GotAuthenticationForFolder" object:nil];
		[nc addObserver:self selector:@selector(handleCancelAuthenticationForFolder:) name:@"MA_Notify_CancelAuthenticationForFolder" object:nil];
		[nc addObserver:self selector:@selector(handleWillDeleteFolder:) name:@"MA_Notify_WillDeleteFolder" object:nil];
	}
	return self;
}

/* sharedManager
 * Returns the single instance of the refresh manager.
 */
+(RefreshManager *)sharedManager
{
	if (!_refreshManager)
		_refreshManager = [[RefreshManager alloc] init];
	return _refreshManager;
}

/* handleWillDeleteFolder
 * Trap the notification that is broadcast just before a folder is being deleted.
 * We use this to remove that folder from the refresh queue, if it is present, and
 * interrupt a connection on that folder. Otherwise our retain on the folder will
 * prevent it from being fully released until the end of the refresh by which time
 * the folder list pane will probably have completed its post delete update.
 */
-(void)handleWillDeleteFolder:(NSNotification *)nc
{
	Folder * folder = [[Database sharedDatabase] folderFromID:[[nc object] intValue]];
	if (folder != nil)
	{
		int index = [refreshArray count];
		while (--index >= 0)
		{
			RefreshItem * item = [refreshArray objectAtIndex:index];
			if ([item folder] == folder)
				[refreshArray removeObjectAtIndex:index];
		}

		index = [connectionsArray count];
		while (--index >= 0)
		{
			AsyncConnection * conn = [connectionsArray objectAtIndex:index];
			if ([conn contextData] == folder)
			{
				[conn cancel];
				[self removeConnection:conn];
				break;
			}
		}
	}
}

/* refreshSubscriptions
 * Add the folders specified in the foldersArray to the refreshArray.
 */
-(void)refreshSubscriptions:(NSArray *)foldersArray
{
	int count = [foldersArray count];
	int index;
	
	for (index = 0; index < count; ++index)
	{
		Folder * folder = [foldersArray objectAtIndex:index];
		if (IsGroupFolder(folder))
			[self refreshSubscriptions:[[Database sharedDatabase] arrayOfFolders:[folder itemId]]];
		else if (IsRSSFolder(folder))
		{
			if (![self isRefreshingFolder:folder ofType:MA_Refresh_Feed])
			{
				RefreshItem * newItem = [[RefreshItem alloc] init];
				[newItem setFolder:folder];
				[newItem setType:MA_Refresh_Feed];
				[refreshArray addObject:newItem];
				[newItem release];
			}
		}
	}
	[self beginRefreshTimer];
}

/* refreshFavIcon
 * Adds the specified folder to the refreshArray.
 */
-(void)refreshFavIcon:(Folder *)folder
{
	if (![self isRefreshingFolder:folder ofType:MA_Refresh_FavIcon])
	{
		RefreshItem * newItem = [[RefreshItem alloc] init];
		[newItem setFolder:folder];
		[newItem setType:MA_Refresh_FavIcon];
		[refreshArray addObject:newItem];
		[newItem release];
		[self beginRefreshTimer];
	}
}

/* isRefreshingFolder
 * Returns whether refreshArray has an queue refresh for the specified folder
 * and refresh type.
 */
-(BOOL)isRefreshingFolder:(Folder *)folder ofType:(RefreshTypes)type
{
	NSEnumerator * enumerator = [refreshArray objectEnumerator];
	RefreshItem * item;
	
	while ((item = [enumerator nextObject]) != nil)
	{
		if ([item folder] == folder && [item type] == type)
			return YES;
	}
	return NO;
}

/* cancelAll
 * Cancel all active refreshes.
 */
-(void)cancelAll
{
	[refreshArray removeAllObjects];
	while (totalConnections > 0)
	{
		AsyncConnection * conn = [connectionsArray objectAtIndex:0];
		[conn cancel];
		[self removeConnection:conn];
	}
}

/* totalConnections
 * Returns the current number of concurrent active connections.
 */
-(int)totalConnections
{
	return totalConnections;
}

/* countOfNewArticles
 */
-(int)countOfNewArticles
{
	return countOfNewArticles;
}

/* getCredentialsForFolder
 * Initiate the UI to request the credentials for the specified folder.
 */
-(void)getCredentialsForFolder
{
	if (credentialsController == nil)
		credentialsController = [[FeedCredentials alloc] init];
	
	// Pull next folder out of the queue. The UI will post a
	// notification when it is done and we can move on to the
	// next one.
	if ([authQueue count] > 0 && ![[credentialsController window] isVisible])
	{
		Folder * folder = [authQueue objectAtIndex:0];
		[credentialsController credentialsForFolder:[NSApp mainWindow] folder:folder];
	}
}

/* handleRequireAuthenticationForFolder [delegate]
 * Called when somewhere requires us to provide authentication for the specified
 * folder.
 */
-(void)handleRequireAuthenticationForFolder:(NSNotification *)nc
{
	Folder * folder = (Folder *)[nc object];
	if (![authQueue containsObject:folder])
		[authQueue addObject:folder];
	[self getCredentialsForFolder];
}

/* handleCancelAuthenticationForFolder
 * Called when somewhere cancelled our request to authenticate the specified
 * folder.
 */
-(void)handleCancelAuthenticationForFolder:(NSNotification *)nc
{
	Folder * folder = (Folder *)[nc object];
	[authQueue removeObject:folder];

	// Get the next one in the queue, if any
	[self getCredentialsForFolder];
}

/* handleGotAuthenticationForFolder [delegate]
 * Called when somewhere just provided us the needed authentication for the specified
 * folder. Note that we don't know if the authentication is valid yet - just that a
 * user name and password has been provided.
 */
-(void)handleGotAuthenticationForFolder:(NSNotification *)nc
{
	Folder * folder = (Folder *)[nc object];
	[folder clearFlag:MA_FFlag_NeedCredentials];
	[authQueue removeObject:folder];
	[self refreshSubscriptions:[NSArray arrayWithObject:folder]];
	
	// Get the next one in the queue, if any
	[self getCredentialsForFolder];
}

/* beginRefreshTimer
 * Start the connection refresh timer running.
 */
-(void)beginRefreshTimer
{
	if (pumpTimer == nil)
		pumpTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshPumper:) userInfo:nil repeats:YES] retain];
}

/* refreshPumper
 * This is the heart of the refresh code. We manage the refreshArray by creating a
 * connection for each item in the array up to a maximum number of simultaneous
 * connections as defined in the maximumConnections variable.
 */
-(void)refreshPumper:(NSTimer *)aTimer
{
	while ((totalConnections < maximumConnections) && ([refreshArray count] > 0))
	{
		RefreshItem * item = [refreshArray objectAtIndex:0];
		switch ([item type])
		{
		case MA_Refresh_NilType:
			NSAssert(false, @"Uninitialised RefreshItem in refreshArray");
			break;

		case MA_Refresh_BloglinesList:
			[self pumpBloglinesListRefresh];
			break;

		case MA_Refresh_Feed:
			[self pumpSubscriptionRefresh:[item folder]];
			break;
			
		case MA_Refresh_FavIcon:
			[self pumpFolderIconRefresh:[item folder]];
			break;
		}
		[refreshArray removeObjectAtIndex:0];
	}
}

/* pumpSubscriptionRefresh
 * Pick the folder at the head of the refresh array and spawn a connection to
 * refresh that folder.
 */
-(void)pumpSubscriptionRefresh:(Folder *)folder
{
	// If this folder needs credentials, add the folder to the list requiring authentication
	// and since we can't progress without it, skip this folder on the connection
	if ([folder flags] & MA_FFlag_NeedCredentials)
	{
		[authQueue addObject:folder];
		[self getCredentialsForFolder];
		return;
	}

	// If this folder also requires an image refresh, add that
	if ([folder flags] & MA_FFlag_CheckForImage)
		[self refreshFavIcon:folder];

	// The activity log name we use depends on whether or not this folder has a real name.
	Database * db = [Database sharedDatabase];
	NSString * name = [[folder name] isEqualToString:[db untitledFeedFolderName]] ? [folder feedURL] : [folder name];
	ActivityItem * aItem = [[ActivityLog defaultLog] itemByName:name];
	
	// Compute the URL for this connection
	NSString * urlString = IsBloglinesFolder(folder) ? [NSString stringWithFormat:@"http://rpc.bloglines.com/getitems?s=%d&n=1", [folder bloglinesId]] : [folder feedURL];
	NSURL * url = [NSURL URLWithString:urlString];
	
	// Seed the activity log for this feed.
	[aItem clearDetails];
	[aItem setStatus:NSLocalizedString(@"Retrieving articles", nil)];
	
	// Additional detail for the log
	[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Connecting to %@", nil), urlString]];

	// Kick off the connection
	AsyncConnection * conn = [[AsyncConnection alloc] init];
	NSMutableDictionary * headers = [NSMutableDictionary dictionary];
	
	[headers setValue:@"gzip" forKey:@"Accept-Encoding"];
	[headers setValue:[folder lastUpdateString] forKey:@"If-Modified-Since"];

	[conn setHttpHeaders:headers];

	if ([conn beginLoadDataFromURL:url
					  username:[folder username]
					  password:[folder password]
					  delegate:self
				   contextData:folder
						   log:aItem
				didEndSelector:@selector(folderRefreshCompleted:)])
		[self addConnection:conn];
}

/* pumpFolderIconRefresh
 * Initiate a connect to refresh the icon for a folder.
 */
-(void)pumpFolderIconRefresh:(Folder *)folder
{
	if (([folder flags] & MA_FFlag_CheckForImage) && [folder homePage] != nil && ![[folder homePage] isBlank])
	{
		// The activity log name we use depends on whether or not this folder has a real name.
		Database * db = [Database sharedDatabase];
		NSString * name = [[folder name] isEqualToString:[db untitledFeedFolderName]] ? [folder feedURL] : [folder name];
		ActivityItem * aItem = [[ActivityLog defaultLog] itemByName:name];
		
		[aItem appendDetail:NSLocalizedString(@"Retrieving folder image", nil)];

		AsyncConnection * conn = [[AsyncConnection alloc] init];
		NSString * favIconPath = [NSString stringWithFormat:@"http://%@/favicon.ico", [[[folder homePage] trim] baseURL]];
		
		if ([conn beginLoadDataFromURL:[NSURL URLWithString:favIconPath]
						  username:nil
						  password:nil
						  delegate:self
					   contextData:folder
							   log:aItem
					didEndSelector:@selector(folderIconRefreshCompleted:)])
			[self addConnection:conn];
	}
}

/* pumpBloglinesListRefresh
 * Initiate a connection to refresh our folders list with a list of subscriptions
 * in the user's bloglines account.
 *
 * TODO stevepa: Implement this.
 */
-(void)pumpBloglinesListRefresh
{
	AsyncConnection * conn = [[AsyncConnection alloc] init];
	if ([conn beginLoadDataFromURL:[NSURL URLWithString:@"http://rpc.bloglines.com/listsubs"]
							 username:nil
							 password:nil
							 delegate:self
						  contextData:nil
								  log:nil
					   didEndSelector:@selector(bloglinesListRefreshCompleted:)])
		[self addConnection:conn];
}

/* folderRefreshCompleted
 * Called when a folder refresh completed.
 */
-(void)folderRefreshCompleted:(AsyncConnection *)connector
{
	if ([connector status] == MA_Connect_NeedCredentials)
	{
		Folder * folder = (Folder *)[connector contextData];
		if (![authQueue containsObject:folder])
			[authQueue addObject:folder];
		[self getCredentialsForFolder];
	}
	else if ([connector status] == MA_Connect_Succeeded)
	{
		Folder * folder = (Folder *)[connector contextData];
		Database * db = [Database sharedDatabase];
		NSData * receivedData = [connector receivedData];
		
		// Remember the last modified date
		NSString * lastModifiedString = [[connector responseHeaders] valueForKey:@"Last-Modified"];
		if (lastModifiedString != nil)
			[folder setLastUpdateString:lastModifiedString];
		
		// Create a new rich XML parser instance that will take care of
		// parsing the XML data we just got.
		RichXMLParser * newFeed = [[RichXMLParser alloc] init];
		if (newFeed == nil || [receivedData length] == 0 || ![newFeed parseRichXML:receivedData])
		{
			[[connector aItem] setStatus:NSLocalizedString(@"Error parsing XML data in feed", nil)];
			[newFeed release];
			[self removeConnection:connector];
			return;
		}
		
		// Log number of bytes we received
		[[connector aItem] appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%ld bytes received", nil), [receivedData length]]];
		
		// Extract the latest title and description
		NSString * feedTitle = [newFeed title];
		NSString * feedDescription = [newFeed description];
		NSString * feedLink = [newFeed link];
		
		// Synthesize feed link if it is missing
		if ([feedLink isBlank])
			feedLink = [[folder feedURL] baseURL];

		// Get the feed's last update from the header if it is present. This will mark the
		// date of the most recent article in the feed if the individual articles are
		// missing a date tag.
		NSDate * lastUpdate = [folder lastUpdate];
		NSDate * newLastUpdate = [lastUpdate retain];
		
		// We'll be collecting articles into this array
		NSMutableArray * articleArray = [NSMutableArray array];
		int newArticlesFromFeed = 0;	
		
		// Parse off items.
		NSEnumerator * itemEnumerator = [[newFeed items] objectEnumerator];
		FeedItem * newsItem;
		
		while ((newsItem = [itemEnumerator nextObject]) != nil)
		{
			NSDate * articleDate = [newsItem date];
			NSAssert(articleDate != nil, @"FeedItem should not have a nil date");
			
			if ([articleDate compare:lastUpdate] == NSOrderedDescending)
			{
				Article * article = [[Article alloc] initWithGuid:[newsItem guid]];
				[article setFolderId:[folder itemId]];
				[article setAuthor:[newsItem author]];
				[article setBody:[newsItem description]];
				[article setTitle:[newsItem title]];
				[article setLink:[newsItem link]];
				[article setDate:articleDate];
				[articleArray addObject:article];
				[article release];

				// Track most recent article
				if ([articleDate isGreaterThan:newLastUpdate])
				{
					[articleDate retain];
					[newLastUpdate release];
					newLastUpdate = articleDate;
				}
			}
		}

		// Here's where we add the articles to the database
		NSEnumerator * articleEnumerator = [articleArray objectEnumerator];
		Article * article;
		
		while ((article = [articleEnumerator nextObject]) != nil)
		{
			[db createArticle:[article folderId] article:article];
			if ([article status] == MA_MsgStatus_New)
				++newArticlesFromFeed;
		}
		
		// A notify is only needed if we added any new articles.
		BOOL needNotify = (newArticlesFromFeed > 0);
		
		int folderId = [folder itemId];
		if ([[folder name] isEqualToString:[db untitledFeedFolderName]])
		{
			// If there's an existing feed with this title, make ours unique
			// BUGBUG: This duplicates logic in database.m so consider moving it there.
			NSString * oldFeedTitle = feedTitle;
			unsigned int index = 1;

			while (([db folderFromName:feedTitle]) != nil)
				feedTitle = [NSString stringWithFormat:@"%@ (%i)", oldFeedTitle, index++];

			[[connector aItem] setName:feedTitle];
			if ([db setFolderName:folderId newName:feedTitle])
				needNotify = NO;
		}
		if (feedDescription != nil)
		{
			if ([db setFolderDescription:folderId newDescription:feedDescription])
				needNotify = NO;
		}
		if (feedLink!= nil)
		{
			if ([db setFolderHomePage:folderId newHomePage:feedLink])
				needNotify = NO;
		}

		// Set the last update date for this folder to be the date of the most
		// recent article we retrieved.
		if (newLastUpdate != nil)
			[db setFolderLastUpdate:folderId lastUpdate:newLastUpdate];
		[db flushFolder:folderId];
		
		// Let interested callers know that the folder has changed.
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		if (needNotify)
			[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
		
		// Send status to the activity log
		if (newArticlesFromFeed == 0)
			[[connector aItem] setStatus:NSLocalizedString(@"No new articles available", nil)];
		else
		{
			NSString * logText = [NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newArticlesFromFeed];
			[[connector aItem] setStatus:logText];
		}
		
		// Done with this connection
		[newFeed release];

		// If this folder also requires an image refresh, add that
		if ([folder flags] & MA_FFlag_CheckForImage)
			[self refreshFavIcon:folder];

		// Add to count of new articles so far
		countOfNewArticles += newArticlesFromFeed;
	}
	[self removeConnection:connector];
}

/* folderIconRefreshCompleted
 * Called when a folder icon refresh completed.
 */
-(void)folderIconRefreshCompleted:(AsyncConnection *)connector
{
	if ([connector status] == MA_Connect_Succeeded)
	{
		Folder * folder = [connector contextData];
		NSImage * iconImage = [[NSImage alloc] initWithData:[connector receivedData]];
		if (iconImage != nil && [iconImage isValid])
		{
			[iconImage setScalesWhenResized:YES];
			[iconImage setSize:NSMakeSize(16, 16)];
			[folder setImage:iconImage];

			// Broadcast a notification since the folder image has now changed
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[folder itemId]]];

			// Log additional details about this.
			ActivityItem * aItem = [[ActivityLog defaultLog] itemByName:[folder name]];
			NSString * favIconPath = [NSString stringWithFormat:@"http://%@/favicon.ico", [[folder homePage] baseURL]];
			NSString * logText = [NSString stringWithFormat:NSLocalizedString(@"Folder image retrieved from %@", nil), favIconPath];
			[aItem appendDetail:logText];
		}
		[folder clearFlag:MA_FFlag_CheckForImage];
		[iconImage release];
	}
	[self removeConnection:connector];
}

/* bloglinesListRefreshCompleted
 * Called when the Bloglines subscription data has been retrieved.
 */
-(void)bloglinesListRefreshCompleted:(AsyncConnection *)connector
{
	if ([connector status] == MA_Connect_Succeeded)
	{
		NSData * xmlData = [connector receivedData];
		if (xmlData != nil)
		{
			XMLParser * tree = [[XMLParser alloc] init];
			if ([tree setData:xmlData])
			{
				// TODO: stevepa. Implement this.
				//XMLParser * bodyTree = [tree treeByPath:@"opml/body"];
				//[self importSubscriptionGroup:bodyTree underParent:MA_Root_Folder];
			}
			[tree release];
		}
	}
	[self removeConnection:connector];
}

/* addConnection
 * Add the specified connection to the array of connections
 * that we manage.
 */
-(void)addConnection:(AsyncConnection *)conn
{
	if (![connectionsArray containsObject:conn])
		[connectionsArray addObject:conn];

	if (totalConnections++ == 0 && hasStarted)
	{
		countOfNewArticles = 0;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_RefreshStatus" object:nil];
		hasStarted = NO;
	}
}

/* removeConnection
 * Removes the specified connection from the array of connections
 * that we manage.
 */
-(void)removeConnection:(AsyncConnection *)conn
{
	NSAssert(totalConnections > 0, @"Calling removeConnection with zero active connection count");
	if (totalConnections > 0)
	{
		if ([connectionsArray containsObject:conn])
			[connectionsArray removeObject:conn];

		// Close the connection before we release as otherwise
		// we'll leak.
		[conn close];
		[conn release];

		if (--totalConnections == 0 && [refreshArray count] == 0)
		{
			[pumpTimer invalidate];
			[pumpTimer release];
			pumpTimer = nil;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_RefreshStatus" object:nil];
			
			hasStarted = YES;
		}
	}
}

/* dealloc
 * Clean up after ourselves.
 */
-(void)dealloc
{
	[pumpTimer release];
	[authQueue release];
	[connectionsArray release];
	[refreshArray release];
	[super dealloc];
}
@end
