//
//  PSMTabBarControl.h
//  PSMTabBarControl
//
//  Created by John Pannell on 10/13/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

/*
   This view provides a control interface to manage a regular NSTabView.  It looks and works like the tabbed browsing interface of many popular browsers.
 */

#import <Cocoa/Cocoa.h>

#define PSMTabDragDidEndNotification		@ "PSMTabDragDidEndNotification"
#define PSMTabDragDidBeginNotification	@ "PSMTabDragDidBeginNotification"

#define kPSMTabBarControlHeight             22
// internal cell border
#define MARGIN_X							6
#define MARGIN_Y							3
// padding between objects
#define kPSMTabBarCellPadding				4
// fixed size objects
#define kPSMMinimumTitleWidth				30
#define kPSMTabBarIndicatorWidth			16.0
#define kPSMTabBarIconWidth					16.0
#define kPSMHideAnimationSteps				3.0
#define kPSMObjectCounterMinWidth           20.0
#define kPSMObjectCounterRadius             7.0
#define kPSMTabBarControlSourceListHeight   28

// Value used in _currentStep to indicate that resizing operation is not in progress
#define kPSMIsNotBeingResized				-1

// Value used in _currentStep when a resizing operation has just been started
#define kPSMStartResizeAnimation			0

@class PSMOverflowPopUpButton;
@class PSMRolloverButton;
@class PSMTabBarCell;
@class PSMTabBarController;
@protocol PSMTabStyle;

typedef enum PSMTabBarOrientation : NSInteger {
	PSMTabBarHorizontalOrientation,
	PSMTabBarVerticalOrientation
} PSMTabBarOrientation;

typedef enum PSMTabBarTearOffStyle : NSInteger {
	PSMTabBarTearOffAlphaWindow,
	PSMTabBarTearOffMiniwindow
} PSMTabBarTearOffStyle;

typedef enum PSMTabStateMask : NSInteger {
	PSMTab_SelectedMask				= 1 << 1,
	PSMTab_LeftIsSelectedMask		= 1 << 2,
	PSMTab_RightIsSelectedMask		= 1 << 3,
	PSMTab_PositionLeftMask			= 1 << 4,
	PSMTab_PositionMiddleMask		= 1 << 5,
	PSMTab_PositionRightMask		= 1 << 6,
	PSMTab_PositionSingleMask		= 1 << 7,
} PSMTabStateMask;

@protocol PSMTabBarControlDelegate;

@interface PSMTabBarControl : NSControl {
												
	// control basics
	NSMutableArray							*_cells;								// the cells that draw the tabs
	IBOutlet NSTabView						*tabView;								// the tab view being navigated
	PSMOverflowPopUpButton					*_overflowPopUpButton;				// for too many tabs
	PSMRolloverButton						*_addTabButton;
	PSMTabBarController						*_controller;

	// Spring-loading.
	NSTimer									*_springTimer;
	NSTabViewItem							*_tabViewItemWithSpring;

	// drawing style
	id<PSMTabStyle>							style;
	BOOL									_canCloseOnlyTab;
	BOOL									_disableTabClose;
	BOOL									_hideForSingleTab;
	BOOL									_showAddTabButton;
	BOOL									_sizeCellsToFit;
	BOOL									_useOverflowMenu;
	BOOL									_alwaysShowActiveTab;
	BOOL									_allowsScrubbing;
	NSInteger								_resizeAreaCompensation;
	PSMTabBarOrientation					_orientation;
	BOOL									_automaticallyAnimates;
	NSTimer									*_animationTimer;
	PSMTabBarTearOffStyle					_tearOffStyle;

	// behavior
	BOOL									_allowsBackgroundTabClosing;
	BOOL									_selectsTabsOnMouseDown;

	// vertical tab resizing
	BOOL									_allowsResizing;
	BOOL									_resizing;

	// cell width
	NSInteger								_cellMinWidth;
	NSInteger								_cellMaxWidth;
	NSInteger								_cellOptimumWidth;

