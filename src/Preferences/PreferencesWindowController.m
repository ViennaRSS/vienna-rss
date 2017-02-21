//
//  PreferencesWindowController.m
//  Vienna
//
//  Copyright 2017
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

#import "PreferencesWindowController.h"

#import "GeneralPreferencesViewController.h"
#import "AppearancePreferencesViewController.h"
#import "SyncingPreferencesViewController.h"
#import "AdvancedPreferencesViewController.h"

@implementation PreferencesWindowController

/*
 This initializer is called by -initWithWindow.
 */
- (instancetype)init {
    NSViewController *general = [GeneralPreferencesViewController new];
    NSViewController *appearance = [AppearancePreferencesViewController new];
    NSViewController *syncing = [SyncingPreferencesViewController new];
    NSViewController *advanced = [AdvancedPreferencesViewController new];

    NSArray *controllers = @[general, appearance, syncing, advanced];
    NSString *title = NSLocalizedString(@"Preferences", @"Title of the Preferences window");

    return [self initWithViewControllers:controllers title:title];
}

@end
