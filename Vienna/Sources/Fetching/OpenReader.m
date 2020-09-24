//
//  OpenReader.m
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011-2018 Vienna contributors (see menu item 'About Vienna' for list of contributors). All rights reserved.
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

#import "OpenReader.h"
#import "URLRequestExtensions.h"
#import "HelperFunctions.h"
#import "Folder.h"
#import "Database.h"
#import "RefreshManager.h"
#import "Preferences.h"
#import "StringExtensions.h"
#import "NSNotificationAdditions.h"
#import "KeyChain.h"
#import "ActivityItem.h"
#import "Article.h"
#import "Debug.h"

static NSString *LoginBaseURL = @"https://%@/accounts/ClientLogin?accountType=GOOGLE&service=reader";
static NSString *ClientName = @"ViennaRSS";

// host specific variables
NSString *openReaderHost;
NSString *username;
NSString *password;
NSString *APIBaseURL;
BOOL hostSendsHexaItemId;
BOOL hostRequiresSParameter;
BOOL hostRequiresHexaForFeedId;
BOOL hostRequiresInoreaderHeaders;

typedef NS_ENUM (NSInteger, OpenReaderStatus) {
    notAuthenticated = 0,
    waitingClientToken,
    missingTToken,
    waitingTToken,
    fullyAuthenticated
};

@interface OpenReader ()

@property (readwrite, copy) NSString *statusMessage;
@property (readwrite, nonatomic) NSUInteger countOfNewArticles;
@property (atomic) NSString *tToken;
@property (atomic) NSString *clientAuthToken;
@property (nonatomic) NSTimer *tTokenTimer;
@property (nonatomic) NSTimer *clientAuthTimer;
@property (nonatomic) dispatch_queue_t asyncQueue;
@property (nonatomic) OpenReaderStatus openReaderStatus;

@end

@implementation OpenReader

# pragma mark initialization

-(instancetype)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
        _openReaderStatus = notAuthenticated;
        _countOfNewArticles = 0;
        openReaderHost = nil;
        username = nil;
        password = nil;
        APIBaseURL = nil;
        _asyncQueue = dispatch_queue_create("uk.co.opencommunity.vienna2.openReaderTasks", DISPATCH_QUEUE_SERIAL);
    }

    return self;
} // init

/* sharedManager
 * Returns the single instance of the Open Reader.
 */
+(OpenReader *)sharedManager
{
    // Singleton
    static OpenReader *_openReader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _openReader = [[OpenReader alloc] init];
        Preferences *prefs = [Preferences standardPreferences];
        if (prefs.syncGoogleReader) {
            openReaderHost = prefs.syncServer;
            APIBaseURL = [NSString stringWithFormat:@"https://%@/reader/api/0/", openReaderHost];
        }
    });
    return _openReader;
}

# pragma mark user authentication and requests preparation

/* prepare a NSMutableURLRequest from an NSURL
 */
-(NSMutableURLRequest *)requestFromURL:(NSURL *)url
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [self addClientTokenToRequest:request];
    [self specificHeadersPrepare:request];
    return request;
}

/* prepare a FormData request from an NSURL and pass the T token
 */
