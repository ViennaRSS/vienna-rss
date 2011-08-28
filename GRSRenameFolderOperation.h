//
//  GRSRenameFolderOperation.h
//  Vienna
//
//  Created by Adam Hartford on 8/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSOperation.h"

@class Folder;

@interface GRSRenameFolderOperation : GRSOperation
{
    Folder * folder;
    NSString * oldName;
    NSString * newName;
}

@property (nonatomic, retain) Folder * folder;
@property (nonatomic, copy) NSString * oldName;
@property (nonatomic, copy) NSString * newName;

@end
