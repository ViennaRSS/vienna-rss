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

/* windowDidLoad
 * Do the things that only make sense after the window file is loaded.
 */
-(void)windowDidLoad
{
	// Work around a Cocoa bug where the window positions aren't saved
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"downloadWindow"];
	[window setDelegate:self];

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
	
	// Set the window title
	[window setTitle:NSLocalizedString(@"Downloads", nil)];
}

/* clearList
 * Remove everything from the list.
 */
-(IBAction)clearList:(id)sender
{
	[[DownloadManager sharedInstance] clearList];
}

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of log items.
 */
-(int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	lastCount = [[[DownloadManager sharedInstance] downloadsList] count];
	[clearButton setEnabled:lastCount > 0];
	return lastCount;
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
			NSString * suffixString = @"bytes";
			if (size > 1024 * 1024)
			{
				// Work in MBs if we're larger than 1Mb.
				size /= 1024 * 1024;
				suffixString = @"MB";
			}
			else if (size > 1024)
			{
				size /= 1024;
				suffixString = @"KB";
			}
			objectString = [NSString stringWithFormat:@"%@\n%.1f %@", filename, size, suffixString];
			break;
		}
			
		case DOWNLOAD_STARTED: {
			// Filename on top
			// Progress gauge in middle
			// Size gathered so far at bottom
			double expectedSize = [item expectedSize];
			double sizeSoFar = [item size];
			NSString * suffixString = @"bytes";
			if (expectedSize > 1024 * 1024)
			{
				// Work in MBs if we're larger than 1Mb.
				expectedSize /= 1024 * 1024;
				sizeSoFar /= 1024 * 1024;
				suffixString = @"MB";
			}
			else if (expectedSize > 1024)
			{
				expectedSize /= 1024;
				sizeSoFar /= 1024;
				suffixString = @"KB";
			}
			objectString = [NSString stringWithFormat:@"%@\n%.1f of %.1f %@", filename, sizeSoFar, expectedSize, suffixString];
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
	// NOTE: item MAY be nil.
//	DownloadItem * item = (DownloadItem *)[notification object];
	NSArray * list = [[DownloadManager sharedInstance] downloadsList];
	if ([list count] != lastCount)
		[table reloadData];
	else
	{
		[table reloadData];
//		int rowIndex = [list indexOfObject:item];
//		if (rowIndex >= 0 && rowIndex < lastCount)
//		{
//			NSRect rectRow = [table rectOfRow:rowIndex];
//			[table drawRect:rectRow];
//		}
	}
}
@end
