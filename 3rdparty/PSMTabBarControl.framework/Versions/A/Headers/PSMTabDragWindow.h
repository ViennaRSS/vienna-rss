//
//  PSMTabDragWindow.h
//  PSMTabBarControl
//
//  Created by Kent Sutherland on 6/1/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PSMTabDragView;

@interface PSMTabDragWindow : NSWindow {
	PSMTabDragView					*_dragView;
}
+ (PSMTabDragWindow *)dragWindowWithImage:(NSImage *)image styleMask:(NSUInteger)styleMask;

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag __attribute((unavailable("You can not create a PSMTabDragWindow through initWithContentRect:styleMask:backing:defer: / Please use -initWithImage:styleMask:")));
- (instancetype)initWithImage:(NSImage *)image styleMask:(NSUInteger)styleMask __attribute((objc_designated_initializer));
@property (NS_NONATOMIC_IOSONLY, readonly, strong) PSMTabDragView *dragView;
@end
