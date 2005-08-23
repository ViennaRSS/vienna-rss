//
//  ViennaApp.m
//  Vienna
//
//  Created by Steve on Tue Jul 06 2004.
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

#import "ViennaApp.h"
#import "AppController.h"
#import "Import.h"
#import "Export.h"
#import "Refresh.h"
#import "Constants.h"
#import "FoldersTree.h"
#import "KeyChain.h"

static NSString * MA_Bloglines_URL = @"http://rpc.bloglines.com/listsubs";

@implementation ViennaApp

/* init
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		hasPrefs = NO;
	}
	return self;
}

/* initialisePreferences
 * Do delay-loaded initialisation of preferences.
 */
-(void)initialisePreferences
{
	if (!hasPrefs)
	{
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		isBloglinesEnabled = [defaults boolForKey:MAPref_EnableBloglinesSupport];
		readingPaneOnRight = [defaults boolForKey:MAPref_ReadingPaneOnRight];
		markReadInterval = [defaults floatForKey:MAPref_MarkReadInterval];
		minimumFontSize = [defaults integerForKey:MAPref_MinimumFontSize];
		enableMinimumFontSize = [defaults boolForKey:MAPref_UseMinimumFontSize];
		openLinksInVienna = [defaults boolForKey:MAPref_OpenLinksInVienna];
		openLinksInBackground = [defaults boolForKey:MAPref_OpenLinksInBackground];
		bloglinesEmailAddress = [[defaults valueForKey:MAPref_BloglinesEmailAddress] retain];
		bloglinesPassword = [bloglinesEmailAddress ? [KeyChain getPasswordFromKeychain:bloglinesEmailAddress url:MA_Bloglines_URL] : @"" retain];
		hasPrefs = YES;
	}
}

/* handleRefreshAllSubscriptions
 * Refreshes all folders.
 */
-(id)handleRefreshAllSubscriptions:(NSScriptCommand *)cmd
{
	[[self delegate] refreshAllSubscriptions:nil];
	return nil;
}

/* handleRefreshSubscription
 * Refreshes a specific folder.
 */
-(id)handleRefreshSubscription:(NSScriptCommand *)cmd
{
	NSDictionary * args = [cmd evaluatedArguments];
	Folder * folder = [args objectForKey:@"Folder"];
	if (folder != nil)
		[[self delegate] refreshSubscriptions:[NSArray arrayWithObject:folder]];
	return nil;
}

/* handleMarkAllRead
 * Mark all messages in the specified folder as read
 */
-(id)handleMarkAllRead:(NSScriptCommand *)cmd
{
	NSDictionary * args = [cmd evaluatedArguments];
	Folder * folder = [args objectForKey:@"Folder"];
	if (folder != nil)
		[[self delegate] markAllReadInArray:[NSArray arrayWithObject:folder]];
	return nil;
}

/* handleImportSubscriptions
 * Import subscriptions from a file.
 */
-(id)handleImportSubscriptions:(NSScriptCommand *)cmd
{
	NSDictionary * args = [cmd evaluatedArguments];
	[[self delegate] importFromFile:[args objectForKey:@"FileName"]];
	return nil;
}

/* handleExportSubscriptions
 * Export all or specified folders to a file.
 */
-(id)handleExportSubscriptions:(NSScriptCommand *)cmd
{
	NSDictionary * args = [cmd evaluatedArguments];
	Folder * folder = [args objectForKey:@"Folder"];
	
	// If no folder is specified, default to exporting everything.
	NSArray * array = (folder ? [NSArray arrayWithObject:folder] : [self folders]);
	[[self delegate] exportToFile:[args objectForKey:@"FileName"] from:array];
	return nil;
}

/* handleNewSubscription
 * Create a new subscription in the specified folder. If the specified folder is not
 * a group folder, the parent of the specified folder is used.
 */
-(id)handleNewSubscription:(NSScriptCommand *)cmd
{
	NSDictionary * args = [cmd evaluatedArguments];
	Folder * folder = [args objectForKey:@"UnderFolder"];

	int parentId = folder ? ((IsGroupFolder(folder)) ? [folder itemId] :[folder parentId]) : MA_Root_Folder;

	[[self delegate] createNewSubscription:[args objectForKey:@"URL"] underFolder:parentId];
	return nil;
}

/* applicationVersion
 * Return the applications version number.
 */
-(NSString *)applicationVersion
{
	NSBundle * appBundle = [NSBundle mainBundle];
	NSDictionary * fileAttributes = [appBundle infoDictionary];
	return [fileAttributes objectForKey:@"CFBundleShortVersionString"];
}

