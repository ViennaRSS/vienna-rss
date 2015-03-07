//
//  GoogleReader.m
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011-2014 Vienna contributors (see Help/Acknowledgements for list of contributors). All rights reserved.
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

#import "GoogleReader.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "JSONKit.h"
#import "HelperFunctions.h"
#import "Folder.h"
#import "Database.h"
#import <Foundation/Foundation.h>
#import "Article.h"
#import "AppController.h"
#import "RefreshManager.h"
#import "Preferences.h"
#import "StringExtensions.h"
#import "NSNotificationAdditions.h"
#import "KeyChain.h"

#define TIMESTAMP [NSString stringWithFormat:@"%0.0f",[[NSDate date] timeIntervalSince1970]]

static NSString * LoginBaseURL = @"https://%@/accounts/ClientLogin?accountType=GOOGLE&service=reader";
static NSString * ClientName = @"ViennaRSS";

// host specific variables
NSString * openReaderHost;
NSString * username;
NSString * password;
NSString * APIBaseURL;
BOOL hostSupportsLongId;
BOOL hostRequiresSParameter;
BOOL hostRequiresLastPathOnly;

// Singleton
static GoogleReader * _googleReader = nil;

enum GoogleReaderStatus {
	notAuthenticated = 0,
	isAuthenticating,
	isAuthenticated
} googleReaderStatus;

@interface GoogleReader()
@property (nonatomic, copy) NSMutableArray * localFeeds;
@property (atomic, copy) NSString *token;
@property (atomic, copy) NSString *clientAuthToken;
@property (nonatomic, retain) NSTimer * tokenTimer;
@property (nonatomic, retain) NSTimer * authTimer;
@end

@implementation GoogleReader

@synthesize localFeeds;
@synthesize token;
@synthesize clientAuthToken;
@synthesize tokenTimer;
@synthesize authTimer;

JSONDecoder * jsonDecoder;

-(BOOL)isReady
{
	return (googleReaderStatus == isAuthenticated && tokenTimer != nil);
}


- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
		localFeeds = [[NSMutableArray alloc] init];
		jsonDecoder = [[JSONDecoder decoder] retain];
		googleReaderStatus = notAuthenticated;
		countOfNewArticles = 0;
		clientAuthToken= nil;
		token=nil;
		tokenTimer=nil;
		authTimer=nil;
		openReaderHost=nil;
		username=nil;
		password=nil;
		APIBaseURL=nil;
	}
    
    return self;
}

/* countOfNewArticles
 */
-(NSUInteger)countOfNewArticles
{
	NSUInteger count = countOfNewArticles;
	countOfNewArticles = 0;
	return count;
}

// default handler for didFailSelector
- (void)requestFailed:(ASIHTTPRequest *)request
{
	LLog(@"Failed on request");
	LOG_EXPR([request originalURL]);
	LOG_EXPR([request error]);
	LOG_EXPR([request responseHeaders]);
	if ([[request error] code] == ASIAuthenticationErrorType) //Error caused by lack of authentication
		[self clearAuthentication];
}

// default handler for didFinishSelector
- (void)requestFinished:(ASIHTTPRequest *)request
{
	LLog(@"HTTP response status code: %d -- URL: %@", [request responseStatusCode], [[request originalURL] absoluteString]);
	NSString *requestResponse = [[[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding] autorelease];
	if (![requestResponse isEqualToString:@"OK"]) {
		LLog(@"Error on request");
		LOG_EXPR([request error]);
		LOG_EXPR([request originalURL]);
		LOG_EXPR([request requestHeaders]);
		LOG_EXPR([[[NSString alloc] initWithData:[request postBody] encoding:NSUTF8StringEncoding] autorelease]);
		LOG_EXPR([request responseHeaders]);
		LOG_EXPR(requestResponse);
		[self clearAuthentication];
	}
}

-(ASIHTTPRequest*)refreshFeed:(Folder*)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit
{				
	
	//This is a workaround throw a BAD folderupdate value on DB
	NSString *folderLastUpdateString = ignoreLimit ? @"0" : [thisFolder lastUpdateString];
	if ([folderLastUpdateString isEqualToString:@""] || [folderLastUpdateString isEqualToString:@"(null)"]) folderLastUpdateString=@"0";
	
	NSString *itemsLimitation;
	if (ignoreLimit)
		itemsLimitation = @"&n=10000"; //just stay reasonable…
	else
		//Note : we don't set "r" (sorting order) here.
		//But according to some documentation, Google Reader and TheOldReader
		//need "r=o" order to make the "ot" time limitation work.
		//In fact, Vienna used successfully "r=n" with Google Reader.
		itemsLimitation = [NSString stringWithFormat:@"&ot=%@&n=500",folderLastUpdateString];

	if (![self isReady])
		[self authenticate];

    NSString* feedIdentifier;
    if( hostRequiresLastPathOnly )
    {
        feedIdentifier = [[thisFolder feedURL] lastPathComponent];
    }
    else
    {
    	feedIdentifier =  [thisFolder feedURL];
    }
		
	NSURL *refreshFeedUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@stream/contents/feed/%@?client=%@&comments=false&likes=false%@&ck=%@&output=json",APIBaseURL,
                                                  percentEscape(feedIdentifier),ClientName,itemsLimitation,TIMESTAMP]];
		
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:refreshFeedUrl];	
	[request setDelegate:self];
	[request setDidFinishSelector:@selector(feedRequestDone:)];
	[request setDidFailSelector:@selector(feedRequestFailed:)];
	[request setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:thisFolder, @"folder",aItem, @"log",folderLastUpdateString,@"lastupdatestring", [NSNumber numberWithInt:MA_Refresh_GoogleFeed], @"type", nil]];
	[request addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	[request setUseCookiePersistence:NO];
	
	return request;
}

