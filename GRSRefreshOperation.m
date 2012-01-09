//
//  GRSRefreshOperation.m
//  Vienna
//
//  Created by Adam Hartford on 7/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSRefreshOperation.h"
#import "Folder.h"
#import "GoogleReader.h"
#import "Database.h"
#import "ArticleRef.h"
#import "Message.h"

@implementation GRSRefreshOperation

@synthesize googleReader;
@synthesize folder;
@synthesize articles;
@synthesize delegate;
@synthesize type;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)notifyDelegate 
{
    [[self delegate] syncFinishedForFolder:[self folder]];
}

-(void)deleteFolder:(Folder *)f 
{
    [[Database sharedDatabase] deleteFolder:[folder itemId]];    
}

-(void)fetchArticles
{
    [self setArticles:[[self folder] articles]];
}

-(void)moveFolderToParent:(NSString *)parentName
{
    Database * db = [Database sharedDatabase];
    Folder * parent = [db folderFromName:parentName];
    
    if ([folder parentId] != [parent itemId])
    {
        int folderId = [folder itemId];
        int parentId = [parent itemId];
        int predecessorId = 0;
        
        NSMutableArray * params = [NSMutableArray array];
        [params addObject:[NSNumber numberWithInt:folderId]];
        [params addObject:[NSNumber numberWithInt:parentId]];
        [params addObject:[NSNumber numberWithInt:predecessorId]];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_GRSFolderChange" object:params];
    }
}

-(void)renameFolderTo:(NSString *)name
{
    Database * db = [Database sharedDatabase];
    [db setFolderName:[folder itemId] newName:name];
}

