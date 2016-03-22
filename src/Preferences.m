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
#import "Constants.h"
#import "Article.h"
#import "SearchMethod.h"
#import <Sparkle/Sparkle.h>

// Initial paths
NSString * MA_ApplicationSupportFolder = @"~/Library/Application Support/Vienna";
NSString * MA_ScriptsFolder = @"~/Library/Scripts/Applications/Vienna";
NSString * MA_EnclosureDownloadFolder = @"~/Desktop";
NSString * MA_DefaultDownloadsFolder = @"~/Desktop";
NSString * MA_DefaultStyleName = @"Default";
NSString * MA_Database_Name = @"messages.db";
NSString * MA_ImagesFolder_Name = @"Images";
NSString * MA_StylesFolder_Name = @"Styles";
NSString * MA_ScriptsFolder_Name = @"Scripts";
NSString * MA_PluginsFolder_Name = @"Plugins";
NSString * MA_FeedSourcesFolder_Name = @"Sources";

// NSNotificationCenter string constants
NSString * const kMA_Notify_MinimumFontSizeChange = @"MA_Notify_MinimumFontSizeChange";
NSString * const kMA_Notify_UseJavaScriptChange = @"MA_Notify_UseJavaScriptChange";
NSString * const kMA_Notify_UseWebPluginsChange = @"MA_Notify_UseWebPluginsChange";


// The default preferences object.
static Preferences * _standardPreferences = nil;

// Private methods
@interface Preferences (Private)
@property (nonatomic, readonly, copy) NSDictionary *allocFactoryDefaults;
-(void)createFeedSourcesFolderIfNecessary;
-(void)handleUpdateRestart:(NSNotification *)nc;
@end

@implementation Preferences

/* standardPreferences
 * Return the single set of Vienna wide preferences object.
 */
+(Preferences *)standardPreferences
{
	if (_standardPreferences == nil)
		_standardPreferences = [[Preferences alloc] init];
	return _standardPreferences;
}

/* init
 * The designated initialiser.
 */
