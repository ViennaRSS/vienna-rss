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

@import Cocoa;

NSString * MA_DefaultUserAgentString = @"%@/%@ (Macintosh; Intel macOS %@)";
NSString * MA_BrowserUserAgentString = @"(Macintosh; Intel Mac OS X %@) AppleWebKit/%@ (KHTML, like Gecko) Version/%@ Safari/604.1.38 %@/%@";

NSString * MAPref_ArticleListFont = @"MessageListFont";
NSString * MAPref_AutoSortFoldersTree = @"AutomaticallySortFoldersTree";
NSString * MAPref_CheckForUpdatedArticles = @"CheckForUpdatedArticles";
NSString * MAPref_ShowUnreadArticlesInBold = @"ShowUnreadArticlesInBold";
NSString * MAPref_FolderFont = @"FolderFont";
NSString * MAPref_CachedFolderID = @"CachedFolderID";
NSString * MAPref_DefaultDatabase = @"DefaultDatabase";
NSString *const MAPref_DownloadsFolderBookmark = @"DownloadsFolderBookmark";
NSString * MAPref_SortColumn = @"SortColumn";
NSString * MAPref_CheckFrequency = @"CheckFrequencyInSeconds";
NSString * MAPref_ArticleListColumns = @"MessageColumns";
NSString * MAPref_CheckForNewArticlesOnStartup = @"CheckForNewMessagesOnStartup";
NSString * MAPref_FolderImagesFolder = @"FolderIconsCache";
NSString * MAPref_StylesFolder = @"StylesFolder";
NSString * MAPref_PluginsFolder = @"PluginsFolder";
NSString * MAPref_ScriptsFolder = @"ScriptsFolder";
NSString * MAPref_ActiveStyleName = @"ActiveStyle";
NSString * MAPref_ActiveTextSizeMultiplier = @"TextSizeMultiplier";
NSString * MAPref_FolderStates = @"FolderStates";
NSString * MAPref_BacktrackQueueSize = @"BacktrackQueueSize";
NSString * MAPref_MarkReadInterval = @"MarkReadInterval";
NSString * MAPref_OpenLinksInVienna = @"OpenLinksInVienna";
NSString * MAPref_OpenLinksInBackground = @"OpenLinksInBackground";
NSString * MAPref_MinimumFontSize = @"MinimumFontSize";
NSString * MAPref_UseMinimumFontSize = @"UseMinimumFontSize";
NSString * MAPref_AutoExpireDuration = @"AutoExpireFrequency";
NSString * MAPref_DownloadsList = @"DownloadsList";
NSString * MAPref_ShowFolderImages = @"ShowFolderImages";
NSString * MAPref_UseJavaScript = @"UseJavaScript";
NSString * MAPref_UseNewBrowser = @"UseNewBrowser";
NSString * MAPref_CachedArticleGUID = @"CachedArticleGUID";
NSString * MAPref_ArticleSortDescriptors = @"ArticleSortDescriptors";
NSString * MAPref_FilterMode = @"FilterMode";
NSString * MAPref_LastRefreshDate = @"LastRefreshDate";
NSString * MAPref_TabList = @"TabList";
NSString * MAPref_TabTitleDictionary = @"TabTitleDict";
NSString * MAPref_Layout = @"Layout";
NSString * MAPref_NewArticlesNotification = @"NewArticlesNotification";
NSString * MAPref_Profile_Path = @"ProfilePath";
NSString * MAPref_EmptyTrashNotification = @"EmptyTrashNotification";
NSString * MAPref_ShowAppInStatusBar = @"ShowAppInStatusBar";
NSString * MAPref_ShowStatusBar = @"ShowStatusBar";
NSString * MAPref_ShowFilterBar = @"ShowFilterBar";
NSString * MAPref_LastViennaVersionRun = @"LastViennaVersionRun";
NSString * MAPref_HighestViennaVersionRun = @"HighestViennaVersionRun";
NSString * MAPref_ShouldSaveFeedSource = @"ShouldSaveFeedSource";
NSString * MAPref_ShouldSaveFeedSourceBackup = @"ShouldSaveFeedSourceBackup";
NSString * MAPref_SearchMethod = @"SearchMethod";
NSString * MAPref_SyncGoogleReader = @"SyncGoogleReader";
NSString * MAPref_GoogleNewSubscription = @"GoogleNewSubscription";
NSString * MAPref_ConcurrentDownloads = @"ConcurrentDownloads"; 
NSString * MAPref_SyncServer = @"SyncServer";
NSString * MAPref_SyncingUser = @"SyncingUser";
NSString * MAPref_SyncingAppId = @"SyncingAppId";
NSString * MAPref_SyncingAppKey = @"SyncingAppKey";
NSString * MAPref_AlwaysAcceptBetas = @"AlwayAcceptBetas";
NSString * MAPref_UserAgentName = @"UserAgentName";

const NSInteger MA_Default_BackTrackQueueSize = 20;
const NSInteger MA_Default_RefreshThreads = 20;
const NSInteger MA_Default_MinimumFontSize = 9;
const float MA_Default_Read_Interval = 0.5;
const NSInteger MA_Default_AutoExpireDuration = 0;
const NSInteger MA_Default_Check_Frequency = 10800;
const CGFloat MA_Default_Main_Window_Min_Width = 700.0;
const CGFloat MA_Default_Main_Window_Min_Height = 350.0;
const NSInteger MA_Default_ConcurrentDownloads = 10;

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
