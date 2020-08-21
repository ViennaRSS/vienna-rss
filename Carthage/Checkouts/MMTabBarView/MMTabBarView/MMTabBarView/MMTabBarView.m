 //
//  MMTabBarView.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/19/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//


#import "MMTabBarView.h"

#import "MMAttachedTabBarButtonCell.h"
#import "MMOverflowPopUpButton.h"
#import "MMOverflowPopUpButtonCell.h"
#import "MMRolloverButton.h"
#import "MMTabStyle.h"
#import "MMMetalTabStyle.h"
#import "MMAquaTabStyle.h"
#import "MMUnifiedTabStyle.h"
#import "MMAdiumTabStyle.h"
#import "MMLiveChatTabStyle.h"
#import "MMCardTabStyle.h"
#import "MMSafariTabStyle.h"
#import "MMYosemiteTabStyle.h"
#import "MMSierraTabStyle.h"
#import "MMTabDragAssistant.h"
#import "MMTabBarController.h"
#import "MMAttachedTabBarButton.h"
#import "MMTabPasteboardItem.h"
#import "MMSlideButtonsAnimation.h"
#import "NSView+MMTabBarViewExtensions.h"
#import "MMTabBarItem.h"

NS_ASSUME_NONNULL_BEGIN

#define DIVIDER_WIDTH 3

@interface MMTabBarView ()

// reordering
@property (assign) BOOL isReorderingTabViewItems;

// resizing
@property (assign) BOOL isResizing;
@property (readonly) NSCursor *resizingMouseCursor;

// private actions
- (IBAction)_overflowMenuAction:(id)sender;
- (IBAction)_didClickTabButton:(id)sender;
- (IBAction)_didClickCloseButton:(id)sender;

@end


CGFloat noIntrinsicMetric(void) {
    if (@available(macos 10.11, *)) {
        return NSViewNoIntrinsicMetric;
    }
    else {
        return NSViewNoInstrinsicMetric;
    }
}


@implementation MMTabBarView
{
    // control basics
    NSTabView                       *_tabView;                    // the tab view being navigated
    MMOverflowPopUpButton           *_overflowPopUpButton;        // for too many tabs
    MMRolloverButton                *_addTabButton;
    MMTabBarController              *_controller;

    // Spring-loading.
    NSTimer                         *_springTimer;
    NSTabViewItem                   *_tabViewItemWithSpring;

    // configuration
    id <MMTabStyle>                 _style;
    BOOL                            _onlyShowCloseOnHover;    
    BOOL                            _canCloseOnlyTab;
    BOOL                            _disableTabClose;
    BOOL                            _hideForSingleTab;
    BOOL                            _showAddTabButton;
    BOOL                            _sizeButtonsToFit;
    BOOL                            _useOverflowMenu;
    BOOL                            _alwaysShowActiveTab;
    BOOL                            _allowsScrubbing;
    NSInteger                       _resizeAreaCompensation;
    MMTabBarOrientation             _orientation;
    BOOL                            _automaticallyAnimates;
    MMTabBarTearOffStyle            _tearOffStyle;
    BOOL                            _allowsBackgroundTabClosing;
    BOOL                            _selectsTabsOnMouseDown;

    // vertical tab resizing
    BOOL                            _allowsResizing;

    // button width
    NSInteger                       _buttonMinWidth;
    NSInteger                       _buttonMaxWidth;
    NSInteger                       _buttonOptimumWidth;

    // animation
    MMSlideButtonsAnimation         *_slideButtonsAnimation;
    
    // properties for hide/show
    BOOL                            _isHidden;
    NSInteger                       _tabBarWidth;   // stored width of vertical tab bar
        
    // states
    BOOL                            _needsUpdate;

    // delegate
    id <MMTabBarViewDelegate> __weak _delegate;
}

static NSMutableDictionary<NSString*, Class <MMTabStyle>> *registeredStyleClasses = nil;

+ (void)initialize
{
    if (self == MMTabBarView.class) {
        if (registeredStyleClasses == nil) {
            registeredStyleClasses = [NSMutableDictionary dictionaryWithCapacity:10];
            
            [self registerDefaultTabStyleClasses];
        }
    }
}

- (instancetype)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		// Initialization
		[self _commonInit];

		_style = [[MMMetalTabStyle alloc] init];

		[self registerForDraggedTypes:@[AttachedTabBarButtonUTI]];

		// resize
		[self setPostsFrameChangedNotifications:YES];
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(frameDidChange:) name:NSViewFrameDidChangeNotification object:self];
	}

	return self;
}

- (void)dealloc {
    
	[NSNotificationCenter.defaultCenter removeObserver:self];

    // assure that pending animation will stop
    if (_slideButtonsAnimation) {
        [_slideButtonsAnimation stopAnimation];
        _slideButtonsAnimation = nil;
    }

	//Also unwind the spring, if it's wound.
	[_springTimer invalidate];

	//unbind all the items to prevent crashing
	//not sure if this is necessary or not
	// http://code.google.com/p/maccode/issues/detail?id=35
    NSSet<MMAttachedTabBarButton *> *tmpButtonArray = self.attachedButtons;
    for (MMAttachedTabBarButton *aButton in tmpButtonArray) {
		[self removeAttachedButton:aButton];
	}

	[self unregisterDraggedTypes];
}

