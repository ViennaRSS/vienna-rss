//
//  GoogleReader.m
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GoogleReader.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "JSONKit.h"
#import "GTMHTTPFetcher.h"
#import "GTMHTTPFetcherLogging.h"
#import "Folder.h"
#import "Database.h"
#import <Foundation/Foundation.h>
#import "Message.h"
#import "AppController.h"

//Vienna keychain Google Reader name
static NSString *const kKeychainItemName = @"OAuth2 Vienna: Google Reader";

#define TIMESTAMP [NSString stringWithFormat:@"%0.0f",[[NSDate date] timeIntervalSince1970]]

static NSString * APIBaseURL = @"https://www.google.com/reader/api/0/";
static NSString * ClientName = @"ViennaRSS";

// Singleton
static GoogleReader * _googleReader = nil;

enum GoogleReaderStatus {
	notAuthenticated = 0,
	isAutenthicating,
	isAuthenticated,
	isTokenAcquired,
	isActionTokenAcquired
} googleReaderStatus;


@implementation GoogleReader

@synthesize readingList;
@synthesize localFeeds;
@synthesize token;
@synthesize readerUser;
@synthesize tokenTimer;
@synthesize actionToken;
@synthesize actionTokenTimer;


-(BOOL)isReady
{
	return (googleReaderStatus == isTokenAcquired || googleReaderStatus == isActionTokenAcquired);
}


- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
		localFeeds = [[[NSMutableArray alloc] init] retain]; 
		googleReaderStatus = notAuthenticated;
		[self authenticate];
	}
    
    return self;
}

