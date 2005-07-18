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
#import "ViennaApp.h"
#import "AppController.h"
#import "Constants.h"

// List of available font sizes. I picked the ones that matched
// Mail but you easily could add or remove from the list as needed.
int availableFontSizes[] = { 6, 8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 32, 48, 64 };
#define countOfAvailableFontSizes  (sizeof(availableFontSizes)/sizeof(availableFontSizes[0]))

// Private functions
@interface PreferenceController (Private)
	-(void)selectUserDefaultFont:(NSString *)preferenceName control:(NSPopUpButton *)control sizeControl:(NSComboBox *)sizeControl;
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
	[nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_PreferencesUpdated" object:nil];
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
	// Populate the drop downs with the font names and sizes
	[self selectUserDefaultFont:MAPref_MessageListFont control:messageListFont sizeControl:messageListFontSize];
	[self selectUserDefaultFont:MAPref_FolderFont control:folderFont sizeControl:folderFontSize];
	
	// Set the check frequency
	[checkFrequency selectItemAtIndex:[checkFrequency indexOfItemWithTag:[NSApp refreshFrequency]]];

	// Set check for updates when starting
	[checkForUpdates setState:[NSApp checkForNewOnStartup] ? NSOnState : NSOffState];
	
	// Set check for new messages when starting
	[checkOnStartUp setState:[NSApp refreshOnStartup] ? NSOnState : NSOffState];

	// Set mark read behaviour
	[markReadAfterNext setState:[NSApp markReadInterval] == 0 ? NSOnState : NSOffState];
	[markReadAfterDelay setState:[NSApp markReadInterval] != 0 ? NSOnState : NSOffState];

	// Handle the Bloglines settings
//	[enableBloglines setState:[NSApp enableBloglinesSupport] ? NSOnState : NSOffState];
//	[bloglinesEmailAddress setStringValue:[NSApp bloglinesEmailAddress]];
//	[bloglinesPassword setStringValue:[NSApp bloglinesPassword]];
//	[self updateBloglinesUIState];
	
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

/* changeCheckForUpdates
 * Set whether Vienna checks for updates when it starts.
 */
-(IBAction)changeCheckForUpdates:(id)sender
{
	[NSApp internalChangeCheckOnStartup:[sender state] == NSOnState];
}

/* changeCheckOnStartUp
 * Set whether Vienna checks for new messages when it starts.
 */
-(IBAction)changeCheckOnStartUp:(id)sender
{
	[NSApp internalChangeRefreshOnStartup:[sender state] == NSOnState];
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
 */
-(void)selectUserDefaultFont:(NSString *)preferenceName control:(NSPopUpButton *)control sizeControl:(NSComboBox *)sizeControl
{
	NSFontManager * fontManager = [NSFontManager sharedFontManager];
	NSArray * availableFonts = [[fontManager availableFonts] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:preferenceName];
	NSFont * font = [NSUnarchiver unarchiveObjectWithData:fontData];

	[control removeAllItems];
	[control addItemsWithTitles:availableFonts];
	[control selectItemWithTitle:[font fontName]];

	unsigned int i;
	for (i = 0; i < countOfAvailableFontSizes; ++i)
		[sizeControl addItemWithObjectValue:[NSNumber numberWithInt:availableFontSizes[i]]];
	[sizeControl setFloatValue:[font pointSize]];
}

/* changeFont
 * Handle changes to any of the font selection options.
 */
-(IBAction)changeFont:(id)sender
{
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	if (sender == messageListFont || sender == messageListFontSize)
	{
		NSString * newFontName = [messageListFont titleOfSelectedItem];
		float newFontSize = [messageListFontSize floatValue];

		NSFont * msgListFont = [NSFont fontWithName:newFontName size:newFontSize];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:msgListFont] forKey:MAPref_MessageListFont];
		[nc postNotificationName:@"MA_Notify_MessageListFontChange" object:msgListFont];
	}
	else if (sender == folderFont || sender == folderFontSize)
	{
		NSString * newFontName = [folderFont titleOfSelectedItem];
		float newFontSize = [folderFontSize floatValue];
		
		NSFont * fldrFont = [NSFont fontWithName:newFontName size:newFontSize];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:fldrFont] forKey:MAPref_FolderFont];
		[nc postNotificationName:@"MA_Notify_FolderFontChange" object:fldrFont];
	}
}

/* changeMarkReadBehaviour
 * Set the mark read behaviour based on the users selection.
 */
-(IBAction)changeMarkReadBehaviour:(id)sender
{
	float newReadInterval = ([sender selectedCell] == markReadAfterNext) ? 0 : MA_Default_Read_Interval;
	[NSApp internalSetMarkReadInterval:newReadInterval];
}

/* changeCheckFrequency
 * The user changed the connect frequency drop down so save the new value and then
 * tell the main app that it changed.
 */
-(IBAction)changeCheckFrequency:(id)sender
{
	int newFrequency = [[checkFrequency selectedItem] tag];
	[NSApp internalSetRefreshFrequency:newFrequency];
}

/* changeEnableBloglines
 * Respond to the user enabling or disabling Bloglines support.
 */
-(IBAction)changeEnableBloglines:(id)sender
{
	[NSApp setEnableBloglinesSupport:[sender state] == NSOnState];
	[self updateBloglinesUIState];
}

/* changeBloglinesEmailAddress
 * Handle changes in the Bloglines E-mail address field.
 */
-(IBAction)changeBloglinesEmailAddress:(id)sender
{
	[NSApp internalSetBloglinesEmailAddress:[sender stringValue]];
}

/* changeBloglinesPassword
 * Handle changes in the Bloglines password field.
 */
-(IBAction)changeBloglinesPassword:(id)sender
{
	[NSApp internalSetBloglinesPassword:[sender stringValue]];
}

/* updateBloglinesUIState
 * Enable or disable the Bloglines e-mail address and password fields depending on whether or not
 * Bloglines support is enabled.
 */
-(void)updateBloglinesUIState
{
	BOOL isBlogLinesEnabled = [NSApp enableBloglinesSupport];
	[bloglinesEmailAddress setEnabled:isBlogLinesEnabled];
	[bloglinesPassword setEnabled:isBlogLinesEnabled];
	[bloglinesEmailAddressLabel setEnabled:isBlogLinesEnabled];
	[bloglinesPasswordLabel setEnabled:isBlogLinesEnabled];
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
