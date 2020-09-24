//
//  RefreshManager.m
//  Vienna
//
//  Created by Steve on 7/19/05.
//  Copyright (c) 2004-2018 Steve Palmer and Vienna contributors (see menu item 'About Vienna' for list of contributors). All rights reserved.
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
#import "ActivityItem.h"
#import "ActivityLog.h"
#import "RichXMLParser.h"
#import "StringExtensions.h"
#import "Preferences.h"
#import "Constants.h"
#import "OpenReader.h"
#import "NSNotificationAdditions.h"
#import "VTPG_Common.h"
#import "Debug.h"
#import "Article.h"
#import "Folder.h"
#import "Database.h"
#import "TRVSURLSessionOperation.h"
#import "URLRequestExtensions.h"

typedef NS_ENUM (NSInteger, Redirect301Status) {
    HTTP301Unknown = 0,
    HTTP301Pending,
    HTTP301Unsafe,
    HTTP301Safe
};

@interface RefreshManager ()

@property (readwrite, copy) NSString * statusMessage;
@property (nonatomic, retain) NSTimer * unsafe301RedirectionTimer;
@property (atomic, copy) NSString * riskyIPAddress;
@property (nonatomic) Redirect301Status redirect301Status;
@property (nonatomic) NSMutableArray * redirect301WaitQueue;
@property (nonatomic, readonly) NSURLSession * urlSession;

-(BOOL)isRefreshingFolder:(Folder *)folder ofType:(RefreshTypes)type;
-(void)getCredentialsForFolder;
-(void)setFolderErrorFlag:(Folder *)folder flag:(BOOL)theFlag;
-(void)setFolderUpdatingFlag:(Folder *)folder flag:(BOOL)theFlag;
-(void)pumpSubscriptionRefresh:(Folder *)folder shouldForceRefresh:(BOOL)force;
-(void)pumpFolderIconRefresh:(Folder *)folder;
-(void)refreshFeed:(Folder *)folder fromURL:(NSURL *)url withLog:(ActivityItem *)aItem shouldForceRefresh:(BOOL)force;
-(NSString *)getRedirectURL:(NSData *)data;
-(void)syncFinishedForFolder:(Folder *)folder;

@end

@implementation RefreshManager

+(void)initialize
{
}


/* init
 * Initialise the class.
 */
-(instancetype)init
{
    if ((self = [super init]) != nil) {
        countOfNewArticles = 0;
        authQueue = [[NSMutableArray alloc] init];
        statusMessageDuringRefresh = nil;
        networkQueue = [[NSOperationQueue alloc] init];
        networkQueue.name = @"VNAHTTPSession queue";
        networkQueue.maxConcurrentOperationCount = [[Preferences standardPreferences] integerForKey:MAPref_ConcurrentDownloads];
        NSString * osVersion;
        if (@available(macOS 10.10, *)) {
            NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
            osVersion = [NSString stringWithFormat:@"%ld_%ld_%ld", version.majorVersion, version.minorVersion, version.patchVersion];
        } else {
            osVersion = @"10_9_x";
        }
        NSString * userAgent = [NSString stringWithFormat:MA_DefaultUserAgentString, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"], osVersion];
        NSURLSessionConfiguration * config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 180;
        config.URLCache = nil;
        config.HTTPAdditionalHeaders = @{@"User-Agent": userAgent};
        config.HTTPMaximumConnectionsPerHost = 6;
        config.HTTPShouldUsePipelining = YES;
        _urlSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];

        NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(handleGotAuthenticationForFolder:) name:@"MA_Notify_GotAuthenticationForFolder" object:nil];
        [nc addObserver:self selector:@selector(handleCancelAuthenticationForFolder:) name:@"MA_Notify_CancelAuthenticationForFolder"
            object:nil];
        [nc addObserver:self selector:@selector(handleWillDeleteFolder:) name:databaseWillDeleteFolderNotification object:nil];
        [nc addObserver:self selector:@selector(handleChangeConcurrentDownloads:) name:@"MA_Notify_CowncurrentDownloadsChange" object:nil];
        // be notified on system wake up after sleep
        [[NSWorkspace sharedWorkspace].notificationCenter addObserver:self selector:@selector(handleDidWake:)
            name:@"NSWorkspaceDidWakeNotification" object:nil];
        _queue = dispatch_queue_create("uk.co.opencommunity.vienna2.refresh", NULL);
        _redirect301WaitQueue = [[NSMutableArray alloc] init];
        hasStarted = NO;
    }
    return self;
} // init

/* sharedManager
 * Returns the single instance of the refresh manager.
 */
+(RefreshManager *)sharedManager
{
    // Singleton
    static RefreshManager * _refreshManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _refreshManager = [[RefreshManager alloc] init];
    });
    return _refreshManager;
}

-(void)handleChangeConcurrentDownloads:(NSNotification *)nc
{
    NSLog(@"Handling new downloads count");
    networkQueue.maxConcurrentOperationCount = [[Preferences standardPreferences] integerForKey:MAPref_ConcurrentDownloads];
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
    Folder * folder = [[Database sharedManager] folderFromID:[nc.object integerValue]];
    if (folder != nil) {
        for (TRVSURLSessionOperation *theRequest in networkQueue.operations) {
            NSMutableURLRequest *urlRequest = (NSMutableURLRequest *)(theRequest.task.originalRequest);
            if (((NSDictionary *)[urlRequest userInfo])[@"folder"] == folder) {
                [theRequest.task cancel];
                break;
            }
        }
    }
}


-(void)handleDidWake:(NSNotification *)nc
{
    NSString * currentAddress = [NSHost currentHost].address;
    if (![currentAddress isEqualToString:self.riskyIPAddress]) {
        // we might have moved to a new network
        // so, at the next occurence we should test if we can safely handle
        // 301 redirects
        self.redirect301Status = HTTP301Unknown;
        [self.unsafe301RedirectionTimer invalidate];
        self.unsafe301RedirectionTimer = nil;
    }
}

