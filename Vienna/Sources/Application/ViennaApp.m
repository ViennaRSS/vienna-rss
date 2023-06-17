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
#import "RefreshManager.h"
#import "Constants.h"
#import "Folder.h"
#import "Article.h"
#import "Database.h"
#import "StringExtensions.h"
#import "FeedListConstants.h"
#import "Vienna-Swift.h"

@interface ViennaApp ()

@property (nonatomic) VNAFeedListSizeMode feedListSizeMode;
@property (readonly, nonatomic) BOOL readingPaneOnRight;

// MARK: Obsolete

@property (nonatomic) NSString *folderListFont;
@property (nonatomic) NSInteger folderListFontSize;

@end

@implementation ViennaApp

/* handleRefreshAllSubscriptions
 * Refreshes all folders.
 */
-(id)handleRefreshAllSubscriptions:(NSScriptCommand *)cmd
{
	[(AppController*)self.delegate refreshAllSubscriptions:nil];
	return nil;
}

/* evaluatedArrayOfFolders
 * Given a script argument object, this code attempts to determine
 * an array of folders from that argument. If any argument is NOT a folder
 * type, we return nil and report an error back to the script command.
 */
-(NSArray *)evaluatedArrayOfFolders:(id)argObject withCommand:(NSScriptCommand *)cmd
{
	NSMutableArray * newArgArray = [NSMutableArray array];
	BOOL hasError = NO;

	if ([argObject isKindOfClass:[Folder class]]) {
		[newArgArray addObject:argObject];
	} else if ([argObject isKindOfClass:[NSArray class]]) {
		NSArray * argArray = (NSArray *)argObject;
		NSInteger index;

		for (index = 0; index < argArray.count; ++index) {
			id argItem = argArray[index];
			if ([argItem isKindOfClass:[Folder class]]) {
				[newArgArray addObject:argItem];
				continue;
			}
			if ([argItem isKindOfClass:[NSScriptObjectSpecifier class]]) {
				id evaluatedItem = [argItem objectsByEvaluatingSpecifier];
				if ([evaluatedItem isKindOfClass:[Folder class]]) {
					[newArgArray addObject:evaluatedItem];
					continue;
				}
				if ([evaluatedItem isKindOfClass:[NSArray class]]) {
					NSArray * newArray = [self evaluatedArrayOfFolders:evaluatedItem withCommand:cmd];
					if (newArray == nil) {
						return nil;
					}

					[newArgArray addObjectsFromArray:newArray];
					continue;
				}
			}
			hasError = YES;
			break;
		}
	}
	if (!hasError) {
		return [newArgArray copy];
	}

	// At least one of the arguments didn't evaluate to a Folder object
	cmd.scriptErrorNumber = errASIllegalFormalParameter;
	cmd.scriptErrorString = @"Argument must evaluate to a valid folder";
	return nil;
}

/* handleRefreshSubscription
 * Refreshes a specific folder.
 */
-(id)handleRefreshSubscription:(NSScriptCommand *)cmd
{
	NSDictionary * args = cmd.evaluatedArguments;
	NSArray * argArray = [self evaluatedArrayOfFolders:args[@"Folder"] withCommand:cmd];
	if (argArray != nil) {
		[[RefreshManager sharedManager] refreshSubscriptions:argArray ignoringSubscriptionStatus:YES];
	}

	return nil;
}

/* handleMarkAllRead
 * Mark all articles in the specified folder as read
 */
-(id)handleMarkAllRead:(NSScriptCommand *)cmd
{
	NSDictionary * args = cmd.evaluatedArguments;
	NSArray * argArray = [self evaluatedArrayOfFolders:args[@"Folder"] withCommand:cmd];
	if (argArray != nil) {
		[(AppController*)self.delegate markSelectedFoldersRead:argArray];
	}

	return nil;
}

/* handleMarkAllSubscriptionsRead
 * Mark all articles read in all subscriptions
 */
-(id)handleMarkAllSubscriptionsRead:(NSScriptCommand *)cmd
{
	[(AppController*)self.delegate markAllSubscriptionsRead:nil];
	
	return nil;
}

/* handleCompactDatabase
 * Compact the database.
 */
-(id)handleCompactDatabase:(NSScriptCommand *)cmd
{
	[[Database sharedManager] compactDatabase];
	return nil;
}

/* handleEmptyTrash
 * Empty the trash.
 */
-(id)handleEmptyTrash:(NSScriptCommand *)cmd
{
	[(AppController*)self.delegate clearUndoStack];
	[[Database sharedManager] purgeDeletedArticles];
	return nil;
}

/* handleImportSubscriptions
 * Import subscriptions from a file.
 */
