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

extern NSString * const MA_DefaultUserAgentString;
extern NSString * const MA_BrowserUserAgentString;

extern NSNotificationName const MA_Notify_ArticleListContentChange;
extern NSNotificationName const MA_Notify_ArticleListFontChange;
extern NSNotificationName const MA_Notify_ArticleListStateChange;
extern NSNotificationName const MA_Notify_ArticleViewChange;
extern NSNotificationName const MA_Notify_ArticleViewEnded NS_SWIFT_NAME(articleViewEnded);
extern NSNotificationName const MA_Notify_AutoSortFoldersTreeChange;
extern NSNotificationName const MA_Notify_CancelAuthenticationForFolder;
extern NSNotificationName const MA_Notify_CellResize;
extern NSNotificationName const MA_Notify_CheckFrequencyChange;
extern NSNotificationName const MA_Notify_CowncurrentDownloadsChange;
extern NSNotificationName const MA_Notify_DownloadCompleted;
extern NSNotificationName const MA_Notify_DownloadsListChange;
extern NSNotificationName const MA_Notify_EditFolder;
extern NSNotificationName const MA_Notify_FilterBarChanged;
extern NSNotificationName const MA_Notify_FolderAdded;
extern NSNotificationName const MA_Notify_FolderDescriptionChanged; // Unused
extern NSNotificationName const MA_Notify_FolderHomePageChanged; // Unused
extern NSNotificationName const MA_Notify_FolderNameChanged;
extern NSNotificationName const MA_Notify_FolderSelectionChange;
extern NSNotificationName const MA_Notify_FoldersUpdated;
extern NSNotificationName const MA_Notify_GoogleAuthFailed;
extern NSNotificationName const MA_Notify_GoogleReaderNewSubscriptionChange; // Unused
extern NSNotificationName const MA_Notify_GotAuthenticationForFolder;
extern NSNotificationName const MA_Notify_LoadFullHTMLChange;
extern NSNotificationName const MA_Notify_MinimumFontSizeChange;
extern NSNotificationName const MA_Notify_OpenReaderFolderChange;
extern NSNotificationName const MA_Notify_PreferenceChange;
extern NSNotificationName const MA_Notify_ReadingPaneChange;
extern NSNotificationName const MA_Notify_RefreshStatus;
extern NSNotificationName const MA_Notify_ShowAppInStatusBarChanged;
extern NSNotificationName const MA_Notify_ShowFolderImages;
extern NSNotificationName const MA_Notify_StyleChange NS_SWIFT_NAME(styleChanged);
extern NSNotificationName const MA_Notify_SyncGoogleReaderChange; // Unused
extern NSNotificationName const MA_Notify_TabChanged NS_SWIFT_NAME(tabChanged);
extern NSNotificationName const MA_Notify_TabCountChanged NS_SWIFT_NAME(tabCountChanged);
extern NSNotificationName const MA_Notify_UseJavaScriptChange; // Unused

extern NSString * const MAPref_ArticleListFont;
extern NSString * const MAPref_AutoSortFoldersTree;
extern NSString * const MAPref_CheckForUpdatedArticles;
extern NSString * const MAPref_ShowUnreadArticlesInBold;
extern NSString * const MAPref_CachedFolderID;
extern NSString * const MAPref_DefaultDatabase;
extern NSString * const MAPref_DownloadsFolderBookmark;
extern NSString * const MAPref_SortColumn;
extern NSString * const MAPref_CheckFrequency;
extern NSString * const MAPref_ArticleListColumns;
extern NSString * const MAPref_CheckForNewArticlesOnStartup;
extern NSString * const MAPref_ActiveStyleName;
extern NSString * const MAPref_ActiveTextSizeMultiplier;
extern NSString * const MAPref_FolderStates;
extern NSString * const MAPref_BacktrackQueueSize;
extern NSString * const MAPref_MarkReadInterval;
extern NSString * const MAPref_OpenLinksInVienna;
extern NSString * const MAPref_OpenLinksInBackground;
extern NSString * const MAPref_MinimumFontSize;
extern NSString * const MAPref_UseMinimumFontSize;
extern NSString * const MAPref_AutoExpireDuration;
extern NSString * const MAPref_DownloadItemList;
extern NSString * const MAPref_ShowFolderImages;
extern NSString * const MAPref_UseJavaScript;
extern NSString * const MAPref_CachedArticleGUID;
extern NSString * const MAPref_ArticleListSortOrders;
extern NSString * const MAPref_FilterMode;
extern NSString * const MAPref_LastRefreshDate;
extern NSString * const MAPref_TabList;
extern NSString * const MAPref_TabTitleDictionary;
extern NSString * const MAPref_Layout;
extern NSString * const MAPref_NewArticlesNotification;
extern NSString * const MAPref_EmptyTrashNotification;
extern NSString * const MAPref_ShowAppInStatusBar;
extern NSString * const MAPref_ShowStatusBar;
extern NSString * const MAPref_ShowFilterBar;
extern NSString * const MAPref_LastViennaVersionRun;
extern NSString * const MAPref_HighestViennaVersionRun;
extern NSString * const MAPref_ShouldSaveFeedSource;
extern NSString * const MAPref_ShouldSaveFeedSourceBackup;
extern NSString * const MAPref_SearchMethod;
extern NSString * const MAPref_SyncGoogleReader;
extern NSString * const MAPref_GoogleNewSubscription;
extern NSString * const MAPref_ConcurrentDownloads;
extern NSString * const MAPref_SyncServer;
extern NSString * const MAPref_SyncScheme;
extern NSString * const MAPref_SyncingUser;
extern NSString * const MAPref_SyncingAppId;
extern NSString * const MAPref_SyncingAppKey;
extern NSString * const MAPref_AlwaysAcceptBetas;
extern NSString * const MAPref_UserAgentName;
extern NSString * const MAPref_UseRelativeDates;
extern NSString * const MAPref_ShowDetailsOnFeedCredentialsDialog;
extern NSString * const MAPref_ShowEnclosureBar;
extern NSString * const MAPref_FeedListSizeMode;
extern NSString * const MAPref_ShowFeedsWithUnreadItemsInBold;

extern NSInteger const MA_Default_BackTrackQueueSize;
extern float const MA_Default_Read_Interval;
extern NSInteger const MA_Default_MinimumFontSize;
extern NSInteger const MA_Default_AutoExpireDuration;
extern NSInteger const MA_Default_Check_Frequency;
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
