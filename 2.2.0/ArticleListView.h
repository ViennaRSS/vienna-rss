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
#import "WebKit/WebView.h"
#import "ExtDateFormatter.h"
#import "ArticleBaseView.h"
#import "BrowserView.h"
#import "PopupButton.h"
#import "KFSplitView.h"

@class AppController;
@class ArticleController;
@class MessageListView;
@class ArticleView;
@class TexturedHeader;
@class FoldersTree;

@interface ArticleListView : NSView<BaseView, ArticleBaseView>
{
	IBOutlet AppController * controller;
	IBOutlet ArticleController * articleController;
	IBOutlet TexturedHeader * articleListHeader;
	IBOutlet MessageListView * articleList;
	IBOutlet ArticleView * articleText;
	IBOutlet KFSplitView * splitView2;
	IBOutlet FoldersTree * foldersTree;
	IBOutlet PopupButton * filtersPopupMenu;

	int currentSelectedRow;
	int tableLayout;
	BOOL isAppInitialising;
	BOOL isChangingOrientation;
	BOOL isInTableInit;
	BOOL blockSelectionHandler;
	BOOL blockMarkRead;

	NSTimer * markReadTimer;
	NSTimer * selectionTimer;
	NSString * guidOfArticleToSelect;
	NSFont * articleListFont;
	NSFont * articleListUnreadFont;
	NSMutableDictionary * reportCellDict;
	NSMutableDictionary * unreadReportCellDict;
	NSMutableDictionary * selectionDict;
	NSMutableDictionary * topLineDict;
	NSMutableDictionary * linkLineDict;
	NSMutableDictionary * middleLineDict;
	NSMutableDictionary * bottomLineDict;
	NSMutableDictionary * unreadTopLineDict;
	NSMutableDictionary * unreadTopLineSelectionDict;
}

// Public functions
-(void)initialiseArticleView;
-(void)updateAlternateMenuTitle;
-(void)updateVisibleColumns;
-(void)saveTableSettings;
-(int)tableLayout;
-(NSArray *)markedArticleRange;
-(BOOL)canDeleteMessageAtRow:(int)row;
@end
