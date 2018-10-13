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
@import WebKit;

#import "BaseView.h"

@class MMTabBarView;
@class BrowserPane;

@interface Browser : NSObject
{
	NSView<BaseView, WebUIDelegate, WebFrameLoadDelegate> * primaryTabItemView;
}

@property (assign) IBOutlet NSLayoutConstraint *tabBarHeightConstraint;
@property (assign) IBOutlet MMTabBarView *tabBarControl;

// Accessors
-(BrowserPane *)newTab;
-(BrowserPane *)createAndLoadNewTab:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag;
-(BrowserPane *)createNewTab:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag;
-(BrowserPane *)createNewTab:(NSURL *)url withTitle:(NSString *)title inBackground:(BOOL)openInBackgroundFlag;

-(void)setPrimaryTabItemView:(NSView *)newPrimaryTabItemView;
-(NSString *)tabItemViewTitle:(NSView *)tabView;
@property (nonatomic, readonly) NSTabViewItem *activeTab;
@property (nonatomic, readonly) NSView<BaseView> *activeTabItemView;
-(NSView<BaseView, WebUIDelegate, WebFrameLoadDelegate> *)primaryTabItemView;
-(void)setActiveTabToPrimaryTab;
-(void)closeTab:(NSTabViewItem *)tabViewItem;
-(void)closeAllTabs;
@property (nonatomic, readonly) NSInteger countOfTabs;
-(void)showArticlesTab;
-(void)showPreviousTab;
-(void)showNextTab;
-(void)saveOpenTabs;
@end
