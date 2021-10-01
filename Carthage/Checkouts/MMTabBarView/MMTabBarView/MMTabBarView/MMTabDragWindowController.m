//
//  MMTabDragWindowController.m
//  MMTabBarView
//
//  Created by Kent Sutherland on 6/18/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#import "MMTabDragWindowController.h"
#import "MMTabDragWindow.h"
#import "MMTabDragView.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMTabDragWindowController
{
	MMTabBarTearOffStyle				_tearOffStyle;
	MMTabDragView						*_view;
	NSAnimation							*_animation;
	NSTimer								*_timer;

	BOOL								_showingAlternate;
	NSRect								_originalWindowFrame;
}

- (instancetype)initWithImage:(NSImage *)image styleMask:(NSUInteger)styleMask tearOffStyle:(MMTabBarTearOffStyle)tearOffStyle {
	MMTabDragWindow *window = [MMTabDragWindow dragWindowWithImage:image styleMask:styleMask];
	if ((self = [super initWithWindow:window])) {
		_view = window.dragView;
		_tearOffStyle = tearOffStyle;

		if (tearOffStyle == MMTabBarTearOffMiniwindow) {
			[window setBackgroundColor:NSColor.clearColor];
			[window setHasShadow:YES];
		}

		[window setAlphaValue:kMMTabDragWindowAlpha];
	}
	return self;
}

- (void)dealloc {
	if (_timer) {
		[_timer invalidate];
	}
}

- (NSImage *)image {
	return _view.image;
}

- (NSImage *)alternateImage {
	return _view.alternateImage;
}

- (void)setAlternateImage:(NSImage *)image {
	[_view setAlternateImage:image];
}

- (BOOL)isAnimating {
	return _animation != nil;
}

- (void)switchImages {
	if (_tearOffStyle != MMTabBarTearOffMiniwindow || !_view.alternateImage) {
		return;
	}

	NSAnimationProgress progress = 0;
	_showingAlternate = !_showingAlternate;

	if (_animation) {
		//An animation already exists, get the current progress
		progress = 1.0f - _animation.currentProgress;
		[_animation stopAnimation];
	}

	//begin animating
	_animation = [[NSAnimation alloc] initWithDuration:0.25 animationCurve:NSAnimationEaseInOut];
	[_animation setAnimationBlockingMode:NSAnimationNonblocking];
	[_animation setCurrentProgress:progress];
	[_animation startAnimation];

	_originalWindowFrame = self.window.frame;

	if (_timer) {
		[_timer invalidate];
	}
	_timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 target:self selector:@selector(animateTimer:) userInfo:nil repeats:YES];
}

- (void)animateTimer:(NSTimer *)timer {
	NSRect frame = _originalWindowFrame;
	NSImage *currentImage = _showingAlternate ? _view.alternateImage : _view.image;
	NSSize size = currentImage.size;
	NSPoint mousePoint = NSEvent.mouseLocation;
	CGFloat animationValue = (CGFloat) _animation.currentValue;

	frame.size.width = _originalWindowFrame.size.width + (size.width - _originalWindowFrame.size.width) * animationValue;
	frame.size.height = _originalWindowFrame.size.height + (size.height - _originalWindowFrame.size.height) * animationValue;
	frame.origin.x = mousePoint.x - (frame.size.width / 2);
	frame.origin.y = mousePoint.y - (frame.size.height / 2);

	[_view setAlpha:_showingAlternate ? 1.0 - animationValue : animationValue];
	[self.window setFrame:frame display:YES];

	if (!_animation.isAnimating) {
		_animation = nil;
		[timer invalidate];
		_timer = nil;
	}
}

@end

NS_ASSUME_NONNULL_END
