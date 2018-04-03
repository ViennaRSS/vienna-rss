//
//  MMOverflowPopUpButton.h
//  MMTabBarView
//
//  Created by John Pannell on 11/4/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#if __has_feature(modules)
@import Cocoa;
@import QuartzCore;
#else
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#endif

NS_ASSUME_NONNULL_BEGIN

typedef void (^MMCellBezelDrawingBlock)(NSCell *cell, NSRect frame, NSView *controlView);

@interface MMOverflowPopUpButton : NSPopUpButton 

/**
 *  Second image
 */
@property (strong) NSImage *secondImage;

/**
 *  Block to be used for drawing the bezel
 */
@property (copy) MMCellBezelDrawingBlock bezelDrawingBlock;

@end

NS_ASSUME_NONNULL_END
