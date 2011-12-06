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

#define TIMESTAMP [NSString stringWithFormat:@"%0.0f",[[NSDate date] timeIntervalSince1970]]

static NSString * LoginBaseURL = @"https://www.google.com/accounts/ClientLogin?service=reader&Email=%@&Passwd=%@";
static NSString * APIBaseURL = @"http://www.google.com/reader/api/0/";
static NSString * ClientName =@"scroll";

//static GoogleReader *Instance;

@implementation GoogleReader

@synthesize subscriptions;
@synthesize readingList;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

/* Singleton or not? For now, no.
+(id)alloc 
 {
	@synchronized([GoogleReader class]) 
    {
		NSAssert(Instance == nil, @"Attempted to allocate a second instance of a singleton.");
		Instance = [super alloc];
		return Instance;
	}
    
	return nil;
}

+(GoogleReader *)sharedInstance 
 {
	@synchronized([GoogleReader class]) 
    {
		if (!Instance)
			[[self alloc] init];
        
		return Instance;
	}
    
	return nil;
}
*/

-(void)requestFinished:(ASIHTTPRequest *)request
{
    NSLog(@"HTTP response status code: %d -- URL: %@", [request responseStatusCode], [[request url] absoluteString]);
}

-(BOOL)isAuthenticated
{
    return authenticated;
}

-(void)clearCookies
{
    NSURL *url = [NSURL URLWithString:@"https://www.google.com"];
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSEnumerator *enumerator = [[cookieStorage cookiesForURL:url] objectEnumerator];
    NSHTTPCookie *cookie = nil;
    while ((cookie = [enumerator nextObject])) 
    {
        NSString * cookieName = [[cookie properties] objectForKey:NSHTTPCookieName];
        if ([@"ViennaCookie" isEqualToString:cookieName])
            [cookieStorage deleteCookie:cookie];
    }
}

-(void)authenticate 
{    
    authenticated = NO;
    [self clearCookies];
    
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:LoginBaseURL, username, password]];
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request startSynchronous];

    NSLog(@"Google Reader auth reponse code: %d", [request responseStatusCode]);
    NSString * response = [request responseString];
    NSLog(@"Google Reader auth response: %@", response);

    if (!response || [request responseStatusCode] != 200) 
    {
        NSLog(@"Failed to authenticate with Google Reader");
        return;
    }
    
    NSArray * components = [response componentsSeparatedByString:@"\n"];
    
    NSString * sid = [[components objectAtIndex:0] substringFromIndex:4];
    //NSString * lsid = [[components objectAtIndex:1] substringFromIndex:5];
    NSString * auth = [[components objectAtIndex:2] substringFromIndex:5];
    
    NSDictionary * properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                sid, NSHTTPCookieValue,
                                @"ViennaCookie", NSHTTPCookieName,
                                @".google.com", NSHTTPCookieDomain,
                                [NSDate dateWithTimeIntervalSinceNow:60*60], NSHTTPCookieExpires,
                                @"/", NSHTTPCookiePath,
                                nil];
    
    NSHTTPCookie * cookie = [NSHTTPCookie cookieWithProperties:properties];
    
    request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com/reader/api/0/token"]];
    [request setUseCookiePersistence:NO];
    [request setRequestCookies:[NSMutableArray arrayWithObject:cookie]];
    [request addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"GoogleLogin auth=%@", auth]];
    [request addRequestHeader:@"Content-Type" value:@"application/x-www-form-urlencoded"];
    
    [request startSynchronous];
    
    // Save token
    token = [request responseString];
    [token retain];
    
    authenticated = YES;
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
    

-(void)loadSubscriptions 
{
    NSString * args = [NSString stringWithFormat:@"?ck=%@&client=@%&output=json", TIMESTAMP, ClientName];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", APIBaseURL, @"subscription/list", args]];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request startSynchronous];
    
    NSLog(@"Load subscriptions response code: %d", [request responseStatusCode]);
    
    NSData * jsonData = [request responseData];
    JSONDecoder * jsonDecoder = [JSONDecoder decoder];
    NSDictionary * dict = [jsonDecoder objectWithData:jsonData];
    [self setSubscriptions:[dict objectForKey:@"subscriptions"]];
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
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", APIBaseURL, @"edit-tag"]];
    
    ASIFormDataRequest * request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:@"user/-/state/com.google/read" forKey:flag ? @"a" : @"r"];
    [request setPostValue:@"true" forKey:@"async"];
    [request setPostValue:itemGuid forKey:@"i"];
    [request setPostValue:token forKey:@"T"];
    [request setDelegate:self];
    [request startSynchronous];
    NSLog(@"Mark read response status code: %d", [request responseStatusCode]);
}

-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", APIBaseURL, @"edit-tag"]];
    
    ASIFormDataRequest * request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:@"user/-/state/com.google/starred" forKey:flag ? @"a" : @"r"];
    [request setPostValue:@"true" forKey:@"async"];
    [request setPostValue:itemGuid forKey:@"i"];
    [request setPostValue:token forKey:@"T"];
    [request setDelegate:self];
    [request startSynchronous];
    NSLog(@"Mark starred response status code: %d", [request responseStatusCode]);
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

-(id)initWithUsername:(NSString *)user password:(NSString *)pass 
{
    self = [self init];
    username = user;
    password = pass;
    [self authenticate];
     return self;
}
     
+(id)readerWithUsername:(NSString *)user password:(NSString *)pass 
{
    return [[[self alloc] initWithUsername:user password:pass] autorelease];
}

-(void)dealloc 
{
    [subscriptions release];
}

@end
