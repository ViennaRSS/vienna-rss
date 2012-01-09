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
#import "VTPG_Common.h"
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

@implementation GoogleReader

@synthesize subscriptions;
@synthesize readingList;
@synthesize localFeeds;
@synthesize nq;
@synthesize token;
@synthesize readerUser;



- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
		localFeeds = [[[NSMutableArray alloc] init] retain]; 
		nq = [[[ASINetworkQueue alloc] init] retain];
		nq.delegate = self;
		[nq setShouldCancelAllRequestsOnFailure:NO];
		[nq setRequestDidFinishSelector:@selector(nqRequestFinished:)];
		[nq setRequestDidStartSelector:@selector(nqRequestStarted:)];
		[self authenticate];
    }
    
    return self;
}

- (void)nqRequestFinished:(ASIHTTPRequest *)request {
	NSLog(@"Nuova richiesta accodata. CODA: %i",[nq requestsCount]);
}

- (void)nqRequestStarted:(ASIHTTPRequest *)request {
	NSLog(@"Richiesta terminata. CODA: %i",[nq requestsCount]);	
}


- (NSString *) URLEncodedString_ch:(NSString*)sourceString {
    NSMutableString * output = [NSMutableString string];
    const char * source = (const char *)[sourceString UTF8String];
    size_t sourceLen = strlen((const char *)source);
    for (size_t i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' || 
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

-(void)refreshFeed:(Folder*)thisFolder {
				
	//This is a workaround throw a BAD folderupdate value on DB
	NSString *folderLastUpdate = [thisFolder lastUpdateString];
	if ([folderLastUpdate isEqualToString:@"(null)"]) folderLastUpdate=@"0";
	
	__block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/stream/contents/feed/%@?client=scroll&comments=false&likes=false&r=n&n=100&ot=%@&T=%@&access_token=%@",[self URLEncodedString_ch:[thisFolder feedURL]],folderLastUpdate, token, oAuthObject.accessToken]]];
	
	[request setUserInfo:[NSDictionary dictionaryWithObject:thisFolder forKey:@"folder"]];
	[request setCompletionBlock:^{
		NSData *data = [request responseData];
		Folder *refreshedFolder = [[request userInfo] objectForKey:@"folder"];
		NSLog(@"Finito il refresh per %@",[refreshedFolder feedURL]);
		
		if (data) {
			Database *db = [Database sharedDatabase];

			NSDictionary * dict = [[NSDictionary alloc] initWithDictionary:[[JSONDecoder decoder] objectWithData:data]];		
			if ([dict objectForKey:@"updated"] == nil) {
				NSLog(@"-----------------------> ABBIAMO QUALCHE ERRORE!!!!");
				LOG_EXPR([request url]);
				NSLog(@"Feed name: %@",[dict objectForKey:@"title"]);
				NSLog(@"Check precedente: %@",folderLastUpdate);
				NSLog(@"Last update: %@",[dict objectForKey:@"updated"]);
				NSLog(@"Presenti %i articoli",[[dict objectForKey:@"items"] count]);
				LOG_EXPR(dict);
				//NSString *tmp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
				//LOG_EXPR(tmp);
			}
			[db setFolderLastUpdateString:[refreshedFolder itemId] lastUpdateString:[NSString stringWithFormat:@"%@",[dict objectForKey:@"updated"]]];
			
			// Log number of bytes we received
			//[[connector aItem] appendDetail:[NSString stringWithFormat:NSLocalizedString(@"%ld bytes received", nil), [receivedData length]]];
						
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
				
				// Here's where we add the articles to the database
				if ([articleArray count] > 0)
				{
					NSArray * guidHistory = [db guidHistoryForFolderId:[refreshedFolder itemId]];
					
					[refreshedFolder clearCache];
					// Should we wrap the entire loop or just individual article updates?
					[db beginTransaction];
					for (Article * article in articleArray)
					{
						if ([db createArticle:[refreshedFolder itemId] article:article guidHistory:guidHistory] && ([article status] == MA_MsgStatus_New)) {
						} else {
							[db markArticleRead:[refreshedFolder itemId] guid:[article guid] isRead:[article isRead]];
							//NSLog(@"Articolo: %@ - Marcato Read: %@",[article title],[article isRead] ? @"YES" : @"NO");
						}
						
					}
					[db commitTransaction];				
				}
								
				// Let interested callers know that the folder has changed.
				//[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[refreshedFolder itemId]]];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListStateChange" object:nil];
			
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
			
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[refreshedFolder itemId]]];
			
		/*
			// Send status to the activity log
			if (newArticlesFromFeed == 0)
				[[connector aItem] setStatus:NSLocalizedString(@"No new articles available", nil)];
			else
			{
				NSString * logText = [NSString stringWithFormat:NSLocalizedString(@"%d new articles retrieved", nil), newArticlesFromFeed];
				[[connector aItem] setStatus:logText];
			}
			
			// Done with this connection
			[newFeed release];
			
			// If this folder also requires an image refresh, add that
			if ([folder flags] & MA_FFlag_CheckForImage)
				[self refreshFavIcon:folder];
			
			// Add to count of new articles so far
			countOfNewArticles += newArticlesFromFeed;
				*/
			}
			 
		
	}];
	
	[request setFailedBlock:^{
		LOG_EXPR([request error]);
	}];
	[nq addOperation:request];
	[nq go];
}


