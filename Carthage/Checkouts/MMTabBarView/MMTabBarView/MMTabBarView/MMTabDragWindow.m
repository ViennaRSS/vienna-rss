//
//  MMTabDragWindow.m
//  MMTabBarView
//
//  Created by Kent Sutherland on 6/1/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#import "MMTabDragWindow.h"
#import "MMTabDragView.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMTabDragWindow
{
    MMTabDragView *_dragView;
}

+ (instancetype)dragWindowWithImage:(NSImage *)image styleMask:(NSUInteger)styleMask {
	return [[MMTabDragWindow alloc] initWithImage:image styleMask:styleMask];
}

- (instancetype)initWithImage:(NSImage *)image styleMask:(NSUInteger)styleMask {
	NSSize size = [image size];

	if ((self = [super initWithContentRect:NSMakeRect(0, 0, size.width, size.height) styleMask:styleMask backing:NSBackingStoreBuffered defer:NO])) {
		_dragView = [[MMTabDragView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
		[self setContentView:_dragView];
		[self setLevel:NSStatusWindowLevel];
		[self setIgnoresMouseEvents:YES];
		[self setOpaque:NO];

		[_dragView setImage:image];

		//Set the size of the window to be the exact size of the drag image
		NSRect windowFrame = [self frame];
		windowFrame.origin.y += windowFrame.size.height - size.height;
		windowFrame.size = size;

		if (styleMask | NSBorderlessWindowMask) {
			windowFrame.size.height += 22;
		}

		[self setFrame:windowFrame display:YES];
	}
	return self;
}

- (MMTabDragView *)dragView {
	return _dragView;
}

@end

NS_ASSUME_NONNULL_END
