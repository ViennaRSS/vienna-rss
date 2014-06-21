//
//  GeneralPreferences.m
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

#import "GeneralPreferences.h"
#import "PopUpButtonExtensions.h"
#import "AppController.h"
#import "Constants.h"
#import "Preferences.h"

// Private functions
@interface GeneralPreferences (Private)
	-(void)initializePreferences;
	-(void)selectUserDefaultFont:(NSString *)name size:(int)size control:(NSPopUpButton *)control sizeControl:(NSComboBox *)sizeControl;
	-(void)setDefaultLinksHandler:(NSURL *)pathToNewHandler;
	-(void)controlTextDidEndEditing:(NSNotification *)notification;
	-(void)refreshLinkHandler;
	-(IBAction)handleLinkSelector:(id)sender;
	-(void)updateDownloadsPopUp:(NSString *)downloadFolderPath;
@end

@implementation GeneralPreferences

/* init
 * Initialize the class
 */
-(id)init
{
	if ((self = [super initWithWindowNibName:@"GeneralPreferences"]) != nil)
	{
		internetConfigHandler = nil;
		appToPathMap = [[NSMutableDictionary alloc] init];
	}
	return self;
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
	[nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_CheckFrequencyChange" object:nil];
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

	// Set the check frequency
	[checkFrequency selectItemAtIndex:[checkFrequency indexOfItemWithTag:[prefs refreshFrequency]]];
	
	// Set check for updates when starting
	[checkForUpdates setState:[prefs checkForNewOnStartup] ? NSOnState : NSOffState];
	
	// Set check for new articles when starting
	[checkOnStartUp setState:[prefs refreshOnStartup] ? NSOnState : NSOffState];
	
	// Set range of auto-expire values
	[expireDuration removeAllItems];
	[expireDuration insertItemWithTag:NSLocalizedString(@"Never", nil) tag:0 atIndex:0];
	[expireDuration insertItemWithTag:NSLocalizedString(@"After a Day", nil) tag:1 atIndex:1];
	[expireDuration insertItemWithTag:NSLocalizedString(@"After 2 Days", nil) tag:2 atIndex:2];
	[expireDuration insertItemWithTag:NSLocalizedString(@"After a Week", nil) tag:7 atIndex:3];
	[expireDuration insertItemWithTag:NSLocalizedString(@"After 2 Weeks", nil) tag:14 atIndex:4];
	[expireDuration insertItemWithTag:NSLocalizedString(@"After a Month", nil) tag:1000 atIndex:5];
	
	// Set auto-expire duration
	[expireDuration selectItemAtIndex:[expireDuration indexOfItemWithTag:[prefs autoExpireDuration]]];
	
	// Set download folder
	[self updateDownloadsPopUp:[prefs downloadFolder]];
	
	// Set whether the application is shown in the menu bar
	[showAppInMenuBar setState:[prefs showAppInStatusBar] ? NSOnState : NSOffState];

	// Set whether links are opened in the background
	[openLinksInBackground setState:[prefs openLinksInBackground] ? NSOnState : NSOffState];
	
	// Set whether links are opened in the external browser
	[openLinksInExternalBrowser setState:[prefs openLinksInVienna] ? NSOffState : NSOnState];
	
	// Set mark read behaviour
	[markReadAfterNext setState:[prefs markReadInterval] == 0 ? NSOnState : NSOffState];
	[markReadAfterDelay setState:[prefs markReadInterval] != 0 ? NSOnState : NSOffState];
	
	// Show new articles notification option
	[newArticlesNotificationNothingButton setState:([prefs newArticlesNotification] == MA_NewArticlesNotification_None) ? NSOnState : NSOffState];
	[newArticlesNotificationBadgeButton setState:([prefs newArticlesNotification] == MA_NewArticlesNotification_Badge) ? NSOnState : NSOffState];
	[newArticlesNotificationBounceButton setState:([prefs newArticlesNotification] == MA_NewArticlesNotification_Bounce) ? NSOnState : NSOffState];
	
	// Set whether updated articles are considered as new
	[markUpdatedAsNew setState:[prefs markUpdatedAsNew] ? NSOnState : NSOffState];

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
	[linksHandler addItemWithTag:NSLocalizedString(@"Select...", nil) tag:-1];
	
	// Select the registered item
	[linksHandler selectItemAtIndex:0];
}

/* changeExpireDuration
 * Handle the change to the auto-expire duration.
 */
-(IBAction)changeExpireDuration:(id)sender
{
	NSMenuItem * selectedItem = [expireDuration selectedItem];
	if (selectedItem != nil)
		[[Preferences standardPreferences] setAutoExpireDuration:[selectedItem tag]];
}

/* changeOpenLinksInBackground
 * Sets whether Vienna opens new links in the background in the active web
 * browser.
 */
-(IBAction)changeOpenLinksInBackground:(id)sender
{
	[[Preferences standardPreferences] setOpenLinksInBackground:[sender state] == NSOnState];
}

/* changeShowAppInMenuBar
 * Sets whether or not the application icon is shown in the menu bar.
 */
-(IBAction)changeShowAppInMenuBar:(id)sender
{
	[[Preferences standardPreferences] setShowAppInStatusBar:[sender state] == NSOnState];
}

/* changeMarkUpdatedAsNew
 * Sets whether Vienna considers updated articles
 * as new ones.
 */
-(IBAction)changeMarkUpdatedAsNew:(id)sender
{
	[[Preferences standardPreferences] setMarkUpdatedAsNew:[sender state] == NSOnState];
}

/* changeOpenLinksInExternalBrowser
 * Sets whether Vienna opens new links in the browser view or in
 * the user's current default browser application.
 */
-(IBAction)changeOpenLinksInExternalBrowser:(id)sender
{
	[[Preferences standardPreferences] setOpenLinksInVienna:[sender state] == NSOffState];
}

/* changeDownloadFolder
 * Bring up the folder browser to pick a new download folder.
 */
-(IBAction)changeDownloadFolder:(id)sender
{
	NSOpenPanel * openPanel = [NSOpenPanel openPanel];
	NSWindow * prefPaneWindow = [downloadFolder window];

	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanCreateDirectories:YES];
	[openPanel setCanChooseFiles:NO];
	[openPanel setDirectoryURL:[[NSFileManager defaultManager] URLForDirectory:NSDownloadsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil]];
	[openPanel beginSheetModalForWindow:prefPaneWindow completionHandler:^(NSInteger returnCode) {
			// Force the focus back to the main preferences pane
			[openPanel orderOut:self];
			[prefPaneWindow makeKeyAndOrderFront:prefPaneWindow];

			if (returnCode == NSOKButton)
			{
				NSString * downloadFolderPath = [[openPanel directoryURL] path];
				[[Preferences standardPreferences] setDownloadFolder:downloadFolderPath];
				[self updateDownloadsPopUp:downloadFolderPath];
			}

			if (returnCode == NSCancelButton)
				[downloadFolder selectItemAtIndex:0];
		}];
}

