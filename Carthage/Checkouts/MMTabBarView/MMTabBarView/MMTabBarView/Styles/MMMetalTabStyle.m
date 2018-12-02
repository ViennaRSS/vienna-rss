//
//  MMMetalTabStyle.m
//  MMTabBarView
//
//  Created by John Pannell on 2/17/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

#import "MMMetalTabStyle.h"
#import "MMAttachedTabBarButton.h"
#import "MMAttachedTabBarButtonCell.h"
#import "MMTabBarView.h"
#import "NSView+MMTabBarViewExtensions.h"
#import "NSBezierPath+MMTabBarViewExtensions.h"
#import "MMTabBarButtonCell.h"
#import "MMOverflowPopUpButton.h"
#import "MMOverflowPopUpButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMMetalTabStyle ()

@end

@implementation MMMetalTabStyle
{
	NSImage					*metalCloseButton;
	NSImage					*metalCloseButtonDown;
	NSImage					*metalCloseButtonOver;
	NSImage					*metalCloseDirtyButton;
	NSImage					*metalCloseDirtyButtonDown;
	NSImage					*metalCloseDirtyButtonOver;

	NSDictionary<NSAttributedStringKey, id> *_objectCountStringAttributes;
}

StaticImage(TabNewMetal)
StaticImage(TabNewMetalPressed)
StaticImage(TabNewMetalRollover)

+ (NSString *)name {
    return @"Metal";
}

- (NSString *)name {
	return self.class.name;
}

#pragma mark -
#pragma mark Creation/Destruction

- (instancetype) init {
	if ((self = [super init])) {
		metalCloseButton = [MMTabBarView.bundle imageForResource:@"TabClose_Front"];
		metalCloseButtonDown = [MMTabBarView.bundle imageForResource:@"TabClose_Front_Pressed"];
		metalCloseButtonOver = [MMTabBarView.bundle imageForResource:@"TabClose_Front_Rollover"];

		metalCloseDirtyButton = [MMTabBarView.bundle imageForResource:@"TabClose_Dirty"];
		metalCloseDirtyButtonDown = [MMTabBarView.bundle imageForResource:@"TabClose_Dirty_Pressed"];
		metalCloseDirtyButtonOver = [MMTabBarView.bundle imageForResource:@"TabClose_Dirty_Rollover"];

		NSFont* const font = [NSFont fontWithName:@"Helvetica" size:11.0];
		NSFont* const styledFont = [NSFontManager.sharedFontManager convertFont:font toHaveTrait:NSBoldFontMask];
		_objectCountStringAttributes = @{
			NSFontAttributeName: styledFont != nil ? styledFont : font,
			NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.85]
		};
	}
	return self;
}

#pragma mark -
#pragma mark Tab View Specific

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return 10.0;
    else
        return 0.0;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return 10.0;
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
#pragma mark Add Tab Button

- (void)updateAddButton:(MMRolloverButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {

    [aButton setImage:_staticTabNewMetalImage()];
    [aButton setAlternateImage:_staticTabNewMetalPressedImage()];
    [aButton setRolloverImage:_staticTabNewMetalRolloverImage()];
}

#pragma mark -
#pragma mark Drag Support

- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {

	NSRect dragRect = aButton.stackingFrame;
	dragRect.size.width++;

    MMTabBarOrientation orientation = tabBarView.orientation;

	if (aButton.state == NSOnState) {
		if (orientation == MMTabBarHorizontalOrientation) {
			dragRect.size.height -= 2.0;
		} else {
			dragRect.size.height += 1.0;
			dragRect.origin.y -= 1.0;
			dragRect.origin.x += 2.0;
			dragRect.size.width -= 3.0;
		}
	} else if (orientation == MMTabBarVerticalOrientation) {
		dragRect.origin.x--;
	}

	return dragRect;    
}

#pragma mark -
#pragma mark Providing Images

- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell
{
    switch (type) {
        case MMCloseButtonImageTypeStandard:
            return metalCloseButton;
        case MMCloseButtonImageTypeRollover:
            return metalCloseButtonOver;
        case MMCloseButtonImageTypePressed:
            return metalCloseButtonDown;
            
        case MMCloseButtonImageTypeDirty:
            return metalCloseDirtyButton;
        case MMCloseButtonImageTypeDirtyRollover:
            return metalCloseDirtyButtonOver;
        case MMCloseButtonImageTypeDirtyPressed:
            return metalCloseDirtyButtonDown;
            
        default:
            break;
    }
    
}

#pragma mark -
#pragma mark Cell Values

- (NSAttributedString *)attributedObjectCountStringValueForTabCell:(MMTabBarButtonCell *)cell {
	NSString *contents = [NSString stringWithFormat:@"%lu", (unsigned long)cell.objectCount];
	return [[NSMutableAttributedString alloc] initWithString:contents attributes:_objectCountStringAttributes];
}

- (NSAttributedString *)attributedStringValueForTabCell:(MMTabBarButtonCell *)cell {
	NSMutableAttributedString *attrStr;
	NSString *contents = cell.title;
	attrStr = [[NSMutableAttributedString alloc] initWithString:contents];
	NSRange range = NSMakeRange(0, contents.length);

	// Add font attribute
	[attrStr addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:11.0] range:range];
	[attrStr addAttribute:NSForegroundColorAttributeName value:[NSColor.textColor colorWithAlphaComponent:0.75] range:range];

	// Add shadow attribute
	NSShadow* shadow;
	shadow = [[NSShadow alloc] init];
	CGFloat shadowAlpha;
	if ((cell.state == NSOnState) || cell.mouseHovered) {
		shadowAlpha = 0.8;
	} else {
		shadowAlpha = 0.5;
	}
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:shadowAlpha]];
	[shadow setShadowOffset:NSMakeSize(0, -1)];
	[shadow setShadowBlurRadius:1.0];
	[attrStr addAttribute:NSShadowAttributeName value:shadow range:range];

	// Paragraph Style for Truncating Long Text
	static NSMutableParagraphStyle *TruncatingTailParagraphStyle = nil;
	if (!TruncatingTailParagraphStyle) {
		TruncatingTailParagraphStyle = [NSParagraphStyle.defaultParagraphStyle mutableCopy];
		[TruncatingTailParagraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
		[TruncatingTailParagraphStyle setAlignment:NSCenterTextAlignment];
	}
	[attrStr addAttribute:NSParagraphStyleAttributeName value:TruncatingTailParagraphStyle range:range];

	return attrStr;
}

