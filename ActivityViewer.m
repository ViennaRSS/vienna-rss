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
#import "SplitViewExtensions.h"

@implementation ActivityViewer

/* init
 * Just init the activity window.
 */
-(id)init
{
	return [super initWithWindowNibName:@"ActivityViewer"];
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
	[detailsFont release];
	
	// Restore the split position
	[splitView loadLayoutWithName:@"SplitView3Positions"];	

	// Set up to receive notifications when the activity log changes
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLogChange:) name:@"MA_Notify_ActivityLogChange" object:nil];	
}

/* windowShouldClose
 * Since we established ourselves as the delegate for the window, we will
 * get the notifications when the window closes.
 */
-(BOOL)windowShouldClose:(NSNotification *)notification
{
	[splitView storeLayoutWithName:@"SplitView3Positions"];
	return YES;
}	

/* handleLogChange
 * Handle the notification that is broadcast when the activity log
 * has items added, removed or changed.
 */
-(void)handleLogChange:(NSNotification *)nc
{
	[activityTable reloadData];
}

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of messages in the current folder.
 */
-(int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[[ActivityLog defaultLog] allItems] count];
}

/* tableViewSelectionDidChange [delegate]
 * Handle the selection changing in the table view. Update the details portion with the full
 * information for the selected source.
 */
-(void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	unsigned int selectedRow = [activityTable selectedRow];
	NSArray * log = [[ActivityLog defaultLog] allItems];
	if (selectedRow >= 0 && selectedRow < [log count])
	{
		ActivityItem * item = [log objectAtIndex:selectedRow];
		[activityDetail setString:[item details]];
	}
}

/* objectValueForTableColumn [datasource]
 * Called by the table view to obtain the object at the specified column and row. This is
 * called often so it needs to be fast.
 */
-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSArray * log = [[ActivityLog defaultLog] allItems];
	ActivityItem * item = [log objectAtIndex:rowIndex];
	if ([[aTableColumn identifier] isEqualToString:@"source"])
	{
		return [item name];
	}
	if ([[aTableColumn identifier] isEqualToString:@"status"])
	{
		return [item status];
	}
	return @"";
}
@end
