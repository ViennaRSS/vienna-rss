//
//  MMTabBarView.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/19/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

/*
   This view provides a control interface to manage a regular NSTabView.  It looks and works like the tabbed browsing interface of many popular browsers.
 */

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

#pragma mark Umbrella Header section

//! Project version number for GameworkSDK.
FOUNDATION_EXPORT double MMTabBarViewVersionNumber;

//! Project version string for GameworkSDK.
FOUNDATION_EXPORT const unsigned char MMTabBarViewVersionString[];

#import <MMTabBarView/MMTabBarView.Globals.h>

#import <MMTabBarView/MMTabBarItem.h>

#import <MMTabBarView/MMTabBarButton.h>
#import <MMTabBarView/MMTabBarButtonCell.h>

#import <MMTabBarView/MMAttachedTabBarButton.h>
#import <MMTabBarView/MMAttachedTabBarButtonCell.h>

#import <MMTabBarView/MMOverflowPopUpButton.h>
#import <MMTabBarView/MMOverflowPopUpButtonCell.h>

#import <MMTabBarView/MMAdiumTabStyle.h>
#import <MMTabBarView/MMAquaTabStyle.h>
#import <MMTabBarView/MMCardTabStyle.h>
#import <MMTabBarView/MMLiveChatTabStyle.h>
#import <MMTabBarView/MMMetalTabStyle.h>
#import <MMTabBarView/MMMojaveTabStyle.h>
#import <MMTabBarView/MMSafariTabStyle.h>
#import <MMTabBarView/MMUnifiedTabStyle.h>
#import <MMTabBarView/MMYosemiteTabStyle.h>
#import <MMTabBarView/MMSierraTabStyle.h>
#import <MMTabBarView/MMSierraRolloverButton.h>
#import <MMTabBarView/MMSierraRolloverButtonCell.h>

#import <MMTabBarView/NSBezierPath+MMTabBarViewExtensions.h>
#import <MMTabBarView/NSTabViewItem+MMTabBarViewExtensions.h>

NS_ASSUME_NONNULL_BEGIN

@class MMRolloverButton;
@class MMTabBarViewler;
@class MMTabBarButton;
@class MMAttachedTabBarButton;
@class MMSlideButtonsAnimation;
@class MMTabBarController;

@protocol MMTabStyle;
@protocol MMTabBarViewDelegate;

@interface MMTabBarView : NSView <NSDraggingSource, NSDraggingDestination, NSAnimationDelegate>

#pragma mark Basics

/**
 *  Get bundle of class
 *
 *  @return The bundle
 */
+ (NSBundle *)bundle;

#pragma mark Outlets

/**
 *  Tab view
 */
@property (strong) IBOutlet NSTabView *tabView;

/**
 *  A partner view
 */
@property (nullable, strong) IBOutlet NSView *partnerView;

/**
 *  Delegate
 */
@property (weak)   IBOutlet id <MMTabBarViewDelegate> delegate;

#pragma mark Working with View's current state

/**
 *  Get available width for buttons
 */
@property (readonly) CGFloat availableWidthForButtons;

/**
 *  Get available height for buttons
 */
@property (readonly) CGFloat availableHeightForButtons;

/**
 *  Get generic button rect
 *
 *  @return The button rect
 */
- (NSRect)genericButtonRect;

/**
 *  Check if overflow button is currently visible
 */
@property (readonly) BOOL isOverflowButtonVisible;

/**
 *  Get window's active state
 */
@property (readonly) BOOL isWindowActive;

/**
 *  Check if in resize mode
 */
@property (readonly) BOOL isResizing;

/**
 *  Check if receiver needs update
 */
@property (assign) BOOL needsUpdate;

#pragma mark Drag & Drop Support

/**
 *  Check if detached dragging of tab view item is allowed
 *
 *  @param anItem A Tab view item
 *
 *  @return YES or NO
 */
- (BOOL)allowsDetachedDraggingOfTabViewItem:(NSTabViewItem *)anItem;

/**
 *  Get destination index for dragged item
 */
@property (assign) NSUInteger destinationIndexForDraggedItem;

#pragma mark Style Class Registry

/**
 *  Register default tab style classes
 */
+ (void)registerDefaultTabStyleClasses;

/**
 *  Register a tab style class
 *
 *  @param aStyleClass A tab style class
 */
+ (void)registerTabStyleClass:(Class <MMTabStyle>)aStyleClass;

/**
 *  Unregister tab style class
 *
 *  @param aStyleClass A tab style class
 */
+ (void)unregisterTabStyleClass:(Class <MMTabStyle>)aStyleClass;