// callback : handler for timed out feeds, etc...
- (void)feedRequestFailed:(ASIHTTPRequest *)request
{
	ActivityItem *aItem = [[request userInfo] objectForKey:@"log"];
	Folder *refreshedFolder = [[request userInfo] objectForKey:@"folder"];

	[aItem appendDetail:[NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"Error", nil),[[request error] localizedDescription ]]];
	[aItem setStatus:NSLocalizedString(@"Error", nil)];
	[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
	[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
}

// callback
- (void)feedRequestDone:(ASIHTTPRequest *)request
{
	dispatch_queue_t queue = [[RefreshManager sharedManager] asyncQueue];
	dispatch_async(queue, ^() {
		
	ActivityItem *aItem = [[request userInfo] objectForKey:@"log"];
	Folder *refreshedFolder = [[request userInfo] objectForKey:@"folder"];
	LLog(@"Refresh Done: %@",[refreshedFolder feedURL]);

	if ([request responseStatusCode] == 404) {
		[aItem appendDetail:NSLocalizedString(@"Error: Feed not found!", nil)];
		[aItem setStatus:NSLocalizedString(@"Error", nil)];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
	} else if ([request responseStatusCode] == 200) {
		NSData *data = [request responseData];
		NSDictionary * dict;
		@synchronized(jsonDecoder) {
			dict = [[NSDictionary alloc] initWithDictionary:[jsonDecoder objectWithData:data]];
		}
		NSString *folderLastUpdateString = [[dict objectForKey:@"updated"] stringValue];
		if ([folderLastUpdateString isEqualToString:@""] || [folderLastUpdateString isEqualToString:@"(null)"]) {
			LOG_EXPR([request url]);
			NSLog(@"Feed name: %@",[dict objectForKey:@"title"]);
			NSLog(@"Last Check: %@",[[request userInfo] objectForKey:@"lastupdatestring"]);
			NSLog(@"Last update: %@",folderLastUpdateString);
			NSLog(@"Found %lu items", (unsigned long)[[dict objectForKey:@"items"] count]);
			LOG_EXPR(dict);
			LOG_EXPR([[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
			ALog(@"Error !!! Incoherent data !");
			//keep the previously recorded one
			folderLastUpdateString = [[request userInfo] objectForKey:@"lastupdatestring"];
		}
	
		// Log number of bytes we received
		[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%ld bytes received", nil), [data length]]];
					
		LLog(@"%ld items returned from %@", [[dict objectForKey:@"items"] count], [request url]);
		NSMutableArray * articleArray = [NSMutableArray array];
		
		for (NSDictionary *newsItem in (NSArray*)[dict objectForKey:@"items"]) {
			
			NSDate * articleDate = [NSDate dateWithTimeIntervalSince1970:[[newsItem objectForKey:@"published"] doubleValue]];
			NSString * articleGuid = [newsItem objectForKey:@"id"];
			Article *article = [[[Article alloc] initWithGuid:articleGuid] autorelease];
			[article setFolderId:[refreshedFolder itemId]];
		
			if ([newsItem objectForKey:@"author"] != nil) {
				[article setAuthor:[newsItem objectForKey:@"author"]];
			} else {
				[article setAuthor:@""];
			}
		
			if ([newsItem objectForKey:@"content"] != nil ) {
				[article setBody:[[newsItem objectForKey:@"content"] objectForKey:@"content"]];
			} else if ([newsItem objectForKey:@"summary"] != nil ) {
				[article setBody:[[newsItem objectForKey:@"summary"] objectForKey:@"content"]];
			} else {
				[article setBody:@"Not available..."];
			}
			
			for (NSString * category in (NSArray*)[newsItem objectForKey:@"categories"])
			{
				if ([category hasSuffix:@"/read"]) [article markRead:YES];
				if ([category hasSuffix:@"/starred"]) [article markFlagged:YES];
				if ([category hasSuffix:@"/kept-unread"]) [article markRead:NO];
			}
				
			if ([newsItem objectForKey:@"title"]!=nil) {
				[article setTitle:[[newsItem objectForKey:@"title"] summaryTextFromHTML]];
                
			} else {
				[article setTitle:@""];
			}
			
			if ([[newsItem objectForKey:@"alternate"] count] != 0) {
				[article setLink:[[[newsItem objectForKey:@"alternate"] objectAtIndex:0] objectForKey:@"href"]];
			} else {
				[article setLink:[refreshedFolder feedURL]];
			}
		
			[article setDate:articleDate];

			if ([[newsItem objectForKey:@"enclosure"] count] != 0) {
				[article setEnclosure:[[[newsItem objectForKey:@"enclosure"] objectAtIndex:0] objectForKey:@"href"]];
			} else {
				[article setEnclosure:@""];
			}
		
			if ([[article enclosure] isNotEqualTo:@""])
				{
					[article setHasEnclosure:YES];
				}

			[articleArray addObject:article];
		}
			
		Database *dbManager = [Database sharedManager];
		NSInteger newArticlesFromFeed = 0;

		// Here's where we add the articles to the database
		if ([articleArray count] > 0)
		{
			NSArray * guidHistory = [dbManager guidHistoryForFolderId:[refreshedFolder itemId]];
			[refreshedFolder clearCache];
			//BOOL hasCache = [db initArticleArray:refreshedFolder];

			for (Article * article in articleArray)
			{
                if ([dbManager createArticle:[refreshedFolder itemId] article:article guidHistory:guidHistory] &&
                    ([article status] == ArticleStatusNew)) {
					newArticlesFromFeed++;
                }
			}

			// Set the last update date for this folder.
            [dbManager setLastUpdate:[NSDate date] forFolder:refreshedFolder.itemId];
            
		}

        if ([folderLastUpdateString isEqualToString:@""] || [folderLastUpdateString isEqualToString:@"(null)"]) {
            folderLastUpdateString=@"0";
        }

		// Set the last update date given by the Open Reader server for this folder.
        [dbManager setLastUpdateString:folderLastUpdateString forFolder:refreshedFolder.itemId];
		// Set the HTML homepage for this folder.
		// a legal JSON string can have, as its outer "container", either an array or a dictionary/"object"
        if ([[dict objectForKey:@"alternate"] isKindOfClass:[NSArray class]]) {
            [dbManager setHomePage:[[[dict objectForKey:@"alternate"] objectAtIndex:0] objectForKey:@"href"]
                         forFolder:refreshedFolder.itemId];
        }
        else {
            [dbManager setHomePage:[[dict objectForKey:@"alternate"] objectForKey:@"href"]
                         forFolder:refreshedFolder.itemId];
        }
		
		// Add to count of new articles so far
		countOfNewArticles += newArticlesFromFeed;

		// Unread count may have changed
		dispatch_async(dispatch_get_main_queue(), ^{
			AppController *controller = APPCONTROLLER;
			[controller setStatusMessage:nil persist:NO];
			[controller showUnreadCountOnApplicationIconAndWindowTitle];
			[refreshedFolder clearNonPersistedFlag:MA_FFlag_Error];

			// Send status to the activity log
			if (newArticlesFromFeed == 0)
				[aItem setStatus:NSLocalizedString(@"No new articles available", nil)];
			else
			{
				[aItem setStatus:[NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newArticlesFromFeed]];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListStateChange" object:refreshedFolder];
			}
		});
		
		[dict release];

		NSString* feedIdentifier;
		if( hostRequiresLastPathOnly )
		{
			feedIdentifier = [[refreshedFolder feedURL] lastPathComponent];
		}
		else
		{
			feedIdentifier =  [refreshedFolder feedURL];
		}

		// Request id's of unread items
		NSString * args = [NSString stringWithFormat:@"?ck=%@&client=%@&s=feed/%@&xt=user/-/state/com.google/read&n=1000&output=json", TIMESTAMP, ClientName,
                           percentEscape(feedIdentifier)];
		NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", APIBaseURL, @"stream/items/ids", args]];
		ASIHTTPRequest *request2 = [ASIHTTPRequest requestWithURL:url];
		[request2 setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:refreshedFolder, @"folder", aItem, @"log", nil]];
		[request2 setDelegate:self];
		[request2 setDidFinishSelector:@selector(readRequestDone:)];
		[request2 addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
		[request2 setUseCookiePersistence:NO];
		[request2 setTimeOutSeconds:180];
		[[RefreshManager sharedManager] addConnection:request2];

		// Request id's of starred items
		// Note: Inoreader requires syntax "it=user/-/state/...", while TheOldReader ignores it and requires "s=user/-/state/..."
		NSString* starredSelector;
		if (hostRequiresSParameter)
		{
			starredSelector=@"s=user/-/state/com.google/starred";
		}
		else
		{
			starredSelector=@"it=user/-/state/com.google/starred";
		}

		NSString * args3 = [NSString stringWithFormat:@"?ck=%@&client=%@&s=feed/%@&%@&n=1000&output=json", TIMESTAMP, ClientName, percentEscape(feedIdentifier), starredSelector];
		NSURL * url3 = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", APIBaseURL, @"stream/items/ids", args3]];
		ASIHTTPRequest *request3 = [ASIHTTPRequest requestWithURL:url3];
		[request3 setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:refreshedFolder, @"folder", aItem, @"log", nil]];
		[request3 setDelegate:self];
		[request3 setDidFinishSelector:@selector(starredRequestDone:)];
		[request3 addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
		[request3 setUseCookiePersistence:NO];
		[request3 setTimeOutSeconds:180];
		[[RefreshManager sharedManager] addConnection:request3];

	} else { //other HTTP status response...
		[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil), [request responseStatusCode]]];
		LOG_EXPR([request originalURL]);
		LOG_EXPR([request requestHeaders]);
		LOG_EXPR([[[NSString alloc] initWithData:[request postBody] encoding:NSUTF8StringEncoding] autorelease]);
		LOG_EXPR([request responseHeaders]);
		LOG_EXPR([[[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding] autorelease]);
		[aItem setStatus:NSLocalizedString(@"Error", nil)];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
	}
	}); //block for dispatch_async
}

// callback
- (void)readRequestDone:(ASIHTTPRequest *)request
{
	Folder *refreshedFolder = [[request userInfo] objectForKey:@"folder"];
	ActivityItem *aItem = [[request userInfo] objectForKey:@"log"];
	if ([request responseStatusCode] == 200)
	{
	@try {
		NSArray * dict;
		@synchronized(jsonDecoder) {
			dict =  (NSArray *)[[jsonDecoder objectWithData:[request responseData]]  objectForKey:@"itemRefs"];
		}
		NSMutableArray * guidArray = [NSMutableArray arrayWithCapacity:[dict count]];
		for (NSDictionary *itemRef in dict)
		{
            NSString * guid;
            if( hostSupportsLongId )
            {
                guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%@",[itemRef objectForKey:@"id"]];
            }
            else
            {
				// as described in http://code.google.com/p/google-reader-api/wiki/ItemId
				// the short version of id is a base 10 signed integer ; the long version includes a 16 characters base 16 representation
                NSInteger shortId = [[itemRef objectForKey:@"id"] integerValue];
                guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%016qx",(long long)shortId];
            }

            [guidArray addObject:guid];
		}
		LLog(@"%ld unread items for %@", [guidArray count], [request url]);

        [[Database sharedManager] markUnreadArticlesFromFolder:refreshedFolder guidArray:guidArray];

	} @catch (NSException *exception) {
		[aItem appendDetail:[NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"Error", nil),exception]];
		[aItem setStatus:NSLocalizedString(@"Error", nil)];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[refreshedFolder itemId]]];
		return;
	}  // try/catch


		// If this folder also requires an image refresh, add that
		dispatch_queue_t queue = [[RefreshManager sharedManager] asyncQueue];
		if ([refreshedFolder flags] & MA_FFlag_CheckForImage)
			dispatch_async(queue, ^() {
				[[RefreshManager sharedManager] refreshFavIconForFolder:refreshedFolder];
			});

	}
	else //response status other than OK (200)
	{
		[aItem appendDetail:[NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"Error", nil),[[request error] localizedDescription ]]];
		[aItem setStatus:NSLocalizedString(@"Error", nil)];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
	}

}

