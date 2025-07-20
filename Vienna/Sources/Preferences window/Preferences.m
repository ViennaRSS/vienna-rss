//
//  Preferences.m
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

#import "Preferences.h"

@import os.log;
@import Sparkle;

#import "Article.h"
#import "ArticleListConstants.h"
#import "Constants.h"
#import "DownloadItem.h"
#import "FeedListConstants.h"
#import "NSFileManager+Paths.h"
#import "NSKeyedUnarchiver+Compatibility.h"
#import "SearchMethod.h"
#import "StringExtensions.h"
#import "Vienna-Swift.h"

#define VNA_LOG os_log_create("--", "Preferences")

// Initial paths
static NSString * const MA_DefaultStyleName = @"Default";
static NSString * const MA_Database_Name = @"messages.db";
static NSString * const MA_FeedSourcesFolder_Name = @"Sources";

// Private methods
@interface Preferences ()

@property (readonly, nonatomic) NSDictionary *allocFactoryDefaults;

-(void)createFeedSourcesFolderIfNecessary;

@end

@implementation Preferences {
    NSUserDefaults *userPrefs;
    float markReadInterval;
    NSInteger minimumFontSize;
    NSInteger refreshFrequency;
    NSInteger autoExpireDuration;
    NSInteger filterMode;
    NSInteger layout;
    NSInteger newArticlesNotification;
    NSInteger foldersTreeSortMethod;
    BOOL refreshOnStartup;
    BOOL alwaysAcceptBetas;
    BOOL enableMinimumFontSize;
    BOOL openLinksInVienna;
    BOOL openLinksInBackground;
    BOOL hasPrefs;
    BOOL showFolderImages;
    BOOL useJavaScript;
    BOOL showAppInStatusBar;
    BOOL showStatusBar;
    BOOL shouldSaveFeedSource;
    BOOL syncGoogleReader;
    BOOL prefersGoogleNewSubscription;
    BOOL markUpdatedAsNew;
    NSString *displayStyle;
    CGFloat textSizeMultiplier;
    NSString *defaultDatabase;
    NSString *feedSourcesFolder;
    NSArray *articleSortDescriptors;
    SearchMethod *searchMethod;
    NSUInteger concurrentDownloads;
    NSString *syncServer;
    NSString *syncScheme;
    NSString *syncingUser;
}

/* standardPreferences
 * Return the single set of Vienna wide preferences object.
 */
+ (Preferences *)standardPreferences
{
    static Preferences *standardPreferences;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        standardPreferences = [Preferences new];
    });
    return standardPreferences;
}

/* init
 * The designated initialiser.
 */