/* handleGotAuthenticationForFolder [delegate]
 * Called when somewhere just provided us the needed authentication for the specified
 * folder. Note that we don't know if the authentication is valid yet - just that a
 * user name and password has been provided.
 */
-(void)handleGotAuthenticationForFolder:(NSNotification *)nc
{
    Folder * folder = (Folder *)nc.object;
    [[Database sharedManager] clearFlag:VNAFolderFlagNeedCredentials forFolder:folder.itemId];
    [authQueue removeObject:folder];
    [self refreshSubscriptions:@[folder] ignoringSubscriptionStatus:YES];

    // Get the next one in the queue, if any
    [self getCredentialsForFolder];
}

/* handleCancelAuthenticationForFolder
 * Called when somewhere cancelled our request to authenticate the specified
 * folder.
 */
-(void)handleCancelAuthenticationForFolder:(NSNotification *)nc
{
    Folder * folder = (Folder *)nc.object;
    [authQueue removeObject:folder];

    // Get the next one in the queue, if any
    [self getCredentialsForFolder];
}

-(void)forceRefreshSubscriptionForFolders:(NSArray *)foldersArray
{
    statusMessageDuringRefresh = NSLocalizedString(@"Forcing Refresh subscriptions…", nil);

    for (Folder * folder in foldersArray) {
        if (folder.type == VNAFolderTypeGroup) {
            [self forceRefreshSubscriptionForFolders:[[Database sharedManager] arrayOfFolders:folder.itemId]];
        } else if (folder.type == VNAFolderTypeOpenReader) {
            if (![self isRefreshingFolder:folder ofType:MA_Refresh_GoogleFeed] &&
                ![self isRefreshingFolder:folder ofType:MA_ForceRefresh_Google_Feed])
            {
                [self pumpSubscriptionRefresh:folder shouldForceRefresh:YES];
            }
        }
    }
}

/* refreshSubscriptions
 * Add the folders specified in the foldersArray to the refresh queue.
 */
-(void)refreshSubscriptions:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus
{
    statusMessageDuringRefresh = NSLocalizedString(@"Refreshing subscriptions…", nil);

    for (Folder * folder in foldersArray) {
        if (folder.isGroupFolder) {
            [self refreshSubscriptions:[[Database sharedManager] arrayOfFolders:folder.itemId] ignoringSubscriptionStatus:NO];
        } else if (folder.isRSSFolder) {
            if ((!folder.isUnsubscribed || ignoreSubStatus) && ![self isRefreshingFolder:folder ofType:MA_Refresh_Feed]) {
                [self pumpSubscriptionRefresh:folder shouldForceRefresh:NO];
            }
        } else if (folder.isOpenReaderFolder) {
            if ((!folder.isUnsubscribed || ignoreSubStatus)  && ![self isRefreshingFolder:folder ofType:MA_Refresh_GoogleFeed] &&
                ![self isRefreshingFolder:folder ofType:MA_ForceRefresh_Google_Feed])
            {
                // we depend of pieces of info gathered by loadSubscriptions
                NSOperation * op = [NSBlockOperation blockOperationWithBlock:^(void) {
                     if (!folder.isSyncedOK) {
                        [self pumpSubscriptionRefresh:folder shouldForceRefresh:NO];
                     }
                }];
                NSOperation * unreadCountOperation = [OpenReader sharedManager].unreadCountOperation;
                if (unreadCountOperation != nil && !unreadCountOperation.isFinished) {
                    [op addDependency:unreadCountOperation];
                }
                [[NSOperationQueue mainQueue] addOperation:op];
            }
        }
    }
} // refreshSubscriptions

/* refreshFolderIconCacheForSubscriptions
 * Add the folders specified in the foldersArray to the refresh queue.
 */
