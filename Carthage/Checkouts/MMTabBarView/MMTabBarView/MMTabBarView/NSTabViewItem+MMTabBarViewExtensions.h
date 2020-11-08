//
//  NSTabViewItem+MMTabBarViewExtensions.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/29/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

#import "MMTabBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSTabViewItem (MMTabBarViewExtensions) <MMTabBarItem>

@property (nullable, retain) NSImage *largeImage;
@property (nullable, retain) NSImage *icon;
@property (assign) BOOL isProcessing;
@property (assign) NSInteger objectCount;
@property (nullable, retain) NSColor *objectCountColor;
@property (assign) BOOL showObjectCount;
@property (assign) BOOL isEdited;
@property (assign) BOOL hasCloseButton;

@end

NS_ASSUME_NONNULL_END
