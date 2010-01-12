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
#import "Message.h"
#import <Sparkle/Sparkle.h>

// Initial paths
NSString * MA_ApplicationSupportFolder = @"~/Library/Application Support/Vienna";
NSString * MA_ScriptsFolder = @"~/Library/Scripts/Applications/Vienna";
NSString * MA_EnclosureDownloadFolder = @"~/Desktop";
NSString * MA_DefaultDownloadsFolder = @"~/Desktop";
NSString * MA_DefaultStyleName = @"FeedLight Aqua (Default)";
NSString * MA_Database_Name = @"messages.db";
NSString * MA_ImagesFolder_Name = @"Images";
NSString * MA_StylesFolder_Name = @"Styles";
NSString * MA_ScriptsFolder_Name = @"Scripts";
NSString * MA_PluginsFolder_Name = @"Plugins";
NSString * MA_FeedSourcesFolder_Name = @"Sources";

// The default preferences object.
static Preferences * _standardPreferences = nil;

// Private methods
@interface Preferences (Private)
	-(NSDictionary *)factoryDefaults;
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
-(id)init
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
		NSArray * appArguments = [[NSProcessInfo processInfo] arguments];
		NSEnumerator * enumerator = [appArguments objectEnumerator];
		NSString * argName;

		while ((argName = [enumerator nextObject]) != nil)
		{
			if ([[argName lowercaseString] isEqualToString:@"-profile"])
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
		NSDictionary * defaults = [self factoryDefaults];
		if (profilePath == nil)
		{
			preferencesPath = nil;
			userPrefs = [NSUserDefaults standardUserDefaults];
			[userPrefs registerDefaults:defaults];

			// Application-specific folder locations
			defaultDatabase = [[userPrefs valueForKey:MAPref_DefaultDatabase] retain];
			imagesFolder = [[[MA_ApplicationSupportFolder stringByAppendingPathComponent:MA_ImagesFolder_Name] stringByExpandingTildeInPath] retain];
			stylesFolder = [[[MA_ApplicationSupportFolder stringByAppendingPathComponent:MA_StylesFolder_Name] stringByExpandingTildeInPath] retain];
			pluginsFolder = [[[MA_ApplicationSupportFolder stringByAppendingPathComponent:MA_PluginsFolder_Name] stringByExpandingTildeInPath] retain];
			scriptsFolder = [[MA_ScriptsFolder stringByExpandingTildeInPath] retain];
			feedSourcesFolder = [[[MA_ApplicationSupportFolder stringByAppendingPathComponent:MA_FeedSourcesFolder_Name] stringByExpandingTildeInPath] retain];
		}
		else
		{
			// Make sure profilePath exists and create it otherwise. A failure to create the profile
			// path counts as treating the profile as transient for this session.
			NSFileManager * fileManager = [NSFileManager defaultManager];
			BOOL isDir;

			if (![fileManager fileExistsAtPath:profilePath isDirectory:&isDir])
			{
				if (![fileManager createDirectoryAtPath:profilePath attributes:NULL])
				{
					NSLog(@"Cannot create profile folder %@", profilePath);
					profilePath = nil;
				}
			}

			// The preferences file is stored under the profile folder with the bundle identifier
			// name plus the .plist extension. (This is the same convention used by NSUserDefaults.)
			if (profilePath != nil)
			{
				[profilePath retain];
				NSDictionary * fileAttributes = [[NSBundle mainBundle] infoDictionary];
				preferencesPath = [profilePath stringByAppendingPathComponent:[fileAttributes objectForKey:@"CFBundleIdentifier"]];
				preferencesPath = [[preferencesPath stringByAppendingString:@".plist"] retain];
			}
			userPrefs = [[NSMutableDictionary alloc] initWithDictionary:defaults];
			if (preferencesPath != nil)
				[userPrefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:preferencesPath]];
			
			// Other folders are local to the profilePath
			defaultDatabase = [[profilePath stringByAppendingPathComponent:MA_Database_Name] retain];
			imagesFolder = [[[profilePath stringByAppendingPathComponent:MA_ImagesFolder_Name] stringByExpandingTildeInPath] retain];
			stylesFolder = [[[profilePath stringByAppendingPathComponent:MA_StylesFolder_Name] stringByExpandingTildeInPath] retain];
			scriptsFolder = [[[profilePath stringByAppendingPathComponent:MA_ScriptsFolder_Name] stringByExpandingTildeInPath] retain];
			pluginsFolder = [[[profilePath stringByAppendingPathComponent:MA_PluginsFolder_Name] stringByExpandingTildeInPath] retain];
			feedSourcesFolder = [[[profilePath stringByAppendingPathComponent:MA_FeedSourcesFolder_Name] stringByExpandingTildeInPath] retain];
		}
		
		// Register to be notified when Sparkle does an update.
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleUpdateRestart:) name:SUUpdaterWillRestartNotification object:nil];		

		// Load those settings that we cache.
		foldersTreeSortMethod = [self integerForKey:MAPref_AutoSortFoldersTree];
		articleSortDescriptors = [[NSUnarchiver unarchiveObjectWithData:[userPrefs valueForKey:MAPref_ArticleSortDescriptors]] retain];
		refreshFrequency = [self integerForKey:MAPref_CheckFrequency];
		filterMode = [self integerForKey:MAPref_FilterMode];
		layout = [self integerForKey:MAPref_Layout];
		refreshOnStartup = [self boolForKey:MAPref_CheckForNewArticlesOnStartup];
		checkForNewOnStartup = [self boolForKey:MAPref_CheckForUpdatesOnStartup];
		markReadInterval = [[userPrefs valueForKey:MAPref_MarkReadInterval] floatValue];
		minimumFontSize = [self integerForKey:MAPref_MinimumFontSize];
		newArticlesNotification = [self integerForKey:MAPref_NewArticlesNotification];
		enableMinimumFontSize = [self boolForKey:MAPref_UseMinimumFontSize];
		autoExpireDuration = [self integerForKey:MAPref_AutoExpireDuration];
		openLinksInVienna = [self boolForKey:MAPref_OpenLinksInVienna];
		openLinksInBackground = [self boolForKey:MAPref_OpenLinksInBackground];
		displayStyle = [[userPrefs valueForKey:MAPref_ActiveStyleName] retain];
		showFolderImages = [self boolForKey:MAPref_ShowFolderImages];
		showStatusBar = [self boolForKey:MAPref_ShowStatusBar];
		showFilterBar = [self boolForKey:MAPref_ShowFilterBar];
		useJavaScript = [self boolForKey:MAPref_UseJavaScript];
		showAppInStatusBar = [self boolForKey:MAPref_ShowAppInStatusBar];
		folderFont = [[NSUnarchiver unarchiveObjectWithData:[userPrefs objectForKey:MAPref_FolderFont]] retain];
		articleFont = [[NSUnarchiver unarchiveObjectWithData:[userPrefs objectForKey:MAPref_ArticleListFont]] retain];
		downloadFolder = [[userPrefs valueForKey:MAPref_DownloadsFolder] retain];
		shouldSaveFeedSource = [self boolForKey:MAPref_ShouldSaveFeedSource];
		
		if (shouldSaveFeedSource)
		{
			[self createFeedSourcesFolderIfNecessary];
		}
		
		// Here is where we want to put any logic that depends on the last or highest version of Vienna that has been run.
		NSString * bundleVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		if (bundleVersionString != nil)
		{
			int bundleVersion = [bundleVersionString intValue];
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
	[defaultDatabase release];
	[imagesFolder release];
	[downloadFolder release];
	[folderFont release];
	[articleFont release];
	[displayStyle release];
	[preferencesPath release];
	[articleSortDescriptors release];
	[profilePath release];
	[feedSourcesFolder release];
	[super dealloc];
}