/**
 *  Get registered tab style classes
 *
 *  @return Array of all registered classes
 */
+ (NSArray<Class <MMTabStyle>> *)registeredTabStyleClasses;

/**
 *  Get registered class for specified tab style name
 *
 *  @param name Name of a registered tab style
 *
 *  @return The matching tab style class
 */
+ (nullable Class <MMTabStyle>)registeredClassForStyleName:(NSString *)name;

#pragma mark Tab View Item Management

/**
 *  Get number of tab view items
 */
@property (readonly) NSUInteger numberOfTabViewItems;

/**
 *  Get number of visible tab view items
 */
@property (readonly) NSUInteger numberOfVisibleTabViewItems;

/**
 *  Get array of visible tab view items
 */
@property (readonly) NSArray<NSTabViewItem*> *visibleTabViewItems;

/**
 *  Get index of specified tab view item
 *
 *  @param anItem A tab view item
 *
 *  @return The index into array of tab view items
 */
- (NSUInteger)indexOfTabViewItem:(NSTabViewItem *)anItem;

/**
 *  Get selected tab view item
 */
@property (nullable, readonly) NSTabViewItem *selectedTabViewItem;

/**
 *  Select specified tab view item
 *
 *  @param anItem A tab view item
 */
- (void)selectTabViewItem:(NSTabViewItem *)anItem;

/**
 *  Move a tab view item to specified index
 *
 *  @param anItem A tab view item
 *  @param index  The destination index
 */
- (void)moveTabViewItem:(NSTabViewItem *)anItem toIndex:(NSUInteger)index;

/**
 *  Close a tab view item, executing all due delegate methods
 *
 *  @param anItem A tab view item
 */
- (void)closeTabViewItem:(NSTabViewItem *)anItem;

/**
 *  Remove a tab view item, skip all delegate methods
 *
 *  @param anItem Tab view item to remove
 */
- (void)removeTabViewItem:(NSTabViewItem *)anItem;

/**
 *  Tab view item currently pinned to overflow button
 */
@property (strong) NSTabViewItem *tabViewItemPinnedToOverflowButton;

#pragma mark Attached Buttons Management

/**
 *  Get number of attached tab bar buttons
 */
@property (readonly) NSUInteger numberOfAttachedButtons;

/**
 *  Get array of all attached tab bar buttons
 */
@property (readonly) NSSet<MMAttachedTabBarButton *> *attachedButtons;

/**
 *  Get ordered array of attached tab bar buttons
 */
@property (readonly) NSArray<MMAttachedTabBarButton *> *orderedAttachedButtons;

/**
 *  Get array of attached tab bar buttons sorted by using a comparator
 *
 *  @param cmptr A comparator block
 *
 *  @return The sorted array
 */
- (NSArray<MMAttachedTabBarButton *> *)sortedAttachedButtonsUsingComparator:(NSComparator)cmptr;

/**
 *  INsert attached tab bar button for specified tab view item
 *
 *  @param item  A tab view item
 *  @param index Index to insert attached tab bar button at
 */
- (void)insertAttachedButtonForTabViewItem:(NSTabViewItem *)item atIndex:(NSUInteger)index;

/**
 *  Add attached tab bar button for specified tab view item
 *
 *  @param item view item to add attached tab bar button for
 */
- (void)addAttachedButtonForTabViewItem:(NSTabViewItem *)item;

/**
 *  Remove attached tab bar button
 *
 *  @param aButton A tab bar button
 */
- (void)removeAttachedButton:(MMAttachedTabBarButton *)aButton;

/**
 *  Remove attached tab bar button and synchronize tab view items
 *
 *  @param aButton          A tab bar button
 *  @param syncTabViewItems YES: synchronize tab view items
 */
- (void)removeAttachedButton:(MMAttachedTabBarButton *)aButton synchronizeTabViewItems:(BOOL)syncTabViewItems;

/**
 *  Insert specified attached tab bar button at index
 *
 *  @param aButton A tab bar button
 *  @param anIndex Destination index
 */
- (void)insertAttachedButton:(MMAttachedTabBarButton *)aButton atTabItemIndex:(NSUInteger)anIndex;

#pragma mark Find Attached Buttons

/**
 *  Get view indexes of attached buttons
 */
@property (readonly) NSIndexSet *viewIndexesOfAttachedButtons;

/**
 *  Get view index of selected attached button
 */
@property (readonly) NSUInteger viewIndexOfSelectedAttachedButton;

/**
 *  Get selected attached tab bar button
 */
@property (readonly) MMAttachedTabBarButton *selectedAttachedButton;