/* folders
 * Return a flat array of all folders
 */
-(NSArray *)folders
{
	return [[self delegate] folders];
}

/* folderListFont
 * Retrieve the name of the font used in the folder list
 */
-(NSString *)folderListFont
{
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_FolderFont];
	NSFont * font = [NSUnarchiver unarchiveObjectWithData:fontData];
	return [font fontName];
}

/* folderListFontSize
 * Retrieve the size of the font used in the folder list
 */
-(int)folderListFontSize
{
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_FolderFont];
	NSFont * font = [NSUnarchiver unarchiveObjectWithData:fontData];
	return [font pointSize];
}

/* setFolderListFont
 * Retrieve the name of the font used in the folder list
 */
-(void)setFolderListFont:(NSString *)newFontName
{
	NSFont * fldrFont = [NSFont fontWithName:newFontName size:[self folderListFontSize]];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:fldrFont] forKey:MAPref_FolderFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderFontChange" object:fldrFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* setFolderListFontSize
 * Changes the size of the font used in the folder list.
 */
-(void)setFolderListFontSize:(int)newFontSize
{
	NSFont * fldrFont = [NSFont fontWithName:[self folderListFont] size:newFontSize];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:fldrFont] forKey:MAPref_FolderFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderFontChange" object:fldrFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* articleListFont
 * Retrieve the name of the font used in the article list
 */
-(NSString *)articleListFont
{
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_MessageListFont];
	NSFont * font = [NSUnarchiver unarchiveObjectWithData:fontData];
	return [font fontName];
}

/* articleListFontSize
 * Retrieve the size of the font used in the article list
 */
-(int)articleListFontSize
{
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_MessageListFont];
	NSFont * font = [NSUnarchiver unarchiveObjectWithData:fontData];
	return [font pointSize];
}

/* setArticleListFont
 * Retrieve the name of the font used in the article list
 */
-(void)setArticleListFont:(NSString *)newFontName
{
	NSFont * fldrFont = [NSFont fontWithName:newFontName size:[self articleListFontSize]];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:fldrFont] forKey:MAPref_MessageListFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_MessageListFontChange" object:fldrFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* setArticleListFontSize
 * Changes the size of the font used in the article list.
 */
-(void)setArticleListFontSize:(int)newFontSize
{
	NSFont * fldrFont = [NSFont fontWithName:[self articleListFont] size:newFontSize];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:fldrFont] forKey:MAPref_MessageListFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_MessageListFontChange" object:fldrFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* isRefreshing
 * Return whether or not Vienna is in the process of connecting.
 */
-(BOOL)isRefreshing
{
	return [[self delegate] isConnecting];
}

/* unreadCount
 * Return the number of unread messages.
 */
-(int)unreadCount
{
	return [[Database sharedDatabase] countOfUnread];
}

/* displayStyle
 * Retrieves the name of the current article display style.
 */
-(NSString *)displayStyle
{
	return [[NSUserDefaults standardUserDefaults] valueForKey:MAPref_ActiveStyleName];
}

/* setDisplayStyle
 * Changes the style used for displaying articles
 */
-(void)setDisplayStyle:(NSString *)newStyleName
{
	[[self delegate] setActiveStyle:newStyleName refresh:YES];
}

/* markReadInterval
 * Return the number of seconds after an unread article is displayed before it is marked as read.
 * A value of zero means that it remains marked unread until the user does 'Display Next Unread'.
 */
-(float)markReadInterval
{
	[self initialisePreferences];
	return markReadInterval;
}

/* setMarkReadInterval
 * Changes the interval after an article is read before it is marked as read then sends a notification
 * that the preferences have changed.
 */
