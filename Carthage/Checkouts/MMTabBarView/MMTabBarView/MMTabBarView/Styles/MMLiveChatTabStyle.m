//
//  MMLiveChatTabStyle.m
//  --------------------
//
//  Created by Keith Blount on 30/04/2006.
//  Copyright 2006 Keith Blount. All rights reserved.
//

#import "MMLiveChatTabStyle.h"
#import "MMAttachedTabBarButton.h"
#import "MMAttachedTabBarButtonCell.h"
#import "MMTabBarView.h"
#import "NSView+MMTabBarViewExtensions.h"
#import "NSCell+MMTabBarViewExtensions.h"
#import "NSBezierPath+MMTabBarViewExtensions.h"
#import "MMTabBarButtonCell.h"
#import "MMOverflowPopUpButton.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMLiveChatTabStyle ()
@end

@implementation MMLiveChatTabStyle
{
	NSImage				*liveChatCloseButton;
	NSImage				*liveChatCloseButtonDown;
	NSImage				*liveChatCloseButtonOver;
	NSImage				*liveChatCloseDirtyButton;
	NSImage				*liveChatCloseDirtyButtonDown;
	NSImage				*liveChatCloseDirtyButtonOver;

	NSDictionary<NSAttributedStringKey, id> *_objectCountStringAttributes;
}

+ (NSString *)name {
    return @"LiveChat";
}

- (NSString *)name {
	return self.class.name;
}

#pragma mark -
#pragma mark Creation/Destruction

- (instancetype) init {
	if ((self = [super init])) {
		liveChatCloseButton = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front"];
		liveChatCloseButtonDown = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front_Pressed"];
		liveChatCloseButtonOver = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front_Rollover"];

		liveChatCloseDirtyButton = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front"];
		liveChatCloseDirtyButtonDown = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front_Pressed"];
		liveChatCloseDirtyButtonOver = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front_Rollover"];

		NSFont* const font = [NSFont fontWithName:@"Lucida Grande" size:11.0];
		NSFont* const styledFont = [NSFontManager.sharedFontManager convertFont:font toHaveTrait:NSBoldFontMask];
		_objectCountStringAttributes = @{
			NSFontAttributeName: styledFont != nil ? styledFont : font,
			NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.85]
		};
		_leftMarginForTabBarView = 5.0;
	}
	return self;
}

#pragma mark -
#pragma mark Tab View Specific

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return _leftMarginForTabBarView;
    else
        return 0.0;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return _leftMarginForTabBarView;
    else
        return 0.0;
}

- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return 0.0;
    else
        return 0.0;
}

- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation forTabBarView:(MMTabBarView *)tabBarView {

    if (orientation != MMTabBarHorizontalOrientation)
        return NO;
    
    return YES;
}

#pragma mark -
#pragma mark Drag Support

- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {

	NSRect dragRect = aButton.stackingFrame;
	dragRect.size.width++;
	return dragRect;
}

#pragma mark -
#pragma mark Providing Images

- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell
{
    switch (type) {
        case MMCloseButtonImageTypeStandard:
            return liveChatCloseButton;
        case MMCloseButtonImageTypeRollover:
            return liveChatCloseButtonOver;
        case MMCloseButtonImageTypePressed:
            return liveChatCloseButtonDown;
            
        case MMCloseButtonImageTypeDirty:
            return liveChatCloseDirtyButton;
        case MMCloseButtonImageTypeDirtyRollover:
            return liveChatCloseDirtyButtonOver;
        case MMCloseButtonImageTypeDirtyPressed:
            return liveChatCloseDirtyButtonDown;
            
        default:
            break;
    }
}

#pragma mark -
#pragma mark Determining Cell Size

- (NSRect)iconRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {
    
    if (!cell.icon)
        return NSZeroRect;

    NSImage *icon = cell.icon;
    if (!icon)
        return NSZeroRect;

    MMTabBarView *tabBarView = cell.tabBarView;
    MMTabBarOrientation orientation = tabBarView.orientation;
    
    if (cell.largeImage && orientation == MMTabBarVerticalOrientation)
        return NSZeroRect;
        
    // calculate rect
    NSRect drawingRect = [cell drawingRectForBounds:theRect];
                
    NSSize iconSize = icon.size;
    
    NSSize scaledIconSize = [cell mm_scaleImageWithSize:iconSize toFitInSize:NSMakeSize(iconSize.width, drawingRect.size.height) scalingType:NSImageScaleProportionallyDown];

    NSRect result = NSMakeRect(drawingRect.origin.x, drawingRect.origin.y, scaledIconSize.width, scaledIconSize.height);

    // center in available space (in case icon image is smaller than kMMTabBarIconWidth)
    if (scaledIconSize.width < kMMTabBarIconWidth) {
        result.origin.x += ceil((kMMTabBarIconWidth - scaledIconSize.width) / 2.0);
    }

    if (scaledIconSize.height < kMMTabBarIconWidth) {
        result.origin.y += ceil((kMMTabBarIconWidth - scaledIconSize.height) / 2.0 - 0.5);
    }

    return NSIntegralRect(result);
}

