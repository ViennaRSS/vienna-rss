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

#import "ActivityItem.h"

@interface ActivityItem ()

@property NSMutableArray *detailsArray;

@end

@implementation ActivityItem

NSNotificationName const activityItemStatusUpdatedNotification = @"Activity Item Status Updated";
NSNotificationName const activityItemDetailsUpdatedNotification = @"Activity Item Details Updated";

#pragma mark Accessors

- (void)setStatus:(NSString *)status {
	dispatch_async(dispatch_get_main_queue(), ^{
		_status = [status copy];

		NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
		[center postNotificationName:activityItemStatusUpdatedNotification
							  object:self];
	});
}

- (NSString *)details {
    NSMutableString *detailString = [NSMutableString stringWithString:@""];
    if (self.detailsArray) {
        for (NSString *string in self.detailsArray) {
            [detailString appendFormat:@"%@\n", string];
        }
    }

    return detailString;
}

/*
 Overrides the description for debugging purposes.
 */
- (NSString *)description {
    return [NSString stringWithFormat:@"{'%@', '%@'}", self.name, self.status];
}

#pragma mark Methods

- (void)clearDetails {
    [self.detailsArray removeAllObjects];
}

- (void)appendDetail:(NSString *)string {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (!self.detailsArray) {
			self.detailsArray = [NSMutableArray new];
		}
		[self.detailsArray addObject:string];

		NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
		[center postNotificationName:activityItemDetailsUpdatedNotification
							  object:self];
	});
}

@end
