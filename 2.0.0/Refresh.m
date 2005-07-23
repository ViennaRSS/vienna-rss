//
//  Refresh.m
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

#import "Refresh.h"
#import "FeedCredentials.h"
#import "ActivityLog.h"
#import "FoldersTree.h"
#import "RichXMLParser.h"
#import "StringExtensions.h"
#import "Growl/GrowlDefines.h"

// Non-class function used for sorting
static int messageDateSortHandler(Message * item1, Message * item2, void * context);

// Static constant strings that are typically never tweaked
static NSString * GROWL_NOTIFICATION_DEFAULT = @"NotificationDefault";

@implementation AppController (Refresh)

/* refreshAllSubscriptions
 * Get new articles from all subscriptions.
 */
-(IBAction)refreshAllSubscriptions:(id)sender
{
	if (totalConnections == 0)
		[self refreshSubscriptions:[db arrayOfRSSFolders]];
}

/* refreshSelectedSubscriptions
 * Refresh one or more subscriptions selected from the folders list. The selection we obtain
 * may include non-RSS folders so these have to be trimmed out first.
 */
-(IBAction)refreshSelectedSubscriptions:(id)sender
{
	NSMutableArray * selectedFolders = [NSMutableArray arrayWithArray:[foldersTree selectedFolders]];
	int count = [selectedFolders count];
	int index;
	
	// For group folders, add all sub-groups to the array. The array we get back
	// from selectedFolders may include groups but will not include the folders within
	// those groups if they weren't selected. So we need to grab those folders here.
	for (index = 0; index < count; ++index)
	{
		Folder * folder = [selectedFolders objectAtIndex:index];
		if (IsGroupFolder(folder))
			[selectedFolders addObjectsFromArray:[db arrayOfFolders:[folder itemId]]];
	}
	
	// Trim the array to remove non-RSS folders that can't be refreshed.
	for (index = count - 1; index >= 0; --index)
	{
		Folder * folder = [selectedFolders objectAtIndex:index];
		if (!IsRSSFolder(folder))
			[selectedFolders removeObjectAtIndex:index];
	}
	
	// Hopefully what is left is refreshable.
	if ([selectedFolders count] > 0)
		[self refreshSubscriptions:selectedFolders];
}

/* refreshSubscriptions
 * Add the folders specified in the foldersArray to the refreshArray, removing any
 * duplicates.
 */
-(void)refreshSubscriptions:(NSArray *)foldersArray
{
	int count = [foldersArray count];
	int index;
	
	unreadAtBeginning = [db countOfUnread];
	for (index = 0; index < count; ++index)
	{
		Folder * folder = [foldersArray objectAtIndex:index];
		if (![refreshArray containsObject:folder])
			[refreshArray addObject:folder];
	}
	[self beginRefreshTimer];
}

/* getCredentialsForFolder
 * Initiate the UI to request the credentials for the specified folder.
 */
-(void)getCredentialsForFolder
{
	if (credentialsController == nil)
		credentialsController = [[FeedCredentials alloc] initWithDatabase:db];
	
	// Pull next folder out of the queue. The UI will post a
	// notification when it is done and we can move on to the
	// next one.
	if ([authQueue count] > 0 && ![[credentialsController window] isVisible])
	{
		Folder * folder = [authQueue objectAtIndex:0];
		[credentialsController credentialsForFolder:mainWindow folder:folder];
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
	{
		[pumpTimer invalidate];
		pumpTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshPumper:) userInfo:nil repeats:YES] retain];
	}
}

/* refreshPumper
 * This is the heart of the refresh code. We manage the refreshArray by creating a
 * connection for each item in the array up to a maximum number of simultaneous
 * connections as defined in the maximumConnections variable.
 */
-(void)refreshPumper:(NSTimer *)aTimer
{
	while (totalConnections < maximumConnections)
	{
		// Pump a refresh of subscription articles
		if ([refreshArray count] > 0)
			[self pumpSubscriptionRefresh];
		
		// Pump a refresh of folder icons
		else if ([folderIconRefreshArray count] > 0)
			[self pumpFolderIconRefresh];
		
		// Otherwise done
		else break;
	}
}

/* pumpSubscriptionRefresh
 * Pick the folder at the head of the refresh array and spawn a connection to
 * refresh that folder.
 */