-(instancetype)init
{
	if ((self = [super init]) != nil) {
		// Merge in the user preferences from the defaults.
		NSDictionary * defaults = self.allocFactoryDefaults;
		userPrefs = NSUserDefaults.standardUserDefaults;
		[self migrateEncodedPreferences];
		[userPrefs registerDefaults:defaults];

		// Application-specific folder locations
		defaultDatabase = [userPrefs stringForKey:MAPref_DefaultDatabase];
		NSFileManager *fileManager = NSFileManager.defaultManager;
		NSString *appSupportPath = fileManager.vna_applicationSupportDirectory.path;
		feedSourcesFolder = [appSupportPath stringByAppendingPathComponent:MA_FeedSourcesFolder_Name];
		
		// Load those settings that we cache.
		foldersTreeSortMethod = [self integerForKey:MAPref_AutoSortFoldersTree];
		refreshFrequency = [self integerForKey:MAPref_CheckFrequency];
		filterMode = [self integerForKey:MAPref_FilterMode];
		layout = [self integerForKey:MAPref_Layout];
		refreshOnStartup = [self boolForKey:MAPref_CheckForNewArticlesOnStartup];
		markUpdatedAsNew = [self boolForKey:MAPref_CheckForUpdatedArticles];
		markReadInterval = [userPrefs floatForKey:MAPref_MarkReadInterval];
		minimumFontSize = [self integerForKey:MAPref_MinimumFontSize];
		newArticlesNotification = [self integerForKey:MAPref_NewArticlesNotification];
		enableMinimumFontSize = [self boolForKey:MAPref_UseMinimumFontSize];
		autoExpireDuration = [self integerForKey:MAPref_AutoExpireDuration];
		openLinksInVienna = [self boolForKey:MAPref_OpenLinksInVienna];
		openLinksInBackground = [self boolForKey:MAPref_OpenLinksInBackground];
		displayStyle = [userPrefs stringForKey:MAPref_ActiveStyleName];
		textSizeMultiplier = [userPrefs doubleForKey:MAPref_ActiveTextSizeMultiplier];
		showFolderImages = [self boolForKey:MAPref_ShowFolderImages];
		showStatusBar = [self boolForKey:MAPref_ShowStatusBar];
		useJavaScript = [self boolForKey:MAPref_UseJavaScript];
		showAppInStatusBar = [self boolForKey:MAPref_ShowAppInStatusBar];
		shouldSaveFeedSource = [self boolForKey:MAPref_ShouldSaveFeedSource];
		concurrentDownloads = [self integerForKey:MAPref_ConcurrentDownloads];
        _userAgentName = [self stringForKey:MAPref_UserAgentName];

        // Archived objects
        searchMethod = [NSKeyedUnarchiver unarchivedObjectOfClass:[SearchMethod class]
                                                         fromData:[self objectForKey:MAPref_SearchMethod]
                                                            error:NULL];
        articleSortDescriptors = [NSKeyedUnarchiver vna_unarchivedArrayOfObjectsOfClass:[NSSortDescriptor class]
                                                                               fromData:[self objectForKey:MAPref_ArticleListSortOrders]];
        // Securely decoded sort descriptors must be explicitely set to allow
        // evaluation, otherwise an exception is thrown.
        for (NSSortDescriptor *descriptor in articleSortDescriptors) {
            [descriptor allowEvaluation];
        }
        
        // Open Reader sync
        syncGoogleReader = [self boolForKey:MAPref_SyncGoogleReader];
        prefersGoogleNewSubscription = [self boolForKey:MAPref_GoogleNewSubscription];
		syncServer = [userPrefs stringForKey:MAPref_SyncServer];
        syncScheme = [userPrefs stringForKey:MAPref_SyncScheme];
		syncingUser = [userPrefs stringForKey:MAPref_SyncingUser];
		_syncingAppId = [userPrefs stringForKey:MAPref_SyncingAppId];
		_syncingAppKey = [userPrefs stringForKey:MAPref_SyncingAppKey];
				
		//Sparkle autoupdate
        alwaysAcceptBetas = [self boolForKey:MAPref_AlwaysAcceptBetas];

		if (shouldSaveFeedSource) {
			[self createFeedSourcesFolderIfNecessary];
		}
		
		// Here is where we want to put any logic that depends on the last or highest version of Vienna that has been run.
		NSString * bundleVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		if (bundleVersionString != nil) {
			NSInteger bundleVersion = bundleVersionString.integerValue;
			if (bundleVersion > 0) {
				if (bundleVersion > [self integerForKey:MAPref_HighestViennaVersionRun]) {
					[self setInteger:bundleVersion forKey:MAPref_HighestViennaVersionRun];
				}
				[self setInteger:bundleVersion forKey:MAPref_LastViennaVersionRun];
			}
		}
	}
	return self;
}

/* dealloc
 * Clean up behind ourselves.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/* allocFactoryDefaults
 * The standard class initialization object.
 */
