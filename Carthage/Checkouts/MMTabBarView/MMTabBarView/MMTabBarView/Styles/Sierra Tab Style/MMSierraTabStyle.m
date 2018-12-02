//
//  MMSierraTabStyle.m
//  --------------------
//
//  Based on MMYosemiteTabStyle.m by Ajin Man Tuladhar
//  Created by Ajin Isaiah Carew on 04/16/2017
//  Copyright 2017 Isaiah Carew. All rights reserved.
//

#import "MMSierraTabStyle.h"
#import "MMAttachedTabBarButton.h"
#import "MMTabBarView.h"
#import "NSView+MMTabBarViewExtensions.h"
#import "NSBezierPath+MMTabBarViewExtensions.h"
#import "MMOverflowPopUpButton.h"
#import "MMOverflowPopUpButtonCell.h"
#import "MMTabBarView.Private.h"
#import "MMSierraRolloverButton.h"
#import "MMSierraCloseButton.h"

@interface MMSierraTabStyle()
// fill gradients
@property (class, nonatomic) NSGradient * selectedFillGradient;
@property (class, nonatomic) NSGradient * idleFillGradient;
@property (class, nonatomic) NSGradient * hoverFillGradient;
@property (class, nonatomic) NSGradient * mouseDownFillGradient;
// top border gradients
@property (class, nonatomic) NSGradient * selectedTopBorderGradient;
@property (class, nonatomic) NSGradient * unselectedTopBorderGradient;
// left/right-border gradients
@property (class, nonatomic) NSGradient * edgeBorderGradient;
// bottom gradients
@property (class, nonatomic) NSGradient * bottomBorderGradient;
// inactive windows
@property (class, nonatomic) NSColor * inactiveSelectedFillColor;
@property (class, nonatomic) NSColor * inactiveIdleFillColor;
@property (class, nonatomic) NSColor * inactiveHoverFillColor;
@property (class, nonatomic) NSColor * inactiveBorderColor;
@property (class, nonatomic) NSColor * inactiveBottomBorderColor;

@end

@implementation MMSierraTabStyle

static NSGradient * _selectedFillGradient;
static NSGradient * _idleFillGradient;
static NSGradient * _hoverFillGradient;
static NSGradient * _mouseDownFillGradient;
static NSGradient * _selectedTopBorderGradient;
static NSGradient * _unselectedTopBorderGradient;
static NSGradient * _edgeBorderGradient;
static NSGradient * _bottomBorderGradient;
static NSColor * _inactiveSelectedFillColor;
static NSColor * _inactiveIdleFillColor;
static NSColor * _inactiveHoverFillColor;
static NSColor * _inactiveBorderColor;
static NSColor * _inactiveBottomBorderColor;

NS_ASSUME_NONNULL_BEGIN

+ (NSString *)name {
    return @"Sierra";
}

- (NSString *)name {
	return [[self class] name];
}

#pragma mark -
#pragma mark Creation/Destruction

- (id) init {
	if ((self = [super init])) {
		_leftMarginForTabBarView = 0.;
        _needsResizeTabsToFitTotalWidth = YES;
	}
    
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(resetColors) name:@"AppleInterfaceThemeChangedNotification" object:nil];
	return self;
}

- (void) dealloc
{
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
}

-(void)resetColors
{
    _selectedFillGradient = nil;
    _idleFillGradient = nil;
    _hoverFillGradient = nil;
    _mouseDownFillGradient = nil;
    _selectedTopBorderGradient = nil;
    _unselectedTopBorderGradient = nil;
    _edgeBorderGradient = nil;
    _bottomBorderGradient = nil;
    _inactiveSelectedFillColor = nil;
    _inactiveIdleFillColor = nil;
    _inactiveHoverFillColor = nil;
    _inactiveBorderColor = nil;
    _inactiveBottomBorderColor = nil;
} // resetColors

#pragma mark -
#pragma mark Tab View Specific

