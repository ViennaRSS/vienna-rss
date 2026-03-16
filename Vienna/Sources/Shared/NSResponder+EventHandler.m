//
//  NSResponder+EventHandler.m
//  Vienna
//
//  Copyright 2025 Eitot
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

#import "NSResponder+EventHandler.h"

@implementation NSResponder (EventHandler)

- (BOOL)vna_handleEvent:(NSEvent *)event
{
    NSResponder *supplementalHandler = [self.nextResponder vna_supplementalHandlerForEvent:event];
    if (supplementalHandler) {
        return [supplementalHandler vna_handleEvent:event];
    }
    return [self.nextResponder vna_handleEvent:event];
}

- (BOOL)vna_canHandleEvent:(NSEvent *)event
{
    return NO;
}

- (nullable NSResponder *)vna_supplementalHandlerForEvent:(NSEvent *)event
{
    return nil;
}

@end