-(ASIHTTPRequest*)refreshFeed:(Folder*)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit
{				
	
	//This is a workaround throw a BAD folderupdate value on DB
	NSString *folderLastUpdate = ignoreLimit ? @"0" : [thisFolder lastUpdateString];
	if ([folderLastUpdate isEqualToString:@"(null)"]) folderLastUpdate=@"0";
	
	NSInteger articleLimit = ignoreLimit ? 10000 : 100;
		
	NSURL *refreshFeedUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/stream/contents/feed/%@?client=scroll&comments=false&likes=false&r=n&n=%i&ot=%@&T=%@&access_token=%@", [GTMOAuth2Authentication encodedOAuthValueForString:[thisFolder feedURL]],articleLimit,folderLastUpdate, token, token]];
		
	__block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:refreshFeedUrl];
	
	[request setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:thisFolder, @"folder",aItem, @"log",nil]];
	[request setCompletionBlock:^{
		
		ActivityItem *aItem = [[request userInfo] objectForKey:@"log"];
		Folder *refreshedFolder = [[request userInfo] objectForKey:@"folder"];
		LLog(@"Refresh Done: %@",[refreshedFolder feedURL]);

		if ([request responseStatusCode] == 404) {
			[aItem appendDetail:NSLocalizedString(@"Error: Feed not found!", nil)];
			[aItem setStatus:NSLocalizedString(@"Error", nil)];
			//TOFIX: Where is the error flag ?!?!?!?
			[refreshedFolder setFlag:MA_FFlag_Error];
		} else if ([request responseStatusCode] == 200) {
			NSData *data = [request responseData];		
			NSDictionary * dict = [[NSDictionary alloc] initWithDictionary:[[JSONDecoder decoder] objectWithData:data]];		
			
			if ([dict objectForKey:@"updated"] == nil) {
				LOG_EXPR([request url]);
				NSLog(@"Feed name: %@",[dict objectForKey:@"title"]);
				NSLog(@"Last Check: %@",folderLastUpdate);
				NSLog(@"Last update: %@",[dict objectForKey:@"updated"]);
				NSLog(@"Found %lu items", (unsigned long)[[dict objectForKey:@"items"] count]);
				LOG_EXPR(dict);
				NSString *tmp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
				LOG_EXPR(tmp);
				ALog(@"Errore!!!!");
			}
		
			// Log number of bytes we received
			[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%ld bytes received", nil), [data length]]];
						
			NSMutableArray * articleArray = [NSMutableArray array];
			NSMutableArray * articleGuidArray = [NSMutableArray array];
			
			for (NSDictionary *newsItem in (NSArray*)[dict objectForKey:@"items"]) {
				
				NSDate * articleDate = [NSDate dateWithTimeIntervalSince1970:[[newsItem objectForKey:@"published"] doubleValue]];
				NSString * articleGuid = [newsItem objectForKey:@"id"];
				[articleGuidArray addObject:articleGuid];
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
					if ([category hasSuffix:@"starred"]) [article markFlagged:YES];
					if ([category hasSuffix:@"/kept-unread"]) [article markRead:NO];
				}
					
				if ([newsItem objectForKey:@"title"]!=nil) {	
					[article setTitle:[newsItem objectForKey:@"title"]];
				} else {
					[article setTitle:@""];
				}
				
				if ([newsItem objectForKey:@"alternate"] != nil) {
					[article setLink:[[[newsItem objectForKey:@"alternate"] objectAtIndex:0] objectForKey:@"href"]];
				} else {
					[article setLink:[refreshedFolder feedURL]];
				}
			
				[article setDate:articleDate];
				[article setEnclosure:@""];
				/*	
				if ([[article enclosure] isNotEqualTo:@""])
					{
						[article setHasEnclosure:YES];
					}
				 */
				[articleArray addObject:article];
				[article release];
			}
				
			Database *db = [Database sharedDatabase];
			[db setFolderLastUpdateString:[refreshedFolder itemId] lastUpdateString:[NSString stringWithFormat:@"%@",[dict objectForKey:@"updated"]]];

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
						[db markArticleRead:[refreshedFolder itemId] guid:[article guid] isRead:[article isRead]];
					else
						newArticlesFromFeed++;
				}	
						
					
				[db commitTransaction];				
			}
								
				// Let interested callers know that the folder has changed.
				//[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[refreshedFolder itemId]]];
				//[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListStateChange" object:nil];
			
			// Mark the feed as succeeded
			//[self setFolderErrorFlag:folder flag:NO];
			
			// Set the last update date for this folder.
			[db setFolderLastUpdate:[refreshedFolder itemId] lastUpdate:[NSDate date]];
			
			AppController *controller = [NSApp delegate];
			
			// Unread count may have changed
			[controller setStatusMessage:nil persist:NO];
			[controller showUnreadCountOnApplicationIconAndWindowTitle];
			[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];

			
			//[self setFolderUpdatingFlag:refreshedFolder flag:NO];
			
			
		
			// Send status to the activity log
			if (newArticlesFromFeed == 0)
				[aItem setStatus:NSLocalizedString(@"No new articles available", nil)];
			else
				[aItem setStatus:[NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newArticlesFromFeed]];
			
			
		// FIX: check when reload icons
		//if ([folder flags] & MA_FFlag_CheckForImage)
		//	[self refreshFavIcon:folder];
			
		// Add to count of new articles so far
		//countOfNewArticles += newArticlesFromFeed;
			
			[dict release];
		} else {
			ALog(@"Error code non gestito! %d",[request responseStatusCode]);
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[refreshedFolder itemId]]];

	}];
	
	[request setFailedBlock:^{
		LOG_EXPR([request error]);
	}];
	
	return request;
}


