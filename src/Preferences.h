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

@ class SearchMethod;

@interface Preferences : NSObject {
	id userPrefs;
	NSString * profilePath;
	NSString * preferencesPath;
	float markReadInterval;
	int minimumFontSize;
	int refreshFrequency;
	int autoExpireDuration;
	int filterMode;
	int layout;
	int newArticlesNotification;
	int foldersTreeSortMethod;
	BOOL refreshOnStartup;
	BOOL checkForNewOnStartup;
	BOOL enableMinimumFontSize;
	BOOL openLinksInVienna;
	BOOL openLinksInBackground;
	BOOL hasPrefs;
	BOOL showFolderImages;
	BOOL useJavaScript;
	BOOL showAppInStatusBar;
	BOOL showStatusBar;
	BOOL showFilterBar;
	BOOL shouldSaveFeedSource;
    BOOL syncGoogleReader;
    BOOL prefersGoogleNewSubscription;
	NSString * downloadFolder;
	NSString * displayStyle;
	NSString * defaultDatabase;
	NSString * imagesFolder;
	NSString * scriptsFolder;
	NSString * stylesFolder;
	NSString * pluginsFolder;
	NSString * feedSourcesFolder;
	NSFont * folderFont;
	NSFont * articleFont;
	NSArray * articleSortDescriptors;
	SearchMethod * searchMethod;
    NSDate * lastGoogleSyncDate;
	NSUInteger concurrentDownloads;
}

// Accessor functions
+(Preferences *)standardPreferences;
-(void)savePreferences;

// Accessor functions
-(BOOL)boolForKey:(NSString *)defaultName;
-(NSInteger)integerForKey:(NSString *)defaultName;
-(NSString *)stringForKey:(NSString *)defaultName;
-(NSArray *)arrayForKey:(NSString *)defaultName;
-(id)objectForKey:(NSString *)defaulName;
-(void)setBool:(BOOL)value forKey:(NSString *)defaultName;
-(void)setInteger:(NSInteger)value forKey:(NSString *)defaultName;
-(void)setString:(NSString *)value forKey:(NSString *)defaultName;
-(void)setArray:(NSArray *)value forKey:(NSString *)defaultName;
-(void)setObject:(id)value forKey:(NSString *)defaultName;

// Path to default database
-(NSString *)defaultDatabase;
-(void)setDefaultDatabase:(NSString *)newDatabase;

// Path to scripts folder
-(NSString *)scriptsFolder;

// Path to images folder
-(NSString *)imagesFolder;

// Path to styles folder
-(NSString *)stylesFolder;

// Path to the external plugins folder
-(NSString *)pluginsFolder;

// Read-only internal settings
-(int)backTrackQueueSize;

// Auto-expire values
-(int)autoExpireDuration;
-(void)setAutoExpireDuration:(int)newDuration;

// Download folder
-(NSString *)downloadFolder;
-(void)setDownloadFolder:(NSString *)newFolder;

// New articles notification method
-(int)newArticlesNotification;
-(void)setNewArticlesNotification:(int)newMethod;

// Mark read interval
-(float)markReadInterval;
-(void)setMarkReadInterval:(float)newInterval;

// Layout style
-(int)layout;
-(void)setLayout:(int)newLayout;

// Controls how articles are filtered in the view
-(int)filterMode;
-(void)setFilterMode:(int)newMode;

// Whether or not we show folder images
-(BOOL)showFolderImages;
-(void)setShowFolderImages:(BOOL)showImages;

// Refresh all subscriptions on startup
-(BOOL)refreshOnStartup;
-(void)setRefreshOnStartup:(BOOL)flag;

// Check for new versions of Vienna on startup
-(BOOL)checkForNewOnStartup;
-(void)setCheckForNewOnStartup:(BOOL)flag;

// Opening URL links in Vienna
-(BOOL)openLinksInVienna;
-(void)setOpenLinksInVienna:(BOOL)flag;

// Opening URL links in background
-(BOOL)openLinksInBackground;
-(void)setOpenLinksInBackground:(BOOL)flag;

// Minimum font size settings
-(int)minimumFontSize;
-(BOOL)enableMinimumFontSize;
-(void)setMinimumFontSize:(int)newSize;
-(void)setEnableMinimumFontSize:(BOOL)flag;

// JavaScript settings
-(BOOL)useJavaScript;
-(void)setUseJavaScript:(BOOL)flag;

// Refresh frequency
-(void)setRefreshFrequency:(int)newFrequency;
-(int)refreshFrequency;

// Current display style
-(NSString *)displayStyle;
-(void)setDisplayStyle:(NSString *)newStyle;
-(void)setDisplayStyle:(NSString *)newStyle withNotification:(BOOL)flag;

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

// Article list sort descriptors
-(NSArray *)articleSortDescriptors;
-(void)setArticleSortDescriptors:(NSArray *)newSortDescriptors;

// Automatically sort folders tree
-(int)foldersTreeSortMethod;
-(void)setFoldersTreeSortMethod:(int)newMethod;

// Do we show an icon in the status bar?
-(BOOL)showAppInStatusBar;
-(void)setShowAppInStatusBar:(BOOL)show;

// Handle update via Sparkle
-(void)handleUpdateRestart;

// Show or hide the status bar
-(BOOL)showStatusBar;
-(void)setShowStatusBar:(BOOL)show;

// Show or hide the filter bar
-(BOOL)showFilterBar;
-(void)setShowFilterBar:(BOOL)show;

// Should we save the raw feed source XML?
-(NSString *)feedSourcesFolder;
-(BOOL)shouldSaveFeedSource;
-(void)setShouldSaveFeedSource:(BOOL)shouldSave;

// Current search method
-(SearchMethod *)searchMethod;
-(void)setSearchMethod:(SearchMethod *)newMethod;

// Concurrent download settings
-(NSUInteger)concurrentDownloads;
-(void)setConcurrentDownloads:(NSUInteger)downloads;

#pragma mark -
#pragma mark Google reader syncing

-(BOOL)syncGoogleReader;
-(void)setSyncGoogleReader:(BOOL)flag;

-(BOOL)prefersGoogleNewSubscription;
-(void)setPrefersGoogleNewSubscription:(BOOL)flag;

@end