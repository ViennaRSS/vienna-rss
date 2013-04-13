//
//  PSMTabStyle.h
//  PSMTabBarControl
//
//  Created by John Pannell on 2/17/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

/*
   Protocol to be observed by all style delegate objects.  These objects handle the drawing responsibilities for PSMTabBarCell; once the control has been assigned a style, the background and cells draw consistent with that style.  Design pattern and implementation by David Smith, Seth Willits, and Chris Forsythe, all touch up and errors by John P. :-)
 */

#import "PSMTabBarCell.h"
#import "PSMTabBarControl.h"

@protocol PSMTabStyle <NSObject>

// identity
+ (NSString *)name;
- (NSString *)name;

// add tab button
- (NSImage *)addTabButtonImage;
- (NSImage *)addTabButtonPressedImage;
- (NSImage *)addTabButtonRolloverImage;

@optional

// control specific parameters
- (CGFloat)leftMarginForTabBarControl:(PSMTabBarControl *)tabBarControl;
- (CGFloat)rightMarginForTabBarControl:(PSMTabBarControl *)tabBarControl;
- (CGFloat)topMarginForTabBarControl:(PSMTabBarControl *)tabBarControl;
- (CGFloat)bottomMarginForTabBarControl:(PSMTabBarControl *)tabBarControl;
- (NSSize)addTabButtonSizeForTabBarControl:(PSMTabBarControl *)tabBarControl;
- (NSRect)addTabButtonRectForTabBarControl:(PSMTabBarControl *)tabBarControl;
- (NSSize)overflowButtonSizeForTabBarControl:(PSMTabBarControl *)tabBarControl;
- (NSRect)overflowButtonRectForTabBarControl:(PSMTabBarControl *)tabBarControl;

// cell values
- (NSAttributedString *)attributedObjectCountStringValueForTabCell:(PSMTabBarCell *)cell;
- (NSAttributedString *)attributedStringValueForTabCell:(PSMTabBarCell *)cell;

// Constraints
- (CGFloat)minimumWidthOfTabCell:(PSMTabBarCell *)cell;
- (CGFloat)desiredWidthOfTabCell:(PSMTabBarCell *)cell;

// Providing Images
- (NSImage *)closeButtonImageOfType:(PSMCloseButtonImageType)type forTabCell:(PSMTabBarCell *)cell;

// Determining Cell Size
- (CGFloat)heightOfTabCellsForTabBarControl:(PSMTabBarControl *)tabBarControl;
- (NSRect)drawingRectForBounds:(NSRect)theRect ofTabCell:(PSMTabBarCell *)cell;
- (NSRect)titleRectForBounds:(NSRect)theRect ofTabCell:(PSMTabBarCell *)cell;
- (NSRect)iconRectForBounds:(NSRect)theRect ofTabCell:(PSMTabBarCell *)cell;
- (NSRect)largeImageRectForBounds:(NSRect)theRect ofTabCell:(PSMTabBarCell *)cell;
- (NSRect)indicatorRectForBounds:(NSRect)theRect ofTabCell:(PSMTabBarCell *)cell;
- (NSSize)objectCounterSizeOfTabCell:(PSMTabBarCell *)cell;
- (NSRect)objectCounterRectForBounds:(NSRect)theRect ofTabCell:(PSMTabBarCell *)cell;
- (NSRect)closeButtonRectForBounds:(NSRect)theRect ofTabCell:(PSMTabBarCell *)cell;

// Drawing
- (void)drawTabBarControl:(PSMTabBarControl *)tabBarControl inRect:(NSRect)rect;
- (void)drawBezelOfTabBarControl:(PSMTabBarControl *)tabBarControl inRect:(NSRect)rect;
- (void)drawInteriorOfTabBarControl:(PSMTabBarControl *)tabBarControl inRect:(NSRect)rect;

- (void)drawTabBarCell:(PSMTabBarCell *)cell withFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawBezelOfTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawInteriorOfTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawTitleOfTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawIconOfTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;;
- (void)drawLargeImageOfTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawIndicatorOfTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawObjectCounterOfTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawCloseButtonOfTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;

// Dragging Support
- (NSRect)dragRectForTabCell:(PSMTabBarCell *)cell ofTabBarControl:(PSMTabBarControl *)tabBarControl;

// Deprecated Stuff

- (void)drawTabCell:(PSMTabBarCell *)cell DEPRECATED_ATTRIBUTE;
- (NSRect)closeButtonRectForTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)cellFrame DEPRECATED_ATTRIBUTE;
- (NSRect)iconRectForTabCell:(PSMTabBarCell *)cell DEPRECATED_ATTRIBUTE;
- (NSRect)indicatorRectForTabCell:(PSMTabBarCell *)cell DEPRECATED_ATTRIBUTE;
- (NSRect)objectCounterRectForTabCell:(PSMTabBarCell *)cell DEPRECATED_ATTRIBUTE;
- (void)setOrientation:(PSMTabBarOrientation)value DEPRECATED_ATTRIBUTE;
- (void)drawBackgroundInRect:(NSRect)rect DEPRECATED_ATTRIBUTE;
- (void)drawTabBar:(PSMTabBarControl *)bar inRect:(NSRect)rect DEPRECATED_ATTRIBUTE;
- (CGFloat)tabCellHeight DEPRECATED_ATTRIBUTE;
- (NSRect)dragRectForTabCell:(PSMTabBarCell *)cell orientation:(PSMTabBarOrientation)orientation DEPRECATED_ATTRIBUTE;
- (NSAttributedString *)attributedObjectCountValueForTabCell:(PSMTabBarCell *)cell DEPRECATED_ATTRIBUTE;
- (CGFloat)leftMarginForTabBarControl DEPRECATED_ATTRIBUTE;
- (CGFloat)rightMarginForTabBarControl DEPRECATED_ATTRIBUTE;
- (CGFloat)topMarginForTabBarControl DEPRECATED_ATTRIBUTE;
@end

