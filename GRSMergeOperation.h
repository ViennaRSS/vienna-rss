//
//  GRSMergeOperation.h
//  Vienna
//
//  Created by Adam Hartford on 8/14/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSRefreshAllOperation.h"

@protocol GRSMergeDelegate;

@interface GRSMergeOperation : GRSRefreshAllOperation
{
    id <GRSMergeDelegate> delegate;
    NSArray * articles;
}

@property (nonatomic, assign) id <GRSMergeDelegate> delegate;

@end

@protocol GRSMergeDelegate <NSObject>

-(void)mergeDidComplete;
-(void)statusMessageChanged:(NSString *)message;

@end