-(void)requestFinished:(ASIHTTPRequest *)request
{
    NSLog(@"HTTP response status code: %d -- URL: %@", [request responseStatusCode], [[request url] absoluteString]);
	NSString *tmp = [[[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding] autorelease];
	LOG_EXPR(tmp);
}



-(void)completeUpdateViennaSubscriptionsWithGoogleSubscriptions:(NSNotification*)nc {
	
	NSLog(@"completeUpdateViennaSubscriptionsWithGoogleSubscriptions - START");
	
	NSLog(@"rimuovo il centro notifiche");
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"GRSync_RemoteSubscriptionsRefreshed" object:nil];
	NSLog(@"continuo dopo aver rimosso il centro notifiche");
		
	// Get Google subscriptions
	for (NSDictionary * feed in subscriptions) 
	{
		NSString * feedID = [feed objectForKey:@"id"];
		NSString * feedURL = [feedID stringByReplacingOccurrencesOfString:@"feed/" withString:@""];
		
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
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_RemoteFoldersAdded" object:nil];
	
	NSLog(@"completeUpdateViennaSubscriptionsWithGoogleSubscriptions - END");

}

-(void)updateViennaSubscriptionsWithGoogleSubscriptions:(NSArray*)folderList {

	NSLog(@"updateViennaSubscriptionsWithGoogleSubscriptions - START");
	
	[localFeeds removeAllObjects];
	
	if (folderList!=nil) {
		for (Folder * f in folderList) {
			[localFeeds addObject:[f feedURL]];
		}
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(completeUpdateViennaSubscriptionsWithGoogleSubscriptions:) name:@"GRSync_RemoteSubscriptionsRefreshed" object:nil];
		
	NSLog(@"updateViennaSubscriptionsWithGoogleSubscriptions - END");
}


-(void)handleGoogleLoginRequest
{
	
	NSLog(@"Non autenticato, richiedo la pagina GOOGLE");
	
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
			NSLog(@"Errore di autenticazione!!!!");
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_GoogleAuthFailed" object:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_AuthFailed" object:nil];
		} else {
			// Authentication succeeded
			NSLog(@"Autenticato!!");
			oAuthObject = [auth retain];
			//[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];

			
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com/reader/api/0/token?client=scroll"]];
			
			[auth authorizeRequest:request completionHandler:^(NSError *error) {
				NSLog(@"Finito il load del token"); 
				if (error) {
					LOG_EXPR([error description]);
				} else {
					// Synchronous fetches like this are a really bad idea in Cocoa applications
					//
					// For a very easy async alternative, we could use GTMHTTPFetcher
					NSError *error = nil;
					NSURLResponse *response = nil;
					NSData *data = [NSURLConnection sendSynchronousRequest:request
														 returningResponse:&response
																	 error:&error];
					if (data) {
						NSLog(@"Processo l'acquisizione del token");
						token = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] retain];
						LOG_EXPR(token);
						[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];
						
					} else {
						// Fetch failed
						LOG_EXPR([error description]);
					}
				}
				
				
			}];

			//[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];
		}
		
	}];
}


