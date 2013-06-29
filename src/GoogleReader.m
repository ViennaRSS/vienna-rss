//
//  GoogleReader.m
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011-2012 Vienna contributors (see Help/Acknowledgements for list of contributors). All rights reserved.
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
#import "GTMOAuth2WindowController.h"
#import "Folder.h"
#import "Database.h"
#import <Foundation/Foundation.h>
#import "Message.h"
#import "AppController.h"
#import "RefreshManager.h"
#import "Preferences.h"
#import "StringExtensions.h"
#import "NSNotificationAdditions.h"

#define TIMESTAMP [NSString stringWithFormat:@"%0.0f",[[NSDate date] timeIntervalSince1970]]

static NSString * openReaderHost = @"www.bazqux.com";
static NSString * LoginBaseURL = @"https://%@/accounts/ClientLogin?accountType=GOOGLE&service=reader&Email=%@&Passwd=%@";
NSString * APIBaseURL;
NSString* refererURL;
static NSString * ClientName = @"ViennaRSS";

static NSString * username = @"";
static NSString * password = @"";

// Singleton
static GoogleReader * _googleReader = nil;

enum GoogleReaderStatus {
	notAuthenticated = 0,
	isAutenthicating,
	isAuthenticated
} googleReaderStatus;


@implementation GoogleReader

@synthesize localFeeds;
@synthesize token;
@synthesize tokenTimer;

JSONDecoder * jsonDecoder;

-(BOOL)isReady
{
	return (googleReaderStatus == isAuthenticated);
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
		APIBaseURL = [[NSString stringWithFormat:@"https://%@/reader/api/0/", openReaderHost] retain];
		refererURL = [[NSString stringWithFormat:@"https://%@/", openReaderHost] retain];
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
	LOG_EXPR(requestResponse);
	if (![requestResponse isEqualToString:@"OK"]) {
		LLog(@"Error on request");
		LOG_EXPR([request error]);
		LOG_EXPR([request responseHeaders]);
		LOG_EXPR([request requestHeaders]);
		[self clearAuthentication];
	}
}

