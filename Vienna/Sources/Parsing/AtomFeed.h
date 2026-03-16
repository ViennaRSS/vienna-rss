//
//  AtomFeed.h
//  Vienna
//
//  Copyright 2004-2005 Steve Palmer, 2021-2022 Eitot
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

#import "XMLFeed.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AtomFeed)
@interface VNAAtomFeed : VNAXMLFeed

- (nullable instancetype)initWithXMLRootElement:(NSXMLElement *)rootElement
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
