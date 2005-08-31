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

#import <Foundation/Foundation.h>
#import "Database.h"
#import "ActivityViewer.h"

@class PreferenceController;
@class AboutController;
@class FoldersTree;
@class CheckForUpdates;
@class DownloadUpdate;
@class SearchFolder;
@class NewSubscription;
@class NewGroupFolder;
@class WebPreferences;
@class BrowserView;
@class ArticleListView;

@interface AppController : NSObject {
	IBOutlet NSWindow * mainWindow;
	IBOutlet FoldersTree * foldersTree;
	IBOutlet NSWindow * renameWindow;
	IBOutlet NSWindow * compactDatabaseWindow;
	IBOutlet NSTextField * renameField;
	IBOutlet NSSplitView * splitView1;
	IBOutlet NSView * exportSaveAccessory;
	IBOutlet ArticleListView * mainArticleView;
	IBOutlet BrowserView * browserView;
	IBOutlet NSButtonCell * exportAll;
	IBOutlet NSButtonCell * exportSelected;
	IBOutlet NSSearchField * searchField;
	IBOutlet NSTextField * statusText;
	IBOutlet NSProgressIndicator * spinner;

	ActivityViewer * activityViewer;
	PreferenceController * preferenceController;
	AboutController * aboutController;
	CheckForUpdates * checkUpdates;
	DownloadUpdate * downloadUpdate;
	SearchFolder * smartFolder;
	NewSubscription * rssFeed;
	NewGroupFolder * groupFolder;

	Database * db;
	NSMutableDictionary * scriptPathMappings;
	NSImage * originalIcon;
	NSMenu * appDockMenu;
	int progressCount;
	NSDictionary * standardURLs;
	NSTimer * checkTimer;
	int lastCountOfUnread;
	BOOL growlAvailable;
	NSString * appName;
	NSString * persistedStatusText;
}

// Menu action items
-(IBAction)handleAbout:(id)sender;
-(IBAction)showPreferencePanel:(id)sender;
-(IBAction)deleteMessage:(id)sender;
-(IBAction)deleteFolder:(id)sender;
-(IBAction)searchUsingToolbarTextField:(id)sender;
-(IBAction)markAllRead:(id)sender;
-(IBAction)markRead:(id)sender;
-(IBAction)markFlagged:(id)sender;
-(IBAction)viewNextUnread:(id)sender;
-(IBAction)printDocument:(id)sender;
-(IBAction)toggleActivityViewer:(id)sender;
-(IBAction)backTrackMessage:(id)sender;
-(IBAction)forwardTrackMessage:(id)sender;
-(IBAction)newSmartFolder:(id)sender;
-(IBAction)newSubscription:(id)sender;
-(IBAction)newGroupFolder:(id)sender;
-(IBAction)compactDatabase:(id)sender;
-(IBAction)editFolder:(id)sender;
-(IBAction)showAcknowledgements:(id)sender;
-(IBAction)showViennaHomePage:(id)sender;
-(IBAction)readingPaneOnRight:(id)sender;
-(IBAction)readingPaneOnBottom:(id)sender;
-(IBAction)closeMainWindow:(id)sender;
-(IBAction)viewArticlePage:(id)sender;
-(IBAction)doSelectScript:(id)sender;
-(IBAction)doOpenScriptsFolder:(id)sender;
-(IBAction)validateFeed:(id)sender;
-(IBAction)emptyTrash:(id)sender;
-(IBAction)refreshSelectedSubscriptions:(id)sender;
-(IBAction)refreshAllSubscriptions:(id)sender;
-(IBAction)cancelAllRefreshes:(id)sender;
-(IBAction)moreStyles:(id)sender;
-(IBAction)showMainWindow:(id)sender;

// Public functions
-(void)setStatusMessage:(NSString *)newStatusText persist:(BOOL)persistenceFlag;
-(void)showUnreadCountOnApplicationIcon;
-(void)openURLInBrowser:(NSString *)urlString;
-(void)openURLInBrowserWithURL:(NSURL *)url;
-(void)handleRSSLink:(NSString *)linkPath;
-(BOOL)selectFolder:(int)folderId;
-(void)markAllReadInArray:(NSArray *)folderArray;
-(void)createNewSubscription:(NSString *)url underFolder:(int)parentId;
-(void)setMainWindowTitle:(int)folderId;
-(void)doSafeInitialisation;
-(void)clearUndoStack;
-(NSString *)searchString;
-(int)currentFolderId;
-(BOOL)isConnecting;
-(Database *)database;
-(NSArray *)folders;
@end