-(instancetype)init
{
	if ((self = [super init]) != nil)
	{
		// Look to see where we're getting our preferences from. This is a command line
		// argument of the form:
		//
		//  -profile <name>
		//
		// where <name> is the name of the folder at the same level of the application.
		// If no profile is specified, is called "default" or is absent then we fall back
		// on the user profile.
		//
		NSArray * appArguments = [NSProcessInfo processInfo].arguments;
		NSEnumerator * enumerator = [appArguments objectEnumerator];
		NSString * argName;
		
		while ((argName = [enumerator nextObject]) != nil)
		{
			if ([argName.lowercaseString isEqualToString:@"-profile"])
			{
				NSString * argValue = [enumerator nextObject];
				if (argValue == nil || [argValue isEqualToString:@"default"])
					break;
				profilePath = argValue;
				break;
			}
		}
		
		// Look to see if there's a cached profile path from the updater
		if (profilePath == nil)
			profilePath = [[NSUserDefaults standardUserDefaults] stringForKey:MAPref_Profile_Path];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:MAPref_Profile_Path];
		
		// Merge in the user preferences from the defaults.
		NSDictionary * defaults = self.allocFactoryDefaults;
		if (profilePath == nil)
		{
			preferencesPath = nil;
			userPrefs = [NSUserDefaults standardUserDefaults];
			[userPrefs registerDefaults:defaults];
			
			// Application-specific folder locations
			defaultDatabase = [userPrefs valueForKey:MAPref_DefaultDatabase];
			imagesFolder = [MA_ApplicationSupportFolder stringByAppendingPathComponent:MA_ImagesFolder_Name].stringByExpandingTildeInPath;
			stylesFolder = [MA_ApplicationSupportFolder stringByAppendingPathComponent:MA_StylesFolder_Name].stringByExpandingTildeInPath;
			pluginsFolder = [MA_ApplicationSupportFolder stringByAppendingPathComponent:MA_PluginsFolder_Name].stringByExpandingTildeInPath;
			scriptsFolder = MA_ScriptsFolder.stringByExpandingTildeInPath;
			feedSourcesFolder = [MA_ApplicationSupportFolder stringByAppendingPathComponent:MA_FeedSourcesFolder_Name].stringByExpandingTildeInPath;
		}
		else
		{
			// Make sure profilePath exists and create it otherwise. A failure to create the profile
			// path counts as treating the profile as transient for this session.
			NSFileManager * fileManager = [NSFileManager defaultManager];
			BOOL isDir;
			
			if (![fileManager fileExistsAtPath:profilePath isDirectory:&isDir])
			{
				NSError * error;
				if (![fileManager createDirectoryAtPath:profilePath withIntermediateDirectories:YES attributes:NULL error:&error])
				{
					NSLog(@"Cannot create profile folder %@: %@", profilePath, error);
					profilePath = nil;
				}
			}
			
			// The preferences file is stored under the profile folder with the bundle identifier
			// name plus the .plist extension. (This is the same convention used by NSUserDefaults.)
			if (profilePath != nil)
			{
				NSDictionary * fileAttributes = [NSBundle mainBundle].infoDictionary;
				preferencesPath = [profilePath stringByAppendingPathComponent:fileAttributes[@"CFBundleIdentifier"]];
				preferencesPath = [preferencesPath stringByAppendingString:@".plist"];
			}
			userPrefs = [[NSMutableDictionary alloc] initWithDictionary:defaults];
			if (preferencesPath != nil)
				[userPrefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:preferencesPath]];
            
			// Other folders are local to the profilePath
			defaultDatabase = [profilePath stringByAppendingPathComponent:MA_Database_Name];
			imagesFolder = [profilePath stringByAppendingPathComponent:MA_ImagesFolder_Name].stringByExpandingTildeInPath;
			stylesFolder = [profilePath stringByAppendingPathComponent:MA_StylesFolder_Name].stringByExpandingTildeInPath;
			scriptsFolder = [profilePath stringByAppendingPathComponent:MA_ScriptsFolder_Name].stringByExpandingTildeInPath;
			pluginsFolder = [profilePath stringByAppendingPathComponent:MA_PluginsFolder_Name].stringByExpandingTildeInPath;
			feedSourcesFolder = [profilePath stringByAppendingPathComponent:MA_FeedSourcesFolder_Name].stringByExpandingTildeInPath;
		}
        
		
		// Load those settings that we cache.
		foldersTreeSortMethod = [self integerForKey:MAPref_AutoSortFoldersTree];
		articleSortDescriptors = [NSUnarchiver unarchiveObjectWithData:[userPrefs valueForKey:MAPref_ArticleSortDescriptors]];
		refreshFrequency = [self integerForKey:MAPref_CheckFrequency];
		filterMode = [self integerForKey:MAPref_FilterMode];
		layout = [self integerForKey:MAPref_Layout];
		refreshOnStartup = [self boolForKey:MAPref_CheckForNewArticlesOnStartup];
		markUpdatedAsNew = [self boolForKey:MAPref_CheckForUpdatedArticles];
		markReadInterval = [[userPrefs valueForKey:MAPref_MarkReadInterval] floatValue];
		minimumFontSize = [self integerForKey:MAPref_MinimumFontSize];
		newArticlesNotification = [self integerForKey:MAPref_NewArticlesNotification];
		enableMinimumFontSize = [self boolForKey:MAPref_UseMinimumFontSize];
		autoExpireDuration = [self integerForKey:MAPref_AutoExpireDuration];
		openLinksInVienna = [self boolForKey:MAPref_OpenLinksInVienna];
		openLinksInBackground = [self boolForKey:MAPref_OpenLinksInBackground];
		displayStyle = [userPrefs valueForKey:MAPref_ActiveStyleName];
		textSizeMultiplier = [[userPrefs valueForKey:MAPref_ActiveTextSizeMultiplier] doubleValue];
		showFolderImages = [self boolForKey:MAPref_ShowFolderImages];
		showStatusBar = [self boolForKey:MAPref_ShowStatusBar];
		showFilterBar = [self boolForKey:MAPref_ShowFilterBar];
		useJavaScript = [self boolForKey:MAPref_UseJavaScript];
        useWebPlugins = [self boolForKey:MAPref_UseWebPlugins];
		showAppInStatusBar = [self boolForKey:MAPref_ShowAppInStatusBar];
		folderFont = [NSUnarchiver unarchiveObjectWithData:[userPrefs objectForKey:MAPref_FolderFont]];
		articleFont = [NSUnarchiver unarchiveObjectWithData:[userPrefs objectForKey:MAPref_ArticleListFont]];
		downloadFolder = [userPrefs valueForKey:MAPref_DownloadsFolder];
		shouldSaveFeedSource = [self boolForKey:MAPref_ShouldSaveFeedSource];
		searchMethod = [NSKeyedUnarchiver unarchiveObjectWithData:[userPrefs objectForKey:MAPref_SearchMethod]];
		concurrentDownloads = [self integerForKey:MAPref_ConcurrentDownloads];
        
        // Open Reader sync
        syncGoogleReader = [self boolForKey:MAPref_SyncGoogleReader];
        prefersGoogleNewSubscription = [self boolForKey:MAPref_GoogleNewSubscription];
		syncServer = [userPrefs valueForKey:MAPref_SyncServer];
		syncingUser = [userPrefs valueForKey:MAPref_SyncingUser];
				
		//Sparkle autoupdate
		checkForNewOnStartup = [SUUpdater sharedUpdater].automaticallyChecksForUpdates;
        sendSystemSpecs = [SUUpdater sharedUpdater].sendsSystemProfile;
        alwaysAcceptBetas = [self boolForKey:MAPref_AlwaysAcceptBetas];

		if (shouldSaveFeedSource)
		{
			[self createFeedSourcesFolderIfNecessary];
		}
		
		// Here is where we want to put any logic that depends on the last or highest version of Vienna that has been run.
		NSString * bundleVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		if (bundleVersionString != nil)
		{
			NSInteger bundleVersion = bundleVersionString.integerValue;
			if (bundleVersion > 0)
			{
				if (bundleVersion > [self integerForKey:MAPref_HighestViennaVersionRun])
				{
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
	NSData * defaultArticleListFont = [NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"LucidaGrande" size:11.0]];
	NSData * defaultFolderFont = [NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"LucidaGrande" size:11.0]];
	NSData * defaultArticleSortDescriptors = [NSArchiver archivedDataWithRootObject:@[]];
	
	NSNumber * boolNo = @NO;
	NSNumber * boolYes = @YES;
	
	defaultValues[MAPref_DefaultDatabase] = [MA_ApplicationSupportFolder stringByAppendingPathComponent:MA_Database_Name];
	defaultValues[MAPref_CheckForUpdatedArticles] = boolNo;
	defaultValues[MAPref_ShowUnreadArticlesInBold] = boolYes;
	defaultValues[MAPref_ArticleListFont] = defaultArticleListFont;
	defaultValues[MAPref_FolderFont] = defaultFolderFont;
	defaultValues[MAPref_CheckForNewArticlesOnStartup] = boolYes;
	defaultValues[MAPref_CachedFolderID] = @1;
	defaultValues[MAPref_SortColumn] = MA_Field_Date;
	defaultValues[MAPref_CheckFrequency] = @(MA_Default_Check_Frequency);
	defaultValues[MAPref_MarkReadInterval] = @((float)MA_Default_Read_Interval);
	defaultValues[MAPref_RefreshThreads] = @(MA_Default_RefreshThreads);
	defaultValues[MAPref_ActiveStyleName] = MA_DefaultStyleName;
	defaultValues[MAPref_ActiveTextSizeMultiplier] = @1.0;
	defaultValues[MAPref_BacktrackQueueSize] = @(MA_Default_BackTrackQueueSize);
	defaultValues[MAPref_AutoSortFoldersTree] = @MA_FolderSort_ByName;
	defaultValues[MAPref_ShowFolderImages] = boolYes;
	defaultValues[MAPref_UseJavaScript] = boolYes;
    defaultValues[MAPref_UseWebPlugins] = boolYes;
	defaultValues[MAPref_OpenLinksInVienna] = boolYes;
	defaultValues[MAPref_OpenLinksInBackground] = boolYes;
	defaultValues[MAPref_ShowAppInStatusBar] = boolNo;
	defaultValues[MAPref_ShowStatusBar] = boolYes;
	defaultValues[MAPref_ShowFilterBar] = boolYes;
	defaultValues[MAPref_NewFolderUI] = boolNo;
	defaultValues[MAPref_UseMinimumFontSize] = boolNo;
	defaultValues[MAPref_FilterMode] = @MA_Filter_All;
	defaultValues[MAPref_MinimumFontSize] = @(MA_Default_MinimumFontSize);
	defaultValues[MAPref_AutoExpireDuration] = @(MA_Default_AutoExpireDuration);
	defaultValues[MAPref_DownloadsFolder] = MA_DefaultDownloadsFolder;
	defaultValues[MAPref_ArticleSortDescriptors] = defaultArticleSortDescriptors;
	defaultValues[MAPref_LastRefreshDate] = [NSDate distantPast];
	defaultValues[MAPref_Layout] = @MA_Layout_Report;
	defaultValues[MAPref_NewArticlesNotification] = @MA_NewArticlesNotification_Badge;
	defaultValues[MAPref_EmptyTrashNotification] = @MA_EmptyTrash_WithWarning;
	defaultValues[MAPref_HighestViennaVersionRun] = @0;
	defaultValues[MAPref_LastViennaVersionRun] = @0;
	defaultValues[MAPref_ShouldSaveFeedSource] = boolYes;
	defaultValues[MAPref_ShouldSaveFeedSourceBackup] = boolNo;
	defaultValues[MAPref_SearchMethod] = [NSKeyedArchiver archivedDataWithRootObject:[SearchMethod searchAllArticlesMethod]];
    defaultValues[MAPref_ConcurrentDownloads] = @(MA_Default_ConcurrentDownloads);
    defaultValues[MAPref_SyncGoogleReader] = boolNo;
    defaultValues[MAPref_GoogleNewSubscription] = boolNo;
    defaultValues[MAPref_AlwaysAcceptBetas] = boolNo;
	
	return [defaultValues copy];
}