-(void)pumpSubscriptionRefresh
{
	Folder * folder = [refreshArray objectAtIndex:0];
	
	// If this folder needs credentials, add the folder to the list requiring authentication
	// and since we can't progress without it, skip this folder on the connection
	if ([folder flags] & MA_FFlag_NeedCredentials)
	{
		[authQueue addObject:folder];
		[refreshArray removeObjectAtIndex:0];
		[self getCredentialsForFolder];
		return;
	}
	
	// If this folder also requires an image refresh, add that
	if ([folder flags] & MA_FFlag_CheckForImage)
		[folderIconRefreshArray addObject:folder];
	
	// The activity log name we use depends on whether or not this folder has a real name.
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
	NSDictionary * headers = [NSDictionary dictionaryWithObjectsAndKeys:
								[folder lastUpdateString], @"If-Modified-Since",
								@"gzip", @"Accepts-Encoding",
								nil, nil];
	[conn setHttpHeaders:headers];

	if ([conn beginLoadDataFromURL:url
					  username:[folder username]
					  password:[folder password]
					  delegate:self
				   contextData:folder
						   log:aItem
				didEndSelector:@selector(folderRefreshCompleted:)])
		[self addConnection:conn];

	[refreshArray removeObjectAtIndex:0];
}

/* pumpFolderIconRefresh
 * Initiate a connect to refresh the icon for a folder.
 */
