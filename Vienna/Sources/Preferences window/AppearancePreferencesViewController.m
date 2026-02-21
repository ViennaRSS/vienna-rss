//
//  AppearancePreferencesViewController.m
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

#import "AppearancePreferencesViewController.h"

#import "Constants.h"
#import "Preferences.h"

// List of minimum font sizes. I picked the ones that matched the same option in
// Safari but you easily could add or remove from the list as needed.
static NSInteger const availableMinimumFontSizes[] = { 9, 10, 11, 12, 14, 18, 24 };
#define countOfAvailableMinimumFontSizes  (sizeof(availableMinimumFontSizes)/sizeof(availableMinimumFontSizes[0]))


@interface AppearancePreferencesViewController ()

@property (nonatomic, weak) NSFontPanel *fontPanel;

-(void)initializePreferences;

@end

@implementation AppearancePreferencesViewController {
    IBOutlet NSTextField *articleFontSample;
    IBOutlet NSButton *articleFontSelectButton;
    IBOutlet NSComboBox *minimumFontSizes;
    IBOutlet NSButton *enableMinimumFontSize;
    IBOutlet NSButton *showFolderImagesButton;
}

- (void)viewDidLoad {
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleReloadPreferences:) name:MA_Notify_ArticleListFontChange object:nil];
    [nc addObserver:self selector:@selector(handleReloadPreferences:) name:MA_Notify_MinimumFontSizeChange object:nil];
    [nc addObserver:self selector:@selector(handleReloadPreferences:) name:MA_Notify_PreferenceChange object:nil];
}

- (void)viewWillAppear {
    [self initializePreferences];
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];
    [self.fontPanel close];
}

#pragma mark - Vienna Preferences

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
    
    // Populate the drop downs with the font names and sizes
    [self displaySelectedFont:prefs.articleListFont inTextField:articleFontSample];

    // Show folder images option
    showFolderImagesButton.state = prefs.showFolderImages ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Set minimum font size option
    enableMinimumFontSize.state = prefs.enableMinimumFontSize ? NSControlStateValueOn : NSControlStateValueOff;
    minimumFontSizes.enabled = prefs.enableMinimumFontSize;
    
    NSUInteger i;
    [minimumFontSizes removeAllItems];
    for (i = 0; i < countOfAvailableMinimumFontSizes; ++i) {
        [minimumFontSizes addItemWithObjectValue:@(availableMinimumFontSizes[i])];
    }
    minimumFontSizes.doubleValue = prefs.minimumFontSize;
}

/* changeShowFolderImages
 * Toggle whether or not the folder list shows folder images.
 */
-(IBAction)changeShowFolderImages:(id)sender
{
    BOOL showFolderImages = [sender state] == NSControlStateValueOn;
    [Preferences standardPreferences].showFolderImages = showFolderImages;
}

/* changeMinimumFontSize
 * Enable whether a minimum font size is used for article display.
 */
-(IBAction)changeMinimumFontSize:(id)sender
{
    BOOL useMinimumFontSize = [sender state] == NSControlStateValueOn;
    [Preferences standardPreferences].enableMinimumFontSize = useMinimumFontSize;
    minimumFontSizes.enabled = useMinimumFontSize;
}

/* selectMinimumFontSize
 * Changes the actual minimum font size for article display.
 */
-(IBAction)selectMinimumFontSize:(id)sender
{
    CGFloat newMinimumFontSize = minimumFontSizes.doubleValue;
    [Preferences standardPreferences].minimumFontSize = newMinimumFontSize;
}

// Display sample text in the specified font and size.
- (void)displaySelectedFont:(NSFont *)font inTextField:(NSTextField *)textField
{
    textField.font = font;
    textField.stringValue = [NSString stringWithFormat:@"%@ %.0f",
                                                       font.displayName,
                                                       font.pointSize];
}

/* selectArticleFont
 * Bring up the standard font selector for the article font.
 */
-(IBAction)selectArticleFont:(id)sender
{
    Preferences * prefs = [Preferences standardPreferences];
    NSFontManager * fontManager = NSFontManager.sharedFontManager;
    if (!self.fontPanel) {
        NSFontPanel *fontPanel = [fontManager fontPanel:YES];
        fontPanel.restorable = NO;
        self.fontPanel = fontPanel;
    }
    [fontManager setSelectedFont:prefs.articleListFont isMultiple:NO];
    // The NSFontChanging callbacks are sent to the first responder, which this
    // view controller is not by default.
    [self.view.window makeFirstResponder:self];
    // If the view controller loses first-responder status, e.g. when the user
    // selects or inserts text in the combo box, -changeFont: can still be sent
    // to a predefined target. -validModesForFontPanel: is not affected by this,
    // however.
    fontManager.target = self;
    [fontManager orderFrontFontPanel:self];
}

/* dealloc
 * Clean up and release resources. 
 */
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// MARK: - NSFontChanging

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Woverriding-method-mismatch"
- (void)changeFont:(nullable NSFontManager *)sender
#pragma clang diagnostic pop
{
    Preferences * prefs = [Preferences standardPreferences];
    NSFont *font = prefs.articleListFont;
    font = [sender convertFont:font];
    prefs.articleListFont = font;
    [self displaySelectedFont:font inTextField:articleFontSample];
}

- (NSFontPanelModeMask)validModesForFontPanel:(NSFontPanel *)fontPanel
{
    return (NSFontPanelModeMaskFace | NSFontPanelModeMaskSize | NSFontPanelModeMaskCollection);
}

@end
