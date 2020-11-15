//
//  ArticleListView.h
//  Vienna
//
//  Created by Steve on 8/27/05.
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
@import WebKit;

#import "BaseView.h"
#import "ArticleBaseView.h"

@class AppController;
@class ArticleView;
@class MessageListView;
@class EnclosureView;
@protocol ArticleContentView;
@protocol ArticleViewDelegate;

@interface ArticleListView : NSView<BaseView, ArticleBaseView, ArticleViewDelegate, NSTableViewDelegate, NSTableViewDataSource>
{
	IBOutlet MessageListView * articleList;
    NSObject<ArticleContentView> *articleText;
	IBOutlet NSSplitView * splitView2;
	IBOutlet EnclosureView * enclosureView;

	NSInteger tableLayout;
	BOOL isAppInitialising;
	BOOL isChangingOrientation;
	BOOL isInTableInit;
	BOOL blockSelectionHandler;

	NSTimer * markReadTimer;
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

	NSURL *	currentURL;
	BOOL isCurrentPageFullHTML;
	BOOL isLoadingHTMLArticle;
	NSError * lastError;
	NSProgressIndicator * progressIndicator;
}

@property (weak, nonatomic) AppController *controller;

// Public functions
-(void)updateAlternateMenuTitle;
-(void)updateVisibleColumns;
-(void)saveTableSettings;
-(BOOL)canDeleteMessageAtRow:(NSInteger)row;
-(void)loadArticleLink:(NSString *) articleLink;
@property (nonatomic, readonly, copy) NSURL *url;
-(void)webViewLoadFinished:(NSNotification *)notification;
@end
