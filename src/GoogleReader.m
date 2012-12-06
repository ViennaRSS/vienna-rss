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

// Private functions
@interface GoogleReader (Private)
	-(NSString *)getGoogleOAuthToken;
	-(NSString *)getGoogleActionToken;
@end

@implementation GoogleReader

@synthesize localFeeds;
@synthesize token;
@synthesize readerUser;
@synthesize tokenTimer;
@synthesize actionToken;
@synthesize actionTokenTimer;

JSONDecoder * jsonDecoder;

-(BOOL)isReady
{
	return (googleReaderStatus == isTokenAcquired || googleReaderStatus == isActionTokenAcquired);
}


- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
		localFeeds = [[NSMutableArray alloc] init];
		jsonDecoder = [[JSONDecoder decoder] retain];
		googleReaderStatus = notAuthenticated;
		[self authenticate];
		countOfNewArticles = 0;
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
		[self resetAuthentication];
	}
}

-(ASIHTTPRequest*)refreshFeed:(Folder*)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit
{				
	
	//This is a workaround throw a BAD folderupdate value on DB
	NSString *folderLastUpdate = ignoreLimit ? @"0" : [thisFolder lastUpdateString];
	if ([folderLastUpdate isEqualToString:@"(null)"]) folderLastUpdate=@"0";
	
	NSInteger articleLimit = ignoreLimit ? 10000 : 100;
		
	NSURL *refreshFeedUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/stream/contents/feed/%@?client=%@&comments=false&likes=false&r=n&n=%li&ot=%@&ck=%@&T=%@&access_token=%@", [GTMOAuth2Authentication encodedOAuthValueForString:[thisFolder feedURL]],ClientName,articleLimit,folderLastUpdate,TIMESTAMP, token, token]];
		
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
	  NSString * theUser = [[request responseHeaders] objectForKey:@"X-Reader-User"];
	  if (theUser != nil) { //if Google matches us with a user...
		[self setReaderUser:theUser];
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
				if ([category hasSuffix:@"/starred"]) [article markFlagged:YES];
				if ([category hasSuffix:@"/kept-unread"]) [article markRead:NO];
			}
				
			if ([newsItem objectForKey:@"title"]!=nil) {
				[article setTitle:[NSString stringByRemovingHTML:[newsItem objectForKey:@"title"]]];
                
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
		[[RefreshManager articlesUpdateSemaphore] lock];

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
			[db setFolderHomePage:[refreshedFolder itemId] newHomePage:[[[dict objectForKey:@"alternate"] objectAtIndex:0] objectForKey:@"href"]];
		[[RefreshManager articlesUpdateSemaphore] unlock];
		
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
			[aItem setStatus:[NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newArticlesFromFeed]];
		
		[dict release];

		// If this folder also requires an image refresh, add that
		if ([refreshedFolder flags] & MA_FFlag_CheckForImage)
			[[RefreshManager sharedManager] performSelectorInBackground:@selector(refreshFavIcon:) withObject:refreshedFolder];

	} else { // apparently Google does not recognize the user anymore...
		[aItem setStatus:NSLocalizedString(@"Error", nil)];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
	  }
	} else { //other HTTP status response...
		[aItem appendDetail:[NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil), [request responseStatusCode]]];
		[aItem setStatus:NSLocalizedString(@"Error", nil)];
		[refreshedFolder clearNonPersistedFlag:MA_FFlag_Updating];
		[refreshedFolder setNonPersistedFlag:MA_FFlag_Error];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[refreshedFolder itemId]]];

}

-(void)refreshGoogleAccessToken:(NSTimer*)timer
{
	LLog(@"Access Token expired!!! Refreshing it!");
	googleReaderStatus = isAuthenticated;
	[self getGoogleOAuthToken];
}


-(void)refreshGoogleActionToken:(NSTimer*)timer
{
	LLog(@"Action Token expired!!! Refreshing it!");
	googleReaderStatus = isTokenAcquired;
	[self getGoogleActionToken];
}

