//
//  PSMTabBarCell.h
//  PSMTabBarControl
//
//  Created by John Pannell on 10/13/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PSMTabBarControl.h"
#import "PSMProgressIndicator.h"

typedef enum PSMCloseButtonImageType
{
    PSMCloseButtonImageTypeStandard = 0,
    PSMCloseButtonImageTypeRollover,
    PSMCloseButtonImageTypePressed,
    PSMCloseButtonImageTypeDirty,
    PSMCloseButtonImageTypeDirtyRollover,
    PSMCloseButtonImageTypeDirtyPressed
} PSMCloseButtonImageType;

typedef enum PSMTabBarCellTrackingAreaType
{
    PSMTabBarCellTrackingAreaCellFrameType   = 0,
    PSMTabBarCellTrackingAreaCloseButtonType = 1
} PSMTabBarCellTrackingAreaType;

@interface PSMTabBarCell : NSActionCell {
	// sizing
	NSRect					_frame;
	NSSize					_attributedStringSize;
	NSInteger				_currentStep;
	BOOL					_isPlaceholder;

	// state
	PSMTabStateMask		    _tabState;
	BOOL					_closeButtonOver;
	BOOL					_closeButtonPressed;
	PSMProgressIndicator	*_indicator;
	BOOL					_isInOverflowMenu;
	BOOL					_hasCloseButton;
	BOOL					_isCloseButtonSuppressed;
	BOOL					_hasIcon;
	BOOL					_hasLargeImage;
	NSInteger				_count;
	NSColor                 *_countColor;
	BOOL					_isEdited;
}

@property (assign) PSMTabStateMask tabState;
@property (assign) BOOL hasCloseButton;
@property (assign) BOOL hasIcon;
@property (assign) BOOL hasLargeImage;
@property (assign) NSInteger count;
@property (retain) NSColor *countColor;
@property (assign) BOOL isPlaceholder;
@property (assign) BOOL isEdited;
@property (assign) BOOL closeButtonPressed;

#pragma mark Creation/Destruction
- (id)init;
- (id)initPlaceholderWithFrame:(NSRect) frame expanded:(BOOL) value inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)dealloc;

#pragma mark Accessors
- (PSMTabBarControl *)controlView;
- (void)setControlView:(PSMTabBarControl *)newControl;
- (CGFloat)width;
- (NSRect)frame;
- (void)setFrame:(NSRect)rect;
- (NSSize)attributedStringSize;
- (NSAttributedString *)attributedStringValue;
- (NSAttributedString *)attributedObjectCountStringValue;
- (NSProgressIndicator *)indicator;
- (BOOL)isInOverflowMenu;
- (void)setIsInOverflowMenu:(BOOL)value;
- (BOOL)closeButtonOver;
- (void)setCloseButtonOver:(BOOL)value;
- (void)setCloseButtonSuppressed:(BOOL)suppress;
- (BOOL)isCloseButtonSuppressed;
- (NSInteger)currentStep;
- (void)setCurrentStep:(NSInteger)value;

#pragma mark Providing Images
- (NSImage *)closeButtonImageOfType:(PSMCloseButtonImageType)type;

#pragma mark Determining Cell Size
- (NSRect)drawingRectForBounds:(NSRect)theRect;
- (NSRect)titleRectForBounds:(NSRect)theRect ;
- (NSRect)iconRectForBounds:(NSRect)theRect;
- (NSRect)largeImageRectForBounds:(NSRect)theRect;
- (NSRect)indicatorRectForBounds:(NSRect)theRect;
- (NSSize)objectCounterSize;
- (NSRect)objectCounterRectForBounds:(NSRect)theRect;
- (NSRect)closeButtonRectForBounds:(NSRect)theRect;

- (CGFloat)minimumWidthOfCell;
- (CGFloat)desiredWidthOfCell;

#pragma mark Image Scaling
- (NSSize)scaleImageWithSize:(NSSize)imageSize toFitInSize:(NSSize)canvasSize scalingType:(NSImageScaling)scalingType;

#pragma mark Drawing
- (BOOL)shouldDrawCloseButton;
- (BOOL)shouldDrawObjectCounter;
- (void)drawWithFrame:(NSRect) cellFrame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawInteriorWithFrame:(NSRect)cellFrame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawLargeImageWithFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawIconWithFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawTitleWithFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawObjectCounterWithFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawIndicatorWithFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)drawCloseButtonWithFrame:(NSRect)frame inTabBarControl:(PSMTabBarControl *)tabBarControl;

#pragma mark Tracking Area Support
- (void)addTrackingAreasForView:(NSView *)view inRect:(NSRect)cellFrame withUserInfo:(NSDictionary *)userInfo mouseLocation:(NSPoint)currentPoint;
- (void)mouseEntered:(NSEvent *)theEvent;
- (void)mouseExited:(NSEvent *)theEvent;

#pragma mark Drag Support
- (NSRect)draggingRect;
- (NSImage *)dragImage;

#pragma mark Archiving
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

@end

@interface PSMTabBarControl (CellAccessors)

- (id<PSMTabStyle>)style;

@end

@interface NSObject (IdentifierAccesors)

- (NSImage *)largeImage;

@end