-(void)pumpFolderIconRefresh
{
	Folder * folder = [folderIconRefreshArray objectAtIndex:0];
	
	if (([folder flags] & MA_FFlag_CheckForImage) && [folder homePage] != nil)
	{
		ActivityItem * aItem = [[ActivityLog defaultLog] itemByName:[folder name]];
		[aItem setStatus:NSLocalizedString(@"Retrieving folder image", nil)];
		
		AsyncConnection * conn = [[AsyncConnection alloc] init];
		NSString * favIconPath = [NSString stringWithFormat:@"http://%@/favicon.ico", [[folder homePage] baseURL]];
		
		[conn beginLoadDataFromURL:[NSURL URLWithString:favIconPath]
						  username:nil
						  password:nil
						  delegate:self
					   contextData:folder
							   log:aItem
					didEndSelector:@selector(folderIconRefreshCompleted:)];
		[self addConnection:conn];
	}
	
	[folderIconRefreshArray removeObjectAtIndex:0];
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
		
		// Get the feed's last update from the header if it is present. This will mark the
		// date of the most recent message in the feed if the individual messages are
		// missing a date tag.
		//
		// Note: some feeds appear to have a lastModified in the header that is out of
		//   date compared to the items in the feed. So do a sanity check to ensure that
		//   the date on the items take precedence.
		//
		NSDate * lastUpdate = [folder lastUpdate];
		NSDate * newLastUpdate = nil;
		
		if ([[newFeed lastModified] isGreaterThan:lastUpdate])
			newLastUpdate = [[newFeed lastModified] retain];
		if (newLastUpdate == nil)
			newLastUpdate = [lastUpdate retain];
		
		// We'll be collecting messages into this array
		NSMutableArray * messageArray = [NSMutableArray array];
		int newMessagesFromFeed = 0;	
		
		// Parse off items.
		NSEnumerator * itemEnumerator = [[newFeed items] objectEnumerator];
		FeedItem * newsItem;
		
		while ((newsItem = [itemEnumerator nextObject]) != nil)
		{
			NSDate * messageDate = [newsItem date];
			int msgFlag = MA_MsgID_New;
			
			// If no dates anywhere then use MA_MsgID_RSSNew as the message number to
			// force the database to locate a previous copy of this message if there
			// is one. Then use the current date/time as the message date.
			if (messageDate == nil)
			{
				messageDate = [NSCalendarDate date];
				msgFlag = MA_MsgID_RSSNew;
			}
			
			// Now insert the message into the database if it is newer than the
			// last update for this feed.
			if ([messageDate isGreaterThan:lastUpdate])
			{
				NSString * messageBody = [newsItem description];
				NSString * messageTitle = [newsItem title];
				NSString * messageLink = [newsItem link];
				NSString * userName = [newsItem author];
				
				// Create the message
				Message * message = [[Message alloc] initWithInfo:msgFlag];
				[message setFolderId:[folder itemId]];
				[message setAuthor:userName];
				[message setText:messageBody];
				[message setTitle:messageTitle];
				[message setLink:messageLink];
				[message setDate:messageDate];
				[messageArray addObject:message];
				[message release];
				
				// Track most current update
				if ([messageDate isGreaterThan:newLastUpdate])
				{
					[messageDate retain];
					[newLastUpdate release];
					newLastUpdate = messageDate;
				}
			}
		}
		
		// Now sort the message array before we insert into the
		// database so we're always inserting oldest first. The RSS feed is
		// likely to give us newest first.
		NSArray * sortedArrayOfMessages = [messageArray sortedArrayUsingFunction:messageDateSortHandler context:self];
		NSEnumerator * messageEnumerator = [sortedArrayOfMessages objectEnumerator];
		Message * message;
		
		// Here's where we add the messages to the database
		while ((message = [messageEnumerator nextObject]) != nil)
		{
			[db addMessage:[message folderId] message:message];
			if ([message status] == MA_MsgStatus_New)
				++newMessagesFromFeed;
		}
		
		// A notify is only needed if we added any new messages.
		BOOL needNotify = (newMessagesFromFeed > 0);
		
		// Set the last update date for this folder to be the date of the most
		// recent article we retrieved.
		int folderId = [folder itemId];
		if ([[folder name] isEqualToString:[db untitledFeedFolderName]])
		{
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
		[db setFolderLastUpdate:folderId lastUpdate:newLastUpdate];
		[db flushFolder:folderId];
		
		// Let interested callers know that the folder has changed.
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		if (needNotify)
			[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
		
		// Send status to the activity log
		if (newMessagesFromFeed == 0)
			[[connector aItem] setStatus:NSLocalizedString(@"No new articles available", nil)];
		else
		{
			NSString * logText = [NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newMessagesFromFeed];
			[[connector aItem] setStatus:logText];
		}
		
		// Done with this connection
		[newFeed release];
	}
	[self removeConnection:connector];
}

/* messageDateSortHandler
 * Compares two Messages and returns their chronological order
 */
static int messageDateSortHandler(Message * item1, Message * item2, void * context)
{
	return [[item1 date] compare:[item2 date]];
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

/* addConnection
 * Add the specified connection to the array of connections
 * that we manage.
 */
-(void)addConnection:(AsyncConnection *)conn
{
	if (![connectionsArray containsObject:conn])
		[connectionsArray addObject:conn];
	
	if (totalConnections++ == 0)
	{
		[self startProgressIndicator];
		[self setStatusMessage:NSLocalizedString(@"Refreshing subscriptions...", nil) persist:YES];
	}
}

/* removeConnection
 * Removes the specified connection from the array of connections
 * that we manage.
 */
-(void)removeConnection:(AsyncConnection *)conn
{
	if ([connectionsArray containsObject:conn])
		[connectionsArray removeObject:conn];
	
	[conn release];
	
	if (--totalConnections == 0)
		[self handleEndOfRefresh];
}

/* cancelAllRefreshes
 * Used to kill all active refresh connections and empty the queue of folders due to
 * be refreshed.
 */
-(IBAction)cancelAllRefreshes:(id)sender
{
	[refreshArray removeAllObjects];
	[folderIconRefreshArray removeAllObjects];
	while (totalConnections > 0)
	{
		AsyncConnection * theConnection = [connectionsArray objectAtIndex:0];
		[theConnection cancel];
		[theConnection release];
		[connectionsArray removeObjectAtIndex:0];
		--totalConnections;
	}
	[self handleEndOfRefresh];
}

/* handleEndOfRefresh
 * Do the things that come at the end of a refresh, whether or not the refresh
 * was successful.
 */
-(void)handleEndOfRefresh
{	
	[self setStatusMessage:NSLocalizedString(@"Refresh completed", nil) persist:YES];
	[self stopProgressIndicator];
	[self showUnreadCountOnApplicationIcon];
	int newUnread = [db countOfUnread] - unreadAtBeginning;
	if (growlAvailable && newUnread > 0)
	{
		NSNumber * defaultValue = [NSNumber numberWithBool:YES];
		NSNumber * stickyValue = [NSNumber numberWithBool:NO];
		NSString * msgText = [NSString stringWithFormat:NSLocalizedString(@"Growl description", nil), newUnread];
		
		NSDictionary *aNuDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Growl notification name", nil), GROWL_NOTIFICATION_NAME,
			NSLocalizedString(@"Growl notification title", nil), GROWL_NOTIFICATION_TITLE,
			msgText, GROWL_NOTIFICATION_DESCRIPTION,
			appName, GROWL_APP_NAME,
			defaultValue, GROWL_NOTIFICATION_DEFAULT,
			stickyValue, GROWL_NOTIFICATION_STICKY,
			nil];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION 
																	   object:nil 
																	 userInfo:aNuDict
														   deliverImmediately:YES];
	}
}
@end