-(NSMutableURLRequest *)authentifiedFormRequestFromURL:(NSURL *)url
{
    NSMutableURLRequest *request = [self requestFromURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [self getTokenForRequest:request];
    return request;
}

-(void)specificHeadersPrepare:(NSMutableURLRequest *)request
{
    if (hostRequiresInoreaderHeaders) {
        [request setValue:[Preferences standardPreferences].syncingAppId forHTTPHeaderField:@"AppID"];
        [request setValue:[Preferences standardPreferences].syncingAppKey forHTTPHeaderField:@"AppKey"];
        [request setValue:@"Mozilla/5.0 (compatible)" forHTTPHeaderField:@"User-Agent"];
    }
}

/* pass the GoogleLogin client authentication token
 */
-(void)addClientTokenToRequest:(NSMutableURLRequest *)clientRequest
{
    static NSOperation * clientAuthOperation;
    dispatch_semaphore_t sema;

    // Do nothing if syncing is disabled in preferences
    if (![Preferences standardPreferences].syncGoogleReader) {
        return;
    }

    if (self.openReaderStatus == fullyAuthenticated || self.openReaderStatus == waitingTToken || self.openReaderStatus == missingTToken) {
        [clientRequest addValue:[NSString stringWithFormat:@"GoogleLogin auth=%@",
                                 self.clientAuthToken] forHTTPHeaderField:@"Authorization"];
        return;     //we are already connected
    } else if ((self.openReaderStatus == waitingClientToken) && clientAuthOperation != nil && !clientAuthOperation.isFinished) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [clientRequest addValue:[NSString stringWithFormat:@"GoogleLogin auth=%@",
                                 self.clientAuthToken] forHTTPHeaderField:@"Authorization"];
        return;
    } else {
        // start first authentication
        self.openReaderStatus = waitingClientToken;

        [self configureForSpecificHost];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:LoginBaseURL, openReaderHost]];
        NSMutableURLRequest *myRequest = [NSMutableURLRequest requestWithURL:url];
        myRequest.HTTPMethod = @"POST";
        [myRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [self specificHeadersPrepare:myRequest];
        [myRequest setPostValue:username forKey:@"Email"];
        [myRequest setPostValue:password forKey:@"Passwd"];

        // semaphore with count equal to zero for synchronizing completion of work
        sema = dispatch_semaphore_create(0);

        clientAuthOperation = [NSBlockOperation blockOperationWithBlock:^(void) {
            NSURLSessionDataTask * task = [[NSURLSession sharedSession] dataTaskWithRequest:myRequest
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    self.openReaderStatus = notAuthenticated;
					if (error) {
						NSString * info = error.localizedDescription;
						[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_GoogleAuthFailed" object:info];
					} else if (((NSHTTPURLResponse *)response).statusCode != 200) {
						NSString * info = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
						[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_GoogleAuthFailed" object:info];
 					} else {         // statusCode 200
						NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
						NSArray *components = [response componentsSeparatedByString:@"\n"];
						for (NSString * item in components) {
							if([item hasPrefix:@"Auth="]) {
								self.clientAuthToken = [item substringFromIndex:5];
								self.openReaderStatus = missingTToken;
								break;
							}
						}

						if (self.openReaderStatus == missingTToken && (self.clientAuthTimer == nil || !self.clientAuthTimer.valid)) {
							//new request every 6 days
							self.clientAuthTimer = [NSTimer scheduledTimerWithTimeInterval:6 * 24 * 3600
																					target:self
																				  selector:@selector(resetAuthentication)
																				  userInfo:nil
																				   repeats:YES];
						}
                    }  // if statusCode 200

                    // Signal that we are done
                    dispatch_semaphore_signal(sema);

            }];
            if (@available(macOS 10.10, *)) {
                task.priority = NSURLSessionTaskPriorityHigh;
            };
            [task resume];

        }];

        self.statusMessage = NSLocalizedString(@"Authenticating on Open Reader", nil);
        clientAuthOperation.queuePriority = NSOperationQueuePriorityHigh;
        [clientAuthOperation start];
        // Now we wait until the task response block will send a signal
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [clientRequest addValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", self.clientAuthToken] forHTTPHeaderField:@"Authorization"];
    }
} // addClientTokenToRequest

/* configures oneself regarding host, username and password
 */
-(void)configureForSpecificHost
{
    // restore from Preferences
    Preferences *prefs = [Preferences standardPreferences];
    username = prefs.syncingUser;
    openReaderHost = prefs.syncServer;
    // default settings
    hostSendsHexaItemId = NO;
    hostRequiresSParameter = NO;
    hostRequiresHexaForFeedId = NO;
    hostRequiresInoreaderHeaders = NO;
    // settings for specific kind of servers
    if ([openReaderHost isEqualToString:@"theoldreader.com"]) {
        hostSendsHexaItemId = YES;
        hostRequiresSParameter = YES;
        hostRequiresHexaForFeedId = YES;
    }
    if ([openReaderHost rangeOfString:@"inoreader.com"].length != 0) {
        hostRequiresInoreaderHeaders = YES;
    }
    // restore from keychain
    password = [KeyChain getGenericPasswordFromKeychain:username serviceName:@"Vienna sync"];
    APIBaseURL = [NSString stringWithFormat:@"https://%@/reader/api/0/", openReaderHost];
} // configureForSpecificHost

/* pass the T token
 */
-(void)getTokenForRequest:(NSMutableURLRequest *)clientRequest
{
    static NSOperation * tTokenOperation;
    dispatch_semaphore_t sema;

    if (self.openReaderStatus == fullyAuthenticated) {
        [clientRequest setPostValue:self.tToken forKey:@"T"];
        return;
    } else {
        // we might get here when status is missingTToken or waitingClientToken or notAuthenticated
        NSMutableURLRequest * myRequest = [self requestFromURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@token", APIBaseURL]]];
        self.openReaderStatus = waitingTToken;
        // semaphore with count equal to zero for synchronizing completion of work
        sema = dispatch_semaphore_create(0);
        tTokenOperation = [NSBlockOperation blockOperationWithBlock:^(void) {
          NSURLSessionDataTask * task = [[NSURLSession sharedSession] dataTaskWithRequest:myRequest
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    NSLog(@"tTokenOperation error for URL %@", myRequest.URL);
                    NSLog(@"Request headers %@", myRequest.allHTTPHeaderFields);
                    NSLog(@"Request body %@", [[NSString alloc] initWithData:myRequest.HTTPBody encoding:NSUTF8StringEncoding]);
                    NSLog(@"Response headers %@", ((NSHTTPURLResponse *)response).allHeaderFields);
                    NSLog(@"Response data %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                    self.tToken = nil;
                    self.openReaderStatus = missingTToken;
                } else {
                    self.tToken = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    self.openReaderStatus = fullyAuthenticated;
                    if (self.tTokenTimer == nil || !self.tTokenTimer.valid) {
                        //tokens expire after 30 minutes : renew them every 25 minutes
                        self.tTokenTimer = [NSTimer scheduledTimerWithTimeInterval:25 * 60
                                                                            target:self
                                                                          selector:@selector(renewTToken)
                                                                          userInfo:nil
                                                                           repeats:YES];
                    }
                }
				// Signal that we are done with the synchronous task
				dispatch_semaphore_signal(sema);
          }];
          if (@available(macOS 10.10, *)) {
              task.priority = NSURLSessionTaskPriorityHigh;
          };
          [task resume];
        }];
        [tTokenOperation start];
        // we wait until the task response block above will send a signal
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [clientRequest setPostValue:self.tToken forKey:@"T"];
    } // missingTToken or waitingClientToken or notAuthenticated
} // getTokenForRequest

-(void)renewTToken
{
    self.openReaderStatus = missingTToken;
    self.tToken = nil;
    [self getTokenForRequest:nil];
}

-(void)clearAuthentication
{
    self.openReaderStatus = notAuthenticated;
    self.clientAuthToken = nil;
    self.tToken = nil;
}

-(void)resetAuthentication
{
    [self clearAuthentication];
    [self addClientTokenToRequest:nil];
}

# pragma mark default handlers

// default handler for didFailSelector
-(void)requestFailed:(NSMutableURLRequest *)request response:(NSURLResponse *)response error:(NSError *)error
{
    LLog(@"Failed on request %@", request.URL);
    LOG_EXPR(error);
    LOG_EXPR(request.allHTTPHeaderFields);
    LOG_EXPR(((NSHTTPURLResponse *)response).allHeaderFields);
    if (error.code == NSURLErrorUserAuthenticationRequired) {   //Error caused by lack of authentication
        [self clearAuthentication];
    }
}

// default handler for didFinishSelector
-(void)requestFinished:(NSMutableURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data
{
    NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (![requestResponse isEqualToString:@"OK"]) {
        LLog(@"Error (response status code %ld) on request %@", (long)((NSHTTPURLResponse *)response).statusCode, request.URL);
        LOG_EXPR(request.allHTTPHeaderFields);
        LOG_EXPR([[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
        LOG_EXPR(((NSHTTPURLResponse *)response).allHeaderFields);
        LOG_EXPR(requestResponse);
    }
}

# pragma mark status accessors

-(BOOL)isReady
{
    return (self.openReaderStatus == fullyAuthenticated && self.tTokenTimer != nil);
}

/* resetCountOfNewArticles
 */
-(void)resetCountOfNewArticles
{
    self.countOfNewArticles=0;
}

# pragma mark operations

-(void)refreshFeed:(Folder *)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit
{
    //This is a workaround throw a BAD folderupdate value on DB
    NSString *folderLastUpdateString = ignoreLimit ? @"0" : thisFolder.lastUpdateString;
    if (folderLastUpdateString == nil
        || [folderLastUpdateString isEqualToString:@""]
        || [folderLastUpdateString isEqualToString:@"(null)"])
    {
        folderLastUpdateString = @"0";
    }

    NSString *itemsLimitation;
    if (ignoreLimit) {
        itemsLimitation = @"&n=10000";         //just stay reasonable…
    } else {
        //Note : we don't set "r" (sorting order) here.
        //But according to some documentation, Google Reader and TheOldReader
        //need "r=o" order to make the "ot" time limitation work.
        //In fact, Vienna used successfully "r=n" with Google Reader.
        @try {
            double limit = folderLastUpdateString.doubleValue - 15*60;
            if (limit < 0.0f) {
                limit = 0.0;
            }
            NSString *startEpoch = @(limit).stringValue;
            itemsLimitation = [NSString stringWithFormat:@"&ot=%@&n=1000", startEpoch];
        } @catch (NSException *exception) {
            itemsLimitation = @"&n=1000";
        }
        if (thisFolder.flags & VNAFolderFlagBuggySync) {
            itemsLimitation = @"&n=1000";
        }
    }

    NSString *feedIdentifier = thisFolder.remoteId;
    if (feedIdentifier == nil || ![feedIdentifier hasPrefix:@"feed/"]) {
            return;
    }

    NSURL *refreshFeedUrl =
        [NSURL URLWithString:[NSString stringWithFormat:
                              @"%@stream/contents/%@?client=%@&comments=false&likes=false%@&output=json",
                              APIBaseURL,
                              [OpenReader escapeFeedId:feedIdentifier], ClientName, itemsLimitation]];

    NSMutableURLRequest *request = [self requestFromURL:refreshFeedUrl];
    [request setUserInfo:
        @{ @"folder": thisFolder, @"log": aItem, @"lastupdatestring": folderLastUpdateString, @"type": @(MA_Refresh_GoogleFeed) }];

    // Request id's of unread items
    NSString *args =
        [NSString stringWithFormat:@"?client=%@&s=%@&xt=user/-/state/com.google/read&n=1000&output=json", ClientName,
         [OpenReader escapeFeedId:feedIdentifier]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", APIBaseURL, @"stream/items/ids", args]];
    NSMutableURLRequest *request2 = [self requestFromURL:url];
    [request2 setUserInfo:@{ @"folder": thisFolder, @"log": aItem }];

    // Request id's of starred items
    // Note: Inoreader requires syntax "it=user/-/state/...", while TheOldReader ignores it and requires "s=user/-/state/..."
    NSString *starredSelector;
    if (hostRequiresSParameter) {
        starredSelector = @"s=user/-/state/com.google/starred";
    } else {
        starredSelector = @"it=user/-/state/com.google/starred";
    }

    NSString *args3 =
        [NSString stringWithFormat:@"?client=%@&s=%@&%@&n=1000&output=json", ClientName,
         [OpenReader escapeFeedId:feedIdentifier], starredSelector];
    NSURL *url3 = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", APIBaseURL, @"stream/items/ids", args3]];
    NSMutableURLRequest *request3 = [self requestFromURL:url3];
    [request3 setUserInfo:@{ @"folder": thisFolder, @"log": aItem }];

    __weak typeof(self) weakSelf = self;
    NSOperation * op =
        [[RefreshManager sharedManager] addConnection:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf feedRequestFailed:request response:response error:error];
            } else {
                [weakSelf feedRequestDone:request response:response data:data];
            }
    }];

    [[RefreshManager sharedManager] suspendConnectionsQueue];

    NSOperation * op2 =
        [[RefreshManager sharedManager] addConnection:request2 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:request2 response:response error:error];
            } else {
                [weakSelf readRequestDone:request2 response:response data:data];
            }
    }];
    [op2 addDependency:op];

    NSOperation * op3 =
        [[RefreshManager sharedManager] addConnection:request3 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:request3 response:response error:error];
            } else {
                [weakSelf starredRequestDone:request2 response:response data:data];
            }
    }];
    [op3 addDependency:op2];

    [[RefreshManager sharedManager] resumeConnectionsQueue];

} // refreshFeed

