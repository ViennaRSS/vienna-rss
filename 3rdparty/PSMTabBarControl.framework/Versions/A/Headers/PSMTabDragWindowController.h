//
//  PSMTabDragWindowController.h
//  PSMTabBarControl
//
//  Created by Kent Sutherland on 6/18/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PSMTabBarControl.h"

#define kPSMTabDragWindowAlpha 0.75
#define kPSMTabDragAlphaInterval 0.15

@class PSMTabDragView;

@interface PSMTabDragWindowController : NSWindowController {
	PSMTabBarTearOffStyle				_tearOffStyle;
	PSMTabDragView						*_view;
	NSAnimation							*_animation;
	NSTimer								*_timer;

	BOOL									_showingAlternate;
	NSRect									_originalWindowFrame;
}

- (instancetype)initWithWindow:(NSWindow *)window __attribute((objc_designated_initializer));
- (instancetype)initWithCoder:(NSCoder *)coder __attribute((objc_designated_initializer));
- (instancetype)initWithImage:(NSImage *)image styleMask:(NSUInteger) styleMask tearOffStyle:(PSMTabBarTearOffStyle)tearOffStyle __attribute((objc_designated_initializer));

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSImage *image;
@property (NS_NONATOMIC_IOSONLY, copy) NSImage *alternateImage;
@property (NS_NONATOMIC_IOSONLY, getter=isAnimating, readonly) BOOL animating;
- (void)switchImages;
@end