-(void)setMarkReadInterval:(float)newInterval
{
	[self internalSetMarkReadInterval:newInterval];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalSetMarkReadInterval
 * Changes the interval after an article is read before it is marked as read.
 */
-(void)internalSetMarkReadInterval:(float)newInterval
{	
	[self initialisePreferences];
	if (markReadInterval != newInterval)
	{
		markReadInterval = newInterval;
		NSNumber * floatValue = [NSNumber numberWithFloat:newInterval];
		[[NSUserDefaults standardUserDefaults] setObject:floatValue forKey:MAPref_MarkReadInterval];
	}
}

/* openLinksInVienna
 * Returns whether or not URL links clicked in Vienna should be opened in Vienna's own browser or
 * in an the default external Browser (Safari or FireFox, etc).
 */
-(BOOL)openLinksInVienna
{
	[self initialisePreferences];
	return openLinksInVienna;
}

/* setOpenLinksInVienna
 * Changes whether or not links clicked in Vienna are opened in Vienna or the default system
 * browser, then sends a notification that the preferences have changed.
 */
-(void)setOpenLinksInVienna:(float)flag
{
	[self internalSetOpenLinksInVienna:flag];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalSetOpenLinksInVienna
 * Changes whether or not links clicked in Vienna are opened in the background.
 */
-(void)internalSetOpenLinksInVienna:(BOOL)flag
{	
	[self initialisePreferences];
	if (openLinksInVienna != flag)
	{
		openLinksInVienna = flag;
		NSNumber * boolFlag = [NSNumber numberWithBool:flag];
		[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_OpenLinksInVienna];
	}
}

/* openLinksInBackground
 * Returns whether or not links clicked in Vienna are opened in the background.
 */
-(BOOL)openLinksInBackground
{
	[self initialisePreferences];
	return openLinksInBackground;
}

/* setOpenLinksInBackground
 * Changes whether or not links clicked in Vienna are opened in the background then sends a notification
 * that the preferences have changed.
 */
-(void)setOpenLinksInBackground:(float)flag
{
	[self internalSetOpenLinksInBackground:flag];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalSetOpenLinksInBackground
 * Changes whether or not links clicked in Vienna are opened in the background.
 */
-(void)internalSetOpenLinksInBackground:(BOOL)flag
{	
	[self initialisePreferences];
	if (openLinksInBackground != flag)
	{
		openLinksInBackground = flag;
		NSNumber * boolFlag = [NSNumber numberWithBool:flag];
		[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_OpenLinksInBackground];
	}
}

/* checkForNewOnStartup
 * Returns whether or not Vienna checks for new versions when it starts.
 */
-(BOOL)checkForNewOnStartup
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:MAPref_CheckForUpdatesOnStartup];
}

/* setCheckForNewOnStartup
 * Changes whether or not Vienna checks for new versions when it starts.
 */
-(void)setCheckForNewOnStartup:(BOOL)flag
{
	[self internalChangeCheckOnStartup:flag];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalChangeCheckOnStartup
 * Changes whether or not Vienna checks for new versions when it starts.
 */
-(void)internalChangeCheckOnStartup:(BOOL)flag
{
	NSNumber * boolFlag = [NSNumber numberWithBool:flag];
	[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_CheckForUpdatesOnStartup];
}

/* enableBloglinesSupport
 * Returns whether or not Bloglines spport is enabled.
 */
-(BOOL)enableBloglinesSupport
{
	[self initialisePreferences];
	return isBloglinesEnabled;
}

/* setEnableBloglinesSupport
 * Changes whether or not Bloglines spport is enabled.
 */
-(void)setEnableBloglinesSupport:(BOOL)flag
{
	[self internalSetEnableBloglinesSupport:flag];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}
	
/* internalSetEnableBloglinesSupport
 * Changes whether or not Bloglines support is enabled.
 */
-(void)internalSetEnableBloglinesSupport:(BOOL)flag
{
	[self initialisePreferences];
	if (flag != isBloglinesEnabled)
	{
		isBloglinesEnabled = flag;
		NSNumber * boolFlag = [NSNumber numberWithBool:flag];
		[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_EnableBloglinesSupport];
	}
}

/* bloglinesEmailAddress
 * Returns the e-mail address associated with the user's Bloglines account.
 */
-(NSString *)bloglinesEmailAddress
{
	[self initialisePreferences];
	return bloglinesEmailAddress;
}

/* setBloglinesEmailAddress
 * Changes the e-mail address associated with the user's Bloglines account.
 */
-(void)setBloglinesEmailAddress:(NSString *)newEmailAddress
{
	[self internalSetBloglinesEmailAddress:newEmailAddress];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalSetBloglinesEmailAddress
 * Changes the e-mail address associated with the user's Bloglines account.
 */
-(void)internalSetBloglinesEmailAddress:(NSString *)newEmailAddress
{
	[self initialisePreferences];
	[newEmailAddress retain];
	[bloglinesEmailAddress release];
	bloglinesEmailAddress = newEmailAddress;
	[[NSUserDefaults standardUserDefaults] setObject:bloglinesEmailAddress forKey:MAPref_BloglinesEmailAddress];
}

/* bloglinesPassword
 * Returns the password associated with the user's Bloglines account.
 */
-(NSString *)bloglinesPassword
{
	[self initialisePreferences];
	return bloglinesPassword;
}

/* setBloglinesPassword
 * Changes the password associated with the user's Bloglines account.
 */
-(void)setBloglinesPassword:(NSString *)newPassword
{
	[self internalSetBloglinesPassword:newPassword];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalSetBloglinesPassword
 * Changes the password associated with the user's Bloglines account.
 */
-(void)internalSetBloglinesPassword:(NSString *)newPassword
{
	[self initialisePreferences];
	[newPassword retain];
	[bloglinesPassword release];
	bloglinesPassword = newPassword;
	[KeyChain setPasswordInKeychain:newPassword username:bloglinesEmailAddress url:MA_Bloglines_URL];
}

/* refreshOnStartup
 * Returns whether or not Vienna refreshes all subscriptions when it starts.
 */
-(BOOL)refreshOnStartup
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:MAPref_CheckForNewMessagesOnStartup];
}

/* setRefreshOnStartup
 * Changes whether or not Vienna refreshes all subscriptions when it starts.
 */
-(void)setRefreshOnStartup:(BOOL)flag
{
	[self internalChangeRefreshOnStartup:flag];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalChangeRefreshOnStartup
 * Changes whether or not Vienna refreshes all subscriptions when it starts.
 */
-(void)internalChangeRefreshOnStartup:(BOOL)flag
{
	NSNumber * boolFlag = [NSNumber numberWithBool:flag];
	[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_CheckForNewMessagesOnStartup];
}

/* currentFolder
 * Retrieves the current folder
 */
-(Folder *)currentFolder
{
	return [[Database sharedDatabase] folderFromID:[[self delegate] currentFolderId]];
}

/* setCurrentFolder
 * Sets the current folder
 */
-(void)setCurrentFolder:(Folder *)newCurrentFolder
{
	int folderId = [newCurrentFolder itemId];
	[[self delegate] selectFolderAndMessage:folderId guid:nil];
}

/* readingPaneOnRight
 * Returns whether the reading pane is on the right or at the bottom of the article list.
 */
-(BOOL)readingPaneOnRight
{
	[self initialisePreferences];
	return readingPaneOnRight;
}

/* setReadingPaneOnRight
 * Changes where the reading pane appears relative to the article list then updates the UI.
 */
-(void)setReadingPaneOnRight:(BOOL)flag
{
	[[self delegate] setReadingPaneOnRight:flag];
}

/* internalSetReadingPaneOnRight
 * Changes where the reading pane appears relative to the article list.
 */
-(void)internalSetReadingPaneOnRight:(BOOL)flag
{
	[self initialisePreferences];
	if (flag != readingPaneOnRight)
	{
		readingPaneOnRight = flag;
		NSNumber * boolFlag = [NSNumber numberWithBool:flag];
		[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_ReadingPaneOnRight];
	}
}

/* refreshFrequency
 * Return the frequency with which we refresh all subscriptions
 */
-(int)refreshFrequency
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:MAPref_CheckFrequency];
}

/* setRefreshFrequency
 * Updates the refresh frequency and then updates the preferences.
 */
-(void)setRefreshFrequency:(int)newFrequency
{
	[self internalSetRefreshFrequency:newFrequency];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalSetRefreshFrequency
 * Updates the refresh frequency.
 */
-(void)internalSetRefreshFrequency:(int)newFrequency
{
	[[NSUserDefaults standardUserDefaults] setInteger:newFrequency forKey:MAPref_CheckFrequency];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_CheckFrequencyChange" object:nil];
}

/* enableMinimumFontSize
 * Specifies whether or not the minimum font size is in force.
 */
-(BOOL)enableMinimumFontSize
{
	return enableMinimumFontSize;
}

/* minimumFontSize
 * Return the current minimum font size.
 */
-(int)minimumFontSize
{
	return minimumFontSize;
}

/* setMinimumFontSize
 * Change the minimum font size.
 */
-(void)setMinimumFontSize:(int)newSize
{
	if (newSize != minimumFontSize)
	{
		[self internalSetMinimumFontSize:newSize];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
	}
}

/* internalSetMinimumFontSize
 * Internally change the minimum font size.
 */
-(void)internalSetMinimumFontSize:(int)newSize
{
	minimumFontSize = newSize;
	[[NSUserDefaults standardUserDefaults] setInteger:minimumFontSize forKey:MAPref_MinimumFontSize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_MinimumFontSizeChange" object:nil];
}

/* changeMinimumFontSize
 * Enable whether the minimum font size is used.
 */
-(void)changeMinimumFontSize:(BOOL)flag
{
	[self internalChangeMinimumFontSize:flag];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}


/* internalChangeMinimumFontSize
 * Internally enable whether the minimum font size is used.
 */
-(void)internalChangeMinimumFontSize:(BOOL)flag
{
	enableMinimumFontSize = flag;
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:MAPref_UseMinimumFontSize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_MinimumFontSizeChange" object:nil];
}
@end
