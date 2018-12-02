//
//  MMRolloverButton.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/8/12.
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

#import "MMRolloverButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMRolloverButton : NSButton 

#pragma mark Cell Interface

@property (nullable, strong) NSImage *rolloverImage;
@property (assign) MMRolloverButtonType rolloverButtonType;

@property (readonly) BOOL mouseHovered;

@property (assign) BOOL simulateClickOnMouseHovered;

@end

NS_ASSUME_NONNULL_END
