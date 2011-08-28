//
//  GRSSetFolderOperation.m
//  Vienna
//
//  Created by Adam Hartford on 7/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSSetFolderOperation.h"
#import "GoogleReader.h"
#import "Folder.h"
#import "Database.h"

@implementation GRSSetFolderOperation

@synthesize folderFlag;
@synthesize folder;
@synthesize oldParent;
@synthesize newParent;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(NSString *)labelForFolder:(Folder *)f
{
    NSMutableArray * folderNames = [NSMutableArray arrayWithObject:[f name]];
    Database * db = [Database sharedDatabase];
    Folder * parent = [db folderFromID:[f parentId]];
    
    if ([parent itemId] == MA_Root_Folder) return nil;
    else
    {
        while (parent)
        {
            [folderNames addObject:[parent name]];
            parent = [db folderFromID:[parent parentId]];
        }
    
        NSArray * path = [[folderNames reverseObjectEnumerator] allObjects];
        return [folderNames count] > 1 ? [path componentsJoinedByString:@" — "] : [folderNames objectAtIndex:0];
    }
}

-(void)buildLabels
{
    if ([oldParent itemId]) oldLabel = [[self labelForFolder:oldParent] retain];
    else oldLabel = nil;
    
    if ([newParent itemId]) newLabel = [[self labelForFolder:newParent] retain];
    else newLabel = nil;
}

-(void)doMain
{
    GoogleReader * googleReader = [GRSOperation sharedGoogleReader];
    
    [self performSelectorOnMainThread:@selector(buildLabels) withObject:nil waitUntilDone:YES];

    if (oldLabel) [googleReader setFolder:oldLabel forFeed:[folder feedURL] folderFlag:NO];
    if (newLabel) [googleReader setFolder:newLabel forFeed:[folder feedURL] folderFlag:YES];
}

-(void)dealloc
{
    [folder release];
    [oldParent release];
    [newParent release];
    
    [oldLabel release];
    [newLabel release];
}

@end
