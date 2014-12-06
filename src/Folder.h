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
//   MA_Root_Folder = the abstract root folder
//   MA_Smart_Folder = the articles are dynamically collected by a custom query
//   MA_Group_Folder = a folder used to group other folders
//   MA_RSS_Folder = folder contains RSS articles
//   MA_Trash_Folder - a folder that contains deleted articles
//   MA_Search_Folder - a folder that contains a search result
//
#define MA_Root_Folder			-1
#define MA_Smart_Folder			2
#define MA_Group_Folder			3
#define MA_RSS_Folder			4
#define MA_Trash_Folder			5
#define MA_Search_Folder		6
#define MA_GoogleReader_Folder	7

// Macros to simplify getting folder types
#define FolderType(f)			([(f) type])
#define IsSmartFolder(f)		(([(f) type]) == MA_Smart_Folder)
#define IsRSSFolder(f)			(([(f) type]) == MA_RSS_Folder)
#define IsGroupFolder(f)		(([(f) type]) == MA_Group_Folder)
#define IsTrashFolder(f)		(([(f) type]) == MA_Trash_Folder)
#define IsSearchFolder(f)		(([(f) type]) == MA_Search_Folder)
#define IsGoogleReaderFolder(f)	(([(f) type]) == MA_GoogleReader_Folder)
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

@interface Folder : NSObject {
	NSInteger itemId;
	NSInteger parentId;
	NSInteger nextSiblingId;
	NSInteger firstChildId;
	NSInteger unreadCount;
	NSInteger type;
	NSInteger childUnreadCount;
	NSUInteger flags;
	NSUInteger nonPersistedFlags;
	BOOL isCached;
	BOOL hasPassword;
	NSDate * lastUpdate;
	NSMutableDictionary * attributes;
	NSMutableDictionary * cachedArticles;
}

// Initialisation functions
-(id)initWithId:(NSInteger)itemId parentId:(NSInteger)parentId name:(NSString *)name type:(NSInteger)type;
-(NSString *)name;
-(NSString *)feedDescription;
-(NSString *)homePage;
-(NSString *)feedURL;
-(NSDate *)lastUpdate;
-(NSString *)lastUpdateString;
-(NSString *)username;
-(NSString *)password;
-(NSDictionary *)attributes;
-(NSArray *)articles;
-(NSArray *)articlesWithFilter:(NSString *)fstring;
-(NSInteger)parentId;
-(NSInteger)itemId;
-(NSInteger)nextSiblingId;
-(NSInteger)firstChildId;
-(NSInteger)countOfCachedArticles;
-(NSInteger)unreadCount;
-(NSInteger)type;
-(NSUInteger)nonPersistedFlags;
-(NSUInteger)flags;
-(NSImage *)image;
-(BOOL)hasCachedImage;
-(NSImage *)standardImage;
-(NSInteger)childUnreadCount;
-(void)clearCache;
-(BOOL)isGroupFolder;
-(BOOL)isSmartFolder;
-(BOOL)isRSSFolder;
-(BOOL)loadsFullHTML;
-(void)setName:(NSString *)name;
-(void)setUnreadCount:(NSInteger)count;
-(void)setType:(NSInteger)newType;
-(void)setParent:(NSInteger)newParent;
-(void)setNextSiblingId:(NSInteger)newNextSibling;
-(void)setFirstChildId:(NSInteger)newFirstChild;
-(void)setImage:(NSImage *)newImage;
-(void)setFlag:(NSUInteger)flagToSet;
-(void)clearFlag:(NSUInteger)flagToClear;
-(void)setNonPersistedFlag:(NSUInteger)flagToSet;
-(void)clearNonPersistedFlag:(NSUInteger)flagToClear;
-(void)setChildUnreadCount:(NSInteger)count;
-(void)setFeedDescription:(NSString *)newFeedDescription;
-(void)setHomePage:(NSString *)newHomePage;
-(void)setFeedURL:(NSString *)feedURL;
-(void)setUsername:(NSString *)newUsername;
-(void)setPassword:(NSString *)newPassword;
-(void)setLastUpdate:(NSDate *)newLastUpdate;
-(void)setLastUpdateString:(NSString *)newLastUpdateString;
-(unsigned)indexOfArticle:(Article *)article;
-(Article *)articleFromGuid:(NSString *)guid;
-(void)addArticleToCache:(Article *)newArticle;
-(void)removeArticleFromCache:(NSString *)guid;
-(void)markFolderEmpty;
-(NSComparisonResult)folderNameCompare:(Folder *)otherObject;
-(NSComparisonResult)folderIDCompare:(Folder *)otherObject;
-(NSString *)feedSourceFilePath;
-(BOOL)hasFeedSource;
@end
