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

#import <Cocoa/Cocoa.h>
#import "BrowserView.h"

@class AppController;
@class TabbedWebView;

@interface BrowserPaneButtonCell : NSCell {}
@end

@interface BrowserPaneButton : NSButton {}
@end

@interface BrowserPane : NSView<BaseView> {
	IBOutlet NSBox * boxFrame;
	IBOutlet TabbedWebView * webPane;
	IBOutlet NSButton * backButton;
	IBOutlet NSButton * forwardButton;
	IBOutlet NSButton * refreshButton;
	IBOutlet NSButton * rssPageButton;
	IBOutlet NSTextField * addressField;
	IBOutlet NSButton * iconImage;
	IBOutlet NSImageView * lockIconImage;
	IBOutlet NSView * viewwwer;
	AppController * controller;
	NSString * pageFilename;
	NSError * lastError;
	BOOL isLocalFile;
	BOOL isLoading;
	BOOL openURLInBackground;
	NSString * rssPageURL;
	NSString * viewTitle;
}

// Action functions
-(IBAction)handleGoForward:(id)sender;
-(IBAction)handleGoBack:(id)sender;
-(IBAction)handleReload:(id)sender;
-(IBAction)handleAddress:(id)sender;
-(IBAction)handleRSSPage:(id)sender;

// Accessor functions
-(void)setController:(AppController *)theController;
-(void)loadURL:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag;
-(NSURL *)url;
-(void)setViewTitle:(NSString *)newTitle;
-(NSString *)viewTitle;
-(BOOL)isLoading;
-(BOOL)canGoBack;
-(BOOL)canGoForward;
-(void)handleStopLoading:(id)sender;
-(void)activateAddressBar;
@end