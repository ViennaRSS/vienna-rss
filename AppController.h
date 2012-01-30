//
//  AppController.h
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

#import <Cocoa/Cocoa.h>
#import "Database.h"
#import "ArticleController.h"
#import "ActivityViewer.h"
#import <Growl/GrowlApplicationBridge.h>
#import "DownloadWindow.h"
#import "FilterView.h"
#import "PopupButton.h"
#import "PluginManager.h"
#import <AppKit/AppKit.h>

@class NewPreferenceController;
@class FoldersTree;
@class SmartFolder;
@class NewSubscription;
@class NewGroupFolder;
@class WebPreferences;
@class BrowserView;
@class ArticleListView;
@class UnifiedDisplayView;
@class EmptyTrashWarning;
@class ClickableProgressIndicator;
@class SearchPanel;

@interface AppController : NSObject <GrowlApplicationBridgeDelegate,NSWindowDelegate,NSToolbarDelegate,NSSplitViewDelegate,NSMenuDelegate> 
{
	IBOutlet NSWindow * mainWindow;
	IBOutlet ArticleController * articleController;
	IBOutlet FoldersTree * foldersTree;
	IBOutlet NSSplitView * splitView1;
	IBOutlet NSView * exportSaveAccessory;
	IBOutlet NSView * searchView;
	IBOutlet NSSearchField * filterSearchField;
	IBOutlet NSPopUpButton * filterViewPopUp;
	IBOutlet ArticleListView * mainArticleView;
	IBOutlet UnifiedDisplayView * unifiedListView;
	IBOutlet NSView * articleFrame;
	IBOutlet BrowserView * browserView;
	IBOutlet NSButtonCell * exportAll;
	IBOutlet NSButtonCell * exportSelected;
	IBOutlet NSButton * exportWithGroups;
	IBOutlet NSSearchField * searchField;
	IBOutlet NSTextField * statusText;
	IBOutlet ClickableProgressIndicator * spinner;
	IBOutlet NSMenuItem * closeTabItem;
	IBOutlet NSMenuItem * closeAllTabsItem;
	IBOutlet NSMenuItem * closeWindowItem;
	IBOutlet NSMenuItem * sortByMenu;
	IBOutlet NSMenuItem * columnsMenu;
	IBOutlet NSMenuItem * stylesMenu;
	IBOutlet NSMenuItem * filtersMenu;
	IBOutlet FilterView * filterView;
	IBOutlet NSView * cosmeticStatusBarHighlightLine;
	IBOutlet NSTextField * currentFilterTextField;
	IBOutlet NSButton * filterIconInStatusBarButton;

	ActivityViewer * activityViewer;
	NewPreferenceController * preferenceController;
	DownloadWindow * downloadWindow;
	SmartFolder * smartFolder;
	NewSubscription * rssFeed;
	NewGroupFolder * groupFolder;
	EmptyTrashWarning * emptyTrashWarning;
	SearchPanel * searchPanel;
	NSMutableArray * sourceWindows;
	
	Database * db;
	PluginManager * pluginManager;
	NSMutableDictionary * scriptPathMappings;
	NSImage * originalIcon;
	NSMenu * appDockMenu;
	NSStatusItem * appStatusItem;
	int progressCount;
	NSDictionary * standardURLs;
	NSTimer * checkTimer;
	int lastCountOfUnread;
	BOOL growlAvailable;
	BOOL isStatusBarVisible;
	NSString * persistedStatusText;
	NSMenuItem * scriptsMenuItem;
	BOOL didCompleteInitialisation;
	NSString * searchString;
}

