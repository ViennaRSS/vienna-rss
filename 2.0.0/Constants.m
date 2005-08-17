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

NSString * MA_DefaultDatabaseName = @"~/Library/Application Support/Vienna/messages.db";
NSString * MA_FolderImagesFolder = @"~/Library/Application Support/Vienna/Images";
NSString * MA_StylesFolder = @"~/Library/Application Support/Vienna/Styles";
NSString * MA_ScriptsFolder = @"~/Library/Scripts/Applications/Vienna";
NSString * MA_DefaultStyleName = @"Default";

NSString * MAPref_MessageListFont = @"MessageListFont";
NSString * MAPref_FolderFont = @"FolderFont";
NSString * MAPref_CachedFolderID = @"CachedFolderID";
NSString * MAPref_DefaultDatabase = @"DefaultDatabase";
NSString * MAPref_SortDirection = @"SortDirection";
NSString * MAPref_SortColumn = @"SortColumn";
NSString * MAPref_CheckFrequency = @"CheckFrequencyInSeconds";
NSString * MAPref_MessageColumns = @"MessageColumns";
NSString * MAPref_CheckForUpdatesOnStartup = @"CheckForUpdatesOnStartup";
NSString * MAPref_CheckForNewMessagesOnStartup = @"CheckForNewMessagesOnStartup";
NSString * MAPref_FolderImagesFolder = @"FolderIconsCache";
NSString * MAPref_StylesFolder = @"StylesFolder";
NSString * MAPref_ScriptsFolder = @"ScriptsFolder";
NSString * MAPref_RefreshThreads = @"MaxRefreshThreads";
NSString * MAPref_ActiveStyleName = @"ActiveStyle";
NSString * MAPref_FolderStates = @"FolderStates";
NSString * MAPref_BacktrackQueueSize = @"BacktrackQueueSize";
NSString * MAPref_ReadingPaneOnRight = @"ReadingPaneOnRight";
NSString * MAPref_EnableBloglinesSupport = @"EnableBloglinesSupport";
NSString * MAPref_BloglinesEmailAddress = @"BloglinesEmailAddress";
NSString * MAPref_MarkReadInterval = @"MarkReadInterval";
NSString * MAPref_OpenLinksInVienna = @"OpenLinksInVienna";
NSString * MAPref_OpenLinksInBackground = @"OpenLinksInBackground";
NSString * MAPref_ShowScriptsMenu = @"ShowScriptsMenu";

const int MA_Default_BackTrackQueueSize = 20;
const int MA_Default_RefreshThreads = 6;
const float MA_Default_Read_Interval = 0.5;
