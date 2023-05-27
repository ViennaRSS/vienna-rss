//
//  DownloadWindow.m
//  Vienna
//
//  Created by Steve on 10/9/05.
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

#import "DownloadWindow.h"

#import "AppController+Notifications.h"
#import "DownloadItem.h"
#import "DownloadManager.h"
#import "HelperFunctions.h"
#import "ImageAndTextCell.h"
#import "TableViewExtensions.h"
#import "NSWorkspace+OpenWithMenu.h"

@implementation DownloadWindow

/* init
 * Just init the download window.
 */
-(instancetype)init
{
	if ((self = [super initWithWindowNibName:@"Downloads"]) != nil) {
		lastCount = 0;
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
	self.windowFrameAutosaveName = @"downloadWindow";
	downloadWindow.delegate = self;

	// Register to get notified when the download manager's list changes
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleDownloadsChange:) name:@"MA_Notify_DownloadsListChange" object:nil];

	// Set the cell for each row
	ImageAndTextCell * imageAndTextCell;
	NSTableColumn * tableColumn = [table tableColumnWithIdentifier:@"listColumn"];
	imageAndTextCell = [[ImageAndTextCell alloc] init];
	imageAndTextCell.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	imageAndTextCell.textColor = [NSColor darkGrayColor];
	tableColumn.dataCell = imageAndTextCell;	

	// We are the delegate and the datasource
	table.delegate = self;
	table.dataSource = self;
	table.doubleAction = @selector(handleDoubleClick:);
	table.target = self;

	// Create the popup menu
	NSMenu * downloadMenu = [[NSMenu alloc] init];
    
	// Open
	[downloadMenu addItemWithTitle:NSLocalizedString(@"Open", @"Title of a popup menu item") action:@selector(handleDoubleClick:) keyEquivalent:@""];

	// Open With
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open With", @"") action:nil keyEquivalent:@""];
	openWithMenu = [[NSMenu alloc] init];
	openWithMenu.delegate = self;
	[item setSubmenu:openWithMenu];
	[downloadMenu addItem:item];

	// Show in Finder
	[downloadMenu addItemWithTitle:NSLocalizedString(@"Show in Finder", @"Title of a popup menu item") action:@selector(showInFinder:) keyEquivalent:@""];
    
	// Remove from List
	[downloadMenu addItemWithTitle:NSLocalizedString(@"Remove From List", @"Title of a popup menu item") action:@selector(removeFromList:) keyEquivalent:@""];
    
	// Cancel
	[downloadMenu addItemWithTitle:NSLocalizedString(@"Cancel", @"Title of a popup menu item") action:@selector(cancelDownload:) keyEquivalent:@""];

	[downloadMenu setDelegate:self];
	table.menu = downloadMenu;
}

- (void)menuWillOpen:(NSMenu *)menu
{
	
	// Dynamically generate Open With submenu for item
	if (menu == openWithMenu) {
		NSArray * list = [DownloadManager sharedInstance].downloadsList;
		NSInteger index = table.selectedRow;
		if (index != -1) {
			DownloadItem * item = list[index];
			[[NSWorkspace sharedWorkspace] vna_openWithMenuForFile:item.filename target:nil action:nil menu:menu];
		}
	}
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	// Clear relevant notifications when the user views this window.
	NSUserNotificationCenter *center = NSUserNotificationCenter.defaultUserNotificationCenter;
	[center.deliveredNotifications enumerateObjectsUsingBlock:^(NSUserNotification *notification, NSUInteger idx, BOOL *stop) {
		BOOL completed = [notification.userInfo[UserNotificationContextKey] isEqualToString:UserNotificationContextFileDownloadCompleted];
		BOOL failed = [notification.userInfo[UserNotificationContextKey] isEqualToString:UserNotificationContextFileDownloadFailed];

		if (completed || failed) {
			[center removeDeliveredNotification: notification];
		}
	}];
}

/* clearList
 * Remove everything from the list.
 */
-(IBAction)clearList:(id)sender
{
	[[DownloadManager sharedInstance] clearList];
}

/* handleDoubleClick
 * Handle a double click on a row. Use this to launch the file that was
 * downloaded if it has completed.
 */
-(void)handleDoubleClick:(id)sender
{
	NSArray * list = [DownloadManager sharedInstance].downloadsList;
	NSInteger index = table.selectedRow;
	if (index != -1) {
		DownloadItem * item = list[index];
		if (item) {
            NSURL *url = [NSURL fileURLWithPath:item.filename];
            if (url && ![NSWorkspace.sharedWorkspace openURL:url]) {
                runOKAlertSheet(NSLocalizedString(@"Vienna cannot open the file.", nil),
                                NSLocalizedString(@"Vienna cannot open the file \"%@\" because it moved since you downloaded it.", nil),
                                item.filename.lastPathComponent);
            }
		}
	}
}

/* showInFinder
 * Open the Finder with the path set to where the selected item was downloaded.
 */
-(void)showInFinder:(id)sender
{
	NSArray * list = [DownloadManager sharedInstance].downloadsList;
	NSInteger index = table.selectedRow;
	if (index != -1) {
		DownloadItem * item = list[index];
		if (item && [[NSFileManager defaultManager] fileExistsAtPath:item.filename]) {
			if ([[NSWorkspace sharedWorkspace] selectFile:item.filename inFileViewerRootedAtPath:@""] == NO) {
				runOKAlertSheet(NSLocalizedString(@"Vienna cannot show the file.", nil), NSLocalizedString(@"Vienna cannot show the file \"%@\" because it moved since you downloaded it.", nil), item.filename.lastPathComponent);
			}
		} else {
			NSBeep();
		}
	}
}