-(NSDictionary *)allocFactoryDefaults
{
	// Set the preference defaults
	NSMutableDictionary * defaultValues = [[NSMutableDictionary alloc] init];
    NSFont *defaultFont = [NSFont fontWithName:@"LucidaGrande" size:11.0];

	NSNumber * boolNo = @NO;
	NSNumber * boolYes = @YES;

	NSFileManager *fileManager = NSFileManager.defaultManager;
	NSString *appSupportPath = fileManager.vna_applicationSupportDirectory.path;
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:[@"articleData." stringByAppendingString:MA_Field_LastUpdate]
                                                                   ascending:YES];

	defaultValues[MAPref_DefaultDatabase] = [appSupportPath stringByAppendingPathComponent:MA_Database_Name];
	defaultValues[MAPref_CheckForUpdatedArticles] = boolNo;
	defaultValues[MAPref_ShowUnreadArticlesInBold] = boolYes;
	defaultValues[MAPref_CheckForNewArticlesOnStartup] = boolYes;
	defaultValues[MAPref_CachedFolderID] = @1;
	defaultValues[MAPref_SortColumn] = MA_Field_LastUpdate;
	defaultValues[MAPref_CheckFrequency] = @(MA_Default_Check_Frequency);
	defaultValues[MAPref_MarkReadInterval] = @((float)MA_Default_Read_Interval);
	defaultValues[MAPref_ActiveStyleName] = MA_DefaultStyleName;
	defaultValues[MAPref_ActiveTextSizeMultiplier] = @1.0;
	defaultValues[MAPref_BacktrackQueueSize] = @(MA_Default_BackTrackQueueSize);
	defaultValues[MAPref_AutoSortFoldersTree] = [NSNumber numberWithInt:VNAFolderSortManual];
	defaultValues[MAPref_ShowFolderImages] = boolYes;
	defaultValues[MAPref_UseJavaScript] = boolYes;
	defaultValues[MAPref_OpenLinksInVienna] = boolYes;
	defaultValues[MAPref_OpenLinksInBackground] = boolYes;
	defaultValues[MAPref_ShowAppInStatusBar] = boolNo;
	defaultValues[MAPref_ShowStatusBar] = boolYes;
	defaultValues[MAPref_ShowFilterBar] = boolYes;
	defaultValues[MAPref_UseMinimumFontSize] = boolNo;
	defaultValues[MAPref_FilterMode] = [NSNumber numberWithInt:VNAFilterAll];
	defaultValues[MAPref_MinimumFontSize] = @(MA_Default_MinimumFontSize);
	defaultValues[MAPref_AutoExpireDuration] = @(MA_Default_AutoExpireDuration);
	defaultValues[MAPref_Layout] = [NSNumber numberWithInt:VNALayoutReport];
	defaultValues[MAPref_NewArticlesNotification] = [NSNumber numberWithInt:0];
	defaultValues[MAPref_EmptyTrashNotification] = [NSNumber numberWithInt:VNAEmptyTrashWithWarning];
	defaultValues[MAPref_HighestViennaVersionRun] = @0;
	defaultValues[MAPref_LastViennaVersionRun] = @0;
	defaultValues[MAPref_ShouldSaveFeedSource] = boolYes;
	defaultValues[MAPref_ShouldSaveFeedSourceBackup] = boolNo;
    defaultValues[MAPref_ShowDetailsOnFeedCredentialsDialog] = boolNo;
    defaultValues[MAPref_ShowEnclosureBar] = boolYes;

    // Archives
    defaultValues[MAPref_ArticleListFont] = [NSKeyedArchiver archivedDataWithRootObject:defaultFont
                                                                  requiringSecureCoding:YES
                                                                                  error:NULL];
    defaultValues[MAPref_ArticleListSortOrders] = [NSKeyedArchiver archivedDataWithRootObject:@[sortDescriptor]
                                                                        requiringSecureCoding:YES
                                                                                        error:NULL];
    defaultValues[MAPref_SearchMethod] = [NSKeyedArchiver archivedDataWithRootObject:SearchMethod.allArticlesSearchMethod
                                                               requiringSecureCoding:YES
                                                                               error:NULL];

    defaultValues[MAPref_ConcurrentDownloads] = @(MA_Default_ConcurrentDownloads);
    defaultValues[MAPref_SyncGoogleReader] = boolNo;
    defaultValues[MAPref_GoogleNewSubscription] = boolNo;
    defaultValues[MAPref_SyncingAppId] = @"1000001359";
    defaultValues[MAPref_SyncingAppKey] = @"rAlfs2ELSuFxZJ5adJAW54qsNbUa45Qn";
    defaultValues[MAPref_AlwaysAcceptBetas] = boolNo;
    defaultValues[MAPref_UserAgentName] = @"Vienna";
    defaultValues[MAPref_UseRelativeDates] = boolYes;
    defaultValues[MAPref_FeedListSizeMode] = [NSNumber numberWithInteger:VNAFeedListSizeModeSmall];

	return [defaultValues copy];
}

