//
//  NSKeyedUnarchiver+Compatibility.m
//  Vienna
//
//  Copyright 2021 Eitot
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

#import "NSKeyedUnarchiver+Compatibility.h"

#import <objc/runtime.h>
#import <os/log.h>

#define VNA_LOG os_log_create("--", "KeyedUnarchiver")

@implementation NSKeyedUnarchiver (Compatibility)

+ (nullable id)vna_unarchivedObjectOfClass:(Class)cls fromData:(NSData *)data
{
    id object = nil;

    if (@available(macOS 10.13, *)) {
        NSError *error = nil;
        object = [NSKeyedUnarchiver unarchivedObjectOfClass:cls
                                                   fromData:data
                                                      error:&error];
        if (error) {
            os_log_error(VNA_LOG,
                         "Failed to unarchive %{public}s using keyed "
                         "unarchiver",
                         class_getName(cls));
        }
    } else {
        @try {
            object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        } @catch (NSException *exception) {
            os_log_error(VNA_LOG,
                         "Failed to unarchive %{public}s using keyed "
                         "unarchiver. Reason: %{public}@",
                         class_getName(cls), exception.reason);
        }
    }

    return object;
}

+ (nullable id)vna_unarchivedArrayOfObjectsOfClass:(Class)cls
                                          fromData:(NSData *)data
{
    id object = nil;

    if (@available(macOS 11, *)) {
        NSError *error = nil;
        object = [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClass:cls
                                                           fromData:data
                                                              error:&error];
        if (error) {
            os_log_error(VNA_LOG,
                         "Failed to unarchive %{public}s using keyed "
                         "unarchiver",
                         class_getName(cls));
        }
    } else if (@available(macOS 10.13, *)) {
        NSError *error = nil;
        NSSet *classes = [NSSet setWithArray:@[[NSArray class], cls]];
        object = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                     fromData:data
                                                        error:&error];
        if (error) {
            os_log_error(VNA_LOG,
                         "Failed to unarchive %{public}s using keyed "
                         "unarchiver",
                         class_getName(cls));
        }
    } else {
        @try {
            object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        } @catch (NSException *exception) {
            os_log_error(VNA_LOG,
                         "Failed to unarchive %{public}s using keyed "
                         "unarchiver. Reason: %{public}@",
                         class_getName(cls), exception.reason);
        }
    }

    return object;
}

@end