/**
 *   Get last attached tab bar button
 */
@property (nullable, readonly) MMAttachedTabBarButton *lastAttachedButton;

/**
 *  Get attached tab bar button at point
 *
 *  @param aPoint A point in receiver's coos
 *
 *  @return The matching attached tab bar button (or nil)
 */
- (MMAttachedTabBarButton *)attachedButtonAtPoint:(NSPoint)aPoint;

/**
 *  Get attached tab bar button for specified tab view item
 *
 *  @param anItem A tab view item
 *
 *  @return Matching attached tab bar button (or nil)
 */
- (MMAttachedTabBarButton *)attachedButtonForTabViewItem:(NSTabViewItem *)anItem;

/**
 *  Get index of specified attached tab bar button
 *
 *  @param aButton A tab bar button
 *
 *  @return Index of tab bar button
 */
- (NSUInteger)indexOfAttachedButton:(MMAttachedTabBarButton *)aButton;

#pragma mark Button State Management

/**
 *  Update tab state mask of specified attached tab bar button
 *
 *  @param aButton    An attached tab bar button
 *  @param index      Button index
 *  @param prevButton Previous button
 *  @param nextButton Next Button
 */
- (void)updateTabStateMaskOfAttachedButton:(MMAttachedTabBarButton *)aButton atIndex:(NSUInteger)index withPrevious:(MMAttachedTabBarButton *)prevButton next:(MMAttachedTabBarButton *)nextButton;

/**
 *  Update tab state mask of specified attached tab bar button
 *
 *  @param aButton An attached tab bar button
 *  @param index   Button index
 */
- (void)updateTabStateMaskOfAttachedButton:(MMAttachedTabBarButton *)aButton atIndex:(NSUInteger)index;

/**
 *  Update tab state mask of all attached buttons
 */
- (void)updateTabStateMaskOfAttachedButtons;

#pragma mark Sending Messages to Attached Buttons

/**
 *  Enumerate attached tab bar buttons
 *
 *  @param block Block to execute
 */
- (void)enumerateAttachedButtonsUsingBlock:(void (^)(MMAttachedTabBarButton *aButton, NSUInteger idx, BOOL *stop))block;

/**
 *  Enumerate attached tab bar buttons with options
 *
 *  @param opts  Options (@see MMAttachedButtonsEnumerationOptions)
 *  @param block Block to execute
 */
- (void)enumerateAttachedButtonsWithOptions:(MMAttachedButtonsEnumerationOptions)opts usingBlock:(nullable void (^)(MMAttachedTabBarButton *aButton, NSUInteger idx, MMAttachedTabBarButton *previousButton, MMAttachedTabBarButton *nextButton, BOOL *stop))block;

/**
 *  Enumerate attached tab bar buttons in range with options
 *
 *  @param buttons Array of attached tab bar buttons
 *  @param range   Button index range
 *  @param opts    Options (@see MMAttachedButtonsEnumerationOptions)
 *  @param block   Block to execute
 */
- (void)enumerateAttachedButtons:(NSArray<MMAttachedTabBarButton *> *)buttons inRange:(NSRange)range withOptions:(MMAttachedButtonsEnumerationOptions)opts usingBlock:(void (^)(MMAttachedTabBarButton *aButton, NSUInteger idx, MMAttachedTabBarButton *previousButton, MMAttachedTabBarButton *nextButton, BOOL *stop))block;

#pragma mark Find Tab Bar Buttons

/**
 *  Fin tab bar button at point
 *
 *  @param point Point in receiver's coo system
 *
 *  @return Matching tab bar button (or nil)
 */
- (MMTabBarButton *)tabBarButtonAtPoint:(NSPoint)point;

#pragma mark Control Configuration

/**
 *  The tab style to use
 */
@property (strong) id <MMTabStyle> style;

/**
 *  Name of tab style
 */
@property (readonly) NSString *styleName;

/**
 *  Set tab style by style name
 *
 *  @param name Name of registered tab style
 */
- (void)setStyleNamed:(NSString *)name;

/**
 *  Reciever's layout orientation
 */
@property (assign) MMTabBarOrientation orientation;

/**
 *  YES: only show close button on hover
 */
@property (assign) BOOL onlyShowCloseOnHover;

/**
 *  YES: can close last (single) tab available
 */
@property (assign) BOOL canCloseOnlyTab;

/**
 *  Disable closing of tabs
 */
@property (assign) BOOL disableTabClose;

/**
 *  Hide receiver if there is a single tab only
 */
@property (assign) BOOL hideForSingleTab;

/**
 *  Visibilty of 'add' button
 */
@property (assign) BOOL showAddTabButton;

