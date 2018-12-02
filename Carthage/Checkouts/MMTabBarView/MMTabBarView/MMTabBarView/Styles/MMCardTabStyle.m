//
//  MMCardTabStyle.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/3/12.
//
//

#import "MMCardTabStyle.h"

#import "MMAttachedTabBarButton.h"
#import "NSView+MMTabBarViewExtensions.h"
#import "NSBezierPath+MMTabBarViewExtensions.h"
#import "MMTabBarView.Private.h"
#import "MMOverflowPopUpButton.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMCardTabStyle ()
@end

@implementation MMCardTabStyle
{
    NSImage *cardCloseButton;
    NSImage *cardCloseButtonDown;
    NSImage *cardCloseButtonOver;
    NSImage *cardCloseDirtyButton;
    NSImage *cardCloseDirtyButtonDown;
    NSImage *cardCloseDirtyButtonOver;	    
}

+ (NSString *)name {
    return @"Card";
}

- (NSString *)name {
	return self.class.name;
}

#pragma mark -
#pragma mark Creation/Destruction

- (instancetype) init {
    if ( (self = [super init]) ) {
        cardCloseButton = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front"];
        cardCloseButtonDown = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front_Pressed"];
        cardCloseButtonOver = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front_Rollover"];
        
        cardCloseDirtyButton = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front"];
        cardCloseDirtyButtonDown = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front_Pressed"];
        cardCloseDirtyButtonOver = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front_Rollover"];
                        
		_horizontalInset = 3.0;
	}
    return self;
}

#pragma mark -
#pragma mark Tab View Specific

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return _horizontalInset;
    else
        return 0.0;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return _horizontalInset;
    else
        return 0.0;
}

- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView {
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return 2.0;

    return 0.0;
}

- (CGFloat)heightOfTabBarButtonsForTabBarView:(MMTabBarView *)tabBarView {

    return kMMTabBarViewHeight - [self topMarginForTabBarView:tabBarView];
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
            return cardCloseButton;
        case MMCloseButtonImageTypeRollover:
            return cardCloseButtonOver;
        case MMCloseButtonImageTypePressed:
            return cardCloseButtonDown;
            
        case MMCloseButtonImageTypeDirty:
            return cardCloseDirtyButton;
        case MMCloseButtonImageTypeDirtyRollover:
            return cardCloseDirtyButtonOver;
        case MMCloseButtonImageTypeDirtyPressed:
            return cardCloseDirtyButtonDown;
            
        default:
            break;
    }
}

#pragma mark -
#pragma mark Determining Cell Size

- (NSRect)overflowButtonRectForTabBarView:(MMTabBarView *)tabBarView {

    NSRect rect = tabBarView._overflowButtonRect;
    
    rect.origin.y += tabBarView.topMargin;
    rect.size.height -= tabBarView.topMargin;
    
    return rect;
}

#pragma mark -
#pragma mark Drawing

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {
	//Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
	NSRect bounds = tabBarView.bounds;
    
    bounds.size.height -= 1.0;    

    NSGradient *gradient = nil;
    
    if (tabBarView.isWindowActive) {
        // gray bar gradient
        gradient = [[NSGradient alloc] initWithColorsAndLocations:
                        [NSColor colorWithCalibratedWhite:0.678 alpha:1.000],0.0,
                        [NSColor colorWithCalibratedWhite:0.821 alpha:1.000],1.0,
                        nil];
    } else {
        // light gray bar gradient
        gradient = [[NSGradient alloc] initWithColorsAndLocations:
                [NSColor colorWithCalibratedWhite:0.821 alpha:1.000],0.0,
                [NSColor colorWithCalibratedWhite:0.956 alpha:1.000],1.0,
                nil];
    }
    
    if (gradient) {
        [gradient drawInRect:bounds angle:270];
    
        }

    bounds = tabBarView.bounds;
        
        // draw additional separator line
    [[NSColor colorWithCalibratedWhite:0.576 alpha:1.0] set];
        
    [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(bounds),NSMaxY(bounds)-0.5)
                  toPoint:NSMakePoint(NSMaxX(bounds),NSMaxY(bounds)-0.5)];        
}