- (NSSize)intrinsicContentSizeOfTabBarView:(MMTabBarView *)tabBarView
{
    return NSMakeSize(noIntrinsicMetric(), 24);
}

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView {
    return 0.0;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView {
    return 0.0;
}

- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView {
    return 0.0;
}

- (CGFloat)heightOfTabBarButtonsForTabBarView:(MMTabBarView *)tabBarView {
    return 24.0;
}

- (NSSize)overflowButtonSizeForTabBarView:(MMTabBarView *)tabBarView {
    return NSMakeSize(22.0, [self heightOfTabBarButtonsForTabBarView:tabBarView]);
}

//- (NSSize)overflowButtonSizeForTabBarView:(MMTabBarView *)tabBarView {
//    return NSMakeSize(22, [self heightOfTabBarButtonsForTabBarView:tabBarView]);
//}



- (NSRect)addTabButtonRectForTabBarView:(MMTabBarView *)tabBarView {
    NSSize tabBarSize = tabBarView.bounds.size;
    NSSize buttonSize = [self addTabButtonSizeForTabBarView:tabBarView];
    CGFloat x = tabBarSize.width - buttonSize.width;
    return NSMakeRect( x, 0, buttonSize.width, buttonSize.height);
    //return NSMakeRect( tabBarSize.width - buttonSize.width , 0, buttonSize.width, buttonSize.height);
}

- (NSSize)addTabButtonSizeForTabBarView:(MMTabBarView *)tabBarView {
    return NSMakeSize(24, [self heightOfTabBarButtonsForTabBarView:tabBarView]);
}

- (CGFloat)addTabButtonPaddingForTabBarView:(MMTabBarView *)tabBarView {
    return 0;
}

- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation forTabBarView:(MMTabBarView *)tabBarView {
    return orientation == MMTabBarHorizontalOrientation;
}

#pragma mark -
#pragma mark Drag Support

- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {
	NSRect dragRect = aButton.stackingFrame;
	dragRect.size.width++;
	return dragRect;
}

#pragma mark -
#pragma mark Add Tab Button

- (MMRolloverButton *)rolloverButtonWithFrame:(NSRect)frame ofTabBarView:(MMTabBarView *)tabBarView {
    // return our rollover subclass that draws Sierra gradients
    return [[MMSierraRolloverButton alloc] initWithFrame:frame];
}

- (void)updateAddButton:(MMRolloverButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {
    if (@available(macos 10.14, *)) {
        aButton.bezelStyle = NSBezelStyleRegularSquare;
    } else {
        aButton.bordered = YES;
    }
}

#pragma mark -
#pragma mark Close Button Drawing

- (NSSize)closeButtonSizeForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {
    CGFloat width = 16.0;
    CGFloat height = 16.0;
    return NSMakeSize(width, height);
}

- (NSRect)closeButtonRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {

	if (![cell shouldDisplayCloseButton]) {
		return NSZeroRect;
	}

    CGFloat marginX = 4.0;
    CGFloat marginY = 4.0;
    NSSize size = [self closeButtonSizeForBounds:theRect ofTabCell:cell];

    CGFloat x = theRect.origin.x + marginX;
    CGFloat y = theRect.origin.y + marginY;
    CGFloat width = size.width;
    CGFloat height = size.height;
    return NSMakeRect(x, y, width, height);
}

- (MMRolloverButton *)closeButtonForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {

    NSRect frame = [self closeButtonRectForBounds:theRect ofTabCell:cell];
    MMRolloverButton *closeButton = [[MMSierraCloseButton alloc] initWithFrame:frame];

    closeButton.title=@"";
    closeButton.imagePosition = NSImageOnly;
    closeButton.rolloverButtonType = MMRolloverActionButton;
    closeButton.bezelStyle = NSShadowlessSquareBezelStyle;

    return closeButton;

}


#pragma mark -
#pragma mark Drawing

- (CGFloat)overflowButtonPaddingForTabBarView:(MMTabBarView *)tabBarView {
    return 0;
}

- (void)drawTitleOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {
    NSRect rect = [self _titleRectForBounds:frame ofTabCell:cell];
    NSMutableAttributedString *attrString = [[cell attributedStringValue] mutableCopy];
	// Add font attribute
	NSRange range = NSMakeRange(0, [attrString length]);
	[attrString addAttribute:NSForegroundColorAttributeName value:[[NSColor textColor] colorWithAlphaComponent:0.75] range:range];
    [attrString drawInRect:rect];
}

-(NSRect)_titleRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {
	NSRect titleRect = [cell titleRectForBounds:theRect];
	NSRect closeButtonRect = [cell closeButtonRectForBounds:theRect];
	if (!NSEqualRects(closeButtonRect, NSZeroRect)) {
		titleRect.size.width -= NSWidth(closeButtonRect);
	}
	titleRect.origin.x -= MARGIN_X;
	titleRect.size.width += 2*MARGIN_X;
	return titleRect;
}

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {
    NSRect topRect = [self topBorderRectWithFrame:rect];
    NSRect bottomRect = [self bottomBorderRectWithFrame:rect];

    if ([tabBarView isWindowActive]) {
        [[MMSierraTabStyle idleFillGradient] drawInRect:rect angle:90];
        [[MMSierraTabStyle unselectedTopBorderGradient] drawInRect:topRect angle:90];
        [[MMSierraTabStyle bottomBorderGradient] drawInRect:bottomRect angle:90];
    } else {
        [[MMSierraTabStyle inactiveIdleFillColor] set];
        NSFrameRect(rect);
        [[MMSierraTabStyle inactiveBorderColor] set];
        NSFrameRect(topRect);
        [[MMSierraTabStyle inactiveBottomBorderColor] set];
        NSFrameRect(bottomRect);
    }
}


-(void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {
    // when a tab is sliding it needs to draw on top of all other tabs
    // its style is the selected style, but with left and right edges
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;
    if (button.isInDraggedSlide) {

        [[MMSierraTabStyle selectedFillGradient] drawInRect:frame angle:90];

        [[MMSierraTabStyle selectedTopBorderGradient] drawInRect:[self topBorderRectWithFrame:frame] angle:90];
        [[MMSierraTabStyle bottomBorderGradient] drawInRect:[self bottomBorderRectWithFrame:frame] angle:90];

        [[MMSierraTabStyle edgeBorderGradient] drawInRect:[self leftRectWithFrame:frame] angle:90];
        [[MMSierraTabStyle edgeBorderGradient] drawInRect:[self rightRectWithFrame:frame] angle:90];
    }
}

- (void)updateOverflowPopUpButton:(MMOverflowPopUpButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {
    static NSImage *overflowImage = nil;
    if (!overflowImage) {
        overflowImage = [[MMTabBarView bundle] imageForResource:@"MMSierraOverflow"];
        overflowImage.template = YES;
    }

    aButton.image = overflowImage;
    aButton.alternateImage = overflowImage;
    aButton.autoresizingMask = (NSViewNotSizable);
    aButton.preferredEdge = 0;

    MMOverflowPopUpButtonCell *cell = aButton.cell;
    cell.centerImage = YES;

}

-(void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)button ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)barRect {

    MMAttachedTabBarButton *lastAttachedButton = [tabBarView lastAttachedButton];
    if ([lastAttachedButton isSliding])
        return;

    // fill
    NSRect rect = [self fillRectWithFrame:button.frame];
    if ([tabBarView isWindowActive]) {
        NSGradient *gradient = nil;
        if (lastAttachedButton.state == NSOnState) {
            gradient = [MMSierraTabStyle selectedFillGradient];
        } else if (lastAttachedButton.mouseHovered) {
            gradient = [MMSierraTabStyle hoverFillGradient];
        } else {
            gradient = [MMSierraTabStyle idleFillGradient];
        }
        [gradient drawInRect:rect angle:90];
    } else {
        NSColor *color = nil;
        if (lastAttachedButton.state == NSOnState) {
            color = [MMSierraTabStyle inactiveSelectedFillColor];
        } else if (lastAttachedButton.mouseHovered) {
            color = [MMSierraTabStyle inactiveHoverFillColor];
        } else {
            color = [MMSierraTabStyle inactiveIdleFillColor];
        }
        [color set];
        NSRectFill(rect);
    }

    // top
    rect = [self topBorderRectWithFrame:button.frame];
    if ([tabBarView isWindowActive]) {
        NSGradient *gradient = nil;
        if (lastAttachedButton.state == NSOnState) {
            gradient = [MMSierraTabStyle selectedTopBorderGradient];
        } else {
            gradient = [MMSierraTabStyle unselectedTopBorderGradient];
        }
        [gradient drawInRect:rect angle:90];
    } else {
        [[MMSierraTabStyle inactiveBorderColor] set];
        NSFrameRect(rect);
    }

    // bottom
    rect = [self bottomBorderRectWithFrame:button.frame];
    if ([tabBarView isWindowActive]) {
        [[MMSierraTabStyle bottomBorderGradient] drawInRect:rect angle:90];
    } else {
        [[MMSierraTabStyle inactiveBottomBorderColor] set];
        NSFrameRect(rect);
    }

}

- (void)drawLeftBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView {
    // leftmost tab is flush against the view
    if (index < 1) return;

    // the selected tab has no edges
    if (index == selIndex) return;

    // tabs right of the selected tab have no left edge
    // except for the tab immediately to the right of the selection
    if (index - 1 > selIndex) return;

    NSRect rect = [self leftRectWithFrame:button.frame];
    if ([tabBarView isWindowActive]) {
        [[MMSierraTabStyle edgeBorderGradient] drawInRect:rect angle:90];
    } else {
        [[MMSierraTabStyle inactiveBorderColor] set];
        NSFrameRect(rect);
    }
}

- (void)drawRightBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView {
    // rightmost tab is flush against the add-tab button
    if (index == buttons.count - 1) return;

    // the selected tab has no edges
    if (index == selIndex) return;

    // tabs left of the selected tab have no right edge
    // except for the tab immediately to the left of the selection
    if (index + 1 < selIndex) return;

    NSRect rect = [self rightRectWithFrame:button.frame];
    if ([tabBarView isWindowActive]) {
        [[MMSierraTabStyle edgeBorderGradient] drawInRect:rect angle:90];
    } else {
        [[MMSierraTabStyle inactiveBorderColor] set];
        NSFrameRect(rect);
    }
}

- (void)drawTopBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView {
    NSRect rect = [self topBorderRectWithFrame:button.frame];
    if ([tabBarView isWindowActive]) {
        NSGradient *gradient = nil;
        if (index == selIndex) {
            gradient = [MMSierraTabStyle selectedTopBorderGradient];
        } else {
            gradient = [MMSierraTabStyle unselectedTopBorderGradient];
        }
        [gradient drawInRect:rect angle:90];
    } else {
        [[MMSierraTabStyle inactiveBorderColor] set];
        NSFrameRect(rect);
    }
}

- (void)drawBottomBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView {
    NSRect rect = [self bottomBorderRectWithFrame:button.frame];
    if ([tabBarView isWindowActive]) {
        [[MMSierraTabStyle bottomBorderGradient] drawInRect:rect angle:90];
    } else {
        [[MMSierraTabStyle inactiveBottomBorderColor] set];
        NSFrameRect(rect);
    }
}

- (void)drawFillOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView {
    NSRect rect = [self fillRectWithFrame:button.frame];
    if ([tabBarView isWindowActive]) {
        NSGradient *gradient = nil;
        if (index == selIndex) {
            gradient = [MMSierraTabStyle selectedFillGradient];
        } else if (button.mouseHovered) {
            gradient = [MMSierraTabStyle hoverFillGradient];
        } else {
            gradient = [MMSierraTabStyle idleFillGradient];
        }
        [gradient drawInRect:rect angle:90];
    } else {
        NSColor *color = nil;
        if (index == selIndex) {
            color = [MMSierraTabStyle inactiveSelectedFillColor];
        } else if (button.mouseHovered) {
            color = [MMSierraTabStyle inactiveHoverFillColor];
        } else {
            color = [MMSierraTabStyle inactiveIdleFillColor];
        }
        [color set];
        NSRectFill(rect);
    }
}

- (void)drawBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {
    [self drawFillOfButton:button atIndex:index inButtons:buttons indexOfSelectedButton:selIndex tabBarView:tabBarView];
    [self drawLeftBezelOfButton:button atIndex:index inButtons:buttons indexOfSelectedButton:selIndex tabBarView:tabBarView];
    [self drawRightBezelOfButton:button atIndex:index inButtons:buttons indexOfSelectedButton:selIndex tabBarView:tabBarView];
    [self drawTopBezelOfButton:button atIndex:index inButtons:buttons indexOfSelectedButton:selIndex tabBarView:tabBarView];
    [self drawBottomBezelOfButton:button atIndex:index inButtons:buttons indexOfSelectedButton:selIndex tabBarView:tabBarView];
}


#pragma mark - component frames

- (NSRect)bottomBorderRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x, frame.origin.y + frame.size.height - 1.0, frame.size.width, 1.0);
}

- (NSRect)topBorderRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, 1.0);
}

