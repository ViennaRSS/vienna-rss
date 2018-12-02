//
//  MMTabBarButtonCell.h
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

#import "MMRolloverButtonCell.h"

#import "MMTabBarButton.Common.h"

NS_ASSUME_NONNULL_BEGIN

@class MMTabBarView;
@class MMProgressIndicator;
@class MMTabBarButton;
@class MMRolloverButton;

@protocol MMTabStyle;

@interface MMTabBarButtonCell : MMRolloverButtonCell

/**
 *  Default color for object count display
 *
 *  @return The default color
 */
+ (NSColor *)defaultObjectCountColor;

/**
 *  The control view
 * 
 *  TODO: fix, rename "tabBarButton"
 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-property-type"
@property (assign) MMTabBarButton *controlView;
#pragma clang diagnostic pop

/**
 *  Tab bar view the tab bar button belongs to
 */
@property (readonly) MMTabBarView *tabBarView;

#pragma mark Update images

/**
 *  Update images
 */
- (void)updateImages;

#pragma mark Additional Properties

/**
 *  Tab style
 */
@property (strong) id <MMTabStyle> style;

/**
 *  Icon of receiver
 */
@property (nullable, strong) NSImage *icon;

/**
 *  Large image of receiver
 */
@property (nullable, strong) NSImage *largeImage;

/**
 *  Visibility of object count
 */
@property (assign) BOOL showObjectCount;

/**
 *  Current object count
 */
@property (assign) NSInteger objectCount;

/**
 *  Color of object count
 */
@property (nullable, strong) NSColor *objectCountColor;

/**
 *  Edited state
 */
@property (assign) BOOL isEdited;

/**
 *  Processing state
 */
@property (assign) BOOL isProcessing;

/**
 *  Visibility of close button
 */
@property (assign) BOOL hasCloseButton;

/**
 *  Check if close button should be suppressed
 */
@property (assign) BOOL suppressCloseButton;

/**
 *  Current tab state mask
 */
@property (assign) MMTabStateMask tabState;

#pragma mark Progress Indicator Support

/**
 *  Get progress indicator
 */
@property (readonly) MMProgressIndicator *indicator;

#pragma mark Close Button Support

/**
 *  The close button
 */
@property (readonly) MMRolloverButton *closeButton;

/**
 *  Check if receiver should display close button
 */
@property (readonly) BOOL shouldDisplayCloseButton;

/**
 *  Get close button image
 *
 *  @param type Close button image type
 *
 *  @return The image
 */
- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type;

#pragma mark Cell Values

/**
 *  Attributed string value
 */
@property (readonly) NSAttributedString *attributedStringValue;

/**
 *  Object count string value
 */
@property (readonly) NSAttributedString *attributedObjectCountStringValue;

#pragma mark Determining Cell Size

- (NSRect)drawingRectForBounds:(NSRect)theRect;
- (NSRect)titleRectForBounds:(NSRect)theRect ;
- (NSRect)iconRectForBounds:(NSRect)theRect;
- (NSRect)largeImageRectForBounds:(NSRect)theRect;
- (NSRect)indicatorRectForBounds:(NSRect)theRect;
- (NSSize)objectCounterSize;
- (NSRect)objectCounterRectForBounds:(NSRect)theRect;
- (MMRolloverButton *)closeButtonForBounds:(NSRect)theRect;
- (NSRect)closeButtonRectForBounds:(NSRect)theRect;

@property (readonly) CGFloat minimumWidthOfCell;
@property (readonly) CGFloat desiredWidthOfCell;

#pragma mark Drawing

- (void)drawWithFrame:(NSRect) cellFrame inView:(NSView *)controlView;
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (void)drawBezelWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (void)drawLargeImageWithFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawIconWithFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawTitleWithFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawObjectCounterWithFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawIndicatorWithFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawCloseButtonWithFrame:(NSRect)frame inView:(NSView *)controlView;

@end

NS_ASSUME_NONNULL_END
