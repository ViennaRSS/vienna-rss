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
@import MMTabBarView;
@import WebKit;

#import "BaseView.h"

@protocol Tab;

// This is defined somewhere but I can't find where.
#define WebKitErrorPlugInWillHandleLoad	204

@class TabbedWebView;

@interface BrowserPaneButtonCell : NSCell {}
@end

@interface BrowserPaneButton : NSButton {}
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
@interface BrowserPane : NSView <BaseView, WebFrameLoadDelegate, MMTabBarItem, Tab> {
	IBOutlet NSButton * backButton;
	IBOutlet NSButton * forwardButton;
	IBOutlet NSButton * refreshButton;
	IBOutlet NSButton * rssPageButton;
	IBOutlet NSTextField * addressField;
	IBOutlet NSButton * iconImage;
	IBOutlet NSImageView * lockIconImage;
	NSString * pageFilename;
	NSError * lastError;
	BOOL loading;
	BOOL hasRSSlink;
}
#pragma clang diagnostic pop

@property (nonatomic) IBOutlet TabbedWebView * webPane;

// Action functions
-(IBAction)handleGoForward:(id)sender;
-(IBAction)handleGoBack:(id)sender;
-(IBAction)handleReload:(id)sender;
-(IBAction)handleAddress:(id)sender;
-(IBAction)handleRSSPage:(id)sender;

// Accessor functions
-(void)loadTab;
@property (weak) NSTabViewItem *tab;
@property (nonatomic, copy) NSURL *tabUrl;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wproperty-attribute-mismatch"
@property (copy) NSString *title;
#pragma clang diagnostic pop
@property (nonatomic, readonly) BOOL loading;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
-(void)handleStopLoading:(id)sender;
-(void)activateAddressBar;
@property (readonly) NSString *textSelection;
@property (readonly) NSString *html;


//tabBarItem functions
@property BOOL hasCloseButton;
@property BOOL isProcessing;

-(void)hoveredOverURL:(NSURL *)url;

@end