// callback : handler for timed out feeds, etc...
-(void)feedRequestFailed:(NSMutableURLRequest *)request response:(NSURLResponse *)response error:(NSError *)error
{
    LLog(@"Open Reader feed request Failed : %@", request.URL);
    LOG_EXPR(error);
    LOG_EXPR(request.allHTTPHeaderFields);
    LOG_EXPR([[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
    LOG_EXPR(((NSHTTPURLResponse *)response).allHeaderFields);
    ActivityItem *aItem = ((NSDictionary *)[request userInfo])[@"log"];
    Folder *refreshedFolder = ((NSDictionary *)[request userInfo])[@"folder"];

    [aItem appendDetail:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Error", nil), error.localizedDescription ]];
    [aItem setStatus:NSLocalizedString(@"Error", nil)];
    [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
    [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
    [refreshedFolder clearNonPersistedFlag:VNAFolderFlagSyncedOK]; // get ready for next request
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated"
                                                                        object:@(refreshedFolder.itemId)];
}

// callback
-(void)feedRequestDone:(NSMutableURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data
{
    dispatch_async(self.asyncQueue, ^() {
        // TODO : refactor code to separate feed refresh code and UI

        ActivityItem *aItem = ((NSDictionary *)[request userInfo])[@"log"];
        Folder *refreshedFolder = ((NSDictionary *)[request userInfo])[@"folder"];

        if (((NSHTTPURLResponse *)response).statusCode == 404) {
            [aItem appendDetail:NSLocalizedString(@"Error: Feed not found!", nil)];
            dispatch_async(dispatch_get_main_queue(), ^{
                [aItem setStatus:NSLocalizedString(@"Error", nil)];
            });
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
            [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
        } else if (((NSHTTPURLResponse *)response).statusCode == 200) {
            // reset unread statuses in cache : we will receive in -ReadRequestDone: the updated list of unreads
            [refreshedFolder markArticlesInCacheRead];
            NSDictionary *subscriptionsDict;
            NSError *jsonError;
            subscriptionsDict = [NSJSONSerialization JSONObjectWithData:data
                                                                options:NSJSONReadingMutableContainers
                                                                  error:&jsonError];
            NSString *folderLastUpdateString = [subscriptionsDict[@"updated"] stringValue];
            if (folderLastUpdateString == nil
                || [folderLastUpdateString isEqualToString:@""]
                || [folderLastUpdateString isEqualToString:@"(null)"])
            {
                LOG_EXPR(request.URL);
                NSLog(@"Feed name: %@", subscriptionsDict[@"title"]);
                NSLog(@"Last Check: %@", ((NSDictionary *)[request userInfo])[@"lastupdatestring"]);
                NSLog(@"Last update: %@", folderLastUpdateString);
                NSLog(@"Found %lu items", (unsigned long)[subscriptionsDict[@"items"] count]);
                LOG_EXPR(subscriptionsDict);
                LOG_EXPR([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                ALog(@"Error !!! Incoherent data !");
                //keep the previously recorded one
                folderLastUpdateString = ((NSDictionary *)[request userInfo])[@"lastupdatestring"];
            }

            // Log number of bytes we received
            NSString *byteCount = [NSByteCountFormatter stringFromByteCount:data.length
                                                                 countStyle:NSByteCountFormatterCountStyleFile];
            [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%@ received",
                                                                             @"Number of bytes received, e.g. 1 MB received"), byteCount]];

            NSMutableArray *articleArray = [NSMutableArray array];

            for (NSDictionary *newsItem in (NSArray *)subscriptionsDict[@"items"]) {
                NSDate *articleDate = [NSDate dateWithTimeIntervalSince1970:[newsItem[@"published"] doubleValue]];
                NSString *articleGuid = newsItem[@"id"];
                Article *article = [[Article alloc] initWithGuid:articleGuid];
                article.folderId = refreshedFolder.itemId;

                if (newsItem[@"author"] != nil) {
                    article.author = newsItem[@"author"];
                } else {
                    article.author = @"";
                }

                if (newsItem[@"content"] != nil) {
                    article.body = newsItem[@"content"][@"content"];
                } else if (newsItem[@"summary"] != nil) {
                    article.body = newsItem[@"summary"][@"content"];
                } else {
                    article.body = @"Not available…";
                }

                for (NSString *category in (NSArray *)newsItem[@"categories"]) {
                    if ([category hasSuffix:@"/read"]) {
                        [article markRead:YES];
                    }
                    if ([category hasSuffix:@"/starred"]) {
                        [article markFlagged:YES];
                    }
                    if ([category hasSuffix:@"/kept-unread"]) {
                        [article markRead:NO];
                    }
                }

                if (newsItem[@"title"] != nil) {
                    article.title = [newsItem[@"title"] summaryTextFromHTML];
                } else {
                    article.title = @"";
                }

                if ([newsItem[@"alternate"] count] != 0) {
                    article.link = newsItem[@"alternate"][0][@"href"];
                } else {
                    article.link = refreshedFolder.feedURL;
                }

                article.date = articleDate;

                if ([newsItem[@"enclosure"] count] != 0) {
                    article.enclosure = newsItem[@"enclosure"][0][@"href"];
                } else {
                    article.enclosure = @"";
                }

                if ([article.enclosure isNotEqualTo:@""]) {
                    [article setHasEnclosure:YES];
                }

                [articleArray addObject:article];
            }

            Database *dbManager = [Database sharedManager];
            NSInteger newArticlesFromFeed = 0;

            // Here's where we add the articles to the database
            if (articleArray.count > 0) {
                NSArray *guidHistory = [dbManager guidHistoryForFolderId:refreshedFolder.itemId];

                for (Article *article in articleArray) {
                    if ([refreshedFolder createArticle:article guidHistory:guidHistory] &&
                        (article.status == ArticleStatusNew))
                    {
                        newArticlesFromFeed++;
                    }
                }

                // Set the last update date for this folder.
                [dbManager setLastUpdate:[NSDate date] forFolder:refreshedFolder.itemId];
            }

            if (folderLastUpdateString == nil
                || [folderLastUpdateString isEqualToString:@""]
                || [folderLastUpdateString isEqualToString:@"(null)"])
            {
                folderLastUpdateString = @"0";
            }

            // Set the last update date given by the Open Reader server for this folder.
            [dbManager setLastUpdateString:folderLastUpdateString forFolder:refreshedFolder.itemId];
            // Set the HTML homepage for this folder.
            // a legal JSON string can have, as its outer "container", either an array or a dictionary/"object"
            if ([subscriptionsDict[@"alternate"] isKindOfClass:[NSArray class]]) {
                [dbManager setHomePage:subscriptionsDict[@"alternate"][0][@"href"]
                             forFolder:refreshedFolder.itemId];
            } else {
                [dbManager setHomePage:subscriptionsDict[@"alternate"][@"href"]
                             forFolder:refreshedFolder.itemId];
            }

            // Add to count of new articles so far
            self.countOfNewArticles += newArticlesFromFeed;

            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagError];
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagBuggySync];
            // Send status to the activity log
            if (newArticlesFromFeed == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [aItem setStatus:NSLocalizedString(@"No new articles available", nil)];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    aItem.status = [NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), (int)newArticlesFromFeed];
                });
            }
        } else { //other HTTP status response...
            [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil),
                                 (int)((NSHTTPURLResponse *)response).statusCode]];
            LOG_EXPR(request.URL);
            LOG_EXPR(request.allHTTPHeaderFields);
            LOG_EXPR([[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
            LOG_EXPR(((NSHTTPURLResponse *)response).allHeaderFields);
            LOG_EXPR([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            dispatch_async(dispatch_get_main_queue(), ^{
                [aItem setStatus:NSLocalizedString(@"Error", nil)];
            });
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
            [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagSyncedOK];
        }
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated"
                                                                            object:@(refreshedFolder.itemId)];
    });     //block for dispatch_async
} // feedRequestDone

// callback
-(void)readRequestDone:(NSMutableURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data
{
    dispatch_async(self.asyncQueue, ^() {
        Folder *refreshedFolder = ((NSDictionary *)[request userInfo])[@"folder"];
        ActivityItem *aItem = ((NSDictionary *)[request userInfo])[@"log"];
        if (((NSHTTPURLResponse *)response).statusCode == 200) {
            @try {
                NSArray *itemRefsArray;
                NSError *jsonError;
                itemRefsArray = [NSJSONSerialization JSONObjectWithData:data
                                                                options:NSJSONReadingMutableContainers
                                                                  error:&jsonError][@"itemRefs"];
                NSMutableArray *guidArray = [NSMutableArray arrayWithCapacity:itemRefsArray.count];
                for (NSDictionary *itemRef in itemRefsArray) {
                    NSString *guid;
                    if (hostSendsHexaItemId) {
                        guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%@", itemRef[@"id"]];
                    } else {
                        // as described in http://code.google.com/p/google-reader-api/wiki/ItemId
                        // the short version of id is a base 10 signed integer ; the long version includes a 16 characters base 16 representation
                        NSInteger shortId = [itemRef[@"id"] integerValue];
                        guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%016qx", (long long)shortId];
                    }

                    [guidArray addObject:guid];
                    // now, mark relevant articles unread
                    [[refreshedFolder articleFromGuid:guid] markRead:NO];
                }

                [[Database sharedManager] markUnreadArticlesFromFolder:refreshedFolder guidArray:guidArray];
                // reset starred statuses in cache : we will receive in -StarredRequestDone: the updated list
                for (Article *article in refreshedFolder.articles) {
                    [article markFlagged:NO];
                }
            } @catch (NSException *exception) {
                [aItem appendDetail:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Error", nil), exception]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [aItem setStatus:NSLocalizedString(@"Error", nil)];
                });
                [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
                [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:@(
                     refreshedFolder.itemId)];
                return;
            } // try/catch


            // If this folder also requires an image refresh, add that
            if (refreshedFolder.flags & VNAFolderFlagCheckForImage) {
                [[RefreshManager sharedManager] refreshFavIconForFolder:refreshedFolder];
            }
        } else { //response status other than OK (200)
            [aItem appendDetail:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Error", nil),
                                    [NSHTTPURLResponse localizedStringForStatusCode:((NSHTTPURLResponse *)response).statusCode]]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [aItem setStatus:NSLocalizedString(@"Error", nil)];
            });
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
            [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
        }
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated"
                                                                            object:@(refreshedFolder.itemId)];
    });     //block for dispatch_async
} // readRequestDone

// callback
-(void)starredRequestDone:(NSMutableURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data
{
    dispatch_async(self.asyncQueue, ^() {
        Folder *refreshedFolder = ((NSDictionary *)[request userInfo])[@"folder"];
        ActivityItem *aItem = ((NSDictionary *)[request userInfo])[@"log"];
        if (((NSHTTPURLResponse *)response).statusCode == 200) {
            @try {
                NSArray *itemRefsArray;
                NSError *jsonError;
                itemRefsArray = [NSJSONSerialization JSONObjectWithData:data
                                                                options:NSJSONReadingMutableContainers
                                                                  error:&jsonError][@"itemRefs"];
                NSMutableArray *guidArray = [NSMutableArray arrayWithCapacity:itemRefsArray.count];
                for (NSDictionary *itemRef in itemRefsArray) {
                    NSString *guid;
                    if (hostSendsHexaItemId) {
                        guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%@", itemRef[@"id"]];
                    } else {
                        // as described in http://code.google.com/p/google-reader-api/wiki/ItemId
                        // the short version of id is a base 10 signed integer ; the long version includes a 16 characters base 16 representation
                        NSInteger shortId = [itemRef[@"id"] integerValue];
                        guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%016qx", (long long)shortId];
                    }
                    [guidArray addObject:guid];
                    [[refreshedFolder articleFromGuid:guid] markFlagged:YES];
                }
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_ArticleListContentChange" object:@(
                     refreshedFolder.itemId)];

                [[Database sharedManager] markStarredArticlesFromFolder:refreshedFolder guidArray:guidArray];

                [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
            } @catch (NSException *exception) {
                [aItem appendDetail:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Error", nil), exception]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [aItem setStatus:NSLocalizedString(@"Error", nil)];
                });
                [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
                [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
            } // try/catch
        } else { //response status other than OK (200)
            [aItem appendDetail:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Error", nil),
                                    [NSHTTPURLResponse localizedStringForStatusCode:((NSHTTPURLResponse *)response).statusCode]]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [aItem setStatus:NSLocalizedString(@"Error", nil)];
            });
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
            [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
        }
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated"
                                                                            object:@(refreshedFolder.itemId)];
    });     //block for dispatch_async
} // starredRequestDone

-(void)loadSubscriptions
{
    [[RefreshManager sharedManager] suspendConnectionsQueue];
    NSMutableURLRequest *subscriptionRequest =
        [self requestFromURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/list?client=%@&output=json", APIBaseURL,
                                                   ClientName]]];
    __weak typeof(self) weakSelf = self;
    NSOperation * subscriptionOperation = [[RefreshManager sharedManager] addConnection:subscriptionRequest
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:subscriptionRequest response:response error:error];
            } else {
                [weakSelf subscriptionsRequestDone:subscriptionRequest response:response data:data];
            }
        }
    ];

    NSMutableURLRequest *unreadCountRequest =
        [self requestFromURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@unread-count?client=%@&output=json&allcomments=false",
                                                   APIBaseURL,
                                                   ClientName]]];
    self.unreadCountOperation = [[RefreshManager sharedManager] addConnection:unreadCountRequest
        completionHandler:^(NSData *data1, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:unreadCountRequest response:response error:error];
            } else {
                [weakSelf unreadCountDone:unreadCountRequest response:response data:data1];
            }
            weakSelf.statusMessage = @"";
        }
    ];
    [self.unreadCountOperation addDependency:subscriptionOperation];
    [[RefreshManager sharedManager] resumeConnectionsQueue];
    self.statusMessage = NSLocalizedString(@"Fetching Open Reader Subscriptions…", nil);
} // loadSubscriptions

