//
//  AdvancedPreferencesViewController.m
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

#import "AdvancedPreferencesViewController.h"
#import "Preferences.h"

@interface AdvancedPreferencesViewController ()

@end

@implementation AdvancedPreferencesViewController


- (instancetype)init {
    return [super initWithNibName:@"AdvancedPreferencesView" bundle:nil];
}

- (void)viewWillAppear {
    if([NSViewController instancesRespondToSelector:@selector(viewWillAppear)]) {
        [super viewWillAppear];
    }
    // Do view setup here.
    [self initializePreferences];
}

#pragma mark - Vienna Preferences

/* showAdvancedHelp
 * Displays the Help page for the Advanced settings.
 */
-(IBAction)showAdvancedHelp:(id)sender
{
    NSString *helpBook = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"];
    [[NSHelpManager sharedHelpManager] openHelpAnchor:@"AdvancedSettingsSection" inBook:helpBook];
}


/* initializePreferences
 * Set the preference settings from the user defaults.
 */
-(void)initializePreferences
{
    Preferences * prefs = [Preferences standardPreferences];
    
    // Show use JavaScript option
    useJavaScriptButton.state = prefs.useJavaScript ? NSControlStateValueOn : NSControlStateValueOff;
    useWebPluginsButton.state = prefs.useWebPlugins ? NSControlStateValueOn : NSControlStateValueOff;
    [concurrentDownloads selectItemWithTitle:[NSString stringWithFormat:@"%lu",(unsigned long)prefs.concurrentDownloads]];
}

/* changeUseJavaScript
 * Toggle whether or not the webkit should use JavaScript.
 */
-(IBAction)changeUseJavaScript:(id)sender
{
    BOOL useJavaScript = [sender state] == NSControlStateValueOn;
    [Preferences standardPreferences].useJavaScript = useJavaScript;
}

/* changeUseWebPlugins
 * Toggle whether or not the internel webkit browser should use plugins
 * e.g. Flash
 */
- (IBAction)changeUseWebPlugins:(NSButton *)sender {
    BOOL useWebPlugins = sender.state == NSControlStateValueOn;
    [Preferences standardPreferences].useWebPlugins = useWebPlugins;
}


-(IBAction)changeConcurrentDownloads:(id)sender {
    [Preferences standardPreferences].concurrentDownloads = concurrentDownloads.titleOfSelectedItem.integerValue;
}
@end
