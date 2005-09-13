//
//  PreferenceController.m
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
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

#import "PreferenceController.h"
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
@interface PreferenceController (Private)
	-(void)selectUserDefaultFont:(NSString *)name size:(int)size control:(NSPopUpButton *)control sizeControl:(NSComboBox *)sizeControl;
	-(void)setDefaultLinksHandler:(NSURL *)pathToNewHandler;
	-(void)controlTextDidEndEditing:(NSNotification *)notification;
	-(void)updateBloglinesUIState;
	-(void)refreshLinkHandler;
	-(IBAction)handleLinkSelector:(id)sender;
@end

@implementation PreferenceController

/* init
 * Initialize the class
 */
-(id)init
{
	internetConfigHandler = nil;
	appToPathMap = [[NSMutableDictionary alloc] init];
	return [super initWithWindowNibName:@"Preferences"];
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
	[nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_CheckFrequencyChange" object:nil];
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

	// Set the check frequency
	[checkFrequency selectItemAtIndex:[checkFrequency indexOfItemWithTag:[prefs refreshFrequency]]];

	// Set check for updates when starting
	[checkForUpdates setState:[prefs checkForNewOnStartup] ? NSOnState : NSOffState];

	// Set check for new messages when starting
	[checkOnStartUp setState:[prefs refreshOnStartup] ? NSOnState : NSOffState];
	
	// Set minimum font size option
	[enableMinimumFontSize setState:[prefs enableMinimumFontSize] ? NSOnState : NSOffState];
	[minimumFontSizes setEnabled:[prefs enableMinimumFontSize]];

	unsigned int i;
	for (i = 0; i < countOfAvailableMinimumFontSizes; ++i)
		[minimumFontSizes addItemWithObjectValue:[NSNumber numberWithInt:availableMinimumFontSizes[i]]];
	[minimumFontSizes setFloatValue:[prefs minimumFontSize]];

	// Set whether links are opened in the background
	[openLinksInBackground setState:[prefs openLinksInBackground] ? NSOnState : NSOffState];
	
	// Set whether links are opened in the external browser
	[openLinksInExternalBrowser setState:[prefs openLinksInVienna] ? NSOffState : NSOnState];
	
	// Set mark read behaviour
	[markReadAfterNext setState:[prefs markReadInterval] == 0 ? NSOnState : NSOffState];
	[markReadAfterDelay setState:[prefs markReadInterval] != 0 ? NSOnState : NSOffState];

	[self refreshLinkHandler];
}

/* refreshLinkHandler
 * Populate the drop down list of registered handlers for the feed:// URL
 * using launch services.
 */
-(void)refreshLinkHandler
{
	NSBundle * appBundle = [NSBundle mainBundle];
	NSString * ourAppName = [[[appBundle executablePath] lastPathComponent] stringByDeletingPathExtension];
	BOOL onTheList = NO;
	NSURL * testURL = [NSURL URLWithString:@"feed://www.test.com"];
	NSString * registeredAppURL = nil;
	CFURLRef appURL = nil;

	// Clear all existing items
	[linksHandler removeAllItems];
	
	// Add the current registered link handler to the start of the list as Safari does. If
	// there's no current registered handler, default to ourself.
	if (LSGetApplicationForURL((CFURLRef)testURL, kLSRolesAll, NULL, &appURL) != kLSApplicationNotFoundErr)
		registeredAppURL = [(NSURL *)appURL path];
	else
	{
		registeredAppURL = [appBundle executablePath];
		onTheList = YES;
	}

	NSString * regAppName = [[registeredAppURL lastPathComponent] stringByDeletingPathExtension];
	[linksHandler addItemWithTitle:regAppName image:[[NSWorkspace sharedWorkspace] iconForFile:registeredAppURL]];
	[linksHandler addSeparator];

	// Maintain a table to map from the short name to the file URL for when
	// the user changes selection and we later need the file URL to register
	// the new selection.
	[appToPathMap setValue:registeredAppURL forKey:regAppName];

	if (appURL != nil)
		CFRelease(appURL);

	// Next, add the list of all registered link handlers under the /Applications folder
	// except for the registered application.
	CFArrayRef cfArrayOfApps = LSCopyApplicationURLsForURL((CFURLRef)testURL, kLSRolesAll);
	if (cfArrayOfApps != nil)
	{
		CFIndex count = CFArrayGetCount(cfArrayOfApps);
		int index;

		for (index = 0; index < count; ++index)
		{
			NSURL * appURL = (NSURL *)CFArrayGetValueAtIndex(cfArrayOfApps, index);
			if ([appURL isFileURL] && [[appURL path] hasPrefix:@"/Applications/"])
			{
				NSString * appName = [[[appURL path] lastPathComponent] stringByDeletingPathExtension];
				if ([appName isEqualToString:ourAppName])
					onTheList = YES;
				if (![appName isEqualToString:regAppName])
					[linksHandler addItemWithTitle:appName image:[[NSWorkspace sharedWorkspace] iconForFile:[appURL path]]];

				[appToPathMap setValue:appURL forKey:appName];
			}
		}
		CFRelease(cfArrayOfApps);
	}

	// Were we on the list? If not, add ourselves
	// complete with our icon.
	if (!onTheList)
	{
		[linksHandler addItemWithTitle:ourAppName image:[[NSWorkspace sharedWorkspace] iconForFile:[appBundle bundlePath]]];

		NSURL * fileURL = [[NSURL alloc] initFileURLWithPath:[appBundle bundlePath]];
		[appToPathMap setValue:fileURL forKey:ourAppName];
		[fileURL release];
	}

	// Add a Select command so the user can manually pick a registered
	// application.
	[linksHandler addSeparator];
	[linksHandler addItemWithTarget:NSLocalizedString(@"Select...", nil) target:@selector(handleLinkSelector:)];

	// Select the registered item
	[linksHandler selectItemAtIndex:0];
}

/* changeOpenLinksInBackground
 * Sets whether Vienna opens new links in the background in the active web
 * browser.
 */
-(IBAction)changeOpenLinksInBackground:(id)sender
{
	[[Preferences standardPreferences] setOpenLinksInBackground:[sender state] == NSOnState];
}

/* changeOpenLinksInExternalBrowser
 * Sets whether Vienna opens new links in the browser view or in
 * the user's current default browser application.
 */
-(IBAction)changeOpenLinksInExternalBrowser:(id)sender
{
	[[Preferences standardPreferences] setOpenLinksInVienna:[sender state] == NSOffState];
}

/* changeCheckForUpdates
 * Set whether Vienna checks for updates when it starts.
 */
-(IBAction)changeCheckForUpdates:(id)sender
{
	[[Preferences standardPreferences] setCheckForNewOnStartup:[sender state] == NSOnState];
}

/* changeCheckOnStartUp
 * Set whether Vienna checks for new messages when it starts.
 */
-(IBAction)changeCheckOnStartUp:(id)sender
{
	[[Preferences standardPreferences] setRefreshOnStartup:[sender state] == NSOnState];
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

/* selectDefaultLinksHandler
 * The user picked something from the list of handlers.
 */
-(IBAction)selectDefaultLinksHandler:(id)sender
{
	NSMenuItem * selectedItem = [linksHandler selectedItem];
	if (selectedItem != nil)
	{
		if ([selectedItem action] == @selector(handleLinkSelector:))
		{
			[self performSelector:[selectedItem action]];
			return;
		}
	}
	[self setDefaultLinksHandler:[appToPathMap valueForKey:[selectedItem title]]];
	[self refreshLinkHandler];
}

/* handleLinkSelector
 * Handle the 'Select...' command on the popup list of registered applications. Display the
 * file browser in the Applications folder and use that to add a new application to the
 * list.
 */
-(IBAction)handleLinkSelector:(id)sender
{
	NSOpenPanel * panel = [NSOpenPanel openPanel];
	[panel beginSheetForDirectory:@"/Applications/"
							 file:nil
							types:[NSArray arrayWithObjects:NSFileTypeForHFSTypeCode('APPL'), nil]
				   modalForWindow:[self window]
					modalDelegate:self
				   didEndSelector:@selector(linkSelectorDidEnd:returnCode:contextInfo:)
					  contextInfo:nil];
}

/* linkSelectorDidEnd
 * Called when the user completes the open panel
 */
-(void)linkSelectorDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[panel orderOut:self];
	if (returnCode == NSOKButton)
	{
		NSURL * fileURL = [[NSURL alloc] initFileURLWithPath:[panel filename]];
		[self setDefaultLinksHandler:fileURL];
		[fileURL release];
	}
	[self refreshLinkHandler];
	[[self window] makeKeyAndOrderFront:self];
}

/* setDefaultLinksHandler
 * Set the default handler for feed links via Internet Config.
 */
-(void)setDefaultLinksHandler:(NSURL *)fileURLToNewHandler
{
	// First time registration of IC.
	if (!internetConfigHandler)
	{
		NSBundle * appBundle = [NSBundle mainBundle];
		NSDictionary * fileAttributes = [appBundle infoDictionary];
		NSString * creatorString = [NSString stringWithFormat:@"'%@'", [fileAttributes objectForKey:@"CFBundleSignature"]];
		int appCode = NSHFSTypeCodeFromFileType(creatorString);

		if (ICStart(&internetConfigHandler, appCode) != noErr)
			internetConfigHandler = nil;
	}

	if (internetConfigHandler)
	{
		if (ICBegin(internetConfigHandler, icReadWritePerm) == noErr)
		{
			LSItemInfoRecord outItemInfo;
			ICAppSpec spec;
			int attr = 0;
			
			LSCopyItemInfoForURL((CFURLRef)fileURLToNewHandler, kLSRequestTypeCreator, &outItemInfo);
			spec.fCreator = outItemInfo.creator;

			CFStringGetPascalString((CFStringRef)[fileURLToNewHandler path], (StringPtr)&spec.name, sizeof(spec.name), kCFStringEncodingMacRoman);
			ICSetPref(internetConfigHandler, kICHelper "feed", attr, &spec, sizeof(spec));

			ICEnd(internetConfigHandler);
		}
	}
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

/* changeMarkReadBehaviour
 * Set the mark read behaviour based on the users selection.
 */
-(IBAction)changeMarkReadBehaviour:(id)sender
{
	float newReadInterval = ([sender selectedCell] == markReadAfterNext) ? 0 : MA_Default_Read_Interval;
	[[Preferences standardPreferences] setMarkReadInterval:newReadInterval];
}

/* changeCheckFrequency
 * The user changed the connect frequency drop down so save the new value and then
 * tell the main app that it changed.
 */
-(IBAction)changeCheckFrequency:(id)sender
{
	int newFrequency = [[checkFrequency selectedItem] tag];
	[[Preferences standardPreferences] setRefreshFrequency:newFrequency];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[appToPathMap release];
	if (internetConfigHandler != nil)
		ICEnd(internetConfigHandler);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}
@end
