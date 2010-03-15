//
//  UnifiedListView.h
//  Vienna
//
//  Created by Steve on 5/5/06.
//  Copyright (c) 2004-2006 Steve Palmer. All rights reserved.
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
#import "BrowserView.h"
#import "PopupButton.h"
#import "BaseView.h"
#import "ArticleBaseView.h"

@class AppController;
@class ArticleController;
@class ArticleView;
@class FoldersTree;

@interface UnifiedDisplayView : NSView<BaseView, ArticleBaseView>
{
	IBOutlet AppController * controller;
	IBOutlet ArticleController * articleController;
	IBOutlet ArticleView * unifiedText;
	IBOutlet FoldersTree * foldersTree;
}

// Public functions
@end
