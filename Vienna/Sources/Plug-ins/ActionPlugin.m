//
//  ActionPlugin.m
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

#import "ActionPlugin.h"

static NSString * const VNAMenuItemTitleInfoPlistKey = @"MenuPath";
static NSString * const VNAMenuItemKeyEquivalentInfoPlistKey = @"MenuKey";
static NSString * const VNAToolbarItemImageNameInfoPlistKey = @"ButtonImage";
static NSString * const VNAToolbarItemToolTipInfoPlistKey = @"Tooltip";
static NSString * const VNAToolbarItemIsDefaultInfoPlistKey = @"Default";

@implementation VNAActionPlugin

- (NSString *)menuItemTitle
{
    NSString *menuItemTitle = [self.bundle objectForInfoDictionaryKey:VNAMenuItemTitleInfoPlistKey];
    if (!menuItemTitle) {
        menuItemTitle = self.displayName;
    }
    return menuItemTitle;
}

- (nullable NSString *)menuItemKeyEquivalent
{
    return self.bundle.infoDictionary[VNAMenuItemKeyEquivalentInfoPlistKey];
}

- (nullable NSImage *)toolbarItemImage
{
    NSImageName imageName = self.bundle.infoDictionary[VNAToolbarItemImageNameInfoPlistKey];
    return [self.bundle imageForResource:imageName];
}

- (nullable NSString *)toolbarItemToolTip
{
    return [self.bundle objectForInfoDictionaryKey:VNAToolbarItemToolTipInfoPlistKey];
}

- (BOOL)isDefaultToolbarItem
{
    NSNumber *number = self.bundle.infoDictionary[VNAToolbarItemIsDefaultInfoPlistKey];
    return number.boolValue;
}

@end
