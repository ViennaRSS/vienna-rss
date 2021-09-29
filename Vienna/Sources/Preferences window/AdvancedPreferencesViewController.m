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

- (void)viewWillAppear {
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

    previewNewBrowserButton.state = prefs.useNewBrowser ? NSControlStateValueOn : NSControlStateValueOff;
    useJavaScriptButton.state = prefs.useJavaScript ? NSControlStateValueOn : NSControlStateValueOff;

    if (@available(macOS 11, *)) {
        // WKWebKit has no more support for plug-ins. The same might not be true
        // for WebView, however.
        if (prefs.useNewBrowser) {
            useWebPluginsButton.enabled = NO;
            useWebPluginsButton.state = NSControlStateValueOff;
        } else {
            useWebPluginsButton.enabled = YES;
            useWebPluginsButton.state = prefs.useWebPlugins ? NSControlStateValueOn : NSControlStateValueOff;
        }
    } else {
        useWebPluginsButton.state = prefs.useWebPlugins ? NSControlStateValueOn : NSControlStateValueOff;
    }

    [concurrentDownloads selectItemWithTitle:[NSString stringWithFormat:@"%lu",(unsigned long)prefs.concurrentDownloads]];
}

- (IBAction)changeUseNewBrowser:(NSButton *)sender {
    BOOL useNewBrowser = sender.state == NSControlStateValueOn;
    Preferences *preferences = Preferences.standardPreferences;
    preferences.useNewBrowser = useNewBrowser;

    if (@available(macOS 11, *)) {
        // WKWebKit has no more support for plug-ins. The same might not be true
        // for WebView, however.
        if (useNewBrowser) {
            useWebPluginsButton.enabled = NO;
            useWebPluginsButton.state = NSControlStateValueOff;
        } else {
            useWebPluginsButton.enabled = YES;
            useWebPluginsButton.state = preferences.useWebPlugins ? NSControlStateValueOn : NSControlStateValueOff;
        }
    }
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
