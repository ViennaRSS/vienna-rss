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
#import "Preferences.h"
#import "Import.h"
#import "Export.h"
#import "Refresh.h"
#import "Constants.h"
#import "FoldersTree.h"

@implementation ViennaApp

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

/* Accessor getters
 * These thunk through the standard preferences.
 */
-(float)markReadInterval			{ return [[Preferences standardPreferences] markReadInterval]; }
-(BOOL)readingPaneOnRight			{ return [[Preferences standardPreferences] readingPaneOnRight]; }
-(BOOL)refreshOnStartup				{ return [[Preferences standardPreferences] refreshOnStartup]; }
-(BOOL)checkForNewOnStartup			{ return [[Preferences standardPreferences] checkForNewOnStartup]; }
-(BOOL)openLinksInVienna			{ return [[Preferences standardPreferences] openLinksInVienna]; }
-(BOOL)openLinksInBackground		{ return [[Preferences standardPreferences] openLinksInBackground]; }
-(int)minimumFontSize				{ return [[Preferences standardPreferences] minimumFontSize]; }
-(BOOL)enableMinimumFontSize		{ return [[Preferences standardPreferences] enableMinimumFontSize]; }
-(int)refreshFrequency				{ return [[Preferences standardPreferences] refreshFrequency]; }
-(NSString *)displayStyle			{ return [[Preferences standardPreferences] displayStyle]; }
-(NSString *)folderListFont			{ return [[Preferences standardPreferences] folderListFont]; }
-(int)folderListFontSize			{ return [[Preferences standardPreferences] folderListFontSize]; }
-(NSString *)articleListFont		{ return [[Preferences standardPreferences] articleListFont]; }
-(int)articleListFontSize			{ return [[Preferences standardPreferences] articleListFontSize]; }

/* Accessor setters
 * These thunk through the standard preferences.
 */
-(void)setMarkReadInterval:(float)newInterval		{ [[Preferences standardPreferences] setMarkReadInterval:newInterval]; }
-(void)setReadingPaneOnRight:(BOOL)flag				{ [[Preferences standardPreferences] setReadingPaneOnRight:flag]; }
-(void)setRefreshOnStartup:(BOOL)flag				{ [[Preferences standardPreferences] setRefreshOnStartup:flag]; }
-(void)setCheckForNewOnStartup:(BOOL)flag			{ [[Preferences standardPreferences] setCheckForNewOnStartup:flag]; }
-(void)setOpenLinksInVienna:(float)flag				{ [[Preferences standardPreferences] setOpenLinksInVienna:flag]; }
-(void)setOpenLinksInBackground:(float)flag			{ [[Preferences standardPreferences] setOpenLinksInBackground:flag]; }
-(void)setMinimumFontSize:(int)newSize				{ [[Preferences standardPreferences] setMinimumFontSize:newSize]; }
-(void)setEnableMinimumFontSize:(BOOL)flag			{ [[Preferences standardPreferences] setEnableMinimumFontSize:flag]; }
-(void)setRefreshFrequency:(int)newFrequency		{ [[Preferences standardPreferences] setRefreshFrequency:newFrequency]; }
-(void)setDisplayStyle:(NSString *)newStyle			{ [[Preferences standardPreferences] setDisplayStyle:newStyle]; }
-(void)setFolderListFont:(NSString *)newFontName	{ [[Preferences standardPreferences] setFolderListFont:newFontName]; }
-(void)setFolderListFontSize:(int)newFontSize		{ [[Preferences standardPreferences] setFolderListFontSize:newFontSize]; }
-(void)setArticleListFont:(NSString *)newFontName	{ [[Preferences standardPreferences] setArticleListFont:newFontName]; }
-(void)setArticleListFontSize:(int)newFontSize		{ [[Preferences standardPreferences] setArticleListFontSize:newFontSize]; }
@end