-(void)refreshFolderIconCacheForSubscriptions:(NSArray *)foldersArray
{
    statusMessageDuringRefresh = NSLocalizedString(@"Refreshing folder images…", nil);

    for (Folder * folder in foldersArray) {
        if (folder.type == VNAFolderTypeGroup) {
            [self refreshFolderIconCacheForSubscriptions:[[Database sharedManager] arrayOfFolders:folder.itemId]];
        } else if (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) {
            [self refreshFavIconForFolder:folder];
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
    if ((folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) &&
        (folder.homePage == nil || folder.homePage.blank || folder.hasCachedImage))
    {
        [[Database sharedManager] clearFlag:VNAFolderFlagCheckForImage forFolder:folder.itemId];
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
    for (TRVSURLSessionOperation *theRequest in networkQueue.operations) {
        NSMutableURLRequest *urlRequest = (NSMutableURLRequest *)(theRequest.task.originalRequest);
        if ((((NSDictionary *)[urlRequest userInfo])[@"folder"] == folder) &&
            ([[((NSDictionary *)[urlRequest userInfo]) valueForKey:@"type"] integerValue] == @(type).integerValue))
        {
            return YES;
        }
    }
    return NO;
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
    if (credentialsController == nil) {
        credentialsController = [[FeedCredentials alloc] init];
    }

    // Pull next folder out of the queue. The UI will post a
    // notification when it is done and we can move on to the
    // next one.
    if (authQueue.count > 0 && !credentialsController.window.visible) {
        Folder * folder = authQueue[0];
        [credentialsController credentialsForFolder:NSApp.mainWindow folder:folder];
    }
}

/* setFolderErrorFlag
 * Sets or clears the folder error flag then broadcasts an update indicating that the folder
 * has changed.
 */
-(void)setFolderErrorFlag:(Folder *)folder flag:(BOOL)theFlag
{
    if (theFlag) {
        [folder setNonPersistedFlag:VNAFolderFlagError];
    } else {
        [folder clearNonPersistedFlag:VNAFolderFlagError];
    }
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:@(folder.itemId)];
}

/* setFolderUpdatingFlag
 * Sets or clears the folder updating flag then broadcasts an update indicating that the folder
 * has changed.
 */
-(void)setFolderUpdatingFlag:(Folder *)folder flag:(BOOL)theFlag
{
    if (theFlag) {
        [folder setNonPersistedFlag:VNAFolderFlagUpdating];
    } else {
        [folder clearNonPersistedFlag:VNAFolderFlagUpdating];
    }
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:@(folder.itemId)];
}

/* pumpFolderIconRefresh
 * Initiate a connect to refresh the icon for a folder.
 */
-(void)pumpFolderIconRefresh:(Folder *)folder
{
    // The activity log name we use depends on whether or not this folder has a real name.
    NSString * name = [folder.name hasPrefix:[Database untitledFeedFolderName]] ? folder.feedURL : folder.name;
    ActivityItem *aItem = [[ActivityLog defaultLog] itemByName:name];

    NSString * favIconPath;

    if (folder.type == VNAFolderTypeRSS) {
        [aItem appendDetail:NSLocalizedString(@"Retrieving folder image", nil)];
        favIconPath = [NSString stringWithFormat:@"%@/favicon.ico", folder.homePage.trim.baseURL];
    } else {     // Open Reader feed
        [aItem appendDetail:NSLocalizedString(@"Retrieving folder image for Open Reader Feed", nil)];
        favIconPath = [NSString stringWithFormat:@"%@/favicon.ico", folder.homePage.trim.baseURL];
    }

    NSMutableURLRequest *myRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:favIconPath]];
    __weak typeof(self)weakSelf = self;
    [self addConnection:myRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [aItem appendDetail:[NSString stringWithFormat:@"%@ %@",
                                     NSLocalizedString(@"Error retrieving RSS Icon:", nil), error.localizedDescription ]];
                [[Database sharedManager] clearFlag:VNAFolderFlagCheckForImage forFolder:folder.itemId];
            } else {
                [weakSelf setFolderUpdatingFlag:folder flag:NO];
                if (((NSHTTPURLResponse *)response).statusCode == 404) {
                    [aItem appendDetail:NSLocalizedString(@"RSS Icon not found!", nil)];
                } else if (((NSHTTPURLResponse *)response).statusCode == 200) {
                    NSImage *iconImage = [[NSImage alloc] initWithData:data];
                    if (iconImage != nil && iconImage.valid) {
                        iconImage.size = NSMakeSize(16, 16);
                        folder.image = iconImage;

                        // Broadcast a notification since the folder image has now changed
                        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:
                         @"MA_Notify_FoldersUpdated"
                                                                                            object:@(folder.itemId)];

                        // Log additional details about this.
                        [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Folder image retrieved from %@",
                                                                                         nil), myRequest.URL]];

                        NSString * byteCount = [NSByteCountFormatter stringFromByteCount:data.length
                                                                              countStyle:NSByteCountFormatterCountStyleFile];
                        [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%@ received",
                                                                                         @"Number of bytes received, e.g. 1 MB received"),
                                             byteCount]];
                    } else {
                        [aItem appendDetail:NSLocalizedString(@"RSS Icon not found!", nil)];
                    }
                } else {
                    [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server",
                                                                                     nil), ((NSHTTPURLResponse *)response).statusCode]];
                }

                [[Database sharedManager] clearFlag:VNAFolderFlagCheckForImage forFolder:folder.itemId];
            }
    }];
} // pumpFolderIconRefresh

#pragma mark Core of feed refresh

/* pumpSubscriptionRefresh
 * Pick the folder at the head of the refresh queue and spawn a connection to
 * refresh that folder.
 */
-(void)pumpSubscriptionRefresh:(Folder *)folder shouldForceRefresh:(BOOL)force
{
    // If this folder needs credentials, add the folder to the list requiring authentication
    // and since we can't progress without it, skip this folder on the connection
    if (folder.flags & VNAFolderFlagNeedCredentials) {
        [authQueue addObject:folder];
        [self getCredentialsForFolder];
        return;
    }


    // The activity log name we use depends on whether or not this folder has a real name.
    NSString * name = [folder.name hasPrefix:[Database untitledFeedFolderName]] ? folder.feedURL : folder.name;
    ActivityItem * aItem = [[ActivityLog defaultLog] itemByName:name];

    // Compute the URL for this connection
    NSString * urlString = folder.feedURL;
    NSURL * url = nil;

    if ([urlString hasPrefix:@"file://"]) {
        url = [NSURL fileURLWithPath:[urlString substringFromIndex:7].stringByExpandingTildeInPath];
    } else if ([urlString hasPrefix:@"feed://"]) {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", [urlString substringFromIndex:7]]];
    } else {
        url = [NSURL URLWithString:urlString];
    }

    // Seed the activity log for this feed.
    [aItem clearDetails];
    [aItem setStatus:NSLocalizedString(@"Retrieving articles", nil)];

    // Mark the folder as being refreshed. The updating status is not
    // persistent so we set this directly on the folder rather than
    // through the database.
    [self setFolderUpdatingFlag:folder flag:YES];

    // Additional detail for the log
    if (folder.type == VNAFolderTypeOpenReader) {
        [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Connecting to Open Reader server to retrieve %@", nil),
                             urlString]];
    } else {
        [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Connecting to %@", nil), urlString]];
    }

    // Kick off the connection
    [self refreshFeed:folder fromURL:url withLog:aItem shouldForceRefresh:force];
} // pumpSubscriptionRefresh

