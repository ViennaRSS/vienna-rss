//
//  BrowserView.m
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
#import "BrowserView.h"
#import "Preferences.h"
#import "Constants.h"
#import <MMTabBarView/MMTabBarView.h>

@interface MMTabBarView (BrowserViewAdditions)
	-(NSTabViewItem *)tabViewItemWithIdentifier:(id)identifier;
@end

@implementation MMTabBarView (BrowserViewAdditions)

/* tabViewItemWithIdentifier
 * Returns the tab view item that matches the specified identifier.
 */
-(NSTabViewItem *)tabViewItemWithIdentifier:(id)identifier
{
	NSInteger i = [self.tabView indexOfTabViewItemWithIdentifier:identifier];
	return (i != NSNotFound ? [self.tabView tabViewItemAtIndex:i] : nil);
}
@end

@interface BrowserView () <MMTabBarViewDelegate>

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

@implementation BrowserView

-(void)awakeFromNib
{
	[[self.tabBarControl.tabView tabViewItemAtIndex:0] setLabel:NSLocalizedString(@"Articles", nil)];
	[self configureTabBar];
	[self configureTabClosingBehavior];

	self.tabViewOrder = [NSMutableArray array];
}

-(void)configureTabClosingBehavior
{
	self.selectPreviousOnClose = false;
	//only works if selectpreviousonclose is true
	self.selectNewItemFirst = false;
	//only works if selectpreviousonclose is false
	self.selectRightItemFirst = true;
	//only relevant if (selectpreviousonclose is true) or (selectrightitemfirst is false)
	self.canJumpToArticles = false;
}

-(void)configureTabBar
{
	[self.tabBarControl setStyleNamed:@"Sierra"];
	//TODO: set NO
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
}

/* stringForToolTip
 * Returns the tooltip for the tab specified by the userData object. This is the tab's full title which
 * may have been truncated for display.
//XXX Not being used...
 */
-(NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
	return [self.tabBarControl tabViewItemWithIdentifier:(__bridge NSView *)userData].label;
}

/* setPrimaryTabItemView
 * Sets the primary tab view. This is the view that is always displayed and
 * occupies the first tab position.
 */
-(void)setPrimaryTabItemView:(NSView<BaseView, WebUIDelegate, WebFrameLoadDelegate> *)newPrimaryTabItemView
{
	
	NSTabViewItem * item;
	if (primaryTabItemView == nil)
	{
		// This should only be called on launch
		item = [self.tabBarControl.tabView tabViewItemAtIndex:0];
	}
	else
	{
		item = [self.tabBarControl tabViewItemWithIdentifier:primaryTabItemView];
	}

	[item setHasCloseButton:NO];
	item.identifier = newPrimaryTabItemView;
	item.view = newPrimaryTabItemView;
	
	primaryTabItemView = newPrimaryTabItemView;
	
	[primaryTabItemView setNeedsDisplay:YES];
	[self setActiveTabToPrimaryTab];
	//this call seems to be necessary manually here, no delegate call
	//maybe setPrimaryTabItemView is called earlier than the delegate IBOutlet setup.
	[self tabView:self.tabBarControl.tabView didSelectTabViewItem:item];
}

/* activeTabItemView
 * Returns the view associated with the active tab.
 */
-(NSView<BaseView> *)activeTabItemView
{
	return self.tabBarControl.tabView.selectedTabViewItem.identifier;
}

/* setActiveTabToPrimaryTab
 * Make the primary tab the active tab.
 */
-(void)setActiveTabToPrimaryTab
{
	[self showTabItemView:primaryTabItemView];
}

/* primaryTabItemView
 * Return the primary tab view.
 */
-(NSView<BaseView> *)primaryTabItemView
{
	return primaryTabItemView;
}

/* setTabTitle
 * Sets the title of the specified tab then redraws the tab bar.
 */
-(void)setTabItemViewTitle:(NSView *)inTabView title:(NSString *)newTitle
{
	[self.tabBarControl tabViewItemWithIdentifier:inTabView].label = newTitle;
}

/* tabTitle
 * Returns the title of the specified tab. May be an empty string.
 */
