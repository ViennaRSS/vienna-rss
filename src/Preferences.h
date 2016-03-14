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
	NSInteger minimumFontSize;
	NSInteger refreshFrequency;
	NSInteger autoExpireDuration;
	NSInteger filterMode;
	NSInteger layout;
	NSInteger newArticlesNotification;
	NSInteger foldersTreeSortMethod;
	BOOL refreshOnStartup;
	BOOL checkForNewOnStartup;
	BOOL alwaysAcceptBetas;
	BOOL enableMinimumFontSize;
	BOOL openLinksInVienna;
	BOOL openLinksInBackground;
	BOOL hasPrefs;
	BOOL showFolderImages;
	BOOL useJavaScript;
    BOOL useWebPlugins;
	BOOL showAppInStatusBar;
	BOOL showStatusBar;
	BOOL showFilterBar;
	BOOL shouldSaveFeedSource;
    BOOL syncGoogleReader;
    BOOL prefersGoogleNewSubscription;
    BOOL markUpdatedAsNew;
    BOOL sendSystemSpecs;
	NSString * downloadFolder;
	NSString * displayStyle;
	CGFloat textSizeMultiplier;
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
	NSUInteger concurrentDownloads;
	NSString * syncServer;
	NSString * syncingUser;
}

// String constants for NSNotificationCenter
extern NSString * const kMA_Notify_MinimumFontSizeChange;
extern NSString * const kMA_Notify_UseJavaScriptChange;
extern NSString * const kMA_Notify_UseWebPluginsChange;

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
@property (nonatomic, readonly, copy) NSString *scriptsFolder;

// Path to images folder
@property (nonatomic, readonly, copy) NSString *imagesFolder;

// Path to styles folder
@property (nonatomic, readonly, copy) NSString *stylesFolder;

// Path to the external plugins folder
@property (nonatomic, readonly, copy) NSString *pluginsFolder;

// Read-only internal settings
@property (nonatomic, readonly) NSInteger backTrackQueueSize;

// Auto-expire values
@property (nonatomic) NSInteger autoExpireDuration;

// Download folder
@property (nonatomic, copy) NSString *downloadFolder;

// New articles notification method
@property (nonatomic) NSInteger newArticlesNotification;

// Mark read interval
@property (nonatomic) float markReadInterval;

// Layout style
@property (nonatomic) NSInteger layout;

// Controls how articles are filtered in the view
@property (nonatomic) NSInteger filterMode;

// Whether or not we show folder images
@property (nonatomic) BOOL showFolderImages;

// Refresh all subscriptions on startup
@property (nonatomic) BOOL refreshOnStartup;

// Check for new versions of Vienna on startup
@property (nonatomic) BOOL checkForNewOnStartup;

// When checking a newer version, always search for Betas versions
@property (nonatomic) BOOL alwaysAcceptBetas;

// Opening URL links in Vienna
@property (nonatomic) BOOL openLinksInVienna;

// Opening URL links in background
@property (nonatomic) BOOL openLinksInBackground;

// Minimum font size settings
@property (nonatomic) NSInteger minimumFontSize;
@property (nonatomic) BOOL enableMinimumFontSize;

// JavaScript settings
@property (nonatomic) BOOL useJavaScript;

// Web Plugins settings
@property (nonatomic) BOOL useWebPlugins;

// Refresh frequency
@property (nonatomic) NSInteger refreshFrequency;

// Current display style
@property (nonatomic, copy) NSString *displayStyle;
-(void)setDisplayStyle:(NSString *)newStyle withNotification:(BOOL)flag;
@property (nonatomic) CGFloat textSizeMultiplier;

// Folder list font
@property (nonatomic, copy) NSString *folderListFont;
@property (nonatomic) NSInteger folderListFontSize;

// Article list font
@property (nonatomic, copy) NSString *articleListFont;
@property (nonatomic) NSInteger articleListFontSize;

// Article list sort descriptors
@property (nonatomic, copy) NSArray *articleSortDescriptors;

// Automatically sort folders tree
@property (nonatomic) NSInteger foldersTreeSortMethod;

// Do we show an icon in the status bar?
@property (nonatomic) BOOL showAppInStatusBar;

// Handle update via Sparkle
-(void)handleUpdateRestart;

// Show or hide the status bar
@property (nonatomic) BOOL showStatusBar;

// Show or hide the filter bar
@property (nonatomic) BOOL showFilterBar;

// Should we save the raw feed source XML?
@property (nonatomic, readonly, copy) NSString *feedSourcesFolder;
@property (nonatomic) BOOL shouldSaveFeedSource;

// Current search method
@property (nonatomic, strong) SearchMethod *searchMethod;

// Concurrent download settings
@property (nonatomic) NSUInteger concurrentDownloads;

// Do we show updated articles as new ?
@property (nonatomic) BOOL markUpdatedAsNew;

// Do we send system specs when checking for updates?
@property (nonatomic) BOOL sendSystemSpecs;

#pragma mark -
#pragma mark Open Reader syncing

@property (nonatomic) BOOL syncGoogleReader;

@property (nonatomic) BOOL prefersGoogleNewSubscription;

// server used for syncing
@property (nonatomic, copy) NSString *syncServer;

// username used for syncing
@property (nonatomic, copy) NSString *syncingUser;
@end