/* updateDownloadsPopUp
 * Update the Downloads folder popup with the specified download folder path and image.
 */
-(void)updateDownloadsPopUp:(NSString *)downloadFolderPath
{
	NSMenuItem * downloadPathItem = [downloadFolder itemAtIndex:0];
	NSImage * pathImage = [[NSWorkspace sharedWorkspace] iconForFile:downloadFolderPath];
	
	[pathImage setSize:NSMakeSize(16, 16)];
	
	[downloadPathItem setTitle:[downloadFolderPath lastPathComponent]];
	[downloadPathItem setImage:pathImage];
	[downloadPathItem setState:NSOffState];

	[downloadFolder selectItemAtIndex:0];
}

/* changeCheckForUpdates
 * Set whether Vienna checks for updates when it starts.
 */
-(IBAction)changeCheckForUpdates:(id)sender
{
	[[Preferences standardPreferences] setCheckForNewOnStartup:[sender state] == NSOnState];
}

/* changeCheckOnStartUp
 * Set whether Vienna checks for new articles when it starts.
 */
-(IBAction)changeCheckOnStartUp:(id)sender
{
	[[Preferences standardPreferences] setRefreshOnStartup:[sender state] == NSOnState];
}

/* selectDefaultLinksHandler
 * The user picked something from the list of handlers.
 */
-(IBAction)selectDefaultLinksHandler:(id)sender
{
	NSMenuItem * selectedItem = [linksHandler selectedItem];
	if (selectedItem != nil)
	{
		if ([selectedItem tag] == -1)
		{
			[self handleLinkSelector:self];
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
	NSWindow * prefPaneWindow = [linksHandler window];

	[panel setDirectoryURL:[[NSFileManager defaultManager] URLForDirectory:NSApplicationDirectory inDomain:NSLocalDomainMask appropriateForURL:nil create:NO error:nil]];
	[panel setAllowedFileTypes:[NSArray arrayWithObjects:NSFileTypeForHFSTypeCode('APPL'), nil]];
	[panel beginSheetModalForWindow:prefPaneWindow completionHandler:^(NSInteger returnCode) {
		[panel orderOut:self];
		NSWindow * prefPaneWindow = [linksHandler window];
		[prefPaneWindow makeKeyAndOrderFront:self];

		if (returnCode == NSOKButton)
			[self setDefaultLinksHandler:[panel URL]];
		[self refreshLinkHandler];
	}];
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

/* changeCheckFrequency
 * The user changed the connect frequency drop down so save the new value and then
 * tell the main app that it changed.
 */
-(IBAction)changeCheckFrequency:(id)sender
{
	int newFrequency = [[checkFrequency selectedItem] tag];
	[[Preferences standardPreferences] setRefreshFrequency:newFrequency];
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