- (void)migrateEncodedPreferences
{
    // Deprecated defaults keys. These were used in older versions of Vienna.
    NSString * const articleSortDescriptorsKey = @"ArticleSortDescriptors";
    NSString * const downloadsListKey = @"DownloadsList";
    NSString * const messageListFontKey = @"MessageListFont";
    NSString * const folderFontKey = @"FolderFont";
    NSString * const folderListFontKey = @"FolderListFont";

    if ([userPrefs objectForKey:articleSortDescriptorsKey]) {
        NSData *archive = [self objectForKey:articleSortDescriptorsKey];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSMutableArray *sortDescriptors = [[NSUnarchiver unarchiveObjectWithData:archive] mutableCopy];
#pragma clang diagnostic pop
        // Two sort descriptors have a selector that was renamed.
        [sortDescriptors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSSortDescriptor *descriptor = obj;
            if ([NSStringFromSelector(descriptor.selector) isEqualToString:@"numericCompare:"]) {
                descriptor = [NSSortDescriptor sortDescriptorWithKey:descriptor.key
                                                           ascending:descriptor.ascending
                                                            selector:@selector(vna_caseInsensitiveNumericCompare:)];
                [sortDescriptors replaceObjectAtIndex:idx
                                           withObject:descriptor];
            }
        }];
        NSData *keyedArchive = [NSKeyedArchiver archivedDataWithRootObject:[sortDescriptors copy]
                                                     requiringSecureCoding:YES
                                                                     error:NULL];
        [self setObject:keyedArchive forKey:MAPref_ArticleListSortOrders];
        [userPrefs removeObjectForKey:articleSortDescriptorsKey];
    }

    if ([userPrefs objectForKey:downloadsListKey]) {
        // Download items were stored as an array of non-keyed archives.
        NSArray *array = [self objectForKey:downloadsListKey];
        NSMutableArray *downloadItems = [NSMutableArray array];

        for (NSData *archive in array) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            DownloadItem *item = [NSUnarchiver unarchiveObjectWithData:archive];
#pragma clang diagnostic pop
            if (item) {
                [downloadItems addObject:item];
            } else {
                os_log_error(VNA_LOG, "Failed to unarchive download item using "
                             "unkeyed unarchiver. The item is skipped.");
            }
        }

        NSData *keyedArchive = [NSKeyedArchiver archivedDataWithRootObject:downloadItems
                                                     requiringSecureCoding:YES
                                                                     error:NULL];
        [self setObject:keyedArchive forKey:MAPref_DownloadItemList];
        [userPrefs removeObjectForKey:downloadsListKey];
    }

    if ([userPrefs objectForKey:messageListFontKey]) {
        NSData *archive = [self objectForKey:messageListFontKey];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSFont *font = [NSUnarchiver unarchiveObjectWithData:archive];
#pragma clang diagnostic pop
        NSData *keyedArchive = [NSKeyedArchiver archivedDataWithRootObject:font
                                                     requiringSecureCoding:YES
                                                                     error:NULL];
        [self setObject:keyedArchive forKey:MAPref_ArticleListFont];
        [userPrefs removeObjectForKey:messageListFontKey];
    }

    if ([userPrefs objectForKey:folderFontKey]) {
        NSData *archive = [self objectForKey:folderFontKey];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSFont *font = [NSUnarchiver unarchiveObjectWithData:archive];
#pragma clang diagnostic pop
        if (font && font.pointSize <= 11.0) {
            [userPrefs setInteger:VNAFeedListSizeModeTiny
                           forKey:MAPref_FeedListSizeMode];
        }
        [userPrefs removeObjectForKey:folderFontKey];
    }

    if ([userPrefs objectForKey:folderListFontKey]) {
        NSData *archive = [self objectForKey:folderListFontKey];
        NSFont *font = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSFont class]
                                                         fromData:archive
                                                            error:NULL];
        if (font && font.pointSize <= 11.0) {
            [userPrefs setInteger:VNAFeedListSizeModeTiny
                           forKey:MAPref_FeedListSizeMode];
        }
        [userPrefs removeObjectForKey:folderListFontKey];
    }
}

/* setBool
 * Sets the value of the specified default to the given boolean value.
 */
-(void)setBool:(BOOL)value forKey:(NSString *)defaultName
{
	[userPrefs setBool:value forKey:defaultName];
}

/* setInteger
 * Sets the value of the specified default to the given integer value.
 */
-(void)setInteger:(NSInteger)value forKey:(NSString *)defaultName
{
	[userPrefs setInteger:value forKey:defaultName];
}

/* setString
 * Sets the value of the specified default to the given string.
 */
-(void)setString:(NSString *)value forKey:(NSString *)defaultName
{
	[userPrefs setObject:value forKey:defaultName];
}

/* setArray
 * Sets the value of the specified default to the given array.
 */
-(void)setArray:(NSArray *)value forKey:(NSString *)defaultName
{
	[userPrefs setObject:value forKey:defaultName];
}

/* setObject
 * Sets the value of the specified default to the given object.
 */
-(void)setObject:(id)value forKey:(NSString *)defaultName
{
	[userPrefs setObject:value forKey:defaultName];
}

/* boolForKey
 * Returns the boolean value of the given default object.
 */
-(BOOL)boolForKey:(NSString *)defaultName
{
	return [userPrefs boolForKey:defaultName];
}

/* integerForKey
 * Returns the integer value of the given default object.
 */
-(NSInteger)integerForKey:(NSString *)defaultName
{
	return [userPrefs integerForKey:defaultName];
}

/* stringForKey
 * Returns the string value of the given default object.
 */
-(NSString *)stringForKey:(NSString *)defaultName
{
	return [userPrefs stringForKey:defaultName];
}

/* arrayForKey
 * Returns the string value of the given default array.
 */
-(NSArray *)arrayForKey:(NSString *)defaultName
{
	return [userPrefs arrayForKey:defaultName];
}

/* objectForKey
 * Returns the value of the given default object.
 */
-(id)objectForKey:(NSString *)defaultName
{
	return [userPrefs objectForKey:defaultName];
}

- (void)removeObjectForKey:(NSString *)defaultName {
    [userPrefs removeObjectForKey:defaultName];
}

/* defaultDatabase
 * Return the path to the default database. (This may not be fully qualified.)
 */
-(NSString *)defaultDatabase
{
	return defaultDatabase;
}

/* setDefaultDatabase
 * Change the path of the default database.
 */
-(void)setDefaultDatabase:(NSString *)newDatabase
{
	if (defaultDatabase != newDatabase) {
		defaultDatabase = newDatabase;
		[userPrefs setObject:newDatabase forKey:MAPref_DefaultDatabase];
	}
}

