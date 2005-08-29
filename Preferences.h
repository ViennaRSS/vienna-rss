//
//  Preferences.h
//  Vienna
//
//  Created by Steve on 8/23/05.
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

@interface Preferences : NSObject {
	float markReadInterval;
	int minimumFontSize;
	int refreshFrequency;
	BOOL refreshOnStartup;
	BOOL checkForNewOnStartup;
	BOOL enableMinimumFontSize;
	BOOL readingPaneOnRight;
	BOOL openLinksInVienna;
	BOOL openLinksInBackground;
	BOOL hasPrefs;
	NSString * displayStyle;
	NSFont * folderFont;
	NSFont * articleFont;
}

// Accessor functions
+(Preferences *)standardPreferences;

// Read-only internal settings
-(int)backTrackQueueSize;

// Mark read interval
-(float)markReadInterval;
-(void)setMarkReadInterval:(float)newInterval;

// Change position of reading pane
-(BOOL)readingPaneOnRight;
-(void)setReadingPaneOnRight:(BOOL)flag;

// Refresh all subscriptions on startup
-(BOOL)refreshOnStartup;
-(void)setRefreshOnStartup:(BOOL)flag;

// Check for new versions of Vienna on startup
-(BOOL)checkForNewOnStartup;
-(void)setCheckForNewOnStartup:(BOOL)flag;

// Opening URL links in Vienna
-(BOOL)openLinksInVienna;
-(void)setOpenLinksInVienna:(float)flag;

// Opening URL links in background
-(BOOL)openLinksInBackground;
-(void)setOpenLinksInBackground:(float)flag;

// Minimum font size settings
-(int)minimumFontSize;
-(BOOL)enableMinimumFontSize;
-(void)setMinimumFontSize:(int)newSize;
-(void)setEnableMinimumFontSize:(BOOL)flag;

// Refresh frequency
-(void)setRefreshFrequency:(int)newFrequency;
-(int)refreshFrequency;

// Current display style
-(NSString *)displayStyle;
-(void)setDisplayStyle:(NSString *)newStyle;

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
