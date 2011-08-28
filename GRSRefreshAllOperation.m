//
//  GRSRefreshAllOperation.m
//  Vienna
//
//  Created by Adam Hartford on 7/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSRefreshAllOperation.h"
#import "Folder.h"
#import "GoogleReader.h"
#import "AppController.h"
#import "Database.h"

@implementation GRSRefreshAllOperation

@synthesize folders;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)createNewSubscription:(NSArray *)params
{
    int underFolder = MA_Root_Folder;
    NSString * feedURL = [params objectAtIndex:0];
    
    if ([params count] > 1) 
    {
        NSString * folderName = [params objectAtIndex:1];
        Database * db = [Database sharedDatabase];
        Folder * folder = [db folderFromName:folderName];
        underFolder = [folder itemId];
    }
    
    [[NSApp delegate] createNewSubscription:feedURL underFolder:underFolder afterChild:-1];
}

- (void)createFolders:(NSMutableArray *)params
{
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
        int newFolderId = [db addFolder:[parentNumber intValue] afterChild:-1 folderName:folderName type:MA_Group_Folder canAppendIndex:NO];
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
}

-(void)doMain
{
    GoogleReader * googleReader = [GRSOperation sharedGoogleReader];
    
    NSMutableArray * viennaFeeds = [NSMutableArray array];
    
    for (Folder * f in [self folders]) 
    {
        [viennaFeeds addObject:[f feedURL]];
    }
    
    // Get Google subscriptions
    for (NSDictionary * feed in [googleReader subscriptions]) 
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
        
        if (![viennaFeeds containsObject:feedURL])
        {
            NSArray * params = [NSArray arrayWithObjects:feedURL, folderName, nil];
            [self performSelectorOnMainThread:@selector(createNewSubscription:) withObject:params waitUntilDone:YES];
        }
    }
}

-(void)dealloc 
{
    [folders release];
}

@end