/**
 *  Minimum width of tab bar buttons
 */
@property (assign) NSInteger buttonMinWidth;

/**
 *  Minimum width of tab bar buttons
 */
@property (assign) NSInteger buttonMaxWidth;

/**
 *  Optimum width of tab bar buttons
 */
@property (assign) NSInteger buttonOptimumWidth;

/**
 *  Size tab bar buttons to fit
 */
@property (assign) BOOL sizeButtonsToFit;

/**
 *  Should use of overflow menu
 */
@property (assign) BOOL useOverflowMenu;

/**
 *  Allow background closing of tabs
 */
@property (assign) BOOL allowsBackgroundTabClosing;

/**
 *  Allow resizing
 */
@property (assign) BOOL allowsResizing;

/**
 *  Select tabs on mouse down event
 */
@property (assign) BOOL selectsTabsOnMouseDown;

/**
 *  Automatically animates
 */
@property (assign) BOOL automaticallyAnimates;

/**
 *  Assure that active tab is always visible
 */
@property (assign) BOOL alwaysShowActiveTab;

/**
 *  Allow or disallow button scrubbing
 */
@property (assign) BOOL allowsScrubbing;

/**
 *  Tear off style
 */
@property (assign) MMTabBarTearOffStyle tearOffStyle;

/**
 *  Check if tabs should be resized to fit total width
 */
@property (assign) BOOL resizeTabsToFitTotalWidth;

/**
 *  Check if receiver supports specified orientation
 *
 *  @param orientation Orientation (@see MMTabBarOrientation)
 *
 *  @return YES or NO
 */
- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation;

#pragma mark Accessors 

- (CGFloat)heightOfTabBarButtons;

#pragma mark Resizing

- (NSRect)dividerRect;

#pragma mark Hide/Show Tab Bar Control

- (void)hideTabBar:(BOOL)hide animate:(BOOL)animate;
- (BOOL)isTabBarHidden;
- (BOOL)isAnimating;

#pragma mark Determining Sizes

- (NSSize)addTabButtonSize;
- (NSRect)addTabButtonRect;
- (NSSize)overflowButtonSize;
- (NSRect)overflowButtonRect;

#pragma mark Determining Margins

- (CGFloat)rightMargin;
- (CGFloat)leftMargin;
- (CGFloat)topMargin;
- (CGFloat)bottomMargin;

#pragma mark Layout Buttons

- (void)layoutButtons;
- (void)update;
- (void)update:(BOOL)animate;

#pragma mark Interface to Dragging Assistant

- (BOOL)shouldStartDraggingAttachedTabBarButton:(MMAttachedTabBarButton *)aButton withMouseDownEvent:(NSEvent *)event;

- (void)startDraggingAttachedTabBarButton:(MMAttachedTabBarButton *)aButton withMouseDownEvent:(NSEvent *)theEvent;

- (nullable MMAttachedTabBarButton *)attachedTabBarButtonForDraggedItems;

- (BOOL)isSliding;
- (BOOL)isDragging;

#pragma mark Tab Button Menu Support

- (NSMenu *)menuForTabBarButton:(MMTabBarButton *)aButton withEvent:(NSEvent *)anEvent;
- (NSMenu *)menuForTabViewItem:(NSTabViewItem *)aTabViewItem withEvent:(NSEvent *)anEvent;

#pragma mark Convenience

// internal bindings methods also used by the tab drag assistant
- (void)bindPropertiesOfAttachedButton:(MMAttachedTabBarButton *)aButton andTabViewItem:(NSTabViewItem *)item;
- (void)unbindPropertiesOfAttachedButton:(MMAttachedTabBarButton *)aButton;

#pragma mark -
#pragma mark Drawing

- (void)drawRect:(NSRect)rect;
- (void)drawBezelInRect:(NSRect)rect;
- (void)drawButtonBezelsInRect:(NSRect)rect;
- (void)drawInteriorInRect:(NSRect)rect;

@end

@protocol MMTabBarViewDelegate <NSTabViewDelegate>

@optional

    // Additional NSTabView delegate methods
- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView didDetachTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView didMoveTabViewItem:(NSTabViewItem *)tabViewItem toIndex:(NSUInteger)index;

    // Informal tab bar visibility methods
- (void)tabView:(NSTabView *)aTabView tabBarViewDidHide:(MMTabBarView *)tabBarView;
- (void)tabView:(NSTabView *)aTabView tabBarViewDidUnhide:(MMTabBarView *)tabBarView;

	// Tab bar show/hide animation companions
