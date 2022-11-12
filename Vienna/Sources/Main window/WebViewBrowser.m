//
//  Browser.m
//  Vienna
//
//  Created by Steve on 8/26/05.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "BrowserPane.h"
#import "BrowserPaneTemplate.h"
#import "WebViewBrowser.h"
#import "Preferences.h"
#import "Constants.h"
#import "Browser+WebUIDelegate.h"
#import "TabbedWebView.h"
#import "Vienna-Swift.h"

@interface WebViewBrowser () <MMTabBarViewDelegate>

@property (weak) IBOutlet NSLayoutConstraint *tabBarHeightConstraint;
@property (weak) IBOutlet MMTabBarView *tabBarControl;
@property (readonly, nonatomic) NSTabViewItem *activeTabViewItem;

//queue for tab view items to select when current item is closed
@property NSMutableArray<NSTabViewItem *> *tabViewOrder;

//when closing a tab, the previously open tab gets selected
@property BOOL selectPreviousOnClose;
//IF selectpreviousonclose
	//true means the most recently created tab is the next in the order
@property BOOL selectNewItemFirst;
	//true means "previous" is interpreted as "from where it was opened"
	//this preference is not functional yet since
	//we cannot distinguish between browser and article list opened tabs
@property BOOL applyOnlyToBrowserOpenedTabs;
//if NOT selectpreviousonclose
	//true means the next tab to be opened is the one on the right (if it exists)
@property BOOL selectRightItemFirst;

//whether the article tab is treated specially
@property BOOL canJumpToArticles;

@end

@implementation WebViewBrowser

-(void)awakeFromNib
{
    [self commonInit];
}

-(instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self commonInit];
    }
    return self;
}

-(void)commonInit {
    [self configureTabBar];
    [self restoreTabs];
}


- (void)configureTabClosingBehavior
{
    self.selectPreviousOnClose = false;
    self.selectNewItemFirst = false;    // only works if selectpreviousonclose is true
    self.selectRightItemFirst = true;   // only works if selectpreviousonclose is false
    self.canJumpToArticles = false;     // only relevant if (selectpreviousonclose is true) or (selectrightitemfirst is false)
}

-(void)configureTabBar
{
    if (@available(macOS 10.14, *)) {
        [self.tabBarControl setStyleNamed:@"Mojave"];
    } else {
        [self.tabBarControl setStyleNamed:@"Sierra"];
    }
	//TODO: settings
	[self.tabBarControl setOnlyShowCloseOnHover:YES];
	[self.tabBarControl setCanCloseOnlyTab:NO];
	[self.tabBarControl setDisableTabClose:NO];
	[self.tabBarControl setAllowsBackgroundTabClosing:YES];
	[self.tabBarControl setHideForSingleTab:YES];
	[self.tabBarControl setShowAddTabButton:YES];
    self.tabBarControl.buttonMinWidth = 120;
	[self.tabBarControl setUseOverflowMenu:YES];
	[self.tabBarControl setAutomaticallyAnimates:YES];
	//TODO: figure out what this property means
	[self.tabBarControl setAllowsScrubbing:YES];

	[self configureTabClosingBehavior];
}

/* stringForToolTip
 * Returns the tooltip for the tab specified by the userData object. This is the tab's full title which
 * may have been truncated for display.
//XXX Not being used...
 */
-(NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
    NSInteger i = [self.tabBarControl.tabView indexOfTabViewItemWithIdentifier:(__bridge id _Nonnull)(userData)];
    if (i != NSNotFound) {
        return [self.tabBarControl.tabView tabViewItemAtIndex:i].label;
    }
    return nil;
}

/* setPrimaryTab
 * Sets the primary tab view. This is the view that is always displayed and
 * occupies the first tab position.
 */
-(void)setPrimaryTab:(NSTabViewItem *)newPrimaryTab
{
    // remove previous primary tab if there was one
    if (_primaryTab) {
        [self.tabBarControl.tabView removeTabViewItem:_primaryTab];
    }
    _primaryTab = newPrimaryTab;

    [self.tabBarControl.tabView insertTabViewItem:newPrimaryTab atIndex:0];

	[newPrimaryTab setHasCloseButton:NO];
	newPrimaryTab.identifier = newPrimaryTab.view;

	[self.primaryTab.view setNeedsDisplay:YES];
	[self switchToPrimaryTab];
}