- (void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {

    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;

    BOOL overflowMode = button.isOverflowButton;
    if (button.isSliding)
        overflowMode = NO;

    NSRect aRect = NSMakeRect(frame.origin.x+.5, frame.origin.y+0.5, frame.size.width-1.0, frame.size.height-1.0);
    if (overflowMode)
        aRect.size.width += 0.5;
    
    aRect.size.height += 1.0;
 
    if (overflowMode) {
        [self _drawBezelInRect:aRect withCapMask:MMBezierShapeLeftCap usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
    } else {
        [self _drawBezelInRect:aRect withCapMask:MMBezierShapeAllCaps usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
    }
}

-(void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

    MMAttachedTabBarButton *lastAttachedButton = tabBarView.lastAttachedButton;

    if (lastAttachedButton.isSliding)
        return;

    NSRect frame = overflowButton.frame;
    frame.size.width += 5.0;

    NSRect aRect = NSMakeRect(frame.origin.x, frame.origin.y+0.5, frame.size.width-0.5, frame.size.height);

    [self _drawBezelInRect:aRect withCapMask:MMBezierShapeRightCap usingStatesOfAttachedButton:lastAttachedButton ofTabBarView:tabBarView];
}

#pragma mark -
#pragma mark Card Tab Style Drawings

- (void)drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView {

    [self _drawBezelInRect:aRect withCapMask:capMask usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
}

#pragma mark -
#pragma mark Private Methods

- (void)_drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView {

    capMask &= ~MMBezierShapeFillPath;
    
    NSColor *lineColor = [NSColor colorWithCalibratedWhite:0.576 alpha:1.0];

    CGFloat radius = MIN(6.0, 0.5 * MIN(NSWidth(aRect), NSHeight(aRect)))-0.5;

        // fill
    NSBezierPath *fillPath = [NSBezierPath bezierPathWithCardInRect:aRect radius:radius capMask:capMask|MMBezierShapeFillPath];

    NSGradient *gradient = nil;

    if (tabBarView.isWindowActive) {
        if (button.state == NSOnState) {
              gradient = [[NSGradient alloc] initWithStartingColor:NSColor.whiteColor endingColor:[NSColor colorWithDeviceWhite:0.929 alpha:1.000]];
        } else if (button.mouseHovered) {
        
            gradient = [[NSGradient alloc] 
                initWithStartingColor: [NSColor colorWithCalibratedWhite:0.80 alpha:1.0]
                endingColor:[NSColor colorWithCalibratedWhite:0.80 alpha:1.0]];           
        } else {

            gradient = [[NSGradient alloc] 
                initWithStartingColor:[NSColor colorWithCalibratedWhite:0.835 alpha:1.0] 
                endingColor:[NSColor colorWithCalibratedWhite:0.843 alpha:1.0]];                                
        }

        if (gradient != nil) {
            [gradient drawInBezierPath:fillPath angle:90.0];
            gradient = nil;
            }
    } else {
        [NSColor.windowBackgroundColor set];
        NSRectFill(aRect);
    }
    
        // stroke
    NSBezierPath *outlinePath = [NSBezierPath bezierPathWithCardInRect:aRect radius:radius capMask:capMask];
    
    [lineColor set];
    [outlinePath stroke];

    if (button.state == NSOffState) {
    
            // draw additional separator line
        [[NSColor colorWithCalibratedWhite:0.576 alpha:1.0] set];
        
        [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(aRect),NSMaxY(aRect)-0.5)
                  toPoint:NSMakePoint(NSMaxX(aRect),NSMaxY(aRect)-0.5)];
    }    
}

@end

NS_ASSUME_NONNULL_END