- (NSRect)titleRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {
    
    NSRect drawingRect = [cell drawingRectForBounds:theRect];

    NSRect constrainedDrawingRect = drawingRect;

    NSRect largeImageRect = [cell largeImageRectForBounds:theRect];
    if (!NSEqualRects(largeImageRect, NSZeroRect)) {
        constrainedDrawingRect.origin.x += NSWidth(largeImageRect)  + kMMTabBarCellPadding;
        constrainedDrawingRect.size.width -= NSWidth(largeImageRect) + kMMTabBarCellPadding;
    } else {
        NSRect iconRect = [cell iconRectForBounds:theRect];
        if (!NSEqualRects(iconRect, NSZeroRect)) {
            constrainedDrawingRect.origin.x += NSWidth(iconRect)  + kMMTabBarCellPadding;
            constrainedDrawingRect.size.width -= NSWidth(iconRect) + kMMTabBarCellPadding;
        }
    }
            
    NSRect indicatorRect = [cell indicatorRectForBounds:theRect];
    if (!NSEqualRects(indicatorRect, NSZeroRect)) {
        constrainedDrawingRect.size.width -= NSWidth(indicatorRect) + kMMTabBarCellPadding;
    }

    NSRect counterBadgeRect = [cell objectCounterRectForBounds:theRect];
    if (!NSEqualRects(counterBadgeRect, NSZeroRect)) {
        constrainedDrawingRect.size.width -= NSWidth(counterBadgeRect) + kMMTabBarCellPadding;
    }

    NSRect closeButtonRect = [cell closeButtonRectForBounds:theRect];
    if (!NSEqualRects(closeButtonRect, NSZeroRect)) {
        constrainedDrawingRect.size.width -= NSWidth(closeButtonRect) + kMMTabBarCellPadding;        
    }
                                    
    NSAttributedString *attrString = cell.attributedStringValue;
    if (attrString.length == 0)
        return NSZeroRect;
        
    NSSize stringSize = attrString.size;
    
    NSRect result = NSMakeRect(constrainedDrawingRect.origin.x, drawingRect.origin.y+ceil((drawingRect.size.height-stringSize.height)/2), constrainedDrawingRect.size.width, stringSize.height);
                    
    return NSIntegralRect(result);
}

- (NSRect)objectCounterRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {

    if (!cell.showObjectCount) {
        return NSZeroRect;
    }

    NSRect drawingRect = [cell drawingRectForBounds:theRect];

    NSRect constrainedDrawingRect = drawingRect;

    NSRect indicatorRect = [cell indicatorRectForBounds:theRect];
    if (!NSEqualRects(indicatorRect, NSZeroRect))
        {
        constrainedDrawingRect.size.width -= NSWidth(indicatorRect) + kMMTabBarCellPadding;
        }

    NSRect closeButtonRect = [cell closeButtonRectForBounds:theRect];
    if (!NSEqualRects(closeButtonRect, NSZeroRect))
        {
        constrainedDrawingRect.size.width -= NSWidth(closeButtonRect) + kMMTabBarCellPadding;
        }
            
    NSSize counterBadgeSize = cell.objectCounterSize;
    
    // calculate rect
    NSRect result;
    result.size = counterBadgeSize; // temp
    result.origin.x = NSMaxX(constrainedDrawingRect)-counterBadgeSize.width;
    result.origin.y = ceil(constrainedDrawingRect.origin.y+(constrainedDrawingRect.size.height-result.size.height)/2);
                
    return NSIntegralRect(result);
}

- (NSRect)indicatorRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {

    if (!cell.isProcessing) {
        return NSZeroRect;
    }

    // calculate rect
    NSRect drawingRect = [cell drawingRectForBounds:theRect];

    NSRect constrainedDrawingRect = drawingRect;
    
    NSRect closeButtonRect = [cell closeButtonRectForBounds:theRect];
    if (!NSEqualRects(closeButtonRect, NSZeroRect))
        {
        constrainedDrawingRect.size.width -= NSWidth(closeButtonRect) + kMMTabBarCellPadding;
        }
        
    NSSize indicatorSize = NSMakeSize(kMMTabBarIndicatorWidth, kMMTabBarIndicatorWidth);
    
    NSRect result = NSMakeRect(NSMaxX(constrainedDrawingRect)-indicatorSize.width,NSMidY(constrainedDrawingRect)-ceil(indicatorSize.height/2),indicatorSize.width,indicatorSize.height);
    
    return NSIntegralRect(result);
}

