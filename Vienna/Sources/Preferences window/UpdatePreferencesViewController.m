//
//  UpdatePreferencesViewController.m
//  Vienna
//
//  Created by Joshua Pore on 22/11/2014.
//  Copyright (c) 2014 uk.co.opencommunity. All rights reserved.
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
//  limitations under the License.
//

#import "Constants.h"
#import "UpdatePreferencesViewController.h"
#import "Preferences.h"

@interface UpdatePreferencesViewController ()

@property (weak) IBOutlet NSButton *alwaysAcceptBetas;

@end

@implementation UpdatePreferencesViewController

- (void)viewDidLoad {
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleReloadPreferences:) name:MA_Notify_PreferenceChange object:nil];
}

- (void)viewWillAppear {
    [self initializePreferences];
}

#pragma mark - Vienna Preferences handling

/* handleReloadPreferences
 * This gets called when MA_Notify_PreferencesUpdated is broadcast. Just update the controls values.
 */
-(void)handleReloadPreferences:(NSNotification *)nc
{
    [self initializePreferences];
}

/* initializePreferences
 * Set the preference settings from the user defaults.
 */
-(void)initializePreferences
{
    Preferences * prefs = [Preferences standardPreferences];
    
    // Set search for latest Beta versions when checking for updates
    self.alwaysAcceptBetas.state = prefs.alwaysAcceptBetas ? NSControlStateValueOn : NSControlStateValueOff;
}

/* changeAlwaysAcceptBetas
 * Set whether Vienna will always check the cutting edge Beta when checking for updates.
 */
-(IBAction)changeAlwaysAcceptBetas:(id)sender
{
    [Preferences standardPreferences].alwaysAcceptBetas = [sender state] == NSControlStateValueOn;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