/* savePreferences
 * Save the user preferences back to where we loaded them from.
 */
-(void)savePreferences
{
	if (preferencesPath == nil)
		[userPrefs synchronize];
	else
	{
		if (![userPrefs writeToFile:preferencesPath atomically:NO])
			NSLog(@"Failed to update preferences to %@", preferencesPath);
	}
}

/* setBool
 * Sets the value of the specified default to the given boolean value.
 */
-(void)setBool:(BOOL)value forKey:(NSString *)defaultName
{
	[userPrefs setObject:@(value) forKey:defaultName];
}

/* setInteger
 * Sets the value of the specified default to the given integer value.
 */
-(void)setInteger:(NSInteger)value forKey:(NSString *)defaultName
{
	[userPrefs setObject:@(value) forKey:defaultName];
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
	return [[userPrefs valueForKey:defaultName] boolValue];
}

/* integerForKey
 * Returns the integer value of the given default object.
 */
-(NSInteger)integerForKey:(NSString *)defaultName
{
	return [[userPrefs valueForKey:defaultName] integerValue];
}

/* stringForKey
 * Returns the string value of the given default object.
 */
-(NSString *)stringForKey:(NSString *)defaultName
{
	return [userPrefs valueForKey:defaultName];
}

/* arrayForKey
 * Returns the string value of the given default array.
 */
