//
//  MMMojaveTabStyle.m
//  --------------------
//
//  Based on MMYosemiteTabStyle.h by Ajin Man Tuladhar
//  Created by Jim Derry on 2018/07/30.
//  Changes released in accordance with MMTabBarView license.
//

#import "MMMojaveTabStyle.h"
#import "MMMojaveTabStyle+Assets.h"
#import "MMAttachedTabBarButton.h"
#import "MMTabBarView.h"
#import "NSView+MMTabBarViewExtensions.h"
#import "NSBezierPath+MMTabBarViewExtensions.h"
#import "MMOverflowPopUpButton.h"
#import "MMTabBarView.Private.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMMojaveTabStyle


+ (NSString *)name
{
    return @"Mojave";
}


- (NSString *)name
{
    return self.class.name;
}


#pragma mark - Creation/Destruction


- (id) init
{
    if ((self = [super init]))
    {
      _leftMarginForTabBarView = 0.0;
      _needsResizeTabsToFitTotalWidth = YES;
    }

    SEL selector = NSSelectorFromString(@"resetColors");
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:selector name:@"AppleInterfaceThemeChangedNotification" object:
     nil];

    return self;
}

- (void) dealloc
{
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Tab View Specific


- (NSSize)intrinsicContentSizeOfTabBarView:(MMTabBarView *)tabBarView
{
    return NSMakeSize(noIntrinsicMetric(), 26);
}


- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView
{
    return (tabBarView.orientation == MMTabBarHorizontalOrientation) ? 0.0 : 0.0;
}


- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView
{
    return (tabBarView.orientation == MMTabBarHorizontalOrientation) ? 0.0 : 0.0;
}


- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView
{
    return (tabBarView.orientation == MMTabBarHorizontalOrientation) ? 0.0 : 0.0;
}


- (CGFloat)heightOfTabBarButtonsForTabBarView:(MMTabBarView *)tabBarView
{
    return 26;
}


- (NSSize)overflowButtonSizeForTabBarView:(MMTabBarView *)tabBarView
{
    return NSMakeSize(14, [self heightOfTabBarButtonsForTabBarView:tabBarView]);
}


- (NSRect)addTabButtonRectForTabBarView:(MMTabBarView *)tabBarView
{
    if (!tabBarView.showAddTabButton)
        return NSZeroRect;

    NSRect rect = NSZeroRect;
    NSRect bounds = tabBarView.bounds;
    NSSize buttonSize = tabBarView.addTabButtonSize;

    rect.origin.x = bounds.size.width - buttonSize.width - kMMTabBarCellPadding - 1;
    rect.origin.y = (bounds.size.height - buttonSize.height) / 2;
    rect.size = buttonSize;

    return rect;
}


- (NSSize)addTabButtonSizeForTabBarView:(MMTabBarView *)tabBarView
{
    NSSize size = NSMakeSize(18, [self heightOfTabBarButtonsForTabBarView:tabBarView] - 2);
    return size;
}


- (NSRect)closeButtonRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell
{
    if (cell.shouldDisplayCloseButton == NO)
    {
        return NSZeroRect;
    }
    
    NSRect drawingRect = [cell drawingRectForBounds:theRect];
    NSSize closeButtonSize = [self closeButtonSizeForBounds:theRect ofTabCell:cell];
    
    CGFloat dy = (drawingRect.size.height - closeButtonSize.height) / 2;
    NSRect result = NSMakeRect(drawingRect.origin.x, drawingRect.origin.y + dy, closeButtonSize.width, closeButtonSize.height);
    
    return result;   
}


- (NSSize)closeButtonSizeForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell
{
    NSSize size = NSMakeSize(16.0, 16.0);
    return size;
}


- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation forTabBarView:(MMTabBarView *)tabBarView
{
    return (orientation == MMTabBarHorizontalOrientation);
}


#pragma mark - Cell Values


- (NSAttributedString *)attributedStringValueForTabCell:(MMTabBarButtonCell *)cell
 {
	NSMutableAttributedString *attrStr;
	NSString *contents = cell.title;
	attrStr = [[NSMutableAttributedString alloc] initWithString:contents];
	NSColor *textColor = nil;
	NSRange range = NSMakeRange(0, contents.length);

	 // Figure out correct text color
    
    if ( cell.controlView.state == NSOnState )
    {
        textColor = [self colorForPart:MMMtabSelectedFont ofTabBarView:cell.tabBarView];
    }
    else if ( cell.mouseHovered )
    {
        textColor = [self colorForPart:MMMtabUnselectedHoverFont ofTabBarView:cell.tabBarView];
    }
    else
    {
        textColor = [self colorForPart:MMMtabUnselectedFont ofTabBarView:cell.tabBarView];
    }

	// Add font attribute
	[attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:range];
	[attrStr addAttribute:NSForegroundColorAttributeName value:textColor range:range];

	// Paragraph Style for Truncating Long Text
	static NSMutableParagraphStyle *TruncatingTailParagraphStyle = nil;
	if (!TruncatingTailParagraphStyle)
	{
		TruncatingTailParagraphStyle = [NSParagraphStyle.defaultParagraphStyle mutableCopy];
		[TruncatingTailParagraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
		[TruncatingTailParagraphStyle setAlignment:NSCenterTextAlignment];
	}
	[attrStr addAttribute:NSParagraphStyleAttributeName value:TruncatingTailParagraphStyle range:range];

	return attrStr;
}


#pragma mark - Drag Support


- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView
{
    NSRect dragRect = aButton.stackingFrame;
    dragRect.size.width++;
    return dragRect;
}


#pragma mark - Add Tab Button


- (void)updateAddButton:(MMRolloverButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView
{
    [aButton setImage:[self assetForPart:MMMaddButtonImage ofTabBarView:tabBarView]];
    [aButton setAlternateImage:[self assetForPart:MMMaddButtonImageAlternate ofTabBarView:tabBarView]];
    [aButton setRolloverImage:[self assetForPart:MMMaddButtonImageRollover ofTabBarView:tabBarView]];
}


#pragma mark - Providing Images


- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell
{
    return [self assetForPart:(MMMojaveTabStyleAsset)type ofTabBarView:cell.tabBarView];
}


#pragma mark - Drawing


- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect
{
    rect = tabBarView.bounds;

    // Oh, I hate to do this, but don't want to screw with the library by adding
    // anything substantial. Instead, let's get the private iVar using this means:
    MMAttachedTabBarButton *addTabButton = [tabBarView valueForKey:@"_addTabButton"];

    // If we don't invalidate the whole rect, then only the button will fill
    // with the new color.
    [tabBarView setNeedsDisplayInRect:rect];

    // In Mojave, during a mouse press there's also another highlighting; however MMTabBarView
    // doesn't provide the architecture that we need to implement this, but with the hack
    // above we can at least perform the hover behavior of Mojave.
    if ( tabBarView.showAddTabButton && addTabButton.cell.mouseHovered )
    {
        [[self colorForPart:MMMtabUnselectedHover ofTabBarView:tabBarView] set];
    }
    else
    {
        [[self colorForPart:MMMtabBarBackground ofTabBarView:tabBarView] set];
    }

    NSRectFill(rect);

    [[self colorForPart:MMMbezelTop ofTabBarView:tabBarView] set];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(rect), NSMinY(rect) + 0.5)
                              toPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect) + 0.5)];

    [[self colorForPart:MMMbezelBottom ofTabBarView:tabBarView] set];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect) - 0.5)
                              toPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect) - 0.5)];
}