// callback
- (void)starredRequestDone:(ASIHTTPRequest *)request
{
	Folder *refreshedFolder = [[request userInfo] objectForKey:@"folder"];
	ActivityItem *aItem = [[request userInfo] objectForKey:@"log"];
	if ([request responseStatusCode] == 200)
	{
	@try {
		NSArray * dict;
		@synchronized(jsonDecoder) {
			dict =  (NSArray *)[[jsonDecoder objectWithData:[request responseData]]  objectForKey:@"itemRefs"];
		}
		NSMutableArray * guidArray = [NSMutableArray arrayWithCapacity:[dict count]];
		for (NSDictionary *itemRef in dict)
		{
            NSString * guid;
            if( hostSupportsLongId )
            {
                guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%@",[itemRef objectForKey:@"id"]];
            }
            else
            {
				// as described in http://code.google.com/p/google-reader-api/wiki/ItemId
				// the short version of id is a base 10 signed integer ; the long version includes a 16 characters base 16 representation
                NSInteger shortId = [[itemRef objectForKey:@"id"] integerValue];
                guid = [NSString stringWithFormat:@"tag:google.com,2005:reader/item/%016qx",(long long)shortId];
            }
			[guidArray addObject:guid];
		}
		LLog(@"%ld starred items for %@", [guidArray count], [request url]);

        [[Database sharedManager] markStarredArticlesFromFolder:refreshedFolder guidArray:guidArray];

		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
	} @catch (NSException *exception) {
		[aItem appendDetail:[NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"Error", nil),exception]];
		[aItem setStatus:NSLocalizedString(@"Error", nil)];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
	}  // try/catch
	}
	else //response status other than OK (200)
	{
		[aItem appendDetail:[NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"Error", nil),[[request error] localizedDescription ]]];
		[aItem setStatus:NSLocalizedString(@"Error", nil)];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[refreshedFolder itemId]]];
}

