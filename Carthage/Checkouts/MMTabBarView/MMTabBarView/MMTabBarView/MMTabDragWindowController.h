//
//  MMTabDragWindowController.h
//  MMTabBarView
//
//  Created by Kent Sutherland on 6/18/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif
#import "MMTabBarView.h"

NS_ASSUME_NONNULL_BEGIN

#define kMMTabDragWindowAlpha 0.75
#define kMMTabDragAlphaInterval 0.15

@class MMTabDragView;

@interface MMTabDragWindowController : NSWindowController

- (instancetype)initWithImage:(NSImage *)image styleMask:(NSUInteger) styleMask tearOffStyle:(MMTabBarTearOffStyle)tearOffStyle;

@property (readonly) NSImage *image;

@property (strong) NSImage *alternateImage;

@property (readonly) BOOL isAnimating;

- (void)switchImages;

@end

NS_ASSUME_NONNULL_END
