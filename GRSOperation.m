//
//  GRSOperation.m
//  Vienna
//
//  Created by Adam Hartford on 7/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSOperation.h"
#import "GoogleReader.h"
#import "Preferences.h"
#import "AGKeychain.h"
#import "GTMNSString+HTML.h"
#import "Database.h"

@implementation GRSOperation

static GoogleReader *googleReader;
static BOOL fetchFlag;

static NSDate *lastSync;
static NSString *googleUsername;
static NSString *googlePassword;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

+(GoogleReader *)sharedGoogleReader 
{
    return googleReader;
}

+(void)setFetchFlag:(BOOL)flag
{
    fetchFlag = flag;
}

-(void)markRead:(Article *)article
{
    Database *db = [Database sharedDatabase];
    int folderId = [article folderId];
    [db markArticleRead:folderId guid:[article guid] isRead:YES];
    [article markRead:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListStateChange" object:[NSNumber numberWithInt:[article folderId]]];
}

-(void)markUnread:(Article *)article
{
    Database *db = [Database sharedDatabase];
    int folderId = [article folderId];
    [db markArticleRead:folderId guid:[article guid] isRead:NO];
    [article markRead:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListStateChange" object:[NSNumber numberWithInt:[article folderId]]];
}

-(void)markFlagged:(Article *)article
{
    Database *db = [Database sharedDatabase];
    int folderId = [article folderId];
    [db markArticleFlagged:folderId guid:[article guid] isFlagged:YES];
    [article markFlagged:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListStateChange" object:[NSNumber numberWithInt:[article folderId]]];
}

-(void)markUnflagged:(Article *)article
{
    Database *db = [Database sharedDatabase];
    int folderId = [article folderId];
    [db markArticleFlagged:folderId guid:[article guid] isFlagged:NO];
    [article markFlagged:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListStateChange" object:[NSNumber numberWithInt:[article folderId]]];
}

// Abstract
-(void)doMain {}
-(void)handleError {}

-(void)sendErrorNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_GoogleAuthFailed" object:nil];
}

-(void)main 
{
    // Don't allow sync operations to continue if sync is disabled
    if (![[Preferences standardPreferences] syncGoogleReader]) return;
    
    // The class maintains a GoogleReader instance for all objects (so we only authenticate when necessary)
    @synchronized([GRSOperation class]) 
    {
        NSString * username = [[Preferences standardPreferences] googleUsername];
        NSString * password = [AGKeychain getPasswordFromKeychainItem:@"Vienna: GoogleReaderSync" withItemKind:@"application password" forUsername:username];        
        
        // Determine when to re-athorize with google
        if (googleReader == nil || 
            ![googleReader isAuthenticated] ||
            ![googleUsername isEqualToString:username] || // If username changed
            ![googlePassword isEqualToString:password] || // If password changed
            (([[NSDate date] timeIntervalSinceDate:lastSync] / 60) > 20)) // If last sync over 20 minutes ago
        { 
            
            googleReader = [[GoogleReader readerWithUsername:username password:password] retain];
            
            lastSync = [[NSDate date] retain];
            googleUsername = [username retain];
            googlePassword = [password retain];
        }
        
        // Don't allow sync operations to continue if authentication failed
        if (![googleReader isAuthenticated]) 
        {
            [self performSelectorOnMainThread:@selector(sendErrorNotification) withObject:nil waitUntilDone:NO];
            // Give the operation subclass a chance to perform any cleanup work when an error happens
            [self handleError];
            return;
        }
        
        // Fetch Google Reader data if asked.
        // Using a static flag so that multiple operations can be spawned, but data is fetched only once.
        if (fetchFlag)
        {
            [googleReader loadSubscriptions];
            [googleReader loadReadingList];
            fetchFlag = NO;
        }
    }
    
    [self doMain];
}

-(NSDictionary *)readingListDataForArticle:(Article *)article
{
    for (NSDictionary * data in [googleReader readingList])
    {
        NSArray * alternate = [data objectForKey:@"alternate"];
        for (NSDictionary * dict in alternate)
        {
            NSString * url = [dict objectForKey:@"href"];
            if ([[article link] isEqualToString:url]) 
            {
                return data;
            }
        }
    }
    
    NSLog(@"No reading list data for %@", [article title]);
    return nil;
}

@end
