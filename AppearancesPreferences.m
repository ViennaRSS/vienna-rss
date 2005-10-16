//
//  AppearancesPreferences.m
//  Vienna
//
//  Created by Steve on 10/15/05.
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
//  limitations under the License.
//

#import "AppearancesPreferences.h"
#import "PopUpButtonExtensions.h"
#import "AppController.h"
#import "Constants.h"
#import "Preferences.h"

// List of available font sizes. I picked the ones that matched
// Mail but you easily could add or remove from the list as needed.
int availableFontSizes[] = { 6, 8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 32, 48, 64 };
#define countOfAvailableFontSizes  (sizeof(availableFontSizes)/sizeof(availableFontSizes[0]))

// List of minimum font sizes. I picked the ones that matched the same option in
// Safari but you easily could add or remove from the list as needed.
int availableMinimumFontSizes[] = { 9, 10, 11, 12, 14, 18, 24 };
#define countOfAvailableMinimumFontSizes  (sizeof(availableMinimumFontSizes)/sizeof(availableMinimumFontSizes[0]))

// Private functions
@interface AppearancesPreferences (Private)
	-(void)initializePreferences;
	-(void)selectUserDefaultFont:(NSString *)name size:(int)size control:(NSPopUpButton *)control sizeControl:(NSComboBox *)sizeControl;
@end

@implementation AppearancesPreferences

/* init
 * Initialize the class
 */
-(id)init
{
	return [super initWithWindowNibName:@"AppearancesPreferences"];
}

/* windowDidLoad
 * First time window load initialisation. Since preferences could potentially be
 * changed while the Preferences window is closed, initialise the controls in the
 * initializePreferences function instead.
 */
-(void)windowDidLoad
{
	[self initializePreferences];
	
	// Set up to be notified if preferences change outside this window
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_FolderFontChange" object:nil];
	[nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_ArticleListFontChange" object:nil];
	[nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_MinimumFontSizeChange" object:nil];
	[nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_PreferenceChange" object:nil];
}

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
	[self selectUserDefaultFont:[prefs articleListFont] size:[prefs articleListFontSize] control:messageListFont sizeControl:messageListFontSize];
	[self selectUserDefaultFont:[prefs folderListFont] size:[prefs folderListFontSize] control:folderFont sizeControl:folderFontSize];
	
	// Set minimum font size option
	[enableMinimumFontSize setState:[prefs enableMinimumFontSize] ? NSOnState : NSOffState];
	[minimumFontSizes setEnabled:[prefs enableMinimumFontSize]];
	
	unsigned int i;
	for (i = 0; i < countOfAvailableMinimumFontSizes; ++i)
		[minimumFontSizes addItemWithObjectValue:[NSNumber numberWithInt:availableMinimumFontSizes[i]]];
	[minimumFontSizes setFloatValue:[prefs minimumFontSize]];
}

/* changeMinimumFontSize
 * Enable whether a minimum font size is used for article display.
 */
-(IBAction)changeMinimumFontSize:(id)sender
{
	BOOL useMinimumFontSize = [sender state] == NSOnState;
	[[Preferences standardPreferences] setEnableMinimumFontSize:useMinimumFontSize];
	[minimumFontSizes setEnabled:useMinimumFontSize];
}

/* selectMinimumFontSize
 * Changes the actual minimum font size for article display.
 */
-(IBAction)selectMinimumFontSize:(id)sender
{
	float newMinimumFontSize = [minimumFontSizes floatValue];
	[[Preferences standardPreferences] setMinimumFontSize:newMinimumFontSize];
}

/* selectUserDefaultFont
 * Initialise the specified font name and size drop down.
 */
-(void)selectUserDefaultFont:(NSString *)name size:(int)size control:(NSPopUpButton *)control sizeControl:(NSComboBox *)sizeControl
{
	NSFontManager * fontManager = [NSFontManager sharedFontManager];
	NSArray * availableFonts = [[fontManager availableFonts] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	
	[control removeAllItems];
	[control addItemsWithTitles:availableFonts];
	[control selectItemWithTitle:name];
	
	unsigned int i;
	for (i = 0; i < countOfAvailableFontSizes; ++i)
		[sizeControl addItemWithObjectValue:[NSNumber numberWithInt:availableFontSizes[i]]];
	[sizeControl setFloatValue:size];
}

/* changeFont
 * Handle changes to any of the font selection options.
 */
-(IBAction)changeFont:(id)sender
{
	Preferences * prefs = [Preferences standardPreferences];
	if (sender == messageListFont)
	{
		[prefs setArticleListFont:[messageListFont titleOfSelectedItem]];
	}
	else if (sender == messageListFontSize)
	{
		[prefs setArticleListFontSize:[messageListFontSize floatValue]];
	}
	else if (sender == folderFont)
	{
		[prefs setFolderListFont:[folderFont titleOfSelectedItem]];
	}
	else if (sender == folderFontSize)
	{
		[prefs setFolderListFontSize:[folderFontSize floatValue]];
	}
}

/* dealloc
 * Clean up and release resources. 
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}
@end
