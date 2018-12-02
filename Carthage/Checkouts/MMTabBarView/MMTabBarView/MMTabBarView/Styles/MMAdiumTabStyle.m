//
//  MMAdiumTabStyle.m
//  MMTabBarView
//
//  Created by Kent Sutherland on 5/26/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#import "MMAdiumTabStyle.h"
#import "MMAttachedTabBarButtonCell.h"
#import "MMTabBarView.h"
#import "MMAttachedTabBarButton.h"
#import "NSView+MMTabBarViewExtensions.h"
#import "NSCell+MMTabBarViewExtensions.h"
#import "NSBezierPath+MMTabBarViewExtensions.h"
#import "MMTabBarButtonCell.Private.h"
#import "MMOverflowPopUpButton.h"

NS_ASSUME_NONNULL_BEGIN

// #define Adium_CellPadding 2
#define Adium_MARGIN_X 4

@interface MMAdiumTabStyle ()
@end

@implementation MMAdiumTabStyle
{
	NSImage					*_closeButton;
	NSImage					*_closeButtonDown;
	NSImage					*_closeButtonOver;
	NSImage					*_closeDirtyButton;
	NSImage					*_closeDirtyButtonDown;
	NSImage					*_closeDirtyButtonOver;
	NSImage					*_gradientImage;
}

+ (NSString *)name {
    return @"Adium";
}

- (NSString *)name {
	return self.class.name;
}

#pragma mark -
#pragma mark Creation/Destruction

- (instancetype)init {
	if ((self = [super init])) {
		[self _loadImages];
		_drawsUnified = NO;
		_drawsRight = NO;
	}
	return self;
}

#pragma mark -
#pragma mark Tab View Specific

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return 3.0;
    else
        return 0.0;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return 3.0;
    else
        return 0.0;
}

- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return 0.0;
    else
        return 10.0;
}

#pragma mark -
#pragma mark Drag Support

- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {

	NSRect dragRect = aButton.stackingFrame;

    MMTabBarOrientation orientation = tabBarView.orientation;

	if (aButton.state == NSOnState) {
		if (orientation == MMTabBarHorizontalOrientation) {
			dragRect.size.width++;
			dragRect.size.height -= 2.0;
		}
	}

	return dragRect;    
}

#pragma mark -
#pragma mark Providing Images

- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell
{
    switch (type) {
        case MMCloseButtonImageTypeStandard:
            return _closeButton;
        case MMCloseButtonImageTypeRollover:
            return _closeButtonOver;
        case MMCloseButtonImageTypePressed:
            return _closeButtonDown;
            
        case MMCloseButtonImageTypeDirty:
            return _closeDirtyButton;
        case MMCloseButtonImageTypeDirtyRollover:
            return _closeDirtyButtonOver;
        case MMCloseButtonImageTypeDirtyPressed:
            return _closeDirtyButtonDown;
            
        default:
            break;
    }
    
}

#pragma mark -
#pragma mark Determining Cell Size

- (CGFloat)heightOfTabBarButtonsForTabBarView:(MMTabBarView *)tabBarView {
    MMTabBarOrientation orientation = tabBarView.orientation;
	return((orientation == MMTabBarHorizontalOrientation) ? kMMTabBarViewHeight : kMMTabBarViewSourceListHeight);
}

- (NSRect)drawingRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {
    NSRect resultRect;

    MMTabBarView *tabBarView = cell.tabBarView;

    if (tabBarView.orientation == MMTabBarHorizontalOrientation && cell.state == NSOnState) {
        resultRect = NSInsetRect(theRect,Adium_MARGIN_X,0.0);
        resultRect.origin.y += 1;
        resultRect.size.height -= MARGIN_Y + 2;
    } else {
        resultRect = NSInsetRect(theRect, Adium_MARGIN_X, 2.0);
    }
    
    return resultRect;
}

