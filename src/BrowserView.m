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

#import "BrowserView.h"
#import "Preferences.h"
#import "Constants.h"
#import <MMTabBarView/MMTabBarView.h>
#import "AppController.h"
#import "DisclosureView.h"

@interface NSTabView (BrowserViewAdditions)
	-(NSTabViewItem *)tabViewItemWithIdentifier:(id)identifier;
@end

@implementation NSTabView (BrowserViewAdditions)

/* tabViewItemWithIdentifier
 * Returns the tab view item that matches the specified identifier.
 */
-(NSTabViewItem *)tabViewItemWithIdentifier:(id)identifier
{
	NSInteger i = [self indexOfTabViewItemWithIdentifier:identifier];
	return (i != NSNotFound ? [self tabViewItemAtIndex:i] : nil);
}
@end

@interface BrowserView () <MMTabBarViewDelegate>

@property (weak, nonatomic) IBOutlet NSTabView *tabView;
@property (weak, nonatomic) IBOutlet DisclosureView *tabBarDisclosureView;
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
	self.selectPreviousOnClose = false;
	//only works if selectpreviousonclose is true
	self.selectNewItemFirst = false;
	//only works if selectpreviousonclose is false
	self.selectRightItemFirst = true;
	//only relevant if (selectpreviousonclose is true) or (selectrightitemfirst is false)
	self.canJumpToArticles = false;

	[[self.tabView tabViewItemAtIndex:0] setLabel:NSLocalizedString(@"Articles", nil)];

	self.tabViewOrder = [NSMutableArray array];

	//Metal is the default
	[tabBarControl setStyleNamed:@"Sierra"];

	[tabBarControl setHideForSingleTab:YES];
	[tabBarControl setUseOverflowMenu:YES];
	[tabBarControl setAllowsBackgroundTabClosing:YES];
	[tabBarControl setAutomaticallyAnimates:NO];
	//tabBarControl.cellMinWidth = 60.0;
	//tabBarControl.cellMaxWidth = 350.0;

	[tabBarControl setShowAddTabButton:YES];
}

/* stringForToolTip
 * Returns the tooltip for the tab specified by the userData object. This is the tab's full title which
 * may have been truncated for display.
//XXX Not being used...
 */
-(NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
	return [self.tabView tabViewItemWithIdentifier:(__bridge NSView *)userData].label;
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
		item = [self.tabView tabViewItemAtIndex:0];
	}
	else
	{
		item = [self.tabView tabViewItemWithIdentifier:primaryTabItemView];
	}
	
	item.identifier = newPrimaryTabItemView;
	item.view = newPrimaryTabItemView;
	
	primaryTabItemView = newPrimaryTabItemView;
	
	[primaryTabItemView setNeedsDisplay:YES];
	[self setActiveTabToPrimaryTab];
	//this call seems to be necessary manually here, no delegate call
	//maybe setPrimaryTabItemView is called earlier than the delegate IBOutlet setup.
	[self tabView:self.tabView didSelectTabViewItem:item];
}

/* activeTabItemView
 * Returns the view associated with the active tab.
 */
