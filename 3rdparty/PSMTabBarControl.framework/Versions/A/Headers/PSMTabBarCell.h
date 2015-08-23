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

typedef enum PSMCloseButtonImageType : NSUInteger
{
    PSMCloseButtonImageTypeStandard = 0,
    PSMCloseButtonImageTypeRollover,
    PSMCloseButtonImageTypePressed,
    PSMCloseButtonImageTypeDirty,
    PSMCloseButtonImageTypeDirtyRollover,
    PSMCloseButtonImageTypeDirtyPressed
} PSMCloseButtonImageType;

typedef enum PSMTabBarCellTrackingAreaType : NSUInteger
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
@property (strong) NSColor *countColor;
@property (assign) BOOL isPlaceholder;
@property (assign) BOOL isEdited;
@property (assign) BOOL closeButtonPressed;

#pragma mark Creation/Destruction
- (instancetype)init;
- (instancetype)initPlaceholderWithFrame:(NSRect) frame expanded:(BOOL) value inTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)dealloc;

#pragma mark Accessors
@property (NS_NONATOMIC_IOSONLY, strong) PSMTabBarControl *controlView;
@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat width;
@property (NS_NONATOMIC_IOSONLY) NSRect frame;
@property (NS_NONATOMIC_IOSONLY, readonly) NSSize attributedStringSize;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSAttributedString *attributedStringValue;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSAttributedString *attributedObjectCountStringValue;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) NSProgressIndicator *indicator;
@property (NS_NONATOMIC_IOSONLY) BOOL isInOverflowMenu;
@property (NS_NONATOMIC_IOSONLY) BOOL closeButtonOver;
@property (NS_NONATOMIC_IOSONLY, getter=isCloseButtonSuppressed) BOOL closeButtonSuppressed;
@property (NS_NONATOMIC_IOSONLY) NSInteger currentStep;

#pragma mark Providing Images
- (NSImage *)closeButtonImageOfType:(PSMCloseButtonImageType)type;

#pragma mark Determining Cell Size
- (NSRect)drawingRectForBounds:(NSRect)theRect;
- (NSRect)titleRectForBounds:(NSRect)theRect ;
- (NSRect)iconRectForBounds:(NSRect)theRect;
- (NSRect)largeImageRectForBounds:(NSRect)theRect;
- (NSRect)indicatorRectForBounds:(NSRect)theRect;
@property (NS_NONATOMIC_IOSONLY, readonly) NSSize objectCounterSize;
- (NSRect)objectCounterRectForBounds:(NSRect)theRect;
- (NSRect)closeButtonRectForBounds:(NSRect)theRect;

@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat minimumWidthOfCell;
@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat desiredWidthOfCell;

#pragma mark Image Scaling
- (NSSize)scaleImageWithSize:(NSSize)imageSize toFitInSize:(NSSize)canvasSize scalingType:(NSImageScaling)scalingType;

#pragma mark Drawing
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL shouldDrawCloseButton;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL shouldDrawObjectCounter;
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
@property (NS_NONATOMIC_IOSONLY, readonly) NSRect draggingRect;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSImage *dragImage;

#pragma mark Archiving
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (instancetype)initWithCoder:(NSCoder *)aDecoder;

@end

@interface PSMTabBarControl (CellAccessors)

@property (NS_NONATOMIC_IOSONLY, readonly, strong) id<PSMTabStyle> style;

@end

@interface NSObject (IdentifierAccesors)

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSImage *largeImage;

@end


