//
//  GRSRefreshOperation.h
//  Vienna
//
//  Created by Adam Hartford on 7/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSRefreshAllOperation.h"
#import "Constants.h"

@class Folder;
@class GoogleReader;

@protocol GRSRefreshDelegate;

@interface GRSRefreshOperation : GRSRefreshAllOperation
{
    GoogleReader * googleReader;
    Folder * folder;
    NSArray * articles;
    id <GRSRefreshDelegate> delegate;
    SyncTypes type;
    
    NSString * label;
}

@property (nonatomic, retain) GoogleReader * googleReader;
@property (nonatomic, retain) Folder * folder;
@property (nonatomic, copy) NSArray * articles;
@property (nonatomic, assign) id <GRSRefreshDelegate> delegate;
@property (nonatomic) SyncTypes type;

@end

@protocol GRSRefreshDelegate <NSObject>

-(void)syncFinishedForFolder:(Folder *)folder;
-(void)shouldMoveFolder:(Folder *)folder underParent:(Folder *)parent;

@end