//
//  ActivityPanelController.m
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

#import "ActivityPanelController.h"

#import "ActivityItem.h"
#import "ActivityLog.h"
#import "Database.h"

@interface ActivityPanelController ()

@property (weak, nonatomic) IBOutlet NSTableView *tableView;
@property (weak, nonatomic) IBOutlet NSTextView *textView;

@property (nonatomic) ActivityLog *activityLog;

@end

@implementation ActivityPanelController

#pragma mark Initialization

- (instancetype)init {
    return [self initWithWindowNibName:@"ActivityViewer"];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark Window life cycle

- (void)windowDidLoad {
    [super windowDidLoad];

    // Set the activity log.
    self.activityLog = [ActivityLog defaultLog];

    // Set up to receive notifications when a status changes.
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(activityItemStatusDidUpdate:)
                                               name:activityItemStatusUpdatedNotification
                                             object:nil];
    // Set up to receive notifications when the activity log changes.
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(activityItemDidUpdateDetails:)
                                               name:activityItemDetailsUpdatedNotification
                                             object:nil];
}

#pragma mark Table-view actions

/**
 Sends a message to the delegate that contains a folder for the selected item.

 @param selectedItem The selected item in the table view.
 */
- (IBAction)showFolderForItem:(ActivityItem *)selectedItem {
    Folder *folder = [[Database sharedManager] folderFromName:selectedItem.name];

    // If no folder could be resolved by name, try a URL.
    if (!folder) {
        folder = [[Database sharedManager] folderFromFeedURL:selectedItem.name];
    }

    // Send the folder to the delegate.
    if (folder) {
        [self.delegate activityPanelControllerDidSelectFolder:folder];
    }
}

#pragma mark Table-view notification handlers

/*
 When the details of an item in the activity log change, update the detail view.
 */
- (void)activityItemDidUpdateDetails:(NSNotification *)notification {
    ActivityItem *item = notification.object;
    NSInteger selectedRow = self.tableView.selectedRow;

    if (selectedRow >= 0 && item == self.activityLog.allItems[selectedRow]) {
        self.textView.string = item.details;
    }
}

/*
 When the status of an item gets added, removed or changed,
 reload the data with the log sorted and with the selection preserved.
 */
- (void)activityItemStatusDidUpdate:(NSNotification *)notification {
    ActivityItem * selectedItem = nil;

    NSInteger selectedRow = self.tableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.activityLog.allItems.count) {
        selectedItem = self.activityLog.allItems[selectedRow];
    }

    [[ActivityLog defaultLog] sortUsingDescriptors:self.tableView.sortDescriptors];
    self.activityLog = [ActivityLog defaultLog];

    if (selectedItem == nil) {
        self.textView.string = @"";
    } else {
        NSUInteger rowToSelect = [self.activityLog.allItems indexOfObject:selectedItem];
        if (rowToSelect != NSNotFound) {
            NSIndexSet * indexes = [NSIndexSet indexSetWithIndex:rowToSelect];
            [self.tableView selectRowIndexes:indexes byExtendingSelection:NO];
        } else {
            [self.tableView deselectAll:nil];
        }
    }
}

@end
