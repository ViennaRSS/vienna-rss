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

// The default preferences object.
static Preferences * _standardPreferences = nil;

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
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

		refreshFrequency = [defaults integerForKey:MAPref_CheckFrequency];
		readingPaneOnRight = [defaults boolForKey:MAPref_ReadingPaneOnRight];
		refreshOnStartup = [defaults boolForKey:MAPref_CheckForNewArticlesOnStartup];
		checkForNewOnStartup = [defaults boolForKey:MAPref_CheckForUpdatesOnStartup];
		markReadInterval = [defaults floatForKey:MAPref_MarkReadInterval];
		minimumFontSize = [defaults integerForKey:MAPref_MinimumFontSize];
		enableMinimumFontSize = [defaults boolForKey:MAPref_UseMinimumFontSize];
		openLinksInVienna = [defaults boolForKey:MAPref_OpenLinksInVienna];
		openLinksInBackground = [defaults boolForKey:MAPref_OpenLinksInBackground];
		displayStyle = [[defaults stringForKey:MAPref_ActiveStyleName] retain];
		folderFont = [[NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:MAPref_FolderFont]] retain];
		articleFont = [[NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:MAPref_ArticleListFont]] retain]; 
	}
	return self;
}

/* dealloc
 * Clean up behind ourselves.
 */
-(void)dealloc
{
	[folderFont release];
	[articleFont release];
	[displayStyle release];
	[super dealloc];
}

/* initialize
 * The standard class initialization object.
 */
+(void)initialize
{
	// Set the preference defaults
	NSMutableDictionary * defaultValues = [NSMutableDictionary dictionary];
	NSNumber * cachedFolderID = [NSNumber numberWithInt:1];
	NSData * msgListFont = [NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Helvetica" size:12.0]];
	NSData * folderFont = [NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Helvetica" size:12.0]];
	NSNumber * boolNo = [NSNumber numberWithBool:NO];
	NSNumber * boolYes = [NSNumber numberWithBool:YES];
	
	// Some default options vary if we're running on 10.3
	NSDictionary * sysDict = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	BOOL isPanther = [[sysDict valueForKey:@"ProductVersion"] hasPrefix:@"10.3"];

	[defaultValues setObject:MA_DefaultDatabaseName forKey:MAPref_DefaultDatabase];
	[defaultValues setObject:MA_FolderImagesFolder forKey:MAPref_FolderImagesFolder];
	[defaultValues setObject:MA_StylesFolder forKey:MAPref_StylesFolder];
	[defaultValues setObject:MA_ScriptsFolder forKey:MAPref_ScriptsFolder];
	[defaultValues setObject:msgListFont forKey:MAPref_ArticleListFont];
	[defaultValues setObject:folderFont forKey:MAPref_FolderFont];
	[defaultValues setObject:boolNo forKey:MAPref_CheckForUpdatesOnStartup];
	[defaultValues setObject:boolYes forKey:MAPref_CheckForNewArticlesOnStartup];
	[defaultValues setObject:cachedFolderID forKey:MAPref_CachedFolderID];
	[defaultValues setObject:[NSNumber numberWithInt:-1] forKey:MAPref_SortDirection];
	[defaultValues setObject:MA_Field_Date forKey:MAPref_SortColumn];
	[defaultValues setObject:[NSNumber numberWithInt:0] forKey:MAPref_CheckFrequency];
	[defaultValues setObject:[NSNumber numberWithFloat:MA_Default_Read_Interval] forKey:MAPref_MarkReadInterval];
	[defaultValues setObject:[NSNumber numberWithInt:MA_Default_RefreshThreads] forKey:MAPref_RefreshThreads];
	[defaultValues setObject:[NSArray arrayWithObjects:nil] forKey:MAPref_MessageColumns];
	[defaultValues setObject:MA_DefaultStyleName forKey:MAPref_ActiveStyleName];
	[defaultValues setObject:[NSNumber numberWithInt:MA_Default_BackTrackQueueSize] forKey:MAPref_BacktrackQueueSize];
	[defaultValues setObject:boolYes forKey:MAPref_ReadingPaneOnRight];
	[defaultValues setObject:boolNo forKey:MAPref_EnableBloglinesSupport];
	[defaultValues setObject:@"" forKey:MAPref_BloglinesEmailAddress];
	[defaultValues setObject:boolYes forKey:MAPref_OpenLinksInVienna];
	[defaultValues setObject:boolNo forKey:MAPref_OpenLinksInBackground];
	[defaultValues setObject:(isPanther ? boolYes : boolNo) forKey:MAPref_ShowScriptsMenu];
	[defaultValues setObject:boolNo forKey:MAPref_UseMinimumFontSize];
	[defaultValues setObject:[NSNumber numberWithInt:MA_Default_MinimumFontSize] forKey:MAPref_MinimumFontSize];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
}

/* backTrackQueueSize
 * Returns the length of the back track queue.
 */
-(int)backTrackQueueSize
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:MAPref_BacktrackQueueSize];
}

