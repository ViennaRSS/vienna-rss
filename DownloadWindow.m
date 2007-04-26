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
#import "DownloadManager.h"
#import "HelperFunctions.h"
#import "ImageAndTextCell.h"

@implementation DownloadWindow

/* init
 * Just init the download window.
 */
-(id)init
{
	if ((self = [super initWithWindowNibName:@"Downloads"]) != nil)
	{
		lastCount = 0;
	}
	return self;
}

/* dealloc
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

/* windowDidLoad
 * Do the things that only make sense after the window file is loaded.
 */
-(void)windowDidLoad
{
	// Work around a Cocoa bug where the window positions aren't saved
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"downloadWindow"];
	[downloadWindow setDelegate:self];

	// Register to get notified when the download manager's list changes
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleDownloadsChange:) name:@"MA_Notify_DownloadsListChange" object:nil];

	// Set the cell for each row
	ImageAndTextCell * imageAndTextCell;
	NSTableColumn * tableColumn = [table tableColumnWithIdentifier:@"listColumn"];
	imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	[imageAndTextCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[imageAndTextCell setTextColor:[NSColor darkGrayColor]];
	[tableColumn setDataCell:imageAndTextCell];	

	// We are the delegate and the datasource
	[table setDelegate:self];
	[table setDataSource:self];
	[table setDoubleAction:@selector(handleDoubleClick:)];
	[table setTarget:self];

	// Create the popup menu
	NSMenu * downloadMenu = [[NSMenu alloc] init];
	[downloadMenu addItemWithTitle:NSLocalizedString(@"Open", nil) action:@selector(handleDoubleClick:) keyEquivalent:@""];
	[downloadMenu addItemWithTitle:NSLocalizedString(@"Show in Finder", nil) action:@selector(showInFinder:) keyEquivalent:@""];
	[downloadMenu addItemWithTitle:NSLocalizedString(@"Remove From List", nil) action:@selector(removeFromList:) keyEquivalent:@""];
	[downloadMenu addItemWithTitle:NSLocalizedString(@"Cancel", nil) action:@selector(cancelDownload:) keyEquivalent:@""];


	[table setMenu:downloadMenu];
	[downloadMenu release];

	// Set Clear button caption
	[clearButton setTitle:NSLocalizedString(@"ClearButton", nil)];

	// Set the window title
	[downloadWindow setTitle:NSLocalizedString(@"Downloads", nil)];
}

/* clearList
 * Remove everything from the list.
 */
-(IBAction)clearList:(id)sender
{
	[[DownloadManager sharedInstance] clearList];
}

/* menuWillAppear
 * Called when the popup menu is opened on the table. We ensure that the item under the
 * cursor is selected.
 */
-(void)tableView:(ExtendedTableView *)tableView menuWillAppear:(NSEvent *)theEvent
{
	int row = [table rowAtPoint:[table convertPoint:[theEvent locationInWindow] fromView:nil]];
	if (row >= 0)
	{
		// Select the row under the cursor if it isn't already selected
		if ([table numberOfSelectedRows] <= 1)
			[table selectRow:row byExtendingSelection:NO];
	}
}

/* handleDoubleClick
 * Handle a double click on a row. Use this to launch the file that was
 * downloaded if it has completed.
 */
-(void)handleDoubleClick:(id)sender
{
	NSArray * list = [[DownloadManager sharedInstance] downloadsList];
	int index = [table selectedRow];
	if (index != -1)
	{
		DownloadItem * item = [list objectAtIndex:index];
		if (item && [item state] == DOWNLOAD_COMPLETED)
		{
			if ([[NSWorkspace sharedWorkspace] openFile:[item filename]] == NO)
				runOKAlertSheet(@"Vienna cannot open the file title", @"Vienna cannot open the file body", [[item filename] lastPathComponent]);
		}
	}
}

/* showInFinder
 * Open the Finder with the path set to where the selected item was downloaded.
 */
-(void)showInFinder:(id)sender
{
	NSArray * list = [[DownloadManager sharedInstance] downloadsList];
	int index = [table selectedRow];
	if (index != -1)
	{
		DownloadItem * item = [list objectAtIndex:index];
		if (item && [item state] == DOWNLOAD_COMPLETED)
		{
			if ([[NSWorkspace sharedWorkspace] selectFile:[item filename] inFileViewerRootedAtPath:@""] == NO)
				runOKAlertSheet(@"Vienna cannot show the file title", @"Vienna cannot show the file body", [[item filename] lastPathComponent]);
		}
	}
}

/* removeFromList
 * Remove the selected item from the list.
 */
-(void)removeFromList:(id)sender
{
	NSArray * list = [[DownloadManager sharedInstance] downloadsList];
	int index = [table selectedRow];
	if (index != -1)
	{
		DownloadItem * item = [list objectAtIndex:index];
		[[DownloadManager sharedInstance] removeItem:item];
		[table reloadData];
	}
}