-(ASIHTTPRequest*)refreshFeed:(Folder*)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit
{				
	
	//This is a workaround throw a BAD folderupdate value on DB
	NSString *folderLastUpdate = ignoreLimit ? @"0" : [thisFolder lastUpdateString];
	if ([folderLastUpdate isEqualToString:@""] || [folderLastUpdate isEqualToString:@"(null)"]) folderLastUpdate=@"0";
	
	NSInteger articleLimit = ignoreLimit ? 10000 : 100;

	if (![self isReady])
		[self authenticate];
		
	NSURL *refreshFeedUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@stream/contents/feed/%@?client=%@&comments=false&likes=false&r=n&n=%li&ot=%@&ck=%@&T=%@&access_token=%@",APIBaseURL,[GTMOAuth2Authentication encodedOAuthValueForString:[thisFolder feedURL]],ClientName,articleLimit,folderLastUpdate,TIMESTAMP, token, token]];
		
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:refreshFeedUrl];	
	[request setDelegate:self];
	[request setDidFinishSelector:@selector(feedRequestDone:)];
	[request setDidFailSelector:@selector(feedRequestFailed:)];
	[request setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:thisFolder, @"folder",aItem, @"log",folderLastUpdate,@"lastupdate", [NSNumber numberWithInt:MA_Refresh_GoogleFeed], @"type", nil]];
	
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
		
	ActivityItem *aItem = [[request userInfo] objectForKey:@"log"];
	Folder *refreshedFolder = [[request userInfo] objectForKey:@"folder"];
    NSString *folderLastUpdate = [[request userInfo] objectForKey:@"lastupdate"];
	LLog(@"Refresh Done: %@",[refreshedFolder feedURL]);

	if ([request responseStatusCode] == 404) {
		[aItem appendDetail:NSLocalizedString(@"Error: Feed not found!", nil)];
		[aItem setStatus:NSLocalizedString(@"Error", nil)];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
	} else if ([request responseStatusCode] == 200) {
		NSData *data = [request responseData];
		NSDictionary * dict = [[NSDictionary alloc] initWithDictionary:[jsonDecoder objectWithData:data]];
		NSDate * updateDate = nil;
		
		if ([dict objectForKey:@"updated"] == nil) {
			LOG_EXPR([request url]);
			NSLog(@"Feed name: %@",[dict objectForKey:@"title"]);
			NSLog(@"Last Check: %@",folderLastUpdate);
			NSLog(@"Last update: %@",[dict objectForKey:@"updated"]);
			NSLog(@"Found %lu items", (unsigned long)[[dict objectForKey:@"items"] count]);
			LOG_EXPR(dict);
			LOG_EXPR([[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
			ALog(@"Error !!! Incoherent data !");
		}
		else
			updateDate = [NSDate dateWithTimeIntervalSince1970:[[dict objectForKey:@"updated"] doubleValue]];;
	
		// Log number of bytes we received
		[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%ld bytes received", nil), [data length]]];
					
		NSMutableArray * articleArray = [NSMutableArray array];
		
		for (NSDictionary *newsItem in (NSArray*)[dict objectForKey:@"items"]) {
			
			NSDate * articleDate = [NSDate dateWithTimeIntervalSince1970:[[newsItem objectForKey:@"published"] doubleValue]];
			NSString * articleGuid = [newsItem objectForKey:@"id"];
			Article *article = [[Article alloc] initWithGuid:articleGuid];
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
			
			if ([newsItem objectForKey:@"alternate"] != nil) {
				[article setLink:[[[newsItem objectForKey:@"alternate"] objectAtIndex:0] objectForKey:@"href"]];
			} else {
				[article setLink:[refreshedFolder feedURL]];
			}
		
			[article setDate:articleDate];

			if ([newsItem objectForKey:@"enclosure"] != nil) {
				[article setEnclosure:[[[newsItem objectForKey:@"enclosure"] objectAtIndex:0] objectForKey:@"href"]];
			} else {
				[article setEnclosure:@""];
			}
		
			if ([[article enclosure] isNotEqualTo:@""])
				{
					[article setHasEnclosure:YES];
				}

			[articleArray addObject:article];
			[article release];
		}
			
		Database *db = [Database sharedDatabase];
		NSInteger newArticlesFromFeed = 0;

			// Here's where we add the articles to the database
			if ([articleArray count] > 0)
			{
				NSArray * guidHistory = [db guidHistoryForFolderId:[refreshedFolder itemId]];

				[refreshedFolder clearCache];
				// Should we wrap the entire loop or just individual article updates?
				[db beginTransaction];
				//BOOL hasCache = [db initArticleArray:refreshedFolder];
					
				for (Article * article in articleArray)
				{
					if (!([db createArticle:[refreshedFolder itemId] article:article guidHistory:guidHistory] && ([article status] == MA_MsgStatus_New)))
					{
						[db markArticleRead:[refreshedFolder itemId] guid:[article guid] isRead:[article isRead]];
						[db markArticleFlagged:[refreshedFolder itemId] guid:[article guid] isFlagged:[article isFlagged]];
					}
					else
						newArticlesFromFeed++;
				}
				
				[db commitTransaction];
			}
							
			// Set the last update date for this folder.
			if (updateDate != nil)
				[db setFolderLastUpdate:[refreshedFolder itemId] lastUpdate:updateDate];
			// Set the HTML homepage for this folder.
			// a legal JSON string can have, as its outer "container", either an array or a dictionary/"object"
			if ([[dict objectForKey:@"alternate"] isKindOfClass:[NSArray class]])
				[db setFolderHomePage:[refreshedFolder itemId] newHomePage:[[[dict objectForKey:@"alternate"] objectAtIndex:0] objectForKey:@"href"]];
			else
				[db setFolderHomePage:[refreshedFolder itemId] newHomePage:[[dict objectForKey:@"alternate"] objectForKey:@"href"]];
		
		// Add to count of new articles so far
		countOfNewArticles += newArticlesFromFeed;

		AppController *controller = [NSApp delegate];
		
		// Unread count may have changed
		[controller setStatusMessage:nil persist:NO];
		[controller showUnreadCountOnApplicationIconAndWindowTitle];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Error];

		// Send status to the activity log
		if (newArticlesFromFeed == 0)
			[aItem setStatus:NSLocalizedString(@"No new articles available", nil)];
		else
		{
			[aItem setStatus:[NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newArticlesFromFeed]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"MA_Notify_ArticleListStateChange" object:nil];
		}
		
		[dict release];

		// If this folder also requires an image refresh, add that
		if ([refreshedFolder flags] & MA_FFlag_CheckForImage)
			[[RefreshManager sharedManager] performSelectorOnMainThread:@selector(refreshFavIcon:) withObject:refreshedFolder waitUntilDone:NO];

	} else { //other HTTP status response...
		[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil), [request responseStatusCode]]];
		[aItem setStatus:NSLocalizedString(@"Error", nil)];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[refreshedFolder itemId]]];

}

