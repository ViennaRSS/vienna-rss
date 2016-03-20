//
//  ViennaApp.h
//  Vienna
//
//  Created by Steve on Tue Jul 06 2004.
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
#import <Carbon/Carbon.h>
#import "Folder.h"

@interface ViennaApp : NSApplication

// Refresh commands
-(id)handleRefreshAllSubscriptions:(NSScriptCommand *)cmd;
-(id)handleRefreshSubscription:(NSScriptCommand *)cmd;

// Mark all articles read
-(id)handleMarkAllRead:(NSScriptCommand *)cmd;
-(id)handleMarkAllSubscriptionsRead:(NSScriptCommand *)cmd;

// Importing and exporting subscriptions
-(id)handleImportSubscriptions:(NSScriptCommand *)cmd;
-(id)handleExportSubscriptions:(NSScriptCommand *)cmd;

// New subscription
-(id)handleNewSubscription:(NSScriptCommand *)cmd;

// Compact database
-(id)handleCompactDatabase:(NSScriptCommand *)cmd;

// Empty trash
-(id)handleEmptyTrash:(NSScriptCommand *)cmd;

// Reset folder sort order
-(id)resetFolderSort:(NSScriptCommand *)cmd;

// General read-only properties.
@property (nonatomic, readonly, copy) NSString *applicationVersion;
@property (nonatomic, readonly, copy) NSArray *folders;
@property (nonatomic, getter=isRefreshing, readonly) BOOL refreshing;
@property (nonatomic, readonly) NSInteger totalUnreadCount;
@property (nonatomic, readonly, copy) NSString *currentTextSelection;
@property (nonatomic, readonly, copy) NSString *documentHTMLSource;
@property (nonatomic, readonly, copy) NSString *documentTabURL;

// Change folder selection
@property (nonatomic, strong) Folder *currentFolder;

// Current article
@property (nonatomic, readonly, strong) Article *currentArticle;

// Preference properties
@property (nonatomic) NSInteger autoExpireDuration;
@property (nonatomic) float markReadInterval;
@property (nonatomic) BOOL readingPaneOnRight;
@property (nonatomic) BOOL refreshOnStartup;
@property (nonatomic) BOOL checkForNewOnStartup;
@property (nonatomic) BOOL openLinksInVienna;
@property (nonatomic) BOOL openLinksInBackground;
@property (nonatomic) NSInteger minimumFontSize;
@property (nonatomic) BOOL enableMinimumFontSize;
@property (nonatomic) NSInteger refreshFrequency;
@property (nonatomic, copy) NSString *displayStyle;
@property (nonatomic, copy) NSString *folderListFont;
@property (nonatomic) NSInteger folderListFontSize;
@property (nonatomic, copy) NSString *articleListFont;
@property (nonatomic) NSInteger articleListFontSize;
@property (nonatomic) BOOL statusBarVisible;
@property (nonatomic) BOOL filterBarVisible;
@end