/* activeTab
 * Returns the active tab.
 */
-(id<Tab>)activeTab
{
    return self.activeTabViewItem != self.primaryTab ? (id<Tab>)self.activeTabViewItem.view : nil;
}

- (NSTabViewItem *)activeTabViewItem {
    return self.tabBarControl.tabView.selectedTabViewItem;
}

/* setActiveTabToPrimaryTab
 * Make the primary tab the active tab.
 */
-(void)switchToPrimaryTab
{
    if (self.primaryTab) {
        [self.tabBarControl selectTabViewItem:[self.tabBarControl.tabView tabViewItemAtIndex:0]];
    }
}

/* tabTitle
 * Returns the title of the specified tab. May be an empty string.
 */
-(NSString *)tabItemViewTitle:(NSView *)tabItemView
{
    if (tabItemView == self.primaryTab.view) {
        return NSLocalizedString(@"Articles", nil);
    } else {
        return ((BrowserPane *)tabItemView).tab.label;
    }
}

/* closeAllTabs
 * Close all tabs.
 */
-(void)closeAllTabs
{
	NSInteger count = self.tabBarControl.numberOfTabViewItems;
	NSInteger i;
	for ((i = (count - 1)); i >= 0; i--) {
		NSTabViewItem * item = [self.tabBarControl.tabView tabViewItemAtIndex:i];
		if (item != self.primaryTab)
		{
			[self.tabViewOrder removeObject:item];
			[self.tabBarControl removeTabViewItem:item];
		}
	}
}

-(void)closeActiveTab {
    [self closeTab:self.activeTabViewItem];
}

/*
 for manually closing tabs (not initiated from tabview)
 */
-(void)closeTab:(NSTabViewItem *)tabViewItem
{
	MMTabBarView *tabBar = self.tabBarControl;
    [tabBar closeTabViewItem:tabViewItem];
}

/* countOfTabs
 * Returns the total number of tabs.
 */
-(NSInteger)browserTabCount
{
    if (self.primaryTab) {
        return self.tabBarControl.numberOfTabViewItems - 1;
    } else {
        return self.tabBarControl.numberOfTabViewItems;
    }
}

/* showPreviousTab
 * Switch to the previous tab in the view order. Wrap round to the end
 * if we're at the beginning.
 */
-(void)showPreviousTab
{
	if ([self.tabBarControl indexOfTabViewItem:self.tabBarControl.selectedTabViewItem] == 0)
		[self.tabBarControl.tabView selectLastTabViewItem:self];
	else
		[self.tabBarControl.tabView selectPreviousTabViewItem:self];
}

/* showNextTab
 * Switch to the next tab in the tab order. Wrap round to the beginning
 * if we're at the end.
 */
-(void)showNextTab
{
	if ([self.tabBarControl indexOfTabViewItem:self.tabBarControl.tabView.selectedTabViewItem] == self.tabBarControl.tabView.numberOfTabViewItems - 1)
		[self.tabBarControl.tabView selectFirstTabViewItem:self];
	else
		[self.tabBarControl.tabView selectNextTabViewItem:self];
}

#pragma mark - TabBarDelegate

// Additional NSTabView delegate methods

/* shouldCloseTabViewItem:
 * Returns whether the tab close should be disabled for the specified item. We disable the close button
 * for the primary item.
 */
- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	return tabViewItem != self.primaryTab;
}

- (void)tabView:(NSTabView *)aTabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	//remove closing tab from tab order
	[self.tabViewOrder removeObject:tabViewItem];
    [(id<Tab>)tabViewItem.view closeTab];

}