-(id)handleImportSubscriptions:(NSScriptCommand *)cmd
{
	NSDictionary * args = cmd.evaluatedArguments;
	[Import importFromFile:args[@"FileName"]];
	return nil;
}

/* handleExportSubscriptions
 * Export all or specified folders to a file.
 */
-(id)handleExportSubscriptions:(NSScriptCommand *)cmd
{
	NSDictionary * args = cmd.evaluatedArguments;
	id argObject = args[@"Folder"];
	NSArray * argArray = argObject ? [self evaluatedArrayOfFolders:argObject withCommand:cmd] : [[Database sharedManager] arrayOfFolders:VNAFolderTypeRoot];

	NSInteger countExported = 0;
	if (argArray != nil) {
		countExported = [Export exportToFile:args[@"FileName"] from:argArray inFoldersTree:((AppController*)self.delegate).foldersTree withGroups:YES];
	}
	return @(countExported);
}

/* handleNewSubscription
 * Create a new subscription in the specified folder. If the specified folder is not
 * a group folder, the parent of the specified folder is used.
 */
-(id)handleNewSubscription:(NSScriptCommand *)cmd
{
	NSDictionary * args = cmd.evaluatedArguments;
	Folder * folder = args[@"UnderFolder"];

	NSInteger parentId = folder ? ((folder.type == VNAFolderTypeGroup) ? folder.itemId : folder.parentId) : VNAFolderTypeRoot;

	[(AppController*)self.delegate createNewSubscription:args[@"URL"] underFolder:parentId afterChild:-1];
	return nil;
}

/* resetFolderSort
 * Reset the folder sort order.
 */
-(id)resetFolderSort:(NSScriptCommand *)cmd
{
	Preferences * prefs = [Preferences standardPreferences];
	[prefs setFoldersTreeSortMethod:VNAFolderSortByName];
	[prefs setFoldersTreeSortMethod:VNAFolderSortManual];
	return nil;
}

- (NSString *)applicationVersion
{
    NSDictionary *infoDictionary = NSBundle.mainBundle.infoDictionary;
    NSString *versionString = infoDictionary[@"CFBundleShortVersionString"];
    NSString *trimmedVersionString = versionString.vna_trimmed;
    NSUInteger wordLength = [trimmedVersionString vna_indexOfCharacterInString:' '
                                                                    afterIndex:0];
    if (wordLength == NSNotFound) {
        return trimmedVersionString;
    } else {
        return [trimmedVersionString substringToIndex:wordLength];
    }
}

/* folders
 * Return a flat array of all folders
 */
-(NSArray *)folders
{
	return ((AppController*)self.delegate).folders;
}

/* isRefreshing
 * Return whether or not Vienna is in the process of connecting.
 */
-(BOOL)isRefreshing
{
	return ((AppController*)self.delegate).connecting;
}

/* totalUnreadCount
 * Return the total number of unread articles.
 */
-(NSInteger)totalUnreadCount
{
	return [Database sharedManager].countOfUnread;
}

/* currentSelection
 * Returns the current selected text from the article view or an empty
 * string if there is no selection.
 */
-(NSString *)currentTextSelection
{
    id<Tab> activeBrowserTab = ((AppController*)self.delegate).browser.activeTab;

    if (activeBrowserTab) {
        return activeBrowserTab.textSelection;
    }
    return @"";
}

-(NSString *)documentHTMLSource
{
	id<Tab> activeBrowserTab = ((AppController*)self.delegate).browser.activeTab;

	if (activeBrowserTab != nil) {
        return activeBrowserTab.html;
	}
	return @"";
}

-(NSString *)documentTabURL
{
    id<Tab> activeBrowserTab = ((AppController*)self.delegate).browser.activeTab;
	if (activeBrowserTab) {
		return activeBrowserTab.tabUrl.absoluteString;
	} else {
		return @"";
    }
}

/* currentArticle
 * Retrieves the current article.
 */
-(Article *)currentArticle
{
	return ((AppController*)self.delegate).selectedArticle;
}

/* currentFolder
 * Retrieves the current folder
 */
-(Folder *)currentFolder
{
	return [[Database sharedManager] folderFromID:((AppController*)self.delegate).currentFolderId];
}

/* setCurrentFolder
 * Sets the current folder
 */
-(void)setCurrentFolder:(Folder *)newCurrentFolder
{
	AppController * controller = APPCONTROLLER;
	NSInteger folderId = newCurrentFolder.itemId;
	[controller selectFolder:folderId];
}

/* Accessor getters
 * These thunk through the standard preferences.
 */