-(void)addNewArticleFromData:(NSDictionary *)googleData
{
    [googleData retain];
    Database * db = [Database sharedDatabase];
    
    int folderId = [folder itemId];
    
    NSString * author = [googleData objectForKey:@"author"];
    NSString * body = [[googleData objectForKey:@"summary"] objectForKey:@"content"];
    NSString * title = [googleData objectForKey:@"title"];
    NSString * link = [[[googleData objectForKey:@"alternate"] objectAtIndex:0] objectForKey:@"href"];
    NSDate * date = [NSDate dateWithTimeIntervalSince1970:[[googleData objectForKey:@"published"] longValue]];
    
    Article * article = [[Article alloc] initWithGuid:[googleData objectForKey:@"id"]];
    [article setStatus:MA_MsgStatus_New];
    [article setFolderId:folderId];
    [article setAuthor:author ? author : @""];
    [article setBody:body];
    [article setTitle:title];
    [article setLink:link];
    [article setDate:date];
    // TODO Handle article enclosures, if necessary.
    [article setEnclosure:@""];
    [article setHasEnclosure:NO];
    
    NSArray * categories = [googleData objectForKey:@"categories"];
    for (NSString * category in categories)
    {
        if ([category hasSuffix:@"read"])
        {
            [article markRead:YES];
        }
        if ([category hasSuffix:@"starred"])
        {
            [article markFlagged:YES];
        }
        if ([category hasSuffix:@"/kept-unread"])
        {   
            [article markRead:NO];
        }
    }
    
    NSArray * guidHistory = [db guidHistoryForFolderId:folderId];
    [db beginTransaction];
    [db createArticle:folderId article:article guidHistory:guidHistory];
    [db commitTransaction];
    
    [article release];
    [googleData release];
    
    [db setFolderLastUpdate:folderId lastUpdate:[NSDate date]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListStateChange" object:nil];
}

-(void)doRefresh
{
    // Get Google subscriptions
    for (NSDictionary * feed in [googleReader subscriptions]) 
    {
        NSString * feedID = [feed objectForKey:@"id"];
        NSString * feedURL = [feedID stringByReplacingOccurrencesOfString:@"feed/" withString:@""];
        
        if ([feedURL isEqualToString:[folder feedURL]])
        {
            // Rename folder, if necessary
            NSString *title = [feed objectForKey:@"title"];
            if (![[folder name] isEqualToString:title])
                [self performSelectorOnMainThread:@selector(renameFolderTo:) withObject:title waitUntilDone:YES];
            
            NSString * folderName = nil;
        
            NSArray * categories = [feed objectForKey:@"categories"];
            for (NSDictionary * category in categories)
            {
                if ([category objectForKey:@"label"])
                {
                    NSString * theLabel = [category objectForKey:@"label"];
                    NSArray * folderNames = [theLabel componentsSeparatedByString:@" — "];  
                    folderName = [folderNames lastObject];
                    // NNW nested folder char: — 
                
                    NSMutableArray * params = [NSMutableArray arrayWithObjects:[folderNames mutableCopy], [NSNumber numberWithInt:MA_Root_Folder], folder, nil];                
                    [self performSelectorOnMainThread:@selector(createFolders:) withObject:params waitUntilDone:YES];
                    
                    // Make sure feed is in correct folder
                    [self performSelectorOnMainThread:@selector(moveFolderToParent:) withObject:[folderNames lastObject] waitUntilDone:YES];
                }
            }
            
            break;
        }
    }
    

    [self performSelectorOnMainThread:@selector(fetchArticles) withObject:nil waitUntilDone:YES];
    
    NSMutableArray * processedArticles = [NSMutableArray array];
    
    // Handle read/unread/starred
    for (Article * article in [self articles])
    {
        NSDictionary * data = [self readingListDataForArticle:article];
        if (data)
        {
            [processedArticles addObject:[article link]];
            
            BOOL read = NO;
            BOOL flagged = NO;
            
            NSArray * categories = [data objectForKey:@"categories"];
            for (NSString * category in categories)
            {
                if ([category hasSuffix:@"read"])
                {
                    read = YES;
                    [self performSelectorOnMainThread:@selector(markRead:) withObject:article waitUntilDone:NO];
                }
                if ([category hasSuffix:@"starred"])
                {
                    flagged = YES;
                    [self performSelectorOnMainThread:@selector(markFlagged:) withObject:article waitUntilDone:NO];
                }
                if ([category hasSuffix:@"/kept-unread"])
                {
                    [self performSelectorOnMainThread:@selector(markUnread:) withObject:article waitUntilDone:NO];
                }
            }
            
            if (!read && [article isRead])
            {
                [self performSelectorOnMainThread:@selector(markUnread:) withObject:article waitUntilDone:NO];
            }
            if (!flagged && [article isFlagged])
            {
                [self performSelectorOnMainThread:@selector(markUnflagged:) withObject:article waitUntilDone:NO];                
            }
        } 
        else
        {
            [self performSelectorOnMainThread:@selector(markRead:) withObject:article waitUntilDone:NO];
        }
    }
    
    // TODO Do we need to load the reading list again?
    [googleReader loadReadingList];
    
    // Handle articles at Google only. This needs to be revisited. Looping through all Vienna
    // articles, then through the Google reading list isn't a good approach. This can be made
    // to work by only iterating through the Google reading list.
    for (NSDictionary * data in [googleReader readingList])
    {
        NSArray * alternate = [data objectForKey:@"alternate"];
        NSString * url = [[alternate objectAtIndex:0] objectForKey:@"href"];
        NSString * currFeedUrl = [[[data objectForKey:@"origin"] objectForKey:@"streamId"] stringByReplacingOccurrencesOfString:@"feed/" withString:@""];
        
        if ([currFeedUrl isEqualToString:[folder feedURL]] && ![processedArticles containsObject:url])
        {
            NSLog(@"Need to add %@", url);
            [self performSelectorOnMainThread:@selector(addNewArticleFromData:) withObject:data waitUntilDone:YES];
        }
    }
}

-(void)handleRefresh 
{
    if (![googleReader subscribingTo:[folder feedURL]]) 
    {
        [self performSelectorOnMainThread:@selector(deleteFolder:) withObject:folder waitUntilDone:NO];
        return;
    }
    
    [self doRefresh];
}

-(void)buildLabel
{
    NSMutableArray * folderNames = [NSMutableArray array];
    Database * db = [Database sharedDatabase];
    Folder * parent = [db folderFromID:[folder parentId]];
    
    while (parent)
    {
        [folderNames addObject:[parent name]];
        parent = [db folderFromID:[parent parentId]];
    }
    
    NSArray * path = [[folderNames reverseObjectEnumerator] allObjects];
    label = [[path componentsJoinedByString:@" — "] retain];
}

- (void)handleSubscribe 
{
    [googleReader loadSubscriptions];
    if (![googleReader subscribingTo:[folder feedURL]]) 
    {
        [googleReader subscribeToFeed:[folder feedURL]];     
        if ([folder parentId] != MA_Root_Folder)
        {
            [self performSelectorOnMainThread:@selector(buildLabel) withObject:nil waitUntilDone:YES];
            [googleReader setFolder:label forFeed:[folder feedURL] folderFlag:YES];
        }
    }
    
    [googleReader loadReadingList];
    [self doRefresh];   
}

-(void)handleDelete 
{
    [googleReader unsubscribeFromFeed:[self.folder feedURL]];
}

-(void)doMain
{
    [self setGoogleReader:[GoogleReader sharedManager]];
    
    switch (type) 
    {
        case MA_Sync_Subscribe:
            [self handleSubscribe];
            break;
        case MA_Sync_Refresh:
        case MA_Sync_Refresh_All:
            [self handleRefresh];
            break;
        case MA_Sync_Delete:
        case MA_Sync_Unsubscribe:
            [self handleDelete];
            break;
        default:
            break;
    }
    
    [self performSelectorOnMainThread:@selector(notifyDelegate) withObject:nil waitUntilDone:NO];
}

-(void)handleError
{
    [self performSelectorOnMainThread:@selector(notifyDelegate) withObject:nil waitUntilDone:NO];
}

-(void)dealloc
{
    [folder release];
    [articles release];
    [label release];
}

@end