-(void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView
{
    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;
    BOOL overflowMode = button.isOverflowButton;
    NSRect aRect = NSZeroRect;

    if (button.isSliding)
    {
        overflowMode = NO;
    }
    
    if (overflowMode) 
    {
        aRect = NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width + 1, frame.size.height);
    } 
    else
    {
        aRect = NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
    }

    // Accommodate border
    aRect.origin.y += 1;
    aRect.size.height -= 2;

    [self _drawCardBezelInRect:aRect withCapMask:MMBezierShapeFlippedVertically usingStatesOfAttachedButton:button ofTabBarView:tabBarView];
}


-(void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect
{
    MMAttachedTabBarButton *lastAttachedButton = tabBarView.lastAttachedButton;
    
    if (lastAttachedButton.isSliding)
    {
        return;
    }
    
    NSRect frame = overflowButton.frame;
    NSRect aRect = NSMakeRect(frame.origin.x, frame.origin.y + 2.0, frame.size.width + 5.0, frame.size.height - 4.0);
    
   [self _drawCardBezelInRect:aRect withCapMask:MMBezierShapeFlippedVertically usingStatesOfAttachedButton:lastAttachedButton ofTabBarView:tabBarView];
}


#pragma mark - Private Methods


- (void)_drawCardBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView
{
    CGFloat radius = 0.0;
    
    NSBezierPath *fillPath = [NSBezierPath bezierPathWithCardInRect:aRect radius:radius capMask:capMask|MMBezierShapeFillPath];

    if (button.state == NSOnState)
    {
        [NSGraphicsContext.currentContext setShouldAntialias:NO];
        [[self colorForPart:MMMtabSelected ofTabBarView:tabBarView] set];
        [fillPath fill];
        [NSGraphicsContext.currentContext setShouldAntialias:YES];
    }
    else if (button.cell.mouseHovered)
    {
        [[self colorForPart:MMMtabUnselectedHover ofTabBarView:tabBarView] set];
        [fillPath fill];
    }
    else
    {
        [[self colorForPart:MMMtabUnselected ofTabBarView:tabBarView] set];
        [fillPath fill];
    }

    NSBezierPath *bezier = NSBezierPath.bezierPath;

    [[self colorForPart:MMMbezelMiddle ofTabBarView:tabBarView] set];
    
    if (button.shouldDisplayLeftDivider)
    {
        [bezier moveToPoint:NSMakePoint(NSMinX(aRect)-0.5, NSMinY(aRect))];
        [bezier lineToPoint:NSMakePoint(NSMinX(aRect)-0.5, NSMaxY(aRect))];
    }

    BOOL shouldDisplayRightDivider = button.shouldDisplayRightDivider;
    if ((button.tabState & (MMTab_PositionRightMask)) && !tabBarView.showAddTabButton && !tabBarView.sizeButtonsToFit)
    {
        shouldDisplayRightDivider = NO;
    }
    
    if (shouldDisplayRightDivider)
    {
        [bezier moveToPoint:NSMakePoint(NSMaxX(aRect)-0.5, NSMinY(aRect))];
        [bezier lineToPoint:NSMakePoint(NSMaxX(aRect)-0.5, NSMaxY(aRect))];
    }

    [bezier stroke];
}


@end

NS_ASSUME_NONNULL_END
