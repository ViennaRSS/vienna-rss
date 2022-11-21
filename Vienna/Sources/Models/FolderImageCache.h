//
//  FolderImageCache.h
//  Vienna
//
//  Created by Joshua Pore on 8/03/2015.
//  Copyright (c) 2015 The Vienna Project. All rights reserved.
//

@import Cocoa;

@interface FolderImageCache : NSObject {
    NSString * imagesCacheFolder;
    NSMutableDictionary * folderImagesArray;
    BOOL initializedFolderImagesArray;
}

@property (class, readonly, nonatomic) FolderImageCache *defaultCache;

-(void)addImage:(NSImage *)image forURL:(NSString *)baseURL;
-(NSImage *)retrieveImage:(NSString *)baseURL;

@end