/* backTrackQueueSize
 * Returns the length of the back track queue.
 */
-(NSInteger)backTrackQueueSize
{
	return [self integerForKey:MAPref_BacktrackQueueSize];
}

/* enableMinimumFontSize
 * Specifies whether or not the minimum font size is in force.
 */
-(BOOL)enableMinimumFontSize
{
	return enableMinimumFontSize;
}

/* enableJavaScript
 * Specifies whether or not using JavaScript
 */
-(BOOL)useJavaScript
{
	return useJavaScript;
}

/* setEnableJavaScript
 * Enable whether JavaScript is used.
 */
-(void)setUseJavaScript:(BOOL)flag
{
	if (useJavaScript != flag) {
		useJavaScript = flag;
		[self setBool:flag forKey:MAPref_UseJavaScript];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_UseJavaScriptChange
                                                            object:nil];
	}
}

-(NSUInteger)concurrentDownloads {
	return concurrentDownloads;
}

-(void)setConcurrentDownloads:(NSUInteger)downloads {
	if (downloads != concurrentDownloads) {
		concurrentDownloads = downloads;
		[self setInteger:downloads forKey:MAPref_ConcurrentDownloads];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_ConcurrentDownloadsChange object:nil];

	}
}


/* minimumFontSize
 * Return the current minimum font size.
 */
-(NSInteger)minimumFontSize
{
	return minimumFontSize;
}

/* setMinimumFontSize
 * Change the minimum font size.
 */
-(void)setMinimumFontSize:(NSInteger)newSize
{
	if (newSize != minimumFontSize) {
		minimumFontSize = newSize;
		[self setInteger:minimumFontSize forKey:MAPref_MinimumFontSize];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_MinimumFontSizeChange
                                                            object:nil];
	}
}

/* setEnableMinimumFontSize
 * Enable whether the minimum font size is used.
 */
-(void)setEnableMinimumFontSize:(BOOL)flag
{
	if (enableMinimumFontSize != flag) {
		enableMinimumFontSize = flag;
		[self setBool:flag forKey:MAPref_UseMinimumFontSize];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_MinimumFontSizeChange
                                                            object:nil];
	}
}

/* showFolderImages
 * Returns whether or not the folder list shows the associated feed image.
 */
-(BOOL)showFolderImages
{
	return showFolderImages;
}

/* setShowFolderImages
 * Set whether or not the folder list shows the associated feed image.
 */
-(void)setShowFolderImages:(BOOL)flag
{
	if (showFolderImages != flag) {
		showFolderImages = flag;
		[self setBool:flag forKey:MAPref_ShowFolderImages];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_ShowFolderImages object:nil];
	}
}

/* autoExpireDuration
 * Returns the number of days worth of non-flagged articles to be preserved. Articles older than
 * this are automatically deleted. A value of 0 means never expire.
 */
-(NSInteger)autoExpireDuration
{
	return autoExpireDuration;
}

/* setAutoExpireDuration
 * Updates the number of days worth of non-flagged articles to be preserved. A zero value
 * disables auto-expire. Increments of 1000 specify months so 1000 = 1 month, 1001 = 1 month
 * and 1 day, etc.
 */
-(void)setAutoExpireDuration:(NSInteger)newDuration
{
	if (newDuration != autoExpireDuration) {
		autoExpireDuration = newDuration;
		[self setInteger:newDuration forKey:MAPref_AutoExpireDuration];
	}
}

/* layout
 * Returns the current layout.
 */
-(NSInteger)layout
{
	return layout;
}

/* setLayout
 * Changes the current layout.
 */
-(void)setLayout:(NSInteger)newLayout
{
	if (layout != newLayout) {
		layout = newLayout;
		[self setInteger:newLayout forKey:MAPref_Layout];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_ReadingPaneChange object:nil];
	}
}

/* setSearchMethod
 * Updates the current search method that the user has chosen from the search field menu.
 */
-(void)setSearchMethod:(SearchMethod *)newMethod
{
	searchMethod = newMethod;
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:searchMethod
                                            requiringSecureCoding:YES
                                                            error:NULL];
    [self setObject:archive forKey:MAPref_SearchMethod];
}

/* searchMethod
 * Updates the current search method that the user has chosen from the search field menu.
 */
-(SearchMethod *)searchMethod
{
	return searchMethod;
}



/* refreshFrequency
 * Return the frequency with which we refresh all subscriptions
 */
-(NSInteger)refreshFrequency
{
	return refreshFrequency;
}

/* setRefreshFrequency
 * Updates the refresh frequency and then updates the preferences.
 */
-(void)setRefreshFrequency:(NSInteger)newFrequency
{
	if (refreshFrequency != newFrequency) {
		refreshFrequency = newFrequency;
		[self setInteger:newFrequency forKey:MAPref_CheckFrequency];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_CheckFrequencyChange object:nil];
	}
}

