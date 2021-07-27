//
//  UnifiedDisplayView.h
//  Vienna
//
//  Created by Steve Palmer, Barijaona Ramaholimihaso and other Vienna contributors
//  Copyright (c) 2004-2014 Vienna contributors. All rights reserved.
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

#import "ArticleBaseView.h"
#import "BaseView.h"

@class AppController;
@class ExtendedTableView;

@interface UnifiedDisplayView : NSView <BaseView, ArticleBaseView, NSMenuItemValidation, NSTableViewDelegate, NSTableViewDataSource, WKNavigationDelegate>
{
    IBOutlet ExtendedTableView *articleList;

	NSTimer * markReadTimer;

	NSMutableArray * rowHeightArray;
	NSProgressIndicator * progressIndicator;
}

@property (weak, nonatomic) AppController *controller;

// Public functions
-(void)saveTableSettings;
-(BOOL)canDeleteMessageAtRow:(NSInteger)row;
- (void)webViewLoadFinished:(NSNotification *)notification;
@end