// callback 1  to loadSubscriptions
-(void)subscriptionsRequestDone:(NSMutableURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data
{
    NSDictionary *subscriptionsDict;
    NSError *jsonError;
    subscriptionsDict = [NSJSONSerialization JSONObjectWithData:data
                                                        options:NSJSONReadingMutableContainers
                                                          error:&jsonError];
    NSMutableArray *localFeeds = [NSMutableArray array];
    NSMutableArray *remoteFeeds = [NSMutableArray array];
    Database * db = [Database sharedManager];
    NSArray *localFolders = db.arrayOfAllFolders;

    for (Folder *f in localFolders) {
        if (f.isOpenReaderFolder && ![f.remoteId isEqualToString:@"0"]) {
            [localFeeds addObject:f.remoteId];
        }
    }

    for (NSDictionary *feed in subscriptionsDict[@"subscriptions"]) {
        NSString *feedID = feed[@"id"];
        if (feedID == nil || ![feedID hasPrefix:@"feed/"]) {
            break;
        }
        NSString *feedURL = feed[@"url"];
        if (!feedURL) {
            feedURL = [feedID stringByReplacingOccurrencesOfString:@"feed/" withString:@"" options:0 range:NSMakeRange(0, 5)];
        }

        NSString *folderName = nil;

        NSArray *categories = feed[@"categories"];
        for (NSDictionary *category in categories) {
            if (category[@"label"]) {
                NSString *label = category[@"label"];
                NSArray *folderNames = [label componentsSeparatedByString:@" — "];
                folderName = folderNames.lastObject;
                // NNW nested folder char: —

                NSMutableArray *params = [NSMutableArray arrayWithObjects:[folderNames mutableCopy], @(VNAFolderTypeRoot), nil];
                [self createFolders:params];
                break;                 //In case of multiple labels, we retain only the first one
            }
        }

        NSString *rssTitle = @"";
        if (feed[@"title"]) {
            rssTitle = feed[@"title"];
        }
        if (![localFeeds containsObject:feedID]) {
        // legacy search in stored URLs
            NSString *legacyKey;
            if (hostRequiresHexaForFeedId) {                     // TheOldReader
                NSString *identifier =
                  [feedID stringByReplacingOccurrencesOfString:@"feed/" withString:@"" options:0 range:NSMakeRange(0, 5)];
                legacyKey = [NSString stringWithFormat:@"https://%@/reader/public/atom/%@", openReaderHost, identifier];
            } else {
                legacyKey = feedURL;
            }
            Folder *f = [db folderFromFeedURL:legacyKey];
            if (f && f.isOpenReaderFolder) {         // exists already, but we didn't store the remoteId
                [db setRemoteId:feedID forFolder:f.itemId];
                [db setFeedURL:feedURL forFolder:f.itemId];
            } else {
                // we need to create
                // folderName could be nil
                NSArray *params = folderName ? @[feedID, feedURL, rssTitle, folderName] : @[feedID, feedURL, rssTitle];
                [self createNewSubscription:params];
            }
        } else {
            // the feed is already known
            // set HomePage and other infos if they are available
            NSString *homePageURL = feed[@"htmlUrl"];
            for (Folder *localFolder in localFolders) {
                if (localFolder.isOpenReaderFolder && [localFolder.remoteId isEqualToString:feedID]) {
                    NSInteger nativeId = localFolder.itemId;
                    [db setFeedURL:feedURL forFolder:nativeId];
                    if (homePageURL) {
                        [db setHomePage:homePageURL forFolder:nativeId];
                    }
                    if ([db folderFromName:rssTitle] == nil) { // no conflict
                        [db setName:rssTitle forFolder:nativeId];
                    }
                    NSInteger neededParentId = [db folderFromName:folderName].itemId;
                    if (neededParentId == 0) {
                        neededParentId = VNAFolderTypeRoot;
                    }
                    if (localFolder.parentId != neededParentId) {
                        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_OpenReaderFolderChange"
                                                              object:@[ [NSNumber numberWithInteger:nativeId],
                                                                        [NSNumber numberWithInteger:neededParentId],
                                                                        [NSNumber numberWithInteger:0]]];
                    }
                    break;
                }
            }
        }

        [remoteFeeds addObject:feedID];
    }

    if (subscriptionsDict[@"subscriptions"] != nil) { // detect probable authentication error
        //check if we have a folder which is not registered as a Open Reader feed
        for (Folder *f in localFolders) {
            if (f.isOpenReaderFolder) {
             	if ([remoteFeeds containsObject:f.remoteId]  && [f.remoteId hasPrefix:@"feed/"]) {
             		[f setNonPersistedFlag:VNAFolderFlagSyncedOK];
            	} else {
                	[[Database sharedManager] deleteFolder:f.itemId];
            	}
            }
        }
    }
} // subscriptionsRequestDone