- (NSRect)closeButtonRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {

    if (cell.shouldDisplayCloseButton == NO) {
        return NSZeroRect;
    }

    MMTabBarView *tabBarView = cell.tabBarView;
    MMTabBarOrientation orientation = tabBarView.orientation;
        
    // ask style for image
    NSImage *image = [cell closeButtonImageOfType:MMCloseButtonImageTypeStandard];
    if (!image)
        return NSZeroRect;
    
    // calculate rect
    NSRect drawingRect = [cell drawingRectForBounds:theRect];
        
    NSSize imageSize = image.size;
    
    NSSize scaledImageSize = [cell mm_scaleImageWithSize:imageSize toFitInSize:NSMakeSize(imageSize.width, drawingRect.size.height) scalingType:NSImageScaleProportionallyDown];

    NSRect result;
    if (orientation == MMTabBarHorizontalOrientation) {
        result = NSMakeRect(drawingRect.origin.x, drawingRect.origin.y, scaledImageSize.width, scaledImageSize.height);    
    } else {
    
        NSRect constrainedDrawingRect = drawingRect;

        NSRect indicatorRect = [cell indicatorRectForBounds:theRect];
        if (!NSEqualRects(indicatorRect, NSZeroRect))
            {
            constrainedDrawingRect.size.width -= NSWidth(indicatorRect) + kMMTabBarCellPadding;
            }
    
        result = NSMakeRect(NSMaxX(constrainedDrawingRect)-scaledImageSize.width-Adium_MARGIN_X, constrainedDrawingRect.origin.y, scaledImageSize.width, scaledImageSize.height);
    }

    if (scaledImageSize.height < drawingRect.size.height) {
        result.origin.y += ceil((drawingRect.size.height - scaledImageSize.height) / 2.0);
    }

    return NSIntegralRect(result);
}

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

    NSRect result;
    if (orientation == MMTabBarHorizontalOrientation) {
        {
        result = NSMakeRect(drawingRect.origin.x, drawingRect.origin.y, scaledIconSize.width, scaledIconSize.height);
        }
    } else {
        result = NSMakeRect(drawingRect.origin.x, drawingRect.origin.y, scaledIconSize.width, scaledIconSize.height);
    }
    
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

    MMTabBarView *tabBarView = cell.tabBarView;
    MMTabBarOrientation orientation = tabBarView.orientation;
        
    NSRect drawingRect = [cell drawingRectForBounds:theRect];

    NSRect constrainedDrawingRect = drawingRect;
        
    NSRect indicatorRect = [cell indicatorRectForBounds:theRect];
    if (!NSEqualRects(indicatorRect, NSZeroRect)) {
        constrainedDrawingRect.size.width -= NSWidth(indicatorRect) + kMMTabBarCellPadding;
    }
        
    NSRect largeImageRect = [cell largeImageRectForBounds:theRect];
    if (!NSEqualRects(largeImageRect, NSZeroRect)) {
        constrainedDrawingRect.origin.x += NSWidth(largeImageRect) + kMMTabBarCellPadding;
        constrainedDrawingRect.size.width -= NSWidth(largeImageRect) + kMMTabBarCellPadding;
    }

    if (orientation == MMTabBarHorizontalOrientation) {

        NSRect closeButtonRect = [cell closeButtonRectForBounds:theRect];
        NSRect iconRect = [cell iconRectForBounds:theRect];
    
        if (!NSEqualRects(closeButtonRect, NSZeroRect) || !NSEqualRects(iconRect, NSZeroRect)) {
            constrainedDrawingRect.origin.x += MAX(NSWidth(closeButtonRect),NSWidth(iconRect)) + kMMTabBarCellPadding;
            constrainedDrawingRect.size.width -= MAX(NSWidth(closeButtonRect),NSWidth(iconRect)) + kMMTabBarCellPadding;
        }
        
        NSRect counterBadgeRect = [cell objectCounterRectForBounds:theRect];
        if (!NSEqualRects(counterBadgeRect, NSZeroRect)) {
            constrainedDrawingRect.size.width -= NSWidth(counterBadgeRect) + kMMTabBarCellPadding;
        }
    } else {
    
        if (cell.icon && !cell.largeImage) {
            NSRect iconRect = [cell iconRectForBounds:theRect];
            if (!NSEqualRects(iconRect, NSZeroRect) || !NSEqualRects(iconRect, NSZeroRect)) {
                constrainedDrawingRect.origin.x += NSWidth(iconRect) + kMMTabBarCellPadding;
                constrainedDrawingRect.size.width -= NSWidth(iconRect) + kMMTabBarCellPadding;
                }
        }
    
        NSRect closeButtonRect = [cell closeButtonRectForBounds:theRect];
        NSRect counterBadgeRect = [cell objectCounterRectForBounds:theRect];

        if (!NSEqualRects(closeButtonRect, NSZeroRect) || !NSEqualRects(counterBadgeRect, NSZeroRect)) {
            constrainedDrawingRect.size.width -= MAX(NSWidth(closeButtonRect),NSWidth(counterBadgeRect)) + kMMTabBarCellPadding;
        }    
    }

    NSAttributedString *attrString = cell.attributedStringValue;
    if (attrString.length == 0)
        return NSZeroRect;
        
    NSSize stringSize = attrString.size;
    
    NSRect result = NSMakeRect(constrainedDrawingRect.origin.x, drawingRect.origin.y+ceil((drawingRect.size.height-stringSize.height)/2), constrainedDrawingRect.size.width, stringSize.height);
                    
    return NSIntegralRect(result);
}

