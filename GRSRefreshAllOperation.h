//
//  GRSRefreshAllOperation.h
//  Vienna
//
//  Created by Adam Hartford on 7/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSOperation.h"

@class Folder;

@interface GRSRefreshAllOperation : GRSOperation
{
    NSArray * folders;
}

@property (nonatomic, retain) NSArray * folders;

- (void)createFolders:(NSMutableArray *)params;

@end
