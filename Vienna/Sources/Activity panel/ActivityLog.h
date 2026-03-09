//
//  ActivityLog.h
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

@class ActivityItem;

NS_ASSUME_NONNULL_BEGIN

@interface ActivityLog : NSObject

extern NSNotificationName const activityLogUpdatedNotification;

/**
 The default activity log.
 */
@property (class, readonly, nonatomic) ActivityLog *defaultLog;

/**
 An array of activity items.
 */
@property (readonly, nonatomic) NSArray<ActivityItem *> *allItems;

/**
 Returns an activity item for the name of the item.

 @param name The name of the item.
 @return An activity item.
 */
- (ActivityItem *)itemByName:(NSString *)name;

- (void)sortUsingDescriptors:(NSArray *)sortDescriptors;

@end

NS_ASSUME_NONNULL_END