-(void)authenticate 
{    	
	if (![[Preferences standardPreferences] syncGoogleReader])
		return;
	if (googleReaderStatus != notAuthenticated) {
		LLog(@"Another instance is authenticating...");
		return;
	} else {
		LLog(@"Start first authentication...");
		googleReaderStatus = isAutenthicating;
		[[NSApp delegate] setStatusMessage:NSLocalizedString(@"Authenticating on Google Reader", nil) persist:NO];
	}
	
	NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:LoginBaseURL, openReaderHost, username, password]];
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
	[request startSynchronous];

	NSLog(@"Open Reader server auth reponse code: %d", [request responseStatusCode]);
	NSString * response = [request responseString];
	NSLog(@"Open Reader server auth response: %@", response);

	if (!response || [request responseStatusCode] != 200)
	{
		NSLog(@"Failed to authenticate with Open Reader server");
		return;
	}

	NSArray * components = [response componentsSeparatedByString:@"\n"];

	[clientAuthToken release];

	//NSString * sid = [[components objectAtIndex:0] substringFromIndex:4];		//unused
	//NSString * lsid = [[components objectAtIndex:1] substringFromIndex:5];	//unused
	clientAuthToken = [[NSString stringWithString:[[components objectAtIndex:2] substringFromIndex:5]] retain];

    request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@token", APIBaseURL]]];
    [request setUseCookiePersistence:NO];
    [request addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
    [request addRequestHeader:@"Content-Type" value:@"application/x-www-form-urlencoded"];

    [request startSynchronous];

    // Save token
    [token release];
    token = [request responseString];
    [token retain];

    if (tokenTimer == nil || ![tokenTimer isValid])
    	//TODO : review this ; do and when auth items expire ?
    	tokenTimer = [NSTimer scheduledTimerWithTimeInterval:60*60 target:self selector:@selector(resetAuthentication) userInfo:nil repeats:YES];

	googleReaderStatus = isAuthenticated;
}

-(void)clearAuthentication
{
	googleReaderStatus = notAuthenticated;
}

-(void)resetAuthentication
{
	[self clearAuthentication];
	[self authenticate];
}

-(void)submitLoadSubscriptions {
	
	[[NSApp delegate] setStatusMessage:@"Fetching Google Reader Subscriptions..." persist:NO];


	ASIHTTPRequest *subscriptionRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/list?client=%@&output=json&access_token=%@",APIBaseURL,ClientName,token]]];
	[subscriptionRequest setDelegate:self];
	[subscriptionRequest setDidFinishSelector:@selector(subscriptionsRequestDone:)];
	[subscriptionRequest addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	LLog(@"Starting subscriptionRequest");
	LOG_EXPR(subscriptionRequest);
	[subscriptionRequest startAsynchronous];		
	LLog(@"subscriptionRequest submitted");	
}

-(void)subscriptionsRequestDone:(ASIHTTPRequest *)request
{
	LLog(@"Ending subscriptionRequest");
	
	NSDictionary * dict = [jsonDecoder objectWithData:[request responseData]];
			
	[localFeeds removeAllObjects];
	
	for (Folder * f in [[NSApp delegate] folders]) {
		if ([f feedURL]) {
			[localFeeds addObject:[f feedURL]];
		}
	}
			
	NSMutableArray * googleFeeds=[[NSMutableArray alloc] init];

	for (NSDictionary * feed in [dict objectForKey:@"subscriptions"]) 
	{
		LOG_EXPR(feed);
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
				[self performSelectorOnMainThread:@selector(createFolders:) withObject:params waitUntilDone:YES];
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
			[self performSelectorOnMainThread:@selector(createNewSubscription:) withObject:params waitUntilDone:YES];
		}

        [googleFeeds addObject:feedURL];
	}
	
	//check if we have a folder which is not registered as a Google Reader feed
	for (Folder * f in [[NSApp delegate] folders]) {
		if (IsGoogleReaderFolder(f) && ![googleFeeds containsObject:[f feedURL]])
		{
			[[Database sharedDatabase] deleteFolder:[f itemId]];
		}
	}

	AppController *controller = [NSApp delegate];
	
	// Unread count may have changed
	[controller setStatusMessage:nil persist:NO];
	
	[googleFeeds release];
	
}

