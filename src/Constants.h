//
//  Constants.h
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
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

extern NSString * MA_DefaultStyleName;
extern NSString * MA_DefaultUserAgentString;
extern NSString * MA_BrowserUserAgentString;

extern NSString * MAPref_ArticleListFont;
extern NSString * MAPref_AutoSortFoldersTree;
extern NSString * MAPref_CheckForUpdatedArticles;
extern NSString * MAPref_ShowUnreadArticlesInBold;
extern NSString * MAPref_FolderFont;
extern NSString * MAPref_CachedFolderID;
extern NSString * MAPref_DefaultDatabase;
extern NSString * MAPref_DownloadsFolder;
extern NSString * MAPref_SortColumn;
extern NSString * MAPref_CheckFrequency;
extern NSString * MAPref_ArticleListColumns;
extern NSString * MAPref_CheckForNewArticlesOnStartup;
extern NSString * MAPref_FolderImagesFolder;
extern NSString * MAPref_RefreshThreads;
extern NSString * MAPref_ActiveStyleName;
extern NSString * MAPref_ActiveTextSizeMultiplier;
extern NSString * MAPref_StylesFolder;
extern NSString * MAPref_PluginsFolder;
extern NSString * MAPref_ScriptsFolder;
extern NSString * MAPref_FolderStates;
extern NSString * MAPref_BacktrackQueueSize;
extern NSString * MAPref_MarkReadInterval;
extern NSString * MAPref_OpenLinksInVienna;
extern NSString * MAPref_OpenLinksInBackground;
extern NSString * MAPref_MinimumFontSize;
extern NSString * MAPref_UseMinimumFontSize;
extern NSString * MAPref_AutoExpireDuration;
extern NSString * MAPref_DownloadsList;
extern NSString * MAPref_ShowFolderImages;
extern NSString * MAPref_UseJavaScript;
extern NSString * MAPref_UseWebPlugins;
extern NSString * MAPref_CachedArticleGUID;
extern NSString * MAPref_ArticleSortDescriptors;
extern NSString * MAPref_FilterMode;
extern NSString * MAPref_LastRefreshDate;
extern NSString * MAPref_TabList;
extern NSString * MAPref_Layout;
extern NSString * MAPref_NewArticlesNotification;
extern NSString * MAPref_Profile_Path;
extern NSString * MAPref_EmptyTrashNotification;
extern NSString * MAPref_ShowAppInStatusBar;
extern NSString * MAPref_ShowStatusBar;
extern NSString * MAPref_ShowFilterBar;
extern NSString * MAPref_NewFolderUI;
extern NSString * MAPref_LastViennaVersionRun;
extern NSString * MAPref_HighestViennaVersionRun;
extern NSString * MAPref_ShouldSaveFeedSource;
extern NSString * MAPref_ShouldSaveFeedSourceBackup;
extern NSString * MAPref_SearchMethod;
extern NSString * MAPref_SyncGoogleReader;
extern NSString * MAPref_GoogleNewSubscription;
extern NSString * MAPref_ConcurrentDownloads;
extern NSString * MAPref_SyncServer;
extern NSString * MAPref_SyncingUser;
extern NSString * MAPref_SendSystemProfileInfo;
extern NSString * MAPref_AlwaysAcceptBetas;

extern NSInteger MA_Default_BackTrackQueueSize;
extern NSInteger MA_Default_RefreshThreads;
extern float MA_Default_Read_Interval;
extern NSInteger MA_Default_MinimumFontSize;
extern NSInteger MA_Default_AutoExpireDuration;
extern NSInteger MA_Default_Check_Frequency;
extern CGFloat MA_Default_Main_Window_Min_Width;
extern CGFloat MA_Default_Main_Window_Min_Height;
extern NSInteger MA_Default_ConcurrentDownloads;

extern NSString * MA_PBoardType_RSSItem;
extern NSString * MA_PBoardType_FolderList;
extern NSString * MA_PBoardType_RSSSource;
extern NSString * MA_PBoardType_url;
extern NSString * MA_PBoardType_urln;

// New articles notification method
// (managed as an array of binary flags)
#define MA_NewArticlesNotification_Badge	1
#define MA_NewArticlesNotification_Bounce	2

// Filtering options
#define MA_Filter_All					0
#define MA_Filter_Unread				1
#define MA_Filter_LastRefresh			2
#define MA_Filter_Today					3
#define MA_Filter_48h					4
#define MA_Filter_Flagged				5
#define MA_Filter_Unread_Or_Flagged		6

// Refresh folder options
#define MA_Refresh_RedrawList			0
#define MA_Refresh_ReapplyFilter		1
#define MA_Refresh_ReloadFromDatabase	2
#define MA_Refresh_SortAndRedraw		3

// Growl contexts
#define MA_GrowlContext_RefreshCompleted	1
#define MA_GrowlContext_DownloadCompleted	2
#define MA_GrowlContext_DownloadFailed		3

// View animation tags
#define MA_ViewTag_Filterbar			1
#define MA_ViewTag_Statusbar			2

extern AEKeyword EditDataItemAppleEventClass;
extern AEKeyword EditDataItemAppleEventID;
extern AEKeyword DataItemTitle;
extern AEKeyword DataItemDescription;
extern AEKeyword DataItemSummary;
extern AEKeyword DataItemLink;
extern AEKeyword DataItemPermalink;
extern AEKeyword DataItemSubject;
extern AEKeyword DataItemCreator;
extern AEKeyword DataItemCommentsURL;
extern AEKeyword DataItemGUID;
extern AEKeyword DataItemSourceName;
extern AEKeyword DataItemSourceHomeURL;
extern AEKeyword DataItemSourceFeedURL;

// Layout styles
#define MA_Layout_Report				1
#define MA_Layout_Condensed				2
#define MA_Layout_Unified				3

// Folders tree sort method
#define MA_FolderSort_Manual			0
#define MA_FolderSort_ByName			1

// Empty trash option on quitting
#define MA_EmptyTrash_None				0
#define MA_EmptyTrash_WithoutWarning	1
#define MA_EmptyTrash_WithWarning		2

// Sync types
typedef NS_ENUM(unsigned int, SyncTypes) {
    MA_Sync_Subscribe,
    MA_Sync_Unsubscribe,
    MA_Sync_Delete,
    MA_Sync_Merge,
    MA_Sync_Refresh,
    MA_Sync_Refresh_All,
    MA_Sync_NewFromGoogle,
    MA_Sync_Mark_Read,
    MA_Sync_Mark_Unread,
    MA_Sync_Mark_Flagged,
    MA_Sync_Mark_Unflagged
};

//extern NSString * MA_Sync_FolderSeparator;
