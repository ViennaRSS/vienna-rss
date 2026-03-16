//
//  FeedSourcePlugin.m
//  Vienna
//
//  Copyright 2024 Eitot
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

#import "FeedSourcePlugin.h"

static NSString * const VNAPluginTypeInfoPlistValue = @"FeedSource";
static NSString * const VNATextFieldLabelInfoPlistKey = @"LinkName";
static NSString * const VNAQueryStringInfoPlistKey = @"LinkTemplate";
static NSString * const VNAHomePageInfoPlistKey = @"SiteHomePage";

@implementation VNAFeedSourcePlugin

- (nullable instancetype)initWithBundle:(NSBundle *)bundle
{
    self = [super initWithBundle:bundle];
    if (!self || !self.hintLabel || !self.queryString) {
        return nil;
    }
    return self;
}

+ (BOOL)canInitWithBundle:(NSBundle *)bundle
{
    NSString *typeIdentifier = bundle.infoDictionary[VNAPluginTypeInfoPlistKey];
    return [typeIdentifier isEqualToString:VNAPluginTypeInfoPlistValue];
}

- (NSString *)hintLabel
{
    return [self.bundle objectForInfoDictionaryKey:VNATextFieldLabelInfoPlistKey];
}

- (nullable NSURL *)homePageURL
{
    NSString *urlString = [self.bundle objectForInfoDictionaryKey:VNAHomePageInfoPlistKey];
    return [NSURL URLWithString:urlString];
}

- (NSString *)queryString
{
    return [self.bundle objectForInfoDictionaryKey:VNAQueryStringInfoPlistKey];
}

@end
