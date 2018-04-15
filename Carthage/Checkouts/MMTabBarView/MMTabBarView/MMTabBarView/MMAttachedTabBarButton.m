//
//  MMAttachedTabBarButton.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/5/12.
//
//

#import "MMAttachedTabBarButton.h"

#import "MMAttachedTabBarButtonCell.h"
#import "MMTabDragAssistant.h"
#import "MMTabStyle.h"
#import "NSView+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMAttachedTabBarButton ()
@end

@implementation MMAttachedTabBarButton

+ (void)initialize {
    [super initialize];    
}

+ (nullable Class)cellClass {
    return [MMAttachedTabBarButtonCell class];
}

- (instancetype)initWithFrame:(NSRect)frame tabViewItem:(NSTabViewItem *)anItem {

    self = [super initWithFrame:frame];
    if (self) {
        _tabViewItem = anItem;
        _isInAnimatedSlide = NO;
        _isInDraggedSlide = NO;
    }

    return self;
}

- (instancetype)initWithFrame:(NSRect)frame {

    NSAssert(FALSE,@"please use designated initializer -initWithFrame:tabViewItem:");

    return nil;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

- (nullable MMAttachedTabBarButtonCell *)cell {
    return (MMAttachedTabBarButtonCell *)[super cell];
}

- (void)setCell:(nullable MMAttachedTabBarButtonCell *)aCell {
    [super setCell:aCell];
}

-(void)viewWillDraw {

    NSView *superview = [self superview];    
    [superview setNeedsDisplayInRect:[superview bounds]];

    [super viewWillDraw];
}

#pragma mark -
#pragma mark Properties

- (NSRect)slidingFrame {
    @synchronized(self) {
        return [self frame];
    }
}

- (void)setSlidingFrame:(NSRect)aRect {
    @synchronized(self) {
        aRect.origin.y = [self frame].origin.y;
        [self setFrame:aRect];
    }
}

- (BOOL)isSliding {
    return _isInDraggedSlide || _isInAnimatedSlide;
}

- (void)setTitle:(NSString *)aString {
    [super setTitle:aString];
    
        // additionally synchronize label of tab view item if appropriate
    if (_tabViewItem && [_tabViewItem respondsToSelector:@selector(label)]) {
        if (![[_tabViewItem label] isEqualToString:aString]) {
            [_tabViewItem setLabel:aString];
        }
    }
}

#pragma mark -
#pragma mark Dividers

- (BOOL)shouldDisplayLeftDivider {

    if ([self isSliding] || ([self tabState] & MMTab_PlaceholderOnLeft))
        return YES;
    
    return [super shouldDisplayLeftDivider];
}

- (BOOL)shouldDisplayRightDivider {
    
    if ([self isOverflowButton])
        return NO;
    
    return YES;
}

#pragma mark -
#pragma mark Interfacing Cell

- (BOOL)isOverflowButton {
    return [[self cell] isOverflowButton];
}

- (void)setIsOverflowButton:(BOOL)value {
    [[self cell] setIsOverflowButton:value];
}

#pragma mark -
#pragma mark Event Handling

- (void)mouseDown:(NSEvent *)theEvent {

    MMAttachedTabBarButton *previousSelectedButton = [self _selectedAttachedTabBarButton];

    MMTabBarView *tabBarView = [self tabBarView];

        // select immediately
    if ([tabBarView selectsTabsOnMouseDown]) {
        if (self != previousSelectedButton) {
            [previousSelectedButton setState:NSOffState];
            [self setState:NSOnState];
            [self sendAction:[self action] to:[self target]];
        }
    }

        // eventually begin dragging of button
    if ([tabBarView shouldStartDraggingAttachedTabBarButton:self withMouseDownEvent:theEvent]) {
        [tabBarView startDraggingAttachedTabBarButton:self withMouseDownEvent:theEvent];
    }
}

- (void)mouseUp:(NSEvent *)theEvent {

    MMTabBarView *tabBarView = [self tabBarView];
    
    NSPoint mouseUpPoint = [theEvent locationInWindow];
    NSPoint mousePt = [self convertPoint:mouseUpPoint fromView:nil];
    
    if (NSMouseInRect(mousePt, [self bounds], [self isFlipped])) {
        if (![tabBarView selectsTabsOnMouseDown]) {
            MMAttachedTabBarButton *previousSelectedButton = [self _selectedAttachedTabBarButton];
            [previousSelectedButton setState:NSOffState];
            [self setState:NSOnState];
            [self sendAction:[self action] to:[self target]];
        }
    }
}

#pragma mark -
#pragma mark Drag Support

- (NSRect)draggingRect {

    id <MMTabStyle> style = [self style];
    MMTabBarView *tabBarView = [self tabBarView];

    NSRect draggingRect = NSZeroRect;
    
    if (style && [style respondsToSelector:@selector(draggingRectForTabButton:ofTabBarView:)]) {
        draggingRect = [style draggingRectForTabButton:self ofTabBarView:tabBarView];
    } else {
        draggingRect = [self _draggingRect];
    }
    
    return draggingRect;
}

- (NSImage *)dragImage {

        // assure that we will draw the tab bar contents correctly
    [self setFrame:[self stackingFrame]];

    MMTabBarView *tabBarView = [self tabBarView];

    NSRect draggingRect = [self draggingRect];
        
	[tabBarView lockFocus];
    [tabBarView display];  // forces update to ensure that we get current state
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:draggingRect];
	[tabBarView unlockFocus];
	NSImage *image = [[NSImage alloc] initWithSize:[rep size]];
	[image addRepresentation:rep];
	NSImage *returnImage = [[NSImage alloc] initWithSize:[rep size]];
	[returnImage lockFocus];
    [image drawAtPoint:NSMakePoint(0.0, 0.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[returnImage unlockFocus];
	if (![[self indicator] isHidden]) {
		NSImage *pi = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"pi"]];
		[returnImage lockFocus];
		NSPoint indicatorPoint = NSMakePoint([self frame].size.width - MARGIN_X - kMMTabBarIndicatorWidth, MARGIN_Y);
        [pi drawAtPoint:indicatorPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		[returnImage unlockFocus];
	}
	return returnImage;
}

#pragma mark -
#pragma mark Animation Support

- (void)slideAnimationWillStart {
    _isInAnimatedSlide = YES;
}

- (void)slideAnimationDidEnd {
    _isInAnimatedSlide = NO;
}

#pragma mark -
#pragma mark NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {

    self = [super initWithCoder:coder];
    if (self) {
        _tabViewItem = nil;
        _isInAnimatedSlide = NO;
        _isInDraggedSlide = NO;
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
}

#pragma mark -
#pragma mark Private Methods

- (MMAttachedTabBarButton *)_selectedAttachedTabBarButton {

    MMTabBarView *tabBarView = [self enclosingTabBarView];
    return [tabBarView selectedAttachedButton];
}

- (NSRect)_draggingRect {
    return [self frame];
}

@end

NS_ASSUME_NONNULL_END
