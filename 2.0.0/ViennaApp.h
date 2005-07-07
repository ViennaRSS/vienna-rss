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

#import <Foundation/Foundation.h>
#import "Folder.h"

@interface ViennaApp : NSApplication {
}

// Refresh commands
-(id)handleRefreshAllSubscriptions:(NSScriptCommand *)cmd;
-(id)handleRefreshSubscription:(NSScriptCommand *)cmd;

// Mark all messages read
-(id)handleMarkAllRead:(NSScriptCommand *)cmd;

// Importing and exporting subscriptions
-(id)handleImportSubscriptions:(NSScriptCommand *)cmd;
-(id)handleExportSubscriptions:(NSScriptCommand *)cmd;

// General read-only properties.
-(NSString *)applicationVersion;
-(NSArray *)folders;
-(BOOL)isRefreshing;
-(int)unreadCount;

// Change folder selection
-(Folder *)currentFolder;
-(void)setCurrentFolder:(Folder *)newCurrentFolder;

// Change position of reading pane
-(BOOL)readingPaneOnRight;
-(void)setReadingPaneOnRight:(BOOL)flag;

// Check for new versions of Vienna on startup
-(BOOL)checkForNewOnStartup;
-(void)setCheckForNewOnStartup:(BOOL)flag;
-(void)internalChangeCheckOnStartup:(BOOL)flag;

// Refresh all subscriptions on startup
-(BOOL)refreshOnStartup;
-(void)setRefreshOnStartup:(BOOL)flag;
-(void)internalChangeRefreshOnStartup:(BOOL)flag;

// Current display style
-(NSString *)displayStyle;
-(void)setDisplayStyle:(NSString *)newStyle;

// Modify the refresh frequency
-(int)refreshFrequency;
-(void)setRefreshFrequency:(int)newFrequency;
-(void)internalSetRefreshFrequency:(int)newFrequency;

// Folder list font
-(NSString *)folderListFont;
-(int)folderListFontSize;
-(void)setFolderListFont:(NSString *)newFontName;
-(void)setFolderListFontSize:(int)newFontSize;

// Article list font
-(NSString *)articleListFont;
-(int)articleListFontSize;
-(void)setArticleListFont:(NSString *)newFontName;
-(void)setArticleListFontSize:(int)newFontSize;
@end

