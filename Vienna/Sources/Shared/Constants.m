//
//  Constants.m
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

#import "Constants.h"

NSString * const MA_DefaultUserAgentString = @"%@/%@ (Macintosh; Intel macOS %@)";
NSString * const MA_BrowserUserAgentString = @"(Macintosh; Intel Mac OS X %@) AppleWebKit/%@ (KHTML, like Gecko) Version/%@ Safari/604.1.38 %@/%@";

NSString * const MAPref_ArticleListFont = @"ArticleListFont";
NSString * const MAPref_AutoSortFoldersTree = @"AutomaticallySortFoldersTree";
NSString * const MAPref_CheckForUpdatedArticles = @"CheckForUpdatedArticles";
NSString * const MAPref_ShowUnreadArticlesInBold = @"ShowUnreadArticlesInBold";
NSString * const MAPref_CachedFolderID = @"CachedFolderID";
NSString * const MAPref_DefaultDatabase = @"DefaultDatabase";
NSString * const MAPref_DownloadsFolderBookmark = @"DownloadsFolderBookmark";
NSString * const MAPref_SortColumn = @"SortColumn";
NSString * const MAPref_CheckFrequency = @"CheckFrequencyInSeconds";
NSString * const MAPref_ArticleListColumns = @"MessageColumns";
NSString * const MAPref_CheckForNewArticlesOnStartup = @"CheckForNewMessagesOnStartup";
NSString * const MAPref_ActiveStyleName = @"ActiveStyle";
NSString * const MAPref_ActiveTextSizeMultiplier = @"TextSizeMultiplier";
NSString * const MAPref_FolderStates = @"FolderStates";
NSString * const MAPref_BacktrackQueueSize = @"BacktrackQueueSize";
NSString * const MAPref_MarkReadInterval = @"MarkReadInterval";
NSString * const MAPref_OpenLinksInVienna = @"OpenLinksInVienna";
NSString * const MAPref_OpenLinksInBackground = @"OpenLinksInBackground";
NSString * const MAPref_MinimumFontSize = @"MinimumFontSize";
NSString * const MAPref_UseMinimumFontSize = @"UseMinimumFontSize";
NSString * const MAPref_AutoExpireDuration = @"AutoExpireFrequency";
NSString * const MAPref_DownloadItemList = @"DownloadItemsList";
NSString * const MAPref_ShowFolderImages = @"ShowFolderImages";
NSString * const MAPref_UseJavaScript = @"UseJavaScript";
NSString * const MAPref_CachedArticleGUID = @"CachedArticleGUID";
NSString * const MAPref_ArticleListSortOrders = @"ArticleListSortOrders";
NSString * const MAPref_FilterMode = @"FilterMode";
NSString * const MAPref_LastRefreshDate = @"LastRefreshDate";
NSString * const MAPref_TabList = @"TabList";
NSString * const MAPref_TabTitleDictionary = @"TabTitleDict";
NSString * const MAPref_Layout = @"Layout";
NSString * const MAPref_NewArticlesNotification = @"NewArticlesNotification";
NSString * const MAPref_EmptyTrashNotification = @"EmptyTrashNotification";
NSString * const MAPref_ShowAppInStatusBar = @"ShowAppInStatusBar";
NSString * const MAPref_ShowStatusBar = @"ShowStatusBar";
NSString * const MAPref_ShowFilterBar = @"ShowFilterBar";
NSString * const MAPref_LastViennaVersionRun = @"LastViennaVersionRun";
NSString * const MAPref_HighestViennaVersionRun = @"HighestViennaVersionRun";
NSString * const MAPref_ShouldSaveFeedSource = @"ShouldSaveFeedSource";
NSString * const MAPref_ShouldSaveFeedSourceBackup = @"ShouldSaveFeedSourceBackup";
NSString * const MAPref_SearchMethod = @"SearchMethod";
NSString * const MAPref_SyncGoogleReader = @"SyncGoogleReader";
NSString * const MAPref_GoogleNewSubscription = @"GoogleNewSubscription";
NSString * const MAPref_ConcurrentDownloads = @"ConcurrentDownloads";
NSString * const MAPref_SyncServer = @"SyncServer";
NSString * const MAPref_SyncScheme = @"SyncScheme";
NSString * const MAPref_SyncingUser = @"SyncingUser";
NSString * const MAPref_SyncingAppId = @"SyncingAppId";
NSString * const MAPref_SyncingAppKey = @"SyncingAppKey";
NSString * const MAPref_AlwaysAcceptBetas = @"AlwayAcceptBetas";
NSString * const MAPref_UserAgentName = @"UserAgentName";

// Deprecated defaults keys
NSString * const MAPref_Deprecated_ArticleListFont = @"MessageListFont";
NSString * const MAPref_Deprecated_ArticleListSortOrders = @"ArticleSortDescriptors";
NSString * const MAPref_Deprecated_DownloadItemList = @"DownloadsList";
NSString * const MAPref_Deprecated_FolderFont = @"FolderFont";
NSString * const MAPref_Deprecated_FolderListFont = @"FolderListFont";

NSInteger const MA_Default_BackTrackQueueSize = 20;
NSInteger const MA_Default_RefreshThreads = 20;
NSInteger const MA_Default_MinimumFontSize = 9;
float const MA_Default_Read_Interval = 0.5;
NSInteger const MA_Default_AutoExpireDuration = 0;
NSInteger const MA_Default_Check_Frequency = 10800;
CGFloat const MA_Default_Main_Window_Min_Width = 700.0;
CGFloat const MA_Default_Main_Window_Min_Height = 350.0;
NSInteger const MA_Default_ConcurrentDownloads = 10;

// Constants for External Weblog Editor Interface according to http://ranchero.com/netnewswire/developers/externalinterface.php
// We are not using all of them yet, but they might become useful in the future.
AEKeyword const EditDataItemAppleEventClass = 'EBlg';
AEKeyword const EditDataItemAppleEventID = 'oitm';
AEKeyword const DataItemTitle = 'titl';
AEKeyword const DataItemDescription = 'desc';
AEKeyword const DataItemSummary = 'summ';
AEKeyword const DataItemLink = 'link';
AEKeyword const DataItemPermalink = 'plnk';
AEKeyword const DataItemSubject = 'subj';
AEKeyword const DataItemCreator = 'crtr';
AEKeyword const DataItemCommentsURL = 'curl';
AEKeyword const DataItemGUID = 'guid';
AEKeyword const DataItemSourceName = 'snam';
AEKeyword const DataItemSourceHomeURL = 'hurl';
AEKeyword const DataItemSourceFeedURL = 'furl';

// Custom pasteboard types
NSPasteboardType const VNAPasteboardTypeFolderList = @"ViennaFolderType";
NSPasteboardType const VNAPasteboardTypeRSSSource = @"CorePasteboardFlavorType 0x52535373";
NSPasteboardType const VNAPasteboardTypeRSSItem = @"CorePasteboardFlavorType 0x52535369";
NSPasteboardType const VNAPasteboardTypeURL = @"CorePasteboardFlavorType 0x75726C20";
NSPasteboardType const VNAPasteboardTypeURLName = @"CorePasteboardFlavorType 0x75726C6E";
NSPasteboardType const VNAPasteboardTypeWebURLsWithTitles = @"WebURLsWithTitlesPboardType";
