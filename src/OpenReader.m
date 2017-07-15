//
//  OpenReader.m
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011-2017 Vienna contributors (see Help/Acknowledgements for list of contributors). All rights reserved.
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
#import "ASIFormDataRequest.h"

static NSString *LoginBaseURL = @"https://%@/accounts/ClientLogin?accountType=GOOGLE&service=reader";
static NSString *ClientName = @"ViennaRSS";

// host specific variables
NSString *openReaderHost;
NSString *username;
NSString *password;
NSString *APIBaseURL;
BOOL hostSupportsLongId;
BOOL hostRequiresSParameter;
BOOL hostRequiresLastPathOnly;
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

@interface OpenReader () <ASIHTTPRequestDelegate>

@property (readwrite, copy) NSString *statusMessage;
@property (readwrite, nonatomic) NSUInteger countOfNewArticles;
@property (nonatomic) NSMutableArray *localFeeds;
@property (atomic) NSString *tToken;
@property (atomic) NSString *clientAuthToken;
@property (nonatomic) NSTimer *tTokenTimer;
@property (nonatomic) NSTimer *clientAuthTimer;
@property (nonatomic) NSMutableArray *clientAuthWaitQueue;
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
        _localFeeds = [[NSMutableArray alloc] init];
        _clientAuthWaitQueue = [[NSMutableArray alloc] init];
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

/* prepare an ASIHTTPRequest from an NSURL
 */
-(ASIHTTPRequest *)requestFromURL:(NSURL *)url
{
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [self commonRequestPrepare:request];
    return request;
}

/* prepare an ASIFormDataRequest from an NSURL and pass the T token
 */
-(ASIFormDataRequest *)authentifiedFormRequestFromURL:(NSURL *)url
{
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [self commonRequestPrepare:request];
    [self getTokenForRequest:request];
    return request;
}

-(void)commonRequestPrepare:(ASIHTTPRequest *)request
{
    [self addClientTokenToRequest:request];
    if (hostRequiresInoreaderAdditionalHeaders) {
        NSMutableDictionary *theHeaders = [request.requestHeaders mutableCopy] ? : [[NSMutableDictionary alloc] init];
        [theHeaders addEntriesFromDictionary:inoreaderAdditionalHeaders];
        request.requestHeaders = theHeaders;
    }
    [request setUseCookiePersistence:NO];
    request.timeOutSeconds = 180;
    request.delegate = self;
}

/* pass the GoogleLogin client authentication token
 */
