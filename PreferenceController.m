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
#import "PreferenceNames.h"
#import "ViennaApp.h"
#import "AppController.h"

/* Actual definitions of the preference tags. Keep this in
 * sync with the PreferenceNames.h file.
 */
NSString * MAPref_MessageListFont = @"MessageListFont";
NSString * MAPref_FolderFont = @"FolderFont";
NSString * MAPref_CachedFolderID = @"CachedFolderID";
NSString * MAPref_DefaultDatabase = @"DefaultDatabase";
NSString * MAPref_SortDirection = @"SortDirection";
NSString * MAPref_SortColumn = @"SortColumn";
NSString * MAPref_CheckFrequency = @"CheckFrequencyInSeconds";
NSString * MAPref_MessageColumns = @"MessageColumns";
NSString * MAPref_AutoCollapseFolders = @"AutoCollapseFolders";
NSString * MAPref_CheckForUpdatesOnStartup = @"CheckForUpdatesOnStartup";
NSString * MAPref_CheckForNewMessagesOnStartup = @"CheckForNewMessagesOnStartup";
NSString * MAPref_FolderImagesFolder = @"FolderIconsCache";
NSString * MAPref_StylesFolder = @"StylesFolder";
NSString * MAPref_RefreshThreads = @"MaxRefreshThreads";
NSString * MAPref_ActiveStyleName = @"ActiveStyle";
NSString * MAPref_FolderStates = @"FolderStates";
NSString * MAPref_BacktrackQueueSize = @"BacktrackQueueSize";
NSString * MAPref_ReadingPaneOnRight = @"ReadingPaneOnRight";
NSString * MAPref_EnableBloglinesSupport = @"EnableBloglinesSupport";
NSString * MAPref_BloglinesEmailAddress = @"BloglinesEmailAddress";

// List of available font sizes. I picked the ones that matched
// Mail but you easily could add or remove from the list as needed.
int availableFontSizes[] = { 6, 8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 32, 48, 64 };
#define countOfAvailableFontSizes  (sizeof(availableFontSizes)/sizeof(availableFontSizes[0]))

// Private functions
@interface PreferenceController (Private)
	-(void)selectUserDefaultFont:(NSString *)preferenceName control:(NSPopUpButton *)control sizeControl:(NSComboBox *)sizeControl;
	-(void)setDefaultLinksHandler:(NSString *)newHandler creatorCode:(OSType)creatorCode;
	-(void)controlTextDidEndEditing:(NSNotification *)notification;
	-(void)updateBloglinesUIState;
@end

@implementation PreferenceController

/* init
 * Initialize the class
 */
-(id)init
{
	internetConfigHandler = nil;
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

	// Handle the Bloglines settings
//	[enableBloglines setState:[NSApp enableBloglinesSupport] ? NSOnState : NSOffState];
//	[bloglinesEmailAddress setStringValue:[NSApp bloglinesEmailAddress]];
//	[bloglinesPassword setStringValue:[NSApp bloglinesPassword]];
//	[self updateBloglinesUIState];

	// Get some info about us
	NSBundle * appBundle = [NSBundle mainBundle];
	NSString * appName = [[NSApp delegate] appName];
	NSString * fullAppName = @"";
	OSType appCode = 0L;
	if (appBundle != nil)
	{
		NSDictionary * fileAttributes = [appBundle infoDictionary];
		NSString * creatorString = [NSString stringWithFormat:@"'%@'", [fileAttributes objectForKey:@"CFBundleSignature"]];
		appCode = NSHFSTypeCodeFromFileType(creatorString);
		fullAppName = [NSString stringWithFormat:@"%@ (%@)", appName, [fileAttributes objectForKey:@"CFBundleShortVersionString"]];
	}
	
	// Populate links handler combo
	if (!internetConfigHandler)
	{
		if (ICStart(&internetConfigHandler, appCode) != noErr)
			internetConfigHandler = nil;
	}
	if (internetConfigHandler)
	{
		if (ICBegin(internetConfigHandler, icReadWritePerm) == noErr)
		{
			NSString * defaultHandler = nil;
			BOOL onTheList = NO;
			long size;
			ICAttr attr;

			// Get the default handler for the feed URL. If there's no existing default
			// handler for some reason, we register ourselves.
			ICAppSpec spec;
			if (ICGetPref(internetConfigHandler, kICHelper "feed", &attr, &spec, &size) == noErr)
				defaultHandler = (NSString *)CFStringCreateWithPascalString(NULL, spec.name, kCFStringEncodingMacRoman);
			else
			{
				defaultHandler = appName;
				[self setDefaultLinksHandler:appName creatorCode:appCode];
			}

			// Fill the list with all registered helpers for the feed URL.
			ICAppSpecList * specList;
			size = 4096;
			if ((specList = (ICAppSpecList *)malloc(size)) != nil)
			{
				[linksHandler removeAllItems];
				if (ICGetPref(internetConfigHandler, kICHelperList "feed", &attr, specList, &size) == noErr)
				{
					int c;
					for (c = 0; c < specList->numberOfItems; ++c)
					{
						ICAppSpec * spec = &specList->appSpecs[c];
						NSString * handler = (NSString *)CFStringCreateWithPascalString(NULL, spec->name, kCFStringEncodingMacRoman);
						NSMenuItem * item;

						if ([appName isEqualToString:handler])
						{
							[linksHandler addItemWithTitle:fullAppName];
							item = (NSMenuItem *)[linksHandler itemWithTitle:fullAppName];
							[item setTag:appCode];
							onTheList = YES;
						}
						else
						{
							[linksHandler addItemWithTitle:handler];
							item = (NSMenuItem *)[linksHandler itemWithTitle:handler];
							[item setTag:spec->fCreator];
						}
						if ([defaultHandler isEqualToString:handler])
							[linksHandler selectItem:item];
					}
				}
				free(specList);
			}
			
			// Were we on the list? If not, add ourselves
			if (!onTheList)
			{
				[linksHandler addItemWithTitle:fullAppName];
				NSMenuItem * item = [linksHandler itemWithTitle:fullAppName];
				[item setTag:appCode];
			}

			// Done
			ICEnd(internetConfigHandler);
		}
	}
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
		NSString * name = [selectedItem title];
		OSType creator = [selectedItem tag];
		[self setDefaultLinksHandler:name creatorCode:creator];
	}
}

/* setDefaultLinksHandler
 * Set the default handler for cix links via Internet Config.
 */
-(void)setDefaultLinksHandler:(NSString *)newHandler creatorCode:(OSType)creatorCode
{
	ICAppSpec spec;
	int attr = 0;

	spec.fCreator = creatorCode;
	CFStringGetPascalString((CFStringRef)newHandler, (StringPtr)&spec.name, sizeof(spec.name), kCFStringEncodingMacRoman);
	ICSetPref(internetConfigHandler, kICHelper "feed", attr, &spec, sizeof(spec));
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
	if (internetConfigHandler != nil)
		ICEnd(internetConfigHandler);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}
@end
