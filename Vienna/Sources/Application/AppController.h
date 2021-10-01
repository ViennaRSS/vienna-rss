//
//  AppController.h
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
//  Copyright (c) 2004-2017 Steve Palmer and Vienna contributors. All rights reserved.
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

@import Cocoa;
@import IOKit.pwr_mgt;
@import WebKit;

#define APPCONTROLLER ((AppController *)[NSApp delegate])
#define APP ((ViennaApp *)NSApp)

@class FoldersTree;
@class SmartFolder;
@class NewSubscription;
@class NewGroupFolder;
@class WebPreferences;
@class Browser;
@class EmptyTrashWarning;
@class SearchPanel;
@class DisclosureView;
@class PluginManager;
@class SearchMethod;
@class Database;
@class ArticleController;
@class DownloadWindow;
@class Article;
@class UnifiedDisplayView;
@class ArticleListView;

@interface AppController : NSObject <NSApplicationDelegate>
{
	IBOutlet NSMenuItem * closeTabItem;
	IBOutlet NSMenuItem * closeAllTabsItem;
	IBOutlet NSMenuItem * closeWindowItem;
	IBOutlet NSMenuItem * sortByMenu;
	IBOutlet NSMenuItem * columnsMenu;

	DownloadWindow * downloadWindow;
	SmartFolder * smartFolder;
	NewGroupFolder * groupFolder;
	EmptyTrashWarning * emptyTrashWarning;
	SearchPanel * searchPanel;
	
	Database * db;
	NSMutableDictionary * scriptPathMappings;
	NSStatusItem * appStatusItem;
	NSDictionary * standardURLs;
	NSTimer * checkTimer;
	NSInteger lastCountOfUnread;
	NSMenuItem * scriptsMenuItem;
	BOOL didCompleteInitialisation;
	NSString * searchString;
    
    NewSubscription * _rssFeed;
}

@property (nonatomic) PluginManager *pluginManager;
@property (nonatomic, weak) Browser *browser;
@property (nonatomic) ArticleController *articleController;
@property (nonatomic, weak) UnifiedDisplayView *unifiedListView;
@property (nonatomic, weak) ArticleListView *articleListView;
@property (nonatomic, strong) NewSubscription *rssFeed;
@property (nonatomic) FoldersTree *foldersTree;
@property (readonly, copy, nonatomic) NSMenu *searchFieldMenu;

