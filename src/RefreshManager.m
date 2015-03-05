//
//  RefreshManager.m
//  Vienna
//
//  Created by Steve on 7/19/05.
//  Copyright (c) 2004-2014 Steve Palmer and Vienna contributors (see Help/Acknowledgements for list of contributors). All rights reserved.
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
#import "Preferences.h"
#import "Constants.h"
#import "ViennaApp.h"
#import "GoogleReader.h"
#import "Constants.h"
#import "AppController.h"
#import "ASIHTTPRequest.h"
#import "NSNotificationAdditions.h"
#import "VTPG_Common.h"

// Singleton
static RefreshManager * _refreshManager = nil;

// Private functions
@interface RefreshManager (Private)
-(BOOL)isRefreshingFolder:(Folder *)folder ofType:(RefreshTypes)type;
-(void)getCredentialsForFolder;
-(void)setFolderErrorFlag:(Folder *)folder flag:(BOOL)theFlag;
-(void)setFolderUpdatingFlag:(Folder *)folder flag:(BOOL)theFlag;
-(void)pumpSubscriptionRefresh:(Folder *)folder shouldForceRefresh:(BOOL)force;
-(void)pumpFolderIconRefresh:(Folder *)folder;
-(void)refreshFeed:(Folder *)folder fromURL:(NSURL *)url withLog:(ActivityItem *)aItem shouldForceRefresh:(BOOL)force;
-(void)beginRefreshTimer;
-(void)refreshPumper:(NSTimer *)aTimer;
-(void)removeConnection:(ASIHTTPRequest *)conn;
-(void)folderIconRefreshCompleted:(ASIHTTPRequest *)connector;
-(NSString *)getRedirectURL:(NSData *)data;
- (void)syncFinishedForFolder:(Folder *)folder; 
@end

@implementation RefreshManager

+ (void)initialize
{
}


/* init
 * Initialise the class.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		maximumConnections = [[Preferences standardPreferences] integerForKey:MAPref_RefreshThreads];
		countOfNewArticles = 0;
		authQueue = [[NSMutableArray alloc] init];
		statusMessageDuringRefresh = nil;
		networkQueue = [[ASINetworkQueue alloc] init];
		[networkQueue setShouldCancelAllRequestsOnFailure:NO];
		networkQueue.delegate = self;
		[networkQueue setRequestDidFinishSelector:@selector(nqRequestFinished:)];
		[networkQueue setRequestDidStartSelector:@selector(nqRequestStarted:)];
		[networkQueue setQueueDidFinishSelector:@selector(nqQueueDidFinishSelector:)];
		[networkQueue setMaxConcurrentOperationCount:[[Preferences standardPreferences] integerForKey:MAPref_ConcurrentDownloads]];

		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleGotAuthenticationForFolder:) name:@"MA_Notify_GotAuthenticationForFolder" object:nil];
		[nc addObserver:self selector:@selector(handleCancelAuthenticationForFolder:) name:@"MA_Notify_CancelAuthenticationForFolder" object:nil];
		[nc addObserver:self selector:@selector(handleWillDeleteFolder:) name:@"MA_Notify_WillDeleteFolder" object:nil];
		[nc addObserver:self selector:@selector(handleChangeConcurrentDownloads:) name:@"MA_Notify_CowncurrentDownloadsChange" object:nil];
		_queue = dispatch_queue_create("uk.co.opencommunity.vienna2.refresh", NULL);
		hasStarted = NO;
	}
	return self;
}

-(dispatch_queue_t)asyncQueue {
	return _queue;
}

- (void)nqQueueDidFinishSelector:(ASIHTTPRequest *)request {
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_ArticleListStateChange" object:nil];
	if (hasStarted)
	{
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_RefreshStatus" object:nil];
		hasStarted = NO;
	}
	LLog(@"Queue empty!!!");
}

- (void)nqRequestFinished:(ASIHTTPRequest *)request {
	statusMessageDuringRefresh = [NSString stringWithFormat:@"%@: (%i) - %@",NSLocalizedString(@"Queue",nil),[networkQueue requestsCount],NSLocalizedString(@"Refreshing subscriptions...", nil)];
	[APPCONTROLLER setStatusMessage:[self statusMessageDuringRefresh] persist:YES];
	LLog(@"Removed queue: %d", [networkQueue requestsCount]);
}

- (void)nqRequestStarted:(ASIHTTPRequest *)request {
	statusMessageDuringRefresh = [NSString stringWithFormat:@"%@: (%i) - %@",NSLocalizedString(@"Queue",nil),[networkQueue requestsCount],NSLocalizedString(@"Refreshing subscriptions...", nil)];
	[APPCONTROLLER setStatusMessage:[self statusMessageDuringRefresh] persist:YES];
	LLog(@"Added queue: %d", [networkQueue requestsCount]);

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

-(void)handleChangeConcurrentDownloads:(NSNotification *)nc
{
	NSLog(@"Handling new downloads count");
	[networkQueue setMaxConcurrentOperationCount:[[Preferences standardPreferences] integerForKey:MAPref_ConcurrentDownloads]];
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
	Folder * folder = [[Database sharedManager] folderFromID:[[nc object] intValue]];
	if (folder != nil)
	{
        for (ASIHTTPRequest *theRequest in [networkQueue operations]) {
			if ([[theRequest userInfo] objectForKey:@"folder"] == folder) {
				[self removeConnection:theRequest];
				break;
			}
		}
	}
}


-(void)forceRefreshSubscriptionForFolders:(NSArray*)foldersArray
{
	statusMessageDuringRefresh = NSLocalizedString(@"Forcing Refresh subscriptions...", nil);
    
	for (Folder * folder in foldersArray)
	{
		if (IsGroupFolder(folder))
			[self forceRefreshSubscriptionForFolders:[[Database sharedManager] arrayOfFolders:[folder itemId]]];
		else if (IsGoogleReaderFolder(folder))
		{
			if (![self isRefreshingFolder:folder ofType:MA_Refresh_GoogleFeed] && ![self isRefreshingFolder:folder ofType:MA_ForceRefresh_Google_Feed])
				[self pumpSubscriptionRefresh:folder shouldForceRefresh:YES];
		} 
	}
}

/* refreshSubscriptions
 * Add the folders specified in the foldersArray to the refresh queue.
 */
