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
#import "AppController.h"
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
BOOL hostRequiresInoreaderAdditionalHeaders;
BOOL hostRequiresBackcrawling;
NSDictionary *inoreaderAdditionalHeaders;

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
@property (nonatomic) NSMutableArray *tTokenWaitQueue;
@property (nonatomic) dispatch_queue_t asyncQueue;
@property (nonatomic) OpenReaderStatus openReaderStatus;
@property (readonly, class, nonatomic) NSString *currentTimestamp;

@end

@implementation OpenReader

# pragma mark initialization

-(instancetype)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
        _tTokenWaitQueue = [[NSMutableArray alloc] init];
        _openReaderStatus = notAuthenticated;
        _countOfNewArticles = 0;
        openReaderHost = nil;
        username = nil;
        password = nil;
        APIBaseURL = nil;
        inoreaderAdditionalHeaders = @{
            @"AppID": @"1000001359",
            @"AppKey": @"rAlfs2ELSuFxZJ5adJAW54qsNbUa45Qn"
        };
        _asyncQueue = dispatch_queue_create("uk.co.opencommunity.vienna2.openReaderTasks", NULL);
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
    [self commonRequestPrepare:request];
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

-(void)commonRequestPrepare:(NSMutableURLRequest *)request
{
    [self addClientTokenToRequest:request];
    if (hostRequiresInoreaderAdditionalHeaders) {
        NSMutableDictionary *theHeaders = [request.allHTTPHeaderFields mutableCopy] ? : [[NSMutableDictionary alloc] init];
        [theHeaders addEntriesFromDictionary:inoreaderAdditionalHeaders];
        request.allHTTPHeaderFields = theHeaders;
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

        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:LoginBaseURL, openReaderHost]];
        NSMutableURLRequest *myRequest = [NSMutableURLRequest requestWithURL:url];
        myRequest.HTTPMethod = @"POST";

        [self configureForSpecificHost];
        if (hostRequiresInoreaderAdditionalHeaders) {
            NSMutableDictionary *theHeaders = [myRequest.allHTTPHeaderFields mutableCopy];
            [theHeaders addEntriesFromDictionary:inoreaderAdditionalHeaders];
            myRequest.allHTTPHeaderFields = theHeaders;
        }
        [myRequest setPostValue:username forKey:@"Email"];
        [myRequest setPostValue:password forKey:@"Passwd"];

        // semaphore with count equal to zero for synchronizing completion of work
        sema = dispatch_semaphore_create(0);

        clientAuthOperation = [NSBlockOperation blockOperationWithBlock:^(void) {
            NSURLSessionDataTask * task = [[NSURLSession sharedSession] dataTaskWithRequest:myRequest
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    self.openReaderStatus = notAuthenticated;
                    if (error) {
                        NSLog(@"clientAuthOperation error for URL %@", ((NSHTTPURLResponse *)response).URL);
                        NSLog(@"Headers %@", ((NSHTTPURLResponse *)response).allHeaderFields);
                        NSLog(@"Response data %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_GoogleAuthFailed" object:nil];
                    } else {
                        if (((NSHTTPURLResponse *)response).statusCode != 200) {
                            NSLog(@"clientAuthOperation statusCode %ld for URL %@", ((NSHTTPURLResponse *)response).statusCode, ((NSHTTPURLResponse *)response).URL);
                            NSLog(@"Headers %@", ((NSHTTPURLResponse *)response).allHeaderFields);
                            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_GoogleAuthFailed" object:nil];
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
                        }
                    }  // if error

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
    hostRequiresInoreaderAdditionalHeaders = NO;
    hostRequiresBackcrawling = YES;
    // settings for specific kind of servers
    if ([openReaderHost isEqualToString:@"theoldreader.com"]) {
        hostSendsHexaItemId = YES;
        hostRequiresSParameter = YES;
        hostRequiresHexaForFeedId = YES;
        hostRequiresBackcrawling = NO;
    }
    if ([openReaderHost rangeOfString:@"inoreader.com"].length != 0) {
        hostRequiresInoreaderAdditionalHeaders = YES;
        hostRequiresBackcrawling = NO;
    }
    if ([openReaderHost rangeOfString:@"bazqux.com"].length != 0) {
        hostRequiresBackcrawling = NO;
    }
    // restore from keychain
    password = [KeyChain getGenericPasswordFromKeychain:username serviceName:@"Vienna sync"];
    APIBaseURL = [NSString stringWithFormat:@"https://%@/reader/api/0/", openReaderHost];
} // configureForSpecificHost

/* pass the T token
 */
-(void)getTokenForRequest:(NSMutableURLRequest *)clientRequest;
{
    static NSOperation * tTokenOperation;

    if (self.openReaderStatus == fullyAuthenticated) {
        [clientRequest setPostValue:self.tToken forKey:@"T"];
        return;
    } else if (self.openReaderStatus == waitingTToken && tTokenOperation != nil && !tTokenOperation.isFinished) {
        if (clientRequest != nil) {
            [clientRequest setInUserInfo:tTokenOperation forKey:@"dependency"];
            [self.tTokenWaitQueue addObject:clientRequest];
        }
        return;
    } else if (self.openReaderStatus == notAuthenticated || self.openReaderStatus == waitingClientToken) {
        // in principle, this should only happen with _openReaderStatus == notAuthenticated, after failure to get clientAuthToken
        if (clientRequest != nil) {
            [self.tTokenWaitQueue addObject:clientRequest];
        }
        return;
    } else {
        // openReaderStatus ==  missingTToken
        NSMutableURLRequest * myRequest = [self requestFromURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@token", APIBaseURL]]];
        self.openReaderStatus = waitingTToken;
        [[RefreshManager sharedManager] suspendConnectionsQueue];
        tTokenOperation = [[RefreshManager sharedManager] addConnection:myRequest
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    NSLog(@"tTokenOperation error for URL %@", myRequest.URL);
                    NSLog(@"Request headers %@", myRequest.allHTTPHeaderFields);
                    NSLog(@"Request body %@", [[NSString alloc] initWithData:myRequest.HTTPBody encoding:NSUTF8StringEncoding]);
                    NSLog(@"Response headers %@", ((NSHTTPURLResponse *)response).allHeaderFields);
                    NSLog(@"Response data %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                    self.tToken = nil;
                    self.openReaderStatus = missingTToken;
                    [self.tTokenWaitQueue removeAllObjects];
                } else {
                    [[RefreshManager sharedManager] suspendConnectionsQueue];
                    self.tToken = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    self.openReaderStatus = fullyAuthenticated;
                    for (id obj in self.tTokenWaitQueue) {
                        [(NSMutableURLRequest *)obj setPostValue:self.tToken forKey:@"T"];
                    }
                    [self.tTokenWaitQueue removeAllObjects];
                    if (self.tTokenTimer == nil || !self.tTokenTimer.valid) {
                        //tokens expire after 30 minutes : renew them every 25 minutes
                        self.tTokenTimer = [NSTimer scheduledTimerWithTimeInterval:25 * 60
                                                                            target:self
                                                                          selector:@selector(renewTToken)
                                                                          userInfo:nil
                                                                           repeats:YES];
                    }
                    [[RefreshManager sharedManager] resumeConnectionsQueue];
                }
        }];
        if (clientRequest != nil) {
            [clientRequest setInUserInfo:tTokenOperation forKey:@"dependency"];
            [self.tTokenWaitQueue addObject:clientRequest];
        }
        [[RefreshManager sharedManager] resumeConnectionsQueue];
    } // missingTToken
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

/* countOfNewArticles
 */
-(NSUInteger)countOfNewArticles
{
    NSUInteger count = _countOfNewArticles;
    _countOfNewArticles = 0;
    return count;
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
        if (hostRequiresBackcrawling) {
            // For FeedHQ servers, we need to search articles which are older than last refresh
            @try {
                double limit = folderLastUpdateString.doubleValue - 2 * 24 * 3600;
                if (limit < 0.0f) {
                    limit = 0.0;
                }
                NSString *startEpoch = @(limit).stringValue;
                itemsLimitation = [NSString stringWithFormat:@"&ot=%@&n=500", startEpoch];
            } @catch (NSException *exception) {
                itemsLimitation = @"&n=500";
            }
        } else {
            // Bazqux.com, TheOldReader.com and Inoreader.com
            itemsLimitation = [NSString stringWithFormat:@"&ot=%@&n=500", folderLastUpdateString];
        }
    }

    NSString *feedIdentifier;
    if (hostRequiresHexaForFeedId) {
        feedIdentifier = thisFolder.feedURL.lastPathComponent;
    } else {
        feedIdentifier =  thisFolder.feedURL;
    }

    NSURL *refreshFeedUrl =
        [NSURL URLWithString:[NSString stringWithFormat:
                              @"%@stream/contents/feed/%@?client=%@&comments=false&likes=false%@&ck=%@&output=json",
                              APIBaseURL,
                              percentEscape(feedIdentifier), ClientName, itemsLimitation, OpenReader.currentTimestamp]];

    NSMutableURLRequest *request = [self requestFromURL:refreshFeedUrl];
    [request setUserInfo:
        @{ @"folder": thisFolder, @"log": aItem, @"lastupdatestring": folderLastUpdateString, @"type": @(MA_Refresh_GoogleFeed) }];

    // Request id's of unread items
    NSString *args =
        [NSString stringWithFormat:@"?ck=%@&client=%@&s=feed/%@&xt=user/-/state/com.google/read&n=1000&output=json",
         OpenReader.currentTimestamp, ClientName,
         percentEscape(feedIdentifier)];
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
        [NSString stringWithFormat:@"?ck=%@&client=%@&s=feed/%@&%@&n=1000&output=json", OpenReader.currentTimestamp, ClientName,
         percentEscape(feedIdentifier), starredSelector];
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
            // Send status to the activity log
            if (newArticlesFromFeed == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [aItem setStatus:NSLocalizedString(@"No new articles available", nil)];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    aItem.status = [NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newArticlesFromFeed];
                });
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated"
                                                                                    object:@(refreshedFolder.itemId)];
            }
        } else { //other HTTP status response...
            [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil),
                                 ((NSHTTPURLResponse *)response).statusCode]];
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
        }
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
            [aItem setStatus:NSLocalizedString(@"Error", nil)];
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
            [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
        }
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

        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:@(refreshedFolder.
                                                                                                                        itemId)];
    });     //block for dispatch_async
} // starredRequestDone

