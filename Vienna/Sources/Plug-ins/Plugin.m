//
//  Plugin.m
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

#import "Plugin.h"

NSString * const VNAPluginTypeInfoPlistKey = @"Type";

static NSString * const VNAIdentifierInfoPlistKey = @"Name";
static NSString * const VNADisplayNameInfoPlistKey = @"FriendlyName";

@implementation VNAPlugin

// MARK: Initialization

- (nullable instancetype)initWithBundle:(NSBundle *)bundle
{
    self = [super init];
    if (self) {
        NSDictionary *infoDict = bundle.infoDictionary;
        if (!infoDict || !infoDict[VNAPluginTypeInfoPlistKey]) {
            return nil;
        }

        _bundle = bundle;
    }
    return self;
}

+ (BOOL)canInitWithBundle:(NSBundle *)bundle
{
    return NO;
}

// MARK: Accessors

- (NSString *)identifier
{
    NSString *identifier = self.bundle.infoDictionary[VNAIdentifierInfoPlistKey];
    if (!identifier) {
        identifier = [self.bundle.bundleURL.lastPathComponent stringByDeletingPathExtension];
    }
    return identifier;
}

- (NSString *)displayName
{
    NSString *displayName = [self.bundle objectForInfoDictionaryKey:VNADisplayNameInfoPlistKey];
    if (!displayName) {
        displayName = self.identifier;
    }
    return displayName;
}

@end