-(NSString *)tabItemViewTitle:(NSView *)tabItemView
{
	return [self.tabBarControl tabViewItemWithIdentifier:tabItemView].label;
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
		if (item.identifier != primaryTabItemView)
		{
			[self.tabViewOrder removeObject:item];
			[self.tabBarControl removeTabViewItem:item];
		}
	}
}

/*
 for manually closing tabs (not initiated from tabview)
 */
-(void)closeTabItemView:(NSView *)tabItemView
{
	MMTabBarView *tabBar = self.tabBarControl;
	NSTabView *tabView = tabBar.tabView;
	NSTabViewItem *tabViewItem = [tabBar tabViewItemWithIdentifier:tabItemView];

    if ((tabBar.delegate) && ([tabBar.delegate respondsToSelector:@selector(tabView:shouldCloseTabViewItem:)])) {
        if (![tabBar.delegate tabView:tabView shouldCloseTabViewItem:tabViewItem]) {
            return;
        }
    }
    
    if ((tabBar.delegate) && ([tabBar.delegate respondsToSelector:@selector(tabView:willCloseTabViewItem:)])) {
        [tabBar.delegate tabView:tabView willCloseTabViewItem:tabViewItem];
    }
    
    [tabView removeTabViewItem:tabViewItem];
    
    if ((tabBar.delegate) && ([tabBar.delegate respondsToSelector:@selector(tabView:didCloseTabViewItem:)])) {
        [tabBar.delegate tabView:tabView didCloseTabViewItem:tabViewItem];
    }
}

/* countOfTabs
 * Returns the total number of tabs.
 */
-(NSInteger)countOfTabs
{
	return self.tabBarControl.numberOfTabViewItems;
}

/* showTabItemView
 * Makes the specified tab active if not already and post a notification.
 */
-(void)showTabItemView:(NSView *)theTabView
{
	NSTabViewItem *tabViewItem = [self.tabBarControl tabViewItemWithIdentifier:theTabView];
	if (tabViewItem) {
		[self.tabBarControl selectTabViewItem:tabViewItem];
	}
}

/* articlesTab
 * Go straight back to the articles tab
 */
-(void)showArticlesTab
{
	[self showTabItemView:primaryTabItemView];
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
	return tabViewItem.identifier != primaryTabItemView;
}

- (void)tabView:(NSTabView *)aTabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	//remove closing tab from tab order
	[self.tabViewOrder removeObject:tabViewItem];

	if (self.tabBarControl.selectedTabViewItem == tabViewItem)
	{
		if (self.selectPreviousOnClose) {
			//open most recently opened tab
			[self.tabBarControl.tabView selectTabViewItem:self.tabViewOrder.lastObject];
		}
		else if (self.selectRightItemFirst
				 && [self.tabBarControl.tabView indexOfTabViewItem:tabViewItem] < self.tabBarControl.numberOfTabViewItems - 1)
		{
			//since tab is not the last, select the one right of it
			[self.tabBarControl.tabView selectTabViewItemAtIndex:[self.tabBarControl.tabView indexOfTabViewItem:tabViewItem] + 1];
		}
		else if (self.canJumpToArticles == false
				 && [self.tabBarControl.tabView indexOfTabViewItem:tabViewItem] == 1
				 && self.tabBarControl.tabView.numberOfTabViewItems > 2)
		{
			//open tab to the right instead of article tab
			[self.tabBarControl.tabView selectTabViewItemAtIndex:2];
		}
	}
}

// Closing behavior
- (BOOL)tabView:(NSTabView *)aTabView disableTabCloseForTabViewItem:(NSTabViewItem *)tabViewItem
{
	//prevent closing the first tab (articles tab)
	return tabViewItem.identifier == primaryTabItemView;
}

// Adding tabs
- (void)addNewTabToTabView:(NSTabView *)aTabView
{
	[self newTab];
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
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TabChanged" object:inTabViewItem.identifier];
	if (self.canJumpToArticles || inTabViewItem.identifier != primaryTabItemView)
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
	return tabViewItem.identifier != primaryTabItemView;
}

- (NSDragOperation)tabView:(NSTabView *)aTabView validateDrop:(id <NSDraggingInfo>)sender proposedItem:(NSTabViewItem *)tabViewItem proposedIndex:(NSUInteger)proposedIndex inTabBarView:(MMTabBarView *)tabBarView
{
	return proposedIndex == 0 ? NSDragOperationNone : NSDragOperationAll;
}

