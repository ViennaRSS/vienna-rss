//
//  MMUnifiedTabStyle.m
//  --------------------
//
//  Created by Keith Blount on 30/04/2006.
//  Copyright 2006 Keith Blount. All rights reserved.
//

#import "MMUnifiedTabStyle.h"
#import "MMAttachedTabBarButton.h"
#import "MMTabBarView.h"
#import "NSView+MMTabBarViewExtensions.h"
#import "NSBezierPath+MMTabBarViewExtensions.h"
#import "MMTabBarButtonCell.h"
#import "MMOverflowPopUpButton.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMUnifiedTabStyle ()
@end

@implementation MMUnifiedTabStyle
{
	NSImage				*unifiedCloseButton;
	NSImage				*unifiedCloseButtonDown;
	NSImage				*unifiedCloseButtonOver;
	NSImage				*unifiedCloseDirtyButton;
	NSImage				*unifiedCloseDirtyButtonDown;
	NSImage				*unifiedCloseDirtyButtonOver;
}

+ (NSString *)name {
    return @"Unified";
}

- (NSString *)name {
	return self.class.name;
}

#pragma mark -
#pragma mark Creation/Destruction

- (instancetype) init {
	if ((self = [super init])) {
		unifiedCloseButton = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front"];
		unifiedCloseButtonDown = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front_Pressed"];
		unifiedCloseButtonOver = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front_Rollover"];

		unifiedCloseDirtyButton = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front"];
		unifiedCloseDirtyButtonDown = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front_Pressed"];
		unifiedCloseDirtyButtonOver = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front_Rollover"];

		_leftMarginForTabBarView = 0.0;
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
            return unifiedCloseButton;
        case MMCloseButtonImageTypeRollover:
            return unifiedCloseButtonOver;
        case MMCloseButtonImageTypePressed:
            return unifiedCloseButtonDown;
            
        case MMCloseButtonImageTypeDirty:
            return unifiedCloseDirtyButton;
        case MMCloseButtonImageTypeDirtyRollover:
            return unifiedCloseDirtyButtonOver;
        case MMCloseButtonImageTypeDirtyPressed:
            return unifiedCloseDirtyButtonDown;
            
        default:
            break;
    }
    
}

#pragma mark -
#pragma mark Drawing

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {
	//Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
	rect = tabBarView.bounds;

	NSRect gradientRect = rect;
    
    NSWindow *window = tabBarView.window;
    NSToolbar *toolbar = window.toolbar;
    if (toolbar && toolbar.isVisible)
        gradientRect.size.height -= 1.0;

	if (!tabBarView.isWindowActive) {
		[NSColor.windowBackgroundColor set];
		NSRectFill(gradientRect);
	} else {
        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.835 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.843 alpha:1.0]];
        [gradient drawInRect:gradientRect angle:90.0];
    }

	[[NSColor colorWithCalibratedWhite:0.576 alpha:1.0] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, NSMinY(rect) + 0.5)
	 toPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect) + 0.5)];
}

- (void)drawBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray<MMAttachedTabBarButton *> *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

    NSWindow *window = tabBarView.window;
    NSToolbar *toolbar = window.toolbar;
    if (toolbar && toolbar.isVisible)
        return;

    NSRect aRect = button.frame;
	NSColor *lineColor = [NSColor colorWithCalibratedWhite:0.576 alpha:1.0];
    
        // draw dividers
    BOOL shouldDisplayRightDivider = button.shouldDisplayRightDivider;
    if (button.tabState & MMTab_RightIsSelectedMask) {
        if ((button.tabState & (MMTab_PlaceholderOnRight | MMTab_RightIsSliding)) == 0)
            shouldDisplayRightDivider = NO;
    }
    
    if (shouldDisplayRightDivider) {
        [lineColor set];
        [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(aRect)+.5, NSMinY(aRect)) toPoint:NSMakePoint(NSMaxX(aRect)+0.5, NSMaxY(aRect))];

        [[NSColor.whiteColor colorWithAlphaComponent:0.5] set];
        [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(aRect)+1.5, NSMinY(aRect)+1.0)
            toPoint:NSMakePoint(NSMaxX(aRect)+1.5, NSMaxY(aRect)-1.0)];
         
    }

    if (button.shouldDisplayLeftDivider) {
        [lineColor set];    
        [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(aRect)+0.5, NSMinY(aRect)) toPoint:NSMakePoint(NSMinX(aRect)+0.5, NSMaxY(aRect))];

        [[NSColor.whiteColor colorWithAlphaComponent:0.5] set];
        [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(aRect)+1.5, NSMinY(aRect)+1.0) toPoint:NSMakePoint(NSMinX(aRect)+1.5, NSMaxY(aRect)-1.0)];
    }    
}

