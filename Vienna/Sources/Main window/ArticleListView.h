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

#import "BaseView.h"
#import "ArticleBaseView.h"
#import "ArticleViewDelegate.h"
#import "MessageListView.h"

@interface ArticleListView : NSView <BaseView, ArticleBaseView, ArticleViewDelegate, MessageListViewDelegate, NSTableViewDataSource, NSSplitViewDelegate>

// Public functions
-(void)updateVisibleColumns;
-(void)saveTableSettings;
-(void)loadArticleLink:(NSString *) articleLink;
@property (readonly, nonatomic) NSURL *url;

@end