-(void)refreshSubscriptions:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus
{        
	statusMessageDuringRefresh = NSLocalizedString(@"Refreshing subscriptions...", nil);
    
	for (Folder * folder in foldersArray)
	{
		if (IsGroupFolder(folder))
			[self refreshSubscriptions:[[Database sharedManager] arrayOfFolders:[folder itemId]] ignoringSubscriptionStatus:NO];
		else if (IsRSSFolder(folder) || IsGoogleReaderFolder(folder))
		{
			if (!IsUnsubscribed(folder) || ignoreSubStatus)
			{
				if (![self isRefreshingFolder:folder ofType:MA_Refresh_Feed] && ![self isRefreshingFolder:folder ofType:MA_Refresh_GoogleFeed])
				{
					[self pumpSubscriptionRefresh:folder shouldForceRefresh:NO];
				}
			}
		}	
	}
}

-(void)refreshSubscriptionsAfterDelete:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus {
    syncType = MA_Sync_Unsubscribe;
    [self refreshSubscriptions:foldersArray ignoringSubscriptionStatus:ignoreSubStatus];
}
    
-(void)refreshSubscriptionsAfterSubscribe:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus {
    syncType = MA_Sync_Subscribe;
	//   [GRSOperation setFetchFlag:YES];
    [self refreshSubscriptions:foldersArray ignoringSubscriptionStatus:ignoreSubStatus];
}

-(void)refreshSubscriptionsAfterUnsubscribe:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus {
    syncType = MA_Sync_Unsubscribe;
    [self refreshSubscriptions:foldersArray ignoringSubscriptionStatus:ignoreSubStatus];
}

-(void)refreshSubscriptionsAfterMerge:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus {
    syncType = MA_Sync_Merge;
    [self refreshSubscriptions:foldersArray ignoringSubscriptionStatus:ignoreSubStatus];
}

-(void)refreshSubscriptionsAfterRefresh:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus {
    syncType = MA_Sync_Refresh;
    [self refreshSubscriptions:foldersArray ignoringSubscriptionStatus:ignoreSubStatus];
}

- (void)addRSSFoldersIn:(Folder *)folder toArray:(NSMutableArray *)array 
{
    if (IsRSSFolder(folder) || IsGoogleReaderFolder(folder)) [array addObject:folder];
    else
    {
        Database * db = [Database sharedManager];
        for (Folder * f in [db arrayOfFolders:[folder itemId]])
            [self addRSSFoldersIn:f toArray:array];
    }
}

-(void)refreshSubscriptionsAfterRefreshAll:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus 
{   
    syncType = MA_Sync_Refresh_All;
	
	if ([[Preferences standardPreferences] syncGoogleReader]) [[GoogleReader sharedManager] loadSubscriptions:nil];
	
    [self refreshSubscriptions:foldersArray ignoringSubscriptionStatus:ignoreSubStatus];
}

/* refreshFolderIconCacheForSubscriptions
 * Add the folders specified in the foldersArray to the refresh queue.
 */
-(void)refreshFolderIconCacheForSubscriptions:(NSArray *)foldersArray
{
	statusMessageDuringRefresh = NSLocalizedString(@"Refreshing folder images...", nil);
	
	for (Folder * folder in foldersArray)
	{
		if (IsGroupFolder(folder))
			[self refreshFolderIconCacheForSubscriptions:[[Database sharedManager] arrayOfFolders:[folder itemId]]];
		else if (IsRSSFolder(folder) || IsGoogleReaderFolder(folder))
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self refreshFavIconForFolder:folder];
			});
		}
	}
}

/* refreshFavIconForFolder
 * Adds the specified folder to the refresh queue.
 */
