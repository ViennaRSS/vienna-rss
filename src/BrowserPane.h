//
//  BrowserPane.h
//  Vienna
//
//  Created by Steve on 9/7/05.
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
#import <MMTabBarView/MMTabBarItem.h>

// This is defined somewhere but I can't find where.
#define WebKitErrorPlugInWillHandleLoad	204

@class BrowserView;
@class SSTextField;
@class TabbedWebView;

@interface BrowserPaneButtonCell : NSCell {}
@end

@interface BrowserPaneButton : NSButton {}
@end

@interface BrowserPane : NSView<BaseView, WebUIDelegate, WebFrameLoadDelegate, MMTabBarItem> {
	IBOutlet NSButton * backButton;
	IBOutlet NSButton * forwardButton;
	IBOutlet NSButton * refreshButton;
	IBOutlet NSButton * rssPageButton;
	IBOutlet SSTextField * addressField;
	IBOutlet NSButton * iconImage;
	IBOutlet NSImageView * lockIconImage;
	NSString * pageFilename;
	NSError * lastError;
	BOOL isLocalFile;
	BOOL isLoading;
	BOOL hasRSSlink;
}

@property (nonatomic, strong) IBOutlet TabbedWebView * webPane;

// Action functions
-(IBAction)handleGoForward:(id)sender;
-(IBAction)handleGoBack:(id)sender;
-(IBAction)handleReload:(id)sender;
-(IBAction)handleAddress:(id)sender;
-(IBAction)handleRSSPage:(id)sender;

// Accessor functions
-(void)load;
@property (weak) BrowserView *browser;
@property (weak) NSTabViewItem *tab;
@property (nonatomic) NSURL *url;
@property (nonatomic, copy) NSString *viewTitle;
@property (nonatomic, getter=isLoading, readonly) BOOL loading;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
-(void)handleStopLoading:(id)sender;
-(void)activateAddressBar;

//tabBarItem functions
@property (assign) BOOL hasCloseButton;
@property (assign) BOOL isProcessing;
@end
