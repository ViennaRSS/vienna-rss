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

extern NSString * MAPref_ArticleListFont;
extern NSString * MAPref_FolderFont;
extern NSString * MAPref_CachedFolderID;
extern NSString * MAPref_DefaultDatabase;
extern NSString * MAPref_DownloadsFolder;
extern NSString * MAPref_SortColumn;
extern NSString * MAPref_CheckFrequency;
extern NSString * MAPref_ArticleListColumns;
extern NSString * MAPref_CheckForUpdatesOnStartup;
extern NSString * MAPref_CheckForNewArticlesOnStartup;
extern NSString * MAPref_FolderImagesFolder;
extern NSString * MAPref_RefreshThreads;
extern NSString * MAPref_ActiveStyleName;
extern NSString * MAPref_StylesFolder;
extern NSString * MAPref_ScriptsFolder;
extern NSString * MAPref_FolderStates;
extern NSString * MAPref_BacktrackQueueSize;
extern NSString * MAPref_ReadingPaneOnRight;
extern NSString * MAPref_EnableBloglinesSupport;
extern NSString * MAPref_BloglinesEmailAddress;
extern NSString * MAPref_MarkReadInterval;
extern NSString * MAPref_SelectionChangeInterval;
extern NSString * MAPref_OpenLinksInVienna;
extern NSString * MAPref_OpenLinksInBackground;
extern NSString * MAPref_ShowScriptsMenu;
extern NSString * MAPref_MinimumFontSize;
extern NSString * MAPref_UseMinimumFontSize;
extern NSString * MAPref_AutoExpireDuration;
extern NSString * MAPref_DownloadsList;
extern NSString * MAPref_ShowFolderImages;
extern NSString * MAPref_CachedArticleGUID;
extern NSString * MAPref_ArticleSortDescriptors;
extern NSString * MAPref_FilterMode;
extern NSString * MAPref_LastRefreshDate;
extern NSString * MAPref_TabList;

extern int MA_Default_BackTrackQueueSize;
extern int MA_Default_RefreshThreads;
extern float MA_Default_Read_Interval;
extern float MA_Default_Selection_Change_Interval;
extern int MA_Default_MinimumFontSize;
extern int MA_Default_AutoExpireDuration;

extern NSString * MA_PBoardType_RSSItem;
extern NSString * MA_PBoardType_FolderList;
extern NSString * MA_PBoardType_RSSSource;

// Filtering options
#define MA_Filter_All			0
#define MA_Filter_Unread		1
#define MA_Filter_LastRefresh	2
#define MA_Filter_Today			3

// Refresh folder options
#define MA_Refresh_RedrawList			0
#define MA_Refresh_ReapplyFilter		1
#define MA_Refresh_ReloadFromDatabase	2

// Layout styles
#define MA_Table_Layout			0
#define MA_Condensed_Layout		1