/* refreshFeed
 * Refresh a folder's newsfeed using the specified URL.
 */
-(void)refreshFeed:(Folder *)folder fromURL:(NSURL *)url withLog:(ActivityItem *)aItem shouldForceRefresh:(BOOL)force
{
    NSMutableURLRequest *myRequest;

    if (folder.type == VNAFolderTypeRSS) {
        myRequest = [NSMutableURLRequest requestWithURL:url];
        NSString * theLastUpdateString = folder.lastUpdateString;
        if (![theLastUpdateString isEqualToString:@""]) {
            [myRequest setValue:theLastUpdateString forHTTPHeaderField:@"If-Modified-Since"];
            [myRequest setValue:@"feed" forHTTPHeaderField:@"A-IM"];
        }
        [myRequest setUserInfo:@{ @"folder": folder, @"log": aItem, @"type": @(MA_Refresh_Feed) }];
        [myRequest addValue:
         @"application/rss+xml,application/rdf+xml,application/atom+xml,text/xml,application/xml,application/xhtml+xml;q=0.9,text/html;q=0.8,*/*;q=0.5"
                      forHTTPHeaderField:@"Accept"];
        // if authentication infos are present, try basic authentication first
        if (![folder.username isEqualToString:@""]) {
            NSString* usernameAndPassword = [NSString toBase64String:[NSString stringWithFormat:@"%@:%@", folder.username, folder.password]];
			[myRequest setValue:[NSString stringWithFormat:@"Basic %@", usernameAndPassword] forHTTPHeaderField:@"Authorization"];
		}


        __weak typeof(self)weakSelf = self;
        [self addConnection:myRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    [weakSelf folderRefreshFailed:myRequest error:error];
                } else {
                    [weakSelf folderRefreshCompleted:myRequest response:response data:data];
                }
                }];
    } else {     // Open Reader feed
        [[OpenReader sharedManager] refreshFeed:folder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:force];
    }
    if (!hasStarted) {
        hasStarted = YES;
        countOfNewArticles = 0;
        [[OpenReader sharedManager] resetCountOfNewArticles];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_RefreshStatus" object:nil];
    }
} // refreshFeed


// failure callback
-(void)folderRefreshFailed:(NSMutableURLRequest *)request error:(NSError *)error
{
    LOG_EXPR(error);
    Folder * folder = ((NSDictionary *)[request userInfo])[@"folder"];
    if (error.code == NSURLErrorCancelled) {
        // Stopping the connection isn't an error, so clear any existing error flag.
        [self setFolderErrorFlag:folder flag:NO];

        // If this folder also requires an image refresh, add that
        if ((folder.flags & VNAFolderFlagCheckForImage)) {
            [self refreshFavIconForFolder:folder];
        }
    } else if (error.code == NSURLErrorUserAuthenticationRequired) { //Error caused by lack of authentication
        if (![authQueue containsObject:folder]) {
            [authQueue addObject:folder];
        }
        [self getCredentialsForFolder];
    }
    ActivityItem *aItem = (ActivityItem *)((NSDictionary *)[request userInfo])[@"log"];
    [self setFolderErrorFlag:folder flag:YES];
    [aItem appendDetail:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Error retrieving RSS feed:", nil),
                         error.localizedDescription ]];
    [aItem setStatus:NSLocalizedString(@"Error", nil)];
    [self syncFinishedForFolder:folder];
} // folderRefreshFailed

/* folderRefreshCompleted
 * Called when a folder refresh completed.
 */
-(void)folderRefreshCompleted:(NSMutableURLRequest *)connector response:(NSURLResponse *)response data:(NSData *)receivedData
{
    dispatch_async(_queue, ^() {
        // TODO : refactor code to separate feed refresh code and UI

        Folder * folder = (Folder *)((NSDictionary *)[connector userInfo])[@"folder"];
        ActivityItem *connectorItem = ((NSDictionary *)[connector userInfo])[@"log"];
        NSURL * url = connector.URL;
        NSInteger folderId = folder.itemId;
        Database *dbManager = [Database sharedManager];
        NSInteger responseStatusCode;
        NSString * lastModifiedString;

        // hack for handling file:// URLs
        if (url.fileURL) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString * filePath = [url.path stringByRemovingPercentEncoding];
            BOOL isDirectory = NO;
            if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] && !isDirectory) {
                responseStatusCode = 200;
                lastModifiedString = [[fileManager attributesOfItemAtPath:filePath error:nil] fileModificationDate].description;
            } else {
                responseStatusCode = 404;
            }
        } else {
            responseStatusCode = ((NSHTTPURLResponse *)response).statusCode;
            lastModifiedString = SafeString([((NSHTTPURLResponse *)response).allHeaderFields valueForKey:@"Last-Modified"]);
        }

        if (responseStatusCode == 304) {
            // No modification from last check

            [dbManager setLastUpdate:[NSDate date] forFolder:folderId];

            [self setFolderErrorFlag:folder flag:NO];
            [connectorItem appendDetail:NSLocalizedString(@"Got HTTP status 304 - No news from last check", nil)];
            dispatch_async(dispatch_get_main_queue(), ^{
                [connectorItem setStatus:NSLocalizedString(@"No new articles available", nil)];
                [self syncFinishedForFolder:folder];
            });
            return;
        } else if (responseStatusCode == 410) {
            // We got HTTP 410 which means the feed has been intentionally removed so unsubscribe the feed.
            [dbManager setFlag:VNAFolderFlagUnsubscribed forFolder:folderId];

        } else if (responseStatusCode == 200 || responseStatusCode == 226) {
            if (receivedData != nil) {
                [self finalizeFolderRefresh:@{
                     @"folder": folder,
                     @"log": connectorItem,
                     @"url": url,
                     @"data": receivedData,
                     @"lastModifiedString": lastModifiedString,
                 }];
            }
        } else { //other HTTP response codes like 404, 403...
            [connectorItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil),
                                         responseStatusCode]];
            [connectorItem appendDetail:[NSHTTPURLResponse localizedStringForStatusCode:responseStatusCode]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [connectorItem setStatus:NSLocalizedString(@"Error", nil)];
            });
            [self setFolderErrorFlag:folder flag:YES];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self syncFinishedForFolder:folder];
        });
    });     //block for dispatch_async on _queue
} // folderRefreshCompleted