// Menu action items
-(IBAction)reindexDatabase:(id)sender;
-(IBAction)deleteMessage:(id)sender;
-(IBAction)deleteFolder:(id)sender;
-(IBAction)searchUsingToolbarTextField:(id)sender;
-(IBAction)searchUsingFilterField:(id)sender;
-(IBAction)markAllRead:(id)sender;
-(IBAction)markAllSubscriptionsRead:(id)sender;
-(IBAction)markUnread:(id)sender;
-(IBAction)markRead:(id)sender;
-(IBAction)markFlagged:(id)sender;
-(IBAction)renameFolder:(id)sender;
-(IBAction)viewFirstUnread:(id)sender;
-(IBAction)viewArticlesTab:(id)sender;
-(IBAction)viewNextUnread:(id)sender;
-(IBAction)printDocument:(id)sender;
-(IBAction)goBack:(id)sender;
-(IBAction)goForward:(id)sender;
-(IBAction)newSmartFolder:(id)sender;
-(IBAction)newSubscription:(id)sender;
-(IBAction)newGroupFolder:(id)sender;
-(IBAction)editFolder:(id)sender;
-(IBAction)showViennaHomePage:(id)sender;
-(IBAction)viewArticlePages:(id)sender;
-(IBAction)viewArticlePagesInAlternateBrowser:(id)sender;
-(IBAction)openWebElementInNewTab:(id)sender;
-(IBAction)openWebElementInDefaultBrowser:(id)sender;
-(IBAction)doSelectScript:(id)sender;
-(IBAction)doSelectStyle:(id)sender;
-(IBAction)doOpenScriptsFolder:(id)sender;
-(IBAction)viewSourceHomePage:(id)sender;
-(IBAction)viewSourceHomePageInAlternateBrowser:(id)sender;
-(IBAction)emptyTrash:(id)sender;
-(IBAction)refreshAllFolderIcons:(id)sender;
-(IBAction)refreshSelectedSubscriptions:(id)sender;
-(IBAction)forceRefreshSelectedSubscriptions:(id)sender;
-(IBAction)updateRemoteSubscriptions:(id)sender;
-(IBAction)refreshAllSubscriptions:(id)sender;
-(IBAction)cancelAllRefreshes:(id)sender;
-(IBAction)moreStyles:(id)sender;
-(IBAction)showMainWindow:(id)sender;
-(IBAction)previousTab:(id)sender;
-(IBAction)nextTab:(id)sender;
-(IBAction)closeTab:(id)sender;
-(IBAction)closeAllTabs:(id)sender;
-(IBAction)reloadPage:(id)sender;
-(IBAction)stopReloadingPage:(id)sender;
-(IBAction)restoreMessage:(id)sender;
-(IBAction)skipFolder:(id)sender;
-(IBAction)showDownloadsWindow:(id)sender;
-(IBAction)conditionalShowDownloadsWindow:(id)sender;
-(IBAction)mailLinkToArticlePage:(id)sender;
-(IBAction)openWebLocation:(id)sender;
-(IBAction)getInfo:(id)sender;
-(IBAction)unsubscribeFeed:(id)sender;
-(IBAction)useCurrentStyleForArticles:(id)sender;
-(IBAction)useWebPageForArticles:(id)sender;
-(IBAction)keyboardShortcutsHelp:(id)sender;
-(IBAction)unifiedLayout:(id)sender;
-(IBAction)reportLayout:(id)sender;
-(IBAction)condensedLayout:(id)sender;
-(IBAction)makeTextLarger:(id)sender;
-(IBAction)makeTextSmaller:(id)sender;
-(IBAction)downloadEnclosure:(id)sender;
-(IBAction)showHideFilterBar:(id)sender;
-(IBAction)hideFilterBar:(id)sender;
-(IBAction)setFocusToSearchField:(id)sender;
-(IBAction)localPerformFindPanelAction:(id)sender;
-(IBAction)keepFoldersArranged:(id)sender;
-(IBAction)exportSubscriptions:(id)sender;
-(IBAction)importSubscriptions:(id)sender;


// Public functions
-(NSArray *)contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;
-(void)showUnreadCountOnApplicationIconAndWindowTitle;
-(void)openURLFromString:(NSString *)urlString inPreferredBrowser:(BOOL)openInPreferredBrowserFlag;
-(void)openURL:(NSURL *)url inPreferredBrowser:(BOOL)openInPreferredBrowserFlag;
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger)flags;
-(void)openURLInDefaultBrowser:(NSURL *)url;
-(void)handleRSSLink:(NSString *)linkPath;
-(void)selectFolder:(NSInteger)folderId;
-(void)createNewSubscription:(NSString *)urlString underFolder:(NSInteger)parentId afterChild:(NSInteger)predecessorId;
-(void)markSelectedFoldersRead:(NSArray *)arrayOfFolders;
-(void)doSafeInitialisation;
-(void)clearUndoStack;
@property (nonatomic, copy) NSString *filterString;
@property (nonatomic, copy) NSString *searchString;
@property (nonatomic, readonly, strong) Article *selectedArticle;
@property (nonatomic, readonly) NSInteger currentFolderId;
@property (nonatomic, getter=isConnecting, readonly) BOOL connecting;
-(void)runAppleScript:(NSString *)scriptName;
-(NSDictionary *)standardURLs;
@property (nonatomic, readonly, copy) NSArray *folders;
-(void)blogWithExternalEditor:(NSString *)externalEditorBundleIdentifier;
-(void)updateStatusBarFilterButtonVisibility;
@property (nonatomic, readonly, strong) NSLayoutManager *layoutManager;
-(void)performWebSearch:(SearchMethod *)searchMethod;
-(void)performAllArticlesSearch;
-(void)performWebPageSearch;
-(void)searchArticlesWithString:(NSString *)searchString;

@end