- (NSRect)leftRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x, frame.origin.y, 1.0, frame.size.height - 1.0);
}

- (NSRect)rightRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x + frame.size.width - 1, frame.origin.y + 1, 1.0, frame.size.height - 2.0);
}

- (NSRect)fillRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x, frame.origin.y + 1, frame.size.width, frame.size.height - 2.0);
}


#pragma mark - fill gradients

+ (NSGradient *)selectedFillGradient {
    if (!_selectedFillGradient) {
        if (@available(macos 10.14, *)) {
            _selectedFillGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor unemphasizedSelectedTextBackgroundColor],
                          [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.60]
                          ]];
        } else { 
            _selectedFillGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor colorWithCalibratedWhite:0.808 alpha:1.0],
                          [NSColor colorWithCalibratedWhite:0.792 alpha:1.0]
                          ]];
        }
    }
    return _selectedFillGradient;
}

+ (void)setSelectedFillGradient:(NSGradient *)newGradient {
    if (newGradient != _selectedFillGradient) {
        _selectedFillGradient = newGradient;
    }
}

+ (NSGradient *)idleFillGradient {
    if (!_idleFillGradient) {
        if (@available(macos 10.14, *)) {
            _idleFillGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor unemphasizedSelectedTextBackgroundColor],
                          [[NSColor unemphasizedSelectedTextBackgroundColor] colorWithAlphaComponent:0.50]
                          ]];
        } else { 
            _idleFillGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor colorWithCalibratedWhite:0.698 alpha:1.0],
                          [NSColor colorWithCalibratedWhite:0.682 alpha:1.0]
                          ]];
        }
    }
    return _idleFillGradient;
}

