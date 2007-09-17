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
#import "ArticleListView.h"
#import "Preferences.h"
#import "Import.h"
#import "Export.h"
#import "RefreshManager.h"
#import "Constants.h"
#import "FoldersTree.h"
#import "BrowserPane.h"
#import "UnifiedDisplayView.h"
#import "WebKit/WebKit.h"

// This is needed for iTunes-like buttons with different option-key personalities.
OSStatus keyPressed(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) 
{
	return CallNextEventHandler(nextHandler, theEvent);
}

@implementation ViennaApp

/* sendEvent
 * We override sendEvent in order to catch the status of the option key. 
 */
-(void)sendEvent:(NSEvent *)anEvent 
{
	BOOL isHandled = NO;

	if(([anEvent type] == NSFlagsChanged) && ( ([anEvent keyCode] == 61) || ([anEvent keyCode] == 58)))
	{
		AppController * controller = (AppController *)[NSApp delegate];
		[controller toggleOptionKeyButtonStates]; 
		isHandled = YES;
	}
	// Only handle the events we actually need.
    if(!isHandled)
		[super sendEvent:anEvent];
}

/* handleRefreshAllSubscriptions
 * Refreshes all folders.
 */
-(id)handleRefreshAllSubscriptions:(NSScriptCommand *)cmd
{
	[[self delegate] refreshAllSubscriptions:nil];
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

	if ([argObject isKindOfClass:[Folder class]])
		[newArgArray addObject:argObject];

	else if ([argObject isKindOfClass:[NSArray class]])
	{
		NSArray * argArray = (NSArray *)argObject;
		int index;

		for (index = 0; index < [argArray count]; ++index)
		{
			id argItem = [argArray objectAtIndex:index];
			if ([argItem isKindOfClass:[Folder class]])
			{
				[newArgArray addObject:argItem];
				continue;
			}
			if ([argItem isKindOfClass:[NSScriptObjectSpecifier class]])
			{
				id evaluatedItem = [argItem objectsByEvaluatingSpecifier];
				if ([evaluatedItem isKindOfClass:[Folder class]])
				{
					[newArgArray addObject:evaluatedItem];
					continue;
				}
				if ([evaluatedItem isKindOfClass:[NSArray class]])
				{
					NSArray * newArray = [self evaluatedArrayOfFolders:evaluatedItem withCommand:cmd];
					if (newArray == nil)
						return nil;

					[newArgArray addObjectsFromArray:newArray];
					continue;
				}
			}
			hasError = YES;
			break;
		}
	}
	if (!hasError)
		return newArgArray;

	// At least one of the arguments didn't evaluate to a Folder object
	[cmd setScriptErrorNumber:errASIllegalFormalParameter];
	[cmd setScriptErrorString:@"Argument must evaluate to a valid folder"];
	return nil;
}

/* handleRefreshSubscription
 * Refreshes a specific folder.
 */
-(id)handleRefreshSubscription:(NSScriptCommand *)cmd
{
	NSDictionary * args = [cmd evaluatedArguments];
	NSArray * argArray = [self evaluatedArrayOfFolders:[args objectForKey:@"Folder"] withCommand:cmd];
	if (argArray != nil)
		[[RefreshManager sharedManager] refreshSubscriptions:argArray ignoringSubscriptionStatus:YES];

	return nil;
}

/* handleMarkAllRead
 * Mark all articles in the specified folder as read
 */
-(id)handleMarkAllRead:(NSScriptCommand *)cmd
{
	NSDictionary * args = [cmd evaluatedArguments];
	NSArray * argArray = [self evaluatedArrayOfFolders:[args objectForKey:@"Folder"] withCommand:cmd];
	if (argArray != nil)
		[[self delegate] markSelectedFoldersRead:argArray];

	return nil;
}

/* handleMarkAllSubscriptionsRead
 * Mark all articles read in all subscriptions
 */
-(id)handleMarkAllSubscriptionsRead:(NSScriptCommand *)cmd
{
	[[self delegate] markAllSubscriptionsRead:nil];
	
	return nil;
}

/* handleCompactDatabase
 * Compact the database.
 */
-(id)handleCompactDatabase:(NSScriptCommand *)cmd
{
	[[Database sharedDatabase] compactDatabase];
	return nil;
}

/* handleEmptyTrash
 * Empty the trash.
 */
-(id)handleEmptyTrash:(NSScriptCommand *)cmd
{
	[[self delegate] clearUndoStack];
	[[Database sharedDatabase] purgeDeletedArticles];
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
	id argObject = [args objectForKey:@"Folder"];
	NSArray * argArray = argObject ? [self evaluatedArrayOfFolders:argObject withCommand:cmd] : [[Database sharedDatabase] arrayOfFolders:MA_Root_Folder];

	int countExported = 0;
	if (argArray != nil)
		countExported = [[self delegate] exportToFile:[args objectForKey:@"FileName"] from:argArray withGroups:YES];
	return [NSNumber numberWithInt:countExported];
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

	[[self delegate] createNewSubscription:[args objectForKey:@"URL"] underFolder:parentId afterChild:-1];
	return nil;
}

/* resetFolderSort
 * Reset the folder sort order.
 */