/* factoryDefaults
 * The standard class initialization object.
 */
-(NSDictionary *)factoryDefaults
{
	// Set the preference defaults
	NSMutableDictionary * defaultValues = [NSMutableDictionary dictionary];
	NSData * defaultArticleListFont = [NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"LucidaGrande" size:11.0]];
	NSData * defaultFolderFont = [NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"LucidaGrande" size:11.0]];
	NSData * defaultArticleSortDescriptors = [NSArchiver archivedDataWithRootObject:[NSArray array]];
	
	NSNumber * boolNo = [NSNumber numberWithBool:NO];
	NSNumber * boolYes = [NSNumber numberWithBool:YES];

	[defaultValues setObject:[MA_ApplicationSupportFolder stringByAppendingPathComponent:MA_Database_Name] forKey:MAPref_DefaultDatabase];
	[defaultValues setObject:boolNo forKey:MAPref_CheckForUpdatedArticles];
	[defaultValues setObject:boolYes forKey:MAPref_ShowUnreadArticlesInBold];
	[defaultValues setObject:defaultArticleListFont forKey:MAPref_ArticleListFont];
	[defaultValues setObject:defaultFolderFont forKey:MAPref_FolderFont];
	[defaultValues setObject:boolYes forKey:MAPref_CheckForUpdatesOnStartup];
	[defaultValues setObject:boolYes forKey:MAPref_CheckForNewArticlesOnStartup];
	[defaultValues setObject:[NSNumber numberWithInt:1] forKey:MAPref_CachedFolderID];
	[defaultValues setObject:MA_Field_Date forKey:MAPref_SortColumn];
	[defaultValues setObject:[NSNumber numberWithInt:MA_Default_Check_Frequency] forKey:MAPref_CheckFrequency];
	[defaultValues setObject:[NSNumber numberWithFloat:MA_Default_Read_Interval] forKey:MAPref_MarkReadInterval];
	[defaultValues setObject:[NSNumber numberWithInt:MA_Default_RefreshThreads] forKey:MAPref_RefreshThreads];
	[defaultValues setObject:[NSArray arrayWithObjects:nil] forKey:MAPref_ArticleListColumns];
	[defaultValues setObject:MA_DefaultStyleName forKey:MAPref_ActiveStyleName];
	[defaultValues setObject:[NSNumber numberWithInt:MA_Default_BackTrackQueueSize] forKey:MAPref_BacktrackQueueSize];
	[defaultValues setObject:[NSNumber numberWithInt:MA_FolderSort_Manual] forKey:MAPref_AutoSortFoldersTree];
	[defaultValues setObject:boolYes forKey:MAPref_ShowFolderImages];
	[defaultValues setObject:boolYes forKey:MAPref_UseJavaScript];
	[defaultValues setObject:boolYes forKey:MAPref_OpenLinksInVienna];
	[defaultValues setObject:boolNo forKey:MAPref_OpenLinksInBackground];
	[defaultValues setObject:boolNo forKey:MAPref_ShowAppInStatusBar];
	[defaultValues setObject:boolYes forKey:MAPref_ShowStatusBar];
	[defaultValues setObject:boolYes forKey:MAPref_ShowFilterBar];
	[defaultValues setObject:boolNo forKey:MAPref_NewFolderUI];
	[defaultValues setObject:boolNo forKey:MAPref_UseMinimumFontSize];
	[defaultValues setObject:[NSNumber numberWithInt:MA_Filter_All] forKey:MAPref_FilterMode];
	[defaultValues setObject:[NSNumber numberWithInt:MA_Default_MinimumFontSize] forKey:MAPref_MinimumFontSize];
	[defaultValues setObject:[NSNumber numberWithInt:MA_Default_AutoExpireDuration] forKey:MAPref_AutoExpireDuration];
	[defaultValues setObject:MA_DefaultDownloadsFolder forKey:MAPref_DownloadsFolder];
	[defaultValues setObject:defaultArticleSortDescriptors forKey:MAPref_ArticleSortDescriptors];
	[defaultValues setObject:[NSDate distantPast] forKey:MAPref_LastRefreshDate];
	[defaultValues setObject:[NSNumber numberWithInt:MA_Layout_Report] forKey:MAPref_Layout];
	[defaultValues setObject:[NSNumber numberWithInt:MA_NewArticlesNotification_Badge] forKey:MAPref_NewArticlesNotification];
	[defaultValues setObject:[NSNumber numberWithInt:MA_EmptyTrash_WithWarning] forKey:MAPref_EmptyTrashNotification];
	[defaultValues setObject:[NSNumber numberWithInt:0] forKey:MAPref_HighestViennaVersionRun];
	[defaultValues setObject:[NSNumber numberWithInt:0] forKey:MAPref_LastViennaVersionRun];
	[defaultValues setObject:boolYes forKey:MAPref_ShouldSaveFeedSource];
	[defaultValues setObject:boolNo forKey:MAPref_ShouldSaveFeedSourceBackup];

	return defaultValues;
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
	[userPrefs setObject:[NSNumber numberWithBool:value] forKey:defaultName];
}

