//
//  TabbedWebView.h
//  Vienna
//
//  Created by Steve on Tue Jul 05 2005.
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
#import <WebKit/WebKit.h>

@class AppController;

@interface TabbedWebView : WebView <WebPolicyDelegate> {
	AppController * controller;
	WebPreferences * defaultWebPrefs;
	BOOL openLinksInNewBrowser;
	BOOL isFeedRedirect;
	BOOL isDownload;
}

// Public functions
+(NSString *)userAgent;
-(void)initTabbedWebView;
-(void)setController:(AppController *)theController;
-(void)setOpenLinksInNewBrowser:(BOOL)flag;
-(void)keyDown:(NSEvent *)theEvent;
-(void)printDocument:(id)sender;
@property (nonatomic, getter=isFeedRedirect, readonly) BOOL feedRedirect;
@property (nonatomic, getter=isDownload, readonly) BOOL download;
-(void)scrollToTop;
-(void)scrollToBottom;

@end
