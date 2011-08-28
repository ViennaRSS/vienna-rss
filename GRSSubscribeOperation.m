//
//  GRSSubscribeOperation.m
//  Vienna
//
//  Created by Adam Hartford on 7/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSSubscribeOperation.h"
#import "GoogleReader.h"
#import "Folder.h"
#import "Database.h"

@implementation GRSSubscribeOperation

@synthesize folders;
@synthesize subscribeFlag;

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

    for (Folder * f in folders)
    {
        if (IsRSSFolder(f))
        {
            if (subscribeFlag) [googleReader subscribeToFeed:[f feedURL]];
            else [googleReader unsubscribeFromFeed:[f feedURL]];
        }
        else
        {
            if (subscribeFlag) {} // TODO should this be supported and, if so, how?
            else [googleReader disableTag:[f name]];
        }
    }
}

-(void)dealloc
{
    [folders release];
}

@end
