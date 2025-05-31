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
#import "Database.h"
#import "Database+Migration.h"

@interface AdvancedPreferencesViewController ()

@property (weak, nonatomic) IBOutlet NSTextField *javaScriptNoticeTextField;
@property (weak) IBOutlet NSPopUpButton *databaseRollbackChoice;

@end

@implementation AdvancedPreferencesViewController {
    IBOutlet NSButton *useJavaScriptButton;
    IBOutlet NSPopUpButton *concurrentDownloads;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // WKWebViewConfiguration._allowsJavaScriptMarkup may require a restart.
    // This is only necessary for versions older than macOS 11, because the
    // latter use WKWebpagePreferences.allowsContentJavaScript instead.
    if (@available(macOS 11, *)) {
        [self.javaScriptNoticeTextField removeFromSuperview];
    }
}

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

    useJavaScriptButton.state = prefs.useJavaScript ? NSControlStateValueOn : NSControlStateValueOff;

    [concurrentDownloads selectItemWithTitle:[NSString stringWithFormat:@"%lu",(unsigned long)prefs.concurrentDownloads]];

    self.databaseRollbackChoice.menu.itemArray = @[
        [[NSMenuItem alloc] initWithTitle:@"-" action:nil keyEquivalent:@"-"]
    ];

    for (NSNumber *version in [Database availableVersionsForRollback]) {
        [self.databaseRollbackChoice.menu addItem:
         [[NSMenuItem alloc] initWithTitle:version.description action:nil keyEquivalent:@""]];
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

-(IBAction)changeConcurrentDownloads:(id)sender {
    [Preferences standardPreferences].concurrentDownloads = concurrentDownloads.titleOfSelectedItem.integerValue;
}

-(void)chooseVersionForDBRollback:(id)sender {
    int rollbackVersion = self.databaseRollbackChoice.titleOfSelectedItem.intValue;
    [[Database sharedManager] setRevertToDatabaseVersion: rollbackVersion];
}
@end
