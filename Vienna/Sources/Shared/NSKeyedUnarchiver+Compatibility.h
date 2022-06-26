//
//  NSKeyedUnarchiver+Compatibility.h
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

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NSKeyedUnarchiver (Compatibility)

// TODO: Make this a method of NSUserDefaults instead
+ (nullable id)vna_unarchivedObjectOfClass:(Class)cls
                                  fromData:(NSData *)data
    NS_SWIFT_NAME(unarchivedObject(ofClass:from:)) NS_SWIFT_NOTHROW;

+ (nullable id)vna_unarchivedArrayOfObjectsOfClass:(Class)cls
                                          fromData:(NSData *)data
    NS_SWIFT_NAME(unarchivedArrayOfObjects(ofClass:from:)) NS_SWIFT_NOTHROW
    NS_DEPRECATED_MAC(10.12, 11);

@end

NS_ASSUME_NONNULL_END