#pragma mark -
#pragma mark Determining Cell Size

- (NSRect)drawingRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell
{
    NSRect resultRect;

    MMTabBarView *tabBarView = cell.tabBarView;

    if (tabBarView.orientation == MMTabBarHorizontalOrientation && cell.state == NSOnState) {
        resultRect = NSInsetRect(theRect,MARGIN_X,0.0);
        resultRect.origin.y += 1;
        resultRect.size.height -= MARGIN_Y + 2;
    } else {
        resultRect = NSInsetRect(theRect, MARGIN_X, MARGIN_Y);
        resultRect.size.height -= 1;
    }
    
    return resultRect;
}

#pragma mark -
#pragma mark Drawing

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

	//Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
	rect = tabBarView.bounds;
    
    MMTabBarOrientation orientation = tabBarView.orientation;

	if (orientation == MMTabBarVerticalOrientation && tabBarView.frame.size.width < 2) {
		return;
	}

	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext.currentContext setShouldAntialias:NO];

    if (tabBarView.isWindowActive)
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] set];
    else
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
	NSRectFillUsingOperation(rect, NSCompositeSourceAtop);
	[NSColor.darkGrayColor set];

	if (orientation == MMTabBarHorizontalOrientation) {
    
        if ([self _shouldDrawHorizontalTopBorderLineInView:tabBarView]) {
            [NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y + 0.5) toPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + 0.5)];
        }
        
		[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height - 0.5) toPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height - 0.5)];
	} else {
		[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y + 0.5) toPoint:NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height + 0.5)];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + 0.5) toPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height + 0.5)];
	}

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {

    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;
    MMTabBarOrientation orientation = tabBarView.orientation;
    
	NSRect cellFrame = frame;
    
    BOOL overflowMode = button.isOverflowButton;
    if (button.isSliding)
        overflowMode = NO;
    
	[NSGraphicsContext saveGraphicsState];

	if (cell.state == NSOnState) {
		// selected tab
		if (orientation == MMTabBarHorizontalOrientation) {
			NSRect aRect = NSMakeRect(cellFrame.origin.x+0.5, cellFrame.origin.y, cellFrame.size.width-1.0, cellFrame.size.height - 2.5);

            if (overflowMode) {
                aRect.size.width += 0.5;
                [self _drawBezelInRect:aRect withCapMask:MMBezierShapeLeftCap|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
            } else {
                [self _drawBezelInRect:aRect withCapMask:MMBezierShapeAllCaps|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
            }
  
		} else {
			NSRect aRect = NSMakeRect(cellFrame.origin.x + 2.5, cellFrame.origin.y+0.5, cellFrame.size.width - 2.5, cellFrame.size.height-1.0);
            
            if (overflowMode ) {
                [self _drawBezelInRect:aRect withCapMask:MMBezierShapeLeftCap usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
            } else {
                [self _drawBezelInRect:aRect withCapMask:MMBezierShapeLeftCap usingStatesOfAttachedButton:button ofTabBarView:tabBarView];            
            }
		}        
	} else {
		// unselected tab
		NSRect aRect = NSMakeRect(cellFrame.origin.x+0.5, cellFrame.origin.y+0.5, cellFrame.size.width-1.0, cellFrame.size.height-1.0);
        
        if (overflowMode) {
            aRect.size.width += 0.5;
            [self _drawBezelInRect:aRect withCapMask:MMBezierShapeLeftCap|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
        } else {
            [self _drawBezelInRect:aRect withCapMask:MMBezierShapeAllCaps|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
        }
	}

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

    MMTabBarOrientation orientation = tabBarView.orientation;
    MMAttachedTabBarButton *lastAttachedButton = tabBarView.lastAttachedButton;
    MMAttachedTabBarButtonCell *lastAttachedButtonCell = lastAttachedButton.cell;

    if (lastAttachedButton.isSliding)
        return;
    
	NSRect cellFrame = overflowButton.frame;

	NSColor *lineColor = NSColor.darkGrayColor;
    
    if (orientation == MMTabBarHorizontalOrientation) {
            // Draw selected
        if (lastAttachedButtonCell.state == NSOnState) {
            NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width-0.5, cellFrame.size.height-2.5);
            aRect.size.width += 5.0;

            [self _drawBezelInRect:aRect withCapMask:MMBezierShapeRightCap|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:lastAttachedButton ofTabBarView:tabBarView];        
        } else {

            NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y+0.5, cellFrame.size.width-0.5, cellFrame.size.height-1.0);
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

#pragma mark -
#pragma mark Private Methods

- (BOOL)_shouldDrawHorizontalTopBorderLineInView:(id)controlView
{
    NSWindow *window = [(NSView*) controlView window];
    NSToolbar *toolbar = window.toolbar;
    if (!toolbar || !toolbar.isVisible || (toolbar.isVisible && toolbar.showsBaselineSeparator))
        return NO;
    
    return YES;
}

- (void)_drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView {

    MMTabBarOrientation orientation = tabBarView.orientation;
    
	NSColor *lineColor = NSColor.darkGrayColor;
    
    capMask &= ~MMBezierShapeFillPath;

	[NSGraphicsContext saveGraphicsState];
    
    if (orientation == MMTabBarHorizontalOrientation) {

            // selected button
        if (button.state == NSOnState) {
        
                // fill
            NSBezierPath *bezier = [NSBezierPath bezierPathWithCardInRect:aRect radius:3.0 capMask:capMask|MMBezierShapeFillPath];
        
            [NSColor.windowBackgroundColor set];

            [bezier fill];

                // stroke
            [lineColor set];
        
            bezier = [NSBezierPath bezierPathWithCardInRect:aRect radius:3.0 capMask:capMask];
        
            [bezier setLineWidth:1.0];
            [bezier stroke];

            // unselected button
        } else {
                // rollover
            if (button.mouseHovered) {
                [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
                NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
            }
            
            // frame
            NSBezierPath *bezier = NSBezierPath.bezierPath;
            if ([self _shouldDrawHorizontalTopBorderLineInView:button]) {
                [bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y)];
                [bezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y)];
            }
            
            BOOL shouldDisplayRightDivider = button.shouldDisplayRightDivider;
            if (button.tabState & MMTab_RightIsSelectedMask) {
                if ((button.tabState & (MMTab_PlaceholderOnRight | MMTab_RightIsSliding)) == 0)
                    shouldDisplayRightDivider = NO;
            }
            
            if (shouldDisplayRightDivider) {
                [bezier moveToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect))];
                [bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect))];
            }
            if (button.shouldDisplayLeftDivider) {
                [bezier moveToPoint:NSMakePoint(NSMinX(aRect), NSMinY(aRect))];
                [bezier lineToPoint:NSMakePoint(NSMinX(aRect), NSMaxY(aRect))];
            }
            
            [lineColor set];
            [bezier stroke];
        }
    } else {
            // selected button
        if (button.state == NSOnState) {

                // fill
            NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:aRect radius:5.0 capMask:capMask|MMBezierShapeFillPath];
            [NSColor.windowBackgroundColor set];
            [fillPath fill];

                // stroke
            NSBezierPath *strokePath = [NSBezierPath bezierPathWithRoundedRect:aRect radius:5.0 capMask:capMask];
            [strokePath setLineWidth:1.0];
        
			[lineColor set];
            [strokePath stroke];
                        
            // unselected button
        } else {

                // rollover
            if (button.mouseHovered) {
                [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
                NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
            }
            
                // stroke
            BOOL shouldDisplayRightDivider = button.shouldDisplayRightDivider;
            if (button.tabState & MMTab_RightIsSelectedMask) {
                if ((button.tabState & (MMTab_PlaceholderOnRight | MMTab_RightIsSliding)) == 0)
                    shouldDisplayRightDivider = NO;
            }
			
            NSBezierPath *bezier = NSBezierPath.bezierPath;
            
			if (button.shouldDisplayLeftDivider || (button.tabState & MMTab_PositionLeftMask)) {
				[bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y)];
				[bezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y)];
			}

			if (shouldDisplayRightDivider) {
				[bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y + aRect.size.height)];
				[bezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y + aRect.size.height)];
			}
            
            [lineColor set];
            [bezier stroke];
        }
    }
    
	[NSGraphicsContext restoreGraphicsState];    
}

@end

NS_ASSUME_NONNULL_END