-(void)loadSubscriptions:(NSNotification *)nc
{
	if (nc != nil) {
		LLog(@"Firing after notification");
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"GRSync_Autheticated" object:nil];		
		[self performSelectorOnMainThread:@selector(submitLoadSubscriptions) withObject:nil waitUntilDone:YES];
	} else {
		LLog(@"Firing directly");

		if ([self isReady]) {
			LLog(@"Token available, finish subscription");
			[self performSelectorOnMainThread:@selector(submitLoadSubscriptions) withObject:nil waitUntilDone:YES];
		} else {
			LLog(@"Token not available, registering for notification");
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadSubscriptions:) name:@"GRSync_Autheticated" object:nil];
		}
	}
}

-(void)subscribeToFeed:(NSString *)feedURL 
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/quickadd?client=%@",APIBaseURL,ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:feedURL forKey:@"quickadd"];
    [request setDelegate:self];
	[request addRequestHeader:@"Referer" value:refererURL];
   	[request addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];

    // Needs to be synchronous so UI doesn't refresh too soon.
    [request startSynchronous];
    NSLog(@"Subscribe response status code: %d", [request responseStatusCode]);
}

-(void)unsubscribeFromFeed:(NSString *)feedURL 
{
	NSURL *unsubscribeURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?access_token=%@",APIBaseURL,token]];
	ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:unsubscribeURL];
	[myRequest setPostValue:@"unsubscribe" forKey:@"ac"];
	[myRequest setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];
	[myRequest addRequestHeader:@"Referer" value:refererURL];
	[myRequest addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];

	[myRequest startAsynchronous];		
}

-(void)setFolder:(NSString *)folderName forFeed:(NSString *)feedURL folderFlag:(BOOL)flag
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@",APIBaseURL,ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:@"edit" forKey:@"ac"];
    [request setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];
    [request setPostValue:[NSString stringWithFormat:@"user/-/label/%@", folderName] forKey:flag ? @"a" : @"r"];
    [request setDelegate:self];
	[request addRequestHeader:@"Referer" value:refererURL];
	[request addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
    [request startSynchronous];
    NSLog(@"Set folder response status code: %d", [request responseStatusCode]);
}

-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag
{
	if (![self isReady])
		[self authenticate];
	NSURL *markReadURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@edit-tag?access_token=%@",APIBaseURL,token]];
	ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:markReadURL];
	if (flag) {
		[myRequest setPostValue:@"user/-/state/com.google/read" forKey:@"a"];
		[myRequest setDelegate:self];
	} else {
		[myRequest setPostValue:@"user/-/state/com.google/kept-unread" forKey:@"a"];
		[myRequest setPostValue:@"user/-/state/com.google/read" forKey:@"r"];
		[myRequest setDelegate:self];
		[myRequest setDidFinishSelector:@selector(keptUnreadDone:)];
        [myRequest setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:itemGuid, @"guid", nil]];
	}
	[myRequest setPostValue:@"true" forKey:@"async"];
	[myRequest setPostValue:itemGuid forKey:@"i"];
	[myRequest addRequestHeader:@"Referer" value:refererURL];
	[myRequest addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	[myRequest startAsynchronous];
}

