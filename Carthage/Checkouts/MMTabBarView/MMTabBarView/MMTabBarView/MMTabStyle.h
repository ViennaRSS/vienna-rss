//
//  MMTabStyle.h
//  MMTabBarView
//
//  Created by John Pannell on 2/17/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

/*
   Protocol to be observed by all style delegate objects.  These objects handle the drawing responsibilities for MMTabBarButtonCell; once the control has been assigned a style, the background and button cells draw consistent with that style.  Design pattern and implementation by David Smith, Seth Willits, and Chris Forsythe, all touch up and errors by John P. :-)
 */


#import "MMTabBarView.Globals.h"
#import "MMTabBarButton.Common.h"

NS_ASSUME_NONNULL_BEGIN

@class MMTabBarView;
@class MMOverflowPopUpButton;
@class MMRolloverButton;
@class MMTabBarButtonCell;
@class MMAttachedTabBarButton;

@protocol MMTabStyle <NSObject>

#pragma mark Style name

/**
 *  Name of style
 *
 *  @return Style name
 */
+ (NSString *)name;

/**
 *  Name of style
 */
@property (readonly) NSString *name;

@optional

#pragma mark General

- (BOOL)needsResizeTabsToFitTotalWidth;

/**
 *  Get intrinsic content size of tab bar
 *
 *  @param tabBarView A tab bar view
 *
 *  @return Intrinsic content size
 */
- (NSSize)intrinsicContentSizeOfTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Get height of tab bar buttons
 *
 *  @param tabBarView A tab bar view
 *
 *  @return The height of tab bar buttons
 */
- (CGFloat)heightOfTabBarButtonsForTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Check if tab style supports given orientation for specified tab bar view
 *
 *  @param orientation An orientation
 *  @param tabBarView  The tab bar view
 *
 *  @return YES or NO
 */
- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation forTabBarView:(MMTabBarView *)tabBarView;

#pragma mark Working with margins

/**
 *  Get left margin for specified tab bar view
 *
 *  @param tabBarView The tab bar view
 *
 *  @return Margin value
 */
- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Get right margin for specified tab bar view
 *
 *  @param tabBarView The tab bar view
 *
 *  @return Margin value
 */
- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Get top margin for specified tab bar view
 *
 *  @param tabBarView The tab bar view
 *
 *  @return Margin value
 */
- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Get bottom margin for specified tab bar view
 *
 *  @param tabBarView The tab bar view
 *
 *  @return Margin value
 */
- (CGFloat)bottomMarginForTabBarView:(MMTabBarView *)tabBarView;

#pragma mark Working with 'add button'

/**
 *  Get padding of tab bar view's 'add button'
 *
 *  @param tabBarView A tab bar view
 *
 *  @return Padding width of 'add button'
 */
- (CGFloat)addTabButtonPaddingForTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Get size of tab bar view's 'add button'
 *
 *  @param tabBarView A tab bar view
 *
 *  @return Size of 'add button'
 */
- (NSSize)addTabButtonSizeForTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Get frame rect of tab bar view's 'add button'
 *
 *  @param tabBarView A tab bar view
 *
 *  @return Frame rect of 'add button'
 */
- (NSRect)addTabButtonRectForTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Delegate override for the button creation
 *
 *  @param frame    The 'frame of of the new button'
 *  @param tabBarView The tab bar view
 */
- (MMRolloverButton *)rolloverButtonWithFrame:(NSRect)frame ofTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Update 'add button'
 *
 *  @param aButton    The 'add button'
 *  @param tabBarView The tab bar view
 */