- (NSTabViewItem *)tabView:(NSTabView *)aTabView selectOnClosingTabViewItem:(NSTabViewItem *)tabViewItem {

    if (self.tabBarControl.selectedTabViewItem == tabViewItem)
    {
        if (self.selectPreviousOnClose) {
            //open most recently opened tab
            return self.tabViewOrder.lastObject;
        }
        else if (self.selectRightItemFirst
                 && [self.tabBarControl.tabView indexOfTabViewItem:tabViewItem] < self.tabBarControl.numberOfTabViewItems - 1)
        {
            //since tab is not the last, select the one right of it
            return [self.tabBarControl.tabView tabViewItemAtIndex:[self.tabBarControl.tabView indexOfTabViewItem:tabViewItem] + 1];
        }
        else if (self.canJumpToArticles == false
                 && [self.tabBarControl.tabView indexOfTabViewItem:tabViewItem] == 1
                 && self.tabBarControl.tabView.numberOfTabViewItems > 2)
        {
            //open tab to the right instead of article tab
            return [self.tabBarControl.tabView tabViewItemAtIndex:2];
        }
    }

    return nil;
}

// Closing behavior
- (BOOL)tabView:(NSTabView *)aTabView disableTabCloseForTabViewItem:(NSTabViewItem *)tabViewItem
{
	//prevent closing the first tab (articles tab)
	return tabViewItem == self.primaryTab;
}

// Adding tabs
- (void)addNewTabToTabView:(NSTabView *)aTabView
{
	[self createNewTab];
}

/*// Contextual menu support
- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem
{
 	//TODO: we can return items like "reload", "close", "close all others" etc. here.
	return nil;
}*/

/*- (void)tabView:(NSTabView *)aTabView closeWindowForLastTabViewItem:(NSTabViewItem *)tabViewItem
{
 	//TODO: Close Vienna
}*/

/*// Tooltips
- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem
{
 	//TODO: return string for tooltip here;
}*/

/*// Accessibility
- (NSString *)accessibilityStringForTabView:(NSTabView *)aTabView objectCount:(NSInteger)objectCount
{
	//TODO: return string for accessibility here
}*/

/* didSelectTabViewItem
 * Called when the tab is changed.
 */
-(void)tabView:(NSTabView *)inTabView didSelectTabViewItem:(NSTabViewItem *)inTabViewItem
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TabChanged" object:inTabViewItem.view];
	if (self.canJumpToArticles || inTabViewItem != self.primaryTab)
	{
		[self.tabViewOrder removeObject:self.tabBarControl.tabView.selectedTabViewItem];
		[self.tabViewOrder addObject:self.tabBarControl.tabView.selectedTabViewItem];
	}
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TabCountChanged" object:nil];
}


// Drag and drop related methods

- (BOOL)tabView:(NSTabView *)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem inTabBarView:(MMTabBarView *)tabBarView
{
	//prevent dragging articles tab
	return tabViewItem != self.primaryTab;
}

- (NSDragOperation)tabView:(NSTabView *)aTabView validateDrop:(id <NSDraggingInfo>)sender proposedItem:(NSTabViewItem *)tabViewItem proposedIndex:(NSUInteger)proposedIndex inTabBarView:(MMTabBarView *)tabBarView
{
	return proposedIndex == 0 ? NSDragOperationNone : NSDragOperationEvery;
}

- (NSDragOperation)tabView:(NSTabView *)aTabView validateSlideOfProposedItem:(NSTabViewItem *)tabViewItem proposedIndex:(NSUInteger)proposedIndex inTabBarView:(MMTabBarView *)tabBarView
{
	//Do not slide past Articles tab (primary tab at index 0)
	return proposedIndex == 0 ? NSDragOperationNone : NSDragOperationEvery;
}


// Informal tab bar visibility methods

- (void)tabView:(NSTabView *)aTabView tabBarViewDidHide:(MMTabBarView *)tabBarView
{
    self.tabBarHeightConstraint.constant = 0;
}

- (void)tabView:(NSTabView *)aTabView tabBarViewDidUnhide:(MMTabBarView *)tabBarView
{
    self.tabBarHeightConstraint.constant = 23;
}

// Animation companion

- (void (^)(void))animateAlongsideTabBarShow {
	return ^{
        self.tabBarHeightConstraint.animator.constant = 23;
	};
}

- (void (^)(void))animateAlongsideTabBarHide {
	return ^{
        self.tabBarHeightConstraint.animator.constant = 0;
	};
}