/* refreshOnStartup
 * Returns whether or not Vienna refreshes all subscriptions when it starts.
 */
-(BOOL)refreshOnStartup
{
	return refreshOnStartup;
}

/* setRefreshOnStartup
 * Changes whether or not Vienna refreshes all subscriptions when it starts.
 */
-(void)setRefreshOnStartup:(BOOL)flag
{
	if (flag != refreshOnStartup) {
		refreshOnStartup = flag;
		[self setBool:flag forKey:MAPref_CheckForNewArticlesOnStartup];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_PreferenceChange object:nil];
	}
}

/* alwaysAcceptBetas
 * Returns whether when checking for new versions, we should always search for Betas versions
 */
-(BOOL)alwaysAcceptBetas
{
	return alwaysAcceptBetas;
}

/* setAlwaysAcceptBetas
 * Changes whether or not Vienna always checks for cutting edge Beta binaries.
 */
-(void)setAlwaysAcceptBetas:(BOOL)flag
{
	if (flag != alwaysAcceptBetas) {
		alwaysAcceptBetas = flag;
		[self setBool:flag forKey:MAPref_AlwaysAcceptBetas];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_PreferenceChange object:nil];
	}
}

/* markReadInterval
 * Return the number of seconds after an unread article is displayed before it is marked as read.
 * A value of zero means that it remains marked unread until the user does 'Display Next Unread'.
 */
-(float)markReadInterval
{
	return markReadInterval;
}

/* setMarkReadInterval
 * Changes the interval after an article is read before it is marked as read then sends a notification
 * that the preferences have changed.
 */
-(void)setMarkReadInterval:(float)newInterval
{
	if (newInterval != markReadInterval) {
		markReadInterval = newInterval;
		[self setObject:@((float)newInterval) forKey:MAPref_MarkReadInterval];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_PreferenceChange object:nil];
	}
}

/* filterMode
 * Returns the current filtering mode.
 */
-(NSInteger)filterMode
{
	return filterMode;
}

/* setFilterMode
 * Sets the new filtering mode for articles.
 */
-(void)setFilterMode:(NSInteger)newMode
{
	if (filterMode != newMode) {
		filterMode = newMode;
		[self setInteger:filterMode forKey:MAPref_FilterMode];
	}
}

/* openLinksInVienna
 * Returns whether or not URL links clicked in Vienna should be opened in Vienna's own browser or
 * in an the default external Browser (Safari or FireFox, etc).
 */
-(BOOL)openLinksInVienna
{
	return openLinksInVienna;
}

/* setOpenLinksInVienna
 * Changes whether or not links clicked in Vienna are opened in Vienna or the default system
 * browser, then sends a notification that the preferences have changed.
 */
-(void)setOpenLinksInVienna:(BOOL)flag
{
	if (openLinksInVienna != flag) {
		openLinksInVienna = flag;
		[self setBool:flag forKey:MAPref_OpenLinksInVienna];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_PreferenceChange object:nil];
	}
}

/* openLinksInBackground
 * Returns whether or not links clicked in Vienna are opened in the background.
 */
-(BOOL)openLinksInBackground
{
	return openLinksInBackground;
}

/* setOpenLinksInBackground
 * Changes whether or not links clicked in Vienna are opened in the background then sends a notification
 * that the preferences have changed.
 */
-(void)setOpenLinksInBackground:(BOOL)flag
{
	if (openLinksInBackground != flag) {
		openLinksInBackground = flag;
		[self setBool:flag forKey:MAPref_OpenLinksInBackground];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_PreferenceChange object:nil];
	}
}

/* markUpdatedAsNew
 * Returns whether or not updated articles are considered as new
 */
-(BOOL)markUpdatedAsNew
{
	return markUpdatedAsNew;
}

/* setMarkUpdatedAsNew
 * Changes whether or not updated articles are considered as new, then sends a notification
 * that the preferences have changed.
 */
-(void)setMarkUpdatedAsNew:(BOOL)flag
{
	if (markUpdatedAsNew != flag) {
		markUpdatedAsNew = flag;
		[self setBool:flag forKey:MAPref_CheckForUpdatedArticles];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_PreferenceChange object:nil];
	}
}

/* displayStyle
 * Retrieves the name of the current article display style.
 */
-(NSString *)displayStyle
{
	return displayStyle;
}

/* setDisplayStyle
 * Changes the style used for displaying articles
 */
-(void)setDisplayStyle:(NSString *)newStyleName
{
	[self setDisplayStyle:[newStyleName copy] withNotification:YES];
}

/* setDisplayStyle
 * Changes the style used for displaying articles and optionally sends a notification.
 */
-(void)setDisplayStyle:(NSString *)newStyleName withNotification:(BOOL)flag
{
	if (![displayStyle isEqualToString:newStyleName]) {
		displayStyle = newStyleName;
		[self setString:displayStyle forKey:MAPref_ActiveStyleName];
		if (flag) {
			[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_StyleChange object:nil];
		}
	}
}

