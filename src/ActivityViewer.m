//
//  ActivityViewer.m
//  Vienna
//
//  Created by Steve on Thu Mar 18 2004.
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

#import "ActivityViewer.h"
#import "ActivityLog.h"
#import "AppController.h"
#import "Preferences.h"
#import "SplitViewExtensions.h"

@implementation ActivityViewer

/* init
 * Just init the activity window.
 */
-(id)init
{
	if ((self = [super initWithWindowNibName:@"ActivityViewer"]) != nil)
	{
		allItems = [[ActivityLog defaultLog] allItems];
	}
	return self;
}

/* windowDidLoad
 * Do the things that only make sense after the window file is loaded.
 */
-(void)windowDidLoad
{
	// Work around a Cocoa bug where the window positions aren't saved
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"activityViewer"];
	[activityWindow setDelegate:self];

	// Default font for the details view
	NSFont * detailsFont = [NSFont fontWithName:@"Monaco" size:11.0];
	[activityDetail setFont:detailsFont];

	// Handle double-click on an item
	[activityTable setDoubleAction:@selector(handleDoubleClick:)];

	// Set window title
	[activityWindow setTitle:NSLocalizedString(@"Activity Window", nil)];
	
	// Set localised column headers
	[activityTable localiseHeaderStrings];

	// Restore the split position
	[splitView setLayout:[[Preferences standardPreferences] objectForKey:@"SplitView3Positions"]];	

	// Set up to receive notifications when the activity log changes
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleLogChange:) name:@"MA_Notify_ActivityLogChange" object:nil];	
	[nc addObserver:self selector:@selector(handleDetailChange:) name:@"MA_Notify_ActivityDetailChange" object:nil];	
}

/* windowShouldClose
 * Since we established ourselves as the delegate for the window, we will
 * get the notifications when the window closes.
 */
-(BOOL)windowShouldClose:(NSNotification *)notification
{
	[[Preferences standardPreferences] setObject:[splitView layout] forKey:@"SplitView3Positions"];
	return YES;
}

/* handleDoubleClick
 * Handle double-click.
 */
-(IBAction)handleDoubleClick:(id)sender
{
	int selectedRow = [activityTable selectedRow];
	if (selectedRow >= 0)
	{
		ActivityItem * selectedItem = [allItems objectAtIndex:selectedRow];

		// Name might be a URL if the feed has always been invalid.
		Database * db = [Database sharedManager];
		Folder * folder = [db folderFromName:[selectedItem name]];
		if (folder == nil)
			folder = [db folderFromFeedURL:[selectedItem name]];
		if (folder != nil)
		{
			AppController * controller = APPCONTROLLER;
			[controller selectFolder:[folder itemId]];
		}
	}
}

/* reloadTable
 * Reloads the table with the existing log sorted and with the selection preserved.
 */
-(void)reloadTable
{
	ActivityItem * selectedItem = nil;

	int selectedRow = [activityTable selectedRow];
	if (selectedRow >= 0 && selectedRow < [allItems count])
		selectedItem = [allItems objectAtIndex:selectedRow];

	[[ActivityLog defaultLog] sortUsingDescriptors:[activityTable sortDescriptors]];
	[activityTable reloadData];

	if (selectedItem == nil)
		[activityDetail setString:@""];
	else
	{
		NSUInteger rowToSelect = [allItems indexOfObject:selectedItem];
		if (rowToSelect != NSNotFound)
		{
			NSIndexSet * indexes = [NSIndexSet indexSetWithIndex:rowToSelect];
			[activityTable selectRowIndexes:indexes byExtendingSelection:NO];
		}
		else
		{
			[activityTable deselectAll:nil];
		}
	}
}

/* handleLogChange
 * Handle the notification that is broadcast when the activity log
 * has items added, removed or changed.
 */
-(void)handleLogChange:(NSNotification *)nc
{
	[self reloadTable];
}

/* handleDetailChange
 * Handle the notification that is sent when an item detail is changed.
 */
-(void)handleDetailChange:(NSNotification *)nc
{
	ActivityItem * item = (ActivityItem *)[nc object];
	int selectedRow = [activityTable selectedRow];

	if (selectedRow >= 0 && (item == [allItems objectAtIndex:selectedRow]))
		[activityDetail setString:[item details]];		
}

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of log items.
 */
-(NSUInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [allItems count];
}

/* tableViewSelectionDidChange [delegate]
 * Handle the selection changing in the table view. Update the details portion with the full
 * information for the selected source.
 */
-(void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int selectedRow = [activityTable selectedRow];
	if (selectedRow >= 0 && selectedRow < [allItems count])
	{
		ActivityItem * item = [allItems objectAtIndex:selectedRow];
		[activityDetail setString:[item details]];
	}
}

/* sortDescriptorsDidChange
 * Called to sort the status table by the specified descriptor.
 */
-(void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
	[self reloadTable];
}

/* objectValueForTableColumn [datasource]
 * Called by the table view to obtain the object at the specified column and row.
 */
-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSUInteger)rowIndex
{
	ActivityItem * item = [allItems objectAtIndex:rowIndex];
	return ([aTableColumn identifier]) ? [item valueForKey:[aTableColumn identifier]] : @"";
}

/* dealloc
 * Clean up before we're freed.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[activityWindow setDelegate:nil];
	allItems=nil;
}
@end
