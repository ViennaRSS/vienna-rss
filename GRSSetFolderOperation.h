//
//  GRSSetFolderOperation.h
//  Vienna
//
//  Created by Adam Hartford on 7/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSOperation.h"

@class Folder;

@interface GRSSetFolderOperation : GRSOperation
{
    BOOL folderFlag;
    
    Folder * folder;
    Folder * oldParent;
    Folder * newParent;
    
    NSString * oldLabel;
    NSString * newLabel;
}

@property (nonatomic) BOOL folderFlag;

@property (nonatomic, retain) Folder * folder;
@property (nonatomic, retain) Folder * oldParent;
@property (nonatomic, retain) Folder * newParent;

@end
