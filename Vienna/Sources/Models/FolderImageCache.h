//
//  FolderImageCache.h
//  Vienna
//
//  Created by Joshua Pore on 8/03/2015.
//  Copyright (c) 2015 The Vienna Project. All rights reserved.
//

@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface FolderImageCache : NSObject

@property (class, readonly, nonatomic) FolderImageCache *defaultCache;

/// Add the specified image data to the cache and save it to disk.
- (BOOL)cacheImageData:(NSData *)imageData filename:(NSString *)filename;

/// Retrieve the image for the specified URL from the cache.
- (nullable NSImage *)retrieveImage:(NSString *)filename;

@end

NS_ASSUME_NONNULL_END