-(NSInteger)autoExpireDuration			{ return [Preferences standardPreferences].autoExpireDuration; }
-(float)markReadInterval			{ return [Preferences standardPreferences].markReadInterval; }
-(BOOL)readingPaneOnRight			{ return [Preferences standardPreferences].layout == VNALayoutCondensed; }
-(NSInteger)filterMode					{ return [Preferences standardPreferences].filterMode; }
-(BOOL)refreshOnStartup				{ return [Preferences standardPreferences].refreshOnStartup; }
-(BOOL)checkForNewOnStartup			{ return APPCONTROLLER.sparkleController.updater.automaticallyChecksForUpdates; }
-(BOOL)openLinksInVienna			{ return [Preferences standardPreferences].openLinksInVienna; }
-(BOOL)openLinksInBackground		{ return [Preferences standardPreferences].openLinksInBackground; }
-(NSInteger)minimumFontSize				{ return [Preferences standardPreferences].minimumFontSize; }
-(BOOL)enableMinimumFontSize		{ return [Preferences standardPreferences].enableMinimumFontSize; }
-(NSInteger)refreshFrequency				{ return [Preferences standardPreferences].refreshFrequency; }
-(NSString *)displayStyle			{ return [Preferences standardPreferences].displayStyle; }
-(NSString *)articleListFont		{ return [Preferences standardPreferences].articleListFont; }
-(NSInteger)articleListFontSize			{ return [Preferences standardPreferences].articleListFontSize; }
-(BOOL)statusBarVisible				{ return [Preferences standardPreferences].showStatusBar; }
-(BOOL)filterBarVisible				{ return [Preferences standardPreferences].showFilterBar; }

/* Accessor setters
 * These thunk through the standard preferences.
 */
-(void)setAutoExpireDuration:(NSInteger)newDuration		{ [Preferences standardPreferences].autoExpireDuration = newDuration; }
-(void)setMarkReadInterval:(float)newInterval		{ [Preferences standardPreferences].markReadInterval = newInterval; }
-(void)setRefreshOnStartup:(BOOL)flag				{ [Preferences standardPreferences].refreshOnStartup = flag; }
-(void)setFilterMode:(NSInteger)newMode					{ [Preferences standardPreferences].filterMode = newMode; }
-(void)setCheckForNewOnStartup:(BOOL)flag			{ APPCONTROLLER.sparkleController.updater.automaticallyChecksForUpdates = flag; }
-(void)setOpenLinksInVienna:(BOOL)flag				{ [Preferences standardPreferences].openLinksInVienna = flag; }
-(void)setOpenLinksInBackground:(BOOL)flag			{ [Preferences standardPreferences].openLinksInBackground = flag; }
-(void)setMinimumFontSize:(NSInteger)newSize				{ [Preferences standardPreferences].minimumFontSize = newSize; }
-(void)setEnableMinimumFontSize:(BOOL)flag			{ [Preferences standardPreferences].enableMinimumFontSize = flag; }
-(void)setRefreshFrequency:(NSInteger)newFrequency		{ [Preferences standardPreferences].refreshFrequency = newFrequency; }
-(void)setDisplayStyle:(NSString *)newStyle			{ [Preferences standardPreferences].displayStyle = [newStyle copy]; }
-(void)setArticleListFont:(NSString *)newFontName	{ [Preferences standardPreferences].articleListFont = [newFontName copy]; }
-(void)setArticleListFontSize:(NSInteger)newFontSize		{ [Preferences standardPreferences].articleListFontSize = newFontSize; }
-(void)setStatusBarVisible:(BOOL)flag				{ [Preferences standardPreferences].showStatusBar = flag; }
-(void)setFilterBarVisible:(BOOL)flag				{ [Preferences standardPreferences].showFilterBar = flag; }


- (VNAFeedListSizeMode)feedListSizeMode
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSInteger sizeMode = [defaults integerForKey:MAPref_FeedListSizeMode];
    switch (sizeMode) {
    case VNAFeedListSizeModeTiny:
    case VNAFeedListSizeModeSmall:
    case VNAFeedListSizeModeMedium:
        return sizeMode;
    default:
        return VNAFeedListSizeModeDefault;
    }
}

- (void)setFeedListSizeMode:(VNAFeedListSizeMode)feedListSizeMode
{
    switch (feedListSizeMode) {
    case VNAFeedListSizeModeTiny:
    case VNAFeedListSizeModeSmall:
    case VNAFeedListSizeModeMedium:
        break;
    default:
        return;
    }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setInteger:feedListSizeMode forKey:MAPref_FeedListSizeMode];
}

// MARK: Obsolete accessors
// The following accessors are defined for compatibility with scripting.

- (NSString *)folderListFont
{
    return @"";
}

- (void)setFolderListFont:(__unused NSString *)folderListFont
{
    // Not implemented
}

- (NSInteger)folderListFontSize
{
    return -1;
}

- (void)setFolderListFontSize:(__unused NSInteger)folderListFontSize
{
    // Not implemented
}

@end
