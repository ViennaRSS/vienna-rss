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

#import "ArticleBaseView.h"
#import "ArticleViewDelegate.h"
#import "MessageListView.h"

@class AppController;
@class ArticleController;

@interface ArticleListView : NSView <ArticleBaseView,
                                     ArticleViewDelegate,
                                     MessageListViewDelegate,
                                     NSMenuDelegate,
                                     NSSplitViewDelegate,
                                     NSTableViewDataSource>

// This class is initialized in Interface Builder (-initWithCoder:).
- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (weak, nonatomic) AppController *appController;
@property (weak, nonatomic) ArticleController *articleController;

// Public functions
- (void)initialiseArticleView;
-(void)updateVisibleColumns;
-(void)saveTableSettings;
-(void)loadArticleLink:(NSString *) articleLink;

@end