/* textSizeMultiplier
 * Return the textSizeMultiplier to be applied to an ArticleView
 */
-(CGFloat)textSizeMultiplier
{
	return textSizeMultiplier;
}

/* setTextSizeMultiplier
 * Changes the textSizeMultiplier to be applied to an ArticleView
 */
-(void)setTextSizeMultiplier:(CGFloat)newValue
{
	if (newValue != textSizeMultiplier) {
		textSizeMultiplier = newValue;
		[self setObject:@(newValue) forKey:MAPref_ActiveTextSizeMultiplier];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_StyleChange object:nil];
	}
}

- (NSFont *)articleListFont
{
    NSData *archive = [self objectForKey:MAPref_ArticleListFont];
    NSFont *font = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSFont class]
                                                     fromData:archive
                                                        error:NULL];
    // If the unarchived data cannot be resolved to a font instance, the data
    // is likely corrupted and should be removed.
    if (!font) {
        [self removeObjectForKey:MAPref_ArticleListFont];
        // Load the archived data again, this time from registered defaults.
        NSData *registeredArchive = [self objectForKey:MAPref_ArticleListFont];
        font = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSFont class]
                                                 fromData:registeredArchive
                                                    error:NULL];
    }
    return font;
}

- (void)setArticleListFont:(NSFont *)articleListFont
{
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:articleListFont
                                            requiringSecureCoding:YES
                                                            error:NULL];
    [self setObject:archive forKey:MAPref_ArticleListFont];
    [NSNotificationCenter.defaultCenter postNotificationName:MA_Notify_ArticleListFontChange
                                                      object:articleListFont];
}

/* articleSortDescriptors
 * Return article sort descriptor array.
 */
-(NSArray *)articleSortDescriptors
{
	return articleSortDescriptors;
}

/* setArticleSortDescriptors
 * Change the article sort descriptor array.
 */
-(void)setArticleSortDescriptors:(NSArray *)newSortDescriptors
{
    if (!newSortDescriptors) {
        // Reset to registered default value.
        articleSortDescriptors = [NSKeyedUnarchiver vna_unarchivedArrayOfObjectsOfClass:[NSSortDescriptor class]
                                                                               fromData:[self objectForKey:MAPref_ArticleListSortOrders]];
        // Securely decoded sort descriptors must be explicitely set to allow
        // evaluation, otherwise an exception is thrown.
        for (NSSortDescriptor *descriptor in articleSortDescriptors) {
            [descriptor allowEvaluation];
        }
        return;
    }

	if (![articleSortDescriptors isEqualToArray:newSortDescriptors]) {
		articleSortDescriptors = [newSortDescriptors copy];
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:articleSortDescriptors
                                                requiringSecureCoding:YES
                                                                error:NULL];
        [self setObject:archive forKey:MAPref_ArticleListSortOrders];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_PreferenceChange object:nil];
	}
}

/* foldersTreeSortMethod
 * Returns the method by which the folders tree is sorted. See MA_FolderSort_xxx for the possible values.
 */
-(NSInteger)foldersTreeSortMethod
{
	return foldersTreeSortMethod;
}

/* setFoldersTreeSortMethod
 * Sets the method by which the folders tree is sorted.
 */
-(void)setFoldersTreeSortMethod:(NSInteger)newMethod
{
	if (foldersTreeSortMethod != newMethod) {
		foldersTreeSortMethod = newMethod;
		[self setInteger:newMethod forKey:MAPref_AutoSortFoldersTree];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_AutoSortFoldersTreeChange object:nil];
	}
}

/* newArticlesNotification
 * Returns the current method by which Vienna indicates new articles are available.
 */
-(NSInteger)newArticlesNotification
{
	return newArticlesNotification;
}

/* setNewArticlesNotification
 * Sets the method by which Vienna indicates new articles are available.
 */
-(void)setNewArticlesNotification:(NSInteger)newMethod
{
	if (newMethod != newArticlesNotification) {
		newArticlesNotification = newMethod;
		[self setInteger:newArticlesNotification forKey:MAPref_NewArticlesNotification];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_PreferenceChange object:nil];
	}
}

/* showAppInStatusBar
 * Returns whether Vienna shows an icon in the status bar.
 */
-(BOOL)showAppInStatusBar
{
	return showAppInStatusBar;
}

/* setShowAppInStatusBar
 * Specifies whether Vienna shows an icon in the status bar.
 */
-(void)setShowAppInStatusBar:(BOOL)show
{
	if (showAppInStatusBar != show) {
		showAppInStatusBar = show;
		[self setBool:showAppInStatusBar forKey:MAPref_ShowAppInStatusBar];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_ShowAppInStatusBarChanged object:nil];
	}
}

