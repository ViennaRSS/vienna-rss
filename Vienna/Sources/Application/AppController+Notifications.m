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

- (void)userNotificationCenter:(VNAUserNotificationCenter *)center
            didReceiveResponse:(VNAUserNotificationResponse *)response
{
    NSDictionary<NSString *, NSString *> *userInfo = response.userInfo;
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
    if (@available(macOS 14, *)) {
        [NSApp activate];
    } else {
        [NSApp activateIgnoringOtherApps:YES];
    }
    [self showMainWindow:self];

    Criteria *unreadCriteria =
        [[Criteria alloc] initWithField:MA_Field_Read
                           operatorType:VNACriteriaOperatorEqualTo
                                  value:@"No"];
    NSString *predicateFormat = unreadCriteria.predicate.predicateFormat;
    Folder *smartFolder = [db folderForPredicateFormat:predicateFormat];
    if (smartFolder) {
        [self selectFolder:smartFolder.itemId];
    }
}

/**
 Show the file in Finder on success, otherwise do nothing.
 */
- (void)showFileInFinderAtPath:(NSString *)filePath {
    [[NSWorkspace sharedWorkspace] selectFile:filePath
                     inFileViewerRootedAtPath:[filePath stringByDeletingLastPathComponent]];
}

@end
