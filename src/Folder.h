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

#import <Cocoa/Cocoa.h>
#import "Article.h"

// Folder types
//   VNAFolderTypeRoot = the abstract root folder
//   VNAFolderTypeSmart = the articles are dynamically collected by a custom query
//   VNAFolderTypeGroup = a folder used to group other folders
//   VNAFolderTypeRSS = folder contains RSS articles
//   VNAFolderTypeTrash - a folder that contains deleted articles
//   VNAFolderTypeSearch - a folder that contains a search result
//
typedef NS_ENUM(NSInteger, VNAFolderType) {
    VNAFolderTypeRoot       = -1,
    VNAFolderTypeSmart      = 2,
    VNAFolderTypeGroup      = 3,
    VNAFolderTypeRSS        = 4,
    VNAFolderTypeTrash      = 5,
    VNAFolderTypeSearch     = 6,
    VNAFolderTypeOpenReader = 7
};

// Macros to simplify getting folder types
#define IsSmartFolder(f)		(([(f) type]) == VNAFolderTypeSmart)
#define IsRSSFolder(f)			(([(f) type]) == VNAFolderTypeRSS)
#define IsGroupFolder(f)		(([(f) type]) == VNAFolderTypeGroup)
#define IsTrashFolder(f)		(([(f) type]) == VNAFolderTypeTrash)
#define IsSearchFolder(f)		(([(f) type]) == VNAFolderTypeSearch)
#define IsGoogleReaderFolder(f)	(([(f) type]) == VNAFolderTypeOpenReader)
#define IsSameFolderType(f,g)	(([(f) type]) == ([(g) type]))

// Folder flags
// (These must be bitmask values!)
//   MA_FFlag_CheckForImage = asks the refresh code to update the folder image
//
#define MA_FFlag_CheckForImage		1
#define MA_FFlag_NeedCredentials	2
#define MA_FFlag_Error				4
#define MA_FFlag_Unsubscribed		8
#define MA_FFlag_Updating			16
#define MA_FFlag_LoadFullHTML		32

// Macros for testing folder flags
#define IsUnsubscribed(f)		([(f) flags] & MA_FFlag_Unsubscribed)
#define LoadsFullHTML(f)		([(f) flags] & MA_FFlag_LoadFullHTML)
#define IsUpdating(f)			([(f) nonPersistedFlags] & MA_FFlag_Updating)
#define IsError(f)				([(f) nonPersistedFlags] & MA_FFlag_Error)

@interface Folder : NSObject <NSCacheDelegate> {
	NSInteger itemId;
	NSInteger parentId;
	NSInteger nextSiblingId;
	NSInteger firstChildId;
	NSInteger unreadCount;
	NSInteger childUnreadCount;
	NSUInteger flags;
	NSUInteger nonPersistedFlags;
	BOOL isCached;
	BOOL hasPassword;
	BOOL containsBodies;
	NSDate * lastUpdate;
	NSMutableDictionary * attributes;
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
-(NSArray<Article *> *)articles;
-(NSArray<Article *> *)articlesWithFilter:(NSString *)filterString;
@property (nonatomic, readonly) NSInteger parentId;
@property (nonatomic, readonly) NSInteger itemId;
@property (nonatomic) NSInteger nextSiblingId;
@property (nonatomic) NSInteger firstChildId;
@property (nonatomic, readonly) NSInteger countOfCachedArticles;
@property (nonatomic) NSInteger unreadCount;
@property (nonatomic) VNAFolderType type;
@property (nonatomic, readonly) NSUInteger nonPersistedFlags;
@property (nonatomic, readonly) NSUInteger flags;
@property (nonatomic, copy) NSImage *image;
@property (nonatomic, readonly) BOOL hasCachedImage;
-(NSImage *)standardImage;
@property (nonatomic) NSInteger childUnreadCount;
-(void)clearCache;
@property (nonatomic, getter=isGroupFolder, readonly) BOOL groupFolder;
@property (nonatomic, getter=isSmartFolder, readonly) BOOL smartFolder;
@property (nonatomic, getter=isRSSFolder, readonly) BOOL RSSFolder;
@property (nonatomic, readonly) BOOL loadsFullHTML;
-(void)setParent:(NSInteger)newParent;
-(void)setFlag:(NSUInteger)flagToSet;
-(void)clearFlag:(NSUInteger)flagToClear;
-(void)setNonPersistedFlag:(NSUInteger)flagToSet;
-(void)clearNonPersistedFlag:(NSUInteger)flagToClear;
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
@property (nonatomic, readonly) BOOL hasFeedSource;
@end