- (NSRect)indicatorRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {
    
    if (!cell.isProcessing) {
        return NSZeroRect;
    }
    
    // calculate rect
    NSRect drawingRect = [cell drawingRectForBounds:theRect];
        
    NSSize indicatorSize = NSMakeSize(kMMTabBarIndicatorWidth, kMMTabBarIndicatorWidth);
    
    NSRect result = NSMakeRect(NSMaxX(drawingRect)-indicatorSize.width,NSMidY(drawingRect)-ceil(indicatorSize.height/2),indicatorSize.width,indicatorSize.height);
    
    return NSIntegralRect(result);
}

- (NSRect)objectCounterRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {

    if (cell.objectCount == 0) {
        return NSZeroRect;
    }

    NSRect drawingRect = [cell drawingRectForBounds:theRect];

    NSRect constrainedDrawingRect = drawingRect;

    NSRect indicatorRect = [cell indicatorRectForBounds:theRect];
    if (!NSEqualRects(indicatorRect, NSZeroRect))
        {
        constrainedDrawingRect.size.width -= NSWidth(indicatorRect) + kMMTabBarCellPadding;
        }
            
    NSSize counterBadgeSize = cell.objectCounterSize;
    
    // calculate rect
    NSRect result;
    result.size = counterBadgeSize; // temp
    result.origin.x = NSMaxX(constrainedDrawingRect)-counterBadgeSize.width;
    result.origin.y = ceil(constrainedDrawingRect.origin.y+(constrainedDrawingRect.size.height-result.size.height)/2);
                
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
#pragma mark Drawing

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

	//Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
	rect = tabBarView.bounds;

    MMTabBarOrientation orientation = tabBarView.orientation;

	switch(orientation) {
	case MMTabBarHorizontalOrientation :
		if (_drawsUnified) {
			if (tabBarView.isWindowActive) {
                NSGradient *gradient = [NSGradient.alloc initWithStartingColor:[NSColor colorWithCalibratedWhite:0.835 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.843 alpha:1.0]];
                [gradient drawInRect:rect angle:90.0];
			} else {
				[NSColor.windowBackgroundColor set];
				NSRectFill(rect);
			}
		} else {
			[[NSColor colorWithCalibratedWhite:0.85 alpha:0.6] set];
			[NSBezierPath fillRect:rect];
		}
		break;

	case MMTabBarVerticalOrientation:
		//This is the Mail.app source list background color... which differs from the iTunes one.
		[[NSColor colorWithCalibratedRed:.9059
		  green:.9294
		  blue:.9647
		  alpha:1.0] set];
		NSRectFill(rect);
		break;
	}

	//Draw the border and shadow around the tab bar itself
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext.currentContext setShouldAntialias:NO];

	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:2];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.65 alpha:1.0]];

	[NSColor.grayColor set];

	NSBezierPath *path = NSBezierPath.bezierPath;
	[path setLineWidth:2.0];

	switch(orientation) {
	case MMTabBarHorizontalOrientation:
	{
		[path moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y)];
		[path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y)];
		[shadow setShadowOffset:NSMakeSize(0, -1.0)];

		[shadow set];
		[path stroke];

		break;
	}

	case MMTabBarVerticalOrientation:
	{
		NSPoint startPoint, endPoint;
		NSSize shadowOffset;

		//Draw vertical shadow
		if (_drawsRight) {
			startPoint = NSMakePoint(NSMinX(rect), NSMinY(rect));
			endPoint = NSMakePoint(NSMinX(rect), NSMaxY(rect));
			shadowOffset = NSMakeSize(0.5, -0.5);
		} else {
			startPoint = NSMakePoint(NSMaxX(rect), NSMinY(rect));
			endPoint = NSMakePoint(NSMaxX(rect), NSMaxY(rect));
			shadowOffset = NSMakeSize(-0.5, -1.0);
		}

		[path moveToPoint:startPoint];
		[path lineToPoint:endPoint];
		[shadow setShadowOffset:shadowOffset];

		[shadow set];
		[path stroke];

		[path removeAllPoints];

		//Draw top horizontal shadow
		startPoint = NSMakePoint(NSMinX(rect), NSMinY(rect));
		endPoint = NSMakePoint(NSMaxX(rect), NSMinY(rect));
		shadowOffset = NSMakeSize(0, 0);

		[path moveToPoint:startPoint];
		[path lineToPoint:endPoint];
		[shadow setShadowOffset:shadowOffset];

		[shadow set];
		[path stroke];

		break;
	}
	}

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray<MMAttachedTabBarButton *> *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

    [self _drawBezelWithFrame:button.frame usingStatesOfAttachedButton:button ofTabBarView:tabBarView applyShadow:YES drawRollovers:NO];
}