/**
 *  Refreshes the favicon for the specified folder
 *
 *  @param folder The folder object to refresh the favicon for
 */
-(void)refreshFavIconForFolder:(Folder *)folder
{
	
	// Do nothing if there's no homepage associated with the feed
	// or if the feed already has a favicon.
	if ((IsRSSFolder(folder)||IsGoogleReaderFolder(folder)) &&
        ([folder homePage] == nil || [[folder homePage] isBlank] || [folder hasCachedImage]))
	{
        [[Database sharedManager] clearFlag:MA_FFlag_CheckForImage forFolder:folder.itemId];
		return;
	}
	
    if (![self isRefreshingFolder:folder ofType:MA_Refresh_FavIcon]) {
		[self pumpFolderIconRefresh:folder];
    }

}

/* isRefreshingFolder
 * Returns whether refresh queue has a queue item for the specified folder
 * and refresh type.
 */
-(BOOL)isRefreshingFolder:(Folder *)folder ofType:(RefreshTypes)type
{
    for (ASIHTTPRequest *theRequest in [networkQueue operations])
    {
		if (([[theRequest userInfo] objectForKey:@"folder"] == folder) && ([[[theRequest userInfo] valueForKey:@"type"] intValue] == [[NSNumber numberWithInt:type] intValue]))
            return YES;

	}
	return NO;
}

/* statusMessageDuringRefresh
 * Returns the string to be displayed during a refresh.
 */
-(NSString *)statusMessageDuringRefresh
{
	return statusMessageDuringRefresh;
}

/* cancelAll
 * Cancel all active refreshes.
 */
-(void)cancelAll
{
	[networkQueue cancelAllOperations];
}


/* countOfNewArticles
 */
-(NSUInteger)countOfNewArticles
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
    [[Database sharedManager] clearFlag:MA_FFlag_NeedCredentials forFolder:folder.itemId];
	[authQueue removeObject:folder];
	[self refreshSubscriptions:[NSArray arrayWithObject:folder] ignoringSubscriptionStatus:YES];
	
	// Get the next one in the queue, if any
	[self getCredentialsForFolder];
}

/* setFolderErrorFlag
 * Sets or clears the folder error flag then broadcasts an update indicating that the folder
 * has changed.
 */
-(void)setFolderErrorFlag:(Folder *)folder flag:(BOOL)theFlag
{
	if (theFlag)
		[folder setNonPersistedFlag:MA_FFlag_Error];
	else
		[folder clearNonPersistedFlag:MA_FFlag_Error];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[folder itemId]]];
}

/* setFolderUpdatingFlag
 * Sets or clears the folder updating flag then broadcasts an update indicating that the folder
 * has changed.
 */
-(void)setFolderUpdatingFlag:(Folder *)folder flag:(BOOL)theFlag
{
	if (theFlag)
		[folder setNonPersistedFlag:MA_FFlag_Updating];
	else
		[folder clearNonPersistedFlag:MA_FFlag_Updating];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[folder itemId]]];
}

/* pumpSubscriptionRefresh
 * Pick the folder at the head of the refresh queue and spawn a connection to
 * refresh that folder.
 */