- (void)viewWillMoveToWindow:(nullable NSWindow *)aWindow {
	NSNotificationCenter *center = NSNotificationCenter.defaultCenter;

    [super viewWillMoveToWindow:aWindow];
    
    if (_slideButtonsAnimation) {
		[_slideButtonsAnimation stopAnimation];
		 _slideButtonsAnimation = nil;    
    }
    
    if (self.window) {
    
        [center removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
        [center removeObserver:self name:NSWindowDidResignKeyNotification object:nil];
        [center removeObserver:self name:NSWindowDidMoveNotification object:nil];
    
        [self.window removeObserver:self forKeyPath:@"toolbar.visible"];
    }

	if (aWindow) {
    
		[center addObserver:self selector:@selector(windowStatusDidChange:) name:NSWindowDidBecomeKeyNotification object:aWindow];
		[center addObserver:self selector:@selector(windowStatusDidChange:) name:NSWindowDidResignKeyNotification object:aWindow];
		[center addObserver:self selector:@selector(windowDidMove:) name:NSWindowDidMoveNotification object:aWindow];
        
        [aWindow addObserver:self forKeyPath:@"toolbar.visible" options:NSKeyValueObservingOptionNew context:NULL];
	}
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
	[self _checkWindowFrame];
}

- (void)viewWillStartLiveResize {
    for (MMAttachedTabBarButton *aButton in self.attachedButtons) {
		[aButton.indicator stopAnimation:self];
	}
	[self setNeedsDisplay:YES];
}

-(void)viewDidEndLiveResize {
	[self _checkWindowFrame];
	[self update:NO];
}

- (void)resetCursorRects {

	[super resetCursorRects];
    
	if (self.orientation == MMTabBarVerticalOrientation) {

        NSCursor *cursor = self.resizingMouseCursor;
        [self addCursorRect:self.dividerRect cursor:cursor];
	}
}

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent {
	return YES;
}

//Height auto-adjusts based on if we are hidden or not.  This lets autolayout adjust for when we hide/show the tab bar.
- (NSSize)intrinsicContentSize
{
	/*CMC EDITED*/
	//Height auto-adjusts based on if we are hidden or not.  This lets autolayout adjust for when we hide/show the tab bar.
    if ([_style respondsToSelector:@selector(intrinsicContentSizeOfTabBarView:)])
	{
		if(_isHidden)
				return NSMakeSize(noIntrinsicMetric(), 0);
		else
				return [_style intrinsicContentSizeOfTabBarView:self];
	}

    return NSMakeSize(noIntrinsicMetric(), noIntrinsicMetric());
}

#pragma mark -
#pragma mark Characteristics

+ (NSBundle *)bundle;
{
	static NSBundle *bundle = nil;
	if (!bundle) {
		bundle = [NSBundle bundleForClass:MMTabBarView.class];
	}
	return bundle;
}

/*!
    @method     availableWidthForButtons
    @abstract   The number of pixels available for buttons
    @discussion Calculates the number of pixels available for buttons based on margins and the window resize badge.
    @returns    Returns the amount of space for buttons.
 */

- (CGFloat)availableWidthForButtons {

    CGFloat result = self.frame.size.width - self.leftMargin - self.rightMargin;
        
    result -= _resizeAreaCompensation;
    
        //Don't let attached buttons overlap the add tab button if it is visible

	if (self.showAddTabButton) {

        CGFloat padding = kMMTabBarCellPadding;
        if ([_style respondsToSelector:@selector(addTabButtonPaddingForTabBarView:)]) {
            padding = [_style addTabButtonPaddingForTabBarView:self];
        }

		result -= self.addTabButtonSize.width + (2 * padding);
	}
    
    return result;
}

/*!
    @method     availableHeightForButtons
    @abstract   The number of pixels available for buttons
    @discussion Calculates the number of pixels available for buttons based on margins and the window resize badge.
    @returns    Returns the amount of space for buttons.
 */

- (CGFloat)availableHeightForButtons {

    CGFloat result = self.bounds.size.height - self.topMargin - self.bottomMargin;
    
    result -= _resizeAreaCompensation;
        
	//Don't let attached buttons overlap the add tab button if it is visible
	if (self.showAddTabButton) {
		result -= self.addTabButtonRect.size.height;
	}

	//let room for overflow popup button
    if (self.useOverflowMenu && !_overflowPopUpButton.isHidden) {
		result -= self.overflowButtonRect.size.height;
    }
    
    return result;
}

/*!
    @method     genericButtonRect
    @abstract   The basic rect for a tab button.
    @discussion Creates a generic frame for a tab button based on the current control state.
    @returns    Returns a basic rect for a tab button.
 */

- (NSRect)genericButtonRect {
	NSRect aRect = self.frame;
	aRect.origin.x = self.leftMargin;
	aRect.origin.y = self.topMargin;
	aRect.size.width = self.availableWidthForButtons;
	aRect.size.height = self.heightOfTabBarButtons;
	return aRect;
}

- (BOOL)isWindowActive {
    NSWindow *window = self.window;
    BOOL windowActive = NO;
    
    if (window.isKeyWindow) {
        windowActive = YES;
    }
    else if ([window isKindOfClass:NSPanel.class] && NSApp.isActive) {
        windowActive = YES;
    }
    else if (window.isMainWindow) {
        // Don't gray out the tab bar if we're displaying a sheet.
        windowActive = YES;
    }
    return windowActive;
}

- (BOOL)allowsDetachedDraggingOfTabViewItem:(NSTabViewItem *)anItem {

    if (_delegate && [_delegate respondsToSelector:@selector(tabView:shouldAllowTabViewItem:toLeaveTabBarView:)]) {
        return [_delegate tabView:_tabView shouldAllowTabViewItem:anItem toLeaveTabBarView:self];
    }

    return NO;
}

- (void)windowStatusDidChange:(NSNotification *)notification {

    [self _updateImages];

	[self setNeedsUpdate:YES];
}

#pragma mark -
#pragma mark Style Class Registry

+ (void)registerDefaultTabStyleClasses {

    [self registerTabStyleClass:MMAquaTabStyle.class];
    [self registerTabStyleClass:MMUnifiedTabStyle.class];
    [self registerTabStyleClass:MMAdiumTabStyle.class];
    [self registerTabStyleClass:MMMetalTabStyle.class];
    [self registerTabStyleClass:MMMojaveTabStyle.class];
    [self registerTabStyleClass:MMCardTabStyle.class];
    [self registerTabStyleClass:MMLiveChatTabStyle.class];
    [self registerTabStyleClass:MMSafariTabStyle.class];
    [self registerTabStyleClass:MMYosemiteTabStyle.class];
    [self registerTabStyleClass:MMSierraTabStyle.class];
}

+ (void)registerTabStyleClass:(Class <MMTabStyle>)aStyleClass {
    [registeredStyleClasses setObject:aStyleClass forKey:[aStyleClass name]];
}

+ (void)unregisterTabStyleClass:(Class <MMTabStyle>)aStyleClass {
    [registeredStyleClasses removeObjectForKey:[aStyleClass name]];
}

+ (NSArray<Class <MMTabStyle>> *)registeredTabStyleClasses {
    return registeredStyleClasses.allValues;
}

+ (nullable Class <MMTabStyle>)registeredClassForStyleName:(NSString *)name {
    return [registeredStyleClasses objectForKey:name];
}

#pragma mark -
#pragma mark Tab View Item Management

- (NSUInteger)numberOfTabViewItems {
    return _tabView.numberOfTabViewItems;
}

- (NSUInteger)numberOfVisibleTabViewItems {
    return self.viewIndexesOfAttachedButtons.count;
}

- (NSArray<NSTabViewItem*> *)visibleTabViewItems {

    NSArray<MMAttachedTabBarButton *> *attachedButtons = self.orderedAttachedButtons;

	NSMutableArray<NSTabViewItem*> *temp = [NSMutableArray arrayWithCapacity:attachedButtons.count];
    for (MMAttachedTabBarButton *aButton in attachedButtons) {
		if (aButton.tabViewItem) {
			[temp addObject:aButton.tabViewItem];
		}
	}
	return temp;
}

- (NSUInteger)indexOfTabViewItem:(NSTabViewItem *)anItem {

    if (!_tabView || !anItem)
        return NSNotFound;

    return [_tabView indexOfTabViewItem:anItem];
}

- (nullable NSTabViewItem *)selectedTabViewItem {
    return _tabView.selectedTabViewItem;
}

- (void)selectTabViewItem:(NSTabViewItem *)anItem {
    [_tabView selectTabViewItem:anItem];
}

- (void)moveTabViewItem:(NSTabViewItem *)anItem toIndex:(NSUInteger)index {

    [self setIsReorderingTabViewItems:YES];
    
    [_tabView removeTabViewItem:anItem];
    [_tabView insertTabViewItem:anItem atIndex:index];    
    
        // assure that item gets re-selected
    [_tabView selectTabViewItem:anItem];

    [self setIsReorderingTabViewItems:NO];
    
    if (_delegate && [_delegate respondsToSelector:@selector(tabView:didMoveTabViewItem:toIndex:)])
        [_delegate tabView:_tabView didMoveTabViewItem:anItem toIndex:index];
}

- (void)removeTabViewItem:(NSTabViewItem *)anItem {
    [_tabView removeTabViewItem:anItem];
}

- (NSTabViewItem *)tabViewItemPinnedToOverflowButton {
    
    MMAttachedTabBarButton *lastButton = self.lastAttachedButton;
    if (!lastButton)
        return nil;
    
    if (lastButton.isOverflowButton)
        return lastButton.tabViewItem;
    
    return nil;
}

- (void)setTabViewItemPinnedToOverflowButton:(NSTabViewItem *)item {

    MMAttachedTabBarButton *lastButton = self.lastAttachedButton;
    if (!lastButton)
        return;

    [self unbindPropertiesOfAttachedButton:lastButton];
    [lastButton setTabViewItem:item];
    [self bindPropertiesOfAttachedButton:lastButton andTabViewItem:item];
}

#pragma mark -
#pragma mark Attached Buttons Management

- (NSUInteger)numberOfAttachedButtons {
    return self.viewIndexesOfAttachedButtons.count;
}

- (NSSet<MMAttachedTabBarButton *> *)attachedButtons {

    NSIndexSet *indexes = self.viewIndexesOfAttachedButtons;

        // get all attached buttons
    NSArray<MMAttachedTabBarButton *> *buttons = [self.subviews objectsAtIndexes:indexes];
        
    return [NSSet setWithArray:buttons];
}

- (NSArray<MMAttachedTabBarButton *> *)orderedAttachedButtons {

    if (self.isSliding) {
        NSArray<MMAttachedTabBarButton *> *sortedButtons = [self sortedAttachedButtonsUsingComparator:
            ^NSComparisonResult(MMAttachedTabBarButton *but1, MMAttachedTabBarButton *but2) {
            
                NSRect stackingFrame1 = but1.stackingFrame;
                NSRect stackingFrame2 = but2.stackingFrame;
                            
                if (self.orientation == MMTabBarHorizontalOrientation) {
                    
                    if (stackingFrame1.origin.x > stackingFrame2.origin.x)
                        return NSOrderedDescending;
                    else if (stackingFrame1.origin.x < stackingFrame2.origin.x)
                        return NSOrderedAscending;
                    else
                        return NSOrderedSame;
                } else {
                    if (stackingFrame1.origin.y > stackingFrame2.origin.y)
                        return NSOrderedDescending;
                    else if (stackingFrame1.origin.y < stackingFrame2.origin.y)
                        return NSOrderedAscending;
                    else
                        return NSOrderedSame;
                }
            }];
        return sortedButtons;
    } else {
        return [self sortedAttachedButtonsUsingComparator:
            ^NSComparisonResult(MMAttachedTabBarButton *but1, MMAttachedTabBarButton *but2) {
        
            NSUInteger index1 = [self indexOfTabViewItem:but1.tabViewItem],
                       index2 = [self indexOfTabViewItem:but2.tabViewItem];
        
            if (index1 == NSNotFound || index2 == NSNotFound)
                return NSOrderedSame;
            
            if (index1 < index2)
                return NSOrderedAscending;
            else if (index1 > index2)
                return NSOrderedDescending;
            else
                return NSOrderedSame;
            }];
    }
}

- (NSArray<MMAttachedTabBarButton *> *)sortedAttachedButtonsUsingComparator:(NSComparator)cmptr {

    NSIndexSet *indexes = self.viewIndexesOfAttachedButtons;
    
        // get all attached buttons
    NSArray<MMAttachedTabBarButton *> *buttons = [self.subviews objectsAtIndexes:indexes];

        // order buttons by index of tab view item
    buttons = [buttons sortedArrayUsingComparator:cmptr];
    
    return buttons;    
}

- (void)insertAttachedButtonForTabViewItem:(NSTabViewItem *)item atIndex:(NSUInteger)index {

	NSRect buttonFrame = NSZeroRect,
           lastButtonFrame = NSZeroRect;
           
    MMAttachedTabBarButton *lastButton = self.lastAttachedButton;
    if (lastButton) {
		lastButtonFrame = lastButton.frame;
    }
    
	if (self.orientation == MMTabBarHorizontalOrientation) {
		buttonFrame = self.genericButtonRect;
		buttonFrame.size.width = 30;
		buttonFrame.origin.x = lastButtonFrame.origin.x + lastButtonFrame.size.width;
	} else {
		buttonFrame = /*lastCellFrame*/ self.genericButtonRect;
		buttonFrame.size.width = lastButtonFrame.size.width;
		buttonFrame.size.height = 0;
		buttonFrame.origin.y = lastButtonFrame.origin.y + lastButtonFrame.size.height;
	}

        // create attached tab bar button
	MMAttachedTabBarButton *button = [[MMAttachedTabBarButton alloc] initWithFrame:buttonFrame tabViewItem:item];

    [button setRolloverButtonType:MMRolloverSwitchButton];
    [button setSimulateClickOnMouseHovered:_allowsScrubbing];
    [button setStyle:self.style];

        // bind it up
	[self bindPropertiesOfAttachedButton:button andTabViewItem:item];

        // add button as subview
    [self addSubview:button];
    
        // add tab item at specified index
    if ([_tabView.tabViewItems indexOfObjectIdenticalTo:item] == NSNotFound) {
        [_tabView insertTabViewItem:item atIndex:index];
        [_tabView selectTabViewItem:item];
    }    
}

- (void)addAttachedButtonForTabViewItem:(NSTabViewItem *)item {
  [self insertAttachedButtonForTabViewItem:item atIndex:self.numberOfAttachedButtons];
}

- (void)removeAttachedButton:(MMAttachedTabBarButton *)aButton synchronizeTabViewItems:(BOOL)syncTabViewItems {

    if (syncTabViewItems) {
        NSTabViewItem *item = aButton.tabViewItem;
        if (item) {
                // remove tab item
            if ([_tabView.tabViewItems indexOfObjectIdenticalTo:item] != NSNotFound) {
                [_tabView removeTabViewItem:item];
                return;  // exit here. We will call removeAttachedButton: in -update: 
            }
        }
    }
    
    [self removeAttachedButton:aButton];
}

- (void)removeAttachedButton:(MMAttachedTabBarButton *)aButton {

        // only try to unbind if button is attached
    if ([self.attachedButtons containsObject:aButton])
        [self unbindPropertiesOfAttachedButton:aButton];

        // pull button (if it is attached)
    if (aButton.superview)
        [aButton removeFromSuperview];
}

-(void)insertAttachedButton:(MMAttachedTabBarButton *)aButton atTabItemIndex:(NSUInteger)anIndex {

    [self addSubview:aButton];

    NSTabViewItem *item = aButton.tabViewItem;

        //rebind the button to the new control
    [self bindPropertiesOfAttachedButton:aButton andTabViewItem:item];

    [_tabView insertTabViewItem:item atIndex:anIndex];
    [_tabView selectTabViewItem:item];
}

#pragma mark -
#pragma mark Find Attached Buttons

- (NSIndexSet *)viewIndexesOfAttachedButtons {

    return [self.subviews indexesOfObjectsPassingTest:
        ^BOOL(NSView *aView, NSUInteger idx, BOOL *stop) {
        
            if ([aView isKindOfClass:MMAttachedTabBarButton.class])
                return YES;
        
            return NO;
        }];
}

- (NSUInteger)viewIndexOfSelectedAttachedButton {

    return [[self.subviews indexesOfObjectsPassingTest:
        ^BOOL(NSView *aView, NSUInteger idx, BOOL *stop) {
        
            if ([aView isKindOfClass:MMAttachedTabBarButton.class] && [(MMAttachedTabBarButton *)aView state] == NSOnState)
                return YES;
        
            return NO;
        }] lastIndex];
}

- (MMAttachedTabBarButton *)selectedAttachedButton {

    NSUInteger indexOfSelectedAttachedButton = self.viewIndexOfSelectedAttachedButton;
    if (indexOfSelectedAttachedButton != NSNotFound)
        return self.subviews[indexOfSelectedAttachedButton];
    else
        return nil;
}

- (nullable MMAttachedTabBarButton *)lastAttachedButton {
    return self.orderedAttachedButtons.lastObject;
}

- (MMAttachedTabBarButton *)attachedButtonAtPoint:(NSPoint)aPoint {
    MMTabBarButton *tabBarButton = [self tabBarButtonAtPoint:aPoint];
    if ([tabBarButton isKindOfClass:MMAttachedTabBarButton.class])
        return (MMAttachedTabBarButton *)tabBarButton;
    
    return nil;
}

- (MMAttachedTabBarButton *)attachedButtonForTabViewItem:(NSTabViewItem *)anItem {

    NSSet<MMAttachedTabBarButton *> *buttons = self.attachedButtons;
    for (MMAttachedTabBarButton *aButton in buttons) {
        if (aButton.tabViewItem == anItem) {
            return aButton;
        }
    }
    
    return nil;
}

- (NSUInteger)indexOfAttachedButton:(MMAttachedTabBarButton *)aButton {

    return [self.orderedAttachedButtons indexOfObjectIdenticalTo:aButton];
}

#pragma mark -
#pragma mark Button State Management

- (void)updateTabStateMaskOfAttachedButton:(MMAttachedTabBarButton *)aButton atIndex:(NSUInteger)index withPrevious:(MMAttachedTabBarButton *)prevButton next:(MMAttachedTabBarButton *)nextButton {

    MMTabStateMask tabStateMask = aButton.tabState;
    
        // set position related state
    tabStateMask &= ~(MMTab_PositionRightMask|MMTab_PositionLeftMask|MMTab_PositionMiddleMask|MMTab_PositionSingleMask);
    if (nextButton == nil)
        tabStateMask |= MMTab_PositionRightMask;
    if (prevButton == nil)
        tabStateMask |= MMTab_PositionLeftMask;
    if (prevButton != nil && nextButton != nil)
        tabStateMask |= MMTab_PositionMiddleMask;
    else if (prevButton == nil && nextButton == nil)
        tabStateMask |= MMTab_PositionSingleMask;
       
    [aButton setTabState:tabStateMask];
    
        // set selection state related state
    MMTabStateMask prevButtonTabStateMask = prevButton.tabState;
    MMTabStateMask nextButtonTabStateMask = nextButton.tabState;
    
    if (aButton.state == NSOnState) {
        prevButtonTabStateMask |= MMTab_RightIsSelectedMask;
        nextButtonTabStateMask |= MMTab_LeftIsSelectedMask;
    } else {
        prevButtonTabStateMask &= ~MMTab_RightIsSelectedMask;
        nextButtonTabStateMask &= ~MMTab_LeftIsSelectedMask;
    }
    
        // set sliding state related state
    if (aButton.isSliding) {
        prevButtonTabStateMask |= MMTab_RightIsSliding;
        nextButtonTabStateMask |= MMTab_LeftIsSliding;
    } else {
        prevButtonTabStateMask &= ~MMTab_RightIsSliding;
        nextButtonTabStateMask &= ~MMTab_LeftIsSliding;
    }

    if (index == _destinationIndexForDraggedItem) {
        prevButtonTabStateMask |= MMTab_PlaceholderOnRight;
        nextButtonTabStateMask |= MMTab_PlaceholderOnLeft;
    } else {
        prevButtonTabStateMask &= ~MMTab_PlaceholderOnRight;
        nextButtonTabStateMask &= ~MMTab_PlaceholderOnLeft;
    }
    
    [prevButton setTabState:prevButtonTabStateMask];
    [nextButton setTabState:nextButtonTabStateMask];
}

-(void)updateTabStateMaskOfAttachedButton:(MMAttachedTabBarButton *)aButton atIndex:(NSUInteger)index {

    NSArray<MMAttachedTabBarButton *> *buttons = self.orderedAttachedButtons;

    MMAttachedTabBarButton *prevButton = nil,
                           *nextButton = nil;
    
    if (index+1 < buttons.count)
        nextButton = buttons[index+1];
    if (index > 0)
        prevButton = buttons[index-1];

    [self updateTabStateMaskOfAttachedButton:aButton atIndex:index withPrevious:prevButton next:nextButton];
}

- (void)updateTabStateMaskOfAttachedButtons {

    [self enumerateAttachedButtonsWithOptions:MMAttachedButtonsEnumerationUpdateTabStateMask usingBlock:nil];
}

#pragma mark -
#pragma mark Sending Messages to Attached Buttons

- (void)enumerateAttachedButtonsUsingBlock:(void (^)(MMAttachedTabBarButton *aButton, NSUInteger idx, BOOL *stop))block {

    [self.orderedAttachedButtons enumerateObjectsUsingBlock:block];
}

- (void)enumerateAttachedButtonsWithOptions:(MMAttachedButtonsEnumerationOptions)opts usingBlock:(nullable void (^)(MMAttachedTabBarButton *aButton, NSUInteger idx, MMAttachedTabBarButton *previousButton, MMAttachedTabBarButton *nextButton, BOOL *stop))aBlock {
	void (^block)(MMAttachedTabBarButton *aButton, NSUInteger idx, MMAttachedTabBarButton *previousButton, MMAttachedTabBarButton *nextButton, BOOL *stop) = aBlock;
	if (block == nil) {
		return;
	}

    NSArray<MMAttachedTabBarButton *> *buttons = self.orderedAttachedButtons;

    [self enumerateAttachedButtons:buttons inRange:NSMakeRange(0, buttons.count) withOptions:opts usingBlock:block];
}

- (void)enumerateAttachedButtons:(NSArray<MMAttachedTabBarButton *> *)buttons inRange:(NSRange)range withOptions:(MMAttachedButtonsEnumerationOptions)opts usingBlock:(void (^)(MMAttachedTabBarButton *aButton, NSUInteger idx, MMAttachedTabBarButton *previousButton, MMAttachedTabBarButton *nextButton, BOOL *stop))block {

    NSUInteger numberOfButtons = buttons.count;
    
        // range check
    if (NSMaxRange(range) >= numberOfButtons)
        range.length = numberOfButtons - range.location;

	NSTabViewItem *selectedTabViewItem = _tabView.selectedTabViewItem;
    
    __block MMAttachedTabBarButton *prevButton = nil;
    
    [buttons enumerateObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range] options:0 usingBlock:^(MMAttachedTabBarButton *aButton, NSUInteger idx, BOOL *stop) {
        
        MMAttachedTabBarButton *nextButton = nil;
        if (idx+1 < NSMaxRange(range))
            nextButton = buttons[idx+1];

        if (opts & MMAttachedButtonsEnumerationUpdateButtonState) {
            if ([aButton.tabViewItem isEqualTo:selectedTabViewItem])
                [aButton setState:NSOnState];
            else
                [aButton setState:NSOffState];
        }
            
        if (opts & MMAttachedButtonsEnumerationUpdateTabStateMask) {
        
            [self updateTabStateMaskOfAttachedButton:aButton atIndex:idx withPrevious:prevButton next:nextButton];
        }
        
        if (block)
            block(aButton, idx, prevButton, nextButton, stop);
        
        prevButton = aButton;
    }];
}

