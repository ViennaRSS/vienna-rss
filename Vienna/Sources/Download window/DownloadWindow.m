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
#import "Vienna-Swift.h"

@implementation DownloadWindow

/* windowDidLoad
 * Do the things that only make sense after the window file is loaded.
 */
-(void)windowDidLoad
{
	// Work around a Cocoa bug where the window positions aren't saved
	[self setShouldCascadeWindows:NO];
	self.windowFrameAutosaveName = @"downloadWindow";
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