-(void)authenticate 
{    	
	
	NSLog(@"Google Reader - authenticate");
	
	
	oAuthObject = [[GTMOAuth2WindowController authForGoogleFromKeychainForName:kKeychainItemName
																					   clientID:@"49097391685.apps.googleusercontent.com"
																				   clientSecret:@"0wzzJCfkcNPeqKgjo-pfPZSA"] retain];	
	
	if (oAuthObject != nil && [oAuthObject canAuthorize]) {
		NSLog(@"Autenticato da keychain!!");
		//[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];

		
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com/reader/api/0/token?client=scroll"]];
		
		[oAuthObject authorizeRequest:request completionHandler:^(NSError *error) {
			NSLog(@"Finito il load del token"); 
			if (error) {
				LOG_EXPR([error description]);
			} else {
				// Synchronous fetches like this are a really bad idea in Cocoa applications
				//
				// For a very easy async alternative, we could use GTMHTTPFetcher
				NSError *error = nil;
				NSURLResponse *response = nil;
				NSData *data = [NSURLConnection sendSynchronousRequest:request
													 returningResponse:&response
																 error:&error];
				if (data) {
					NSLog(@"Processo l'acquisizione del token");
					token = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] retain];
					LOG_EXPR(token);
					[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];

				} else {
					// Fetch failed
					LOG_EXPR([error description]);
				}
			}
			
			
		}];
		
		/*
		ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com/reader/api/0/token?client=scroll"]];
		
		[request setCompletionBlock:^{
			NSLog(@"Abbiamo un token di accesso!!!!");
			token = [[[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding] retain];
			LOG_EXPR(token);
			[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_Autheticated" object:nil];
		}];
		
		[request setFailedBlock:^{
			LOG_EXPR([request error]);
		}];
		//		[request setDelegate:self];
		[request startAsynchronous];
		 */
		
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
	
	NSLog(@"completeLoadSubscriptions");
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com/reader/api/0/subscription/list?client=scroll&output=json"]];

	[oAuthObject authorizeRequest:request completionHandler:^(NSError *error) {
		NSLog(@"Finito il load della lista"); 
		if (error) {
			LOG_EXPR([error description]);
		} else {
			// Synchronous fetches like this are a really bad idea in Cocoa applications
			//
			// For a very easy async alternative, we could use GTMHTTPFetcher
			NSError *error = nil;
			NSURLResponse *response = nil;
			NSData *data = [NSURLConnection sendSynchronousRequest:request
												 returningResponse:&response
															 error:&error];
			if (data) {
				NSLog(@"Processo la lista di sottoscrizioni remote");
				NSString *tmp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
				LOG_EXPR(tmp);
				// API fetch succeeded
				
				JSONDecoder * jsonDecoder = [JSONDecoder decoder];
				NSDictionary * dict = [jsonDecoder objectWithData:data];
				LOG_EXPR(dict);
				[self setSubscriptions:[dict objectForKey:@"subscriptions"]];
				LOG_EXPR([self subscriptions]);
				[[NSNotificationCenter defaultCenter] postNotificationName:@"GRSync_RemoteSubscriptionsRefreshed" object:nil];
			} else {
				// Fetch failed
				LOG_EXPR([error description]);
			}
		}
		
		
	}];

	
}