+ (void)setIdleFillGradient:(NSGradient *)newGradient {
    if (newGradient != _idleFillGradient) {
        _idleFillGradient = newGradient;
    }
}

+ (NSGradient *)hoverFillGradient {
    if (!_hoverFillGradient) {
        if (@available(macos 10.14, *)) {
            _hoverFillGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [[NSColor unemphasizedSelectedTextBackgroundColor] colorWithAlphaComponent:1],
                          [NSColor colorWithCalibratedWhite:0.647 alpha:1.0]
                          ]];
        } else { 
            _hoverFillGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor colorWithCalibratedWhite:0.663 alpha:1.0],
                          [NSColor colorWithCalibratedWhite:0.647 alpha:1.0]
                          ]];
        }
    }
    return _hoverFillGradient;
}

+ (void)setHoverFillGradient:(NSGradient *)newGradient {
    if (newGradient != _hoverFillGradient) {
        _hoverFillGradient = newGradient;
    }
}

+ (NSGradient *)mouseDownFillGradient {
    if (!_mouseDownFillGradient) {
        _mouseDownFillGradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.608 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.557 alpha:1.0]
                      ]];
    }
    return _mouseDownFillGradient;
}

+ (void)setMouseDownFillGradient:(NSGradient *)newGradient {
    if (newGradient != _mouseDownFillGradient) {
        _mouseDownFillGradient = newGradient;
    }
}

