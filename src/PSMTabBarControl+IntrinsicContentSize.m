/*
 *  PSMTabBarControl+IntrinsicContentSize.m
 *  Vienna
 *
 *
 *  Copyright 2017
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#import "PSMTabBarControl+IntrinsicContentSize.h"

@implementation PSMTabBarControl (IntrinsicContentSize)

// The intrinsic content size will make sure that
// Auto Layout takes the standard height into account.
- (NSSize)intrinsicContentSize {
    return NSMakeSize(kPSMTabBarControlHeight, 50);
}

@end