#pragma mark - save

/* saveOpenTabs
 * Persist the URLs of each open tab to the preferences so they can be
 * restored when we reload.
 */
-(void)saveOpenTabs
{
	NSMutableArray *tabLinks = [NSMutableArray arrayWithCapacity:self.browserTabCount];
	NSMutableDictionary *tabTitles = [NSMutableDictionary dictionaryWithCapacity:self.browserTabCount];
	
	for (NSTabViewItem * tabViewItem in self.tabBarControl.tabView.tabViewItems)
	{
		NSView<BaseView> * theView = tabViewItem.identifier;
		NSString * tabLink = theView.viewLink;
		if (tabLink != nil)
		{
			[tabLinks addObject:tabLink];
			if ([theView respondsToSelector:@selector(title)] && theView.title != nil)
			{
                tabTitles[tabLink] = theView.title;
			}
		}
	}

	[[Preferences standardPreferences] setObject:tabLinks forKey:MAPref_TabList];
	[[Preferences standardPreferences] setObject:tabTitles forKey:MAPref_TabTitleDictionary];
}

-(void)restoreTabs {
    // Start opening the old tabs once everything else has finished initializing and setting up
    NSArray<NSString *> * tabLinks = [Preferences.standardPreferences arrayForKey:MAPref_TabList];
    NSDictionary<NSString *, NSString *> * tabTitles = [Preferences.standardPreferences objectForKey:MAPref_TabTitleDictionary];

    for (int i = 0; i < tabLinks.count; i++)
    {
        NSString *tabLink = tabLinks[i];
        [self createNewTab:([NSURL URLWithString:tabLink])
                             withTitle:tabTitles[tabLink] inBackground:YES];
    }
}

#pragma mark - new tab creation

/* newTab
 * Create a new empty tab.
 */
-(BrowserPane *)createNewTab
{
	// Create a new empty tab in the foreground.
	BrowserPane *browserPane = [self createNewTab:nil inBackground:NO];
	// Make the address bar first responder.
	[browserPane activateAddressBar];

    return browserPane;
}

/* create tab with title and url
 * but do not load the page
 */
-(BrowserPane *)createNewTab:(NSURL *)url withTitle:(NSString *)title inBackground:(BOOL)inBackground
{
	BrowserPane * newBrowserPane = [self createNewTab:url inBackground:inBackground];
	if (title != nil) {
        newBrowserPane.tab.label = title;
		[newBrowserPane setTitle:title];
	}
	return newBrowserPane;
}

/* create tab with url
 * and load the page.
 */
-(BrowserPane *)createNewTab:(NSURL *)url inBackground:(BOOL)inBackground load:(BOOL)load
{
	BrowserPane * newBrowserPane = [self createNewTab:url inBackground:inBackground];
	[newBrowserPane loadTab];
    return newBrowserPane;
}

/* create tab with url
 * but do not load the page
 * in case openInBackgroundFlag is false, open the tab
 */
-(BrowserPane *)createNewTab:(NSURL *)url inBackground:(BOOL)inBackground
{
    BrowserPaneTemplate *newBrowserTemplate = [[BrowserPaneTemplate alloc] init];
    BrowserPane *newBrowserPane;
    if (newBrowserTemplate) {
        newBrowserPane = newBrowserTemplate.mainView;

        NSTabViewItem *tab = [[NSTabViewItem alloc] initWithIdentifier:newBrowserPane];
        tab.view = newBrowserPane;

        [self.tabBarControl.tabView addTabViewItem:tab];

        //newly created item will be selected first or last to be selected
        if (self.selectNewItemFirst) {
            [self.tabViewOrder addObject:tab];
        } else {
            [self.tabViewOrder insertObject:tab atIndex:0];
        }

        if (!inBackground) {
            [self.tabBarControl selectTabViewItem:tab];
        }

        [newBrowserPane setTab:tab];

        //set url but do not load yet
        newBrowserPane.tabUrl = url;

        //set delegate of new tab to the browser
        newBrowserPane.webPane.UIDelegate = self;
    }
    return newBrowserPane;
}

/* dealloc
 * Clean up behind ourselves.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