-(void)addClientTokenToRequest:(ASIHTTPRequest *)clientRequest
{
    static ASIFormDataRequest *myRequest;

    if (self.openReaderStatus == fullyAuthenticated || self.openReaderStatus == waitingTToken || self.openReaderStatus == missingTToken) {
        [clientRequest addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", self.clientAuthToken]];
        return; //we are already connected
    } else if ((self.openReaderStatus == waitingClientToken) && myRequest != nil) {
        [clientRequest addDependency:myRequest];
        if (clientRequest != nil) {
            [self.clientAuthWaitQueue addObject:clientRequest];
        }
        return;
    } else {
        // start first authentication
        self.openReaderStatus = waitingClientToken;
        // Do nothing if syncing is disabled in preferences
        if (![Preferences standardPreferences].syncGoogleReader) {
            return;
        }

        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:LoginBaseURL, openReaderHost]];
        myRequest = [ASIFormDataRequest requestWithURL:url];

        [self configureForSpecificHost];
        if (hostRequiresInoreaderAdditionalHeaders) {
            NSMutableDictionary *theHeaders = [myRequest.requestHeaders mutableCopy];
            [theHeaders addEntriesFromDictionary:inoreaderAdditionalHeaders];
            myRequest.requestHeaders = theHeaders;
        }
        [myRequest setUseCookiePersistence:NO];
        myRequest.timeOutSeconds = 180;
        myRequest.delegate = nil;
        [myRequest setPostValue:username forKey:@"Email"];
        [myRequest setPostValue:password forKey:@"Passwd"];

        __weak typeof(myRequest)weakRequest = myRequest;
        [myRequest setFailedBlock:^{
            __strong typeof(weakRequest)strongRequest = weakRequest;
            LOG_EXPR([strongRequest responseHeaders]);
            LOG_EXPR([[NSString alloc] initWithData:[strongRequest responseData] encoding:NSUTF8StringEncoding]);
            [strongRequest clearDelegatesAndCancel];
            for (id obj in [self.clientAuthWaitQueue reverseObjectEnumerator]) {
                [(ASIHTTPRequest *)obj cancel];
                [self.clientAuthWaitQueue removeObject:obj];
            }
            self.openReaderStatus = notAuthenticated;
            [[RefreshManager sharedManager] resumeConnectionsQueue];
        }];
        [myRequest setCompletionBlock:^{
            __strong typeof(weakRequest)strongRequest = weakRequest;
            if (strongRequest.responseStatusCode != 200) {
                LOG_EXPR([strongRequest responseStatusCode]);
                LOG_EXPR([strongRequest responseHeaders]);
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_GoogleAuthFailed" object:nil];
                [strongRequest clearDelegatesAndCancel];
                self.openReaderStatus = notAuthenticated;
                for (id obj in [self.clientAuthWaitQueue reverseObjectEnumerator]) {
                    [(ASIHTTPRequest *)obj cancel];
                    [self.clientAuthWaitQueue removeObject:obj];
                }
                self.statusMessage = nil;
            } else {
                NSString *response = [strongRequest responseString];
                NSArray *components = [response componentsSeparatedByString:@"\n"];

                //NSString * sid = [[components objectAtIndex:0] substringFromIndex:4];		//unused
                //NSString * lsid = [[components objectAtIndex:1] substringFromIndex:5];	//unused
                self.clientAuthToken = [NSString stringWithString:[components[2] substringFromIndex:5]];
                self.openReaderStatus = missingTToken;

                for (id obj in self.clientAuthWaitQueue) {
                    [(ASIHTTPRequest *)obj addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@",
                                                                                 self.clientAuthToken]];
                }
                for (id obj in [self.clientAuthWaitQueue reverseObjectEnumerator]) {
                    [self.clientAuthWaitQueue removeObject:obj];
                }

                if (self.clientAuthTimer == nil || !self.clientAuthTimer.valid) {
                    //new request every 6 days
                    self.clientAuthTimer = [NSTimer scheduledTimerWithTimeInterval:6 * 24 * 3600
                                                                            target:self
                                                                          selector:@selector(resetAuthentication)
                                                                          userInfo:nil
                                                                           repeats:YES];
                }
            }
            [[RefreshManager sharedManager] resumeConnectionsQueue];
        }];

        [clientRequest addDependency:myRequest];
        [myRequest setQueuePriority:NSOperationQueuePriorityHigh];
        if (clientRequest != nil) {
            [self.clientAuthWaitQueue addObject:clientRequest];
        }
        [[RefreshManager sharedManager] addConnection:myRequest];
        [[RefreshManager sharedManager] suspendConnectionsQueue];
        self.statusMessage = NSLocalizedString(@"Authenticating on Open Reader", nil);
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
    hostSupportsLongId = NO;
    hostRequiresSParameter = NO;
    hostRequiresLastPathOnly = NO;
    hostRequiresInoreaderAdditionalHeaders = NO;
    hostRequiresBackcrawling = YES;
    // settings for specific kind of servers
    if ([openReaderHost isEqualToString:@"theoldreader.com"]) {
        hostSupportsLongId = YES;
        hostRequiresSParameter = YES;
        hostRequiresLastPathOnly = YES;
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
-(void)getTokenForRequest:(ASIFormDataRequest *)clientRequest;
{
    static ASIHTTPRequest *myRequest;

    if (self.openReaderStatus == fullyAuthenticated) {
        [clientRequest setPostValue:self.tToken forKey:@"T"];
        return;
    } else if (self.openReaderStatus == waitingTToken && myRequest != nil) {
        [clientRequest addDependency:myRequest];
        if (clientRequest != nil) {
            [self.tTokenWaitQueue addObject:clientRequest];
        }
        return;
    } else if (self.openReaderStatus == notAuthenticated || self.openReaderStatus == waitingClientToken) {
        if (clientRequest != nil) {
            [self.tTokenWaitQueue addObject:clientRequest];
        }
        [clientRequest setQueuePriority:NSOperationQueuePriorityLow];
        return;
    } else {
        // openReaderStatus ==  missingTToken
        myRequest = [self requestFromURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@token", APIBaseURL]]];
        self.openReaderStatus = waitingTToken;
        [myRequest addRequestHeader:@"Content-Type" value:@"application/x-www-form-urlencoded"];
        myRequest.delegate = nil;
        __weak typeof(myRequest)weakRequest = myRequest;
        [myRequest setCompletionBlock:^{
            __strong typeof(weakRequest)strongRequest = weakRequest;
            [[RefreshManager sharedManager] suspendConnectionsQueue];
            self.tToken = [strongRequest responseString];
            self.openReaderStatus = fullyAuthenticated;
            for (id obj in self.tTokenWaitQueue) {
                [(ASIFormDataRequest *)obj setPostValue:self.tToken forKey:@"T"];
            }
            for (id obj in [self.tTokenWaitQueue reverseObjectEnumerator]) {
                [self.tTokenWaitQueue removeObject:obj];
            }
            if (self.tTokenTimer == nil || !self.tTokenTimer.valid) {
                //tokens expire after 30 minutes : renew them every 25 minutes
                self.tTokenTimer = [NSTimer scheduledTimerWithTimeInterval:25 * 60
                                                                    target:self
                                                                  selector:@selector(renewTToken)
                                                                  userInfo:nil
                                                                   repeats:YES];
                }
            [[RefreshManager sharedManager] resumeConnectionsQueue];
        }];
        [myRequest setFailedBlock:^{
            __strong typeof(weakRequest)strongRequest = weakRequest;
            LOG_EXPR([strongRequest originalURL]);
            LOG_EXPR([strongRequest requestHeaders]);
            LOG_EXPR([[NSString alloc] initWithData:[strongRequest postBody] encoding:NSUTF8StringEncoding]);
            LOG_EXPR([strongRequest responseHeaders]);
            LOG_EXPR([[NSString alloc] initWithData:[strongRequest responseData] encoding:NSUTF8StringEncoding]);
            self.tToken = nil;
            [strongRequest clearDelegatesAndCancel];
            self.openReaderStatus = missingTToken;
            for (id obj in [self.tTokenWaitQueue reverseObjectEnumerator]) {
                [(ASIFormDataRequest *)obj cancel];
                [self.tTokenWaitQueue removeObject:obj];
            }
        }];
        [clientRequest addDependency:myRequest];
        if (clientRequest != nil) {
            [self.tTokenWaitQueue addObject:clientRequest];
        }
        [[RefreshManager sharedManager] addConnection:myRequest];
    }
}

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
-(void)requestFailed:(ASIHTTPRequest *)request
{
    LLog(@"Failed on request %@", [request originalURL]);
    LOG_EXPR([request error]);
    LOG_EXPR([request requestHeaders]);
    LOG_EXPR([request responseHeaders]);
    if (request.error.code == ASIAuthenticationErrorType) {   //Error caused by lack of authentication
        [self clearAuthentication];
    }
}

// default handler for didFinishSelector
-(void)requestFinished:(ASIHTTPRequest *)request
{
    NSString *requestResponse = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
    if (![requestResponse isEqualToString:@"OK"]) {
        LLog(@"Error (response status code %d) on request %@", [request responseStatusCode], [request originalURL]);
        LOG_EXPR([request error]);
        LOG_EXPR([request requestHeaders]);
        LOG_EXPR([[NSString alloc] initWithData:[request postBody] encoding:NSUTF8StringEncoding]);
        LOG_EXPR([request responseHeaders]);
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

-(ASIHTTPRequest *)refreshFeed:(Folder *)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit
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
                double limit = [folderLastUpdateString doubleValue] - 2 * 24 * 3600;
                if (limit < 0.0f) {
                    limit = 0.0;
                }
                NSString *startEpoch = [NSNumber numberWithDouble:limit].stringValue;
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
    if (hostRequiresLastPathOnly) {
        feedIdentifier = thisFolder.feedURL.lastPathComponent;
    } else {
        feedIdentifier =  thisFolder.feedURL;
    }

    NSURL *refreshFeedUrl =
        [NSURL URLWithString:[NSString stringWithFormat:
                              @"%@stream/contents/feed/%@?client=%@&comments=false&likes=false%@&ck=%@&output=json",
                              APIBaseURL,
                              percentEscape(feedIdentifier), ClientName, itemsLimitation, OpenReader.currentTimestamp]];

    ASIHTTPRequest *request = [self requestFromURL:refreshFeedUrl];
    request.didFinishSelector = @selector(feedRequestDone:);
    request.didFailSelector = @selector(feedRequestFailed:);
    request.userInfo =
        @{ @"folder": thisFolder, @"log": aItem, @"lastupdatestring": folderLastUpdateString, @"type": @(MA_Refresh_GoogleFeed) };

    // Request id's of unread items
    NSString *args =
        [NSString stringWithFormat:@"?ck=%@&client=%@&s=feed/%@&xt=user/-/state/com.google/read&n=1000&output=json",
         OpenReader.currentTimestamp, ClientName,
         percentEscape(feedIdentifier)];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", APIBaseURL, @"stream/items/ids", args]];
    ASIHTTPRequest *request2 = [self requestFromURL:url];
    request2.userInfo = @{ @"folder": thisFolder, @"log": aItem };
    request2.didFinishSelector = @selector(readRequestDone:);
    [request2 addDependency:request];
    [[RefreshManager sharedManager] addConnection:request2];

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
    ASIHTTPRequest *request3 = [self requestFromURL:url3];
    request3.userInfo = @{ @"folder": thisFolder, @"log": aItem };
    request3.didFinishSelector = @selector(starredRequestDone:);
    [request3 addDependency:request2];
    [[RefreshManager sharedManager] addConnection:request3];

    return request;
} // refreshFeed

// callback : handler for timed out feeds, etc...
-(void)feedRequestFailed:(ASIHTTPRequest *)request
{
    LLog(@"Open Reader feed request Failed : %@", [request originalURL]);
    LOG_EXPR([request error]);
    LOG_EXPR([request requestHeaders]);
    LOG_EXPR([[NSString alloc] initWithData:[request postBody] encoding:NSUTF8StringEncoding]);
    LOG_EXPR([request responseHeaders]);
    ActivityItem *aItem = request.userInfo[@"log"];
    Folder *refreshedFolder = request.userInfo[@"folder"];

    [aItem appendDetail:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Error", nil), request.error.localizedDescription ]];
    [aItem setStatus:NSLocalizedString(@"Error", nil)];
    [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
    [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
}

// callback
-(void)feedRequestDone:(ASIHTTPRequest *)request
{
    dispatch_async(self.asyncQueue, ^() {
        // TODO : refactor code to separate feed refresh code and UI

        ActivityItem *aItem = request.userInfo[@"log"];
        Folder *refreshedFolder = request.userInfo[@"folder"];

        if (request.responseStatusCode == 404) {
            [aItem appendDetail:NSLocalizedString(@"Error: Feed not found!", nil)];
            dispatch_async(dispatch_get_main_queue(), ^{
                [aItem setStatus:NSLocalizedString(@"Error", nil)];
            });
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
            [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
        } else if (request.responseStatusCode == 200) {
            // reset unread statuses in cache : we will receive in -ReadRequestDone: the updated list of unreads
            [refreshedFolder markArticlesInCacheRead];
            NSData *data = [request responseData];
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
                LOG_EXPR([request url]);
                NSLog(@"Feed name: %@", subscriptionsDict[@"title"]);
                NSLog(@"Last Check: %@", request.userInfo[@"lastupdatestring"]);
                NSLog(@"Last update: %@", folderLastUpdateString);
                NSLog(@"Found %lu items", (unsigned long)[subscriptionsDict[@"items"] count]);
                LOG_EXPR(subscriptionsDict);
                LOG_EXPR([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                ALog(@"Error !!! Incoherent data !");
                //keep the previously recorded one
                folderLastUpdateString = request.userInfo[@"lastupdatestring"];
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

            self.statusMessage = nil;
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagError];
            // Send status to the activity log
            if (newArticlesFromFeed == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [aItem setStatus:NSLocalizedString(@"No new articles available", nil)];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [aItem setStatus:[NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newArticlesFromFeed]];
                });
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated"
                                                                                    object:@(refreshedFolder.itemId)];
            }
        } else { //other HTTP status response...
            [aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil),
                                 request.responseStatusCode]];
            LOG_EXPR([request originalURL]);
            LOG_EXPR([request requestHeaders]);
            LOG_EXPR([[NSString alloc] initWithData:[request postBody] encoding:NSUTF8StringEncoding]);
            LOG_EXPR([request responseHeaders]);
            LOG_EXPR([[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding]);
            dispatch_async(dispatch_get_main_queue(), ^{
                [aItem setStatus:NSLocalizedString(@"Error", nil)];
            });
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
            [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
        }
    });     //block for dispatch_async
} // feedRequestDone

// callback
-(void)readRequestDone:(ASIHTTPRequest *)request
{
    dispatch_async(self.asyncQueue, ^() {
        Folder *refreshedFolder = request.userInfo[@"folder"];
        ActivityItem *aItem = request.userInfo[@"log"];
        if (request.responseStatusCode == 200) {
            @try {
                NSArray *itemRefsArray;
                NSError *jsonError;
                itemRefsArray = [NSJSONSerialization JSONObjectWithData:request.responseData
                                                                options:NSJSONReadingMutableContainers
                                                                  error:&jsonError][@"itemRefs"];
                NSMutableArray *guidArray = [NSMutableArray arrayWithCapacity:itemRefsArray.count];
                for (NSDictionary *itemRef in itemRefsArray) {
                    NSString *guid;
                    if (hostSupportsLongId) {
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
                for (Article *article in [refreshedFolder articles]) {
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
            [aItem appendDetail:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Error",
                                                                                       nil), request.error.localizedDescription ]];
            [aItem setStatus:NSLocalizedString(@"Error", nil)];
            [refreshedFolder clearNonPersistedFlag:VNAFolderFlagUpdating];
            [refreshedFolder setNonPersistedFlag:VNAFolderFlagError];
        }
    });     //block for dispatch_async
} // readRequestDone

// callback
-(void)starredRequestDone:(ASIHTTPRequest *)request
{
    dispatch_async(self.asyncQueue, ^() {
        Folder *refreshedFolder = request.userInfo[@"folder"];
        ActivityItem *aItem = request.userInfo[@"log"];
        if (request.responseStatusCode == 200) {
            @try {
                NSArray *itemRefsArray;
                NSError *jsonError;
                itemRefsArray = [NSJSONSerialization JSONObjectWithData:request.responseData
                                                                options:NSJSONReadingMutableContainers
                                                                  error:&jsonError][@"itemRefs"];
                NSMutableArray *guidArray = [NSMutableArray arrayWithCapacity:itemRefsArray.count];
                for (NSDictionary *itemRef in itemRefsArray) {
                    NSString *guid;
                    if (hostSupportsLongId) {
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
            [aItem appendDetail:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Error",
                                                                                       nil), request.error.localizedDescription ]];
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

-(void)subscriptionsRequestDone:(ASIHTTPRequest *)request
{
    NSDictionary *subscriptionsDict;
    NSError *jsonError;
    subscriptionsDict = [NSJSONSerialization JSONObjectWithData:request.responseData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&jsonError];
    [self.localFeeds removeAllObjects];
    NSArray *localFolders = APPCONTROLLER.folders;

    for (Folder *f in localFolders) {
        if (f.feedURL) {
            [self.localFeeds addObject:f.feedURL];
        }
    }

    NSMutableArray *googleFeeds = [[NSMutableArray alloc] init];

    for (NSDictionary *feed in subscriptionsDict[@"subscriptions"]) {
        NSString *feedID = feed[@"id"];
        if (feedID == nil) {
            break;
        }
        NSString *feedURL = [feedID stringByReplacingOccurrencesOfString:@"feed/" withString:@"" options:0 range:NSMakeRange(0, 5)];
        if (![feedURL hasPrefix:@"http:"] && ![feedURL hasPrefix:@"https:"]) {
            feedURL = [NSString stringWithFormat:@"https://%@/reader/public/atom/%@", openReaderHost, feedURL];
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

        if (![self.localFeeds containsObject:feedURL]) {
            NSString *rssTitle = @"";
            if (feed[@"title"]) {
                rssTitle = feed[@"title"];
            }
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
                        [[Database sharedManager] setHomePage:homePageURL forFolder:localFolder.itemId];
                        break;
                    }
                }
            }
        }

        [googleFeeds addObject:feedURL];
    }

    //check if we have a folder which is not registered as a Open Reader feed
    for (Folder *f in APPCONTROLLER.folders) {
        if (f.type == VNAFolderTypeOpenReader && ![googleFeeds containsObject:f.feedURL]) {
            [[Database sharedManager] deleteFolder:f.itemId];
        }
    }

    // Unread count may have changed
    self.statusMessage = nil;
} // subscriptionsRequestDone

-(void)loadSubscriptions
{
    ASIHTTPRequest *subscriptionRequest =
        [self requestFromURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/list?client=%@&output=json", APIBaseURL,
                                                   ClientName]]];
    subscriptionRequest.didFinishSelector = @selector(subscriptionsRequestDone:);
    [[RefreshManager sharedManager] addConnection:subscriptionRequest];
    self.statusMessage = NSLocalizedString(@"Fetching Open Reader Subscriptions…", nil);
}

-(void)subscribeToFeed:(NSString *)feedURL
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/quickadd?client=%@", APIBaseURL, ClientName]];

    ASIFormDataRequest *request = [self authentifiedFormRequestFromURL:url];
    [request setPostValue:feedURL forKey:@"quickadd"];
    // Needs to be synchronous so UI doesn't refresh too soon.
    request.delegate = nil;
    [request startSynchronous];
    [request clearDelegatesAndCancel];
}

-(void)unsubscribeFromFeed:(NSString *)feedURL
{
    NSURL *unsubscribeURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit", APIBaseURL]];
    ASIFormDataRequest *myRequest = [self authentifiedFormRequestFromURL:unsubscribeURL];
    [myRequest setPostValue:@"unsubscribe" forKey:@"ac"];
    [myRequest setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];
    [[RefreshManager sharedManager] addConnection:myRequest];
}

/* setFolderName
 * set or remove a folder name to a newsfeed
 * set parameter : TRUE => add ; FALSE => remove
 */
-(void)setFolderName:(NSString *)folderName forFeed:(NSString *)feedURL set:(BOOL)flag
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@", APIBaseURL, ClientName]];

    ASIFormDataRequest *request = [self authentifiedFormRequestFromURL:url];
    [request setPostValue:@"edit" forKey:@"ac"];
    [request setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];
    [request setPostValue:[NSString stringWithFormat:@"user/-/label/%@", folderName] forKey:flag ? @"a" : @"r"];
    request.delegate = nil;
    [request startSynchronous];
    [request clearDelegatesAndCancel];
}

-(void)markRead:(Article *)article readFlag:(BOOL)flag
{
    NSURL *markReadURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@edit-tag", APIBaseURL]];
    ASIFormDataRequest *myRequest = [self authentifiedFormRequestFromURL:markReadURL];
    if (flag) {
        [myRequest setPostValue:@"user/-/state/com.google/read" forKey:@"a"];
    } else {
        [myRequest setPostValue:@"user/-/state/com.google/read" forKey:@"r"];
    }
    [myRequest setPostValue:@"true" forKey:@"async"];
    [myRequest setPostValue:article.guid forKey:@"i"];
    myRequest.userInfo = @{ @"article": article, @"readFlag": @(flag) };
    myRequest.didFinishSelector = @selector(markReadDone:);
    [[RefreshManager sharedManager] addConnection:myRequest];
}

// callback : we check if the server did confirm the read status change
-(void)markReadDone:(ASIHTTPRequest *)request
{
    NSString *requestResponse = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
    if ([requestResponse isEqualToString:@"OK"]) {
        Article *article = request.userInfo[@"article"];
        BOOL readFlag = [[request.userInfo valueForKey:@"readFlag"] boolValue];
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
    ASIFormDataRequest *myRequest = [self authentifiedFormRequestFromURL:markStarredURL];
    if (flag) {
        [myRequest setPostValue:@"user/-/state/com.google/starred" forKey:@"a"];
    } else {
        [myRequest setPostValue:@"user/-/state/com.google/starred" forKey:@"r"];
    }
    [myRequest setPostValue:@"true" forKey:@"async"];
    [myRequest setPostValue:article.guid forKey:@"i"];
    [[RefreshManager sharedManager] addConnection:myRequest];
}

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