- (NSRect)closeButtonRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {

    if (cell.shouldDisplayCloseButton == NO) {
        return NSZeroRect;
    }
    
    // ask style for image
    NSImage *image = [cell closeButtonImageOfType:MMCloseButtonImageTypeStandard];
    if (!image)
        return NSZeroRect;
    
    // calculate rect
    NSRect drawingRect = [cell drawingRectForBounds:theRect];
        
    NSSize imageSize = image.size;
    
    NSSize scaledImageSize = [cell mm_scaleImageWithSize:imageSize toFitInSize:NSMakeSize(imageSize.width, drawingRect.size.height) scalingType:NSImageScaleProportionallyDown];

    NSRect result = NSMakeRect(NSMaxX(drawingRect)-scaledImageSize.width, drawingRect.origin.y, scaledImageSize.width, scaledImageSize.height);

    if (scaledImageSize.height < drawingRect.size.height) {
        result.origin.y += ceil((drawingRect.size.height - scaledImageSize.height) / 2.0);
    }

    return NSIntegralRect(result);
}

-(NSRect)largeImageRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell
{
    NSImage *image = cell.largeImage;
    
    if (!image) {
        return NSZeroRect;
    }
    
    // calculate rect
    NSRect drawingRect = [cell drawingRectForBounds:theRect];

    NSRect constrainedDrawingRect = drawingRect;
                
    NSSize scaledImageSize = [cell mm_scaleImageWithSize:image.size toFitInSize:NSMakeSize(constrainedDrawingRect.size.width, constrainedDrawingRect.size.height) scalingType:NSImageScaleProportionallyUpOrDown];
    
    NSRect result = NSMakeRect(constrainedDrawingRect.origin.x,
                                         constrainedDrawingRect.origin.y - ((constrainedDrawingRect.size.height - scaledImageSize.height) / 2),
                                         scaledImageSize.width, scaledImageSize.height);

    if (scaledImageSize.width < kMMTabBarIconWidth) {
        result.origin.x += (kMMTabBarIconWidth - scaledImageSize.width) / 2.0;
    }
    if (scaledImageSize.height < constrainedDrawingRect.size.height) {
        result.origin.y += (constrainedDrawingRect.size.height - scaledImageSize.height) / 2.0;
    }
        
    return result;    
}  // -largeImageRectForBounds:ofTabCell:

#pragma mark -
#pragma mark Cell Values

- (NSAttributedString *)attributedObjectCountStringValueForTabCell:(MMTabBarButtonCell *)cell {
	NSString *contents = [NSString stringWithFormat:@"%lu", (unsigned long)cell.objectCount];
	return [[NSMutableAttributedString alloc] initWithString:contents attributes:_objectCountStringAttributes];
}

- (NSAttributedString *)attributedStringValueForTabCell:(MMTabBarButtonCell *)cell {
	NSMutableAttributedString *attrStr;
	NSString * contents = cell.title;
	attrStr = [[NSMutableAttributedString alloc] initWithString:contents];
	NSRange range = NSMakeRange(0, contents.length);

	[attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:range];

	// Paragraph Style for Truncating Long Text
	static NSMutableParagraphStyle *TruncatingTailParagraphStyle = nil;
	if (!TruncatingTailParagraphStyle) {
		TruncatingTailParagraphStyle = [NSParagraphStyle.defaultParagraphStyle mutableCopy];
		[TruncatingTailParagraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	}
	[attrStr addAttribute:NSParagraphStyleAttributeName value:TruncatingTailParagraphStyle range:range];

	return attrStr;
}

#pragma mark -
#pragma mark Drawing

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {
	//Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
	rect = tabBarView.bounds;

	if (tabBarView.isWindowActive) {
		NSRect gradientRect = rect;
		gradientRect.origin.y += 1.0;
		NSBezierPath *path = [NSBezierPath bezierPathWithRect:gradientRect];
        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.75 alpha:0.0]];
        [gradient drawInBezierPath:path angle:90.0];
	}
    
	[[NSColor colorWithCalibratedWhite:0.576 alpha:1.0] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, NSMinY(rect) + 0.5)
							  toPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect) + 0.5)];
}

