//
//  ArticleController.h
//  Vienna
//
//  Created by Steve on 5/6/06.
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

#import "ArticleBaseView.h"
#import "ArticleListConstants.h"

@class Article;
@class ArticleListView;
@class BackTrackArray;
@class FoldersTree;
@class UnifiedDisplayView;

/* ArticleController
 * The ArticleController contains the controlling logic for the article view that is
 * independent of the view. The code here was split from ArticleListView for the
 * purpose of allowing us to manage multiple article views. The application
 * controller creates a single article controller then assigns it the candidate
 * article view. Thus all control of the article view now passes through the article
 * controller.
 */
@interface ArticleController : NSViewController <NSMenuItemValidation>

@property (nonatomic) FoldersTree * foldersTree;
@property (nonatomic) ArticleListView *articleListView;
@property (nonatomic) UnifiedDisplayView *unifiedListView;
@property (nonatomic) NSView<ArticleBaseView> * mainArticleView;
@property (nonatomic, copy) NSArray * currentArrayOfArticles;
@property (nonatomic, copy) NSArray * folderArrayOfArticles;
@property (nonatomic) NSDictionary * articleSortSpecifiers;
@property (nonatomic) BackTrackArray * backtrackArray;

// Public functions
-(NSView<ArticleBaseView> *)mainArticleView;
-(void)setLayout:(NSInteger)newLayout;
@property (nonatomic, readonly) NSInteger currentFolderId;
@property (nonatomic, readonly) Article *selectedArticle;
@property (readonly, nonatomic) NSArray *markedArticleRange;
-(void)updateVisibleColumns;
-(void)saveTableSettings;
-(void)sortArticles;
@property (readonly, nonatomic) NSArray *allArticles;
-(void)displayFirstUnread;
-(void)displayNextUnread;
-(void)displayNextFolderWithUnread;
-(void)reloadArrayOfArticles;
-(void)displayFolder:(NSInteger)newFolderId;
-(void)refilterArrayOfArticles;
@property (readonly, nonatomic) NSString *sortColumnIdentifier;
@property (nonatomic, readonly) BOOL sortIsAscending;
-(void)ensureSelectedArticle;
-(void)sortByIdentifier:(NSString *)columnName;
-(void)sortAscending:(BOOL)newAscending;
-(void)deleteArticlesByArray:(NSArray *)articleArray;
-(void)markReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag;
-(void)markAllReadByReferencesArray:(NSArray *)refArray readFlag:(BOOL)readFlag;
-(void)markAllFoldersReadByArray:(NSArray *)folderArray;
-(void)markDeletedByArray:(NSArray *)articleArray deleteFlag:(BOOL)deleteFlag;
-(void)markFlaggedByArray:(NSArray *)articleArray flagged:(BOOL)flagged;
-(void)selectFolderAndArticle:(NSInteger)folderId guid:(NSString *)guid;
-(void)addBacktrack:(NSString *)guid;
-(void)goForward;
-(void)goBack;
@property (nonatomic, readonly) BOOL canGoForward;
@property (nonatomic, readonly) BOOL canGoBack;

- (IBAction)reportLayout:(id)sender;
- (IBAction)condensedLayout:(id)sender;
- (IBAction)unifiedLayout:(id)sender;

// MARK: Filter bar

@property (readonly, nonatomic) NSString *filterModeLabel;

@end