// callback 2 to loadSubscriptions
-(void)unreadCountDone:(NSMutableURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data
{
    NSDictionary *unreadDict;
    NSError *jsonError;
    unreadDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    for (NSDictionary *feed in unreadDict[@"unreadcounts"]) {
        NSString *feedID = feed[@"id"];
        if ([feedID hasPrefix:@"feed/"]) {
            Folder *folder = [[Database sharedManager] folderFromRemoteId:feedID];
            if (folder) {
                NSInteger remoteCount = ((NSString *)feed[@"count"]).intValue;
                NSInteger localCount = folder.unreadCount;
                NSInteger remoteTimestamp = ((NSString *)feed[@"newestItemTimestampUsec"]).longLongValue / 1000000; // convert in truncated seconds
                NSString *folderLastUpdateString = folder.lastUpdateString;
                if (folderLastUpdateString == nil || [folderLastUpdateString isEqualToString:@""] ||
                    [folderLastUpdateString isEqualToString:@"(null)"])
                {
                    folderLastUpdateString = @"0";
                }
                NSInteger localTimestamp = folderLastUpdateString.longLongValue;
                if (remoteTimestamp > localTimestamp || remoteCount != localCount) {
                    // discrepancy between local feed and remote OpenReader server
                    [folder clearNonPersistedFlag:VNAFolderFlagSyncedOK];
                }
            }
        }
    }
} // unreadCountDone

-(void)subscribeToFeed:(NSString *)feedURL withLabel:(NSString *)label
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/quickadd?client=%@", APIBaseURL, ClientName]];

    NSMutableURLRequest *request = [self authentifiedFormRequestFromURL:url];
    [request setPostValue:feedURL forKey:@"quickadd"];
    [request setInUserInfo:label  forKey:@"label"];
    __weak typeof(self) weakSelf = self;
    [[RefreshManager sharedManager] addConnection:request
        completionHandler :^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:request response:response error:error];
            } else {
                [weakSelf subscribeToFeedDone:request response:response data:data];
            }
        }
    ];
}