-(id)resetFolderSort:(NSScriptCommand *)cmd
{
	Preferences * prefs = [Preferences standardPreferences];
	[prefs setFoldersTreeSortMethod:MA_FolderSort_ByName];
	[prefs setFoldersTreeSortMethod:MA_FolderSort_Manual];
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

/* totalUnreadCount
 * Return the total number of unread articles.
 */
-(int)totalUnreadCount
{
	return [[Database sharedDatabase] countOfUnread];
}

/* currentSelection
 * Returns the current selected text from the article view or an empty
 * string if there is no selection.
 */
-(NSString *)currentSelection
{
	NSView<BaseView> * theView = [[[self delegate] browserView] activeTabItemView];
	WebView * webPane = nil;

	if ([theView isKindOfClass:[BrowserPane class]])
		webPane = (WebView *)[(BrowserPane *)theView mainView];

	if ([theView isKindOfClass:[ArticleListView class]])
		webPane = (WebView *)[(ArticleListView *)theView webView];
	
	if ([theView isKindOfClass:[UnifiedDisplayView class]])
		webPane = (WebView *)[(UnifiedDisplayView *)theView webView];
	
	if (webPane != nil)
	{
		NSView * docView = [[[webPane mainFrame] frameView] documentView];
		
		if ([docView conformsToProtocol:@protocol(WebDocumentText)])
			return [(id<WebDocumentText>)docView selectedString];
	}
	return @"";
}

-(NSString *)documentHTMLSource
{
	NSView<BaseView> * theView = [[[self delegate] browserView] activeTabItemView];
	WebView * webPane = [theView webView];
	
	if (webPane != nil)
	{
		WebDataSource * dataSource = [[webPane mainFrame] dataSource];
		if (dataSource != nil)
		{
			id representation = [dataSource representation];
			if ((representation != nil) && ([representation conformsToProtocol:@protocol(WebDocumentRepresentation)]) && ([(id<WebDocumentRepresentation>)representation canProvideDocumentSource]))
				return [(id<WebDocumentRepresentation>)representation documentSource];
		}
	}
	return @"";
}

/* currentArticle
 * Retrieves the current article.
 */
-(Article *)currentArticle;
{
	return [[self delegate] selectedArticle];
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
	AppController * controller = (AppController *)[NSApp delegate];
	int folderId = [newCurrentFolder itemId];
	[controller selectFolder:folderId];
}

/* Accessor getters
 * These thunk through the standard preferences.
 */
-(int)autoExpireDuration			{ return [[Preferences standardPreferences] autoExpireDuration]; }
-(float)markReadInterval			{ return [[Preferences standardPreferences] markReadInterval]; }
-(BOOL)readingPaneOnRight			{ return [[Preferences standardPreferences] layout] == MA_Layout_Condensed; }
-(int)filterMode					{ return [[Preferences standardPreferences] filterMode]; }
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
-(BOOL)statusBarVisible				{ return [[Preferences standardPreferences] showStatusBar]; }
-(BOOL)filterBarVisible				{ return [[Preferences standardPreferences] showFilterBar]; }

/* Accessor setters
 * These thunk through the standard preferences.
 */
-(void)setAutoExpireDuration:(int)newDuration		{ [[Preferences standardPreferences] setAutoExpireDuration:newDuration]; }
-(void)setMarkReadInterval:(float)newInterval		{ [[Preferences standardPreferences] setMarkReadInterval:newInterval]; }
-(void)setReadingPaneOnRight:(BOOL)flag				{ ; }
-(void)setRefreshOnStartup:(BOOL)flag				{ [[Preferences standardPreferences] setRefreshOnStartup:flag]; }
-(void)setFilterMode:(int)newMode					{ [[Preferences standardPreferences] setFilterMode:newMode]; }
-(void)setCheckForNewOnStartup:(BOOL)flag			{ [[Preferences standardPreferences] setCheckForNewOnStartup:flag]; }
-(void)setOpenLinksInVienna:(BOOL)flag				{ [[Preferences standardPreferences] setOpenLinksInVienna:flag]; }
-(void)setOpenLinksInBackground:(BOOL)flag			{ [[Preferences standardPreferences] setOpenLinksInBackground:flag]; }
-(void)setMinimumFontSize:(int)newSize				{ [[Preferences standardPreferences] setMinimumFontSize:newSize]; }
-(void)setEnableMinimumFontSize:(BOOL)flag			{ [[Preferences standardPreferences] setEnableMinimumFontSize:flag]; }
-(void)setRefreshFrequency:(int)newFrequency		{ [[Preferences standardPreferences] setRefreshFrequency:newFrequency]; }
-(void)setDisplayStyle:(NSString *)newStyle			{ [[Preferences standardPreferences] setDisplayStyle:newStyle]; }
-(void)setFolderListFont:(NSString *)newFontName	{ [[Preferences standardPreferences] setFolderListFont:newFontName]; }
-(void)setFolderListFontSize:(int)newFontSize		{ [[Preferences standardPreferences] setFolderListFontSize:newFontSize]; }
-(void)setArticleListFont:(NSString *)newFontName	{ [[Preferences standardPreferences] setArticleListFont:newFontName]; }
-(void)setArticleListFontSize:(int)newFontSize		{ [[Preferences standardPreferences] setArticleListFontSize:newFontSize]; }
-(void)setStatusBarVisible:(BOOL)flag				{ [[Preferences standardPreferences] setShowStatusBar:flag]; }
-(void)setFilterBarVisible:(BOOL)flag				{ [[Preferences standardPreferences] setShowFilterBar:flag]; }
@end
