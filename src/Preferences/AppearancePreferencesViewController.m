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
#import "PopUpButtonExtensions.h"
#import "Preferences.h"

// List of available font sizes. I picked the ones that matched
// Mail but you easily could add or remove from the list as needed.
NSInteger availableFontSizes[] = { 6, 8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 32, 48, 64 };
#define countOfAvailableFontSizes  (sizeof(availableFontSizes)/sizeof(availableFontSizes[0]))

// List of minimum font sizes. I picked the ones that matched the same option in
// Safari but you easily could add or remove from the list as needed.
NSInteger availableMinimumFontSizes[] = { 9, 10, 11, 12, 14, 18, 24 };
#define countOfAvailableMinimumFontSizes  (sizeof(availableMinimumFontSizes)/sizeof(availableMinimumFontSizes[0]))


@interface AppearancePreferencesViewController ()
-(void)initializePreferences;
-(void)selectUserDefaultFont:(NSString *)name size:(NSInteger)size control:(NSTextField *)control;

@end

@implementation AppearancePreferencesViewController


- (instancetype)init {
	if ((self = [super initWithNibName:@"AppearancePreferencesView" bundle:nil]) != nil)
	{
        // Set up to be notified if preferences change outside this window
        NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_FolderFontChange" object:nil];
        [nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_ArticleListFontChange" object:nil];
        [nc addObserver:self selector:@selector(handleReloadPreferences:) name:kMA_Notify_MinimumFontSizeChange object:nil];
        [nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_PreferenceChange" object:nil];
	}
	return self;
}


- (void)viewWillAppear {
    if([NSViewController instancesRespondToSelector:@selector(viewWillAppear)]) {
        [super viewWillAppear];
    }
    // Do view setup here.
    [self initializePreferences];
    
    
}

#pragma mark - MASPreferencesViewController

- (NSString *)identifier {
    return @"AppearancePreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"appearancePrefImage"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Appearance", @"Toolbar item name for the Appearance preference pane");
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
    [self selectUserDefaultFont:prefs.articleListFont size:prefs.articleListFontSize control:articleFontSample];
    [self selectUserDefaultFont:prefs.folderListFont size:prefs.folderListFontSize control:folderFontSample];
    
    // Show folder images option
    showFolderImagesButton.state = prefs.showFolderImages ? NSOnState : NSOffState;
    
    // Set minimum font size option
    enableMinimumFontSize.state = prefs.enableMinimumFontSize ? NSOnState : NSOffState;
    minimumFontSizes.enabled = prefs.enableMinimumFontSize;
    
    NSUInteger i;
    [minimumFontSizes removeAllItems];
    for (i = 0; i < countOfAvailableMinimumFontSizes; ++i)
        [minimumFontSizes addItemWithObjectValue:@(availableMinimumFontSizes[i])];
    minimumFontSizes.doubleValue = prefs.minimumFontSize;
}

/* changeShowFolderImages
 * Toggle whether or not the folder list shows folder images.
 */
-(IBAction)changeShowFolderImages:(id)sender
{
    BOOL showFolderImages = [sender state] == NSOnState;
    [Preferences standardPreferences].showFolderImages = showFolderImages;
}

/* changeMinimumFontSize
 * Enable whether a minimum font size is used for article display.
 */
-(IBAction)changeMinimumFontSize:(id)sender
{
    BOOL useMinimumFontSize = [sender state] == NSOnState;
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

/* selectUserDefaultFont
 * Display sample text in the specified font and size.
 */
-(void)selectUserDefaultFont:(NSString *)name size:(NSInteger)size control:(NSTextField *)control
{
    control.font = [NSFont fontWithName:name size:size];
    control.stringValue = [NSString stringWithFormat:@"%@ %li", name, (long)size];
}

/* selectArticleFont
 * Bring up the standard font selector for the article font.
 */
-(IBAction)selectArticleFont:(id)sender
{
    Preferences * prefs = [Preferences standardPreferences];
    NSFontManager * manager = [NSFontManager sharedFontManager];
    [manager setSelectedFont:[NSFont fontWithName:prefs.articleListFont size:prefs.articleListFontSize] isMultiple:NO];
    manager.action = @selector(changeArticleFont:);
    manager.delegate = self;
    [manager orderFrontFontPanel:self];
}

/* selectFolderFont
 * Bring up the standard font selector for the folder font.
 */
-(IBAction)selectFolderFont:(id)sender
{
    Preferences * prefs = [Preferences standardPreferences];
    NSFontManager * manager = [NSFontManager sharedFontManager];
    [manager setSelectedFont:[NSFont fontWithName:prefs.folderListFont size:prefs.folderListFontSize] isMultiple:NO];
    manager.action = @selector(changeFolderFont:);
    manager.delegate = self;
    [manager orderFrontFontPanel:self];
}

/* changeArticleFont
 * Respond to changes to the article font.
 */
-(IBAction)changeArticleFont:(id)sender
{
    Preferences * prefs = [Preferences standardPreferences];
    NSFont * font = [NSFont fontWithName:prefs.articleListFont size:prefs.articleListFontSize];
    font = [sender convertFont:font];
    prefs.articleListFont = font.fontName;
    prefs.articleListFontSize = font.pointSize;
    [self selectUserDefaultFont:prefs.articleListFont size:prefs.articleListFontSize control:articleFontSample];
}

/* changeFolderFont
 * Respond to changes to the folder font.
 */
-(IBAction)changeFolderFont:(id)sender
{
    Preferences * prefs = [Preferences standardPreferences];
    NSFont * font = [NSFont fontWithName:prefs.folderListFont size:prefs.folderListFontSize];
    font = [sender convertFont:font];
    prefs.folderListFont = font.fontName;
    prefs.folderListFontSize = font.pointSize;
    [self selectUserDefaultFont:prefs.folderListFont size:prefs.folderListFontSize control:folderFontSample];
}

/* dealloc
 * Clean up and release resources. 
 */
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