-(void)subscribeToFeedDone:(NSMutableURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data
{
    NSDictionary *responseDict;
    NSError *jsonError;
    responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    NSString *label = ((NSDictionary *)[request userInfo])[@"label"];
    NSString * feedIdentifier = responseDict[@"streamId"];
    if (feedIdentifier) {
        if (label) {
            [self setFolderLabel:label forFeed:feedIdentifier set:TRUE];
        }
	    [self loadSubscriptions];
    }
}

-(void)unsubscribeFromFeedIdentifier:(NSString *)feedIdentifier
{
    NSURL *unsubscribeURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit", APIBaseURL]];
    NSMutableURLRequest *myRequest = [self authentifiedFormRequestFromURL:unsubscribeURL];
    [myRequest setPostValue:@"unsubscribe" forKey:@"ac"];
    [myRequest setPostValue:feedIdentifier forKey:@"s"];
    __weak typeof(self) weakSelf = self;
    [[RefreshManager sharedManager] addConnection:myRequest
        completionHandler :^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:myRequest response:response error:error];
            } else {
                [weakSelf requestFinished:myRequest response:response data:data];
            }
        }
    ];
}

/* setFolderLabel:forFeed:set:
 * add or remove a label (folder name) to a newsfeed
 * set parameter : TRUE => add ; FALSE => remove
 */