-(void)pumpSubscriptionRefresh:(Folder *)folder shouldForceRefresh:(BOOL)force
{
	// If this folder needs credentials, add the folder to the list requiring authentication
	// and since we can't progress without it, skip this folder on the connection
	if ([folder flags] & MA_FFlag_NeedCredentials)
	{
		[authQueue addObject:folder];
		[self getCredentialsForFolder];
		return;
	}
    
	
	// The activity log name we use depends on whether or not this folder has a real name.
	NSString * name = [[folder name] isEqualToString:[Database untitledFeedFolderName]] ? [folder feedURL] : [folder name];
	ActivityItem * aItem = [[ActivityLog defaultLog] itemByName:name];
	
	// Compute the URL for this connection
	NSString * urlString = [folder feedURL];
	NSURL * url = nil;
	
	if ([urlString hasPrefix:@"file://"])
		url = [NSURL fileURLWithPath:[[urlString substringFromIndex:7] stringByExpandingTildeInPath]];
	else if ([urlString hasPrefix:@"feed://"])
		url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", [urlString substringFromIndex:7]]];
	else
		url = [NSURL URLWithString:urlString];
	
	// Seed the activity log for this feed.
	[aItem clearDetails];
	[aItem setStatus:NSLocalizedString(@"Retrieving articles", nil)];
    
	// Mark the folder as being refreshed. The updating status is not
	// persistent so we set this directly on the folder rather than
	// through the database.
	[self setFolderUpdatingFlag:folder flag:YES];
	
	// Additional detail for the log
	if (IsGoogleReaderFolder(folder)) {
		[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Connecting to Open Reader server to retrieve %@", nil), urlString]];
	} else {
		[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Connecting to %@", nil), urlString]];
	}
	
	// Kick off the connection
	[self refreshFeed:folder fromURL:url withLog:aItem shouldForceRefresh:force];
	
	
}

/* refreshFeed
 * Refresh a folder's newsfeed using the specified URL.
 */
-(void)refreshFeed:(Folder *)folder fromURL:(NSURL *)url withLog:(ActivityItem *)aItem shouldForceRefresh:(BOOL)force
{	
	if (!hasStarted)
	{
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_RefreshStatus" object:nil];
			hasStarted = YES;
	}

	ASIHTTPRequest *myRequest;
	
	if (IsRSSFolder(folder)) {
		myRequest = [ASIHTTPRequest requestWithURL:url];
		NSString * theLastUpdateString = [folder lastUpdateString];
        if (![theLastUpdateString isEqualToString:@""])
        {
            [myRequest addRequestHeader:@"If-Modified-Since" value:theLastUpdateString];
        }
		[myRequest setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:folder, @"folder", aItem, @"log", [NSNumber numberWithInt:MA_Refresh_Feed], @"type", nil]];
		if (![[folder username] isEqualToString:@""])
		{
			[myRequest setUsername:[folder username]];
			[myRequest setPassword:[folder password]];
			[myRequest setUseCookiePersistence:NO];
		}
		[myRequest setDelegate:self];
		[myRequest setDidFinishSelector:@selector(folderRefreshCompleted:)];
		[myRequest setDidFailSelector:@selector(folderRefreshFailed:)];
		[myRequest setWillRedirectSelector:@selector(folderRefreshRedirect:)];
		[myRequest addRequestHeader:@"Accept" value:@"application/rss+xml,application/rdf+xml,application/atom+xml,text/xml,application/xml,application/xhtml+xml;q=0.9,text/html;q=0.8,*/*;q=0.5"];
	} else { // Open Reader feed
		myRequest = [[GoogleReader sharedManager] refreshFeed:folder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:force];
	}
	[myRequest setTimeOutSeconds:180];
	// hack for handling file:// URLs
	if ([url isFileURL]) {
		[self folderRefreshCompleted:myRequest];
	} else {
		[self addConnection:myRequest];
	}
}


// failure callback
- (void)folderRefreshFailed:(ASIHTTPRequest *)request

{	LOG_EXPR([request error]);
	Folder * folder = (Folder *)[[request userInfo] objectForKey:@"folder"];
	if ([[request error] code] == ASIAuthenticationErrorType) //Error caused by lack of authentication
	{
		if (![authQueue containsObject:folder])
			[authQueue addObject:folder];
		[self getCredentialsForFolder];
	}
    ActivityItem * aItem = (ActivityItem *)[[request userInfo] objectForKey:@"log"];
	[self setFolderErrorFlag:folder flag:YES];
	[aItem appendDetail:[NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"Error retrieving RSS feed:", nil),[[request error] localizedDescription ]]];
	[aItem setStatus:NSLocalizedString(@"Error",nil)];
	[self syncFinishedForFolder:folder];
}

/* pumpFolderIconRefresh
 * Initiate a connect to refresh the icon for a folder.
 */
-(void)pumpFolderIconRefresh:(Folder *)folder
{
	// The activity log name we use depends on whether or not this folder has a real name.
	NSString * name = [[folder name] isEqualToString:[Database untitledFeedFolderName]] ? [folder feedURL] : [folder name];
	ActivityItem * aItem = [[ActivityLog defaultLog] itemByName:name];
	
	NSString * favIconPath;
	
	if (IsRSSFolder(folder)) {
		[aItem appendDetail:NSLocalizedString(@"Retrieving folder image", nil)];
		favIconPath = [NSString stringWithFormat:@"%@/favicon.ico", [[[folder homePage] trim] baseURL]];
	} else { // Open Reader feed
		[aItem appendDetail:NSLocalizedString(@"Retrieving folder image for Open Reader Feed", nil)];
		favIconPath = [NSString stringWithFormat:@"%@/favicon.ico", [[[folder homePage] trim] baseURL]];
	} 

	ASIHTTPRequest *myRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:favIconPath]];
	[myRequest setDelegate:self];
	[myRequest setDidFinishSelector:@selector(iconRequestDone:)];
	[myRequest setDidFailSelector:@selector(iconRequestFailed:)];
	[myRequest setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:folder, @"folder", aItem, @"log", [NSNumber numberWithInt:MA_Refresh_FavIcon], @"type", nil]];
	[self addConnection:myRequest];

}

// success callback
- (void)iconRequestDone:(ASIHTTPRequest *)request
{
	Folder * folder = (Folder *)[[request userInfo] objectForKey:@"folder"];	
	ActivityItem * aItem = [[ActivityLog defaultLog] itemByName:[folder name]];
	[self setFolderUpdatingFlag:folder flag:NO];
	if ([request responseStatusCode] == 404) {
		[aItem appendDetail:NSLocalizedString(@"RSS Icon not found!", nil)];
	} else if ([request responseStatusCode] == 200) {
		
		NSImage * iconImage = [[NSImage alloc] initWithData:[request responseData]];
		if (iconImage != nil && [iconImage isValid])
		{
			[iconImage setSize:NSMakeSize(16, 16)];
			[folder setImage:iconImage];
			
			// Broadcast a notification since the folder image has now changed
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[folder itemId]]];
			
			// Log additional details about this.
			[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Folder image retrieved from %@", nil), [request url]]];
			[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%ld bytes received", nil), [[request responseData] length]]];
		}
		[iconImage release];
	} else {
		[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil), [request responseStatusCode]]];
	}

    [[Database sharedManager] clearFlag:MA_FFlag_CheckForImage forFolder:folder.itemId];

}