-(void)loadSubscriptions:(NSNotification *)nc
{
	NSLog(@"loadSubscriptions - START");	
	NSLog(@"Loading Google Reader Subscriptions");
	
	if (nc != nil) {
		NSLog(@"Chiamata tramite NC");
		
		//Prima di tutto deregistriamoci dal NC
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"GRSync_Autheticated" object:nil];
		
		NSLog(@"Richiamiamo il processo di update Subscriptions");
		[self performSelectorOnMainThread:@selector(completeLoadSubscriptions) withObject:nil waitUntilDone:YES];

	} else {
		NSLog(@"Chiamata NON da NC");

		if ([oAuthObject canAuthorize]) {
			NSLog(@"Autorizzazione OK - procediamo all'update delle subscriptions");
			[self performSelectorOnMainThread:@selector(completeLoadSubscriptions) withObject:nil waitUntilDone:YES];
		} else {
			NSLog(@"Autorizzazione non ancora disponibile - registriamo la notifica");
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadSubscriptions:) name:@"GRSync_Autheticated" object:nil];
		}

	}
	
	NSLog(@"loadSubscriptions - END");

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
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@subscription/edit?client=%@", APIBaseURL, ClientName]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:@"unsubscribe" forKey:@"ac"];
    [request setPostValue:[NSString stringWithFormat:@"feed/%@", feedURL] forKey:@"s"];
    [request setPostValue:token forKey:@"T"];
    [request setDelegate:self];
    [request startSynchronous];
    NSLog(@"Unsubscribe response status code: %d", [request responseStatusCode]);
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
	
	NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/token?client=scroll&access_token=%@",oAuthObject.accessToken]];
	__block ASIHTTPRequest *tokenRequest = [ASIHTTPRequest requestWithURL:tokenURL];
	[tokenRequest setFailedBlock:^{
		LOG_EXPR([tokenRequest error]);
		LOG_EXPR([tokenRequest responseHeaders]);
	}];
	[tokenRequest setCompletionBlock:^{
		token = [[NSString alloc] initWithData:[tokenRequest responseData] encoding:NSUTF8StringEncoding];
		LOG_EXPR(token);
		//LOG_EXPR([tokenRequest responseHeaders]);
		readerUser = [[tokenRequest responseHeaders] objectForKey:@"X-Reader-User"];
		LOG_EXPR(readerUser);
		NSURL *markReadURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/edit-tag?access_token=%@",oAuthObject.accessToken]];
		__block ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:markReadURL];
		[myRequest setFailedBlock:^{
			LOG_EXPR([myRequest error]);
			LOG_EXPR([myRequest responseHeaders]);
		}];
		if (flag) {
			[myRequest setPostValue:[NSString stringWithFormat:@"user/%@/state/com.google/read",readerUser] forKey:@"a"];	
			//[myRequest setPostValue:[NSString stringWithFormat:@"user/%@/state/com.google/kept-unread",readerUser] forKey:@"r"];	
			[myRequest setPostValue:@"true" forKey:@"async"];
			//[myRequest setPostValue:@"feed/http://images.apple.com/main/rss/hotnews/hotnews.rss" forKey:@"s"];
			[myRequest setPostValue:itemGuid forKey:@"i"];
			[myRequest setPostValue:token forKey:@"T"];
			//[myRequest setPostValue:oAuthObject.accessToken forKey:@"access_token"];

			[myRequest setCompletionBlock:^{
				NSString *tmp = [[NSString alloc] initWithData:[myRequest postBody] encoding:NSUTF8StringEncoding];
				LOG_EXPR(tmp);
				NSString *requestResponse = [[[NSString alloc] initWithData:[myRequest responseData] encoding:NSUTF8StringEncoding] autorelease];
				//LOG_EXPR(requestResponse);
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
			//[myRequest setPostValue:@"feed/http://images.apple.com/main/rss/hotnews/hotnews.rss" forKey:@"s"];
			[myRequest setPostValue:itemGuid forKey:@"i"];
			[myRequest setPostValue:token forKey:@"T"];
			[myRequest setPostValue:oAuthObject.accessToken forKey:@"access_token"];

			
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
				 [request1 setPostValue:token forKey:@"T"];
				 [request1 setPostValue:@"user/-/state/com.google/tracking-kept-unread" forKey:@"a"];
				 //[request1 setDelegate:self];
				[myRequest setCompletionBlock:^{
					NSString *requestResponse = [[[NSString alloc] initWithData:[myRequest responseData] encoding:NSUTF8StringEncoding] autorelease];
					LOG_EXPR(requestResponse);
					if (![requestResponse isEqualToString:@"OK"]) {
						LOG_EXPR([myRequest responseHeaders]);
						LOG_EXPR([myRequest requestHeaders]);
						LOG_EXPR([myRequest error]);
					}
				}];
				[myRequest setFailedBlock:^{
					LOG_EXPR([myRequest error]);
					LOG_EXPR([myRequest responseHeaders]);
				}];
				 [request1 startAsynchronous];
			}];
		}
				[myRequest startAsynchronous];

	}];
	[tokenRequest startAsynchronous];
	
}