/* setInteger
 * Sets the value of the specified default to the given integer value.
 */
-(void)setInteger:(int)value forKey:(NSString *)defaultName
{
	[userPrefs setObject:[NSNumber numberWithInt:value] forKey:defaultName];
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
-(int)integerForKey:(NSString *)defaultName
{
	return [[userPrefs valueForKey:defaultName] intValue];
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
		[defaultDatabase release];
		defaultDatabase = [newDatabase retain];
		[userPrefs setValue:newDatabase forKey:MAPref_DefaultDatabase];
	}
}

/* backTrackQueueSize
 * Returns the length of the back track queue.
 */
-(int)backTrackQueueSize
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
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_UseJavaScriptChange" object:nil];
	}
}

/* minimumFontSize
 * Return the current minimum font size.
 */
-(int)minimumFontSize
{
	return minimumFontSize;
}

/* setMinimumFontSize
 * Change the minimum font size.
 */
-(void)setMinimumFontSize:(int)newSize
{
	if (newSize != minimumFontSize)
	{
		minimumFontSize = newSize;
		[self setInteger:minimumFontSize forKey:MAPref_MinimumFontSize];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_MinimumFontSizeChange" object:nil];
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
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_MinimumFontSizeChange" object:nil];
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
-(int)autoExpireDuration
{
	return autoExpireDuration;
}

/* setAutoExpireDuration
 * Updates the number of days worth of non-flagged articles to be preserved. A zero value
 * disables auto-expire. Increments of 1000 specify months so 1000 = 1 month, 1001 = 1 month
 * and 1 day, etc.
 */
-(void)setAutoExpireDuration:(int)newDuration
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
		[newFolder retain];
		[downloadFolder release];
		downloadFolder = newFolder;
		[self setObject:downloadFolder forKey:MAPref_DownloadsFolder];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
	}
}