- (void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {

    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;

    [self _drawBezelWithFrame:frame usingStatesOfAttachedButton:button ofTabBarView:tabBarView applyShadow:NO drawRollovers:YES];
}

- (void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

    MMTabBarOrientation orientation = tabBarView.orientation;
    MMAttachedTabBarButton *lastAttachedButton = tabBarView.lastAttachedButton;
    MMAttachedTabBarButtonCell *lastAttachedButtonCell = lastAttachedButton.cell;

    if (lastAttachedButton.isSliding)
        return;
    
	NSRect buttonFrame = overflowButton.frame;

	NSColor *lineColor = NSColor.grayColor;
    
    if (orientation == MMTabBarHorizontalOrientation) {
            // Draw selected
        if (lastAttachedButtonCell.state == NSOnState) {
            NSRect aRect = NSMakeRect(buttonFrame.origin.x, buttonFrame.origin.y, buttonFrame.size.width-0.5, buttonFrame.size.height-2.5);
            aRect.size.width += 5.0;

            [self _drawBezelInRect:aRect withCapMask:MMBezierShapeRightCap usingStatesOfAttachedButton:lastAttachedButton ofTabBarView:tabBarView applyShadow:YES drawRollovers:YES];
        } else {

            NSRect aRect = NSMakeRect(buttonFrame.origin.x, buttonFrame.origin.y+0.5, buttonFrame.size.width-0.5, buttonFrame.size.height-1.0);
            aRect.size.width += 5.0;

            // rollover
            if (lastAttachedButtonCell.mouseHovered) {
                [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
                NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
            }
            
            if (tabBarView.showAddTabButton) {
                NSBezierPath *bezier = NSBezierPath.bezierPath;
                [bezier moveToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect))];
				[bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect))];
                [lineColor set];                
                [bezier stroke];
            }
        }
    }
}

- (void)drawIconOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {

    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
        
    if (tabBarView.orientation == MMTabBarHorizontalOrientation) {
  
        if (!cell.shouldDisplayCloseButton || !cell.mouseHovered) {
            [cell _drawIconWithFrame:frame inView:controlView];        
        }
    } else {
        if (!cell.largeImage)
            [cell _drawIconWithFrame:frame inView:controlView];
    }
}

- (void)drawObjectCounterOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {

    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
     
    if (tabBarView.orientation == MMTabBarHorizontalOrientation) {
        [cell _drawObjectCounterWithFrame:frame inView:controlView];
    } else {
        if (!cell.shouldDisplayCloseButton || (cell.shouldDisplayCloseButton && !cell.mouseHovered)) {
            [cell _drawObjectCounterWithFrame:frame inView:controlView];
        }
    }
}

- (void)drawCloseButtonOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {

    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
    MMRolloverButton *closeButton = cell.closeButton;

    if (tabBarView.orientation == MMTabBarHorizontalOrientation) {
    
        if (cell.icon) {
            // always act like if tab bar view's onlyShowCloseOnHover would be set to YES
            [closeButton setHidden:!cell.mouseHovered];
        }
    } else {
    
        if (cell.showObjectCount) {
            // always act like if tab bar view's onlyShowCloseOnHover would be set to YES
            [closeButton setHidden:!cell.mouseHovered];
        }
    }
}

