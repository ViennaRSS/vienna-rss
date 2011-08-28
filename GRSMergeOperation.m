//
//  GRSMergeOperation.m
//  Vienna
//
//  Created by Adam Hartford on 8/14/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSMergeOperation.h"
#import "Folder.h"
#import "GoogleReader.h"
#import "ArticleRef.h"
#import "AppController.h"
#import "GRSRefreshOperation.h"

@implementation GRSMergeOperation

@synthesize delegate;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)fetchArticlesForFolder:(Folder *)folder
{
    articles = [[folder articles] retain];
}

- (void)mergeFinishedForFolder:(Folder *)folder 
{
    AppController *controller = [NSApp delegate];
    
    // Unread count may have changed
    [controller setStatusMessage:nil persist:NO];
    [controller showUnreadCountOnApplicationIconAndWindowTitle];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListStateChange" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:[folder itemId]]];
    
}

-(void)notifyDelegateOfCompletion
{
    [delegate mergeDidComplete];
}

-(void)updateMessageWithText:(NSString *)message
{
    [delegate statusMessageChanged:message];
}

-(void)doMain
{
    GoogleReader * googleReader = [GRSOperation sharedGoogleReader];
    [self performSelectorOnMainThread:@selector(updateMessageWithText:) withObject:@"Fetching Google Reader subscriptions..." waitUntilDone:YES];
    [super doMain];
    
    for (Folder * f in [self folders])
    {
        NSString * message = [NSString stringWithFormat:@"Processing %@...", [f name]];
        [self performSelectorOnMainThread:@selector(updateMessageWithText:) withObject:message waitUntilDone:YES];
        if (![googleReader subscribingTo:[f feedURL]]) [googleReader subscribeToFeed:[f feedURL]];
        
        [self performSelectorOnMainThread:@selector(fetchArticlesForFolder:) withObject:f waitUntilDone:YES];
        for (Article * a in articles)
        {
            NSDictionary * data = [self readingListDataForArticle:a];
            if (data)
            {
                BOOL read = NO;
                BOOL flagged = NO;
                    
                NSString * itemGuid = [data objectForKey:@"id"];
                if ([a isRead]) 
                {
                    read = YES;
                    [googleReader markRead:itemGuid readFlag:YES];
                }
                if ([a isFlagged]) 
                {
                    flagged = YES;
                    [googleReader markStarred:itemGuid starredFlag:YES];
                }
                    
                NSArray * categories = [data objectForKey:@"categories"];
                for (NSString * category in categories)
                {
                    if (!read && [category hasSuffix:@"read"])
                    {
                        [self performSelectorOnMainThread:@selector(markRead:) withObject:a waitUntilDone:NO];
                    }
                    if (!flagged && [category hasSuffix:@"starred"])
                    {
                        [self performSelectorOnMainThread:@selector(markFlagged:) withObject:a waitUntilDone:NO];
                    }
                    if (read && [category hasSuffix:@"/kept-unread"])
                    {
                        [self performSelectorOnMainThread:@selector(markUnread:) withObject:a waitUntilDone:NO];
                    }
                }
            }
            else 
            {
                // This article isn't in the Google Reader reading list. For consistency with
                // other refersh operations, assume it has been read and mark read in Vienna.
                [self performSelectorOnMainThread:@selector(markRead:) withObject:a waitUntilDone:NO];
            }
        }
        
        // Manually refresh
        GRSRefreshOperation * op = [[GRSRefreshOperation alloc] init];
        [op setFolder:f];
        [op setType:MA_Sync_Refresh];
        [op doMain];
        
        [self performSelectorOnMainThread:@selector(mergeFinishedForFolder:) withObject:f waitUntilDone:YES];
    }
    
    [self performSelectorOnMainThread:@selector(updateMessageWithText:) withObject:@"Finished" waitUntilDone:YES];
    [self performSelectorOnMainThread:@selector(notifyDelegateOfCompletion) withObject:nil waitUntilDone:NO];
}

-(void)dealloc
{
    [articles release];
}

@end
