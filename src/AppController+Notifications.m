//
//  AppController+Notifications.m
//  Vienna
//
//  Copyright 2017
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "AppController+Notifications.h"

#import "Database.h"
#import "Folder.h"

@implementation AppController (Notifications)

// Notification keys
NSString *const UserNotificationContextKey = @"User Notification Context";
NSString *const UserNotificationFilePathKey = @"User Notification File Path";

// Notification context descriptors
NSString *const UserNotificationContextFetchCompleted = @"User Notification Context Fetch Completed";
NSString *const UserNotificationContextFileDownloadCompleted = @"User Notification Context File Download Completed";
NSString *const UserNotificationContextFileDownloadFailed = @"User Notification Context File Download Failed";

// MARK: Delegate methods

- (void)userNotificationCenter:(NSUserNotificationCenter *)center
       didActivateNotification:(NSUserNotification *)notification {
    NSDictionary<NSString *, NSString *> *userInfo = notification.userInfo;
    if ([userInfo[UserNotificationContextKey] isEqual:UserNotificationContextFetchCompleted]) {
        [self openWindowAndShowUnreadArticles];
    } else if ([userInfo[UserNotificationContextKey] isEqual:UserNotificationContextFileDownloadCompleted]) {
        [self showFileInFinderAtPath:userInfo[UserNotificationFilePathKey]];
    }
}

// MARK: Notification actions

/**
 Open the main window and switch to the unread-articles section, if there are
 any unread articles after the fetch.
 */
- (void)openWindowAndShowUnreadArticles {
    [NSApp activateIgnoringOtherApps:YES];
    [self showMainWindow:self];

    Folder *unreadArticles = [db folderFromName:NSLocalizedString(@"Unread Articles", nil)];
    if (unreadArticles) {
        [self selectFolder:unreadArticles.itemId];
    }
}

/**
 Show the file in Finder on success, otherwise do nothing.
 */
- (void)showFileInFinderAtPath:(NSString *)filePath {
    [[NSWorkspace sharedWorkspace] selectFile:filePath
                     inFileViewerRootedAtPath:@""];
}

@end