#pragma mark -
#pragma mark Find Tab Bar Buttons

- (MMTabBarButton *)tabBarButtonAtPoint:(NSPoint)point
{
    if (self.orientation == MMTabBarHorizontalOrientation &&
        !NSPointInRect(point, self.genericButtonRect)) {
        return nil;
    }
    
    if (!self.superview)
        return nil;
    
        // convert to coos of superview
    point = [self convertPoint:point toView:self.superview];
    
    NSView *viewUnderMouse = [self hitTest:point];
    if (!viewUnderMouse)
        return nil;
        
    if (![viewUnderMouse isKindOfClass:MMTabBarButton.class]) {
        viewUnderMouse = viewUnderMouse.enclosingTabBarButton;
        if (!viewUnderMouse)
            return nil;
    }
    
    return (MMTabBarButton *)viewUnderMouse;
}

#pragma mark -
#pragma mark Control Configuration

- (id <MMTabStyle>)style {
	return _style;
}

- (void)setStyle:(id <MMTabStyle>)newStyle {
	if (_style != newStyle) {
		_style = newStyle;

        if ([newStyle respondsToSelector:@selector(needsResizeTabsToFitTotalWidth)])
            self.resizeTabsToFitTotalWidth = newStyle.needsResizeTabsToFitTotalWidth;
        else
            self.resizeTabsToFitTotalWidth = NO;
        
            // assure that orientation is valid
        if (![self supportsOrientation:MMTabBarHorizontalOrientation] && _orientation == MMTabBarHorizontalOrientation)
            [self setOrientation:MMTabBarVerticalOrientation];
        if (![self supportsOrientation:MMTabBarVerticalOrientation] && _orientation == MMTabBarVerticalOrientation)
            [self setOrientation:MMTabBarHorizontalOrientation];

            // update buttons
        [self _updateAddTabButton];
        [self _updateOverflowPopUpButton];

            // set style of attached buttons
        [self.attachedButtons makeObjectsPerformSelector:@selector(setStyle:) withObject:_style];
        
        [self invalidateIntrinsicContentSize];
        
		[self update:NO];
	}
}

- (NSString *)styleName {
	return _style.name;
}

- (void)setStyleNamed:(NSString *)name {

    Class <MMTabStyle> styleClass = [self.class registeredClassForStyleName:name];
    if (styleClass == NULL)
        return;

    id <MMTabStyle> newStyle = (id <MMTabStyle>) [(NSObject*) [(Class)styleClass alloc] init];
	[self setStyle:newStyle];
}

- (MMTabBarOrientation)orientation {
	return _orientation;
}

- (void)setOrientation:(MMTabBarOrientation)value {
	MMTabBarOrientation lastOrientation = _orientation;
	_orientation = value;

	if (_tabBarWidth < 10) {
		_tabBarWidth = 120;
	}

	if (lastOrientation != _orientation) {
		[self update:NO];
	}
}

- (BOOL)onlyShowCloseOnHover {
	return _onlyShowCloseOnHover;
}

- (void)setOnlyShowCloseOnHover:(BOOL)value {
	_onlyShowCloseOnHover = value;
    
    [self setNeedsUpdate:YES];
}

- (BOOL)canCloseOnlyTab {
	return _canCloseOnlyTab;
}

- (void)setCanCloseOnlyTab:(BOOL)value {
	_canCloseOnlyTab = value;
    
	if (self.numberOfAttachedButtons == 1) {
        [self setNeedsUpdate:YES];
	}
}

- (BOOL)disableTabClose {
	return _disableTabClose;
}

- (void)setDisableTabClose:(BOOL)value {
	_disableTabClose = value;
    
    [self setNeedsUpdate:YES];
}

- (BOOL)hideForSingleTab {
	return _hideForSingleTab;
}

- (void)setHideForSingleTab:(BOOL)value {
	_hideForSingleTab = value;
    
    [self setNeedsUpdate:YES];
}

- (BOOL)showAddTabButton {
	return _showAddTabButton;
}

- (void)setShowAddTabButton:(BOOL)value {
	_showAddTabButton = value;
    
    [self setNeedsUpdate:YES];
}

- (NSInteger)buttonMinWidth {
	return _buttonMinWidth;
}

- (void)setButtonMinWidth:(NSInteger)value {
	_buttonMinWidth = value;
    [self setNeedsUpdate:YES];
}

- (NSInteger)buttonMaxWidth {
	return _buttonMaxWidth;
}

- (void)setButtonMaxWidth:(NSInteger)value {
	_buttonMaxWidth = value;
    [self setNeedsUpdate:YES];
}

- (NSInteger)buttonOptimumWidth {
	return _buttonOptimumWidth;
}

- (void)setButtonOptimumWidth:(NSInteger)value {
	_buttonOptimumWidth = value;
    [self setNeedsUpdate:YES];
}

- (BOOL)sizeButtonsToFit {
	return _sizeButtonsToFit;
}

- (void)setSizeButtonsToFit:(BOOL)value {
	_sizeButtonsToFit = value;
    [self setNeedsUpdate:YES];
}

- (BOOL)useOverflowMenu {
	return _useOverflowMenu;
}

- (void)setUseOverflowMenu:(BOOL)value {
	_useOverflowMenu = value;
    [self setNeedsUpdate:YES];
}

- (BOOL)allowsBackgroundTabClosing {
	return _allowsBackgroundTabClosing;
}

- (void)setAllowsBackgroundTabClosing:(BOOL)value {
	_allowsBackgroundTabClosing = value;
    [self setNeedsUpdate:YES];
}

- (BOOL)allowsResizing {
	return _allowsResizing;
}

- (void)setAllowsResizing:(BOOL)value {
	_allowsResizing = value;
}

- (BOOL)selectsTabsOnMouseDown {
	return _selectsTabsOnMouseDown;
}

- (void)setSelectsTabsOnMouseDown:(BOOL)value {
	_selectsTabsOnMouseDown = value;
}

- (BOOL)automaticallyAnimates {
	return _automaticallyAnimates;
}

- (void)setAutomaticallyAnimates:(BOOL)value {
	_automaticallyAnimates = value;
}

- (BOOL)alwaysShowActiveTab {
	return _alwaysShowActiveTab;
}

- (void)setAlwaysShowActiveTab:(BOOL)value {
	_alwaysShowActiveTab = value;
}

- (BOOL)allowsScrubbing {
	return _allowsScrubbing;
}

- (void)setAllowsScrubbing:(BOOL)flag {
	_allowsScrubbing = flag;
    
    for (MMAttachedTabBarButton *aButton in self.attachedButtons) {
        [aButton setSimulateClickOnMouseHovered:flag];
    }
}

- (MMTabBarTearOffStyle)tearOffStyle {
	return _tearOffStyle;
}

- (void)setTearOffStyle:(MMTabBarTearOffStyle)tearOffStyle {
	_tearOffStyle = tearOffStyle;
}

#pragma mark -
#pragma mark Accessors

- (nullable id <MMTabBarViewDelegate>)delegate {
	return _delegate;
}

- (void)setDelegate:(nullable id <MMTabBarViewDelegate> )object {
	_delegate = object;

	NSMutableArray<NSPasteboardType> *types = [NSMutableArray arrayWithObject:AttachedTabBarButtonUTI];

        //Update the allowed drag types
	if (_delegate && [_delegate respondsToSelector:@selector(allowedDraggedTypesForTabView:)]) {
		[types addObjectsFromArray:[_delegate allowedDraggedTypesForTabView:_tabView]];
	}
    
	[self unregisterDraggedTypes];
	[self registerForDraggedTypes:types];
}

