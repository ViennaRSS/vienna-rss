//
//  GRSSubscribeOperation.h
//  Vienna
//
//  Created by Adam Hartford on 7/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSOperation.h"

@class Folder;

@interface GRSSubscribeOperation : GRSOperation
{
    NSMutableArray * folders;
    BOOL subscribeFlag;
}

@property (nonatomic, retain) NSMutableArray * folders;
@property (nonatomic) BOOL subscribeFlag;

@end