/* layout
 * Returns the current layout.
 */
-(int)layout
{
	return layout;
}

/* setLayout
 * Changes the current layout.
 */
-(void)setLayout:(int)newLayout
{
	if (layout != newLayout)
	{
		layout = newLayout;
		[self setInteger:newLayout forKey:MAPref_Layout];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ReadingPaneChange" object:nil];
	}
}

/* refreshFrequency
 * Return the frequency with which we refresh all subscriptions
 */
-(int)refreshFrequency
{
	return refreshFrequency;
}

/* setRefreshFrequency
 * Updates the refresh frequency and then updates the preferences.
 */
-(void)setRefreshFrequency:(int)newFrequency
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
		[self setBool:flag forKey:MAPref_CheckForUpdatesOnStartup];
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
		[self setObject:[NSNumber numberWithFloat:newInterval] forKey:MAPref_MarkReadInterval];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
	}
}

/* filterMode
 * Returns the current filtering mode.
 */
-(int)filterMode
{
	return filterMode;
}

/* setFilterMode
 * Sets the new filtering mode for articles.
 */
-(void)setFilterMode:(int)newMode
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
		[newStyleName retain];
		[displayStyle release];
		displayStyle = newStyleName;
		[self setString:displayStyle forKey:MAPref_ActiveStyleName];
		if (flag)
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_StyleChange" object:nil];
	}
}

