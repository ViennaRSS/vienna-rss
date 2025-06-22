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
    IBOutlet NSTableView *table;
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

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

/* windowDidLoad
 * Do the things that only make sense after the window file is loaded.
 */
-(void)windowDidLoad
{
	// Work around a Cocoa bug where the window positions aren't saved
	[self setShouldCascadeWindows:NO];
	self.windowFrameAutosaveName = @"downloadWindow";
    self.window.delegate = self;

	// Register to get notified when the download manager's list changes
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleDownloadsChange:) name:MA_Notify_DownloadsListChange object:nil];

	// We are the delegate and the datasource
	table.delegate = self;
	table.dataSource = self;
	table.doubleAction = @selector(openFile:);
	table.target = self;

	// Create the popup menu
	NSMenu * downloadMenu = [[NSMenu alloc] init];
    
	// Open
	[downloadMenu addItemWithTitle:NSLocalizedString(@"Open", @"Title of a popup menu item") action:@selector(openFile:) keyEquivalent:@""];

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

	table.menu = downloadMenu;
}

// MARK: Actions

/* clearList
 * Remove everything from the list.
 */
-(IBAction)clearList:(id)sender
{
	[[DownloadManager sharedInstance] clearList];
}

/* openFile
 * Handle a double click on a row. Use this to launch the file that was
 * downloaded if it has completed.
 */
- (void)openFile:(id)sender
{
    DownloadItem *item = [self downloadItemForClickedRow];
    if (!item) {
        return;
    }

    NSURL *url = [NSURL fileURLWithPath:item.filename];
    if (url && ![NSWorkspace.sharedWorkspace openURL:url]) {
        runOKAlertSheet(NSLocalizedString(@"Vienna cannot open the file.", nil),
                        NSLocalizedString(@"Vienna cannot open the file \"%@\" because it moved "
                                           "since you downloaded it.",
                                          nil),
                        item.filename.lastPathComponent);
    }
}

/* showInFinder
 * Open the Finder with the path set to where the selected item was downloaded.
 */
- (void)showInFinder:(id)sender
{
    DownloadItem *item = [self downloadItemForClickedRow];
    if (!item) {
        return;
    }

    if (item && [NSFileManager.defaultManager fileExistsAtPath:item.filename]) {
        if ([NSWorkspace.sharedWorkspace selectFile:item.filename
                           inFileViewerRootedAtPath:@""] == NO) {
            runOKAlertSheet(NSLocalizedString(@"Vienna cannot show the file.", nil),
                            NSLocalizedString(@"Vienna cannot show the file \"%@\" because it "
                                               "moved since you downloaded it.",
                                              nil),
                            item.filename.lastPathComponent);
        }
    } else {
        NSBeep();
    }
}

/* removeFromList
 * Remove the selected item from the list.
 */
- (void)removeFromList:(id)sender
{
    DownloadItem *item = [self downloadItemForClickedRow];
    if (!item) {
        return;
    }

    [DownloadManager.sharedInstance removeItem:item];
    [table removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:table.clickedRow]
                 withAnimation:(NSTableViewAnimationEffectFade | NSTableViewAnimationSlideUp)];
}

/* cancelDownload
 * Abort the selected download and delete the partially downloaded file.
 */
- (void)cancelDownload:(id)sender
{
    DownloadItem *item = [self downloadItemForClickedRow];
    if (!item) {
        return;
    }

    [DownloadManager.sharedInstance cancelItem:item];
    [table removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:table.clickedRow]
                 withAnimation:(NSTableViewAnimationEffectFade | NSTableViewAnimationSlideUp)];
}

// MARK: Notifications

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

// MARK: Helper methods

- (nullable DownloadItem *)downloadItemForClickedRow
{
    NSInteger clickedRow = table.clickedRow;
    if (clickedRow == -1) {
        return nil;
    }

    NSArray *list = DownloadManager.sharedInstance.downloadsList;
    return list[clickedRow];
}

// MARK: - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu
{
    // Dynamically generate Open With submenu for item
    if (menu != openWithMenu) {
        return;
    }

    DownloadItem *item = [self downloadItemForClickedRow];
    if (item) {
        [NSWorkspace.sharedWorkspace vna_openWithMenuForFile:item.filename
                                                      target:nil
                                                      action:NULL
                                                        menu:menu];
    }
}

// MARK: - NSMenuItemValidation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    DownloadItem *item = [self downloadItemForClickedRow];
    if (!item) {
        return NO;
    }

    SEL action = menuItem.action;
    DownloadState state = item.state;
    if (action == @selector(openFile:) || action == @selector(showInFinder:)) {
        return state == DownloadStateCompleted;
    } else if (action == @selector(removeFromList:)) {
        return state != DownloadStateInit && state != DownloadStateStarted;
    } else if (action == @selector(cancelDownload:)) {
        return state == DownloadStateInit || state == DownloadStateStarted;
    }

    return YES;
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

// MARK: - NSWindowDelegate

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

@end