- (void)updateAddButton:(MMRolloverButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView;

#pragma mark Working with 'overflow button'

/**
 *  Get size of tab bar view's 'overflow button'
 *
 *  @param tabBarView A tab bar view
 *
 *  @return Size of 'overflow button'
 */
- (NSSize)overflowButtonSizeForTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Get padding of tab bar view's 'overflow button'
 *
 *  @param tabBarView A tab bar view
 *
 *  @return Padding width of 'overflow button'
 */
- (CGFloat)overflowButtonPaddingForTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Get frame rect of tab bar view's 'overflow button'
 *
 *  @param tabBarView A tab bar view
 *
 *  @return Frame rect of 'overflow button'
 */
- (NSRect)overflowButtonRectForTabBarView:(MMTabBarView *)tabBarView;

/**
 *  Update 'overflow button'
 *
 *  @param aButton    The 'overflow button'
 *  @param tabBarView The tab bar view
 */
- (void)updateOverflowPopUpButton:(MMOverflowPopUpButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView;

#pragma mark Working with tab bar button cells

/**
 *  Get attributed string representing object count
 *
 *  @param cell A tab bar button cell
 *
 *  @return Object count (attributed string)
 */
- (NSAttributedString *)attributedObjectCountStringValueForTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Get attributed string value
 *
 *  @param cell A tab bar button cell
 *
 *  @return Attributed string value
 */
- (NSAttributedString *)attributedStringValueForTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Minimum width of tab bar button cell
 *
 *  @param cell A tab bar button cell
 *
 *  @return Minimum width
 */
- (CGFloat)minimumWidthOfTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Desired width of tab bar button cell
 *
 *  @param cell A tab bar button cell
 *
 *  @return Desired width
 */
- (CGFloat)desiredWidthOfTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Update close button
 *
 *  @param closeButton A close button (@see MMRolloverButton)
 *  @param cell        A tab bar button cell
 *
 *  @return YES or NO, returning NO will hide the close button
 */
- (BOOL)updateCloseButton:(MMRolloverButton *)closeButton ofTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Get close button image 
 *
 *  @param type Button image type (@see MMCloseButtonImageType)
 *  @param cell A tab bar button cell
 *
 *  @return The close button image
 */
- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell;

#pragma mark Determining rects of tab bar button cell components

/**
 *  Get drawing rect for bounds of tab bar button cell
 *
 *  @param theRect Bounds rect
 *  @param cell    Tab bar button cell
 *
 *  @return A drawing rect
 */
- (NSRect)drawingRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Get size of close button for bounds of tab bar button cell
 *
 *  @param theRect Bounds rect
 *  @param cell    A tab bar button cell
 *
 *  @return Close button size
 */
- (NSSize)closeButtonSizeForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Allows the style to override the close button and provide its own subclass
 *
 *  @param theRect Bounds rect
 *  @param cell    A tab bar button cell
 *
 *  @return Close button. An instance of a subclass of MMRolloverButton
 */
- (MMRolloverButton *)closeButtonForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Get rect of close button for bounds of tab bar button cell
 *
 *  @param theRect Bounds rect
 *  @param cell    A tab bar button cell
 *
 *  @return Close button rect
 */
- (NSRect)closeButtonRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Get rect of title for bounds of tab bar button cell
 *
 *  @param theRect Bounds rect
 *  @param cell    A tab bar button cell
 *
 *  @return Title rect
 */
- (NSRect)titleRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Get rect of icon for bounds of tab bar button cell
 *
 *  @param theRect Bounds rect
 *  @param cell    A tab bar button cell
 *
 *  @return Icon rect
 */
- (NSRect)iconRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Get rect of large image for bounds of tab bar button cell
 *
 *  @param theRect Bounds rect
 *  @param cell    A tab bar button cell
 *
 *  @return Large image rect
 */
- (NSRect)largeImageRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Get rect of progress indicator for bounds of tab bar button cell
 *
 *  @param theRect Bounds rect
 *  @param cell    A tab bar button cell
 *
 *  @return Progress indicator rect
 */
- (NSRect)indicatorRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Get size of object counter for specified tab bar button cell
 *
 *  @param cell A tab bar button cell
 *
 *  @return Size of object counter
 */
- (NSSize)objectCounterSizeOfTabCell:(MMTabBarButtonCell *)cell;

/**
 *  Get rect of object counter for bounds of tab bar button cell
 *
 *  @param theRect Bounds rect
 *  @param cell    A tab bar button cell
 *
 *  @return object counter rect
 */
- (NSRect)objectCounterRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

#pragma mark Drawing the tab bar view

/**
 *  Draw tab bar view
 *
 *  @param tabBarView A tab bar view
 *  @param rect       Drawing rect in tab bar view's coos
 */
- (void)drawTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;

/**
 *  Draw bezel of tab bar view
 *
 *  @param tabBarView A tab bar view
 *  @param rect       Drawing rect in tab bar view's coos
 */
- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;

/**
 *  Draw button bezels of tab bar view
 *
 *  @param tabBarView A tab bar view
 *  @param rect       Drawing rect in tab bar view's coos
 */
- (void)drawButtonBezelsOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;

/**
 *  Draw interior of tab bar view
 *
 *  @param tabBarView A tab bar view
 *  @param rect       Drawing rect in tab bar view's coos
 */
- (void)drawInteriorOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;

/**
 *  Draw bezel of tab bar button
 *
 *  @param button     A tab bar button
 *  @param index      Index of tab bar button
 *  @param buttons    Array of all buttons
 *  @param selIndex   Index of selected button
 *  @param tabBarView Tab bar view to draw
 *  @param rect       Drawing rect in tab bar view's coos
 */
- (void)drawBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray<MMAttachedTabBarButton *> *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;

/**
 *  Draw bezel of overflow button
 *
 *  @param overflowButton An overflow button
 *  @param tabBarView     Tab bar view to draw
 *  @param rect           Drawing rect in tab bar view's coos
 */
- (void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;

#pragma mark Drawing tab bar button cells

/**
 *  Draw tab bar cell
 *
 *  @param cell        The tab bar button cell
 *  @param frame       Frame of tab bar button cell
 *  @param controlView Cell's control view
 */
- (void)drawTabBarCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;

/**
 *  Draw bezel of tab bar cell
 *
 *  @param cell        The tab bar button cell
 *  @param frame       Frame of tab bar button cell
 *  @param controlView Cell's control view
 */
- (void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;

/**
 *  Draw interior of tab bar cell
 *
 *  @param cell        The tab bar button cell
 *  @param frame       Frame of tab bar button cell
 *  @param controlView Cell's control view
 */
- (void)drawInteriorOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;

/**
 *  Draw title of tab bar cell
 *
 *  @param cell        The tab bar button cell
 *  @param frame       Frame of tab bar button cell
 *  @param controlView Cell's control view
 */
- (void)drawTitleOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;

/**
 *  Draw icon of tab bar cell
 *
 *  @param cell        The tab bar button cell
 *  @param frame       Frame of tab bar button cell
 *  @param controlView Cell's control view
 */
- (void)drawIconOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;

/**
 *  Draw large image of tab bar cell
 *
 *  @param cell        The tab bar button cell
 *  @param frame       Frame of tab bar button cell
 *  @param controlView Cell's control view
 */
- (void)drawLargeImageOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;

/**
 *  Draw progress indicator of tab bar cell
 *
 *  @param cell        The tab bar button cell
 *  @param frame       Frame of tab bar button cell
 *  @param controlView Cell's control view
 */
- (void)drawIndicatorOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;

/**
 *  Draw object counter of tab bar cell
 *
 *  @param cell        The tab bar button cell
 *  @param frame       Frame of tab bar button cell
 *  @param controlView Cell's control view
 */
- (void)drawObjectCounterOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;

/**
 *  Draw close button of tab bar cell
 *
 *  @param cell        The tab bar button cell
 *  @param frame       Frame of tab bar button cell
 *  @param controlView Cell's control view
 */
- (void)drawCloseButtonOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;

#pragma mark Support Drag & Drop

/**
 *  Get dragging rect for specified tab bar button
 *
 *  @param aButton    A tab bar button
 *  @param tabBarView A tab bar view
 *
 *  @return The dragging rect
 */
- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView;

@end

NS_ASSUME_NONNULL_END