// Menu action items
-(IBAction)handleAbout:(id)sender;
-(IBAction)exitVienna:(id)sender;
-(IBAction)showPreferencePanel:(id)sender;
-(IBAction)deleteMessage:(id)sender;
-(IBAction)deleteFolder:(id)sender;
-(IBAction)searchUsingToolbarTextField:(id)sender;
-(IBAction)searchUsingFilterField:(id)sender;
-(IBAction)markAllRead:(id)sender;
-(IBAction)markAllSubscriptionsRead:(id)sender;
-(IBAction)markRead:(id)sender;
-(IBAction)markFlagged:(id)sender;
-(IBAction)renameFolder:(id)sender;
-(IBAction)viewFirstUnread:(id)sender;
-(IBAction)viewNextUnread:(id)sender;
-(IBAction)printDocument:(id)sender;
-(IBAction)toggleActivityViewer:(id)sender;
-(IBAction)goBack:(id)sender;
-(IBAction)goForward:(id)sender;
-(IBAction)newSmartFolder:(id)sender;
-(IBAction)newSubscription:(id)sender;
-(IBAction)newGroupFolder:(id)sender;
-(IBAction)editFolder:(id)sender;
-(IBAction)showXMLSource:(id)sender;
-(IBAction)showAcknowledgements:(id)sender;
-(IBAction)showViennaHomePage:(id)sender;
-(IBAction)viewArticlePages:(id)sender;
-(IBAction)viewArticlePagesInAlternateBrowser:(id)sender;
-(IBAction)openWebElementInNewTab:(id)sender;
-(IBAction)openWebElementInDefaultBrowser:(id)sender;
-(IBAction)doSelectScript:(id)sender;
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
-(IBAction)changeFiltering:(id)sender;
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
-(IBAction)newTab:(id)sender;
-(IBAction)downloadEnclosure:(id)sender;
-(IBAction)showHideStatusBar:(id)sender;
-(IBAction)showHideFilterBar:(id)sender;
-(IBAction)hideFilterBar:(id)sender;
-(IBAction)setFocusToSearchField:(id)sender;
-(IBAction)localPerformFindPanelAction:(id)sender;
-(IBAction)keepFoldersArranged:(id)sender;

// Public functions
-(void)installCustomEventHandler;
-(void)setStatusMessage:(NSString *)newStatusText persist:(BOOL)persistenceFlag;
-(NSArray *)contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;
-(void)showUnreadCountOnApplicationIconAndWindowTitle;
-(void)openURLFromString:(NSString *)urlString inPreferredBrowser:(BOOL)openInPreferredBrowserFlag;
-(void)openURL:(NSURL *)url inPreferredBrowser:(BOOL)openInPreferredBrowserFlag;
-(void)createNewTab:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag;
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger)flags;
-(void)openURLInDefaultBrowser:(NSURL *)url;
-(void)handleRSSLink:(NSString *)linkPath;
-(void)selectFolder:(int)folderId;
-(void)createNewSubscription:(NSString *)url underFolder:(NSInteger)parentId afterChild:(NSInteger)predecessorId;
-(void)createNewGoogleReaderSubscription:(NSString *)url underFolder:(NSInteger)parentId withTitle:(NSString*)title afterChild:(NSInteger)predecessorId;
-(void)markSelectedFoldersRead:(NSArray *)arrayOfFolders;
-(void)doSafeInitialisation;
-(void)clearUndoStack;
-(NSString *)filterString;
-(void)setFilterString:(NSString *)newFilterString;
-(NSString *)searchString;
-(void)setSearchString:(NSString *)newSearchString;
-(Article *)selectedArticle;
-(int)currentFolderId;
-(BOOL)isConnecting;
-(void)runAppleScript:(NSString *)scriptName;
-(NSDictionary *)standardURLs;
-(BrowserView *)browserView;
-(NSArray *)folders;
-(void)blogWithExternalEditor:(NSString *)externalEditorBundleIdentifier;
-(void)toggleOptionKeyButtonStates;
-(NSMenu *)folderMenu;
-(void)updateStatusBarFilterButtonVisibility;
-(NSLayoutManager *)layoutManager;
-(void)viewAnimationCompleted:(NSView *)theView withTag:(int)viewTag;
-(void)growlNotify:(id)notifyContext title:(NSString *)title description:(NSString *)description notificationName:(NSString *)notificationName;
-(void)performWebSearch:(SearchMethod *)searchMethod;
-(void)performAllArticlesSearch;
-(void)performWebPageSearch;
@end