- (void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {

    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;
    
    NSRect cellFrame = frame;

	NSToolbar *toolbar = controlView.window.toolbar;
	BOOL showsBaselineSeparator = (toolbar && [toolbar respondsToSelector:@selector(showsBaselineSeparator)] && toolbar.showsBaselineSeparator);
	if (!showsBaselineSeparator) {
		cellFrame.origin.y += 1.0;
		cellFrame.size.height -= 1.0;
	}

	NSColor * lineColor = nil;
	lineColor = [NSColor colorWithCalibratedWhite:0.576 alpha:1.0];

	BOOL drawSelected = cell.state == NSOnState;

    BOOL overflowMode = button.isOverflowButton;
    if (button.isSliding)
        overflowMode = NO;
    
	if (!showsBaselineSeparator || drawSelected) {
		// selected tab
		NSRect aRect = NSMakeRect(cellFrame.origin.x + 0.5, cellFrame.origin.y - 0.5, cellFrame.size.width-1.0, cellFrame.size.height);
		if (drawSelected) {
			aRect.origin.y -= 1.0;
			aRect.size.height += 1.0;
		}

        if (overflowMode)
            aRect.size.width += 0.5;
        
        if (overflowMode) {
            [self _drawBezelInRect:aRect withCapMask:MMBezierShapeLeftCap|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
        } else {
            [self _drawBezelInRect:aRect withCapMask:MMBezierShapeAllCaps|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
        }

	} else {
    
		// unselected tab
		NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
		aRect.origin.y += 0.5;
		aRect.origin.x += 1.5;
		aRect.size.width -= 1;

		aRect.origin.x -= 1;
		aRect.size.width += 1;

		// rollover
		if (cell.mouseHovered) {
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
			NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
		}

		// frame
		[lineColor set];
		if (!(cell.tabState & MMTab_RightIsSelectedMask)) {
			[NSBezierPath strokeLineFromPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y + aRect.size.height - 0.5) toPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect))];
		}
		// Create a thin lighter line next to the dividing line for a bezel effect
		if (!(cell.tabState & MMTab_RightIsSelectedMask)) {
			[[NSColor.whiteColor colorWithAlphaComponent:0.5] set];
			[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(aRect) + 1.0, aRect.origin.y - 0.5)
			 toPoint:NSMakePoint(NSMaxX(aRect) + 1.0, NSMaxY(aRect) - 2.5)];
		}
	}
}

- (void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

    MMAttachedTabBarButton *lastAttachedButton = tabBarView.lastAttachedButton;
    MMAttachedTabBarButtonCell *lastAttachedButtonCell = lastAttachedButton.cell;

    if (lastAttachedButton.isSliding)
        return;
    
    NSRect frame = overflowButton.frame;

	NSToolbar *toolbar = tabBarView.window.toolbar;
	BOOL showsBaselineSeparator = (toolbar && [toolbar respondsToSelector:@selector(showsBaselineSeparator)] && toolbar.showsBaselineSeparator);
	if (!showsBaselineSeparator) {
		frame.origin.y += 1.0;
		frame.size.height -= 1.0;
	}

	NSColor * lineColor = nil;
	lineColor = [NSColor colorWithCalibratedWhite:0.576 alpha:1.0];

	BOOL drawSelected = lastAttachedButtonCell.state == NSOnState;
    
	if (!showsBaselineSeparator || drawSelected) {
		// selected tab
		NSRect aRect = NSMakeRect(frame.origin.x, frame.origin.y - 0.5, frame.size.width-0.5, frame.size.height);
		if (drawSelected) {
			aRect.origin.y -= 1.0;
			aRect.size.height += 1.0;
		}
        aRect.size.width += 5;

        [self _drawBezelInRect:aRect withCapMask:MMBezierShapeRightCap|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:lastAttachedButton ofTabBarView:tabBarView];
       
	} else {
    
    // not implemented yet

	}
}

#pragma mark -
#pragma mark Live Chat Tab Style Drawings

- (void)drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView {

    [self _drawBezelInRect:aRect withCapMask:capMask usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
}

#pragma mark -
#pragma mark Private Methods

- (void)_drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView {

    capMask &= ~MMBezierShapeFillPath;
    
    NSColor *lineColor = [NSColor colorWithCalibratedWhite:0.576 alpha:1.0];

    CGFloat radius = MIN(6.0, 0.5 * MIN(NSWidth(aRect), NSHeight(aRect)));

	BOOL drawSelected = button.state == NSOnState;
    
    NSBezierPath *fillPath = [NSBezierPath bezierPathWithCardInRect:aRect radius:radius capMask:capMask|MMBezierShapeFillPath];

    NSColor *startColor = nil;
    NSColor *endColor = nil;

    if (tabBarView.isWindowActive) {
        if (drawSelected) {
            startColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
            endColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
        } else if (button.mouseHovered) {

            startColor = [NSColor colorWithCalibratedWhite:0.80 alpha:1.0];
            endColor = [NSColor colorWithCalibratedWhite:0.80 alpha:1.0];
        }
    } else if (drawSelected) {
        startColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
        endColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
    }
    
    NSGradient *gradient = [NSGradient.alloc initWithStartingColor:startColor endingColor:endColor];
    [gradient drawInBezierPath:fillPath angle:90.0];

    NSBezierPath *outlinePath = outlinePath = [NSBezierPath bezierPathWithCardInRect:aRect radius:radius capMask:capMask];
  
    [lineColor set];
    [outlinePath stroke];    
}

@end

NS_ASSUME_NONNULL_END