-(void)authenticate 
{    	
    Preferences * prefs = [Preferences standardPreferences];
	if (![prefs syncGoogleReader])
		return;
	if (googleReaderStatus != notAuthenticated) {
		LLog(@"Another instance is authenticating...");
		return;
	} else {
		LLog(@"Start first authentication...");
		googleReaderStatus = isAuthenticating;
		[APPCONTROLLER setStatusMessage:NSLocalizedString(@"Authenticating on Open Reader", nil) persist:NO];
	}
	
    // restore from Preferences and from keychain
    [username release];
	username = [[prefs syncingUser] retain];
	[openReaderHost release];
	openReaderHost = [[prefs syncServer] retain];
	// set server-specific particularities
	hostSupportsLongId=NO;
	hostRequiresSParameter=NO;
	hostRequiresLastPathOnly=NO;
	if([openReaderHost isEqualToString:@"theoldreader.com"]){
		hostSupportsLongId=YES;
		hostRequiresSParameter=YES;
		hostRequiresLastPathOnly=YES;
	}

	[password release];
	password = [[KeyChain getGenericPasswordFromKeychain:username serviceName:@"Vienna sync"] retain];
	[APIBaseURL release];
	APIBaseURL = [[NSString stringWithFormat:@"https://%@/reader/api/0/", openReaderHost] retain];

	NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:LoginBaseURL, openReaderHost]];
	ASIFormDataRequest *myRequest = [ASIFormDataRequest requestWithURL:url];
	[myRequest setPostValue:username forKey:@"Email"];
	[myRequest setPostValue:password forKey:@"Passwd"];
	[myRequest setUseCookiePersistence:NO];
	[myRequest setTimeOutSeconds:180];
	[myRequest startSynchronous];

	NSString * response = [myRequest responseString];
	if (!response || [myRequest responseStatusCode] != 200)
	{
		LOG_EXPR([myRequest responseStatusCode]);
		LOG_EXPR([myRequest responseHeaders]);
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_GoogleAuthFailed" object:nil];
		[APPCONTROLLER setStatusMessage:nil persist:NO];
		googleReaderStatus = notAuthenticated;
		[myRequest clearDelegatesAndCancel];
		return;
	}

	NSArray * components = [response componentsSeparatedByString:@"\n"];
	[myRequest clearDelegatesAndCancel];

	//NSString * sid = [[components objectAtIndex:0] substringFromIndex:4];		//unused
	//NSString * lsid = [[components objectAtIndex:1] substringFromIndex:5];	//unused
	[self setClientAuthToken:[NSString stringWithString:[[components objectAtIndex:2] substringFromIndex:5]]];

	[self getToken];

    if (authTimer == nil || ![authTimer isValid])
    	//new request every 6 days
    	authTimer = [NSTimer scheduledTimerWithTimeInterval:6*24*3600 target:self selector:@selector(resetAuthentication) userInfo:nil repeats:YES];
}