#pragma mark - top border gradients
+ (NSGradient *)selectedTopBorderGradient {
    if (!_selectedTopBorderGradient) {
        if (@available(macos 10.14, *)) {
            _selectedTopBorderGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor systemGrayColor],
                          [NSColor colorWithCalibratedWhite:0.686 alpha:1.0]
                          ]];
        } else { 
            _selectedTopBorderGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor colorWithCalibratedWhite:0.690 alpha:1.0],
                          [NSColor colorWithCalibratedWhite:0.686 alpha:1.0]
                          ]];
        }
    }
    return _selectedTopBorderGradient;
}

+ (void)setSelectedTopBorderGradient:(NSGradient *)newGradient {
    if (newGradient != _selectedTopBorderGradient) {
        _selectedTopBorderGradient = newGradient;
    }
}

+ (NSGradient *)unselectedTopBorderGradient {
    if (!_unselectedTopBorderGradient) {
        if (@available(macos 10.14, *)) {
            _unselectedTopBorderGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor systemGrayColor],
                          [NSColor colorWithCalibratedWhite:0.573 alpha:1.0]
                          ]];
        } else { 
            _unselectedTopBorderGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor colorWithCalibratedWhite:0.592 alpha:1.0],
                          [NSColor colorWithCalibratedWhite:0.588 alpha:1.0]
                          ]];
        }
    }
    return _unselectedTopBorderGradient;
}

+ (void)setUnselectedTopBorderGradient:(NSGradient *)newGradient {
    if (newGradient != _unselectedTopBorderGradient) {
        _unselectedTopBorderGradient = newGradient;
    }
}

#pragma mark - left/right-border gradients

+ (NSGradient *)edgeBorderGradient {
    if (!_edgeBorderGradient) {
        if (@available(macos 10.14, *)) {
            _edgeBorderGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor systemGrayColor],
                          [NSColor colorWithCalibratedWhite:0.573 alpha:1.0]
                          ]];
        } else {
            _edgeBorderGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor colorWithCalibratedWhite:0.588 alpha:1.0],
                          [NSColor colorWithCalibratedWhite:0.573 alpha:1.0]
                          ]];
        }
    }
    return _edgeBorderGradient;
}

