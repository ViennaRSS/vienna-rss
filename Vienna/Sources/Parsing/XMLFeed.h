//
//  XMLFeed.h
//  Vienna
//
//  Copyright 2004-2005 Steve Palmer, 2015 Joshua Pore
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

#import "Feed.h"

@protocol VNAFeedItem;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(XMLFeed)
@interface VNAXMLFeed : NSObject <VNAFeed>

@property (copy, nonatomic) NSString *title;
@property (nullable, copy, nonatomic) NSString *feedDescription;
@property (nullable, copy, nonatomic) NSString *homePageURL;
@property (nonatomic) NSDate *modifiedDate;
@property (copy, nonatomic) NSArray<id<VNAFeedItem>> *items;

// MARK: Prefix handling

@property (copy, nonatomic) NSString *rdfPrefix;
@property (copy, nonatomic) NSString *mediaPrefix;
@property (copy, nonatomic) NSString *encPrefix;

/// Identify the prefixes used for namespaces that Vienna handles, if defined.
/// If prefixes are not defined in the data, set to frequently used ones.
- (void)identifyNamespacesPrefixes:(NSXMLElement *)element;

// MARK: Date parsing

/// Parse a date in an XML header into an NSDate.
- (nullable NSDate *)dateWithXMLString:(NSString *)dateString;

@end

NS_ASSUME_NONNULL_END
