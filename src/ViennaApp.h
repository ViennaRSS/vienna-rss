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
-(NSString *)applicationVersion;
-(NSArray *)folders;
-(BOOL)isRefreshing;
-(int)totalUnreadCount;
-(NSString *)currentTextSelection;
-(NSString *)documentHTMLSource;
-(NSString *)documentTabURL;

// Change folder selection
-(Folder *)currentFolder;
-(void)setCurrentFolder:(Folder *)newCurrentFolder;

// Current article
-(Article *)currentArticle;

// Preference getters
-(int)autoExpireDuration;
-(float)markReadInterval;
-(BOOL)readingPaneOnRight;
-(BOOL)refreshOnStartup;
-(BOOL)checkForNewOnStartup;
-(BOOL)openLinksInVienna;
-(BOOL)openLinksInBackground;
-(int)minimumFontSize;
-(BOOL)enableMinimumFontSize;
-(int)refreshFrequency;
-(NSString *)displayStyle;
-(NSString *)folderListFont;
-(int)folderListFontSize;
-(NSString *)articleListFont;
-(int)articleListFontSize;
-(BOOL)statusBarVisible;
-(BOOL)filterBarVisible;

// Preference setters
-(void)setAutoExpireDuration:(int)newDuration;
-(void)setMarkReadInterval:(float)newInterval;
-(void)setReadingPaneOnRight:(BOOL)flag;
-(void)setRefreshOnStartup:(BOOL)flag;
-(void)setCheckForNewOnStartup:(BOOL)flag;
-(void)setOpenLinksInVienna:(BOOL)flag;
-(void)setOpenLinksInBackground:(BOOL)flag;
-(void)setMinimumFontSize:(int)newSize;
-(void)setEnableMinimumFontSize:(BOOL)flag;
-(void)setRefreshFrequency:(int)newFrequency;
-(void)setDisplayStyle:(NSString *)newStyle;
-(void)setFolderListFont:(NSString *)newFontName;
-(void)setFolderListFontSize:(int)newFontSize;
-(void)setArticleListFont:(NSString *)newFontName;
-(void)setArticleListFontSize:(int)newFontSize;
-(void)setStatusBarVisible:(BOOL)flag;
-(void)setFilterBarVisible:(BOOL)flag;
@end

