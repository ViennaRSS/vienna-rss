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

- (BOOL)cacheImageData:(NSData *)imageData filename:(NSString *)filename;

- (nullable NSImage *)retrieveImage:(NSString *)filename;

@end

NS_ASSUME_NONNULL_END