/* removeFromList
 * Remove the selected item from the list.
 */
-(void)removeFromList:(id)sender
{
	NSArray * list = [DownloadManager sharedInstance].downloadsList;
	NSInteger index = table.selectedRow;
	if (index != -1) {
		DownloadItem * item = list[index];
		[[DownloadManager sharedInstance] removeItem:item];
		[table reloadData];
	}
}

/* cancelDownload
 * Abort the selected download and delete the partially downloaded file.
 */
-(void)cancelDownload:(id)sender
{
	NSArray * list = [DownloadManager sharedInstance].downloadsList;
	NSInteger index = table.selectedRow;
	if (index != -1) {
		DownloadItem * item = list[index];
		[[DownloadManager sharedInstance] cancelItem:item];
		[table reloadData];
	}
}

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of log items.
 */
-(NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	NSInteger itemCount = [DownloadManager sharedInstance].downloadsList.count;
	clearButton.enabled = itemCount > 0;
	return itemCount;
}

/* menuWillAppear [ExtendedTableView delegate]
 * Called when the popup menu is opened on the table. We ensure that the item under the
 * cursor is selected.
 */
-(void)tableView:(ExtendedTableView *)tableView menuWillAppear:(NSEvent *)theEvent
{
	NSInteger row = [table rowAtPoint:[table convertPoint:theEvent.locationInWindow fromView:nil]];
	if (row >= 0) {
		// Select the row under the cursor if it isn't already selected
		if (table.numberOfSelectedRows <= 1) {
			[table selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];
		}
	}
}

/* willDisplayCell [delegate]
 * Catch the table view before it displays a cell.
 */
-(void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([aCell isKindOfClass:[ImageAndTextCell class]]) {
		NSArray * list = [DownloadManager sharedInstance].downloadsList;
		DownloadItem * item = list[rowIndex];

		if (item.image != nil) {
			[aCell setImage:item.image];
		}
		[aCell setTextColor:(rowIndex == aTableView.selectedRow) ? [NSColor whiteColor] : [NSColor controlTextColor]];
	}
}

/* objectValueForTableColumn [datasource]
 * Called by the table view to obtain the object at the specified column and row.
 */
-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSArray * list = [DownloadManager sharedInstance].downloadsList;
	NSAssert(rowIndex >= 0 && rowIndex < [list count], @"objectValueForTableColumn sent an out-of-range rowIndex");
	DownloadItem * item = list[rowIndex];

	// TODO: return item when we have a cell that can parse it. Until then, construct our own data.
	NSString * rawfilename = item.filename.lastPathComponent;
    NSString * filename = [rawfilename stringByRemovingPercentEncoding];
	if (filename == nil) {
		filename = @"";
	}

	// Different layout depending on the state
	NSString * objectString = filename;
	switch (item.state) {
        case DownloadStateInit:
        case DownloadStateFailed:
        case DownloadStateCancelled:
			break;

		case DownloadStateCompleted: {
            NSString *byteCount = [NSByteCountFormatter stringFromByteCount:item.size
                                                                 countStyle:NSByteCountFormatterCountStyleFile];
            objectString = [NSString stringWithFormat:@"%@\n%@", filename, byteCount];
			break;
		}

		case DownloadStateStarted: {
			// Filename on top
			// Progress gauge in middle
			// Size gathered so far at bottom
			NSString * progressString = @"";

			if (item.expectedSize == -1) {
                progressString = [NSByteCountFormatter stringFromByteCount:item.size
                                                                countStyle:NSByteCountFormatterCountStyleFile];
			} else {
                NSString *bytesSoFar = [NSByteCountFormatter stringFromByteCount:item.size
                                                                      countStyle:NSByteCountFormatterCountStyleFile];
                NSString *expectedBytes = [NSByteCountFormatter stringFromByteCount:item.expectedSize
                                                                         countStyle:NSByteCountFormatterCountStyleFile];
                progressString = [NSString stringWithFormat:NSLocalizedString(@"%@ of %@", @"Progress in bytes, e.g. 1 KB of 1 MB"), bytesSoFar, expectedBytes];
			}
			objectString = [NSString stringWithFormat:@"%@\n%@", filename, progressString];
			break;
		}
	}
	
	return objectString;
}

/* handleDownloadsChange
 * Called when the downloads list has changed. The notification item is the DownloadItem
 * that has been changed. If it exists in our list, we update it. Otherwise we add it to
 * the end of the table.
 */
-(void)handleDownloadsChange:(NSNotification *)notification
{
	DownloadItem * item = (DownloadItem *)notification.object;
	NSArray * list = [DownloadManager sharedInstance].downloadsList;
	NSUInteger  rowIndex = [list indexOfObject:item];
	if (list.count != lastCount) {
		[table reloadData];
		if (rowIndex != NSNotFound) {
			NSIndexSet * indexes = [NSIndexSet indexSetWithIndex:rowIndex];
			[table selectRowIndexes:indexes byExtendingSelection:NO];
			[table scrollRowToVisible:rowIndex];
		}
		lastCount = list.count;
	} else {
		[table reloadData];
	}
}

/* dealloc
 * Do away with ourself.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[downloadWindow setDelegate:nil];
	[table setDelegate:nil];
}
@end
