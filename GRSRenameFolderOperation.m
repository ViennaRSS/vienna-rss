//
//  GRSRenameFolderOperation.m
//  Vienna
//
//  Created by Adam Hartford on 8/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSRenameFolderOperation.h"
#import "Folder.h"
#import "GoogleReader.h"

@implementation GRSRenameFolderOperation

@synthesize folder;
@synthesize newName;
@synthesize oldName;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)doMain
{
    GoogleReader * googleReader = [GRSOperation sharedGoogleReader];
    
    if (IsRSSFolder([self folder]))
        [googleReader renameFeed:[[self folder] feedURL] to:[self newName]];
    else if (IsGroupFolder([self folder]))
        [googleReader renameTagFrom:[self oldName] to:[self newName]];
}

-(void)dealloc
{
    [folder release];
    [oldName release];
    [newName release];
}

@end
