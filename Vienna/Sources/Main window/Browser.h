//
//  Browser.h
//  Vienna
//
//  Created by Steve on 8/26/05.
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

@import Cocoa;
@import MMTabBarView;
@import WebKit;

#import "BaseView.h"

@class MMTabBarView;
@class BrowserPane;

@interface Browser : NSObject

@property (assign) IBOutlet NSLayoutConstraint *tabBarHeightConstraint;
@property (assign) IBOutlet MMTabBarView *tabBarControl;
@property (nonatomic) NSTabViewItem *primaryTab;

// Accessors
-(BrowserPane *)createNewTab;
-(BrowserPane *)createNewTab:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag load:(BOOL)load;
-(BrowserPane *)createNewTab:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag;
-(BrowserPane *)createNewTab:(NSURL *)url withTitle:(NSString *)title inBackground:(BOOL)openInBackgroundFlag;
@property (nonatomic, readonly) NSTabViewItem *activeTab;
-(void)closeActiveTab;
-(void)closeAllTabs;
@property (nonatomic, readonly) NSInteger browserTabCount;

-(void)switchToPrimaryTab;
-(void)showPreviousTab;
-(void)showNextTab;
-(void)saveOpenTabs;
@end
