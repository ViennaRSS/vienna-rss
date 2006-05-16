//
//  ReadingPreferences.m
//  Vienna
//
//  Created by Steve on 5/15/06.
//  Copyright (c) 2004-2006 Steve Palmer. All rights reserved.
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

#import "ReadingPreferences.h"
#import "Constants.h"
#import "Preferences.h"

// Private functions
@interface ReadingPreferences (Private)
	-(void)initializePreferences;
@end

@implementation ReadingPreferences

/* init
 * Initialize the class
 */
-(id)init
{
	return [super initWithWindowNibName:@"ReadingPreferences"];
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
	
	// Set mark read behaviour
	[markReadAfterNext setState:[prefs markReadInterval] == 0 ? NSOnState : NSOffState];
	[markReadAfterDelay setState:[prefs markReadInterval] != 0 ? NSOnState : NSOffState];
	
	// Show new articles notification option
	[newArticlesNotificationNothingButton setState:([prefs newArticlesNotification] == MA_NewArticlesNotification_None) ? NSOnState : NSOffState];
	[newArticlesNotificationBadgeButton setState:([prefs newArticlesNotification] == MA_NewArticlesNotification_Badge) ? NSOnState : NSOffState];
	[newArticlesNotificationBounceButton setState:([prefs newArticlesNotification] == MA_NewArticlesNotification_Bounce) ? NSOnState : NSOffState];

	// Set folder ordering method
	[orderManually setState:([prefs foldersTreeSortMethod] == MA_FolderSort_Manual) ? NSOnState : NSOffState];
	[orderAutomaticByName setState:([prefs foldersTreeSortMethod] == MA_FolderSort_ByName) ? NSOnState : NSOffState];
}

/* changeNewArticlesNotification
 * Change the method by which new articles are announced.
 */
-(IBAction)changeNewArticlesNotification:(id)sender
{
	Preferences * prefs = [Preferences standardPreferences];
	if ([sender selectedCell] == newArticlesNotificationNothingButton)
	{
		[prefs setNewArticlesNotification:MA_NewArticlesNotification_None];
		return;
	}
	if ([sender selectedCell] == newArticlesNotificationBadgeButton)
	{
		[prefs setNewArticlesNotification:MA_NewArticlesNotification_Badge];
		return;
	}
	if ([sender selectedCell] == newArticlesNotificationBounceButton)
	{
		[prefs setNewArticlesNotification:MA_NewArticlesNotification_Bounce];
		return;
	}
}

/* changeMarkReadBehaviour
 * Set the mark read behaviour based on the users selection.
 */
-(IBAction)changeMarkReadBehaviour:(id)sender
{
	float newReadInterval = ([sender selectedCell] == markReadAfterNext) ? 0 : MA_Default_Read_Interval;
	[[Preferences standardPreferences] setMarkReadInterval:newReadInterval];
}

/* changeOrderingBehaviour
 * Change the method by which the folder list orders the folders.
 */
-(IBAction)changeOrderingBehaviour:(id)sender
{
	if ([sender selectedCell] == orderAutomaticByName)
	{
		[[Preferences standardPreferences] setFoldersTreeSortMethod:MA_FolderSort_ByName];
		return;
	}
	if ([sender selectedCell] == orderManually)
	{
		[[Preferences standardPreferences] setFoldersTreeSortMethod:MA_FolderSort_Manual];
		return;
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
