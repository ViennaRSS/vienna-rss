//
//  FolderImageCache.h
//  Vienna
//
//  Created by Joshua Pore on 8/03/2015.
//  Copyright (c) 2015 The Vienna Project. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FolderImageCache : NSObject {
    NSString * imagesCacheFolder;
    NSMutableDictionary * folderImagesArray;
    BOOL initializedFolderImagesArray;
}

// Indexes into folder image array
enum {
    MA_FolderIcon = 0,
    MA_SmartFolderIcon,
    MA_RSSFolderIcon,
    MA_RSSFeedIcon,
    MA_TrashFolderIcon,
    MA_SearchFolderIcon,
    MA_GoogleReaderFolderIcon,
    MA_Max_Icons
};

+(FolderImageCache *)defaultCache;
-(void)addImage:(NSImage *)image forURL:(NSString *)baseURL;
-(NSImage *)retrieveImage:(NSString *)baseURL;

@end
