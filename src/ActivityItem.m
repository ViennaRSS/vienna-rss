//
//  ActivityItem.m
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

#import "ActivityLog.h"

@implementation ActivityItem

NSNotificationName const activityItemStatusUpdatedNotification = @"Activity Item Status Updated";
NSNotificationName const activityItemDetailsUpdatedNotification = @"Activity Item Details Updated";

/* init
 * Initialise a new ActivityItem object
 */
-(instancetype)init
{
    if ((self = [super init]) != nil)
    {
        self.name = @"";
        self.status = @"";
        details = nil;
    }
    return self;
}

/* name
 * Returns the object source name.
 */
-(NSString *)name
{
    return name;
}

/* status
 * Returns the object source status
 */
-(NSString *)status
{
    return status;
}

/* setName
 * Sets the source name
 */
-(void)setName:(NSString *)aName
{
    name = aName;
}

/* setStatus
 * Sets the item status.
 */
-(void)setStatus:(NSString *)aStatus
{
    status = aStatus;
    [[NSNotificationCenter defaultCenter] postNotificationName:activityItemStatusUpdatedNotification object:self];
}

/* clearDetails
 * Empties the details log for this item.
 */
-(void)clearDetails
{
    [details removeAllObjects];
}

/* appendDetail
 * Appends the specified text string to the details for this item.
 */
-(void)appendDetail:(NSString *)aString
{
    if (details == nil)
        details = [[NSMutableArray alloc] init];
    [details addObject:aString];
    [[NSNotificationCenter defaultCenter] postNotificationName:activityItemDetailsUpdatedNotification object:self];
}

/* details
 * Returns all details for this item. Caution: the return value
 * may be nil if the item has no initialised details.
 */
-(NSString *)details
{
    NSMutableString * detailString = [NSMutableString stringWithString:@""];
    if (details != nil)
    {
        for (NSString * aString in details)
        {
            [detailString appendFormat:@"%@\n", aString];
        }
    }
    return detailString;
}

/* description
 * Return item description for debugging.
 */
-(NSString *)description
{
    return [NSString stringWithFormat:@"{'%@', '%@'}", name, status];
}

@end