- (NSDragOperation)tabView:(NSTabView *)aTabView validateSlideOfProposedItem:(NSTabViewItem *)tabViewItem proposedIndex:(NSUInteger)proposedIndex inTabBarView:(MMTabBarView *)tabBarView
{
	//Do not slide past Articles tab (primary tab at index 0)
	return proposedIndex == 0 ? NSDragOperationNone : NSDragOperationAll;
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
	NSMutableArray *tabLinks = [NSMutableArray arrayWithCapacity:self.countOfTabs];
	NSMutableDictionary *tabTitles = [NSMutableDictionary dictionaryWithCapacity:self.countOfTabs];
	
	for (NSTabViewItem * tabViewItem in self.tabBarControl.tabView.tabViewItems)
	{
		NSView<BaseView> * theView = tabViewItem.identifier;
		NSString * tabLink = theView.viewLink;
		if (tabLink != nil)
		{
			[tabLinks addObject:tabLink];
			if ([theView respondsToSelector:@selector(viewTitle)] && theView.viewTitle != nil)
			{
                tabTitles[tabLink] = theView.viewTitle;
			}
		}
	}

	[[Preferences standardPreferences] setObject:tabLinks forKey:MAPref_TabList];
	[[Preferences standardPreferences] setObject:tabTitles forKey:MAPref_TabTitleDictionary];

	[[Preferences standardPreferences] savePreferences];
}

#pragma mark - new tab creation

/* newTab
 * Create a new empty tab.
 */
-(void)newTab
{
	// Create a new empty tab in the foreground.
	[self createNewTab:nil inBackground:NO];

	// Make the address bar first responder.
	NSView<BaseView> * theView = self.activeTabItemView;
	BrowserPane * browserPane = (BrowserPane *)theView;
	[browserPane activateAddressBar];
}

/* create tab with title and url
 * but do not load the page
 */
-(BrowserPane *)createNewTab:(NSURL *)url withTitle:(NSString *)title inBackground:(BOOL)openInBackgroundFlag
{
	BrowserPane * newBrowserPane = [self createNewTab:url inBackground:openInBackgroundFlag];
	if (title != nil) {
		[self setTabItemViewTitle:newBrowserPane title:title];
        newBrowserPane.viewTitle = title;
	}
	return newBrowserPane;
}

/* create tab with url
 * and load the page.
 */
-(void)createAndLoadNewTab:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag
{
	BrowserPane * newBrowserPane = [self createNewTab:url inBackground:openInBackgroundFlag];
	[newBrowserPane load];
}

/* create tab with url
 * but do not load the page
 */
-(BrowserPane *)createNewTab:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag
{
	BrowserPaneTemplate * newBrowserTemplate = [[BrowserPaneTemplate alloc] init];
	BrowserPane * newBrowserPane;
	if (newBrowserTemplate)
	{
		newBrowserPane = newBrowserTemplate.mainView;
		[self createNewTabWithView:newBrowserPane makeKey:!openInBackgroundFlag];
        newBrowserPane.browser = self;
		//set url but do not load yet
        newBrowserPane.url = url;
	}
	return newBrowserPane;
}

/* createNewTabWithView
 * Create a new tab with the specified view. If makeKey is YES then the new tab is
 * made active, otherwise the current tab stays active.
 */
-(void)createNewTabWithView:(NSView<BaseView> *)newTabView makeKey:(BOOL)keyIt
{
	NSTabViewItem *tabViewItem = [[NSTabViewItem alloc] initWithIdentifier:newTabView];
	tabViewItem.view = newTabView;

	[self.tabBarControl.tabView addTabViewItem:tabViewItem];

	//newly created item will be selected first or last to be selected
	if (self.selectNewItemFirst)
	{
		[self.tabViewOrder addObject:tabViewItem];
	}
	else
	{
		[self.tabViewOrder insertObject:tabViewItem atIndex:0];
	}

	if (keyIt) [self showTabItemView:newTabView];
}

/* dealloc
 * Clean up behind ourselves.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