-(void)setFolderLabel:(NSString *)folderName forFeed:(NSString *)feedIdentifier set:(BOOL)flag
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@", APIBaseURL, ClientName]];

    NSMutableURLRequest *request = [self authentifiedFormRequestFromURL:url];
    [request setPostValue:@"edit" forKey:@"ac"];
    [request setPostValue:feedIdentifier forKey:@"s"];
    [request setPostValue:[NSString stringWithFormat:@"user/-/label/%@", folderName] forKey:flag ? @"a" : @"r"];
    __weak typeof(self) weakSelf = self;
    [[RefreshManager sharedManager] addConnection:request
        completionHandler :^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:request response:response error:error];
            } else {
                [weakSelf requestFinished:request response:response data:data];
            }
        }
    ];
}

/* setFolderTitle:forFeed:
 * set title of a newsfeed
 */
-(void)setFolderTitle:(NSString *)folderName forFeed:(NSString *)feedIdentifier
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@", APIBaseURL, ClientName]];

    NSMutableURLRequest *request = [self authentifiedFormRequestFromURL:url];
    [request setPostValue:@"edit" forKey:@"ac"];
    [request setPostValue:feedIdentifier forKey:@"s"];
    [request setPostValue:folderName forKey:@"t"];
    __weak typeof(self) weakSelf = self;
    [[RefreshManager sharedManager] addConnection:request
        completionHandler :^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:request response:response error:error];
            } else {
                [weakSelf requestFinished:request response:response data:data];
            }
        }
    ];
}