-(void)requestFinished:(ASIHTTPRequest *)request
{
    NSLog(@"HTTP response status code: %d -- URL: %@", [request responseStatusCode], [[request url] absoluteString]);
	NSString *tmp = [[[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding] autorelease];
	LOG_EXPR(tmp);
}


-(void)refreshGoogleAccessToken:(NSTimer*)timer
{
	LLog(@"Access Token expired!!! Refreshing it!");
	googleReaderStatus = isAuthenticated;
	LLog([self getGoogleOAuthToken]);
}



-(void)refreshGoogleActionToken:(NSTimer*)timer
{
	LLog(@"Action Token expired!!! Refreshing it!");
	googleReaderStatus = isTokenAcquired;
	LLog([self getGoogleActionToken]);
}

-(NSString *)getGoogleActionToken
{
		
	if (actionTokenTimer != nil && googleReaderStatus == isActionTokenAcquired) {
		LLog(@"An action token is available: %@",actionToken);
		return actionToken;
	}
	
	if (googleReaderStatus == isTokenAcquired) {
		
		// If we have a not expired access token, simply return it :)
		
		NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/token?client=scroll&access_token=%@",token]];
		ASIHTTPRequest * tokenRequest = [ASIHTTPRequest requestWithURL:tokenURL];
		
		LLog(@"Start Action Token Request!");
		[tokenRequest startSynchronous];
		LLog(@"End Action Token Request!");
		
		if ([tokenRequest error]) {
			LLog(@"Error getting the action token");
			LOG_EXPR([tokenRequest error]);
			LOG_EXPR([tokenRequest responseHeaders]);
			return nil;
		} else {
			LLog(@"Action Token Acquired");
			googleReaderStatus = isActionTokenAcquired;
			[actionToken release];
			actionToken = [[[NSString alloc] initWithData:[tokenRequest responseData] encoding:NSUTF8StringEncoding] retain];
			LOG_EXPR(actionToken);
			
			//let expire in 25 mins instead of 30
			actionTokenTimer = [NSTimer scheduledTimerWithTimeInterval:1500 target:self selector:@selector(refreshGoogleActionToken:) userInfo:nil repeats:YES];
			//tokenTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(refreshGoogleAccessToken:) userInfo:nil repeats:YES];
			
			return actionToken;
		}
	} else {
		return nil;
	}
}


-(NSString *)getGoogleOAuthToken
{
	
	[[NSApp delegate] setStatusMessage:NSLocalizedString(@"Acquiring OAuth 2.0 token...", nil) persist:NO];
	
	if (token != nil && googleReaderStatus == isTokenAcquired) {
		LLog(@"A token is available: %@",token);
		return token;
	}
	
	if (googleReaderStatus == isAuthenticated) {
		
		// If we have a not expired access token, simply return it :)
		
		NSURL *tokenURL = [NSURL URLWithString:@"https://accounts.google.com/o/oauth2/token"];
		ASIFormDataRequest * tokenRequest = [ASIFormDataRequest requestWithURL:tokenURL];
		
		[tokenRequest setPostValue:oAuthObject.refreshToken forKey:@"refresh_token"];
		[tokenRequest setPostValue:@"49097391685.apps.googleusercontent.com" forKey:@"client_id"];
		[tokenRequest setPostValue:@"0wzzJCfkcNPeqKgjo-pfPZSA" forKey:@"client_secret"];
		[tokenRequest setPostValue:@"refresh_token" forKey:@"grant_type"];

		LLog(@"Start Token Request!");
		[tokenRequest startSynchronous];
		LLog(@"End Token Request!");
		
		if ([tokenRequest error]) {
			LLog(@"Error getting the OAuth 2.0 token");
			LOG_EXPR([tokenRequest error]);
			LOG_EXPR([tokenRequest responseHeaders]);
			return nil;
		} else {
			LLog(@"OAuth 2.0 Token Acquired");
			googleReaderStatus = isTokenAcquired;
#ifdef DEBUG
			NSString *tmpToken = [[NSString alloc] initWithData:[tokenRequest responseData] encoding:NSUTF8StringEncoding];
			LOG_EXPR(tmpToken);
			[tmpToken release];
#endif
			
			NSData * jsonData = [tokenRequest responseData];
			JSONDecoder * jsonDecoder = [JSONDecoder decoder];
			NSDictionary * dict = [jsonDecoder objectWithData:jsonData];
			[token release];
			token = [[dict objectForKey:@"access_token"] retain];
			//LOG_EXPR(token);

			tokenTimer = [NSTimer scheduledTimerWithTimeInterval:(NSInteger)[dict objectForKey:@"expires_in"] target:self selector:@selector(refreshGoogleAccessToken:) userInfo:nil repeats:YES];
			//tokenTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(refreshGoogleAccessToken:) userInfo:nil repeats:YES];
			
			return token;
		}
	} else {
		return nil;
	}
}

-(void)handleGoogleLoginRequest
{
	googleReaderStatus = isAutenthicating;
	
	GTMOAuth2WindowController *windowController = [GTMOAuth2WindowController controllerWithScope:@"https://www.google.com/reader/api"
																						clientID:@"49097391685.apps.googleusercontent.com"
																					clientSecret:@"0wzzJCfkcNPeqKgjo-pfPZSA"
																				keychainItemName:kKeychainItemName
																				  resourceBundle:nil];
	
	// Optional: display some html briefly before the sign-in page loads
	NSString *html = @"<html><body><div align=center>Loading sign-in page...</div></body></html>";
	windowController.initialHTMLString = html;
	
	[windowController signInSheetModalForWindow:nil completionHandler:^(GTMOAuth2Authentication *auth, NSError *error) {
		
		if (error != nil) {
			// Authentication failed
			googleReaderStatus = notAuthenticated;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_GoogleAuthFailed" object:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_AuthFailed" object:nil];
		} else {
			// Authentication succeeded
			oAuthObject = [auth retain];
			googleReaderStatus = isAuthenticated;
			if ([self getGoogleOAuthToken] != nil) {
				[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];
			} else {
				//TOFIX
				//Handle token request
			}
		}
		
	}];
}


