//
//  CheckForUpdates.m
//  Vienna
//
//  Created by Steve on Wed Mar 24 2004.
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

#import "CheckForUpdates.h"
#import "DownloadUpdate.h"

@implementation CheckForUpdates

/* checkForUpdate
 * Uses MacPAD to check for updates on a remote site.
 */
-(void)checkForUpdate:(NSWindow *)window showUI:(BOOL)showUI
{
	// Initialize UI
	if (showUI)
	{
		if (!updateWindow)
			[NSBundle loadNibNamed:@"UpdateWindow" owner:self];
		[NSApp beginSheet:updateWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
		[progressBar startAnimation:self];
	}

	// Get our version
	NSString * version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

	// Start thread runnng
	if (!macPAD)
		macPAD = [[MacPADSocket alloc] init];
	[macPAD setDelegate:self];
	updateAvailable = NO;
	isShowingUI = showUI;
	[macPAD performCheckWithVersion:version];
}

/* isUpdateAvailable
 */
-(BOOL)isUpdateAvailable
{
	return updateAvailable;
}

/* doneUpdateCheck
 * Called when the update check is complete.
 */
-(void)doneUpdateCheck
{
	// Save the URL
	[self setUpdateURL:[macPAD productDownloadURL]];
	[self setLatestVersion:[macPAD newVersion]];
	
	// We get here after stopModal is called
	if (isShowingUI)
	{
		[progressBar stopAnimation:self];
		[NSApp endSheet:updateWindow];
		[updateWindow orderOut:self];
	}

	// Always send notification to parent if we're showing UI.
	// Send notification to parent if we're showing UI and there is an update available.
	// Otherwise do nothing.
	if (isShowingUI || (!isShowingUI && updateAvailable))
	{
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:@"MA_Notify_UpdateCheckCompleted" object:self];
	}
	
	// Clean up before we exit
	[macPAD release];
	macPAD = nil;
}

/* updateStatus
 * Returns the update status string.
 */
-(NSString *)updateStatus
{
	return updateStatus;
}

/* updateTitle
 * Returns the update title string
 */
-(NSString *)updateTitle
{
	return updateTitle;
}

/* updateURL
 * Returns the URL where the update is located.
 */
-(NSString *)updateURL
{
	return updateURL;
}

/* latestVersion
 * Returns the version of the update at the update URL.
 */
-(NSString *)latestVersion
{
	return latestVersion;
}

/* setUpdateURL
 * Sets the update URL.
 */
-(void)setUpdateURL:(NSString *)newUpdateURL
{
	[newUpdateURL retain];
	[updateURL release];
	updateURL = newUpdateURL;
}

/* setLatestVersion
 * Sets the latest version.
 */
-(void)setLatestVersion:(NSString *)newLatestVersion
{
	[newLatestVersion retain];
	[latestVersion release];
	latestVersion = newLatestVersion;
}

/* macPADErrorOccurred
 * This function is called if an error occurs during the update check.
 */
-(void)macPADErrorOccurred:(NSNotification *)aNotification
{
	updateTitle = NSLocalizedString(@"An error has occurred.", nil);
	updateStatus = [[[aNotification userInfo] objectForKey:MacPADErrorMessage] retain];
	updateAvailable = NO;
	[self doneUpdateCheck];
}

/* macPADCheckFinished
 * This function is called when the check is finished and no error.
 */
-(void)macPADCheckFinished:(NSNotification *)aNotification
{
	updateTitle = NSLocalizedString(@"Your software is up to date", nil);
	updateStatus = NSLocalizedString(@"Please try again later", nil);
	updateAvailable = [[[aNotification userInfo] objectForKey:MacPADErrorCode] intValue] == kMacPADResultNewVersion;
	[self doneUpdateCheck];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[latestVersion release];
	[updateURL release];
	[updateTitle release];
	[updateStatus release];
	[super dealloc];
}
@end

@implementation AppController (CheckForUpdates)

/* checkForUpdates
 * Use MacPAD to poll the distribution source for updates.
 */
-(IBAction)checkForUpdates:(id)sender
{
	if (!checkUpdates)
		checkUpdates = [[CheckForUpdates alloc] init];
	[checkUpdates checkForUpdate:mainWindow showUI:YES];
}

/* checkForUpdatesComplete
 * Notification function called when an update check is completed.
 */
-(void)checkForUpdatesComplete:(NSNotification *)notification
{
	NSAssert(checkUpdates != nil, @"Notification called with nil checkUpdates");
	if (![checkUpdates isUpdateAvailable])
		[self runOKAlertSheet:[checkUpdates updateTitle] text:[checkUpdates updateStatus]];
	else
	{
		NSString * bodyText = [NSString stringWithFormat:NSLocalizedString(@"Update available text", nil), [checkUpdates latestVersion], [checkUpdates updateURL]];
		NSBeginAlertSheet(NSLocalizedString(@"An update is now available", nil),
						  NSLocalizedString(@"Install Update", nil),
						  NSLocalizedString(@"Do Not Install", nil),
						  nil,
						  mainWindow,
						  self,
						  @selector(doUpdateSelection:returnCode:contextInfo:),
						  nil, nil,
						  bodyText);
	}
}

/* doUpdateSelection
 * Handle the response from the sheet.
 */
-(void)doUpdateSelection:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn)
	{
		[sheet close];
		NSSavePanel * panel = [NSSavePanel savePanel];
		[panel beginSheetForDirectory:nil
								 file:[[checkUpdates updateURL] lastPathComponent]
					   modalForWindow:mainWindow
						modalDelegate:self
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
	}
}

/* beginUpdate
 * Here's where we kick off the update if the user OK'd the save panel.
 */
-(void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[sheet close];
		if (!downloadUpdate)
			downloadUpdate = [[DownloadUpdate alloc] init];
		[downloadUpdate download:mainWindow fromURL:[checkUpdates updateURL] toFilename:[sheet filename]];
	}
}
@end