-(void)getToken
{
	LLog(@"Start Token Request!");
    ASIHTTPRequest * request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@token", APIBaseURL]]];
    [request setUseCookiePersistence:NO];
    [request addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
    [request addRequestHeader:@"Content-Type" value:@"application/x-www-form-urlencoded"];

    googleReaderStatus = isAuthenticating;
	[request setUseCookiePersistence:NO];
	[request setTimeOutSeconds:180];
    [request startSynchronous];
    if ([request error])
    {
		LOG_EXPR([request originalURL]);
		LOG_EXPR([request requestHeaders]);
		LOG_EXPR([[[NSString alloc] initWithData:[request postBody] encoding:NSUTF8StringEncoding] autorelease]);
		LOG_EXPR([request responseHeaders]);
		LOG_EXPR([[[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding] autorelease]);
		[self resetAuthentication];
		[request clearDelegatesAndCancel];
		return;
	}
    // Save token
    [self setToken:[request responseString]];
    [request clearDelegatesAndCancel];
	googleReaderStatus = isAuthenticated;

    if (tokenTimer == nil || ![tokenTimer isValid])
    	//tokens expire after 30 minutes : renew them every 25 minutes
    	tokenTimer = [NSTimer scheduledTimerWithTimeInterval:25*60 target:self selector:@selector(getToken) userInfo:nil repeats:YES];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"GRSync_Autheticated" object:nil];
}

-(void)clearAuthentication
{
	googleReaderStatus = notAuthenticated;
	[self setClientAuthToken:nil];
	[self setToken:nil];
}

-(void)resetAuthentication
{
	[self clearAuthentication];
	[self authenticate];
}

-(void)submitLoadSubscriptions {
	
	[APPCONTROLLER setStatusMessage:NSLocalizedString(@"Fetching Open Reader Subscriptions...", nil) persist:NO];


	ASIHTTPRequest *subscriptionRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/list?client=%@&output=json",APIBaseURL,ClientName]]];
	[subscriptionRequest setDelegate:self];
	[subscriptionRequest setDidFinishSelector:@selector(subscriptionsRequestDone:)];
	[subscriptionRequest addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	[subscriptionRequest setUseCookiePersistence:NO];
	LLog(@"Starting subscriptionRequest");
	[subscriptionRequest setTimeOutSeconds:180];
	[[RefreshManager sharedManager] addConnection:subscriptionRequest];
	LLog(@"subscriptionRequest submitted");	
}

-(void)subscriptionsRequestDone:(ASIHTTPRequest *)request
{
	LLog(@"Ending subscriptionRequest");
	NSDictionary * dict;
	@synchronized(jsonDecoder) {
		dict = [jsonDecoder objectWithData:[request responseData]];
	}
	[localFeeds removeAllObjects];
	NSArray * localFolders = [APPCONTROLLER folders];
	
	for (Folder * f in localFolders) {
		if ([f feedURL]) {
			[localFeeds addObject:[f feedURL]];
		}
	}
			
	NSMutableArray * googleFeeds=[[NSMutableArray alloc] init];

	for (NSDictionary * feed in [dict objectForKey:@"subscriptions"]) 
	{
		NSString * feedID = [feed objectForKey:@"id"];
		if (feedID == nil)
			break;
		NSString * feedURL = [feedID stringByReplacingOccurrencesOfString:@"feed/" withString:@"" options:0 range:NSMakeRange(0, 5)];
		if (![feedURL hasPrefix:@"http:"] && ![feedURL hasPrefix:@"https:"])
            feedURL = [NSString stringWithFormat:@"https://%@/reader/public/atom/%@", openReaderHost, feedURL];
		
		NSString * folderName = nil;
		
		NSArray * categories = [feed objectForKey:@"categories"];
		for (NSDictionary * category in categories)
		{
			if ([category objectForKey:@"label"])
			{
				NSString * label = [category objectForKey:@"label"];
				NSArray * folderNames = [label componentsSeparatedByString:@" — "];  
				folderName = [folderNames lastObject];
				// NNW nested folder char: — 
				
				NSMutableArray * params = [NSMutableArray arrayWithObjects:[[folderNames mutableCopy] autorelease], [NSNumber numberWithInt:MA_Root_Folder], nil];
				[self createFolders:params];
				break; //In case of multiple labels, we retain only the first one
			} 
		}
		
		if (![localFeeds containsObject:feedURL])
		{
			NSString *rssTitle = nil;
			if ([feed objectForKey:@"title"]) {
				rssTitle = [feed objectForKey:@"title"];
			}
			NSArray * params = [NSArray arrayWithObjects:feedURL, rssTitle, folderName, nil];
			[self createNewSubscription:params];
		}
		else
		{
			// the feed is already known
			// set HomePage if the info is available
			NSString* homePageURL = [feed objectForKey:@"htmlUrl"];
			if (homePageURL) {
				for (Folder * f in localFolders) {
					if (IsGoogleReaderFolder(f) && [[f feedURL] isEqualToString:feedURL]) {
                        [[Database sharedManager] setHomePage:homePageURL forFolder:f.itemId];
						break;
					}
				}
			}
		}

        [googleFeeds addObject:feedURL];
	}
	
	//check if we have a folder which is not registered as a Open Reader feed
	for (Folder * f in [APPCONTROLLER folders]) {
		if (IsGoogleReaderFolder(f) && ![googleFeeds containsObject:[f feedURL]])
		{
			[[Database sharedManager] deleteFolder:[f itemId]];
		}
	}

	AppController *controller = APPCONTROLLER;
	
	// Unread count may have changed
	[controller setStatusMessage:nil persist:NO];
	
	[googleFeeds release];
	
}

-(void)loadSubscriptions:(NSNotification *)nc
{
	if (nc != nil) {
		LLog(@"Firing after notification");
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"GRSync_Autheticated" object:nil];		
		[self submitLoadSubscriptions];
	} else {
		LLog(@"Firing directly");

		if ([self isReady]) {
			LLog(@"Token available, finish subscription");
			[self submitLoadSubscriptions];
		} else {
			LLog(@"Token not available, registering for notification");
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadSubscriptions:) name:@"GRSync_Autheticated" object:nil];
			[self authenticate];
		}
	}
}

