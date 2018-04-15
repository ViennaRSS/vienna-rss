//
//  MMProgressIndicator.m
//  MMTabBarView
//
//  Created by John Pannell on 2/23/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

#import "MMProgressIndicator.h"
#import "MMTabBarView.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMTabBarView (MMProgressIndicatorExtensions)

- (void)update;

@end

@implementation MMProgressIndicator

/*
// overrides to make tab bar control re-layout things if status changes
- (void)setHidden:(BOOL)flag {
	[super setHidden:flag];
	[(MMTabBarView *)[self superview] update];
}
*/

- (void)stopAnimation:(nullable id)sender {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
	 selector:@selector(startAnimation:)
	 object:nil];
	[super stopAnimation:sender];
}

@end

NS_ASSUME_NONNULL_END