// failure callback
- (void)iconRequestFailed:(ASIHTTPRequest *)request
{
	Folder * folder = (Folder *)[[request userInfo] objectForKey:@"folder"];
	ActivityItem * aItem = [[ActivityLog defaultLog] itemByName:[folder name]];
	[aItem appendDetail:[NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"Error retrieving RSS Icon:", nil),[[request error] localizedDescription ]]];
    [[Database sharedManager] clearFlag:MA_FFlag_CheckForImage forFolder:folder.itemId];
}

- (void)syncFinishedForFolder:(Folder *)folder 
{
    [self setFolderUpdatingFlag:folder flag:NO];
    dispatch_async(dispatch_get_main_queue(), ^{
		// Unread count may have changed
		AppController *controller = APPCONTROLLER;
		[controller setStatusMessage:nil persist:NO];
		[controller showUnreadCountOnApplicationIconAndWindowTitle];
	});
}

/* folderRefreshRedirect
 * Called when a folder refresh is being redirected.
 */
-(void)folderRefreshRedirect:(ASIHTTPRequest *)connector
{

	NSURL *newURL = [NSURL URLWithString:[[connector responseHeaders] valueForKey:@"Location"] relativeToURL:[connector url]];
	int responseStatusCode = [connector responseStatusCode];

	if (responseStatusCode == 301)
	{
		// We got a permanent redirect from the feed so change the feed URL to the new location.
		Folder * folder = (Folder *)[[connector userInfo] objectForKey:@"folder"];
		ActivityItem *connectorItem = [[connector userInfo] objectForKey:@"log"];

        [[Database sharedManager] setFeedURL:newURL.absoluteString
                                   forFolder:folder.itemId];
        
		[connectorItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Feed URL updated to %@", nil), [newURL absoluteString]]];
	}

	[connector redirectToURL:newURL];
}

/* folderRefreshCompleted
 * Called when a folder refresh completed.
 */
-(void)folderRefreshCompleted:(ASIHTTPRequest *)connector
{
	dispatch_async(_queue, ^() {
		
	Folder * folder = (Folder *)[[connector userInfo] objectForKey:@"folder"];
	ActivityItem *connectorItem = [[connector userInfo] objectForKey:@"log"];
	int responseStatusCode = [connector responseStatusCode];
	NSURL *url = [connector url];
	BOOL isCancelled = [connector isCancelled];
	NSInteger folderId = [folder itemId];
	Database * dbManager = [Database sharedManager];
	
     // hack for handling file:// URLs
	if ([url isFileURL])
	{
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *filePath = [[url path] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		BOOL isDirectory = NO;
		if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] && !isDirectory)
		{
        	responseStatusCode = 200;
			NSData * receivedData = [NSData dataWithContentsOfFile:filePath];
			[connector setRawResponseData:[NSMutableData dataWithContentsOfFile:filePath]];
			[connector setContentLength:[receivedData length]];
			[connector setTotalBytesRead:[receivedData length]];
		} else {
			responseStatusCode = 404;
		}
	}
	
	if (responseStatusCode == 304)
	{		
		// No modification from last check

        [dbManager setLastUpdate:[NSDate date] forFolder:folderId];

		[self setFolderErrorFlag:folder flag:NO];
		[connectorItem appendDetail:NSLocalizedString(@"Got HTTP status 304 - No news from last check", nil)];
		[connectorItem setStatus:NSLocalizedString(@"No new articles available", nil)];
		[self syncFinishedForFolder:folder];
		return;
	}
	else if (isCancelled) 
	{
		// Stopping the connection isn't an error, so clear any existing error flag.
		[self setFolderErrorFlag:folder flag:NO];
		
		// FIX: if we don't check this folder we shouldn't update the lastupdate field
		// Set the last update date for this folder.
		// [dbManager setFolderLastUpdate:folderId lastUpdate:[NSDate date]];
		
		// If this folder also requires an image refresh, add that
        if (([folder flags] & MA_FFlag_CheckForImage)) [self refreshFavIconForFolder:folder];
	}
	else if (responseStatusCode == 410)
	{
		// We got HTTP 410 which means the feed has been intentionally removed so unsubscribe the feed.
        [dbManager setFlag:MA_FFlag_Unsubscribed forFolder:folderId];

		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated"
                                                                            object:@(folderId)];
	}
	else if (responseStatusCode == 200)
	{
				
		NSData * receivedData = [connector responseData];
		NSString * lastModifiedString = [[connector responseHeaders] valueForKey:@"Last-Modified"];
				
		[self finalizeFolderRefresh:[NSDictionary dictionaryWithObjectsAndKeys:
																					folder, @"folder", 
																					connectorItem, @"log", 
																					url, @"url",
																					receivedData, @"data",
																					lastModifiedString, @"lastModifiedString",
																					nil]];
	}
	else	//other HTTP response codes like 404, 403...
	{
		[connectorItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil), responseStatusCode]];
		[connectorItem setStatus:NSLocalizedString(@"Error", nil)];
		[self setFolderErrorFlag:folder flag:YES];
	}

	[self syncFinishedForFolder:folder];

	}); //block for dispatch_async on _queue
};