-(void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView
{
    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;
    NSWindow *window = controlView.window;
    NSToolbar *toolbar = window.toolbar;
    
    BOOL overflowMode = button.isOverflowButton;
    if (button.isSliding)
        overflowMode = NO;
        
    if (toolbar && toolbar.isVisible) {

        NSRect aRect = NSZeroRect;
        if (overflowMode) {
            aRect = NSMakeRect(frame.origin.x+0.5, frame.origin.y - 0.5, frame.size.width - 0.5, frame.size.height-1.0);
        } else {
            aRect = NSMakeRect(frame.origin.x+0.5, frame.origin.y - 0.5, frame.size.width-1.0, frame.size.height-1.0);
        }
        
        if (cell.mouseHovered && cell.state == NSOffState)
            {
            aRect.origin.y += 1.5;
            aRect.size.height -= 1.5;
            }
        
        if (overflowMode) {
            [self _drawCardBezelInRect:aRect withCapMask:MMBezierShapeLeftCap|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
        } else {
            [self _drawCardBezelInRect:aRect withCapMask:MMBezierShapeAllCaps|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
        }
     
    } else {
    
        NSRect aRect = NSZeroRect;
        if (overflowMode) {
            aRect = NSMakeRect(frame.origin.x+0.5, frame.origin.y+0.5, frame.size.width-0.5, frame.size.height-1.0);
        } else {
            aRect = NSMakeRect(frame.origin.x+0.5, frame.origin.y+0.5, frame.size.width-1.0, frame.size.height-1.0);
        }

        if (overflowMode) {
            [self _drawBoxBezelInRect:aRect withCapMask:MMBezierShapeLeftCap usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
        } else {
            [self _drawBoxBezelInRect:aRect withCapMask:MMBezierShapeAllCaps usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
        }
    }
}

-(void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

    MMAttachedTabBarButton *lastAttachedButton = tabBarView.lastAttachedButton;
    if (lastAttachedButton.isSliding)
        return;
    
    NSWindow *window = tabBarView.window;
    NSToolbar *toolbar = window.toolbar;
            
    NSRect frame = overflowButton.frame;
    
    if (toolbar && toolbar.isVisible) {

        NSRect aRect = NSMakeRect(frame.origin.x, frame.origin.y - 0.5, frame.size.width-0.5, frame.size.height-1.0);
        aRect.size.width += 5.0;
        
        if (lastAttachedButton.mouseHovered && lastAttachedButton.state == NSOffState)
            {
            aRect.origin.y += 1.5;
            aRect.size.height -= 1.5;
            }
        
        [self _drawCardBezelInRect:aRect withCapMask:MMBezierShapeRightCap|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:lastAttachedButton ofTabBarView:tabBarView];
        
    } else {
        NSRect aRect = NSMakeRect(frame.origin.x, frame.origin.y+0.5, frame.size.width-0.5, frame.size.height-1.0);
        aRect.size.width += 5.0;
        
        [self _drawBoxBezelInRect:aRect withCapMask:MMBezierShapeRightCap|MMBezierShapeFlippedVertically usingStatesOfAttachedButton:lastAttachedButton ofTabBarView:tabBarView];

        if (tabBarView.showAddTabButton) {

            NSColor *lineColor = [NSColor colorWithCalibratedWhite:0.576 alpha:1.0];
            [lineColor set];
            [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(aRect)+.5, NSMinY(aRect)) toPoint:NSMakePoint(NSMaxX(aRect)+0.5, NSMaxY(aRect))];

            [[NSColor.whiteColor colorWithAlphaComponent:0.5] set];
            [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(aRect)+1.5, NSMinY(aRect)+1.0) toPoint:NSMakePoint(NSMaxX(aRect)+1.5, NSMaxY(aRect)-1.0)];
        }        
    }
}

#pragma mark -
#pragma mark Private Methods

- (void)_drawCardBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView {

    NSColor *lineColor = [NSColor colorWithCalibratedWhite:0.576 alpha:1.0];
    CGFloat radius = MIN(6.0, 0.5 * MIN(NSWidth(aRect), NSHeight(aRect)));

    capMask &= ~MMBezierShapeFillPath;
        
    NSBezierPath *fillPath = [NSBezierPath bezierPathWithCardInRect:aRect radius:radius capMask:capMask|MMBezierShapeFillPath];

    if (tabBarView.isWindowActive) {
        if (button.state == NSOnState) {
            NSColor *startColor = [NSColor colorWithDeviceWhite:0.698 alpha:1.000];
            NSColor *endColor = [NSColor colorWithDeviceWhite:0.663 alpha:1.000];
            NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor];
            [gradient drawInBezierPath:fillPath angle:80.0];
        } else if (button.mouseHovered) {
            NSColor *startColor = [NSColor colorWithDeviceWhite:0.8 alpha:1.000];
            NSColor *endColor = [NSColor colorWithDeviceWhite:0.8 alpha:1.000];
            NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor];
            [gradient drawInBezierPath:fillPath angle:80.0];
        }
        
    } else {
        if (button.state == NSOnState) {
            NSColor *startColor = [NSColor colorWithDeviceWhite:0.875 alpha:1.000];
            NSColor *endColor = [NSColor colorWithDeviceWhite:0.902 alpha:1.000];
            NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor];
            [NSGraphicsContext.currentContext setShouldAntialias:NO];
            [gradient drawInBezierPath:fillPath angle:90.0];
            [NSGraphicsContext.currentContext setShouldAntialias:YES];
        }
    }        

    NSBezierPath *strokePath = [NSBezierPath bezierPathWithCardInRect:aRect radius:radius capMask:capMask];

    [lineColor set];
    [strokePath stroke];
}

- (void)_drawBoxBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView {

    capMask &= ~MMBezierShapeFillPath;
    
        // fill
    if (button.state == NSOnState) {
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] set];
        NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);            
    } else if (button.mouseHovered) {
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
        NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
    }
}

@end

NS_ASSUME_NONNULL_END