-(void)subscriptionsRequestDone:(NSMutableURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data
{
    NSDictionary *subscriptionsDict;
    NSError *jsonError;
    subscriptionsDict = [NSJSONSerialization JSONObjectWithData:data
                                                        options:NSJSONReadingMutableContainers
                                                          error:&jsonError];
    NSMutableArray *localFeeds = [NSMutableArray array];
    NSMutableArray *remoteFeeds = [NSMutableArray array];
    NSArray *localFolders = APPCONTROLLER.folders;

    for (Folder *f in localFolders) {
        if (f.feedURL && f.type == VNAFolderTypeOpenReader) {
            [localFeeds addObject:f.feedURL];
        }
    }

    for (NSDictionary *feed in subscriptionsDict[@"subscriptions"]) {
        NSString *feedID = feed[@"id"];
        if (feedID == nil) {
            break;
        }
        NSString *feedURL = feed[@"url"];
        if (feedURL == nil || hostRequiresHexaForFeedId) { // TheOldReader requires BSON identifier in stream Ids instead of URL (ex: feed/0125ef...)
            NSString * feedIdentifier = [feedID stringByReplacingOccurrencesOfString:@"feed/" withString:@"" options:0 range:NSMakeRange(0, 5)];
            if (hostRequiresHexaForFeedId) { // TheOldReader
                feedURL = [NSString stringWithFormat:@"https://%@/reader/public/atom/%@", openReaderHost, feedIdentifier];
            } else { // most services use feed URL as identifier (like GoogleReader did)
                feedURL = feedIdentifier;
            }
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
        if (![localFeeds containsObject:feedURL]) {
            // folderName could be nil
            NSArray *params = folderName ? @[feedURL, rssTitle, folderName] : @[feedURL, rssTitle];
            [self createNewSubscription:params];
        } else {
            // the feed is already known
            // set HomePage if the info is available
            NSString *homePageURL = feed[@"htmlUrl"];
            if (homePageURL) {
                for (Folder *localFolder in localFolders) {
                    if (localFolder.type == VNAFolderTypeOpenReader && [localFolder.feedURL isEqualToString:feedURL]) {
                        Database * db = [Database sharedManager];
                        [db setHomePage:homePageURL forFolder:localFolder.itemId];
                        if ([db folderFromName:rssTitle] == nil) { // no conflict
                            [db setName:rssTitle forFolder:localFolder.itemId];
                        };
                        break;
                    }
                }
            }
        }

        [remoteFeeds addObject:feedURL];
    }


    if (subscriptionsDict[@"subscriptions"] != nil) { // detect probable authentication error
        //check if we have a folder which is not registered as a Open Reader feed
        for (Folder *f in APPCONTROLLER.folders) {
            if (f.type == VNAFolderTypeOpenReader && ![remoteFeeds containsObject:f.feedURL]) {
                [[Database sharedManager] deleteFolder:f.itemId];
            }
        }
    }
} // subscriptionsRequestDone

-(void)loadSubscriptions
{
    NSMutableURLRequest *subscriptionRequest =
        [self requestFromURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/list?client=%@&output=json", APIBaseURL,
                                                   ClientName]]];
    __weak typeof(self) weakSelf = self;
    [[RefreshManager sharedManager] addConnection:subscriptionRequest
        completionHandler :^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [weakSelf requestFailed:subscriptionRequest response:response error:error];
            } else {
                [weakSelf subscriptionsRequestDone:subscriptionRequest response:response data:data];
            }
            weakSelf.statusMessage = @"";
        }
    ];

    self.statusMessage = NSLocalizedString(@"Fetching Open Reader Subscriptions…", nil);
}