- (void (^)(void))animateAlongsideTabBarHide;
- (void (^)(void))animateAlongsideTabBarShow;

    // Closing behavior
- (BOOL)tabView:(NSTabView *)aTabView disableTabCloseForTabViewItem:(NSTabViewItem *)tabViewItem;
- (nullable NSTabViewItem *)tabView:(NSTabView *)aTabView selectOnClosingTabViewItem:(NSTabViewItem *)tabViewItem;

    // Adding tabs
- (void)addNewTabToTabView:(NSTabView *)aTabView;

    // Contextual menu support
- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem;

    // Drag and drop related methods
- (BOOL)tabView:(NSTabView *)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem inTabBarView:(MMTabBarView *)tabBarView;
- (NSDragOperation)tabView:(NSTabView *)aTabView validateDrop:(id <NSDraggingInfo>)sender proposedItem:(NSTabViewItem *)tabViewItem proposedIndex:(NSUInteger)proposedIndex inTabBarView:(MMTabBarView *)tabBarView;
- (NSDragOperation)tabView:(NSTabView *)aTabView validateSlideOfProposedItem:(NSTabViewItem *)tabViewItem proposedIndex:(NSUInteger)proposedIndex inTabBarView:(MMTabBarView *)tabBarView;
- (BOOL)tabView:(NSTabView *)aTabView shouldAllowTabViewItem:(NSTabViewItem *)tabViewItem toLeaveTabBarView:(MMTabBarView *)tabBarView;
- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBarView:(MMTabBarView *)tabBarView;

    // "Spring-loaded" tabs methods
- (NSArray<NSPasteboardType> *)allowedDraggedTypesForTabView:(NSTabView *)aTabView;
- (BOOL)tabView:(NSTabView *)aTabView acceptedDraggingInfo:(id <NSDraggingInfo>) draggingInfo onTabViewItem:(NSTabViewItem *)tabViewItem;

    // Tear-off related methods
- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(NSUInteger *)styleMask;
- (MMTabBarView *)tabView:(NSTabView *)aTabView newTabBarViewForDraggedTabViewItem:(NSTabViewItem *)tabViewItem atPoint:(NSPoint)point;
- (void)tabView:(NSTabView *)aTabView closeWindowForLastTabViewItem:(NSTabViewItem *)tabViewItem;

    // Overflow handling validation
- (BOOL)tabView:(NSTabView *)aTabView validateOverflowMenuItem:(NSMenuItem *)menuItem forTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView tabViewItem:(NSTabViewItem *)tabViewItem isInOverflowMenu:(BOOL)inOverflowMenu;

    // Tooltips
- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem;

    // Accessibility
- (NSString *)accessibilityStringForTabView:(NSTabView *)aTabView objectCount:(NSInteger)objectCount;

    // Deprecated Methods
- (BOOL)tabView:(NSTabView *)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem fromTabBar:(id)tabBarControl __attribute__((deprecated("implement -tabView:shouldDragTabViewItem:inTabBarView: instead.")));
- (BOOL)tabView:(NSTabView *)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(id)tabBarControl __attribute__((deprecated("implement -tabView:shouldDropTabViewItem:inTabBarView: instead.")));
- (BOOL)tabView:(NSTabView *)aTabView shouldAllowTabViewItem:(NSTabViewItem *)tabViewItem toLeaveTabBar:(id)tabBarControl __attribute__((deprecated("implement -tabView:shouldAllowTabViewItem:toLeaveTabBarView: instead.")));
- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(id)tabBarControl __attribute__((deprecated("implement -tabView:didDropTabViewItem:inTabBarView: instead.")));
- (id)tabView:(NSTabView *)aTabView newTabBarForDraggedTabViewItem:(NSTabViewItem *)tabViewItem atPoint:(NSPoint)point __attribute__((deprecated("implement -tabView:newTabBarViewForDraggedTabViewItem:atPoint: instead.")));
- (void)tabView:(NSTabView *)aTabView tabBarDidHide:(id)tabBarControl __attribute__((deprecated("implement -tabView:tabBarViewDidHide: instead.")));
- (void)tabView:(NSTabView *)aTabView tabBarDidUnhide:(id)tabBarControl __attribute__((deprecated("implement -tabView:tabBarViewDidUnhide: instead.")));
- (CGFloat)desiredWidthForVerticalTabBar:(id)tabBarControl DEPRECATED_ATTRIBUTE;

- (NSDragOperation)tabView:(NSTabView *)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBarView:(MMTabBarView *)tabBarView __attribute__((deprecated("implement -tabView:validateDrop:proposedIndex:inTabBarView: instead.")));

@end

NS_ASSUME_NONNULL_END