-(void)markRead:(Article *)article readFlag:(BOOL)flag
{
    NSURL *markReadURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@edit-tag", APIBaseURL]];
    NSMutableURLRequest *myRequest = [self authentifiedFormRequestFromURL:markReadURL];
    if (flag) {
        [myRequest setPostValue:@"user/-/state/com.google/read" forKey:@"a"];
    } else {
        [myRequest setPostValue:@"user/-/state/com.google/read" forKey:@"r"];
    }
    [myRequest setPostValue:@"true" forKey:@"async"];
    [myRequest setPostValue:article.guid forKey:@"i"];
    [myRequest addInfoFromDictionary:@{ @"article": article, @"readFlag": @(flag) }];
    __weak typeof(self) weakSelf = self;
    [[RefreshManager sharedManager] addConnection:myRequest
        completionHandler :^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:myRequest response:response error:error];
            } else {
                [weakSelf markReadDone:myRequest response:response data:data];
            }
        }
    ];
} // markRead

// callback : we check if the server did confirm the read status change
-(void)markReadDone:(NSMutableURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data
{
    NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([requestResponse isEqualToString:@"OK"]) {
        Article *article = ((NSDictionary *)[request userInfo])[@"article"];
        BOOL readFlag = [[((NSDictionary *)[request userInfo]) valueForKey:@"readFlag"] boolValue];
        [[Database sharedManager] markArticleRead:article.folderId guid:article.guid isRead:readFlag];
        [article markRead:readFlag];
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:@(article.folderId)];
        [nc postNotificationOnMainThreadWithName:@"MA_Notify_ArticleListStateChange" object:@(article.folderId)];
    }
}

-(void)markAllReadInFolder:(Folder *)folder
{
    NSURL *markReadURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@mark-all-as-read", APIBaseURL]];
    NSMutableURLRequest *request = [self authentifiedFormRequestFromURL:markReadURL];
    [request setUserInfo: @{ @"folder": folder}];
    NSString *feedIdentifier = folder.remoteId;
    [request setPostValue:feedIdentifier forKey:@"s"];
    NSString *folderLastUpdateString = folder.lastUpdateString;
    //This is a workaround throw a BAD folderupdate value on DB
    if (folderLastUpdateString == nil || [folderLastUpdateString isEqualToString:@""] ||
        [folderLastUpdateString isEqualToString:@"(null)"])
    {
        folderLastUpdateString = @"0";
    }
    NSInteger localTimestamp = (folderLastUpdateString.longLongValue +1)* 1000000 ; // next second converted to microseconds
    NSString * microsecondsUpdateString = @(localTimestamp).stringValue; // string value of NSNumber
    [request setPostValue:microsecondsUpdateString forKey:@"ts"];
    __weak typeof(self) weakSelf = self;
    [[RefreshManager sharedManager] addConnection:request
		completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			if (error) {
			[weakSelf requestFailed:request response:response error:error];
			} else {
			[weakSelf markAllReadDone:request response:response data:data];
			}
		}
    ];
} // markAllReadInFolder

// callback : we check if the server did confirm the read status change
-(void)markAllReadDone:(NSMutableURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data
{
    NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([requestResponse isEqualToString:@"OK"]) {
        Folder *folder = ((NSDictionary *)[request userInfo])[@"folder"];
        [[Database sharedManager] markFolderRead:folder.itemId];
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationOnMainThreadWithName:@"MA_Notify_ArticleListStateChange" object:@(folder.itemId)];
    }
}

-(void)markStarred:(Article *)article starredFlag:(BOOL)flag
{
    NSURL *markStarredURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@edit-tag", APIBaseURL]];
    NSMutableURLRequest *myRequest = [self authentifiedFormRequestFromURL:markStarredURL];
    if (flag) {
        [myRequest setPostValue:@"user/-/state/com.google/starred" forKey:@"a"];
    } else {
        [myRequest setPostValue:@"user/-/state/com.google/starred" forKey:@"r"];
    }
    [myRequest setPostValue:@"true" forKey:@"async"];
    [myRequest setPostValue:article.guid forKey:@"i"];
    __weak typeof(self) weakSelf = self;
    [[RefreshManager sharedManager] addConnection:myRequest
        completionHandler :^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:myRequest response:response error:error];
            } else {
                [weakSelf requestFinished:myRequest response:response data:data];
            }
        }
    ];
} // markStarred

-(void)createNewSubscription:(NSArray *)params
{
    NSInteger underFolder = VNAFolderTypeRoot;
    NSString *feedID = params[0];
    NSString *feedURL = params[1];
    NSString *rssTitle = [NSString stringWithFormat:@""];
    Database *db = [Database sharedManager];

    if (params.count > 2) {
        rssTitle = params[2];
        if (params.count > 3) {
            NSString *folderName = params[3];
            Folder *folder = [db folderFromName:folderName];
            underFolder = folder.itemId;
        }
    }

    [db addOpenReaderFolder:rssTitle underParent:underFolder afterChild:-1 subscriptionURL:feedURL remoteId:feedID];
}

-(void)createFolders:(NSMutableArray *)params
{
    NSMutableArray *folderNames = params[0];
    NSNumber *parentNumber = params[1];

    // Remove the parent parameter. We'll re-add it with a new value later.
    [params removeObjectAtIndex:1];

    Database *dbManager = [Database sharedManager];
    NSString *folderName = folderNames[0];
    Folder *folder = [dbManager folderFromName:folderName];

    if (!folder) {
        NSInteger newFolderId;
        newFolderId =
            [dbManager addFolder:parentNumber.integerValue afterChild:-1 folderName:folderName type:VNAFolderTypeGroup canAppendIndex:NO];
        parentNumber = @(newFolderId);
    } else {
        parentNumber = @(folder.itemId);
    }

    [folderNames removeObjectAtIndex:0];
    if (folderNames.count > 0) {
        // Add the new parent parameter.
        [params addObject:parentNumber];
        [self createFolders:params];
    }
} // createFolders


/**
 * Percent escape the part after "feed/"
 *
 */
+(NSString *)escapeFeedId:(NSString *)identifier
{
    return [NSString stringWithFormat:@"feed/%@", percentEscape([identifier stringByReplacingOccurrencesOfString:@"feed/" withString:@"" options:0 range:NSMakeRange(0, 5)])];
}

@end