-(void)authenticate 
{    	
	if (googleReaderStatus != notAuthenticated) {
		LLog(@"Another instance is authenticating...");
		return;
	} else {
		LLog(@"Start first authentication...");
		googleReaderStatus = isAutenthicating;
		[[NSApp delegate] setStatusMessage:NSLocalizedString(@"Authenticating on Google Reader", nil) persist:NO];
	}
	
	oAuthObject = [[GTMOAuth2WindowController authForGoogleFromKeychainForName:kKeychainItemName
																					   clientID:@"49097391685.apps.googleusercontent.com"
																				   clientSecret:@"0wzzJCfkcNPeqKgjo-pfPZSA"] retain];	
	if (oAuthObject != nil && [oAuthObject canAuthorize]) {
		LLog(@"Google OAuth 2.0 - OAuth token acquired from keychain");
		googleReaderStatus = isAuthenticated;	
		if ([self getGoogleOAuthToken] != nil) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];
		} else {
			//TOFIX
			//Handle token request
		}
	} else {
		[self performSelectorOnMainThread:@selector(handleGoogleLoginRequest) withObject:nil waitUntilDone:YES];
	}
}

-(void)loadReadingList
{
    NSString * args = [NSString stringWithFormat:@"?ck=%@&client=%@&output=json&n=10000&includeAllDirectSreamIds=true", TIMESTAMP, ClientName];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", APIBaseURL, @"stream/contents/user/-/state/com.google/reading-list", args]];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request startSynchronous];

    NSLog(@"Load reading list response code: %d", [request responseStatusCode]);
    
    NSData * jsonData = [request responseData];
    JSONDecoder * jsonDecoder = [JSONDecoder decoder];
    NSDictionary * dict = [jsonDecoder objectWithData:jsonData];
    [self setReadingList:[dict objectForKey:@"items"]];
}                