/* folderListFont
 * Retrieve the name of the font used in the folder list
 */
-(NSString *)folderListFont
{
	return [folderFont fontName];
}

/* folderListFontSize
 * Retrieve the size of the font used in the folder list
 */
-(int)folderListFontSize
{
	return [folderFont pointSize];
}

/* setFolderListFont
 * Retrieve the name of the font used in the folder list
 */
-(void)setFolderListFont:(NSString *)newFontName
{
	[folderFont release];
	folderFont = [NSFont fontWithName:newFontName size:[self folderListFontSize]];
	[self setObject:[NSArchiver archivedDataWithRootObject:folderFont] forKey:MAPref_FolderFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderFontChange" object:folderFont];
}

/* setFolderListFontSize
 * Changes the size of the font used in the folder list.
 */
-(void)setFolderListFontSize:(int)newFontSize
{
	[folderFont release];
	folderFont = [NSFont fontWithName:[self folderListFont] size:newFontSize];
	[self setObject:[NSArchiver archivedDataWithRootObject:folderFont] forKey:MAPref_FolderFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderFontChange" object:folderFont];
}

/* articleListFont
 * Retrieve the name of the font used in the article list
 */
-(NSString *)articleListFont
{
	return [articleFont fontName];
}

/* articleListFontSize
 * Retrieve the size of the font used in the article list
 */
-(int)articleListFontSize
{
	return [articleFont pointSize];
}

/* setArticleListFont
 * Retrieve the name of the font used in the article list
 */
-(void)setArticleListFont:(NSString *)newFontName
{
	[articleFont release];
	articleFont = [NSFont fontWithName:newFontName size:[self articleListFontSize]];
	[self setObject:[NSArchiver archivedDataWithRootObject:articleFont] forKey:MAPref_ArticleListFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListFontChange" object:articleFont];
}

/* setArticleListFontSize
 * Changes the size of the font used in the article list.
 */
-(void)setArticleListFontSize:(int)newFontSize
{
	[articleFont release];
	articleFont = [NSFont fontWithName:[self articleListFont] size:newFontSize];
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
		[articleSortDescriptors release];
		articleSortDescriptors = descriptors;
		[self setObject:[NSArchiver archivedDataWithRootObject:descriptors] forKey:MAPref_ArticleSortDescriptors];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
	}
}

/* foldersTreeSortMethod
 * Returns the method by which the folders tree is sorted. See MA_FolderSort_xxx for the possible values.
 */
-(int)foldersTreeSortMethod
{
	return foldersTreeSortMethod;
}

/* setFoldersTreeSortMethod
 * Sets the method by which the folders tree is sorted.
 */
-(void)setFoldersTreeSortMethod:(int)newMethod
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
-(int)newArticlesNotification
{
	return newArticlesNotification;
}

/* setNewArticlesNotification
 * Sets the method by which Vienna indicates new articles are available.
 */
-(void)setNewArticlesNotification:(int)newMethod
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
-(void)handleUpdateRestart:(NSNotification *)nc
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
			NSLog(@"Could not create feed sources folder at path '%@'. Error: %@", feedSourcesFolder, [error localizedDescription]);
		}
	}
	else if (!isDirectory)
	{
		// Huh, there's a Sources file there, but it's not a directory.
		NSLog(@"Could not create feed sources folder, because a non-directory file already exists at path '%@'.", feedSourcesFolder);
	}
}

@end