- (NSTabView *)tabView {
    @synchronized(self) {
        return _tabView;
    }
}

- (void)setTabView:(NSTabView *)view {

    @synchronized(self) {

        if (view == _tabView)
            return;
            
        if (_tabView) {
            _tabView = nil;
        }
        
        _tabView = view;
        
        // build buttons from existing tab view items
        for (NSTabViewItem *item in _tabView.tabViewItems) {
            if (![self.visibleTabViewItems containsObject:item]) {
                [self addAttachedButtonForTabViewItem:item];
            }
        }
    }
}

- (CGFloat)heightOfTabBarButtons
{
    if ([_style respondsToSelector:@selector(heightOfTabBarButtonsForTabBarView:)])
        return [_style heightOfTabBarButtonsForTabBarView:self];
    
    return self._heightOfTabBarButtons;
}

- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation {
    if ([_style respondsToSelector:@selector(supportsOrientation:forTabBarView:)])
        return [_style supportsOrientation:orientation forTabBarView:self];
    
    return [self _supportsOrientation:orientation];
}

#pragma mark -
#pragma mark Visibility

- (BOOL)isOverflowButtonVisible {
    if (_overflowPopUpButton.frame.size.width != 0.0 && _overflowPopUpButton.frame.size.height != 0.0 && !_overflowPopUpButton.isHidden)
        return YES;

    return NO;
}

#pragma mark -
#pragma mark Resizing

- (NSRect)dividerRect {

    if (self.orientation == MMTabBarHorizontalOrientation || !self.allowsResizing)
        return NSZeroRect;

    NSRect bounds = self.bounds;
    NSRect tabViewFrame = _tabView.frame;
    return NSMakeRect(bounds.size.width - DIVIDER_WIDTH, 0, DIVIDER_WIDTH, tabViewFrame.size.height);
}

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context {

    // did the tab's identifier change?
    if ([keyPath isEqualToString:@"identifier"]) {
//        id oldIdentifier = [change objectForKey: NSKeyValueChangeOldKey];
		NSTabViewItem* const tabViewItem = object;
		if (object != nil) {
				// update binding
			MMAttachedTabBarButton* const button = [self attachedButtonForTabViewItem:tabViewItem];
			if (button != nil) {
				[self _unbindPropertiesOfAttachedButton:button];
				[self _bindPropertiesOfAttachedButton:button andTabViewItem:tabViewItem];
			}
		}
    } else if (object == self.window && [keyPath isEqualToString:@"toolbar.visible"]) {
    
        [self update:NO];
    
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -
#pragma mark Hide/Show Tab Bar Control

- (void)hideTabBar:(BOOL)hide animate:(BOOL)animate {

    if ((_isHidden && hide) || (!_isHidden && !hide)) {
		return;
	}
    
    _isHidden = hide;

    CGFloat partnerOriginalSize, partnerOriginalOrigin, myOriginalSize, myOriginalOrigin, partnerTargetSize, partnerTargetOrigin;

        // target values for partner
	if (self.orientation == MMTabBarHorizontalOrientation) {
		CGFloat tabBarViewHeight = kMMTabBarViewHeight;
		if ([_style respondsToSelector:@selector(intrinsicContentSizeOfTabBarView:)])	// don't call self.intrinsicContentSize, as it would return 0 when hidden
			tabBarViewHeight=[_style intrinsicContentSizeOfTabBarView:self].height;
            // current (original) values
		myOriginalSize = self.frame.size.height;
		myOriginalOrigin = self.frame.origin.y;
		if (_partnerView) {
			partnerOriginalSize = _partnerView.frame.size.height;
			partnerOriginalOrigin = _partnerView.frame.origin.y;
		} else {
			partnerOriginalSize = self.window.frame.size.height;
			partnerOriginalOrigin = self.window.frame.origin.y;
		}

		if (_partnerView) {
                // above or below me?
			if ((myOriginalOrigin - tabBarViewHeight) > partnerOriginalOrigin) {
                    // partner is below me
				if (_isHidden) {
                        // I'm shrinking
					partnerTargetOrigin = partnerOriginalOrigin;
					partnerTargetSize = partnerOriginalSize + tabBarViewHeight;
				} else {
                        // I'm growing
					partnerTargetOrigin = partnerOriginalOrigin;
					partnerTargetSize = partnerOriginalSize - tabBarViewHeight;
				}
			} else {
				// partner is above me
				if (_isHidden) {
                        // I'm shrinking
					partnerTargetOrigin = partnerOriginalOrigin - tabBarViewHeight;
					partnerTargetSize = partnerOriginalSize + tabBarViewHeight;
				} else {
                        // I'm growing
					partnerTargetOrigin = partnerOriginalOrigin + tabBarViewHeight;
					partnerTargetSize = partnerOriginalSize - tabBarViewHeight;
				}
			}
		} else {
			// for window movement
			if (_isHidden) {
                    // I'm shrinking
				partnerTargetOrigin = partnerOriginalOrigin + tabBarViewHeight;
				partnerTargetSize = partnerOriginalSize - tabBarViewHeight;
			} else {
                    // I'm growing
				partnerTargetOrigin = partnerOriginalOrigin - tabBarViewHeight;
				partnerTargetSize = partnerOriginalSize + tabBarViewHeight;
			}
		}
	} else {   // vertical 
            // current (original) values
		myOriginalSize = self.frame.size.width;
		myOriginalOrigin = self.frame.origin.x;
		if (_partnerView) {
			partnerOriginalSize = _partnerView.frame.size.width;
			partnerOriginalOrigin = _partnerView.frame.origin.x;
		} else {
			partnerOriginalSize = self.window.frame.size.width;
			partnerOriginalOrigin = self.window.frame.origin.x;
		}

		if (_partnerView) {
			//to the left or right?
			if (myOriginalOrigin < partnerOriginalOrigin + partnerOriginalSize) {
				// partner is to the left
				if (_isHidden) {
					// I'm shrinking
					partnerTargetOrigin = partnerOriginalOrigin - myOriginalSize;
					partnerTargetSize = partnerOriginalSize + myOriginalSize;
					_tabBarWidth = myOriginalSize;
				} else {
					// I'm growing
					partnerTargetOrigin = partnerOriginalOrigin + _tabBarWidth;
					partnerTargetSize = partnerOriginalSize - _tabBarWidth;
				}
			} else {
				// partner is to the right
				if (_isHidden) {
					// I'm shrinking
					partnerTargetOrigin = partnerOriginalOrigin;
					partnerTargetSize = partnerOriginalSize + myOriginalSize;
					_tabBarWidth = myOriginalSize;
				} else {
					// I'm growing
					partnerTargetOrigin = partnerOriginalOrigin;
					partnerTargetSize = partnerOriginalSize - _tabBarWidth;
				}
			}
		} else {
			// for window movement
			if (_isHidden) {
				// I'm shrinking
				partnerTargetOrigin = partnerOriginalOrigin + myOriginalSize;
				partnerTargetSize = partnerOriginalSize - myOriginalSize;
				_tabBarWidth = myOriginalSize;
			} else {
				// I'm growing
				partnerTargetOrigin = partnerOriginalOrigin - _tabBarWidth;
				partnerTargetSize = partnerOriginalSize + _tabBarWidth;
			}
		}
	}
}

- (void)applyFrameChangesAnimated:(BOOL)animate hide:(BOOL)hide partnerTargetOrigin:(CGFloat)partnerTargetOrigin partnerTargetSize:(CGFloat)partnerTargetSize completion:(void(^)(void))completion {

	if (_partnerView) {
		// resize self and view
		NSRect newPartnerViewFrame;
		if (self.orientation == MMTabBarHorizontalOrientation) {
			newPartnerViewFrame = NSMakeRect(_partnerView.frame.origin.x, partnerTargetOrigin, _partnerView.frame.size.width, partnerTargetSize);
		} else {
			newPartnerViewFrame = NSMakeRect(partnerTargetOrigin, _partnerView.frame.origin.y, partnerTargetSize, _partnerView.frame.size.height);
		}

		if (animate) {

            void (^animateAlongside)(void);
			if (hide && [_delegate respondsToSelector:@selector(animateAlongsideTabBarHide)]) {
				animateAlongside = [_delegate animateAlongsideTabBarHide];
			}
			else if (!hide && [_delegate respondsToSelector:@selector(animateAlongsideTabBarShow)]) {
				animateAlongside = [_delegate animateAlongsideTabBarShow];
			}

			[NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
				context.duration = 0.1;
				context.allowsImplicitAnimation = YES;
				[self invalidateIntrinsicContentSize];
				[self.superview layoutSubtreeIfNeeded];
				self.partnerView.animator.frame = newPartnerViewFrame;
				if (animateAlongside) {
					animateAlongside();
				}
			} completionHandler:completion];
		} else {
			[_partnerView setFrame:newPartnerViewFrame];
			[self invalidateIntrinsicContentSize];
			[self.superview setNeedsLayout: YES];
			completion();
		}
	} else {
		// resize self and window
		NSRect newWindowFrame;
		if (self.orientation == MMTabBarHorizontalOrientation) {
			newWindowFrame = NSMakeRect(self.window.frame.origin.x, partnerTargetOrigin, self.window.frame.size.width, partnerTargetSize);
		} else {
			newWindowFrame = NSMakeRect(partnerTargetOrigin, self.window.frame.origin.y, partnerTargetSize, self.window.frame.size.height);
		}
		[[self window] setFrame:newWindowFrame display:YES];
		completion();
	}
}

- (void) sendTabBarShowHideCompletionCalls:(BOOL)isHidden {
	if (isHidden) {
		if ([_delegate respondsToSelector:@selector(tabView:tabBarViewDidHide:)]) {
			[_delegate tabView:self.tabView tabBarViewDidHide:self];
		}
	} else {
		if ([_delegate respondsToSelector:@selector(tabView:tabBarViewDidUnhide:)]) {
			[_delegate tabView:self.tabView tabBarViewDidUnhide:self];
		}
	}
}

- (BOOL)isTabBarHidden {
	return _isHidden;
}

- (BOOL)isAnimating {
	return _slideButtonsAnimation != nil;
}

#pragma mark -
#pragma mark Determining Sizes

- (NSSize)addTabButtonSize {
    NSSize theSize;

    if ([_style respondsToSelector:@selector(addTabButtonSizeForTabBarView:)]) {
        theSize = [_style addTabButtonSizeForTabBarView:self];

    } else {
        theSize = self._addTabButtonSize;
    }
    return theSize;
}

- (NSRect)addTabButtonRect {
    
    NSRect theRect;
    
    if ([_style respondsToSelector:@selector(addTabButtonRectForTabBarView:)]) {
        theRect = [_style addTabButtonRectForTabBarView:self];
    } else {
        theRect = self._addTabButtonRect;
    }

    return theRect;
}

- (NSSize)overflowButtonSize {

    NSSize theSize;

    if ([_style respondsToSelector:@selector(overflowButtonSizeForTabBarView:)]) {
        theSize = [_style overflowButtonSizeForTabBarView:self];
    } else {
        theSize = self._overflowButtonSize;
    }

    return theSize;
}

- (NSRect)overflowButtonRect {

    NSRect theRect;
    
    if ([_style respondsToSelector:@selector(overflowButtonRectForTabBarView:)]) {
        theRect = [_style overflowButtonRectForTabBarView:self];
    } else {
        theRect = self._overflowButtonRect;
    }

    return theRect;
}

#pragma mark -
#pragma mark Determining Margins

- (CGFloat)rightMargin {
    CGFloat margin = 0.0;
    
    if ([_style respondsToSelector:@selector(rightMarginForTabBarView:)]) {
        margin = [_style rightMarginForTabBarView:self];
    } else {
        margin = self._rightMargin;
    }

    return margin;
}

- (CGFloat)leftMargin {
    CGFloat margin = 0.0;
    
    if ([_style respondsToSelector:@selector(leftMarginForTabBarView:)]) {
        margin = [_style leftMarginForTabBarView:self];
    } else {
        margin = self._leftMargin;
    }

    return margin;
}

- (CGFloat)topMargin {
    CGFloat margin = 0.0;
    
    if ([_style respondsToSelector:@selector(topMarginForTabBarView:)]) {
        margin = [_style topMarginForTabBarView:self];
    } else {
        margin = self._topMargin;
    }

    return margin;
}

- (CGFloat)bottomMargin {
    CGFloat margin = 0.0;
    
    if ([_style respondsToSelector:@selector(bottomMarginForTabBarView:)]) {
        margin = [_style bottomMarginForTabBarView:self];
    } else {
        margin = self._bottomMargin;
    }

    return margin;
}

#pragma mark -
#pragma mark Layout Buttons

- (void)layoutButtons {
    [_controller layoutButtons];
    
    if (!self.isDragging)
        [self _synchronizeSelection];
}

- (BOOL)needsUpdate {

    @synchronized(self) {
        return _needsUpdate;
    }
}

- (void)setNeedsUpdate:(BOOL)newState {

    @synchronized(self) {
    
        if (!newState)
            {
            _needsUpdate = NO;
            return;
            }
        
            // update already scheduled? -> do not schedule again
        if (_needsUpdate)
            return;
        
        _needsUpdate = YES;
        [NSOperationQueue.mainQueue addOperationWithBlock:
            ^{
            [self update];
            }];
    }
}

- (void)update {

    if (!_needsUpdate) {
        return;
    }

    _needsUpdate = NO;

    if (!self.window.isVisible)
        [self update:NO];
    else
        [self update:_automaticallyAnimates];
}

- (void)update:(BOOL)animate {
    
        // not currently handle draggig?
    if (MMTabDragAssistant.sharedDragAssistant.isDragging == NO) {

            // hide/show? (these return if already in desired state)
        if (self._shouldDisplayTabBar)
            [self hideTabBar:NO animate:animate];
        else if (!self._shouldDisplayTabBar) {
            [self hideTabBar:YES animate:animate];
            animate = NO;
        }
    }

	NSArray<__kindof NSTabViewItem *> *tabItems = _tabView.tabViewItems;
        // go through buttons, remove any whose tab view items are not in [_tabView tabViewItems]
    NSSet<MMAttachedTabBarButton *> *attachedButtons = self.attachedButtons;
    for (MMAttachedTabBarButton *aButton in attachedButtons) {
        //remove the observer binding
		if (aButton.tabViewItem && ![tabItems containsObject:aButton.tabViewItem]) {
			if ([self.delegate respondsToSelector:@selector(tabView:didDetachTabViewItem:)]) {
				[self.delegate tabView:_tabView didDetachTabViewItem:aButton.tabViewItem];
			}

			[self removeAttachedButton:aButton];
		}
	}

    BOOL isDragging = MMTabDragAssistant.sharedDragAssistant.isDragging;
    MMAttachedTabBarButton *draggedButton = MMTabDragAssistant.sharedDragAssistant.attachedTabBarButton;

        // go through tab view items, add button for any not present
	NSArray<NSTabViewItem*> *visibleTabViewItems = self.visibleTabViewItems;
    NSUInteger i = 0;
    for (NSTabViewItem *item in tabItems) {
		if (![visibleTabViewItems containsObject:item]) {
        
            if (!(isDragging && item == draggedButton.tabViewItem))
                [self insertAttachedButtonForTabViewItem:item atIndex:i];
		}
        ++i;
	}
    
	[self layoutButtons]; //eventually we should only have to call this when we know something has changed

	NSMenu *overflowMenu = _controller.overflowMenu;
	[_overflowPopUpButton setHidden:(overflowMenu == nil)];
	[_overflowPopUpButton setMenu:overflowMenu];
    [self _positionOverflowMenu];

	if (animate) {
    
            // assure that pending animation will stop
        if (_slideButtonsAnimation) {
            [_slideButtonsAnimation stopAnimation];
        }
        
            // start new animation
        _slideButtonsAnimation = [[MMSlideButtonsAnimation alloc] initWithTabBarButtons:self.attachedButtons];
        
        if (_showAddTabButton) {
			NSDictionary<NSViewAnimationKey, id>* const addButtonAnimDict = @{
				NSViewAnimationTargetKey: _addTabButton,
				NSViewAnimationStartFrameKey: [NSValue valueWithRect:_addTabButton.frame],
				NSViewAnimationEndFrameKey: [NSValue valueWithRect:self.addTabButtonRect]
			};
            [_slideButtonsAnimation addAnimationDictionary:addButtonAnimDict];
        } else {
            [self _positionAddTabButton];
        }
        
        [_slideButtonsAnimation setDelegate:self];
        [_slideButtonsAnimation startAnimation];
      
	} else {
    
        for (MMAttachedTabBarButton *aButton in self.attachedButtons)
            [aButton setFrame:aButton.stackingFrame];

        [self _positionAddTabButton];

        [self updateTrackingAreas];
		[self setNeedsDisplay:YES];
	}
    
    [self setNeedsUpdate:NO];
}

#pragma mark -
#pragma mark Interface to Dragging Assistant

- (BOOL)shouldStartDraggingAttachedTabBarButton:(MMAttachedTabBarButton *)aButton withMouseDownEvent:(NSEvent *)event {

        // ask delegate 
    if (_delegate && [_delegate respondsToSelector:@selector(tabView:shouldDragTabViewItem:inTabBarView:)]) {
        if (![_delegate tabView:_tabView shouldDragTabViewItem:aButton.tabViewItem inTabBarView:self])
            return NO;
    }
    
    return [MMTabDragAssistant.sharedDragAssistant shouldStartDraggingAttachedTabBarButton:aButton ofTabBarView:self withMouseDownEvent:event];
}

- (void)startDraggingAttachedTabBarButton:(MMAttachedTabBarButton *)aButton withMouseDownEvent:(NSEvent *)theEvent {
    [MMTabDragAssistant.sharedDragAssistant startDraggingAttachedTabBarButton:aButton fromTabBarView:self withMouseDownEvent:theEvent];
}

- (nullable MMAttachedTabBarButton *)attachedTabBarButtonForDraggedItems {
    return MMTabDragAssistant.sharedDragAssistant.attachedTabBarButton;
}

- (BOOL)isSliding {
    return MMTabDragAssistant.sharedDragAssistant.isSliding;
}

- (BOOL)isDragging {
    return MMTabDragAssistant.sharedDragAssistant.isDragging;
}

#pragma mark -
#pragma mark NSDraggingSource

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
	return [MMTabDragAssistant.sharedDragAssistant draggingSession:session sourceOperationMaskForDraggingContext:context ofTabBarView:self];
}