-(void)subscribeToFeed:(NSString *)feedURL
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/quickadd?client=%@", APIBaseURL, ClientName]];

    NSMutableURLRequest *request = [self authentifiedFormRequestFromURL:url];
    [request setPostValue:feedURL forKey:@"quickadd"];
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

-(void)unsubscribeFromFeed:(NSString *)feedURL
{
    NSURL *unsubscribeURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit", APIBaseURL]];
    NSMutableURLRequest *myRequest = [self authentifiedFormRequestFromURL:unsubscribeURL];
    [myRequest setPostValue:@"unsubscribe" forKey:@"ac"];
    NSString *feedIdentifier;
    if (hostRequiresHexaForFeedId) {
        feedIdentifier = feedURL.lastPathComponent;
    } else {
        feedIdentifier = feedURL;
    }
    [myRequest setPostValue:[NSString stringWithFormat:@"feed/%@", percentEscape(feedIdentifier)] forKey:@"s"];
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
-(void)setFolderLabel:(NSString *)folderName forFeed:(NSString *)feedURL set:(BOOL)flag
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@", APIBaseURL, ClientName]];

    NSMutableURLRequest *request = [self authentifiedFormRequestFromURL:url];
    [request setPostValue:@"edit" forKey:@"ac"];
    NSString *feedIdentifier;
    if (hostRequiresHexaForFeedId) {
        feedIdentifier = feedURL.lastPathComponent;
    } else {
        feedIdentifier = feedURL;
    }
    [request setPostValue:[NSString stringWithFormat:@"feed/%@", percentEscape(feedIdentifier)] forKey:@"s"];
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
-(void)setFolderTitle:(NSString *)folderName forFeed:(NSString *)feedURL
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@", APIBaseURL, ClientName]];

    NSMutableURLRequest *request = [self authentifiedFormRequestFromURL:url];
    [request setPostValue:@"edit" forKey:@"ac"];
    NSString *feedIdentifier;
    if (hostRequiresHexaForFeedId) {
        feedIdentifier = feedURL.lastPathComponent;
    } else {
        feedIdentifier = feedURL;
    }
    [request setPostValue:[NSString stringWithFormat:@"feed/%@", percentEscape(feedIdentifier)] forKey:@"s"];
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
    NSString *feedURL = params[0];
    NSString *rssTitle = [NSString stringWithFormat:@""];

    if (params.count > 1) {
        if (params.count > 2) {
            NSString *folderName = params[2];
            Database *db = [Database sharedManager];
            Folder *folder = [db folderFromName:folderName];
            underFolder = folder.itemId;
        }
        rssTitle = params[1];
    }

    [APPCONTROLLER createNewGoogleReaderSubscription:feedURL underFolder:underFolder withTitle:rssTitle afterChild:-1];
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
 * Get the current timestamp
 *
 * @return current timestamp as a string
 */
+(NSString *)currentTimestamp
{
    return [NSString stringWithFormat:@"%0.0f", NSDate.date.timeIntervalSince1970];
}

@end
