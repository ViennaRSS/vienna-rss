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

NSString * MA_DefaultUserAgentString = @"Mozilla/5.0 Vienna/%@";
NSString * MA_BrowserUserAgentString = @"Vienna/%@ Version/%@ Safari/%@";

NSString * MAPref_ArticleListFont = @"MessageListFont";
NSString * MAPref_AutoSortFoldersTree = @"AutomaticallySortFoldersTree";
NSString * MAPref_CheckForUpdatedArticles = @"CheckForUpdatedArticles";
NSString * MAPref_ShowUnreadArticlesInBold = @"ShowUnreadArticlesInBold";
NSString * MAPref_FolderFont = @"FolderFont";
NSString * MAPref_CachedFolderID = @"CachedFolderID";
NSString * MAPref_DefaultDatabase = @"DefaultDatabase";
NSString * MAPref_DownloadsFolder = @"DownloadsFolder";
NSString * MAPref_SortColumn = @"SortColumn";
NSString * MAPref_CheckFrequency = @"CheckFrequencyInSeconds";
NSString * MAPref_ArticleListColumns = @"MessageColumns";
NSString * MAPref_CheckForNewArticlesOnStartup = @"CheckForNewMessagesOnStartup";
NSString * MAPref_FolderImagesFolder = @"FolderIconsCache";
NSString * MAPref_StylesFolder = @"StylesFolder";
NSString * MAPref_PluginsFolder = @"PluginsFolder";
NSString * MAPref_ScriptsFolder = @"ScriptsFolder";
NSString * MAPref_RefreshThreads = @"MaxRefreshThreads";
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
NSString * MAPref_UseWebPlugins = @"UseWebPlugins";
NSString * MAPref_CachedArticleGUID = @"CachedArticleGUID";
NSString * MAPref_ArticleSortDescriptors = @"ArticleSortDescriptors";
NSString * MAPref_FilterMode = @"FilterMode";
NSString * MAPref_LastRefreshDate = @"LastRefreshDate";
NSString * MAPref_TabList = @"TabList";
NSString * MAPref_Layout = @"Layout";
NSString * MAPref_NewArticlesNotification = @"NewArticlesNotification";
NSString * MAPref_Profile_Path = @"ProfilePath";
NSString * MAPref_EmptyTrashNotification = @"EmptyTrashNotification";
NSString * MAPref_ShowAppInStatusBar = @"ShowAppInStatusBar";
NSString * MAPref_ShowStatusBar = @"ShowStatusBar";
NSString * MAPref_ShowFilterBar = @"ShowFilterBar";
NSString * MAPref_NewFolderUI = @"NewFolderUI";
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
NSString * MAPref_SendSystemProfileInfo = @"SUSendProfileInfo";
NSString * MAPref_AlwaysAcceptBetas = @"AlwayAcceptBetas";

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
const AEKeyword EditDataItemAppleEventClass = 'EBlg';
const AEKeyword EditDataItemAppleEventID = 'oitm';
const AEKeyword DataItemTitle = 'titl';
const AEKeyword DataItemDescription = 'desc';
const AEKeyword DataItemSummary = 'summ';
const AEKeyword DataItemLink = 'link';
const AEKeyword DataItemPermalink = 'plnk';
const AEKeyword DataItemSubject = 'subj';
const AEKeyword DataItemCreator = 'crtr';
const AEKeyword DataItemCommentsURL = 'curl';
const AEKeyword DataItemGUID = 'guid';
const AEKeyword DataItemSourceName = 'snam';
const AEKeyword DataItemSourceHomeURL = 'hurl';
const AEKeyword DataItemSourceFeedURL = 'furl';

// Custom pasteboard types
NSString * MA_PBoardType_FolderList = @"ViennaFolderType";
NSString * MA_PBoardType_RSSSource = @"CorePasteboardFlavorType 0x52535373";
NSString * MA_PBoardType_RSSItem = @"CorePasteboardFlavorType 0x52535369";
NSString * MA_PBoardType_url = @"CorePasteboardFlavorType 0x75726C20";
NSString * MA_PBoardType_urln = @"CorePasteboardFlavorType 0x75726C6E";

// Sync folder separator
//NSString * MA_Sync_FolderSeparator = @" — ";
