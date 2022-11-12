//
//  HelperFunctions.h
//  Vienna
//
//  Created by Steve on 8/28/05.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//

@import Cocoa;
@import SystemConfiguration;
@import WebKit;

#define kLeftArrow  0x7B
#define kRightArrow 0x7C
#define kUpArrow    0x7E
#define kDownArrow  0x7D
#define kSpacebar   0x31
#define kShift      0x38
#define kControl    0x3B
#define kCommand    0x37
#define kOption     0x3A
#define kEscape     0x35
#define kTab        0x30
#define kBackSpace  0x33
#define kDelete     0x75
#define kCapsLock   0x39
#define kReturn     0x24

NS_ASSUME_NONNULL_BEGIN

void loadMapFromPath(NSString *path,
                     NSMutableDictionary *pathMappings,
                     BOOL foldersOnly,
                     NSArray * _Nullable validExtensions);
BOOL isAccessible(NSString *urlString);
void runOKAlertPanelPlain(NSString *titleString, NSString *bodyText);
void runOKAlertPanel(NSString *titleString, NSString *bodyText, ...);
void runOKAlertSheet(NSString *titleString, NSString *bodyText, ...);
NSMenuItem * _Nullable menuItemWithAction(SEL theSelector);
NSString * _Nullable getDefaultBrowser(void);
NSURL * _Nullable cleanedUpUrlFromString(NSString * _Nullable urlString);
NSURL * _Nullable urlFromUserString(NSString *urlString);
BOOL hasOSScriptsMenu(void);

NS_ASSUME_NONNULL_END