-(NSView<BaseView> *)activeTabItemView
{
	return self.tabView.selectedTabViewItem.identifier;
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

/* createNewTabWithView
 * Create a new tab with the specified view. If makeKey is YES then the new tab is
 * made active, otherwise the current tab stays active.
 */
-(void)createNewTabWithView:(NSView<BaseView> *)newTabView makeKey:(BOOL)keyIt
{
	NSTabViewItem *tabViewItem = [[NSTabViewItem alloc] initWithIdentifier:newTabView];
	tabViewItem.view = newTabView;

	[self.tabView addTabViewItem:tabViewItem];

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

/* setTabTitle
 * Sets the title of the specified tab then redraws the tab bar.
 */
-(void)setTabItemViewTitle:(NSView *)inTabView title:(NSString *)newTitle
{
	[self.tabView tabViewItemWithIdentifier:inTabView].label = newTitle;
}

/* tabTitle
 * Returns the title of the specified tab. May be an empty string.
 */
-(NSString *)tabItemViewTitle:(NSView *)tabItemView
{
	return [self.tabView tabViewItemWithIdentifier:tabItemView].label;
}

/* closeAllTabs
 * Close all tabs.
 */
-(void)closeAllTabs
{
	NSInteger count = self.tabView.numberOfTabViewItems;
	NSInteger i;
	for ((i = (count - 1)); i >= 0; i--) {
		NSTabViewItem * item = [self.tabView tabViewItemAtIndex:i];
		if (item.identifier != primaryTabItemView)
		{
			[self.tabViewOrder removeObject:item];
			[self.tabView removeTabViewItem:item];
		}
	}
}

-(void)closeTabItemView:(NSView *)tabItemView
{
	NSTabViewItem *tabViewItem = [self.tabView tabViewItemWithIdentifier:tabItemView];
	[self closeTab:tabViewItem];
}

-(void)closeTab:(NSTabViewItem *)tabViewItem
{
	//remove closing tab from tab order
	[self.tabViewOrder removeObject:tabViewItem];

	if (self.tabView.selectedTabViewItem == tabViewItem)
	{
		if (self.selectPreviousOnClose) {
			//open most recently opened tab
			[self.tabView selectTabViewItem:self.tabViewOrder.lastObject];
		}
		else if (self.selectRightItemFirst
				 && [self.tabView indexOfTabViewItem:tabViewItem] < self.tabView.numberOfTabViewItems - 1)
		{
			//since tab is not the last, select the one right of it
			[self.tabView selectTabViewItemAtIndex:[self.tabView indexOfTabViewItem:tabViewItem] + 1];
		}
		else if (self.canJumpToArticles == false
				 && [self.tabView indexOfTabViewItem:tabViewItem] == 1
				 && self.tabView.numberOfTabViewItems > 2)
		{
			//open tab to the right instead of article tab
			[self.tabView selectTabViewItemAtIndex:2];
		}
	}

	//close tab to be closed
	[self.tabView removeTabViewItem:tabViewItem];
}

/* countOfTabs
 * Returns the total number of tabs.
 */
-(NSInteger)countOfTabs
{
	return self.tabView.numberOfTabViewItems;
}

/* showTabVew
 * Makes the specified tab active if not already and post a notification.
 */
-(void)showTabItemView:(NSView *)theTabView
{
	if ([self.tabView tabViewItemWithIdentifier:theTabView]) {
		[self.tabView selectTabViewItemWithIdentifier:theTabView];
	}
}

/* showPreviousTab
 * Switch to the previous tab in the view order. Wrap round to the end
 * if we're at the beginning.
 */
-(void)showPreviousTab
{
	if ([self.tabView indexOfTabViewItem:self.tabView.selectedTabViewItem] == 0)
		[self.tabView selectLastTabViewItem:self];
	else
		[self.tabView selectPreviousTabViewItem:self];
}

/* showNextTab
 * Switch to the next tab in the tab order. Wrap round to the beginning
 * if we're at the end.
 */
-(void)showNextTab
{
	if ([self.tabView indexOfTabViewItem:self.tabView.selectedTabViewItem] == (self.tabView.numberOfTabViewItems - 1))
		[self.tabView selectFirstTabViewItem:self];
	else
		[self.tabView selectNextTabViewItem:self];
}

/* didSelectTabViewItem
 * Called when the tab is changed.
 */
-(void)tabView:(NSTabView *)inTabView didSelectTabViewItem:(NSTabViewItem *)inTabViewItem
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TabChanged" object:inTabViewItem.identifier];
	if (self.canJumpToArticles || inTabViewItem.identifier != primaryTabItemView)
	{
		[self.tabViewOrder removeObject:self.tabView.selectedTabViewItem];
		[self.tabViewOrder addObject:self.tabView.selectedTabViewItem];
	}
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TabCountChanged" object:nil];
}

#pragma mark - TabBarDelegate

-(void)addNewTabToTabView:(NSTabView *)aTabView {
	[NSApp.delegate performSelector:@selector(newTab:) withObject:aTabView];
}

- (BOOL)tabView:(NSTabView *)inTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	[self closeTab:tabViewItem];
	return NO;
}

/* disableTabCloseForTabViewItem
 * Returns whether the tab close should be disabled for the specified item. We disable the close button
 * for the primary item.
 */
-(BOOL)tabView:(NSTabView *)aTabView disableTabCloseForTabViewItem:(NSTabViewItem *)tabViewItem
{
	return (tabViewItem.identifier == primaryTabItemView);
}

/* tabView:shouldDragTabViewItem:fromTabBar:
 * Should a tab view item be allowed to be dragged?
 */
- (BOOL)tabView:(NSTabView *)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem fromTabBar:(MMTabBarView *)tabBarControl
{
	return YES;
}

/* tabView:shouldDropTabViewItem:inTabBar:
 * Should a tab view item drop be accepted?
 */
- (BOOL)tabView:(NSTabView *)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(MMTabBarView *)tabBarControl
{
	return YES;
}

/* tabView:didDropTabViewItem:inTabBar:
 * A drag & drop operation of a tab view item was completed.
 */
- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(MMTabBarView *)tabBarControl
{
}

/* tabView:shouldAllowTabViewItem:toLeaveTabBar:
 * Should a tab view item be allowed to leave the tab bar?
 */
- (BOOL)tabView:(NSTabView *)aTabView shouldAllowTabViewItem:(NSTabViewItem *)tabViewItem toLeaveTabBar:(MMTabBarView *)tabBarControl;
{
	return NO;
}

- (void)tabView:(NSTabView *)aTabView tabBarDidHide:(MMTabBarView *)tabBarControl {
    [self.tabBarDisclosureView collapse:YES];
}

- (void)tabView:(NSTabView *)aTabView tabBarDidUnhide:(MMTabBarView *)tabBarControl {
    [self.tabBarDisclosureView disclose:YES];
}

#pragma mark -
/* saveOpenTabs
 * Persist the URLs of each open tab to the preferences so they can be
 * restored when we reload.
 */
-(void)saveOpenTabs
{
	NSMutableArray *tabLinks = [NSMutableArray arrayWithCapacity:self.countOfTabs];
	NSMutableDictionary *tabTitles = [NSMutableDictionary dictionaryWithCapacity:self.countOfTabs];
	
	for (NSTabViewItem * tabViewItem in self.tabView.tabViewItems)
	{
		NSView<BaseView> * theView = tabViewItem.identifier;
		NSString * tabLink = theView.viewLink;
		if (tabLink != nil)
		{
			[tabLinks addObject:tabLink];
			if ([theView respondsToSelector:@selector(viewTitle)] && theView.viewTitle != nil)
			{
				[tabTitles setObject:theView.viewTitle forKey:tabLink];
			}
		}
	}

	[[Preferences standardPreferences] setObject:tabLinks forKey:MAPref_TabList];
	[[Preferences standardPreferences] setObject:tabTitles forKey:MAPref_TabTitleDictionary];

	[[Preferences standardPreferences] savePreferences];
}

/* dealloc
 * Clean up behind ourselves.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
