//
//  MMTabBarButton.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/5/12.
//
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

#import "MMRolloverButton.h"

#import "MMTabBarButton.Common.h"

NS_ASSUME_NONNULL_BEGIN

/*
#import "MMTabBarView.h"
#import "MMRolloverButton.h"
#import "MMProgressIndicator.h"
#import "MMTabBarButton.Common.h"
*/
@class MMTabBarView;
@class MMTabBarButtonCell;
@class MMProgressIndicator;

@protocol MMTabStyle;

@interface MMTabBarButton : MMRolloverButton

- (instancetype)initWithFrame:(NSRect)frame;

#pragma mark Properties

@property (assign) NSRect stackingFrame;
@property (strong) MMRolloverButton *closeButton;
@property (nullable, assign) SEL closeButtonAction;
@property (readonly, strong) MMProgressIndicator *indicator;

@property (nullable, strong) __kindof MMTabBarButtonCell *cell;

- (MMTabBarView *)tabBarView;

#pragma mark Update Cell

- (void)updateCell;
- (void)updateImages;

#pragma mark Dividers

@property (readonly) BOOL shouldDisplayLeftDivider;
@property (readonly) BOOL shouldDisplayRightDivider;

#pragma mark Determine Sizes

- (CGFloat)minimumWidth;
- (CGFloat)desiredWidth;

#pragma mark Interfacing Cell

@property (nullable, strong) id <MMTabStyle> style;
@property (assign) MMTabStateMask tabState;

@property (nullable, strong) NSImage *icon;
@property (nullable, strong) NSImage *largeImage;

@property (assign) BOOL showObjectCount;
@property (assign) NSInteger objectCount;

@property (nullable, strong) NSColor *objectCountColor;

@property (assign) BOOL isEdited;
@property (assign) BOOL isProcessing;

#pragma mark Close Button Support

@property (readonly) BOOL shouldDisplayCloseButton;
@property (assign) BOOL hasCloseButton;
@property (assign) BOOL suppressCloseButton;

@end

NS_ASSUME_NONNULL_END