- (BOOL)ignoreModifierKeysForDraggingSession:(NSDraggingSession *)session {
	return YES;
}

- (void)draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint {
    [MMTabDragAssistant.sharedDragAssistant draggingSession:session willBeginAtPoint:screenPoint withTabBarView:self];
}

- (void)draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint {
    [MMTabDragAssistant.sharedDragAssistant draggingSession:session movedToPoint:screenPoint];
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	[MMTabDragAssistant.sharedDragAssistant draggingSession:session endedAtPoint:screenPoint operation:operation];
}

#pragma mark -
#pragma mark NSDraggingDestination

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {

    NSDragOperation dragOp = NSDragOperationNone;

    NSPasteboard *pb = sender.draggingPasteboard;
    
    if ([pb canReadItemWithDataConformingToTypes:@[AttachedTabBarButtonUTI]]) {
    
        MMTabDragAssistant *dragAssistant = MMTabDragAssistant.sharedDragAssistant;
        
        dragOp = [dragAssistant draggingEntered:sender inTabBarView:self];
    }

	return dragOp;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {

    NSPasteboard *pb = sender.draggingPasteboard;
    
    if ([pb canReadItemWithDataConformingToTypes:@[AttachedTabBarButtonUTI]]) {
        
        MMTabDragAssistant *dragAssistant = MMTabDragAssistant.sharedDragAssistant;
        return [dragAssistant draggingUpdated:sender inTabBarView:self];
         
    }

		//something that was accepted by the delegate was dragged on

	NSPoint aPoint = [self convertPoint:sender.draggingLocation fromView:nil];

	MMAttachedTabBarButton *destinationButton = (MMAttachedTabBarButton *)[self tabBarButtonAtPoint:aPoint];
	if (![destinationButton isKindOfClass:MMAttachedTabBarButton.class])
		return NSDragOperationNone;

	//Wind the spring for a spring-loaded drop.
	//The delay time comes from Finder's defaults, which specifies it in milliseconds.
	//If the delegate can't handle our spring-loaded drop, we'll abort it when the timer fires. See fireSpring:. This is simpler than constantly (checking for spring-loaded awareness and tearing down/rebuilding the timer) at every delegate change.

		//If the user has dragged to a different tab, reset the timer.
	if (_tabViewItemWithSpring != destinationButton.tabViewItem) {
		[_springTimer invalidate];
		 _springTimer = nil;
		_tabViewItemWithSpring = destinationButton.tabViewItem;
	}
	if (!_springTimer) {
			//Finder's default delay time, as of Tiger, is 668 ms. If the user has never changed it, there's no setting in its defaults, so we default to that amount.
		NSNumber *delayNumber = (NSNumber *)CFBridgingRelease(CFPreferencesCopyAppValue((CFStringRef)@"SpringingDelayMilliseconds", (CFStringRef)@"com.apple.finder"));
		NSTimeInterval delaySeconds = delayNumber ? delayNumber.doubleValue / 1000.0 : 0.668;
		_springTimer = [NSTimer scheduledTimerWithTimeInterval:delaySeconds
						 target:self
						 selector:@selector(fireSpring:)
						 userInfo:sender
						 repeats:NO];
	}
	return NSDragOperationCopy;
}

- (void)draggingExited:(nullable id <NSDraggingInfo>)sender {
	[_springTimer invalidate];
	 _springTimer = nil;

	id <NSDraggingInfo> const draggingInfo = sender;
	if (draggingInfo != nil) {
		[MMTabDragAssistant.sharedDragAssistant draggingExitedTabBarView:self draggingInfo:draggingInfo];
	}
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {

    NSPasteboard *pb = sender.draggingPasteboard;

        //validate the drag operation only if there's a valid tab bar to drop into    
    if (![pb canReadItemWithDataConformingToTypes:@[AttachedTabBarButtonUTI]])
        return NO;
    
    if (!MMTabDragAssistant.sharedDragAssistant.destinationTabBar)
        return NO;
        
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {

    MMTabDragAssistant *dragAssistant = MMTabDragAssistant.sharedDragAssistant;
        
    if (![dragAssistant performDragOperation:sender forTabBarView:self]) {

        NSPoint aPoint = [self convertPoint:sender.draggingLocation fromView:nil];
        MMTabBarButton *tabBarButton = [self tabBarButtonAtPoint:aPoint];
        if (![tabBarButton isKindOfClass:MMAttachedTabBarButton.class])
            return NO;
        
        id <MMTabBarViewDelegate> myDelegate = self.delegate;
        if (myDelegate && [myDelegate respondsToSelector:@selector(tabView:acceptedDraggingInfo:onTabViewItem:)]) {
                
                //forward the drop to the delegate
            return [myDelegate tabView:_tabView acceptedDraggingInfo:sender onTabViewItem:[(MMAttachedTabBarButton *)tabBarButton tabViewItem]];
        }
            
    }

    return NO;
}

- (void)concludeDragOperation:(nullable id <NSDraggingInfo>)sender {
    // nothing yet
}

#pragma mark -
#pragma mark Tab Button Menu Support

- (NSMenu *)menuForTabBarButton:(MMTabBarButton *)aButton withEvent:(NSEvent *)anEvent {

    NSMenu *menu = nil;
    
    if ([aButton isKindOfClass:MMAttachedTabBarButton.class]) {
    
        NSTabViewItem *tabViewItem = [(MMAttachedTabBarButton *)aButton tabViewItem];
        if (tabViewItem) {
            return [self menuForTabViewItem:tabViewItem withEvent:anEvent];
        }
    } else {
        // none yet (we should add another optional delegate method in the future)
    }
    
    return menu;
}

- (NSMenu *)menuForTabViewItem:(NSTabViewItem *)aTabViewItem withEvent:(NSEvent *)anEvent {
	NSMenu *menu = nil;

	if (aTabViewItem && [self.delegate respondsToSelector:@selector(tabView:menuForTabViewItem:)]) {
		menu = [self.delegate tabView:_tabView menuForTabViewItem:aTabViewItem];
	}
	return menu;
}

#pragma mark -
#pragma mark Convenience

- (void)bindPropertiesOfAttachedButton:(MMAttachedTabBarButton *)aButton andTabViewItem:(NSTabViewItem *)item {
	[self _bindPropertiesOfAttachedButton:aButton andTabViewItem:item];

        // watch for changes in the identifier
	[item addObserver:self forKeyPath:@"identifier" options:NSKeyValueObservingOptionOld context:nil];
}

- (void)unbindPropertiesOfAttachedButton:(MMAttachedTabBarButton *)aButton {

    NSTabViewItem *item = aButton.tabViewItem;
    if (!item)
        return;

        // watch for changes in the identifier
    [item removeObserver:self forKeyPath:@"identifier"];

	[self _unbindPropertiesOfAttachedButton:aButton];
}

#pragma mark -
#pragma mark Drawing

- (BOOL)isFlipped {
	return YES;
}

- (void)drawRect:(NSRect)rect {

    if ([_style respondsToSelector:@selector(drawTabBarView:inRect:)]) {
        [_style drawTabBarView:self inRect:rect];
    } else {
        [self _drawTabBarViewInRect:rect];
    }
}

- (void)drawBezelInRect:(NSRect)rect {

    if ([_style respondsToSelector:@selector(drawBezelOfTabBarView:inRect:)]) {
        [_style drawBezelOfTabBarView:self inRect:rect];
    } else {
        [self _drawBezelInRect:rect];
    }    
}

- (void)drawButtonBezelsInRect:(NSRect)rect {

    if ([_style respondsToSelector:@selector(drawButtonBezelsOfTabBarView:inRect:)]) {
        [_style drawButtonBezelsOfTabBarView:self inRect:rect];
    } else {
        [self _drawButtonBezelsInRect:rect];
    }    
}

- (void)drawBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray<MMAttachedTabBarButton *> *)buttons indexOfSelectedButton:(NSUInteger)selIndex inRect:(NSRect)rect {

    if ([_style respondsToSelector:@selector(drawBezelOfButton:atIndex:inButtons:indexOfSelectedButton:tabBarView:inRect:)]) {
        [_style drawBezelOfButton:button atIndex:index inButtons:buttons indexOfSelectedButton:selIndex tabBarView:self inRect:rect];
    } else {
        [self _drawBezelOfButton:button atIndex:index inButtons:buttons indexOfSelectedButton:selIndex inRect:rect];
    }
}

- (void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton inRect:(NSRect)rect {
    if ([_style respondsToSelector:@selector(drawBezelOfOverflowButton:ofTabBarView:inRect:)]) {
        [_style drawBezelOfOverflowButton:overflowButton ofTabBarView:self inRect:rect];
    } else {
        [self _drawBezelOfOverflowButton:overflowButton inRect:rect];
    }  
}

- (void)drawInteriorInRect:(NSRect)rect {
    if ([_style respondsToSelector:@selector(drawInteriorOfTabBarView:inRect:)]) {
        [_style drawInteriorOfTabBarView:self inRect:rect];
    } else {
        [self _drawInteriorInRect:rect];
    }
}

#pragma mark -
#pragma mark Mouse Tracking

- (nullable NSView *)hitTest:(NSPoint)aPoint {

    if (self.orientation == MMTabBarVerticalOrientation) {
        NSView *superview = self.superview;
        if (superview) {
            NSRect dividerRect = self.dividerRect;
            dividerRect = [self convertRect:dividerRect toView:superview];
            
            if (NSPointInRect(aPoint, dividerRect)) {
                return self;
            }
        }
    }
    
    return [super hitTest:aPoint];
}

- (BOOL)mouseDownCanMoveWindow {
	return NO;
}

- (BOOL)acceptsFirstMouse:(nullable NSEvent *)theEvent {
	return YES;
}

- (BOOL)acceptsFirstResponder {
    return NO;
}

- (void)mouseDown:(NSEvent *)theEvent {

	NSPoint mousePt = [self convertPoint:theEvent.locationInWindow fromView:nil];
	NSRect frame = self.frame;

        // begin resizing if appropriate
    if (self.orientation == MMTabBarVerticalOrientation && self.allowsResizing && (mousePt.x > frame.size.width - 3)) {
        if ([self mm_dragShouldBeginFromMouseDown:theEvent withExpiration:NSDate.distantFuture xHysteresis:0.0 yHysteresis:0]) {
            [self _beginResizingWithMouseDownEvent:theEvent];
        }
    }
}

#pragma mark -
#pragma mark Spring-loading

- (void)fireSpring:(NSTimer *)timer {

    NSAssert1(timer == _springTimer, @"Spring fired by unrecognized timer %@", timer);

    id <NSDraggingInfo> sender = timer.userInfo;
    
    NSPoint aPoint = [self convertPoint:sender.draggingLocation fromView:nil];
    MMAttachedTabBarButton *button = [self attachedButtonAtPoint:aPoint];
    if (button != nil) {
        [_tabView selectTabViewItem:button.tabViewItem];

        _tabViewItemWithSpring = nil;
        [_springTimer invalidate];
         _springTimer = nil;
    }
}

#pragma mark -
#pragma mark Menu Validation

- (BOOL)validateMenuItem:(NSMenuItem *)sender {
	NSMenuItem* const menuItem = sender;
	if (menuItem == nil) {
		return NO;
	}
	NSTabViewItem* const tabViewItem = menuItem.representedObject;
	if (tabViewItem == nil) {
		return NO;
	}
	[sender setState:([tabViewItem isEqualTo:_tabView.selectedTabViewItem]) ? NSOnState : NSOffState];

	return [self.delegate respondsToSelector:@selector(tabView:validateOverflowMenuItem:forTabViewItem:)] ?
		   [self.delegate tabView:self.tabView validateOverflowMenuItem:menuItem forTabViewItem:tabViewItem] : YES;
}

#pragma mark -
#pragma mark NSTabViewDelegate

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {

    [self _synchronizeSelection];
    
	if ([self.delegate respondsToSelector:@selector(tabView:didSelectTabViewItem:)]) {
		[self.delegate performSelector:@selector(tabView:didSelectTabViewItem:) withObject:aTabView withObject:tabViewItem];
    }
}

- (BOOL)tabView:(NSTabView *)aTabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	if ([self.delegate respondsToSelector:@selector(tabView:shouldSelectTabViewItem:)]) {
		return [self.delegate tabView:aTabView shouldSelectTabViewItem:tabViewItem];
	} else {
		return YES;
	}
}

- (void)tabView:(NSTabView *)aTabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	if ([self.delegate respondsToSelector:@selector(tabView:willSelectTabViewItem:)]) {
		[self.delegate performSelector:@selector(tabView:willSelectTabViewItem:) withObject:aTabView withObject:tabViewItem];
	}
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)aTabView {

    if (_tabView != aTabView)
        return;
        
        // do nothing, if we are reordering the tab view items
    if (self.isReorderingTabViewItems)
        return;
    
    [self setNeedsUpdate:YES];

        // pass along for other delegate responses
	if ([self.delegate respondsToSelector:@selector(tabViewDidChangeNumberOfTabViewItems:)]) {
		[self.delegate performSelector:@selector(tabViewDidChangeNumberOfTabViewItems:) withObject:aTabView];
	}
}

#pragma mark -
#pragma mark NSAnimationDelegate

-(void)_finalizeAnimation:(NSAnimation *)animation {

    if (animation == _slideButtonsAnimation) {
        _slideButtonsAnimation = nil;

        [self _positionAddTabButton];
        
        [self updateTrackingAreas];
        [self setNeedsDisplay:YES];
    }
}

- (void)animationDidStop:(NSAnimation *)animation {
    [self _finalizeAnimation:animation];
}

- (void)animationDidEnd:(NSAnimation *)animation {
    [self _finalizeAnimation:animation];
}

#pragma mark -
#pragma mark Handle Window Notifications

- (void)windowDidMove:(NSNotification *)aNotification {
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder 
{
	[super encodeWithCoder:aCoder];
	if (aCoder.allowsKeyedCoding) {
		[aCoder encodeObject:_tabView forKey:@"MMtabView"];
		[aCoder encodeObject:_overflowPopUpButton forKey:@"MMOverflowPopUpButton"];
		[aCoder encodeObject:_addTabButton forKey:@"MMaddTabButton"];
		[aCoder encodeObject:_style forKey:@"MMstyle"];
		[aCoder encodeInteger:_orientation forKey:@"MMorientation"];
		[aCoder encodeBool:_onlyShowCloseOnHover forKey:@"MMonlyShowCloseOnHover"];        
		[aCoder encodeBool:_canCloseOnlyTab forKey:@"MMcanCloseOnlyTab"];
		[aCoder encodeBool:_disableTabClose forKey:@"MMdisableTabClose"];
		[aCoder encodeBool:_hideForSingleTab forKey:@"MMhideForSingleTab"];
		[aCoder encodeBool:_allowsBackgroundTabClosing forKey:@"MMallowsBackgroundTabClosing"];
		[aCoder encodeBool:_allowsResizing forKey:@"MMallowsResizing"];
		[aCoder encodeBool:_selectsTabsOnMouseDown forKey:@"MMselectsTabsOnMouseDown"];
		[aCoder encodeBool:_showAddTabButton forKey:@"MMshowAddTabButton"];
		[aCoder encodeBool:_sizeButtonsToFit forKey:@"MMsizeButtonsToFit"];
		[aCoder encodeInteger:_buttonMinWidth forKey:@"MMbuttonMinWidth"];
		[aCoder encodeInteger:_buttonMaxWidth forKey:@"MMbuttonMaxWidth"];
		[aCoder encodeInteger:_buttonOptimumWidth forKey:@"MMbuttonOptimumWidth"];
		[aCoder encodeBool:_isHidden forKey:@"MMisHidden"];
		[aCoder encodeObject:_partnerView forKey:@"MMpartnerView"];
		[aCoder encodeBool:_useOverflowMenu forKey:@"MMuseOverflowMenu"];
		[aCoder encodeBool:_automaticallyAnimates forKey:@"MMautomaticallyAnimates"];
		[aCoder encodeBool:_alwaysShowActiveTab forKey:@"MMalwaysShowActiveTab"];
	}
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {

		[self _commonInit];
        
		[self registerForDraggedTypes:@[AttachedTabBarButtonUTI]];
		
            // resize
		[self setPostsFrameChangedNotifications:YES];
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(frameDidChange:) name:NSViewFrameDidChangeNotification object:self];
        
		if (aDecoder.allowsKeyedCoding) {
			_tabView = [aDecoder decodeObjectForKey:@"MMtabView"];
			_overflowPopUpButton = [aDecoder decodeObjectForKey:@"MMOverflowPopUpButton"];
			_addTabButton = [aDecoder decodeObjectForKey:@"MMaddTabButton"];
			_style = [aDecoder decodeObjectForKey:@"MMstyle"];
			_orientation = (MMTabBarOrientation)[aDecoder decodeIntegerForKey:@"MMorientation"];
			_onlyShowCloseOnHover = [aDecoder decodeBoolForKey:@"MMonlyShowCloseOnHover"];            
			_canCloseOnlyTab = [aDecoder decodeBoolForKey:@"MMcanCloseOnlyTab"];
			_disableTabClose = [aDecoder decodeBoolForKey:@"MMdisableTabClose"];
			_hideForSingleTab = [aDecoder decodeBoolForKey:@"MMhideForSingleTab"];
			_allowsBackgroundTabClosing = [aDecoder decodeBoolForKey:@"MMallowsBackgroundTabClosing"];
			_allowsResizing = [aDecoder decodeBoolForKey:@"MMallowsResizing"];
			_selectsTabsOnMouseDown = [aDecoder decodeBoolForKey:@"MMselectsTabsOnMouseDown"];
			_showAddTabButton = [aDecoder decodeBoolForKey:@"MMshowAddTabButton"];
			_sizeButtonsToFit = [aDecoder decodeBoolForKey:@"MMsizeButtonsToFit"];
			_buttonMinWidth = [aDecoder decodeIntegerForKey:@"MMbuttonMinWidth"];
			_buttonMaxWidth = [aDecoder decodeIntegerForKey:@"MMbuttonMaxWidth"];
			_buttonOptimumWidth = [aDecoder decodeIntegerForKey:@"MMbuttonOptimumWidth"];
			_isHidden = [aDecoder decodeBoolForKey:@"MMisHidden"];
			_partnerView = [aDecoder decodeObjectForKey:@"MMpartnerView"];
			_useOverflowMenu = [aDecoder decodeBoolForKey:@"MMuseOverflowMenu"];
			_automaticallyAnimates = [aDecoder decodeBoolForKey:@"MMautomaticallyAnimates"];
			_alwaysShowActiveTab = [aDecoder decodeBoolForKey:@"MMalwaysShowActiveTab"];
		}

		if (_style == nil) {
			_style = [[MMMetalTabStyle alloc] init];
		}
	}

	return self;
}

#pragma mark -
#pragma mark Accessibility

-(BOOL)accessibilityElement {
	return YES;
}

- (nullable NSAccessibilityRole)accessibilityRole {
    return NSAccessibilityGroupRole;
}

- (nullable NSArray *)accessibilityChildren {
    return NSAccessibilityUnignoredChildren(self.attachedButtons.allObjects);
}

- (nullable id)accessibilityHitTest:(NSPoint)point {
	id hitTestResult = self;

	NSEnumerator *enumerator = self.attachedButtons.objectEnumerator;
	MMAttachedTabBarButton *aButton = nil;
	MMAttachedTabBarButton *highlightedButton = nil;

	while(!highlightedButton && (aButton = enumerator.nextObject)) {
		if (aButton.cell.isHighlighted) {
			highlightedButton = aButton;
		}
	}

	if (highlightedButton) {
		hitTestResult = [highlightedButton accessibilityHitTest:point];
	}

	return hitTestResult;
}

#pragma mark -
#pragma mark Private Actions

- (void)_addNewTab:(id)sender {

    if (_delegate && [_delegate respondsToSelector:@selector(addNewTabToTabView:)]) {
        [_delegate addNewTabToTabView:_tabView];
    }
}

- (void)_overflowMenuAction:(id)sender {
	NSTabViewItem *tabViewItem = (NSTabViewItem *)[(NSMenuItem*) sender representedObject];
	[_tabView selectTabViewItem:tabViewItem];
}

- (void)_didClickTabButton:(id)sender {
	[_tabView selectTabViewItem:[(MMAttachedTabBarButton*) sender tabViewItem]];
}

- (void)_didClickCloseButton:(id)sender {

    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)[(NSButton*) sender enclosingTabBarButton];
    if (!button || ![button isKindOfClass:MMAttachedTabBarButton.class])
        {
        NSBeep();
        return;
        }
    
    NSTabViewItem *tabViewItem = button.tabViewItem;
    if (!tabViewItem || ![tabViewItem isKindOfClass:NSTabViewItem.class])
        {
        NSBeep();
        return;
        }

    if ((self.numberOfAttachedButtons == 1) && (!self.canCloseOnlyTab)) {
        NSBeep();
		return;
	}


    if ((self.delegate) && ([self.delegate respondsToSelector:@selector(tabView:shouldCloseTabViewItem:)])) {
        if (![self.delegate tabView:_tabView shouldCloseTabViewItem:tabViewItem]) {
             return;
         }
    }

    if ((self.delegate) && ([self.delegate respondsToSelector:@selector(tabView:willCloseTabViewItem:)])) {
         [self.delegate tabView:_tabView willCloseTabViewItem:tabViewItem];
    }
     
    [_tabView removeTabViewItem:tabViewItem];
     
    if ((self.delegate) && ([self.delegate respondsToSelector:@selector(tabView:didCloseTabViewItem:)])) {
         [self.delegate tabView:_tabView didCloseTabViewItem:tabViewItem];
    }

}