-(void)completeLoadSubscriptions {
	
	LLog(@"START");	
	[[NSApp delegate] setStatusMessage:@"Fetching Google Reader Subscriptions..." persist:NO];


	__block ASIHTTPRequest *subscriptionRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/subscription/list?client=scroll&output=json&access_token=%@",token]]];
		
	[subscriptionRequest setFailedBlock:^{
		LLog(@"Error on subscriptionRequest");
		LOG_EXPR([subscriptionRequest error]);
		LOG_EXPR([subscriptionRequest responseHeaders]);
	}];
		
	[subscriptionRequest setCompletionBlock:^{
		LLog(@"Finish subscriptionRequest");

		
		JSONDecoder * jsonDecoder = [JSONDecoder decoder];
		NSDictionary * dict = [jsonDecoder objectWithData:[subscriptionRequest responseData]];
				
		[localFeeds removeAllObjects];
		
		for (Folder * f in [[NSApp delegate] folders]) {
			if ([f feedURL]) {
				[localFeeds addObject:[f feedURL]];
			}
		}
				
		for (NSDictionary * feed in [dict objectForKey:@"subscriptions"]) 
		{
			LOG_EXPR(feed);
			NSString * feedID = [feed objectForKey:@"id"];
			NSString * feedURL = [feedID stringByReplacingOccurrencesOfString:@"feed/" withString:@"" options:NULL range:NSMakeRange(0, 5)];
			
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
					
					NSMutableArray * params = [NSMutableArray arrayWithObjects:[folderNames mutableCopy], [NSNumber numberWithInt:MA_Root_Folder], nil];                
					[self performSelectorOnMainThread:@selector(createFolders:) withObject:params waitUntilDone:YES];
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
		}
		
		AppController *controller = [NSApp delegate];
		
		// Unread count may have changed
		[controller setStatusMessage:nil persist:NO];
		
		
	}];
	LLog(@"Starting subscriptionRequest");
	LOG_EXPR(subscriptionRequest);
	[subscriptionRequest startAsynchronous];		
	LLog(@"END");	
}

-(void)loadSubscriptions:(NSNotification *)nc
{
	if (nc != nil) {
		LLog(@"Firing after notification");
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"GRSync_Autheticated" object:nil];		
		[self performSelectorOnMainThread:@selector(completeLoadSubscriptions) withObject:nil waitUntilDone:YES];
	} else {
		LLog(@"Firing directly");

		if ([self isReady]) {
			LLog(@"Token available, finish subscription");
			[self performSelectorOnMainThread:@selector(completeLoadSubscriptions) withObject:nil waitUntilDone:YES];
		} else {
			LLog(@"Token not available, registering for notification");
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadSubscriptions:) name:@"GRSync_Autheticated" object:nil];
		}
	}
}

-(void)subscribeToFeed:(NSString *)feedURL 
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/quickadd?client=%@", APIBaseURL, ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:feedURL forKey:@"quickadd"];
    [request setPostValue:token forKey:@"T"];
    [request setDelegate:self];
    
    // Needs to be synchronous so UI doesn't refresh too soon.
    [request startSynchronous];
    NSLog(@"Subscribe response status code: %d", [request responseStatusCode]);
}

-(void)unsubscribeFromFeed:(NSString *)feedURL 
{
	NSURL *unsubscribeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/subscription/edit?access_token=%@",token]];
	__block ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:unsubscribeURL];
	[myRequest setFailedBlock:^{
		LOG_EXPR([myRequest error]);
		LOG_EXPR([myRequest responseHeaders]);
	}];
	[myRequest setPostValue:[self getGoogleActionToken] forKey:@"T"];
	[myRequest setPostValue:@"unsubscribe" forKey:@"ac"];
	[myRequest setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];

	[myRequest setCompletionBlock:^{
		NSString *requestResponse = [[[NSString alloc] initWithData:[myRequest responseData] encoding:NSUTF8StringEncoding] autorelease];
		LOG_EXPR(requestResponse);
		if (![requestResponse isEqualToString:@"OK"]) {
			LOG_EXPR([myRequest responseHeaders]);
			LOG_EXPR([myRequest requestHeaders]);
			LOG_EXPR([myRequest error]);
		}
	}];
	[myRequest startAsynchronous];		
}

-(void)setFolder:(NSString *)folderName forFeed:(NSString *)feedURL folderFlag:(BOOL)flag
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@", APIBaseURL, ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:@"edit" forKey:@"ac"];
    [request setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];
    [request setPostValue:[NSString stringWithFormat:@"user/-/label/%@", folderName] forKey:flag ? @"a" : @"r"];
    [request setPostValue:token forKey:@"T"];
    [request setDelegate:self];
    [request startSynchronous];
    NSLog(@"Set folder response status code: %d", [request responseStatusCode]);
}