-(void)finalizeFolderRefresh:(NSDictionary*)parameters;
{	
	
	ZAssert(parameters!=NULL, @"Null");
	Folder * folder = (Folder *)[parameters objectForKey:@"folder"];
	NSInteger folderId = [folder itemId];
	Database * dbManager = [Database sharedManager];
	ActivityItem *connectorItem = [parameters objectForKey:@"log"];
	NSURL *url = [parameters objectForKey:@"url"];
	NSData * receivedData = [parameters objectForKey:@"data"];
	NSString * lastModifiedString = [parameters objectForKey:@"lastModifiedString"];
    
	// Check whether this is an HTML redirect. If so, create a new connection using
	// the redirect.
	
	NSString * redirectURL = [self getRedirectURL:receivedData];
	

		if (redirectURL != nil)
		{
			if ([redirectURL isEqualToString:[url absoluteString]])
			{
				// To prevent an infinite loop, don't redirect to the same URL.
				[connectorItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Improper infinitely looping URL redirect to %@", nil), [url absoluteString]]];
			}
			else
			{
				[self refreshFeed:folder fromURL:[NSURL URLWithString:redirectURL] withLog:connectorItem shouldForceRefresh:NO];
				return;
			}
		}
        
		        
		// Empty data feed is OK if we got HTTP 200
		__block NSUInteger newArticlesFromFeed = 0;
		RichXMLParser * newFeed = [[RichXMLParser alloc] init];
		if ([receivedData length] > 0)
		{
			Preferences * standardPreferences = [Preferences standardPreferences];
			if ([standardPreferences shouldSaveFeedSource])
			{
				NSString * feedSourcePath = [folder feedSourceFilePath];
				
				if ([standardPreferences boolForKey:MAPref_ShouldSaveFeedSourceBackup])
				{
					BOOL isDirectory = YES;
					NSFileManager * defaultManager = [NSFileManager defaultManager];
					if ([defaultManager fileExistsAtPath:feedSourcePath isDirectory:&isDirectory] && !isDirectory)
					{
						NSString * backupPath = [feedSourcePath stringByAppendingPathExtension:@"bak"];
						if (![defaultManager fileExistsAtPath:backupPath] || [defaultManager removeItemAtPath:backupPath error:NULL]) // Remove any old backup first
						{
							[defaultManager moveItemAtPath:feedSourcePath toPath:backupPath error:NULL];
						}
					}
				}
				
				[receivedData writeToFile:feedSourcePath options:NSAtomicWrite error:NULL];
			}
			
			// Create a new rich XML parser instance that will take care of
			// parsing the XML data we just got.
			if (newFeed == nil || ![newFeed parseRichXML:receivedData])
			{
				// Mark the feed as failed
				[self setFolderErrorFlag:folder flag:YES];
				[connectorItem setStatus:NSLocalizedString(@"Error parsing XML data in feed", nil)];
				[newFeed release];
				return;
			}
            
			// Log number of bytes we received
			[connectorItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%ld bytes received", nil), [receivedData length]]];
			
			// Extract the latest title and description
			NSString * feedTitle = [newFeed title];
			NSString * feedDescription = [newFeed description];
			NSString * feedLink = [newFeed link];
			
			// Synthesize feed link if it is missing
			if (feedLink == nil || [feedLink isBlank])
				feedLink = [[folder feedURL] baseURL];
			if (feedLink != nil && ![feedLink hasPrefix:@"http:"] && ![feedLink hasPrefix:@"https:"])
				feedLink = [[NSURL URLWithString:feedLink relativeToURL:url] absoluteString];

			
			// We'll be collecting articles into this array
			NSMutableArray * articleArray = [NSMutableArray array];
			NSMutableArray * articleGuidArray = [NSMutableArray array];
			
			NSDate * itemAlternativeDate = [newFeed lastModified];
			if (itemAlternativeDate == nil)
				itemAlternativeDate = [NSDate date];

			// Parse off items.
			
			for (FeedItem * newsItem in [newFeed items])
			{
				NSDate * articleDate = [newsItem date];
				
				NSString * articleGuid = [newsItem guid];
				
				// This routine attempts to synthesize a GUID from an incomplete item that lacks an
				// ID field. Generally we'll have three things to work from: a link, a title and a
				// description. The link alone is not sufficiently unique and I've seen feeds where
				// the description is also not unique. The title field generally does vary but we need
				// to be careful since separate articles with different descriptions may have the same
				// title. The solution is to use the link and title and build a GUID from those.
				// We add the folderId at the beginning to ensure that items in different feeds do not share a guid.
                if ([articleGuid isEqualToString:@""]) {
					articleGuid = [NSString stringWithFormat:@"%ld-%@-%@", (long)folderId, [newsItem link], [newsItem title]];
                }
				// This is a horrible hack for horrible feeds that contain more than one item with the same guid.
				// Bad feeds! I'm talking to you, Orange Madagascar.
				NSUInteger articleIndex = [articleGuidArray indexOfObject:articleGuid];
				if (articleIndex != NSNotFound)
				{
					// rebuild a complex guid which should eliminate most duplicates
                    if (articleDate == nil) {
						articleGuid = [NSString stringWithFormat:@"%ld-%@-%@", (long)folderId, [newsItem link], [newsItem title]];
                    }
                    else {
						articleGuid = [NSString stringWithFormat:@"%ld-%@-%@-%@", (long)folderId, [NSString stringWithFormat:@"%1.3f", [articleDate timeIntervalSince1970]], [newsItem link], [newsItem title]];
                    }
				}
				[articleGuidArray addObject:articleGuid];
				
				// set the article date if it is missing. We'll use the
				// last modified date of the feed and set each article to be 1 second older than the
				// previous one. So the array is effectively newest first.
				if (articleDate == nil)
				{
					articleDate = itemAlternativeDate;
					itemAlternativeDate = [itemAlternativeDate dateByAddingTimeInterval:-1.0];
				}
				
				Article * article = [[[Article alloc] initWithGuid:articleGuid] autorelease];
				[article setFolderId:folderId];
				[article setAuthor:[newsItem author]];
				[article setBody:[newsItem description]];
				[article setTitle:[newsItem title]];
				NSString * articleLink = [newsItem link];
				if (![articleLink hasPrefix:@"http:"] && ![articleLink hasPrefix:@"https:"])
					articleLink = [[NSURL URLWithString:articleLink relativeToURL:url] absoluteString];
				if (articleLink == nil)
					articleLink = feedLink;
				[article setLink:articleLink];
				[article setDate:articleDate];
				NSString * enclosureLink = [newsItem enclosure];
				if ([enclosureLink isNotEqualTo:@""] && ![enclosureLink hasPrefix:@"http:"] && ![enclosureLink hasPrefix:@"https:"])
					enclosureLink = [[NSURL URLWithString:enclosureLink relativeToURL:url] absoluteString];
				[article setEnclosure:enclosureLink];
				if ([enclosureLink isNotEqualTo:@""])
				{
					[article setHasEnclosure:YES];
				}
				[articleArray addObject:article];
			}
			
			
			// Here's where we add the articles to the database
			if ([articleArray count] > 0u)
			{
				NSArray * guidHistory = [dbManager guidHistoryForFolderId:folderId];
				[folder clearCache];
				for (Article * article in articleArray)
				{
					if ([dbManager createArticle:folderId
                                         article:article
                                     guidHistory:guidHistory] && ([article status] == ArticleStatusNew)) {
						++newArticlesFromFeed;
                    }
				}
			}
			
            
			// A notify is only needed if we added any new articles.
			if ([[folder name] hasPrefix:[Database untitledFeedFolderName]] && ![feedTitle isBlank])
			{
				// If there's an existing feed with this title, make ours unique
				// BUGBUG: This duplicates logic in database.m so consider moving it there.
				NSString * oldFeedTitle = feedTitle;
				NSString * newFeedTitle = feedTitle;
				NSUInteger index = 1;
                
				while (([dbManager folderFromName:newFeedTitle]) != nil)
					newFeedTitle = [NSString stringWithFormat:@"%@ (%li)", oldFeedTitle, (unsigned long)index++];
                
				[connectorItem setName:newFeedTitle];
                [dbManager setName:newFeedTitle forFolder:folderId];
			}
            if (feedDescription != nil) {
                [dbManager setDescription:feedDescription forFolder:folderId];
            }
            if (feedLink!= nil) {
                [dbManager setHomePage:feedLink forFolder:folderId];
            }

			// Remember the last modified date
            if (lastModifiedString != nil) {
                [dbManager setLastUpdateString:lastModifiedString forFolder:folderId];
            }
			// Set the last update date for this folder.
            [dbManager setLastUpdate:[NSDate date] forFolder:folderId];
			

			// Mark the feed as succeeded
			[self setFolderErrorFlag:folder flag:NO];

		};
				  
		// Send status to the activity log
        if (newArticlesFromFeed == 0) {
                [connectorItem setStatus:NSLocalizedString(@"No new articles available", nil)];
        }
		else
		{
			NSString * logText = [NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newArticlesFromFeed];
			[connectorItem setStatus:logText];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_ArticleListStateChange" object:folder];
		}
		
		// Done with this connection
		[newFeed release];
        
		// Add to count of new articles so far
		countOfNewArticles += newArticlesFromFeed;
	
		// If this folder also requires an image refresh, do that
        if (([folder flags] & MA_FFlag_CheckForImage)) {
                [self refreshFavIconForFolder:folder];
        }

}

/* getRedirectURL
 * Scans the XML data and checks whether it is actually an HTML redirect. If so, returns the
 * redirection URL. (Yes, I'm aware that some of this could be better implemented with calls to
 * strnstr and its ilk but I have a deep rooted distrust of the standard C runtime stemming from
 * a childhood trauma with buffer overflows so bear with me.)
 */
-(NSString *)getRedirectURL:(NSData *)data
{
	const char * scanPtr = [data bytes];
	const char * scanPtrEnd = scanPtr + [data length];
	
	// Make sure this is HTML otherwise this is likely just valid
	// XML and we can ignore everything else.
	const char * htmlTagPtr = "<html>";
	while (scanPtr < scanPtrEnd && *htmlTagPtr != '\0')
	{
		if (*scanPtr != ' ')
		{
			if (tolower(*scanPtr) != *htmlTagPtr)
				return nil;
			++htmlTagPtr;
		}
		++scanPtr;
	}
	
	// Look for the meta attribute
	const char * metaTag = "<meta ";
	const char * headEndTag = "</head>";
	const char * metaTagPtr = metaTag;
	const char * headEndTagPtr = headEndTag;
	while (scanPtr < scanPtrEnd)
	{
		if (tolower(*scanPtr) == *metaTagPtr)
			++metaTagPtr;
		else
		{
			metaTagPtr = metaTag;
			if (tolower(*scanPtr) == *headEndTagPtr)
				++headEndTagPtr;
			else
				headEndTagPtr = headEndTag;
		}
		if (*headEndTagPtr == '\0')
			return nil;
		if (*metaTagPtr == '\0')
		{
			// Now see if this meta tag has http-equiv attribute
			const char * httpEquivAttr = "http-equiv=\"refresh\"";
			const char * httpEquivAttrPtr = httpEquivAttr;
			while (scanPtr < scanPtrEnd && *scanPtr != '>')
			{
				if (tolower(*scanPtr) == *httpEquivAttrPtr)
					++httpEquivAttrPtr;
				else if (*scanPtr != ' ')
					httpEquivAttrPtr = httpEquivAttr;
				if (*httpEquivAttrPtr == '\0')
				{
					// OK. This is our meta tag. Now look for the URL field
					while (scanPtr < scanPtrEnd-3 && *scanPtr != '>')
					{
						if (tolower(*scanPtr) == 'u' && tolower(*(scanPtr+1)) == 'r' && tolower(*(scanPtr+2)) == 'l' && *(scanPtr+3) == '=')
						{
							const char * urlStart = scanPtr + 4;
							const char * urlEnd = urlStart;
							
							// Finally, gather the URL for the redirect and return it as an
							// auto-released string.
							while (urlEnd < scanPtrEnd && *urlEnd != '"' && *urlEnd != ' ' && *urlEnd != '>')
								++urlEnd;
							if (urlEnd == scanPtrEnd)
								return nil;
							return [[[NSString alloc] initWithBytes:urlStart length:(urlEnd - urlStart) encoding:NSASCIIStringEncoding] autorelease];
						}
						++scanPtr;
					}
				}
				++scanPtr;
			}
			
			// Not our meta tag so look for another
			metaTagPtr = metaTag;
		}
		++scanPtr;
	}
	return nil;
}

/* addConnection
 * Add the specified connection to the connections queue
 * that we manage.
 */
-(void)addConnection:(ASIHTTPRequest *)conn
{
	if (![[networkQueue operations] containsObject:conn]) {
		[networkQueue addOperation:conn];
		if ([networkQueue requestsCount] == 1) // networkQueue is NOT YET started
		{
			countOfNewArticles = 0;
			[networkQueue go];
		}
	}
}

/* removeConnection
 * Removes the specified connection from the connections queue
 * that we manage.
 */
-(void)removeConnection:(ASIHTTPRequest *)conn
{
	NSAssert([networkQueue requestsCount] > 0, @"Calling removeConnection with zero active connection count");
	if ([[networkQueue operations] containsObject:conn])
	{
		// Close the connection before we release as otherwise it leaks
		[conn clearDelegatesAndCancel];
	}
	
}

-(BOOL)isConnecting
{
	LOG_NS(@"Connected : %@", [networkQueue requestsCount] > 0 ? @"yes" : @"no" );
	return [networkQueue requestsCount] > 0;
}


/* dealloc
 * Clean up after ourselves.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[pumpTimer release];
	pumpTimer=nil;
	[authQueue release];
	authQueue=nil;
	[networkQueue release];
	networkQueue=nil;
	dispatch_release(_queue);
	[super dealloc];
}
@end