/* cancelDownload
 * Abort the selected download and delete the partially downloaded file.
 */
-(void)cancelDownload:(id)sender
{
	NSArray * list = [[DownloadManager sharedInstance] downloadsList];
	int index = [table selectedRow];
	if (index != -1)
	{
		DownloadItem * item = [list objectAtIndex:index];
		[[DownloadManager sharedInstance] cancelItem:item];
		[table reloadData];
	}
}
	

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of log items.
 */
-(int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	int itemCount = [[[DownloadManager sharedInstance] downloadsList] count];
	[clearButton setEnabled:itemCount > 0];
	return itemCount;
}

/* willDisplayCell [delegate]
 * Catch the table view before it displays a cell.
 */
-(void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ([aCell isKindOfClass:[ImageAndTextCell class]])
	{
		NSArray * list = [[DownloadManager sharedInstance] downloadsList];
		DownloadItem * item = [list objectAtIndex:rowIndex];

		if ([item image] != nil)
			[aCell setImage:[item image]];
		[aCell setTextColor:(rowIndex == [aTableView selectedRow]) ? [NSColor whiteColor] : [NSColor darkGrayColor]];
	}
}

/* objectValueForTableColumn [datasource]
 * Called by the table view to obtain the object at the specified column and row.
 */
-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSArray * list = [[DownloadManager sharedInstance] downloadsList];
	NSAssert(rowIndex >= 0 && rowIndex < [list count], @"objectValueForTableColumn sent an out-of-range rowIndex");
	DownloadItem * item = [list objectAtIndex:rowIndex];

	// TODO: return item when we have a cell that can parse it. Until then, construct our
	// own data.
	NSString * filename = [[item filename] lastPathComponent];
	if (filename == nil)
		filename = @"";

	// Different layout depending on the state
	NSString * objectString = filename;
	switch ([item state])
	{
		case DOWNLOAD_INIT:
			break;

		case DOWNLOAD_COMPLETED: {
			// Filename on top
			// Final size of file at bottom.
			double size = [item size];
			NSString * sizeString = @"";

			if (size > 1024 * 1024)
				sizeString = [NSString stringWithFormat:NSLocalizedString(@"%.1f MB", nil), size / (1024 * 1024)];
			else if (size > 1024)
				sizeString = [NSString stringWithFormat:NSLocalizedString(@"%.1f KB", nil), size / 1024];
			else
				sizeString = [NSString stringWithFormat:NSLocalizedString(@"%.1f bytes", nil), size];
			objectString = [NSString stringWithFormat:@"%@\n%@", filename, sizeString];
			break;
		}

		case DOWNLOAD_STARTED: {
			// Filename on top
			// Progress gauge in middle
			// Size gathered so far at bottom
			NSString * progressString = @"";
			double expectedSize = [item expectedSize];
			double sizeSoFar = [item size];

			if (expectedSize == -1)
			{
				// Expected size unknown - indeterminate progress gauge
				if (sizeSoFar > 1024 * 1024)
					progressString = [NSString stringWithFormat:NSLocalizedString(@"%.1f MB", nil), sizeSoFar / (1024 * 1024)];
				else if (sizeSoFar > 1024)
					progressString = [NSString stringWithFormat:NSLocalizedString(@"%.1f KB", nil), sizeSoFar / 1024];
				else
					progressString = [NSString stringWithFormat:NSLocalizedString(@"%.1f bytes", nil), sizeSoFar];
			}
			else
			{
				if (expectedSize > 1024 * 1024)
					progressString = [NSString stringWithFormat:NSLocalizedString(@"%.1f of %.1f MB", nil), sizeSoFar / (1024 * 1024), expectedSize / (1024 * 1024)];
				else if (expectedSize > 1024)
					progressString = [NSString stringWithFormat:NSLocalizedString(@"%.1f of %.1f KB", nil), sizeSoFar / 1024, expectedSize / 1024];
				else
					progressString = [NSString stringWithFormat:NSLocalizedString(@"%.1f of %.1f bytes", nil), sizeSoFar, expectedSize];
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
	DownloadItem * item = (DownloadItem *)[notification object];
	NSArray * list = [[DownloadManager sharedInstance] downloadsList];
	int rowIndex = [list indexOfObject:item];
	if ([list count] != lastCount || rowIndex == NSNotFound)
	{
		[table reloadData];
		[table selectRow:rowIndex byExtendingSelection:NO];
		[table scrollRowToVisible:rowIndex];
		lastCount = [list count];
	}
	else if (rowIndex >= 0 && rowIndex < lastCount)
	{
		NSRect rectRow = [table rectOfRow:rowIndex];
		[table drawRow:rowIndex clipRect:rectRow];
		[table display];
	}
}
@end