- (void)frameDidChange:(NSNotification *)notification {
	[self _checkWindowFrame];

	// trying to address the drawing artifacts for the progress indicators - hackery follows
	// this one fixes the "blanking" effect when the control hides and shows itself
    for (MMAttachedTabBarButton *aButton in self.attachedButtons) {
		[aButton.indicator stopAnimation:self];

		[aButton.indicator performSelector:@selector(startAnimation:) withObject:nil afterDelay:0.0];
	}

	[self update:NO];
}

#pragma mark -
#pragma mark Private Methods

- (void)_commonInit {
	_controller = [[MMTabBarController alloc] initWithTabBarView:self];

        // default config
	_orientation = MMTabBarHorizontalOrientation;
    _onlyShowCloseOnHover = NO;
	_canCloseOnlyTab = NO;
	_disableTabClose = NO;
	_showAddTabButton = NO;
	_hideForSingleTab = NO;
	_sizeButtonsToFit = NO;
	_isHidden = NO;
	_automaticallyAnimates = NO;
	_useOverflowMenu = YES;
	_allowsBackgroundTabClosing = YES;
	_allowsResizing = YES;
	_selectsTabsOnMouseDown = YES;
	_alwaysShowActiveTab = NO;
	_allowsScrubbing = NO;
	_buttonMinWidth = 100;
	_buttonMaxWidth = 280;
	_buttonOptimumWidth = 130;
	_tearOffStyle = MMTabBarTearOffAlphaWindow;
	_style = nil;
    _isReorderingTabViewItems = NO;
    _destinationIndexForDraggedItem = NSNotFound;
    _needsUpdate = NO;
    _resizeTabsToFitTotalWidth = NO;

    [self _updateOverflowPopUpButton];

    [self _updateAddTabButton];
}

