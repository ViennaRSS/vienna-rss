//
//  MMTabDragWindow.h
//  MMTabBarView
//
//  Created by Kent Sutherland on 6/1/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MMTabDragView;

@interface MMTabDragWindow : NSWindow

+ (instancetype)dragWindowWithImage:(NSImage *)image styleMask:(NSUInteger)styleMask;

- (instancetype)initWithImage:(NSImage *)image styleMask:(NSUInteger)styleMask;

@property (readonly) MMTabDragView *dragView;

@end

NS_ASSUME_NONNULL_END
