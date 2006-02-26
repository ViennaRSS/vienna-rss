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
#import "WebKit/WebView.h"
#import "BrowserView.h"

@class AppController;
@class ArticleView;

@interface BrowserPane : NSBox<BaseView> {
	IBOutlet ArticleView * webPane;
	AppController * controller;
	NSString * pageFilename;
	BrowserTab * tab;
	NSError * lastError;
	BOOL isLocalFile;
	BOOL isLoadingFrame;
	BOOL hasPageTitle;
	BOOL openURLInBackground;
}

// Accessor functions
-(void)setController:(AppController *)theController;
-(void)loadURL:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag;
-(NSURL *)url;
-(void)setTab:(BrowserTab *)newTab;
-(BOOL)isLoading;
-(void)handleGoForward;
-(void)handleGoBack;
-(BOOL)canGoBack;
-(BOOL)canGoForward;
-(void)handleReload:(id)sender;
-(void)handleStopLoading:(id)sender;
-(NSView *)mainView;
@end