/* showStatusBar
 * Returns whether the status bar is shown or hidden.
 */
-(BOOL)showStatusBar
{
	return showStatusBar;
}

/* setShowStatusBar
 * Specifies whether the status bar is shown or hidden.
 */
-(void)setShowStatusBar:(BOOL)show
{
	if (showStatusBar != show) {
		showStatusBar = show;
		[self setBool:showStatusBar forKey:MAPref_ShowStatusBar];
	}
}

/* showFilterBar
 * Returns whether the filter bar is shown or hidden.
 */
-(BOOL)showFilterBar
{
    return [self boolForKey:MAPref_ShowFilterBar];
}

/* setShowFilterBar
 * Specifies whether the filter bar is shown or hidden.
 */
-(void)setShowFilterBar:(BOOL)showFilterBar
{
    [self setBool:showFilterBar forKey:MAPref_ShowFilterBar];
}

/* feedSourcesFolder
 * Return the path to where the raw feed sources are stored.
 */
-(NSString *)feedSourcesFolder
{
	return feedSourcesFolder;
}

/* shouldSaveFeedSource
 * Returns whether to save  the raw feed source XML.
 */
-(BOOL)shouldSaveFeedSource
{
	return shouldSaveFeedSource;
}

/* setShouldSaveFeedSource
 * Specifies whether to save  the raw feed source XML.
 */
-(void)setShouldSaveFeedSource:(BOOL)shouldSave
{
	if (shouldSaveFeedSource != shouldSave) {
		shouldSaveFeedSource = shouldSave;
		if (shouldSaveFeedSource) {
			[self createFeedSourcesFolderIfNecessary];
		}
		[self setBool:shouldSaveFeedSource forKey:MAPref_ShouldSaveFeedSource];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_PreferenceChange object:nil];
	}
}

-(void)createFeedSourcesFolderIfNecessary
{	
	BOOL isDirectory = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:feedSourcesFolder isDirectory:&isDirectory]) {
		NSError * error = nil;
		if (![[NSFileManager defaultManager] createDirectoryAtPath:feedSourcesFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
			NSLog(@"Could not create feed sources folder at path '%@'. Error: %@", feedSourcesFolder, error.localizedDescription);
		}
	} else if (!isDirectory) {
		// Huh, there's a Sources file there, but it's not a directory.
		NSLog(@"Could not create feed sources folder, because a non-directory file already exists at path '%@'.", feedSourcesFolder);
	}
}

#pragma mark -
#pragma mark Open Reader syncing

-(BOOL)syncGoogleReader 
{
    return syncGoogleReader;
}

-(void)setSyncGoogleReader:(BOOL)flag 
{
    if (syncGoogleReader != flag) {
		syncGoogleReader = flag;
		[self setBool:syncGoogleReader forKey:MAPref_SyncGoogleReader];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_SyncGoogleReaderChange object:nil];
	}
}

/* Getter/setters for prefersGoogleNewSubscription
 * Specifies whether Vienna defaults to Open Reader when entering a new subscription
 */
-(BOOL)prefersGoogleNewSubscription
{
    return prefersGoogleNewSubscription;
}

-(void)setPrefersGoogleNewSubscription:(BOOL)flag
{
	if (prefersGoogleNewSubscription != flag) {
		prefersGoogleNewSubscription = flag;
		[self setBool:prefersGoogleNewSubscription forKey:MAPref_GoogleNewSubscription];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_GoogleReaderNewSubscriptionChange object:nil];
	}
}

-(NSString *)syncServer
{
	return syncServer;
}

/* setSyncServer
 * Changes the server used for synchronization and sends a notification
 */
-(void)setSyncServer:(NSString *)newServer
{
	if (![syncServer isEqualToString:newServer]) {
		syncServer = [newServer copy];
		[self setString:syncServer forKey:MAPref_SyncServer];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_SyncGoogleReaderChange object:nil];
	}
}

-(NSString *)syncScheme
{
    return syncScheme;
}

/* setSyncServer
 * Changes the scheme used for synchronization and sends a notification
 */
-(void)setSyncScheme:(NSString *)newScheme
{
    if (![syncScheme isEqualToString:newScheme]) {
        syncScheme = [newScheme copy];
        [self setString:syncScheme forKey:MAPref_SyncScheme];
        [[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_SyncGoogleReaderChange object:nil];
    }
}

-(NSString *)syncingUser
{
	return syncingUser;
}

/* setSyncingUser
 * Changes the user name used for synchronization and sends a notification
 */
-(void)setSyncingUser:(NSString *)newUser
{
	if (![syncingUser isEqualToString:newUser]) {
		syncingUser = [newUser copy];
		[self setString:syncingUser forKey:MAPref_SyncingUser];
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_SyncGoogleReaderChange object:nil];
	}
}

@end