-(NSArray *)arrayForKey:(NSString *)defaultName
{
	return [userPrefs valueForKey:defaultName];
}

/* objectForKey
 * Returns the value of the given default object.
 */
-(id)objectForKey:(NSString *)defaultName
{
	return [userPrefs objectForKey:defaultName];
}

/* imagesFolder
 * Return the path to where the folder images are stored.
 */
-(NSString *)imagesFolder
{
	return imagesFolder;
}

/* pluginsFolder
 * Returns the path to where the user plugins are stored
 */
-(NSString *)pluginsFolder
{
	return pluginsFolder;
}

/* stylesFolder
 * Return the path to where the user styles are stored.
 */
-(NSString *)stylesFolder
{
	return stylesFolder;
}

/* scriptsFolder
 * Return the path to where the scripts are stored.
 */
-(NSString *)scriptsFolder
{
	return scriptsFolder;
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
	if (defaultDatabase != newDatabase)
	{
		defaultDatabase = newDatabase;
		[userPrefs setValue:newDatabase forKey:MAPref_DefaultDatabase];
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
	if (useJavaScript != flag)
	{
		useJavaScript = flag;
		[self setBool:flag forKey:MAPref_UseJavaScript];
		[[NSNotificationCenter defaultCenter] postNotificationName:kMA_Notify_UseJavaScriptChange
                                                            object:nil];
	}
}


/* useWebPlugins
 * Specifies whether or not to enable web plugins
 */
-(BOOL)useWebPlugins
{
    return useWebPlugins;
}

/* setEnableJavaScript
 * Enable whether JavaScript is used.
 */
-(void)setUseWebPlugins:(BOOL)flag
{
    if (useWebPlugins != flag)
    {
        useWebPlugins = flag;
        [self setBool:flag forKey:MAPref_UseWebPlugins];
        [[NSNotificationCenter defaultCenter] postNotificationName:kMA_Notify_UseWebPluginsChange
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
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_CowncurrentDownloadsChange" object:nil];

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
	if (newSize != minimumFontSize)
	{
		minimumFontSize = newSize;
		[self setInteger:minimumFontSize forKey:MAPref_MinimumFontSize];
		[[NSNotificationCenter defaultCenter] postNotificationName:kMA_Notify_MinimumFontSizeChange
                                                            object:nil];
	}
}

/* setEnableMinimumFontSize
 * Enable whether the minimum font size is used.
 */
-(void)setEnableMinimumFontSize:(BOOL)flag
{
	if (enableMinimumFontSize != flag)
	{
		enableMinimumFontSize = flag;
		[self setBool:flag forKey:MAPref_UseMinimumFontSize];
		[[NSNotificationCenter defaultCenter] postNotificationName:kMA_Notify_MinimumFontSizeChange
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
	if (showFolderImages != flag)
	{
		showFolderImages = flag;
		[self setBool:flag forKey:MAPref_ShowFolderImages];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ShowFolderImages" object:nil];
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
	if (newDuration != autoExpireDuration)
	{
		autoExpireDuration = newDuration;
		[self setInteger:newDuration forKey:MAPref_AutoExpireDuration];
	}
}

/* downloadFolder
 * Returns the path of the current download folder.
 */
-(NSString *)downloadFolder
{
	return downloadFolder;
}

/* setDownloadFolder
 * Sets the new download folder path.
 */
-(void)setDownloadFolder:(NSString *)newFolder
{
	if (![newFolder isEqualToString:downloadFolder])
	{
		downloadFolder = newFolder;
		[self setObject:downloadFolder forKey:MAPref_DownloadsFolder];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
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
	if (layout != newLayout)
	{
		layout = newLayout;
		[self setInteger:newLayout forKey:MAPref_Layout];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ReadingPaneChange" object:nil];
	}
}

/* setSearchMethod
 * Updates the current search method that the user has chosen from the search field menu.
 */
-(void)setSearchMethod:(SearchMethod *)newMethod
{
	searchMethod = newMethod;
	[self setObject:[NSKeyedArchiver archivedDataWithRootObject:newMethod] forKey:MAPref_SearchMethod];
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
	if (refreshFrequency != newFrequency)
	{
		refreshFrequency = newFrequency;
		[self setInteger:newFrequency forKey:MAPref_CheckFrequency];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_CheckFrequencyChange" object:nil];
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
	if (flag != refreshOnStartup)
	{
		refreshOnStartup = flag;
		[self setBool:flag forKey:MAPref_CheckForNewArticlesOnStartup];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
	}
}

/* checkForNewOnStartup
 * Returns whether or not Vienna checks for new versions when it starts.
 */
-(BOOL)checkForNewOnStartup
{
	return checkForNewOnStartup;
}

/* setCheckForNewOnStartup
 * Changes whether or not Vienna checks for new versions when it starts.
 */
-(void)setCheckForNewOnStartup:(BOOL)flag
{
	if (flag != checkForNewOnStartup)
	{
		checkForNewOnStartup = flag;
		[SUUpdater sharedUpdater].automaticallyChecksForUpdates = flag;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
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
	if (flag != alwaysAcceptBetas)
	{
		alwaysAcceptBetas = flag;
		[self setBool:flag forKey:MAPref_AlwaysAcceptBetas];
		if (flag)
		{
			[SUUpdater sharedUpdater].feedURL = [NSURL URLWithString:@"http://vienna-rss.org/spstats/changelog_beta.php"];
		}
		else
		{
			// restore the default as defined in Info.plist
			[[SUUpdater sharedUpdater] setFeedURL:nil];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
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
	if (newInterval != markReadInterval)
	{
		markReadInterval = newInterval;
		[self setObject:@((float)newInterval) forKey:MAPref_MarkReadInterval];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
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
	if (filterMode != newMode)
	{
		filterMode = newMode;
		[self setInteger:filterMode forKey:MAPref_FilterMode];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FilteringChange" object:nil];
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
	if (openLinksInVienna != flag)
	{
		openLinksInVienna = flag;
		[self setBool:flag forKey:MAPref_OpenLinksInVienna];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
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
	if (openLinksInBackground != flag)
	{
		openLinksInBackground = flag;
		[self setBool:flag forKey:MAPref_OpenLinksInBackground];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
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
	if (markUpdatedAsNew != flag)
	{
		markUpdatedAsNew = flag;
		[self setBool:flag forKey:MAPref_CheckForUpdatedArticles];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
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
	[self setDisplayStyle:newStyleName withNotification:YES];
}

/* setDisplayStyle
 * Changes the style used for displaying articles and optionally sends a notification.
 */
-(void)setDisplayStyle:(NSString *)newStyleName withNotification:(BOOL)flag
{
	if (![displayStyle isEqualToString:newStyleName])
	{
		displayStyle = newStyleName;
		[self setString:displayStyle forKey:MAPref_ActiveStyleName];
		if (flag)
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_StyleChange" object:nil];
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
	if (newValue != textSizeMultiplier)
	{
		textSizeMultiplier = newValue;
		[self setObject:@(newValue) forKey:MAPref_ActiveTextSizeMultiplier];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_StyleChange" object:nil];
	}
}

/* folderListFont
 * Retrieve the name of the font used in the folder list
 */
-(NSString *)folderListFont
{
	return folderFont.fontName;
}

/* folderListFontSize
 * Retrieve the size of the font used in the folder list
 */
-(NSInteger)folderListFontSize
{
	return folderFont.pointSize;
}

/* setFolderListFont
 * Retrieve the name of the font used in the folder list
 */
-(void)setFolderListFont:(NSString *)newFontName
{
	folderFont = [NSFont fontWithName:newFontName size:self.folderListFontSize];
	[self setObject:[NSArchiver archivedDataWithRootObject:folderFont] forKey:MAPref_FolderFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderFontChange" object:folderFont];
}

/* setFolderListFontSize
 * Changes the size of the font used in the folder list.
 */
-(void)setFolderListFontSize:(NSInteger)newFontSize
{
	folderFont = [NSFont fontWithName:self.folderListFont size:newFontSize];
	[self setObject:[NSArchiver archivedDataWithRootObject:folderFont] forKey:MAPref_FolderFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderFontChange" object:folderFont];
}

/* articleListFont
 * Retrieve the name of the font used in the article list
 */
-(NSString *)articleListFont
{
	return articleFont.fontName;
}

/* articleListFontSize
 * Retrieve the size of the font used in the article list
 */
-(NSInteger)articleListFontSize
{
	return articleFont.pointSize;
}

/* setArticleListFont
 * Retrieve the name of the font used in the article list
 */
-(void)setArticleListFont:(NSString *)newFontName
{
	articleFont = [NSFont fontWithName:newFontName size:self.articleListFontSize];
	[self setObject:[NSArchiver archivedDataWithRootObject:articleFont] forKey:MAPref_ArticleListFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListFontChange" object:articleFont];
}

/* setArticleListFontSize
 * Changes the size of the font used in the article list.
 */
-(void)setArticleListFontSize:(NSInteger)newFontSize
{
	articleFont = [NSFont fontWithName:self.articleListFont size:newFontSize];
	[self setObject:[NSArchiver archivedDataWithRootObject:articleFont] forKey:MAPref_ArticleListFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListFontChange" object:articleFont];
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
	if (![articleSortDescriptors isEqualToArray:newSortDescriptors])
	{
		NSArray * descriptors = [[NSArray alloc] initWithArray:newSortDescriptors];
		articleSortDescriptors = descriptors;
		[self setObject:[NSArchiver archivedDataWithRootObject:descriptors] forKey:MAPref_ArticleSortDescriptors];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
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
	if (foldersTreeSortMethod != newMethod)
	{
		foldersTreeSortMethod = newMethod;
		[self setInteger:newMethod forKey:MAPref_AutoSortFoldersTree];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_AutoSortFoldersTreeChange" object:nil];
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
	if (newMethod != newArticlesNotification)
	{
		newArticlesNotification = newMethod;
		[self setInteger:newArticlesNotification forKey:MAPref_NewArticlesNotification];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
	}
}

/* handleUpdateRestart
 * Called when Sparkle is about to restart Vienna.
 */
-(void)handleUpdateRestart
{
	[[NSUserDefaults standardUserDefaults] setObject:profilePath forKey:MAPref_Profile_Path];
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
	if (showAppInStatusBar != show)
	{
		showAppInStatusBar = show;
		[self setBool:showAppInStatusBar forKey:MAPref_ShowAppInStatusBar];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ShowAppInStatusBarChanged" object:nil];
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
	if (showStatusBar != show)
	{
		showStatusBar = show;
		[self setBool:showStatusBar forKey:MAPref_ShowStatusBar];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_StatusBarChanged" object:nil];
	}
}

/* showFilterBar
 * Returns whether the filter bar is shown or hidden.
 */
-(BOOL)showFilterBar
{
	return showFilterBar;
}

/* setShowFilterBar
 * Specifies whether the filter bar is shown or hidden.
 */
-(void)setShowFilterBar:(BOOL)show
{
	if (showFilterBar != show)
	{
		showFilterBar = show;
		[self setBool:showFilterBar forKey:MAPref_ShowFilterBar];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FilterBarChanged" object:nil];
	}
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
	if (shouldSaveFeedSource != shouldSave)
	{
		shouldSaveFeedSource = shouldSave;
		if (shouldSaveFeedSource)
		{
			[self createFeedSourcesFolderIfNecessary];
		}
		[self setBool:shouldSaveFeedSource forKey:MAPref_ShouldSaveFeedSource];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
	}
}

-(void)createFeedSourcesFolderIfNecessary
{	
	BOOL isDirectory = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:feedSourcesFolder isDirectory:&isDirectory])
	{
		NSError * error = nil;
		if (![[NSFileManager defaultManager] createDirectoryAtPath:feedSourcesFolder withIntermediateDirectories:YES attributes:nil error:&error])
		{
			NSLog(@"Could not create feed sources folder at path '%@'. Error: %@", feedSourcesFolder, error.localizedDescription);
		}
	}
	else if (!isDirectory)
	{
		// Huh, there's a Sources file there, but it's not a directory.
		NSLog(@"Could not create feed sources folder, because a non-directory file already exists at path '%@'.", feedSourcesFolder);
	}
}

/* sendSystemSpecs
 * Returns whether or not Vienna sends system specs when checking for updates.
 */
-(BOOL)sendSystemSpecs
{
    return sendSystemSpecs;
}

/* setCheckForNewOnStartup
 * Changes whether or not Vienna sends system specs when checking for updates.
 */
-(void)setSendSystemSpecs:(BOOL)flag
{
    if (flag != sendSystemSpecs)
    {
        sendSystemSpecs = flag;
        [SUUpdater sharedUpdater].sendsSystemProfile = flag;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
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
    if (syncGoogleReader != flag) 
    {
		syncGoogleReader = flag;
		[self setBool:syncGoogleReader forKey:MAPref_SyncGoogleReader];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_SyncGoogleReaderChange" object:nil];
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
	if (prefersGoogleNewSubscription != flag)
	{
		prefersGoogleNewSubscription = flag;
		[self setBool:prefersGoogleNewSubscription forKey:MAPref_GoogleNewSubscription];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_GoogleReaderNewSubscriptionChange" object:nil];
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
	if (![syncServer isEqualToString:newServer])
	{
		syncServer = newServer;
		[self setString:syncServer forKey:MAPref_SyncServer];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_SyncGoogleReaderChange" object:nil];
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
	if (![syncingUser isEqualToString:newUser])
	{
		syncingUser = newUser;
		[self setString:syncingUser forKey:MAPref_SyncingUser];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_SyncGoogleReaderChange" object:nil];
	}
}

@end