-(void)renameFeed:(NSString *)feedURL to:(NSString *)newName
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@", APIBaseURL, ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:@"edit" forKey:@"ac"];
    [request setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];
    [request setPostValue:newName forKey:@"t"];
    [request setPostValue:token forKey:@"T"];
    [request setDelegate:self];
    [request startSynchronous];
    NSLog(@"Rename feed response status code: %d", [request responseStatusCode]);
}

-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag
{
	//TOFIX
	readerUser = @"-";
	//readerUser = [[tokenRequest responseHeaders] objectForKey:@"X-Reader-User"];
	LLog(token);
	NSURL *markReadURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/edit-tag?access_token=%@",token]];
	__block ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:markReadURL];
		[myRequest setFailedBlock:^{
			LOG_EXPR([myRequest error]);
			LOG_EXPR([myRequest responseHeaders]);
		}];
		if (flag) {
			[myRequest setPostValue:[NSString stringWithFormat:@"user/%@/state/com.google/read",readerUser] forKey:@"a"];	
			[myRequest setPostValue:@"true" forKey:@"async"];
			[myRequest setPostValue:itemGuid forKey:@"i"];
			[myRequest setPostValue:[self getGoogleActionToken] forKey:@"T"];

			[myRequest setCompletionBlock:^{
				NSString *tmp = [[NSString alloc] initWithData:[myRequest postBody] encoding:NSUTF8StringEncoding];
				LOG_EXPR(tmp);
				NSString *requestResponse = [[[NSString alloc] initWithData:[myRequest responseData] encoding:NSUTF8StringEncoding] autorelease];
				if (![requestResponse isEqualToString:@"OK"]) {
					LOG_EXPR([myRequest responseHeaders]);
					LOG_EXPR([myRequest requestHeaders]);
					LOG_EXPR([myRequest error]);
				}
			}];
		} else {
			[myRequest setPostValue:[NSString stringWithFormat:@"user/%@/state/com.google/kept-unread",readerUser] forKey:@"a"];			
			[myRequest setPostValue:[NSString stringWithFormat:@"user/%@/state/com.google/read",readerUser] forKey:@"r"];			
			[myRequest setPostValue:@"true" forKey:@"async"];
			[myRequest setPostValue:itemGuid forKey:@"i"];
			[myRequest setPostValue:[self getGoogleActionToken] forKey:@"T"];
			
			[myRequest setCompletionBlock:^{
				NSString *tmp = [[NSString alloc] initWithData:[myRequest postBody] encoding:NSUTF8StringEncoding];
				LOG_EXPR(tmp);
				NSString *requestResponse = [[[NSString alloc] initWithData:[myRequest responseData] encoding:NSUTF8StringEncoding] autorelease];
				LOG_EXPR(requestResponse);
				if (![requestResponse isEqualToString:@"OK"]) {
					LOG_EXPR([myRequest responseHeaders]);
					LOG_EXPR([myRequest requestHeaders]);
					LOG_EXPR([myRequest error]);
				}
				__block ASIFormDataRequest * request1 = [ASIFormDataRequest requestWithURL:markReadURL];
				[request1 setPostValue:@"true" forKey:@"async"];
				[request1 setPostValue:itemGuid forKey:@"i"];
				[request1 setPostValue:[self getGoogleActionToken] forKey:@"T"];
				[request1 setPostValue:@"user/-/state/com.google/tracking-kept-unread" forKey:@"a"];
				[request1 setCompletionBlock:^{
					NSString *requestResponse = [[[NSString alloc] initWithData:[request1 responseData] encoding:NSUTF8StringEncoding] autorelease];
					LOG_EXPR(requestResponse);
					if (![requestResponse isEqualToString:@"OK"]) {
						LOG_EXPR([request1 responseHeaders]);
						LOG_EXPR([request1 requestHeaders]);
						LOG_EXPR([request1 error]);
					}
				}];
				[request1 setFailedBlock:^{
					LOG_EXPR([request1 error]);
					LOG_EXPR([request1 responseHeaders]);
				}];
				[request1 startAsynchronous];
			}];
		}
		[myRequest startAsynchronous];
}