-(void)subscribeToFeed:(NSString *)feedURL 
{
	if (![self isReady])
		[self authenticate];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/quickadd?client=%@",APIBaseURL,ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:feedURL forKey:@"quickadd"];
    [request setDelegate:self];
	[request setPostValue:token forKey:@"T"];
   	[request addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	[request setUseCookiePersistence:NO];
	[request setTimeOutSeconds:180];
    // Needs to be synchronous so UI doesn't refresh too soon.
    [request startSynchronous];
    LLog(@"Subscribe response status code: %d", [request responseStatusCode]);
    [request clearDelegatesAndCancel];
}

-(void)unsubscribeFromFeed:(NSString *)feedURL 
{
	if (![self isReady])
		[self authenticate];
	NSURL *unsubscribeURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit",APIBaseURL]];
	ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:unsubscribeURL];
	[myRequest setPostValue:@"unsubscribe" forKey:@"ac"];
	[myRequest setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];
	[myRequest setPostValue:token forKey:@"T"];
	[myRequest addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	[myRequest setUseCookiePersistence:NO];
	[myRequest setTimeOutSeconds:180];
	[[RefreshManager sharedManager] addConnection:myRequest];
}

/* setFolderName
 * set or remove a folder name to a newsfeed
 * set parameter : TRUE => add ; FALSE => remove
 */
-(void)setFolderName:(NSString *)folderName forFeed:(NSString *)feedURL set:(BOOL)flag
{
	if (![self isReady])
		[self authenticate];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@",APIBaseURL,ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:@"edit" forKey:@"ac"];
    [request setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];
    [request setPostValue:[NSString stringWithFormat:@"user/-/label/%@", folderName] forKey:flag ? @"a" : @"r"];
    [request setDelegate:self];
	[request setPostValue:token forKey:@"T"];
	[request addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	[request setUseCookiePersistence:NO];
	[request setTimeOutSeconds:180];
    [request startSynchronous];
    LLog(@"Set folder response status code: %d", [request responseStatusCode]);
    [request clearDelegatesAndCancel];
}

-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag
{
	if (![self isReady])
		[self authenticate];
	NSURL *markReadURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@edit-tag",APIBaseURL]];
	ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:markReadURL];
	if (flag) {
		[myRequest setPostValue:@"user/-/state/com.google/read" forKey:@"a"];
	} else {
		[myRequest setPostValue:@"user/-/state/com.google/read" forKey:@"r"];
	}
	[myRequest setPostValue:@"true" forKey:@"async"];
	[myRequest setPostValue:itemGuid forKey:@"i"];
	[myRequest setDelegate:self];
	[myRequest setPostValue:token forKey:@"T"];
	[myRequest addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	[myRequest setUseCookiePersistence:NO];
	[myRequest setTimeOutSeconds:180];
	[[RefreshManager sharedManager] addConnection:myRequest];
}

-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag
{
	if (![self isReady])
		[self authenticate];
	NSURL *markStarredURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@edit-tag",APIBaseURL]];
	ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:markStarredURL];
	if (flag) {
		[myRequest setPostValue:@"user/-/state/com.google/starred" forKey:@"a"];
			
	} else {
		[myRequest setPostValue:@"user/-/state/com.google/starred" forKey:@"r"];
			
	}
	[myRequest setPostValue:@"true" forKey:@"async"];
	[myRequest setPostValue:itemGuid forKey:@"i"];
	[myRequest setDelegate:self];
	[myRequest setPostValue:token forKey:@"T"];
	[myRequest addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	[myRequest setUseCookiePersistence:NO];
	[myRequest setTimeOutSeconds:180];
	[[RefreshManager sharedManager] addConnection:myRequest];
}


-(void)dealloc 
{
	[localFeeds release];
	localFeeds=nil;
	[jsonDecoder release];
	jsonDecoder=nil;
    [username release];
    username=nil;
	[openReaderHost release];
	openReaderHost=nil;
	[password release];
	password=nil;
	[APIBaseURL release];
	APIBaseURL=nil;
	[clientAuthToken release];
	clientAuthToken=nil;
	[token release];
	token=nil;
	[tokenTimer release];
	tokenTimer=nil;
	[authTimer release];
	authTimer=nil;
	[super dealloc];
}

/* sharedManager
 * Returns the single instance of the Open Reader.
 */
+(GoogleReader *)sharedManager
{
	if (!_googleReader)
		_googleReader = [[GoogleReader alloc] init];
	return _googleReader;
}

-(void)createNewSubscription:(NSArray *)params
{
	LLog(@"createNewSubscription - START");
    NSInteger underFolder = MA_Root_Folder;
    NSString * feedURL = [params objectAtIndex:0];
	NSString *rssTitle = [NSString stringWithFormat:@""];
	
    if ([params count] > 1) 
    {
		if ([params count] > 2 ) {
			NSString * folderName = [params objectAtIndex:2];
			Database * db = [Database sharedManager];
			Folder * folder = [db folderFromName:folderName];
			underFolder = [folder itemId];
		}
		rssTitle = [params objectAtIndex:1];
    }
    
    [APPCONTROLLER createNewGoogleReaderSubscription:feedURL underFolder:underFolder withTitle:rssTitle afterChild:-1];

	LLog(@"createNewSubscription - END");

}

- (void)createFolders:(NSMutableArray *)params
{
	LLog(@"createFolder - START");
	
    NSMutableArray * folderNames = [params objectAtIndex:0];
    NSNumber * parentNumber = [params objectAtIndex:1];
    
    // Remove the parent parameter. We'll re-add it with a new value later.
    [params removeObjectAtIndex:1];
    
    Database * dbManager = [Database sharedManager];
    NSString * folderName = [folderNames objectAtIndex:0];
    Folder * folder = [dbManager folderFromName:folderName];
    
    if (!folder)
    {
		NSInteger newFolderId;
        newFolderId = [dbManager addFolder:[parentNumber intValue] afterChild:-1 folderName:folderName type:MA_Group_Folder canAppendIndex:NO];
 
        parentNumber = @(newFolderId);
    }
    else  {
        parentNumber = @(folder.itemId);
    }
    
    [folderNames removeObjectAtIndex:0];
    if ([folderNames count] > 0)
    {
        // Add the new parent parameter.
        [params addObject:parentNumber];
        [self createFolders:params];
    }
	
	LLog(@"createFolder - END");

}

@end