-(NSString *)getGoogleActionToken
{
		
	[self getGoogleOAuthToken];

	// If we have a not expired access token, simply return it :)
	
	if (actionTokenTimer != nil && googleReaderStatus == isActionTokenAcquired) {
		LLog(@"An action token is available: %@",actionToken);
		return actionToken;
	}
	
	if (googleReaderStatus == isTokenAcquired) {
		
		NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/token?client=%@&access_token=%@",ClientName,token]];
		ASIHTTPRequest * tokenRequest = [ASIHTTPRequest requestWithURL:tokenURL];
		
		LLog(@"Start Action Token Request!");
		[tokenRequest startSynchronous];
		LLog(@"End Action Token Request!");
		
		if ([tokenRequest error]) {
			LLog(@"Error getting the action token");
			LOG_EXPR([tokenRequest error]);
			LOG_EXPR([tokenRequest responseHeaders]);
			[self resetAuthentication];
			return nil;
		} else {
			LLog(@"Action Token Acquired");
			googleReaderStatus = isActionTokenAcquired;
			[actionToken release];
			actionToken = [[[NSString alloc] initWithData:[tokenRequest responseData] encoding:NSUTF8StringEncoding] retain];
			LOG_EXPR(actionToken);
			
			//let expire in 25 mins instead of 30
			if (actionTokenTimer == nil || ![actionTokenTimer isValid]) {
				actionTokenTimer = [NSTimer scheduledTimerWithTimeInterval:1500 target:self selector:@selector(refreshGoogleActionToken:) userInfo:nil repeats:YES];
			}
			return actionToken;
		}
	} else {
		return nil;
	}
}


-(NSString *)getGoogleOAuthToken
{
	
	// If we have a not expired access token, simply return it :)
	
	if (token != nil && googleReaderStatus == isTokenAcquired) {
		LLog(@"A token is available: %@",token);
		return token;
	}
	
	[[NSApp delegate] setStatusMessage:NSLocalizedString(@"Acquiring OAuth 2.0 token...", nil) persist:NO];

	if (googleReaderStatus == isAuthenticated) {
		
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
			[self resetAuthentication];
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
			NSDictionary * dict = [jsonDecoder objectWithData:jsonData];
			[token release];
			token = [[dict objectForKey:@"access_token"] retain];

			if (tokenTimer == nil || ![tokenTimer isValid]) {
				tokenTimer = [NSTimer scheduledTimerWithTimeInterval:[[dict objectForKey:@"expires_in"] intValue] target:self selector:@selector(refreshGoogleAccessToken:) userInfo:nil repeats:YES];
			}
			
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
	
	[windowController 	signInSheetModalForWindow:nil
						delegate:self
						finishedSelector:@selector(windowControllerCallback:finishedWithAuth:error:)];
}

- (void)windowControllerCallback:(GTMOAuth2WindowController *)windowController  finishedWithAuth:(GTMOAuth2Authentication *)auth error:(NSError *)error
{
	if (error != nil)
	{
		// Authentication failed
		googleReaderStatus = notAuthenticated;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_GoogleAuthFailed" object:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_AuthFailed" object:nil];
	}
	else
	{
		// Authentication succeeded
		oAuthObject = [auth retain];
		googleReaderStatus = isAuthenticated;
		if ([self getGoogleOAuthToken] != nil) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];
		}
		else
		{
			//TODO
			//Better handling of failure to get an OAuth token (wait message to user ?)
		}
	}
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
	
	oAuthObject = [[GTMOAuth2WindowController authForGoogleFromKeychainForName:kKeychainItemName
																					   clientID:@"49097391685.apps.googleusercontent.com"
																				   clientSecret:@"0wzzJCfkcNPeqKgjo-pfPZSA"] retain];	
	if (oAuthObject != nil && [oAuthObject canAuthorize]) {
		LLog(@"Google OAuth 2.0 - OAuth token acquired from keychain");
		googleReaderStatus = isAuthenticated;	
		if ([self getGoogleOAuthToken] != nil) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];
		} else {
			//TODO
			//Better handling of failure to get an OAuth token (wait message to user ?)
		}
	} else {
		[self performSelectorOnMainThread:@selector(handleGoogleLoginRequest) withObject:nil waitUntilDone:YES];
	}
}

-(void)clearAuthentication
{
	googleReaderStatus = notAuthenticated;
}

-(void)resetAuthentication
{
	[self clearAuthentication];
	[self authenticate];
	[self getGoogleActionToken];
}

