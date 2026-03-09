//
//  ActivityItem.h
//  Vienna
//
//  Created by Steve on 6/21/05.
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

@import Foundation;

@interface ActivityItem : NSObject

extern NSNotificationName const activityItemStatusUpdatedNotification;
extern NSNotificationName const activityItemDetailsUpdatedNotification;

/**
 The name of the item.
 */
@property (copy, nonatomic) NSString *name;

/**
 The fetch status of the item.
 */
@property (copy, nonatomic) NSString *status;

/**
 Detailed information about the fetch status of the item.
 */
@property (readonly, nonatomic) NSString *details;

/**
 Appends a string to the details of the item.

 @param string The string to append.
 */
- (void)appendDetail:(NSString *)string;

/**
 Clears all details from the item.
 */
- (void)clearDetails;

@end