	// animation for hide/show
	NSInteger								_currentStep;
	BOOL									_isHidden;
	IBOutlet id								partnerView;							// gets resized when hide/show
	BOOL									_awakenedFromNib;
	NSInteger								_tabBarWidth;
	NSTimer									*_showHideAnimationTimer;

	// drag and drop
	NSEvent									*_lastMouseDownEvent;				// keep this for dragging reference
	BOOL									_didDrag;
	BOOL									_closeClicked;

	// MVC help
	IBOutlet id<PSMTabBarControlDelegate>	delegate;
}

#pragma mark Control Characteristics

+ (NSBundle *)bundle;
@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat availableCellWidth;
@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat availableCellHeight;
@property (NS_NONATOMIC_IOSONLY, readonly) NSRect genericCellRect;
@property (NS_NONATOMIC_IOSONLY, getter=isWindowActive, readonly) BOOL windowActive;

#pragma mark Style Class Registry

+ (void)registerDefaultTabStyleClasses;
+ (void)registerTabStyleClass:(Class <PSMTabStyle>)aStyleClass;
+ (void)unregisterTabStyleClass:(Class <PSMTabStyle>)aStyleClass;
+ (NSArray *)registeredTabStyleClasses;
+ (Class <PSMTabStyle>)registeredClassForStyleName:(NSString *)name;

#pragma mark Cell Management (KVC Compliant)

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *cells;
- (void)addCell:(PSMTabBarCell *)aCell;
- (void)insertCell:(PSMTabBarCell *)aCell atIndex:(NSUInteger)index;
- (void)removeCellAtIndex:(NSUInteger)index;
- (void)replaceCellAtIndex:(NSUInteger)index withCell:(PSMTabBarCell *)aCell;

#pragma mark Control Configuration

@property (NS_NONATOMIC_IOSONLY) PSMTabBarOrientation orientation;
@property (NS_NONATOMIC_IOSONLY) BOOL canCloseOnlyTab;
@property (NS_NONATOMIC_IOSONLY) BOOL disableTabClose;
@property (NS_NONATOMIC_IOSONLY, strong) id<PSMTabStyle> style;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *styleName;
- (void)setStyleNamed:(NSString *)name;
@property (NS_NONATOMIC_IOSONLY) BOOL hideForSingleTab;
@property (NS_NONATOMIC_IOSONLY) BOOL showAddTabButton;
@property (NS_NONATOMIC_IOSONLY) NSInteger cellMinWidth;
@property (NS_NONATOMIC_IOSONLY) NSInteger cellMaxWidth;
@property (NS_NONATOMIC_IOSONLY) NSInteger cellOptimumWidth;
@property (NS_NONATOMIC_IOSONLY) BOOL sizeCellsToFit;
@property (NS_NONATOMIC_IOSONLY) BOOL useOverflowMenu;
@property (NS_NONATOMIC_IOSONLY) BOOL allowsBackgroundTabClosing;
@property (NS_NONATOMIC_IOSONLY) BOOL allowsResizing;
@property (NS_NONATOMIC_IOSONLY) BOOL selectsTabsOnMouseDown;
@property (NS_NONATOMIC_IOSONLY) BOOL automaticallyAnimates;
@property (NS_NONATOMIC_IOSONLY) BOOL alwaysShowActiveTab;
@property (NS_NONATOMIC_IOSONLY) BOOL allowsScrubbing;
@property (NS_NONATOMIC_IOSONLY) PSMTabBarTearOffStyle tearOffStyle;
@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat heightOfTabCells;

#pragma mark Accessors 

@property (NS_NONATOMIC_IOSONLY, strong) NSTabView *tabView;
@property (NS_NONATOMIC_IOSONLY, assign) id<PSMTabBarControlDelegate> delegate;
@property (NS_NONATOMIC_IOSONLY, strong) id partnerView;

#pragma mark -
#pragma mark Determining Sizes