-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag
{
  	//TOFIX
	readerUser = @"-";
	NSURL *markStarredURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/edit-tag?access_token=%@",token]];
	__block ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:markStarredURL];
	[myRequest setFailedBlock:^{
		LOG_EXPR([myRequest error]);
		LOG_EXPR([myRequest responseHeaders]);
	}];
	if (flag) {
		[myRequest setPostValue:[NSString stringWithFormat:@"user/%@/state/com.google/starred",readerUser] forKey:@"a"];	
		[myRequest setPostValue:@"true" forKey:@"async"];
		[myRequest setPostValue:itemGuid forKey:@"i"];
		[myRequest setPostValue:[self getGoogleActionToken] forKey:@"T"];
			
		[myRequest setCompletionBlock:^{
			NSString *requestResponse = [[[NSString alloc] initWithData:[myRequest responseData] encoding:NSUTF8StringEncoding] autorelease];
			LOG_EXPR(requestResponse);
			if (![requestResponse isEqualToString:@"OK"]) {
				LOG_EXPR([myRequest responseHeaders]);
				LOG_EXPR([myRequest requestHeaders]);
				LOG_EXPR([myRequest error]);
			}
		}];
	} else {
		[myRequest setPostValue:[NSString stringWithFormat:@"user/%@/state/com.google/starred",readerUser] forKey:@"r"];			
		[myRequest setPostValue:@"true" forKey:@"async"];
		[myRequest setPostValue:itemGuid forKey:@"i"];
		[myRequest setPostValue:[self getGoogleActionToken] forKey:@"T"];
			
		[myRequest setCompletionBlock:^{
			NSString *requestResponse = [[[NSString alloc] initWithData:[myRequest responseData] encoding:NSUTF8StringEncoding] autorelease];
			LOG_EXPR(requestResponse);
			if (![requestResponse isEqualToString:@"OK"]) {
				LOG_EXPR([myRequest responseHeaders]);
				LOG_EXPR([myRequest requestHeaders]);
				LOG_EXPR([myRequest error]);
			}
		}];
	}
	[myRequest startAsynchronous];
}

-(void)disableTag:(NSString *)tagName
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@disable-tag?client=%@", APIBaseURL, ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[NSString stringWithFormat:@"user/-/label/%@", tagName] forKey:@"s"];
    [request setPostValue:token forKey:@"T"];
    [request setDelegate:self];
    [request startSynchronous];
    NSLog(@"Disable tag response status code: %d", [request responseStatusCode]);
}

-(void)renameTagFrom:(NSString *)oldName to:(NSString *)newName
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@rename-tag?client=%@", APIBaseURL, ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[NSString stringWithFormat:@"user/-/label/%@", oldName] forKey:@"s"];
    [request setPostValue:[NSString stringWithFormat:@"user/-/label/%@", newName] forKey:@"dest"];
    [request setPostValue:token forKey:@"T"];
    [request setDelegate:self];
    [request startSynchronous];
    NSLog(@"Rename tag response status code: %d", [request responseStatusCode]);
}

/*
-(BOOL)subscribingTo:(NSString *)feedURL 
{
    NSString * targetID = [NSString stringWithFormat:@"feed/%@", feedURL];
    for (NSDictionary * feed in [self subscriptions]) 
    {
        NSString * feedID = [feed objectForKey:@"id"];
        if ([feedID rangeOfString:targetID].location != NSNotFound) return YES;
    }
    return NO;
}
*/

-(void)dealloc 
{
	[oAuthObject release];
	[localFeeds release];
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

-(void)setOauth:(GTMOAuth2Authentication*)oauth {
	NSLog(@"Google Reader Setting OAUTH object");
	oAuthObject = [oauth retain];
	LOG_EXPR(oAuthObject);
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
	NSLog(@"createFolder - START");
	
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
	
	NSLog(@"createFolder - END");

}

@end
