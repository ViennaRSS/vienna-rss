//
//  NewSubscription.h
//  Vienna
//
//  Created by Steve on 4/23/05.
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
#import "Database.h"

@class SubscriptionModel;

@interface NewSubscription : NSWindowController {
	IBOutlet NSTextField * linkTitle;
	IBOutlet NSTextField * feedURL;
	IBOutlet NSTextField * editFeedURL;
	IBOutlet NSPopUpButton * feedSource;
	IBOutlet NSButton * subscribeButton;
	IBOutlet NSButton * saveButton;
	IBOutlet NSButton * editCancelButton;
	IBOutlet NSButton * subscribeCancelButton;
	IBOutlet NSWindow * newRSSFeedWindow;
	IBOutlet NSWindow * editRSSFeedWindow;
	IBOutlet NSButton * siteHomePageButton;
	BOOL googleOptionButton;
	NSDictionary * sourcesDict;
	Database * db;
	NSInteger parentId;
	NSInteger editFolderId;
    SubscriptionModel *subscriptionModel;
    
}

@property BOOL googleOptionButton;
@property(strong) NSArray * topObjects;

// Action handlers
-(IBAction)doSubscribe:(id)sender;
-(IBAction)doSave:(id)sender;
-(IBAction)doSubscribeCancel:(id)sender;
-(IBAction)doEditCancel:(id)sender;
-(IBAction)doLinkSourceChanged:(id)sender;
-(IBAction)doShowSiteHomePage:(id)sender;
-(IBAction)doGoogleOption:(id)sender;

// General functions
-(id)initWithDatabase:(Database *)newDb;
-(void)newSubscription:(NSWindow *)window underParent:(NSInteger)itemId initialURL:(NSString *)initialURL;
-(void)editSubscription:(NSWindow *)window folderId:(NSInteger)folderId;

@end