@property (NS_NONATOMIC_IOSONLY, readonly) NSSize addTabButtonSize;
@property (NS_NONATOMIC_IOSONLY, readonly) NSRect addTabButtonRect;
@property (NS_NONATOMIC_IOSONLY, readonly) NSSize overflowButtonSize;
@property (NS_NONATOMIC_IOSONLY, readonly) NSRect overflowButtonRect;

#pragma mark -
#pragma mark Determining Margins

@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat rightMargin;
@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat leftMargin;
@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat topMargin;
@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat bottomMargin;

#pragma mark The Buttons

@property (NS_NONATOMIC_IOSONLY, readonly, strong) PSMRolloverButton *addTabButton;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) PSMOverflowPopUpButton *overflowPopUpButton;

#pragma mark Tab Information

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMutableArray *representedTabViewItems;
@property (NS_NONATOMIC_IOSONLY, readonly) NSUInteger numberOfVisibleTabs;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) PSMTabBarCell *lastVisibleTab;

#pragma mark Special Effects

- (void)hideTabBar:(BOOL) hide animate:(BOOL)animate;
@property (NS_NONATOMIC_IOSONLY, getter=isTabBarHidden, readonly) BOOL tabBarHidden;
@property (NS_NONATOMIC_IOSONLY, getter=isAnimating, readonly) BOOL animating;

// internal bindings methods also used by the tab drag assistant
- (void)bindPropertiesForCell:(PSMTabBarCell *)cell andTabViewItem:(NSTabViewItem *)item;
- (void)removeTabForCell:(PSMTabBarCell *)cell;

@end

@protocol PSMTabBarControlDelegate <NSTabViewDelegate>

@optional

//Standard NSTabView methods
- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView didDetachTabViewItem:(NSTabViewItem *)tabViewItem;

//"Spring-loaded" tabs methods
- (NSArray *)allowedDraggedTypesForTabView:(NSTabView *)aTabView;
- (void)tabView:(NSTabView *)aTabView acceptedDraggingInfo:(id <NSDraggingInfo>) draggingInfo onTabViewItem:(NSTabViewItem *)tabViewItem;

//Contextual menu method
- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem;

//Event method
- (void)tabView:(NSTabView *)aTabView tabViewItem:(NSTabViewItem *)tabViewItem event:(NSEvent *)event;

//Drag and drop methods
- (BOOL)tabView:(NSTabView *)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem fromTabBar:(PSMTabBarControl *)tabBarControl;
- (BOOL)tabView:(NSTabView *)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl;
- (BOOL)tabView:(NSTabView *)aTabView shouldAllowTabViewItem:(NSTabViewItem *)tabViewItem toLeaveTabBar:(PSMTabBarControl *)tabBarControl;
- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl;


//Tear-off tabs methods
- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(NSUInteger *)styleMask;
- (PSMTabBarControl *)tabView:(NSTabView *)aTabView newTabBarForDraggedTabViewItem:(NSTabViewItem *)tabViewItem atPoint:(NSPoint)point;
- (void)tabView:(NSTabView *)aTabView closeWindowForLastTabViewItem:(NSTabViewItem *)tabViewItem;

//Overflow menu validation
- (BOOL)tabView:(NSTabView *)aTabView validateOverflowMenuItem:(NSMenuItem *)menuItem forTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView tabViewItem:(NSTabViewItem *)tabViewItem isInOverflowMenu:(BOOL)inOverflowMenu;

//tab bar hiding methods
- (void)tabView:(NSTabView *)aTabView tabBarDidHide:(PSMTabBarControl *)tabBarControl;
- (void)tabView:(NSTabView *)aTabView tabBarDidUnhide:(PSMTabBarControl *)tabBarControl;
- (CGFloat)desiredWidthForVerticalTabBar:(PSMTabBarControl *)tabBarControl;

//closing
- (BOOL)tabView:(NSTabView *)aTabView disableTabCloseForTabViewItem:(NSTabViewItem *)tabViewItem;

//tooltips
- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem;

//accessibility
- (NSString *)accessibilityStringForTabView:(NSTabView *)aTabView objectCount:(NSInteger)objectCount;

@end
