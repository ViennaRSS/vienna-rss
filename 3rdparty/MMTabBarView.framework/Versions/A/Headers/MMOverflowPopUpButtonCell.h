//
//  MMOverflowPopUpButtonCell.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/24/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

#import "MMOverflowPopUpButton.h"

NS_ASSUME_NONNULL_BEGIN

@class MMImageTransitionAnimation;

@interface MMOverflowPopUpButtonCell : NSPopUpButtonCell <NSAnimationDelegate>

@property (copy) MMCellBezelDrawingBlock bezelDrawingBlock;
@property (strong) NSImage *image;
@property (strong) NSImage *secondImage;
@property (assign) CGFloat secondImageAlpha;
@property (assign) BOOL centerImage;

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView alpha:(CGFloat)alpha;

@end

NS_ASSUME_NONNULL_END