/* enableMinimumFontSize
 * Specifies whether or not the minimum font size is in force.
 */
-(BOOL)enableMinimumFontSize
{
	return enableMinimumFontSize;
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
		[[NSUserDefaults standardUserDefaults] setInteger:minimumFontSize forKey:MAPref_MinimumFontSize];
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
		[[NSUserDefaults standardUserDefaults] setBool:flag forKey:MAPref_UseMinimumFontSize];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_MinimumFontSizeChange" object:nil];
	}
}

/* readingPaneOnRight
 * Returns whether the reading pane is on the right or at the bottom of the article list.
 */
-(BOOL)readingPaneOnRight
{
	return readingPaneOnRight;
}

/* setReadingPaneOnRight
 * Changes where the reading pane appears relative to the article list then updates the UI.
 */
-(void)setReadingPaneOnRight:(BOOL)flag
{
	if (flag != readingPaneOnRight)
	{
		readingPaneOnRight = flag;
		NSNumber * boolFlag = [NSNumber numberWithBool:flag];
		[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_ReadingPaneOnRight];
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
		[[NSUserDefaults standardUserDefaults] setInteger:newFrequency forKey:MAPref_CheckFrequency];
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
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:MAPref_CheckForNewArticlesOnStartup];
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
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:MAPref_CheckForUpdatesOnStartup];
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
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:newInterval] forKey:MAPref_MarkReadInterval];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferenceChange" object:nil];
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
-(void)setOpenLinksInVienna:(float)flag
{
	if (openLinksInVienna != flag)
	{
		openLinksInVienna = flag;
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:MAPref_OpenLinksInVienna];
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
-(void)setOpenLinksInBackground:(float)flag
{
	if (openLinksInBackground != flag)
	{
		openLinksInBackground = flag;
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:MAPref_OpenLinksInBackground];
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
	if (![displayStyle isEqualToString:newStyleName])
	{
		[newStyleName retain];
		[displayStyle release];
		displayStyle = newStyleName;
		[[NSUserDefaults standardUserDefaults] setValue:displayStyle forKey:MAPref_ActiveStyleName];
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
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:folderFont] forKey:MAPref_FolderFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderFontChange" object:folderFont];
}

/* setFolderListFontSize
 * Changes the size of the font used in the folder list.
 */
-(void)setFolderListFontSize:(int)newFontSize
{
	[folderFont release];
	folderFont = [NSFont fontWithName:[self folderListFont] size:newFontSize];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:folderFont] forKey:MAPref_FolderFont];
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
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:articleFont] forKey:MAPref_ArticleListFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListFontChange" object:articleFont];
}

/* setArticleListFontSize
 * Changes the size of the font used in the article list.
 */
-(void)setArticleListFontSize:(int)newFontSize
{
	[articleFont release];
	articleFont = [NSFont fontWithName:[self articleListFont] size:newFontSize];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:articleFont] forKey:MAPref_ArticleListFont];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleListFontChange" object:articleFont];
}
@end