-(void)submitLoadSubscriptions {
	
	[[NSApp delegate] setStatusMessage:@"Fetching Google Reader Subscriptions..." persist:NO];


	ASIHTTPRequest *subscriptionRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/subscription/list?client=%@&output=json&access_token=%@",ClientName,token]]];
	[subscriptionRequest setDelegate:self];
	[subscriptionRequest setDidFinishSelector:@selector(subscriptionsRequestDone:)];
	LLog(@"Starting subscriptionRequest");
	LOG_EXPR(subscriptionRequest);
	[subscriptionRequest startAsynchronous];		
	LLog(@"subscriptionRequest submitted");	
}

-(void)subscriptionsRequestDone:(ASIHTTPRequest *)request
{
	LLog(@"Ending subscriptionRequest");
	[self setReaderUser:[[request responseHeaders] objectForKey:@"X-Reader-User"]];

	
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
            feedURL = [NSString stringWithFormat:@"http://www.google.com/reader/public/atom/%@", feedURL];
		
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
			[[RefreshManager articlesUpdateSemaphore] lock];
			[[Database sharedDatabase] deleteFolder:[f itemId]];
			[[RefreshManager articlesUpdateSemaphore] unlock];
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
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/quickadd?client=%@", APIBaseURL, ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:feedURL forKey:@"quickadd"];
    [request setPostValue:[self getGoogleActionToken]  forKey:@"T"];
    [request setDelegate:self];
    
    // Needs to be synchronous so UI doesn't refresh too soon.
    [request startSynchronous];
    NSLog(@"Subscribe response status code: %d", [request responseStatusCode]);
}

-(void)unsubscribeFromFeed:(NSString *)feedURL 
{
	NSURL *unsubscribeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/subscription/edit?access_token=%@",token]];
	ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:unsubscribeURL];
	[myRequest setPostValue:[self getGoogleActionToken] forKey:@"T"];
	[myRequest setPostValue:@"unsubscribe" forKey:@"ac"];
	[myRequest setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];

	[myRequest startAsynchronous];		
}

-(void)setFolder:(NSString *)folderName forFeed:(NSString *)feedURL folderFlag:(BOOL)flag
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@", APIBaseURL, ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:@"edit" forKey:@"ac"];
    [request setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];
    [request setPostValue:[NSString stringWithFormat:@"user/-/label/%@", folderName] forKey:flag ? @"a" : @"r"];
    [request setPostValue:[self getGoogleActionToken] forKey:@"T"];
    [request setDelegate:self];
    [request startSynchronous];
    NSLog(@"Set folder response status code: %d", [request responseStatusCode]);
}

-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag
{
	NSString * theActionToken = [self getGoogleActionToken];
	LLog(token);
	NSURL *markReadURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/edit-tag?access_token=%@",token]];
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
	[myRequest setPostValue:theActionToken forKey:@"T"];
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

	LLog(token);
	NSURL *markReadURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/edit-tag?access_token=%@",token]];
    NSString *itemGuid = [[request userInfo] objectForKey:@"guid"];
	ASIFormDataRequest * request1 = [ASIFormDataRequest requestWithURL:markReadURL];
	[request1 setPostValue:@"true" forKey:@"async"];
	[request1 setPostValue:itemGuid forKey:@"i"];
	[request1 setPostValue:[self getGoogleActionToken] forKey:@"T"];
	[request1 setPostValue:@"user/-/state/com.google/tracking-kept-unread" forKey:@"a"];
	[request1 startAsynchronous];
}


-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag
{
	NSString * theActionToken = [self getGoogleActionToken];
	NSURL *markStarredURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/edit-tag?access_token=%@",token]];
	ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:markStarredURL];
	if (flag) {
		[myRequest setPostValue:@"user/-/state/com.google/starred" forKey:@"a"];
			
	} else {
		[myRequest setPostValue:@"user/-/state/com.google/starred" forKey:@"r"];
			
	}
	[myRequest setPostValue:@"true" forKey:@"async"];
	[myRequest setPostValue:itemGuid forKey:@"i"];
	[myRequest setPostValue:theActionToken forKey:@"T"];
	[myRequest setDelegate:self];
	[myRequest startAsynchronous];
}


-(void)dealloc 
{
	[oAuthObject release];
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