#pragma mark -
#pragma mark Private Methods

- (void)_loadImages {
	_closeButton = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front"];
	_closeButtonDown = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front_Pressed"];
	_closeButtonOver = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front_Rollover"];

	_closeDirtyButton = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front"];
	_closeDirtyButtonDown = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front_Pressed"];
	_closeDirtyButtonOver = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front_Rollover"];

	_gradientImage = [MMTabBarView.bundle imageForResource:@"AdiumGradient"];
}

- (void)_drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView applyShadow:(BOOL)applyShadow drawRollovers:(BOOL)drawRollovers {

    MMTabBarOrientation orientation = tabBarView.orientation;

	NSColor *lineColor = NSColor.grayColor;
    
    capMask &= ~MMBezierShapeFillPath;

        // disable antialiasing of bezier paths
    [NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext.currentContext setShouldAntialias:NO];

	NSShadow *shadow = nil;
    if (applyShadow) {
        shadow = [[NSShadow alloc] init];
        [shadow setShadowOffset:NSMakeSize(-1.5, -1.5)];
        [shadow setShadowBlurRadius:2];
        [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.65 alpha:1.0]];
    }

	NSBezierPath *bezier = NSBezierPath.bezierPath;
    [bezier setLineWidth:1.0];
    
    if (orientation == MMTabBarHorizontalOrientation) {

            // selected button
        if (button.state == NSOnState) {

                // fill
			if (_drawsUnified) {
				if (tabBarView.isWindowActive) {
                
                    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.835 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.843 alpha:1.0]];
                    [gradient drawInRect:aRect angle:90.0];
				} else {
					[NSColor.windowBackgroundColor set];
					NSRectFill(aRect);
				}
			} else {
				[_gradientImage drawInRect:NSMakeRect(NSMinX(aRect), NSMinY(aRect), NSWidth(aRect), NSHeight(aRect)) fromRect:NSMakeRect(0, 0, _gradientImage.size.width, _gradientImage.size.height) operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
			}

                // stroke
			[lineColor set];

            if (capMask & MMBezierShapeLeftCap) {
                [bezier setLineWidth:1.0];
                [bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y)];
                [bezier lineToPoint:NSMakePoint(aRect.origin.x, NSMaxY(aRect))];

                if (shadow) {
                    [shadow setShadowOffset:NSMakeSize(-1.0, -1.0)];
                    [shadow set];
                }
                [bezier stroke];
            }

			bezier = NSBezierPath.bezierPath;
			[bezier setLineWidth:1.0];
            
			[bezier moveToPoint:NSMakePoint(NSMinX(aRect), NSMaxY(aRect))];
			[bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect))];
            if (!(capMask & MMBezierShapeRightCap))
                [bezier moveToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect))];
            else
                [bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect))];

			if (button.frame.size.height < 2) {
				// special case of hidden control; need line across top of cell
				[bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y + 0.5)];
				[bezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y + 0.5)];
			}
            
            if (shadow) {
                [shadow setShadowOffset:NSMakeSize(1.0, -1.0)];
                [shadow set];
            }
			[bezier stroke];
            // unselected button        
        } else {

                // rollover
            if (drawRollovers && button.mouseHovered) {
                [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
                NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
            }

                // stroke
            [lineColor set];
            
            [bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y)];
			[bezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y)];
            
            BOOL shouldDisplayRightDivider = button.shouldDisplayRightDivider;
            if (button.tabState & MMTab_RightIsSelectedMask) {
                if ((button.tabState & (MMTab_PlaceholderOnRight | MMTab_RightIsSliding)) == 0)
                    shouldDisplayRightDivider = NO;
            }            
            
			if (shouldDisplayRightDivider) {
				//draw the tab divider
				[bezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y + aRect.size.height)];
			}
            
            if (button.shouldDisplayLeftDivider) {
                [bezier moveToPoint:NSMakePoint(NSMinX(aRect), NSMinY(aRect))];
                [bezier lineToPoint:NSMakePoint(NSMinX(aRect), NSMaxY(aRect))];
            }
            
			[bezier stroke];
        
        }
            
    } else {
    
            // selected button
        if (button.state == NSOnState) {

			// background
			if (_drawsUnified) {
				if (tabBarView.isWindowActive) {
                
                    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.835 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.843 alpha:1.0]];
                    [gradient drawInRect:aRect angle:90.0];
				} else {
					[NSColor.windowBackgroundColor set];
					NSRectFill(aRect);
				}
			} else {
            
                NSGradient *gradient = nil;
                if (_drawsRight) {
                    gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.98 alpha:1.0]];
                } else {
                    gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.98 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];
                }
                
                [gradient drawInRect:aRect angle:0.0];
			}

			// frame
			//top line
			[lineColor set];
			[bezier setLineWidth:1.0];
			[bezier moveToPoint:NSMakePoint(NSMinX(aRect), NSMinY(aRect))];
			[bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect))];
			[bezier stroke];

			//outer edge and bottom lines
			bezier = NSBezierPath.bezierPath;
			[bezier setLineWidth:1.0];
			if (_drawsRight) {
				//Right
				[bezier moveToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect))];
				[bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect))];
				//Bottom
				[bezier lineToPoint:NSMakePoint(NSMinX(aRect), NSMaxY(aRect))];
			} else {
				//Left
				[bezier moveToPoint:NSMakePoint(NSMinX(aRect), NSMinY(aRect))];
				[bezier lineToPoint:NSMakePoint(NSMinX(aRect), NSMaxY(aRect))];
				//Bottom
				[bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect))];
			}
            
            if (shadow) {
                [shadow setShadowOffset:NSMakeSize((_drawsRight ? 1.0 : -1.0), -1.0)];
                [shadow set];
            }
			[bezier stroke];
        
            // unselected button        
        } else {
        
        // draw nothing
        
        }
    }
    
	[NSGraphicsContext restoreGraphicsState];
}

