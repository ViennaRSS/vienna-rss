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

@import Cocoa;

extern NSString * MA_DefaultUserAgentString;
extern NSString * MA_BrowserUserAgentString;

extern NSString *const MAPref_ArticleListFont;
extern NSString * MAPref_AutoSortFoldersTree;
extern NSString * MAPref_CheckForUpdatedArticles;
extern NSString * MAPref_ShowUnreadArticlesInBold;
extern NSString *const MAPref_FolderListFont;
extern NSString * MAPref_CachedFolderID;
extern NSString * MAPref_DefaultDatabase;
extern NSString *const MAPref_DownloadsFolderBookmark;
extern NSString * MAPref_SortColumn;
extern NSString * MAPref_CheckFrequency;
extern NSString * MAPref_ArticleListColumns;
extern NSString * MAPref_CheckForNewArticlesOnStartup;
extern NSString * MAPref_FolderImagesFolder;
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
extern NSString *const MAPref_DownloadItemList;
extern NSString * MAPref_ShowFolderImages;
extern NSString * MAPref_UseJavaScript;
extern NSString * MAPref_UseNewBrowser;
extern NSString * MAPref_CachedArticleGUID;
extern NSString *const MAPref_ArticleListSortOrders;
extern NSString * MAPref_FilterMode;
extern NSString * MAPref_LastRefreshDate;
extern NSString * MAPref_TabList;
extern NSString * MAPref_TabTitleDictionary;
extern NSString * MAPref_Layout;
extern NSString * MAPref_NewArticlesNotification;
extern NSString * MAPref_EmptyTrashNotification;
extern NSString * MAPref_ShowAppInStatusBar;
extern NSString * MAPref_ShowStatusBar;
extern NSString * MAPref_ShowFilterBar;
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
extern NSString * MAPref_SyncingAppId;
extern NSString * MAPref_SyncingAppKey;
extern NSString * MAPref_AlwaysAcceptBetas;
extern NSString * MAPref_UserAgentName;
extern NSString *const MAPref_UseRelativeDates;
extern NSString * const MAPref_ShowDetailsOnFeedCredentialsDialog;

// Deprecated defaults keys
extern NSString *const MAPref_Deprecated_ArticleListFont;
extern NSString *const MAPref_Deprecated_ArticleListSortOrders;
extern NSString *const MAPref_Deprecated_DownloadItemList;
extern NSString *const MAPref_Deprecated_FolderListFont;

extern NSInteger const MA_Default_BackTrackQueueSize;
extern NSInteger const MA_Default_RefreshThreads;
extern float const MA_Default_Read_Interval;
extern NSInteger const MA_Default_MinimumFontSize;
extern NSInteger const MA_Default_AutoExpireDuration;
extern NSInteger const MA_Default_Check_Frequency;
extern CGFloat const MA_Default_Main_Window_Min_Width;
extern CGFloat const MA_Default_Main_Window_Min_Height;
extern NSInteger const MA_Default_ConcurrentDownloads;

extern NSPasteboardType const VNAPasteboardTypeRSSItem;
extern NSPasteboardType const VNAPasteboardTypeFolderList;
extern NSPasteboardType const VNAPasteboardTypeRSSSource;
extern NSPasteboardType const VNAPasteboardTypeURL;
extern NSPasteboardType const VNAPasteboardTypeURLName;
extern NSPasteboardType const VNAPasteboardTypeWebURLsWithTitles;

extern AEKeyword const EditDataItemAppleEventClass;
extern AEKeyword const EditDataItemAppleEventID;
extern AEKeyword const DataItemTitle;
extern AEKeyword const DataItemDescription;
extern AEKeyword const DataItemSummary;
extern AEKeyword const DataItemLink;
extern AEKeyword const DataItemPermalink;
extern AEKeyword const DataItemSubject;
extern AEKeyword const DataItemCreator;
extern AEKeyword const DataItemCommentsURL;
extern AEKeyword const DataItemGUID;
extern AEKeyword const DataItemSourceName;
extern AEKeyword const DataItemSourceHomeURL;
extern AEKeyword const DataItemSourceFeedURL;
