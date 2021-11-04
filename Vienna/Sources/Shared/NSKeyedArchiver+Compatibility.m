//
//  NSKeyedArchiver+Compatibility.m
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

#import "NSKeyedArchiver+Compatibility.h"

#import <os/log.h>

#define VNA_LOG os_log_create("--", "KeyedArchiver")

@implementation NSKeyedArchiver (Compatibility)

+ (nullable NSData *)archivedDataWithRootObject:(id)object
                          requiringSecureCoding:(BOOL)requiresSecureCoding
{
    if (![object conformsToProtocol:@protocol(NSSecureCoding)]) {
        os_log_fault(VNA_LOG, "%{public}@ does not conform to NSSecureCoding",
                     [object className]);
    }

    NSData *data = nil;

    if (@available(macOS 10.13, *)) {
        NSError *error = nil;
        data = [NSKeyedArchiver archivedDataWithRootObject:object
                                     requiringSecureCoding:requiresSecureCoding
                                                     error:&error];
        if (error) {
            os_log_fault(VNA_LOG,
                         "Failed to archive %{public}@ using keyed archiver",
                         [object className]);
        }
    } else {
        @try {
            data = [NSKeyedArchiver archivedDataWithRootObject:object];
        } @catch (NSException *exception) {
            os_log_fault(VNA_LOG,
                         "Failed to archive %{public}@ using keyed archiver. "
                         "Reason: %{public}@",
                         [object className], exception.reason);
        }
    }

    return data;
}

@end
