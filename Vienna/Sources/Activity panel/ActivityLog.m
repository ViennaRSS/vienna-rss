//
//  ActivityLog.m
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

#import "ActivityItem.h"
#import "Database.h"
#import "Folder.h"

@interface ActivityLog ()

@property (nonatomic) NSMutableArray<ActivityItem *> *log;

@end

@implementation ActivityLog

#pragma mark Initialization

+ (ActivityLog *)defaultLog {
    static ActivityLog *_defaultLog = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        _defaultLog = [self new];
    });

    return _defaultLog;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        self.log = [NSMutableArray new];

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(handleWillDeleteFolder:)
                                                   name:VNADatabaseWillDeleteFolderNotification
                                                 object:nil];
    }

    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark Accessors

- (NSArray *)allItems {
    return [self.log copy];
}

- (ActivityItem *)itemByName:(NSString *)name {
    NSInteger insertionIndex;
    ActivityItem *item = [self getStatus:name index:&insertionIndex];

    // If no item is found, create a new item.
    if (!item) {
        item = [ActivityItem new];
        item.name = name;
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:insertionIndex];
        NSString *allItemsKey = NSStringFromSelector(@selector(allItems));
        [self willChange:NSKeyValueChangeInsertion
            valuesAtIndexes:indexes
                     forKey:allItemsKey];
        [self.log insertObject:item atIndex:insertionIndex];
        [self didChange:NSKeyValueChangeInsertion
            valuesAtIndexes:indexes
                     forKey:allItemsKey];
        item = self.log[insertionIndex];
    }

    return item;
}

/* sortUsingDescriptors
 * Sort the log using the specified descriptors.
 */
-(void)sortUsingDescriptors:(NSArray *)sortDescriptors
{
	[self.log sortUsingDescriptors:sortDescriptors];
}

#pragma mark Helper methods

/**
 Retrieves the status item in the array corresponding to the source name. On
 return, indexPointer is the index of the item or the index of the item just
 where the status item should be if it was found.
 */
- (ActivityItem *)getStatus:(NSString *)name index:(NSInteger *)indexPointer {
    NSInteger index = 0;
    ActivityItem *item;

    for (item in self.log) {
        if ([item.name caseInsensitiveCompare:name] == NSOrderedSame) {
            break;
        }
        ++index;
    }
    *indexPointer = index;

    return item;
}

#pragma mark Notification handling

/**
 Removes the folder from the log and posts a notification.
 */
- (void)handleWillDeleteFolder:(NSNotification *)nc {
    Folder *folder = [[Database sharedManager] folderFromID:[nc.object integerValue]];
    ActivityItem *activityItem = [self itemByName:folder.name];
    NSUInteger activityItemIndex = [self.log indexOfObject:activityItem];
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:activityItemIndex];
    NSString *allItemsKey = NSStringFromSelector(@selector(allItems));
    [self willChange:NSKeyValueChangeRemoval
        valuesAtIndexes:indexes
                 forKey:allItemsKey];
    [self.log removeObject:activityItem];
    [self didChange:NSKeyValueChangeRemoval
        valuesAtIndexes:indexes
                 forKey:allItemsKey];

    [NSNotificationCenter.defaultCenter postNotificationName:activityItemStatusUpdatedNotification
                                                      object:nil];
}

@end
