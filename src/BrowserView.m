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
#import <PSMTabBarControl/PSMTabBarControl.h>
#import <PSMTabBarControl/PSMRolloverButton.h>
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

@interface BrowserView ()

@property (weak, nonatomic) IBOutlet NSTabView *tabView;
@property (weak, nonatomic) IBOutlet DisclosureView *tabBarDisclosureView;
//queue for tab view items to select when current item is closed
@property NSMutableArray<NSTabViewItem *> *tabViewOrder;
//set to true to enable new tab selection behavior
@property BOOL selectPreviousOnClose;
@property BOOL selectNewItemFirst;
@end

@implementation BrowserView

-(void)awakeFromNib
{
	[[self.tabView tabViewItemAtIndex:0] setLabel:NSLocalizedString(@"Articles", nil)];

	//TODO: make this a preference
	self.selectPreviousOnClose = true;
	self.selectNewItemFirst = true;

	//do not initialize tabview order to restore default behavior
	if (self.selectPreviousOnClose)
	{
		self.tabViewOrder = [NSMutableArray array];
	}

	//Metal is the default
	[tabBarControl setStyleNamed:@"Unified"];
	
	[tabBarControl setHideForSingleTab:YES];
	[tabBarControl setUseOverflowMenu:YES];
	[tabBarControl setAllowsBackgroundTabClosing:YES];
	[tabBarControl setAutomaticallyAnimates:NO];
	tabBarControl.cellMinWidth = 60.0;
	tabBarControl.cellMaxWidth = 350.0;

	[tabBarControl setShowAddTabButton:YES];
	tabBarControl.addTabButton.target = NSApp.delegate;
	tabBarControl.addTabButton.action = @selector(newTab:);
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
			//most recently selected item moves to front of queue
			[self.tabViewOrder removeObject:item];
			[self.tabView removeTabViewItem:item];
		}
	}
}

/* closeTab
 * Close the specified tab unless it is the primary tab, in which case
 * we do nothing.
 */
-(void)closeTabItemView:(NSView *)tabItemView
{
	NSTabViewItem *tabViewItem = [self.tabView tabViewItemWithIdentifier:tabItemView];
	[self closeTab:tabViewItem];
}

- (BOOL)tabView:(NSTabView *)inTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	[self closeTab:tabViewItem];
	return NO;
}

-(void)closeTab:(NSTabViewItem *)tabViewItem
{
	if (tabViewItem.identifier != primaryTabItemView)
	{
		[self.tabViewOrder removeObject:tabViewItem];
		[self.tabView selectTabViewItem:self.tabViewOrder.lastObject];
		[self.tabView removeTabViewItem:tabViewItem];
	}
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
	if (inTabViewItem.identifier != primaryTabItemView)
	{
		[self.tabViewOrder removeObject:self.tabView.selectedTabViewItem];
		[self.tabViewOrder addObject:self.tabView.selectedTabViewItem];
	}
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TabCountChanged" object:nil];
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
- (BOOL)tabView:(NSTabView *)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem fromTabBar:(PSMTabBarControl *)tabBarControl
{
	return YES;
}

/* tabView:shouldDropTabViewItem:inTabBar:
 * Should a tab view item drop be accepted?
 */
- (BOOL)tabView:(NSTabView *)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl
{
	return YES;
}

/* tabView:didDropTabViewItem:inTabBar:
 * A drag & drop operation of a tab view item was completed.
 */
- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl
{
}

/* tabView:shouldAllowTabViewItem:toLeaveTabBar:
 * Should a tab view item be allowed to leave the tab bar?
 */
- (BOOL)tabView:(NSTabView *)aTabView shouldAllowTabViewItem:(NSTabViewItem *)tabViewItem toLeaveTabBar:(PSMTabBarControl *)tabBarControl;
{
	return NO;
}

- (void)tabView:(NSTabView *)aTabView tabBarDidHide:(PSMTabBarControl *)tabBarControl {
    [self.tabBarDisclosureView collapse:YES];
}

- (void)tabView:(NSTabView *)aTabView tabBarDidUnhide:(PSMTabBarControl *)tabBarControl {
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
