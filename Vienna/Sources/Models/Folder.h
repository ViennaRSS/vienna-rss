//
//  Folder.h
//  Vienna
//
//  Created by Steve on Thu Feb 19 2004.
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

@class Article;

/**
 Folder types
 
 - VNAFolderTypeRoot: the abstract root folder
 - VNAFolderTypeSmart: the articles are dynamically collected by a custom query
 - VNAFolderTypeGroup: a folder used to group other folders
 - VNAFolderTypeRSS: a folder that contains RSS articles
 - VNAFolderTypeTrash: a folder that contains deleted articles
 - VNAFolderTypeSearch: a folder that contains a search result
 - VNAFolderTypeOpenReader: a folder that is on an OpenReader server
 */
typedef NS_ENUM(NSInteger, VNAFolderType) {
    VNAFolderTypeRoot       = -1,
    VNAFolderTypeSmart      = 2,
    VNAFolderTypeGroup      = 3,
    VNAFolderTypeRSS        = 4,
    VNAFolderTypeTrash      = 5,
    VNAFolderTypeSearch     = 6,
    VNAFolderTypeOpenReader = 7
};

/**
 Folder flags
 
 - VNAFolderFlagCheckForImage: asks the refresh code to update the folder image
 - VNAFolderFlagNeedCredentials: feed requires credentials which is not yet obtained
 - VNAFolderFlagError: inform the user that the feed has an error
 - VNAFolderFlagUnsubscribed: currently unsubscribed from the feed
 - VNAFolderFlagUpdating: inform the user that the folder is currently being refreshed
 - VNAFolderFlagLoadFullHTML: load article's web page rather than display feed text
 - VNAFolderFlagSyncedOK: according to available info, no fresher information is available
                          on the OpenReader server
 */
typedef NS_OPTIONS(NSUInteger, VNAFolderFlag) {
    VNAFolderFlagCheckForImage   = 1 << 0,
    VNAFolderFlagNeedCredentials = 1 << 1,
    VNAFolderFlagError           = 1 << 2,
    VNAFolderFlagUnsubscribed    = 1 << 3,
    VNAFolderFlagUpdating        = 1 << 4,
    VNAFolderFlagLoadFullHTML    = 1 << 5,
    VNAFolderFlagSyncedOK        = 1 << 6
};

@interface Folder : NSObject <NSCacheDelegate> {
	NSInteger unreadCount;
	NSInteger childUnreadCount;
    VNAFolderFlag nonPersistedFlags;
    VNAFolderFlag flags;
}

// Initialisation functions
-(instancetype)initWithId:(NSInteger)itemId parentId:(NSInteger)parentId name:(NSString *)name type:(VNAFolderType)type /*NS_DESIGNATED_INITIALIZER*/;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *feedDescription;
@property (nonatomic, copy) NSString *homePage;
@property (nonatomic, copy) NSString *feedURL;
@property (nonatomic, copy) NSDate *lastUpdate;
@property (nonatomic, copy) NSString *lastUpdateString;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, readonly, copy) NSArray<Article *> *articles;
-(NSArray<Article *> *)articlesWithFilter:(NSString *)filterString;
@property (nonatomic, readonly) NSInteger itemId;
@property (nonatomic) NSInteger parentId;
@property (nonatomic) NSInteger nextSiblingId;
@property (nonatomic) NSInteger firstChildId;
@property (atomic, readonly) NSInteger countOfCachedArticles;
@property (atomic) NSInteger unreadCount;
@property (nonatomic) VNAFolderType type;
@property (nonatomic, readonly) VNAFolderFlag nonPersistedFlags;
@property (nonatomic, readonly) VNAFolderFlag flags;
@property (nonatomic, copy) NSImage *image;
@property (nonatomic, readonly) BOOL hasCachedImage;
-(NSImage *)standardImage;
@property (atomic) NSInteger childUnreadCount;
-(void)clearCache;
@property (nonatomic, getter=isGroupFolder, readonly) BOOL groupFolder;
@property (nonatomic, getter=isSmartFolder, readonly) BOOL smartFolder;
@property (nonatomic, getter=isRSSFolder, readonly) BOOL RSSFolder;
@property (nonatomic, getter=isOpenReaderFolder, readonly) BOOL OpenReaderFolder;
@property (nonatomic, readonly) BOOL loadsFullHTML;
@property (nonatomic, getter=isUnsubscribed, readonly) BOOL unsubscribed;
@property (nonatomic, getter=isUpdating, readonly) BOOL updating;
@property (nonatomic, getter=isError, readonly) BOOL error;
@property (nonatomic, getter=isSyncedOK, readonly) BOOL localSynced;
-(void)setFlag:(VNAFolderFlag)flagToSet;
-(void)clearFlag:(VNAFolderFlag)flagToClear;
-(void)setNonPersistedFlag:(VNAFolderFlag)flagToSet;
-(void)clearNonPersistedFlag:(VNAFolderFlag)flagToClear;
-(NSUInteger)indexOfArticle:(Article *)article;
-(Article *)articleFromGuid:(NSString *)guid;
-(BOOL)createArticle:(Article *)article guidHistory:(NSArray *)guidHistory;
-(void)removeArticleFromCache:(NSString *)guid;
-(void)restoreArticleToCache:(Article *)article;
-(void)markArticlesInCacheRead;
-(NSArray *)arrayOfUnreadArticlesRefs;
-(NSComparisonResult)folderNameCompare:(Folder *)otherObject;
-(NSComparisonResult)folderIDCompare:(Folder *)otherObject;
@property (nonatomic, readonly, copy) NSString *feedSourceFilePath;
@end