+ (void)setEdgeBorderGradient:(NSGradient *)newGradient {
    if (newGradient != _edgeBorderGradient) {
        _edgeBorderGradient = newGradient;
    }
}

#pragma mark - bottom gradients

+ (NSGradient *)bottomBorderGradient {
    if (!_bottomBorderGradient) {
        if (@available(macos 10.14, *)) {
            _bottomBorderGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor systemGrayColor],
                          [NSColor colorWithCalibratedWhite:0.573 alpha:1.0]
                          ]];
        } else {
            _bottomBorderGradient = [[NSGradient alloc] initWithColors:
                        @[
                          [NSColor colorWithCalibratedWhite:0.592 alpha:1.0],
                          [NSColor colorWithCalibratedWhite:0.588 alpha:1.0]
                          ]];
        }
    }
    return _bottomBorderGradient;
}

+ (void)setBottomBorderGradient:(NSGradient *)newGradient {
    if (newGradient != _bottomBorderGradient) {
        _bottomBorderGradient = newGradient;
    }
}

#pragma mark - inactive windows

+ (NSColor *)inactiveSelectedFillColor {
    if (!_inactiveSelectedFillColor) {
        if (@available(macos 10.14, *)) {
            _inactiveSelectedFillColor = [[NSColor unemphasizedSelectedTextBackgroundColor] colorWithAlphaComponent:0.10];
        } else {
            _inactiveSelectedFillColor = [NSColor colorWithCalibratedWhite:0.957 alpha:1.0];
        }
    }
    return _inactiveSelectedFillColor;
}

+ (void)setInactiveSelectedFillColor:(NSColor *)newColor {
    if (newColor != _inactiveSelectedFillColor) {
        _inactiveSelectedFillColor = newColor;
    }
}

+ (NSColor *)inactiveIdleFillColor {
    if (!_inactiveIdleFillColor) {
        if (@available(macos 10.14, *)) {
            _inactiveIdleFillColor = [[NSColor unemphasizedSelectedTextBackgroundColor] colorWithAlphaComponent:0.50];
        } else {
            _inactiveIdleFillColor = [NSColor colorWithCalibratedWhite:0.906 alpha:1.0];
        }
    }
    return _inactiveIdleFillColor;
}

+ (void)setInactiveIdleFillColor:(NSColor *)newColor {
    if (newColor != _inactiveIdleFillColor) {
        _inactiveIdleFillColor = newColor;
    }
}

+ (NSColor *)inactiveHoverFillColor {
    if (!_inactiveHoverFillColor) {
        if (@available(macos 10.14, *)) {
            _inactiveHoverFillColor = [[NSColor unemphasizedSelectedTextBackgroundColor] colorWithAlphaComponent:1];
        } else {
            _inactiveHoverFillColor = [NSColor colorWithCalibratedWhite:0.871 alpha:1.0];
        }
    }
    return _inactiveHoverFillColor;
}

+ (void)setInactiveHoverFillColor:(NSColor *)newColor {
    if (newColor != _inactiveHoverFillColor) {
        _inactiveHoverFillColor = newColor;
    }
}

+ (NSColor *)inactiveBorderColor {
    if (!_inactiveBorderColor) {
        if (@available(macos 10.14, *)) {
            _inactiveBorderColor = [NSColor placeholderTextColor];
        } else {
            _inactiveBorderColor = [NSColor colorWithCalibratedWhite:0.827 alpha:1.0];
        }
    }
    return _inactiveBorderColor;
}

+ (void)setInactiveBorderColor:(NSColor *)newColor {
    if (newColor != _inactiveBorderColor) {
        _inactiveBorderColor = newColor;
    }
}

+ (NSColor *)inactiveBottomBorderColor {
    if (!_inactiveBottomBorderColor) {
        if (@available(macos 10.14, *)) {
            _inactiveBottomBorderColor = [NSColor placeholderTextColor];
        } else {
            _inactiveBottomBorderColor = [NSColor colorWithCalibratedWhite:0.784 alpha:1.0];
        }
    }
    return _inactiveBottomBorderColor;
}

+ (void)setInactiveBottomBorderColor:(NSColor *)newColor {
    if (newColor != _inactiveBottomBorderColor) {
        _inactiveBottomBorderColor = newColor;
    }
}



@end

NS_ASSUME_NONNULL_END