- (BOOL)_supportsOrientation:(MMTabBarOrientation)orientation {
    return YES;
}

- (CGFloat)_heightOfTabBarButtons {
    return kMMTabBarViewHeight;
}

- (CGFloat)_rightMargin {

    if (self.orientation == MMTabBarHorizontalOrientation)
        return MARGIN_X;
    else
        return 0.0;
}

- (CGFloat)_leftMargin {

    if (self.orientation == MMTabBarHorizontalOrientation)
        return MARGIN_X;
    else
        return 0.0;
}

- (CGFloat)_topMargin {

    if (self.orientation == MMTabBarHorizontalOrientation)
        return 0.0;
    else
        return MARGIN_Y;
}

- (CGFloat)_bottomMargin {

    if (self.orientation == MMTabBarHorizontalOrientation)
        return 0.0;
    else
        return MARGIN_Y;
}

- (NSSize)_addTabButtonSize {

    if (self.orientation == MMTabBarHorizontalOrientation)
       return NSMakeSize(12.0,self.frame.size.height);
    else
        return NSMakeSize(self.frame.size.width,18.0);
}

- (NSRect)_addTabButtonRect {
    
    if (!self.showAddTabButton)
        return NSZeroRect;

    NSRect theRect;
    NSSize buttonSize = self.addTabButtonSize;
    NSSize overflowButtonSize = self.overflowButtonSize;
    
    if (self.orientation == MMTabBarHorizontalOrientation) {
        CGFloat xOffset = kMMTabBarCellPadding;
        MMAttachedTabBarButton *lastAttachedButton = self.lastAttachedButton;
        if (lastAttachedButton) {
            xOffset += NSMaxX(lastAttachedButton.stackingFrame);
            
            if (lastAttachedButton.isOverflowButton) {
                xOffset += kMMTabBarCellPadding;
                xOffset += overflowButtonSize.width;
            }
        }
                
        theRect = NSMakeRect(xOffset, NSMinY(self.bounds), buttonSize.width, buttonSize.height);
    } else {
        CGFloat yOffset = 0;
        MMAttachedTabBarButton *lastAttachedButton = self.lastAttachedButton;
        if (lastAttachedButton)
            yOffset += NSMaxY(lastAttachedButton.stackingFrame);
        
        theRect = NSMakeRect(NSMinX(self.bounds), yOffset, buttonSize.width, buttonSize.height);
    }
            
    return theRect;  
}
	
- (NSSize)_overflowButtonSize {

    if (self.orientation == MMTabBarHorizontalOrientation)
        return NSMakeSize(14.0,self.frame.size.height);
    else
        return NSMakeSize(self.frame.size.width,18.0);
}

- (NSRect)_overflowButtonRect {

    if (!self.useOverflowMenu)
        return NSZeroRect;

    NSRect theRect;
    NSSize buttonSize = self.overflowButtonSize;
    
    if (self.orientation == MMTabBarHorizontalOrientation) {
        CGFloat xOffset = 0.0; //kMMTabBarCellPadding;
        MMAttachedTabBarButton *lastAttachedButton = self.lastAttachedButton;
        if (lastAttachedButton)
            xOffset += NSMaxX(lastAttachedButton.stackingFrame);
                
        theRect = NSMakeRect(xOffset, NSMinY(self.bounds), buttonSize.width, buttonSize.height);
    } else {
        CGFloat yOffset = 0;
        MMAttachedTabBarButton *lastAttachedButton = self.lastAttachedButton;
        if (lastAttachedButton)
            yOffset += NSMaxY(lastAttachedButton.stackingFrame);
        
        theRect = NSMakeRect(NSMinX(self.bounds), yOffset, buttonSize.width, buttonSize.height);
    }
            
    return theRect;
}

- (void)_drawTabBarViewInRect:(NSRect)aRect {
    
    [self drawBezelInRect:aRect];
    
    if (self.frame.size.height < 2)
        return;
    
    [self drawButtonBezelsInRect:aRect];
    [self drawInteriorInRect:aRect];
}

- (void)_drawBezelInRect:(NSRect)rect {
    // default implementation draws nothing
}

- (void)_drawButtonBezelsInRect:(NSRect)rect {

    NSArray<MMAttachedTabBarButton *> *buttons = self.orderedAttachedButtons;

        // find selected button
    NSUInteger selIndex = NSNotFound;
    NSUInteger i = 0;
    for (MMAttachedTabBarButton *aButton in buttons) {
        if (aButton.state == NSOnState) {
            selIndex = i;
            break;
        }
        
        i++;
    }
    
        // draw a bezel for each button
    i = 0;
    for (MMAttachedTabBarButton *aButton in buttons) {
        
        [NSGraphicsContext saveGraphicsState];
        [self drawBezelOfButton:aButton atIndex:i inButtons:buttons indexOfSelectedButton:selIndex inRect:rect];
        [NSGraphicsContext restoreGraphicsState];
        i++;
    }

    if (self.isOverflowButtonVisible) {
        [self drawBezelOfOverflowButton:_overflowPopUpButton inRect:rect];
    }
}

- (void)_drawBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray<MMAttachedTabBarButton *> *)sortedButtons indexOfSelectedButton:(NSUInteger)selIndex inRect:(NSRect)rect {
    // default implementation draws nothing
}

- (void)_drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton inRect:(NSRect)rect {
    // default implementation draws nothing
}

- (void)_drawInteriorInRect:(NSRect)rect {

        // no tab view == not connected
	if (!self.tabView) {
		NSRect labelRect = rect;
		labelRect.size.height -= 4.0;
		labelRect.origin.y += 4.0;
		NSMutableAttributedString *attrStr;
		NSString *contents = @"MMTabBarView";
		attrStr = [[NSMutableAttributedString alloc] initWithString:contents];
		NSRange range = NSMakeRange(0, contents.length);
		[attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:range];
		NSMutableParagraphStyle *centeredParagraphStyle = [NSParagraphStyle.defaultParagraphStyle mutableCopy];
        [centeredParagraphStyle setAlignment:NSCenterTextAlignment];
        
		[attrStr addAttribute:NSParagraphStyleAttributeName value:centeredParagraphStyle range:range];
		[attrStr drawInRect:labelRect];
        
		return;
	}
}

- (void)_positionOverflowMenu {

    NSRect buttonRect = self.overflowButtonRect;
    if (!NSEqualRects(buttonRect, NSZeroRect))
        [_overflowPopUpButton setFrame:buttonRect];
}

- (void)_positionAddTabButton {
	if (!NSIsEmptyRect(self.addTabButtonRect)) {
		[_addTabButton setFrame:self.addTabButtonRect];
	}

    [_addTabButton setHidden:!_showAddTabButton];
    [_addTabButton setNeedsDisplay:YES];
}

