//
//  ArticleListView.h
//  Vienna
//
//  Created by Steve on 8/27/05.
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
#import "BacktrackArray.h"
#import "WebKit/WebView.h"
#import "ExtDateFormatter.h"
#import "BrowserView.h"

@class AppController;
@class MessageListView;
@class ArticleView;
@class TexturedHeader;
@class FoldersTree;

@interface ArticleListView : NSView<BaseView>
{
	IBOutlet TexturedHeader * messageListHeader;
	IBOutlet MessageListView * messageList;
	IBOutlet ArticleView * textView;
	IBOutlet NSSplitView * splitView2;	
	IBOutlet FoldersTree * foldersTree;

	int currentSelectedRow;
	int sortDirection;
	int sortColumnTag;
	int tableLayout;
	int currentFolderId;
	BOOL isAppInitialising;
	BOOL isChangingOrientation;
	AppController * controller;
	Database * db;

	NSMutableDictionary * stylePathMappings;
	NSString * sortColumnIdentifier;
	BOOL previousFolderColumnState;
	NSTimer * markReadTimer;
	NSArray * currentArrayOfArticles;
	BackTrackArray * backtrackArray;
	BOOL isBacktracking;
	NSString * guidOfArticleToSelect;
	NSFont * articleListFont;
	NSString * htmlTemplate;
	NSString * cssStylesheet;
	WebPreferences * defaultWebPrefs;
	NSMutableDictionary * selectionDict;
	NSMutableDictionary * topLineDict;
	NSMutableDictionary * bottomLineDict;
	ExtDateFormatter * extDateFormatter;
}

// Public functions
-(void)setController:(AppController *)theController;
-(void)initialiseArticleView;
-(BOOL)selectFolderAndArticle:(int)folderId guid:(NSString *)guid;
-(void)refreshFolder:(BOOL)reloadData;
-(void)updateVisibleColumns;
-(void)saveTableSettings;
-(int)currentFolderId;
-(NSString *)sortColumnIdentifier;
-(int)tableLayout;
-(NSDictionary *)initStylesMap;
-(NSArray *)markedArticleRange;
-(void)selectFolderWithFilter:(int)newFolderId;
-(NSView *)mainView;
-(void)sortByIdentifier:(NSString *)columnName;
-(Article *)selectedArticle;
-(void)displayNextUnread;
-(void)deleteSelectedMessages;
-(void)markReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag;
-(void)markAllReadByReferencesArray:(NSArray *)refArray readFlag:(BOOL)readFlag;
-(void)markAllReadByArray:(NSArray *)folderArray;
-(void)markDeletedByArray:(NSArray *)articleArray deleteFlag:(BOOL)deleteFlag;
-(void)markFlaggedByArray:(NSArray *)articleArray flagged:(BOOL)flagged;
@end