-(void)finalizeFolderRefresh:(NSDictionary *)parameters
{
    ZAssert(parameters != NULL, @"Null");
    Folder * folder = (Folder *)parameters[@"folder"];
    NSInteger folderId = folder.itemId;
    Database * dbManager = [Database sharedManager];
    ActivityItem *connectorItem = parameters[@"log"];
    NSURL * url = parameters[@"url"];
    NSData * receivedData = parameters[@"data"];
    NSString * lastModifiedString = parameters[@"lastModifiedString"];

    // Check whether this is an HTML redirect. If so, create a new connection using
    // the redirect.

    NSString * redirectURL = [self getRedirectURL:receivedData];


    if (redirectURL != nil) {
        if ([redirectURL isEqualToString:url.absoluteString]) {
            // To prevent an infinite loop, don't redirect to the same URL.
            [connectorItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Improper infinitely looping URL redirect to %@",
                                                                                     nil), url.absoluteString]];
        } else {
            [self refreshFeed:folder fromURL:[NSURL URLWithString:redirectURL] withLog:connectorItem shouldForceRefresh:NO];
            return;
        }
    }


    // Empty data feed is OK if we got HTTP 200
    __block NSUInteger newArticlesFromFeed = 0;
    RichXMLParser *newFeed = [[RichXMLParser alloc] init];
    if (receivedData.length > 0) {
        Preferences *standardPreferences = [Preferences standardPreferences];
        if (standardPreferences.shouldSaveFeedSource) {
            NSString * feedSourcePath = folder.feedSourceFilePath;

            if ([standardPreferences boolForKey:MAPref_ShouldSaveFeedSourceBackup]) {
                BOOL isDirectory = YES;
                NSFileManager *defaultManager = [NSFileManager defaultManager];
                if ([defaultManager fileExistsAtPath:feedSourcePath isDirectory:&isDirectory] && !isDirectory) {
                    NSString * backupPath = [feedSourcePath stringByAppendingPathExtension:@"bak"];
                    if (![defaultManager fileExistsAtPath:backupPath] || [defaultManager removeItemAtPath:backupPath error:NULL]) {  // Remove any old backup first
                        [defaultManager moveItemAtPath:feedSourcePath toPath:backupPath error:NULL];
                    }
                }
            }

            [receivedData writeToFile:feedSourcePath options:NSAtomicWrite error:NULL];
        }

        // Create a new rich XML parser instance that will take care of
        // parsing the XML data we just got.
        if (newFeed == nil || ![newFeed parseRichXML:receivedData]) {
            // Mark the feed as failed
            [self setFolderErrorFlag:folder flag:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                [connectorItem setStatus:NSLocalizedString(@"Error parsing XML data in feed", nil)];
            });
            return;
        }

        // Log number of bytes we received
        NSString * byteCount = [NSByteCountFormatter stringFromByteCount:receivedData.length
                                                             countStyle:NSByteCountFormatterCountStyleFile];
        [connectorItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%@ received",
                                                                                 @"Number of bytes received, e.g. 1 MB received"),
                                     byteCount]];

        if (newFeed.items.count == 0) {
            // Mark the feed as empty
            [self setFolderErrorFlag:folder flag:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                [connectorItem setStatus:NSLocalizedString(@"No articles in feed", nil)];
            });
            return;
        }

        // Extract the latest title and description
        NSString * feedTitle = newFeed.title;
        NSString * feedDescription = newFeed.description;
        NSString * feedLink = newFeed.link;

        // Synthesize feed link if it is missing
        if (feedLink == nil || feedLink.blank) {
            feedLink = folder.feedURL.baseURL;
        }
        if (feedLink != nil && ![feedLink hasPrefix:@"http:"] && ![feedLink hasPrefix:@"https:"]) {
            feedLink = [NSURL URLWithString:feedLink relativeToURL:url].absoluteString;
        }


        // We'll be collecting articles into this array
        NSMutableArray *articleArray = [NSMutableArray array];
        NSMutableArray *articleGuidArray = [NSMutableArray array];

        NSDate *itemAlternativeDate = newFeed.lastModified;
        if (itemAlternativeDate == nil) {
            itemAlternativeDate = [NSDate date];
        }

        // Parse off items.

        for (FeedItem * newsItem in newFeed.items) {
            NSDate * articleDate = newsItem.date;

            NSString * articleGuid = newsItem.guid;

            // This routine attempts to synthesize a GUID from an incomplete item that lacks an
            // ID field. Generally we'll have three things to work from: a link, a title and a
            // description. The link alone is not sufficiently unique and I've seen feeds where
            // the description is also not unique. The title field generally does vary but we need
            // to be careful since separate articles with different descriptions may have the same
            // title. The solution is to use the link and title and build a GUID from those.
            // We add the folderId at the beginning to ensure that items in different feeds do not share a guid.
            if ([articleGuid isEqualToString:@""]) {
                articleGuid = [NSString stringWithFormat:@"%ld-%@-%@", (long)folderId, newsItem.link, newsItem.title];
            }
            // This is a horrible hack for horrible feeds that contain more than one item with the same guid.
            // Bad feeds! I'm talking to you, kerbalstuff.com
            NSUInteger articleIndex = [articleGuidArray indexOfObject:articleGuid];
            if (articleIndex != NSNotFound) {
                // We rebuild complex guids which should eliminate most duplicates
                Article * firstFoundArticle = articleArray[articleIndex];
                if (articleDate == nil) {
                    // first, hack the initial article (which is probably the first loaded / most recent one)
                    NSString * firstFoundArticleNewGuid =
                        [NSString stringWithFormat:@"%ld-%@-%@", (long)folderId, firstFoundArticle.link, firstFoundArticle.title];
                    firstFoundArticle.guid = firstFoundArticleNewGuid;
                    articleGuidArray[articleIndex] = firstFoundArticleNewGuid;
                    // then hack the guid for the item being processed
                    articleGuid = [NSString stringWithFormat:@"%ld-%@-%@", (long)folderId, newsItem.link, newsItem.title];
                } else {
                    // first, hack the initial article (which is probably the first loaded / most recent one)
                    NSString * firstFoundArticleNewGuid =
                        [NSString stringWithFormat:@"%ld-%@-%@-%@", (long)folderId,
                         [NSString stringWithFormat:@"%1.3f", firstFoundArticle.date.timeIntervalSince1970], firstFoundArticle.link,
                         firstFoundArticle.title];
                    firstFoundArticle.guid = firstFoundArticleNewGuid;
                    articleGuidArray[articleIndex] = firstFoundArticleNewGuid;
                    // then hack the guid for the item being processed
                    articleGuid =
                        [NSString stringWithFormat:@"%ld-%@-%@-%@", (long)folderId,
                         [NSString stringWithFormat:@"%1.3f", articleDate.timeIntervalSince1970], newsItem.link, newsItem.title];
                }
            }
            [articleGuidArray addObject:articleGuid];

            // set the article date if it is missing. We'll use the
            // last modified date of the feed and set each article to be 1 second older than the
            // previous one. So the array is effectively newest first.
            if (articleDate == nil) {
                articleDate = itemAlternativeDate;
                itemAlternativeDate = [itemAlternativeDate dateByAddingTimeInterval:-1.0];
            }

            Article * article = [[Article alloc] initWithGuid:articleGuid];
            article.folderId = folderId;
            article.author = newsItem.author;
            article.body = newsItem.feedItemDescription;
            article.title = newsItem.title;
            NSString * articleLink = newsItem.link;
            if (![articleLink hasPrefix:@"http:"] && ![articleLink hasPrefix:@"https:"]) {
                articleLink = [NSURL URLWithString:articleLink relativeToURL:url].absoluteString;
            }
            if (articleLink == nil) {
                articleLink = feedLink;
            }
            article.link = articleLink;
            article.date = articleDate;
            NSString * enclosureLink = newsItem.enclosure;
            if ([enclosureLink isNotEqualTo:@""] && ![enclosureLink hasPrefix:@"http:"] && ![enclosureLink hasPrefix:@"https:"]) {
                enclosureLink = [NSURL URLWithString:enclosureLink relativeToURL:url].absoluteString;
            }
            article.enclosure = enclosureLink;
            if ([enclosureLink isNotEqualTo:@""]) {
                [article setHasEnclosure:YES];
            }
            [articleArray addObject:article];
        }


        // Here's where we add the articles to the database
        if (articleArray.count > 0u) {
            NSArray *guidHistory = [dbManager guidHistoryForFolderId:folderId];
            for (Article * article in articleArray) {
                if ([folder createArticle:article
                              guidHistory:guidHistory] && (article.status == ArticleStatusNew))
                {
                    ++newArticlesFromFeed;
                }
            }
        }


        // A notify is only needed if we added any new articles.
        if (feedTitle != nil  && !feedTitle.blank && [folder.name hasPrefix:[Database untitledFeedFolderName]]) {
            // If there's an existing feed with this title, make ours unique
            // BUGBUG: This duplicates logic in database.m so consider moving it there.
            NSString * oldFeedTitle = feedTitle;
            NSString * newFeedTitle = feedTitle;
            NSUInteger index = 1;

            while (([dbManager folderFromName:newFeedTitle]) != nil) {
                newFeedTitle = [NSString stringWithFormat:@"%@ (%lu)", oldFeedTitle, (unsigned long)index++];
            }

            connectorItem.name = newFeedTitle;
            [dbManager setName:newFeedTitle forFolder:folderId];
        }
        if (feedDescription != nil) {
            [dbManager setDescription:feedDescription forFolder:folderId];
        }
        if (feedLink != nil) {
            [dbManager setHomePage:feedLink forFolder:folderId];
        }

        // Remember the last modified date
        if (lastModifiedString != nil && lastModifiedString.length > 0) {
            [dbManager setLastUpdateString:lastModifiedString forFolder:folderId];
        }
        // Set the last update date for this folder.
        [dbManager setLastUpdate:[NSDate date] forFolder:folderId];


        // Mark the feed as succeeded
        [self setFolderErrorFlag:folder flag:NO];
        [folder clearNonPersistedFlag:VNAFolderFlagBuggySync];
    }

    // Send status to the activity log
    if (newArticlesFromFeed == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [connectorItem setStatus:NSLocalizedString(@"No new articles available", nil)];
        });
    } else {
        NSString * logText = [NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newArticlesFromFeed];
        dispatch_async(dispatch_get_main_queue(), ^{
            connectorItem.status = logText;
        });
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_ArticleListContentChange" object:@(folder.
                                                                                                                                  itemId)];
    }

    // Done with this connection

    // Add to count of new articles so far
    countOfNewArticles += newArticlesFromFeed;

    // If this folder also requires an image refresh, do that
    if ((folder.flags & VNAFolderFlagCheckForImage)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshFavIconForFolder:folder];
        });
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
    const char *scanPtr = data.bytes;
    const char *scanPtrEnd = scanPtr + data.length;

    // Make sure this is HTML otherwise this is likely just valid
    // XML and we can ignore everything else.
    const char *htmlTagPtr = "<html>";
    while (scanPtr < scanPtrEnd && *htmlTagPtr != '\0') {
        if (*scanPtr != ' ') {
            if (tolower(*scanPtr) != *htmlTagPtr) {
                return nil;
            }
            ++htmlTagPtr;
        }
        ++scanPtr;
    }

    // Look for the meta attribute
    const char *metaTag = "<meta ";
    const char *headEndTag = "</head>";
    const char *metaTagPtr = metaTag;
    const char *headEndTagPtr = headEndTag;
    while (scanPtr < scanPtrEnd) {
        if (tolower(*scanPtr) == *metaTagPtr) {
            ++metaTagPtr;
        } else {
            metaTagPtr = metaTag;
            if (tolower(*scanPtr) == *headEndTagPtr) {
                ++headEndTagPtr;
            } else {
                headEndTagPtr = headEndTag;
            }
        }
        if (*headEndTagPtr == '\0') {
            return nil;
        }
        if (*metaTagPtr == '\0') {
            // Now see if this meta tag has http-equiv attribute
            const char *httpEquivAttr = "http-equiv=\"refresh\"";
            const char *httpEquivAttrPtr = httpEquivAttr;
            while (scanPtr < scanPtrEnd && *scanPtr != '>') {
                if (tolower(*scanPtr) == *httpEquivAttrPtr) {
                    ++httpEquivAttrPtr;
                } else if (*scanPtr != ' ') {
                    httpEquivAttrPtr = httpEquivAttr;
                }
                if (*httpEquivAttrPtr == '\0') {
                    // OK. This is our meta tag. Now look for the URL field
                    while (scanPtr < scanPtrEnd - 3 && *scanPtr != '>') {
                        if (tolower(*scanPtr) == 'u' && tolower(*(scanPtr + 1)) == 'r' && tolower(*(scanPtr + 2)) == 'l' &&
                            *(scanPtr + 3) == '=')
                        {
                            const char *urlStart = scanPtr + 4;
                            const char *urlEnd = urlStart;

                            // Finally, gather the URL for the redirect and return it as an
                            // auto-released string.
                            while (urlEnd < scanPtrEnd && *urlEnd != '"' && *urlEnd != ' ' && *urlEnd != '>') {
                                ++urlEnd;
                            }
                            if (urlEnd == scanPtrEnd) {
                                return nil;
                            }
                            return [[NSString alloc] initWithBytes:urlStart length:(urlEnd - urlStart) encoding:NSASCIIStringEncoding];
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
} // getRedirectURL

-(void)syncFinishedForFolder:(Folder *)folder
{
    [self setFolderUpdatingFlag:folder flag:NO];
}

#pragma mark NSURLSession redirection delegate
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(
        NSURLRequest *)newRequest completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    completionHandler(newRequest);
    NSMutableURLRequest *originalRequest = (NSMutableURLRequest *)task.originalRequest;
    if ([originalRequest userInfo] != nil) {
        Folder * folder = (Folder *)[originalRequest userInfo][@"folder"];
        NSInteger type = [[(NSDictionary *)[originalRequest userInfo] valueForKey:@"type"] integerValue];
        if (((NSHTTPURLResponse *)response).statusCode == 301 && folder != nil && type == MA_Refresh_Feed) {
            // We got a permanent redirect from the feed so we probably need to change the feed URL to the new location.
            [self verify301Status:task];
        }
    }
}

// We got a permanent redirect from the feed
// We check if we really need to change the feed URL to a new location
// to avoid issue #380 : https://github.com/ViennaRSS/vienna-rss/issues/380
-(void)verify301Status:(NSURLSessionTask *)task
{
    NSMutableURLRequest *originalRequest = ((NSMutableURLRequest *)(task.originalRequest));
    if (task != nil) {
        // we might have successive redirections for one task
        if ([self.redirect301WaitQueue containsObject:task]) {
            [self.redirect301WaitQueue removeObject:task];
        }
        [self.redirect301WaitQueue addObject:task];
    }

    NSURL * newURL = task.currentRequest.URL;
    if ([newURL.host isEqualToString:originalRequest.URL.host]) {
        [self validate301WaitQueue];
    }


    switch (self.redirect301Status) {
        case HTTP301Unknown: {
            self.redirect301Status = HTTP301Pending;
            // build a test request, assuming that
            // there is no valid reason for
            // www.example.com to be permanently redirected
            // (cf RFC 6761 http://www.iana.org/go/rfc6761)
            NSURL * testURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://www.example.com", originalRequest.URL.scheme]];
            NSMutableURLRequest *testRequest = [NSMutableURLRequest requestWithURL:testURL];
            __weak typeof(self)weakSelf = self;
            [self   addConnection:testRequest
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    if (error) {
                    LOG_EXPR(((NSHTTPURLResponse *)response).allHeaderFields);
                    LOG_EXPR([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                    [weakSelf void301WaitQueue];
                    } else {
                    if (![((NSHTTPURLResponse *)response).URL.host isEqualToString:testRequest.URL.host]) {
                        // we probably have a misconfigured router / proxy
                        // which redirects permanently every site, even www.example.com
                        [weakSelf void301WaitQueue];
                    } else {
                        // we can now assume that 301 redirects we encounter are safe
                        [weakSelf validate301WaitQueue];
                    }
                    }
                }];
        }
        break;

        case HTTP301Pending:
            break;

        case HTTP301Unsafe:
            [self purge301WaitQueue];
            break;

        case HTTP301Safe:
            [self process301WaitQueue];
            break;
    } /* switch */
} /* verify301Status */

-(void)void301WaitQueue
{
    self.redirect301Status = HTTP301Unsafe;
    // we will not consider 301 redirections as permanent for 24 hours
    self.unsafe301RedirectionTimer = [NSTimer scheduledTimerWithTimeInterval:24 * 3600
                                                                      target:self
                                                                    selector:@selector(reset301Status:)
                                                                    userInfo:nil
                                                                     repeats:NO];
    self.riskyIPAddress = [NSHost currentHost].address;
    [self purge301WaitQueue];
}

-(void)purge301WaitQueue
{
    for (id obj in [self.redirect301WaitQueue reverseObjectEnumerator]) {
        NSURLSessionTask *theConnector = (NSURLSessionTask *)obj;
        NSMutableURLRequest * originalRequest = (NSMutableURLRequest *)theConnector.originalRequest;
        [self.redirect301WaitQueue removeObject:obj];
        ActivityItem *connectorItem = ((NSDictionary *)[originalRequest userInfo])[@"log"];
        [connectorItem appendDetail:NSLocalizedString(@"Redirection attempt treated as temporary for safety concern", nil)];
    }
}

-(void)validate301WaitQueue
{
    self.redirect301Status = HTTP301Safe;
    [self process301WaitQueue];
}

-(void)process301WaitQueue
{
    for (id obj in [self.redirect301WaitQueue reverseObjectEnumerator]) {
        NSURLSessionTask *theConnector = (NSURLSessionTask *)obj;
        NSMutableURLRequest * originalRequest = (NSMutableURLRequest *)theConnector.originalRequest;
        [self.redirect301WaitQueue removeObject:obj];
        NSString * theNewURLString = theConnector.originalRequest.URL.absoluteString;
        Folder * theFolder = (Folder *)((NSDictionary *)[originalRequest userInfo])[@"folder"];
        [[Database sharedManager] setFeedURL:theNewURLString forFolder:theFolder.itemId];
        ActivityItem *connectorItem = ((NSDictionary *)[originalRequest userInfo])[@"log"];
        [connectorItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"Feed URL updated to %@",
                                                                                 nil), theNewURLString]];
    }
}

-(void)reset301Status:(NSTimer *)timer
{
    self.redirect301Status = HTTP301Unknown;
    [timer invalidate];
    timer = nil;
}

#pragma mark Network queue management

/* addConnection
 * Add the specified connection to the connections queue
 * that we manage.
 */
-(NSOperation *)addConnection:(NSMutableURLRequest *)urlRequest completionHandler:(void (^)(NSData *data, NSURLResponse *response,
                                                                                            NSError *error))completionHandler
{
    TRVSURLSessionOperation *op =
        [[TRVSURLSessionOperation alloc] initWithSession:self.urlSession request:urlRequest completionHandler:completionHandler];
    NSOperation *completionOperation = [NSBlockOperation blockOperationWithBlock:^{
                                                         if (self->networkQueue.operationCount == 0) {
                                                            [self performSelector:@selector(finishConnectionQueue) withObject:nil afterDelay:0.1];
                                                         }
                                                         [self updateStatus];
                                                     }];
    [completionOperation addDependency:op];
    [[NSOperationQueue mainQueue] addOperation:completionOperation];

    [networkQueue addOperation:op];
    return op;
} // addConnection

/* suspendConnectionsQueue
 * suspend the connections queue that we manage.
 * Useful for managing dependencies inside the queue
 */
-(void)suspendConnectionsQueue
{
    [networkQueue setSuspended:YES];
}

/* resumeConnectionsQueue
 * release the connections queue that we manage,
 * after we suspended it.
 */
-(void)resumeConnectionsQueue
{
    [networkQueue setSuspended:NO];
}

-(BOOL)isConnecting
{
    return networkQueue.operationCount > 0;
}

-(void)updateStatus
{
    if (hasStarted) {
        statusMessageDuringRefresh =
            [NSString stringWithFormat:@"%@: (%lu) - %@", NSLocalizedString(@"Queue", nil), (unsigned long)networkQueue.operationCount,
             NSLocalizedString(@"Refreshing subscriptions…", nil)];
    }
    self.statusMessage = self->statusMessageDuringRefresh;
}

/* finishConnectionQueue
 * this is run on the main thread
 * at the exhaustion of the network queue
 */
-(void)finishConnectionQueue
{
    if (hasStarted && networkQueue.operationCount == 0) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:@"MA_Notify_RefreshStatus" object:nil];
        [nc postNotificationName:@"MA_Notify_ArticleListContentChange" object:nil];
        statusMessageDuringRefresh = NSLocalizedString(@"Refresh completed", nil);
        hasStarted = NO;
        LLog(@"Queue empty!!!");
    } else {
        statusMessageDuringRefresh = @"";
    }
    [self updateStatus];
}

#pragma mark NSURLSession Authentication delegates

-(void)URLSession:(NSURLSession *)session
    task:(NSURLSessionTask *)task
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    }

    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic] ||
        [challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPDigest])
    {
        if ([challenge previousFailureCount] == 3) {
            completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
        } else {
            NSMutableURLRequest *urlRequest = (NSMutableURLRequest *)(task.originalRequest);
            Folder * folder = ((NSDictionary *)[urlRequest userInfo])[@"folder"];
            if (![folder.username isEqualToString:@""]) {
                NSURLCredential *credential = [NSURLCredential credentialWithUser:folder.username
                                                                         password:folder.password
                                                                      persistence:NSURLCredentialPersistenceNone];
                if (credential) {
                    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
                } else {
                    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
                }
            } else {
                if (![authQueue containsObject:folder]) {
                    [authQueue addObject:folder];
                }
                completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
                [self getCredentialsForFolder];
            }
        }
    }
} // URLSession

/* dealloc
 * Clean up after ourselves.
 */
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