- (void)_checkWindowFrame {
        //figure out if the new frame puts the control in the way of the resize widget
	NSWindow *window = self.window;

	if (window) {
		NSRect resizeWidgetFrame = window.contentView.frame;
		resizeWidgetFrame.origin.x += resizeWidgetFrame.size.width - 22;
		resizeWidgetFrame.size.width = 22;
		resizeWidgetFrame.size.height = 22;

		if (window.showsResizeIndicator && NSIntersectsRect(self.frame, resizeWidgetFrame)) {
                //the resize widgets are larger on metal windows
			_resizeAreaCompensation = window.styleMask & NSTexturedBackgroundWindowMask ? 20 : 8;
		} else {
			_resizeAreaCompensation = 0;
		}
	}
}

- (id <MMTabBarItem>)_dataSourceForSelector:(SEL)sel withTabViewItem:(NSTabViewItem *)item {

    id <MMTabBarItem> dataSource = nil;
    
    if (item.identifier &&
        [(NSObject*) item.identifier conformsToProtocol:@protocol(MMTabBarItem)] &&
        [(NSObject*) item.identifier respondsToSelector:sel]) {
        dataSource = item.identifier;
    } else if ([item conformsToProtocol:@protocol(MMTabBarItem)] &&
               [item respondsToSelector:sel]) {
        dataSource = (id <MMTabBarItem>)item;
    }
    
    return dataSource;
}

- (void)_bindPropertiesOfAttachedButton:(MMAttachedTabBarButton *)aButton andTabViewItem:(NSTabViewItem *)item {

    id <MMTabBarItem> dataSource = nil;
    
        // title binding
    dataSource = [self _dataSourceForSelector:@selector(title) withTabViewItem:item];
    if (!dataSource) {
        dataSource = [self _dataSourceForSelector:@selector(label) withTabViewItem:item];
        if (dataSource)
            [aButton bind:@"title" toObject:dataSource withKeyPath:@"label" options:nil];
    } else {
        [aButton bind:@"title" toObject:dataSource withKeyPath:@"title" options:nil];
    }
    
        // progress indicator binding
    [aButton.indicator setHidden:YES];
    dataSource = [self _dataSourceForSelector:@selector(isProcessing) withTabViewItem:item];
    if (dataSource)
        [aButton bind:@"isProcessing" toObject:dataSource withKeyPath:@"isProcessing" options:nil];

        // icon indicator binding
	[aButton setIcon:nil];
    dataSource = [self _dataSourceForSelector:@selector(icon) withTabViewItem:item];
    if (dataSource)
        [aButton bind:@"icon" toObject:dataSource withKeyPath:@"icon" options:nil];
    
        // object count binding
	[aButton setObjectCount:0];
    dataSource = [self _dataSourceForSelector:@selector(objectCount) withTabViewItem:item];
    if (dataSource)
        {
			NSDictionary<NSBindingOption, id> *options = @{
				NSConditionallySetsHiddenBindingOption: [NSNumber numberWithBool:YES]
			};
        [aButton bind:@"objectCount" toObject:dataSource withKeyPath:@"objectCount" options:options];
        }
    
        // object count color binding
	[aButton setObjectCountColor:MMAttachedTabBarButtonCell.defaultObjectCountColor];
    dataSource = [self _dataSourceForSelector:@selector(objectCountColor) withTabViewItem:item];
    if (dataSource)
        [aButton bind:@"objectCountColor" toObject:dataSource withKeyPath:@"objectCountColor" options:nil];

        // show object count binding
	[aButton setShowObjectCount:NO];
    dataSource = [self _dataSourceForSelector:@selector(showObjectCount) withTabViewItem:item];
    if (dataSource)
        [aButton bind:@"showObjectCount" toObject:dataSource withKeyPath:@"showObjectCount" options:nil];
    
        // large image binding
   	[aButton setLargeImage:nil];
    dataSource = [self _dataSourceForSelector:@selector(largeImage) withTabViewItem:item];
    if (dataSource)
        [aButton bind:@"largeImage" toObject:dataSource withKeyPath:@"largeImage" options:nil];

        // edited state binding
	[aButton setIsEdited:NO];
    dataSource = [self _dataSourceForSelector:@selector(isEdited) withTabViewItem:item];
    if (dataSource)
        [aButton bind:@"isEdited" toObject:dataSource withKeyPath:@"isEdited" options:nil];

        // has close button binding
	[aButton setHasCloseButton:NO];
    dataSource = [self _dataSourceForSelector:@selector(hasCloseButton) withTabViewItem:item];
    if (dataSource)
        [aButton bind:@"hasCloseButton" toObject:dataSource withKeyPath:@"hasCloseButton" options:nil];
}

- (void)_unbindPropertiesOfAttachedButton:(MMAttachedTabBarButton *)aButton {

        // unbind
	[aButton unbind:@"title"];
	[aButton unbind:@"objectCount"];
	[aButton unbind:@"objectCountColor"];
    [aButton unbind:@"showObjectCount"];    
	[aButton unbind:@"isEdited"];
	[aButton unbind:@"hasCloseButton"];
    [aButton unbind:@"isProcessing"];
    [aButton unbind:@"icon"];
    [aButton unbind:@"largeImage"];
}

- (void)_synchronizeSelection {
    NSTabViewItem *selectedTabViewItem = _tabView.selectedTabViewItem;
    
    MMAttachedTabBarButton *buttonToSelect = [self attachedButtonForTabViewItem:selectedTabViewItem];

    if (!buttonToSelect) {
        MMAttachedTabBarButton *lastButton = self.lastAttachedButton;
        if (lastButton.isOverflowButton) {
            [self setTabViewItemPinnedToOverflowButton:selectedTabViewItem];
            buttonToSelect = lastButton;
        }
    }
    
        // reset state masks
    for (MMAttachedTabBarButton *aButton in self.attachedButtons) {
    
        [aButton setTabState:aButton.tabState & ~(MMTab_RightIsSelectedMask|MMTab_LeftIsSelectedMask)];
        
        if (aButton == buttonToSelect) {
            if (aButton.state != NSOnState)
                [aButton setState:NSOnState];
        } else {
            if (aButton.state != NSOffState)
                [aButton setState:NSOffState];
        }
    }
    
    if (buttonToSelect) {
        NSUInteger indexOfSelectedButton = [self indexOfAttachedButton:buttonToSelect];
        if (indexOfSelectedButton != NSNotFound)
            [self updateTabStateMaskOfAttachedButton:buttonToSelect atIndex:indexOfSelectedButton];
    }
}

- (NSCursor *)resizingMouseCursor {

    if (NSWidth(self.frame) <= self.buttonMinWidth) {
        return NSCursor.resizeRightCursor;
    }
    else if (NSWidth(self.frame) >= self.buttonMaxWidth)
        return NSCursor.resizeLeftCursor;
    else  {
        return NSCursor.resizeLeftRightCursor;
    }
}

- (void)_beginResizingWithMouseDownEvent:(NSEvent *)theEvent {

    NSEvent *nextEvent = nil,
            *firstEvent = nil,
            *dragEvent = nil,
            *mouseUp = nil;
    NSDate *expiration = NSDate.distantFuture;

    if (self.orientation == MMTabBarHorizontalOrientation)
        return;

    [self setIsResizing:YES];
                
    NSCursor *cursor = self.resizingMouseCursor;
    [cursor set];
            
    while ((nextEvent = [self.window nextEventMatchingMask:NSLeftMouseUpMask | NSLeftMouseDraggedMask untilDate:expiration inMode:NSEventTrackingRunLoopMode dequeue:YES]) != nil) {

        if (firstEvent == nil) {
            firstEvent = nextEvent;
        }
        
        if (nextEvent.type == NSLeftMouseDragged) {
            dragEvent = nextEvent;

            NSPoint currentPoint = [self convertPoint:nextEvent.locationInWindow fromView:nil];
            NSRect frame = self.frame;
            CGFloat resizeAmount = nextEvent.deltaX;
            if ((currentPoint.x > frame.size.width && resizeAmount > 0) || (currentPoint.x < frame.size.width && resizeAmount < 0)) {

                cursor = self.resizingMouseCursor;
                [cursor set];

                NSRect partnerFrame = _partnerView.frame;

                //do some bounds checking
                if ((frame.size.width + resizeAmount >= self.buttonMinWidth) && (frame.size.width + resizeAmount <= self.buttonMaxWidth)) {
                    frame.size.width += resizeAmount;
                    partnerFrame.size.width -= resizeAmount;
                    partnerFrame.origin.x += resizeAmount;

                    [self setFrame:frame];
                    [_partnerView setFrame:partnerFrame];
                    [self.superview setNeedsDisplay:YES];
                }
            }
                    
        } else if (nextEvent.type == NSLeftMouseUp) {
            mouseUp = nextEvent;
            break;
        }
        
    }
    
    [[NSCursor arrowCursor] set];
    
    [self setIsResizing:NO];
}

- (BOOL)_shouldDisplayTabBar {

    if (!_hideForSingleTab)
        return YES;
    
    if (_tabView.numberOfTabViewItems <= 1)
        return NO;

    return YES;
}

-(void)_updateImages {
    [self.attachedButtons makeObjectsPerformSelector:@selector(updateImages)];
    [self _updateAddTabButton];
    [self _updateOverflowPopUpButton];
}

StaticImage(AquaTabNew)
StaticImage(AquaTabNewPressed)
StaticImage(AquaTabNewRollover)

- (MMRolloverButton *)_rolloverButtonWithFrame:(NSRect)frame {
    MMRolloverButton *rolloverButton = nil;
    if (_style && [_style respondsToSelector:@selector(rolloverButtonWithFrame:ofTabBarView:)]) {
        rolloverButton = [_style rolloverButtonWithFrame:frame ofTabBarView:self];
    } else {
        rolloverButton = [[MMRolloverButton alloc] initWithFrame:frame];
    }
    return rolloverButton;
}

- (void)_updateAddTabButton {

    if (_addTabButton) {
        [_addTabButton removeFromSuperview];    
        _addTabButton = nil;
    }
        // new tab button
	NSRect addTabButtonRect = self.addTabButtonRect;
//	_addTabButton = [[MMRolloverButton alloc] initWithFrame:addTabButtonRect];
    _addTabButton = [self _rolloverButtonWithFrame:addTabButtonRect];

    [_addTabButton setImage:_staticAquaTabNewImage()];
    [_addTabButton setAlternateImage:_staticAquaTabNewPressedImage()];
    [_addTabButton setRolloverImage:_staticAquaTabNewRolloverImage()];
    
    [_addTabButton setTitle:@""];
    [_addTabButton setImagePosition:NSImageOnly];
    [_addTabButton setRolloverButtonType:MMRolloverActionButton];
    [_addTabButton setBordered:NO];
    [_addTabButton setBezelStyle:NSShadowlessSquareBezelStyle];
    
    if (_style && [_style respondsToSelector:@selector(updateAddButton:ofTabBarView:)])
        [_style updateAddButton:_addTabButton ofTabBarView:self];

    [_addTabButton setTarget:self];
    [_addTabButton setAction:@selector(_addNewTab:)];
    
    [self addSubview:_addTabButton];

    if (_showAddTabButton) {
        [_addTabButton setHidden:NO];
    } else {
        [_addTabButton setHidden:YES];
    }
}

- (void)_updateOverflowPopUpButton {

    if (!_overflowPopUpButton)
        {
            // the overflow button/menu
        NSRect overflowButtonRect = self.overflowButtonRect;
        _overflowPopUpButton = [[MMOverflowPopUpButton alloc] initWithFrame:overflowButtonRect pullsDown:YES];
        [_overflowPopUpButton setAutoresizingMask:NSViewNotSizable | NSViewMinXMargin];
        [_overflowPopUpButton setHidden:YES];
        
        [self addSubview:_overflowPopUpButton];        
        }
    
    if (_style && [_style respondsToSelector:@selector(updateOverflowPopUpButton:ofTabBarView:)])
        [_style updateOverflowPopUpButton:_overflowPopUpButton ofTabBarView:self];
    
    if (_useOverflowMenu && _tabView && self.numberOfAttachedButtons != (NSUInteger) _tabView.numberOfTabViewItems) {
       [_overflowPopUpButton setHidden:NO];    
    } else {
       [_overflowPopUpButton setHidden:YES];
    }   
}
@end

NS_ASSUME_NONNULL_END
