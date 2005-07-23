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
#import "BacktrackArray.h"
#import "ActivityViewer.h"
#import "ExtDateFormatter.h"
#import "WebKit/WebView.h"

@class PreferenceController;
@class AboutController;
@class FoldersTree;
@class FolderHeaderBar;
@class CheckForUpdates;
@class DownloadUpdate;
@class SearchFolder;
@class NewSubscription;
@class NewGroupFolder;
@class MessageView;
@class MessageListView;
@class ArticleView;
@class TexturedHeader;
@class FeedCredentials;

// How to select a message after reloading a folder
// (Values must be <= 0 because > 0 is a message number)
#define MA_Select_None		0
#define MA_Select_Unread	-1

@interface AppController : NSObject {
	IBOutlet NSWindow * mainWindow;
	IBOutlet FoldersTree * foldersTree;
	IBOutlet MessageListView * messageList;
	IBOutlet ArticleView * textView;
	IBOutlet FolderHeaderBar * headerBarView;
	IBOutlet NSWindow * gotoWindow;
	IBOutlet NSWindow * renameWindow;
	IBOutlet NSWindow * compactDatabaseWindow;
	IBOutlet NSTextField * gotoNumber;
	IBOutlet NSTextField * renameField;
	IBOutlet NSSplitView * splitView1;
	IBOutlet NSSplitView * splitView2;
	IBOutlet NSView * exportSaveAccessory;
	IBOutlet NSButtonCell * exportAll;
	IBOutlet NSButtonCell * exportSelected;
	IBOutlet NSSearchField * searchField;
	IBOutlet TexturedHeader * folderHeader;
	IBOutlet TexturedHeader * messageListHeader;
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
	FeedCredentials * credentialsController;

	Database * db;
	BOOL sortedFlag;
	int currentFolderId;
	int currentSelectedRow;
	NSArray * currentArrayOfMessages;
	NSMutableDictionary * stylePathMappings;
	NSMutableDictionary * scriptPathMappings;
	BackTrackArray * backtrackArray;
	BOOL isBacktracking;
	BOOL selectAtEndOfReload;
	NSFont * messageListFont;
	NSImage * originalIcon;
	NSString * sortColumnIdentifier;
	NSMenu * appDockMenu;
	int sortDirection;
	int sortColumnTag;
	int progressCount;
	NSArray * allColumns;
	ExtDateFormatter * extDateFormatter;
	NSMutableDictionary * topLineDict;
	NSMutableDictionary * bottomLineDict;
	NSTimer * checkTimer;
	NSTimer * markReadTimer;
	NSTimer * pumpTimer;
	int lastCountOfUnread;
	int unreadAtBeginning;
	BOOL growlAvailable;
	int requestedMessage;
	NSString * appName;
	NSString * selectedStyle;
	NSString * htmlTemplate;
	NSString * cssStylesheet;
	NSString * persistedStatusText;
	int maximumConnections;
	int totalConnections;
	NSMutableArray * connectionsArray;
	NSMutableArray * folderIconRefreshArray;
	NSMutableArray * refreshArray;
	NSMutableArray * authQueue;
	BOOL previousFolderColumnState;
	BOOL isViewingArticlePage;
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
-(IBAction)setTableLayout:(id)sender;
-(IBAction)setCondensedLayout:(id)sender;
-(IBAction)doSelectScript:(id)sender;
-(IBAction)doOpenScriptsFolder:(id)sender;

// Infobar functions
-(void)setStatusMessage:(NSString *)newStatusText persist:(BOOL)persistenceFlag;
-(void)showUnreadCountOnApplicationIcon;

// Notification response functions
-(void)handleFolderSelection:(NSNotification *)note;
-(void)handleCheckFrequencyChange:(NSNotification *)note;
-(void)handleFolderUpdate:(NSNotification *)nc;
-(void)handleRSSLink:(NSString *)linkPath;

// Message selection functions
-(BOOL)scrollToMessage:(int)number;
-(void)selectFirstUnreadInFolder;
-(void)makeRowSelectedAndVisible:(int)rowIndex;
-(BOOL)viewNextUnreadInCurrentFolder:(int)currentRow;

// General functions
-(void)initSortMenu;
-(void)initColumnsMenu;
-(void)initStylesMenu;
-(void)initScriptsMenu;
-(void)startProgressIndicator;
-(void)stopProgressIndicator;
-(void)loadMapFromPath:(NSString *)path intoMap:(NSMutableDictionary *)pathMappings foldersOnly:(BOOL)foldersOnly;
-(void)setActiveStyle:(NSString *)newStyleName refresh:(BOOL)refresh;
-(void)setMainWindowTitle:(int)folderId;
-(void)doEditFolder:(Folder *)folder;
-(void)setReadingPaneOnRight:(BOOL)onRightFlag;
-(void)refreshFolder:(BOOL)reloadData;
-(void)markAllReadInArray:(NSArray *)folderArray;
-(BOOL)selectFolderAndMessage:(int)folderId messageNumber:(int)messageNumber;
-(void)selectFolderWithFilter:(int)newFolderId;
-(void)reloadArrayOfMessages;
-(void)updateMessageText;
-(void)markFlaggedByArray:(NSArray *)messageArray flagged:(BOOL)flagged;
-(void)getMessagesOnTimer:(NSTimer *)aTimer;
-(void)doConfirmedDelete:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
-(void)markCurrentRead:(NSTimer *)aTimer;
-(void)refreshMessageAtRow:(int)theRow markRead:(BOOL)markReadFlag;
-(void)updateMessageListRowHeight;
-(void)setOrientation:(BOOL)flag;
-(void)runAppleScript:(NSString *)scriptName;
-(Database *)database;
-(int)currentFolderId;
-(NSArray *)folders;
-(NSString *)appName;
-(BOOL)isConnecting;
-(void)openURLInBrowser:(NSString *)urlString;
-(void)openURLInBrowserWithURL:(NSURL *)url;
-(void)createNewSubscription:(NSString *)url underFolder:(int)parentId;

// Rename sheet functions
-(IBAction)endRenameFolder:(id)sender;
-(IBAction)cancelRenameFolder:(id)sender;

// Message list helper functions
-(void)initTableView;
-(void)showColumnsForFolder:(int)folderId;
-(void)setTableViewFont;
-(void)sortByIdentifier:(NSString *)columnName;
-(void)showSortDirection;
-(void)setSortColumnIdentifier:(NSString *)str;
-(void)runOKAlertSheet:(NSString *)titleString text:(NSString *)bodyText, ...;
-(void)updateVisibleColumns;
-(void)saveTableSettings;
-(void)selectMessageAfterReload;
-(void)markReadByArray:(NSArray *)messageArray readFlag:(BOOL)readFlag;
@end