// callback
- (void)keptUnreadDone:(ASIFormDataRequest *)request
{
	NSString *requestResponse = [[[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding] autorelease];
	LOG_EXPR(requestResponse);
	if (![requestResponse isEqualToString:@"OK"]) {
		LLog(@"Error on request");
		LOG_EXPR([request error]);
		LOG_EXPR([request originalURL]);
		LOG_EXPR([request responseHeaders]);
		LOG_EXPR([request requestHeaders]);
		[self resetAuthentication];
	}

	LLog(@"Logged token: %@",token);
	NSURL *markReadURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@edit-tag?access_token=%@",APIBaseURL,token]];
    NSString *itemGuid = [[request userInfo] objectForKey:@"guid"];
	ASIFormDataRequest * request1 = [ASIFormDataRequest requestWithURL:markReadURL];
	[request1 setPostValue:@"true" forKey:@"async"];
	[request1 setPostValue:itemGuid forKey:@"i"];
	[request1 setPostValue:@"user/-/state/com.google/tracking-kept-unread" forKey:@"a"];
	[request1 addRequestHeader:@"Referer" value:refererURL];
	[request1 addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	[request1 startAsynchronous];
}


-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag
{
	if (![self isReady])
		[self authenticate];
	NSURL *markStarredURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@edit-tag?access_token=%@",APIBaseURL,token]];
	ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:markStarredURL];
	if (flag) {
		[myRequest setPostValue:@"user/-/state/com.google/starred" forKey:@"a"];
			
	} else {
		[myRequest setPostValue:@"user/-/state/com.google/starred" forKey:@"r"];
			
	}
	[myRequest setPostValue:@"true" forKey:@"async"];
	[myRequest setPostValue:itemGuid forKey:@"i"];
	[myRequest setDelegate:self];
	[myRequest addRequestHeader:@"Referer" value:refererURL];
	[myRequest addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", clientAuthToken]];
	[myRequest startAsynchronous];
}


-(void)dealloc 
{
	[localFeeds release];
	[jsonDecoder release];
	[super dealloc];
}

/* sharedManager
 * Returns the single instance of the Google Reader.
 */
+(GoogleReader *)sharedManager
{
	if (!_googleReader)
		_googleReader = [[GoogleReader alloc] init];
	return _googleReader;
}

-(void)createNewSubscription:(NSArray *)params
{
	NSLog(@"createNewSubscription - START");
    NSInteger underFolder = MA_Root_Folder;
    NSString * feedURL = [params objectAtIndex:0];
	NSString *rssTitle = [NSString stringWithFormat:@""];
	
    if ([params count] > 1) 
    {
		if ([params count] > 2 ) {
			NSString * folderName = [params objectAtIndex:2];
			Database * db = [Database sharedDatabase];
			Folder * folder = [db folderFromName:folderName];
			underFolder = [folder itemId];
		}
		rssTitle = [params objectAtIndex:1];
    }
    
    [[NSApp delegate] createNewGoogleReaderSubscription:feedURL underFolder:underFolder withTitle:rssTitle afterChild:-1];

	NSLog(@"createNewSubscription - END");

}

- (void)createFolders:(NSMutableArray *)params
{
	LLog(@"createFolder - START");
	
    NSMutableArray * folderNames = [params objectAtIndex:0];
    NSNumber * parentNumber = [params objectAtIndex:1];
    
    // Remove the parent parameter. We'll re-add it with a new value later.
    [params removeObjectAtIndex:1];
    
    Database * db = [Database sharedDatabase];
    NSString * folderName = [folderNames objectAtIndex:0];
    Folder * folder = [db folderFromName:folderName];
    
    if (!folder)
    {
        [db beginTransaction];
        NSInteger newFolderId = [db addFolder:[parentNumber intValue] afterChild:-1 folderName:folderName type:MA_Group_Folder canAppendIndex:NO];
        [db commitTransaction];
        
        parentNumber = [NSNumber numberWithInteger:newFolderId];
    }
    else parentNumber = [NSNumber numberWithInteger:[folder itemId]];
    
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
