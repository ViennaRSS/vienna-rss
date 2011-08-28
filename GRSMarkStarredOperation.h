//
//  GRSMarkStarredOperation.h
//  Vienna
//
//  Created by Adam Hartford on 7/29/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSOperation.h"

@interface GRSMarkStarredOperation : GRSOperation
{
    NSArray * articles;
    BOOL starredFlag;
}

@property (nonatomic, copy) NSArray * articles;
@property (nonatomic) BOOL starredFlag;

@end
