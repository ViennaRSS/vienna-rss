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
#import "Constants.h"
#import "DownloadItem.h"
#import "DownloadListCellView.h"
#import "DownloadManager.h"
#import "HelperFunctions.h"
#import "NSWorkspace+OpenWithMenu.h"
#import "Vienna-Swift.h"

@implementation DownloadWindow {
    IBOutlet NSWindow *downloadWindow;
    IBOutlet ExtendedTableView *table;
    IBOutlet NSButton *clearButton;
    NSInteger lastCount;
    NSMenu *openWithMenu;
}

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
	[nc addObserver:self selector:@selector(handleDownloadsChange:) name:MA_Notify_DownloadsListChange object:nil];

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
	[downloadMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"cancel.menuItem",
																	 nil,
																	 NSBundle.mainBundle,
																	 @"Cancel",
																	 @"Title of a menu item")
							action:@selector(cancelDownload:)
					 keyEquivalent:@""];

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
    VNAUserNotificationCenter *center = VNAUserNotificationCenter.current;
    [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<VNAUserNotificationResponse *> *responses) {
        NSMutableArray *identifiers = [NSMutableArray array];
        for (VNAUserNotificationResponse *response in responses) {
            NSString *context = response.userInfo[UserNotificationContextKey];
            if ([context isEqualToString:UserNotificationContextFileDownloadCompleted] ||
                [context isEqualToString:UserNotificationContextFileDownloadFailed]) {
                [identifiers addObject:response.identifier];
            }
        }
        [center removeDeliveredNotificationsWithIdentifiers:identifiers];
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
        [table removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:index]
                     withAnimation:(NSTableViewAnimationEffectFade | NSTableViewAnimationSlideUp)];
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
        [table removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:index]
                     withAnimation:(NSTableViewAnimationEffectFade | NSTableViewAnimationSlideUp)];
	}
}

/* handleDownloadsChange
 * Called when the downloads list has changed. The notification item is the DownloadItem
 * that has been changed. If it has been added to our list, we insert it. Otherwise we
 * reload the table.
 */
-(void)handleDownloadsChange:(NSNotification *)notification
{
	DownloadItem * item = (DownloadItem *)notification.object;
	NSArray * list = [DownloadManager sharedInstance].downloadsList;
	NSUInteger  rowIndex = [list indexOfObject:item];
	if (list.count != lastCount && rowIndex != NSNotFound) {
        NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndex:rowIndex];
        [table insertRowsAtIndexes:rowIndexes
                     withAnimation:(NSTableViewAnimationEffectFade | NSTableViewAnimationSlideDown)];
        [table selectRowIndexes:rowIndexes byExtendingSelection:NO];
        [table scrollRowToVisible:rowIndex];
		lastCount = list.count;
	} else if (rowIndex != NSNotFound) {
        [table reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex]
                         columnIndexes:[NSIndexSet indexSetWithIndex:table.numberOfColumns - 1]];
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

// MARK: - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return DownloadManager.sharedInstance.downloadsList.count;
}

// MARK: - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row
{
    // Retrieve the cell data.
    NSArray *list = DownloadManager.sharedInstance.downloadsList;
    DownloadItem *item = list[row];
    NSString *fileName = item.filename.lastPathComponent.stringByRemovingPercentEncoding;
    if (!fileName) {
        fileName = @"";
    }
    NSString *progressString;
    switch (item.state) {
        case DownloadStateInit:
        case DownloadStateFailed:
        case DownloadStateCancelled:
            break;

        case DownloadStateCompleted: {
            progressString = [NSByteCountFormatter stringFromByteCount:item.size
                                                            countStyle:NSByteCountFormatterCountStyleFile];
            break;
        }

        case DownloadStateStarted: {
            // Filename on top
            // Progress gauge in middle
            // Size gathered so far at bottom
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
            break;
        }
    }

    // Set up the cell view.
    VNADownloadListCellView *cellView =
        [tableView makeViewWithIdentifier:VNADownloadListCellViewIdentifier
                                    owner:self];
    cellView.imageView.image = item.image;
    cellView.textField.stringValue = fileName;
    cellView.fileSizeString = progressString;
    return cellView;
}

- (void)tableView:(NSTableView *)tableView
    didAddRowView:(NSTableRowView *)rowView
           forRow:(NSInteger)row
{
    clearButton.enabled = tableView.numberOfRows > 0;
}

- (void)tableView:(NSTableView *)tableView
    didRemoveRowView:(NSTableRowView *)rowView
              forRow:(NSInteger)row
{
    clearButton.enabled = tableView.numberOfRows > 0;
}

// MARK: - ExtendedTableViewDelegate

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

@end