- (void)_drawBezelWithFrame:(NSRect)frame usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView applyShadow:(BOOL)applyShadow drawRollovers:(BOOL)drawRollovers
{

    MMTabBarOrientation orientation = tabBarView.orientation;
    
	NSBezierPath *bezier = NSBezierPath.bezierPath;
    [bezier setLineWidth:1.0];

    BOOL overflowMode = button.isOverflowButton;
    if (button.isSliding)
        overflowMode = NO;
    
	//disable antialiasing of bezier paths
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext.currentContext setShouldAntialias:NO];

	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowOffset:NSMakeSize(-1.5, -1.5)];
	[shadow setShadowBlurRadius:2];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.65 alpha:1.0]];

	if (button.state == NSOnState) {
		// selected tab
		if (orientation == MMTabBarHorizontalOrientation) {
			NSRect aRect = NSMakeRect(frame.origin.x, frame.origin.y, NSWidth(frame), frame.size.height - 2.5);

            if (overflowMode) {
                [self _drawBezelInRect:aRect withCapMask:MMBezierShapeLeftCap usingStatesOfAttachedButton:button ofTabBarView:tabBarView applyShadow:applyShadow drawRollovers:drawRollovers];
            } else {
                [self _drawBezelInRect:aRect withCapMask:MMBezierShapeAllCaps usingStatesOfAttachedButton:button ofTabBarView:tabBarView applyShadow:applyShadow drawRollovers:drawRollovers];
            }
		} else {
			NSRect aRect;

			if (_drawsRight) {
				aRect = NSMakeRect(frame.origin.x - 1, frame.origin.y, frame.size.width - 3, frame.size.height);
			} else {
				aRect = NSMakeRect(frame.origin.x + 2, frame.origin.y, frame.size.width - 2, frame.size.height);
			}
            
            [self _drawBezelInRect:aRect withCapMask:_drawsRight?MMBezierShapeRightCap:MMBezierShapeLeftCap usingStatesOfAttachedButton:button ofTabBarView:tabBarView applyShadow:applyShadow drawRollovers:drawRollovers];
		}
	} else {
		// unselected tab
		NSRect aRect = NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);

        if (overflowMode) {
            [self _drawBezelInRect:aRect withCapMask:MMBezierShapeLeftCap usingStatesOfAttachedButton:button ofTabBarView:tabBarView applyShadow:applyShadow drawRollovers:drawRollovers];
        } else {
            [self _drawBezelInRect:aRect withCapMask:MMBezierShapeAllCaps usingStatesOfAttachedButton:button ofTabBarView:tabBarView applyShadow:applyShadow drawRollovers:drawRollovers];
        }
	}

	[NSGraphicsContext restoreGraphicsState];
}

@end

NS_ASSUME_NONNULL_END