-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag
{
  	
	NSURL *tokenURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/token?client=scroll&access_token=%@",oAuthObject.accessToken]];
	__block ASIHTTPRequest *tokenRequest = [ASIHTTPRequest requestWithURL:tokenURL];
	[tokenRequest setFailedBlock:^{
		LOG_EXPR([tokenRequest error]);
		LOG_EXPR([tokenRequest responseHeaders]);
	}];
	[tokenRequest setCompletionBlock:^{
		token = [[NSString alloc] initWithData:[tokenRequest responseData] encoding:NSUTF8StringEncoding];
		LOG_EXPR(token);
		//LOG_EXPR([tokenRequest responseHeaders]);
		readerUser = [[tokenRequest responseHeaders] objectForKey:@"X-Reader-User"];
		LOG_EXPR(readerUser);
		NSURL *markStarredURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/reader/api/0/edit-tag?access_token=%@",oAuthObject.accessToken]];
		__block ASIFormDataRequest * myRequest = [ASIFormDataRequest requestWithURL:markStarredURL];
		[myRequest setFailedBlock:^{
			LOG_EXPR([myRequest error]);
			LOG_EXPR([myRequest responseHeaders]);
		}];
		if (flag) {
			[myRequest setPostValue:[NSString stringWithFormat:@"user/%@/state/com.google/starred",readerUser] forKey:@"a"];	
			[myRequest setPostValue:@"true" forKey:@"async"];
			[myRequest setPostValue:itemGuid forKey:@"i"];
			[myRequest setPostValue:token forKey:@"T"];
			
			[myRequest setCompletionBlock:^{
				NSString *tmp = [[NSString alloc] initWithData:[myRequest postBody] encoding:NSUTF8StringEncoding];
				LOG_EXPR(tmp);
				NSString *requestResponse = [[[NSString alloc] initWithData:[myRequest responseData] encoding:NSUTF8StringEncoding] autorelease];
				//LOG_EXPR(requestResponse);
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
			[myRequest setPostValue:token forKey:@"T"];
			[myRequest setPostValue:oAuthObject.accessToken forKey:@"access_token"];			
			
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
			}];
		}
		[myRequest startAsynchronous];
		
	}];
	[tokenRequest startAsynchronous];

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

-(void)dealloc 
{
    [subscriptions release];
	[oAuthObject release];
	[localFeeds release];
	[nq release];
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
		[rssTitle release];
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
        
        parentNumber = [NSNumber numberWithInt:newFolderId];
    }
    else parentNumber = [NSNumber numberWithInt:[folder itemId]];
    
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
