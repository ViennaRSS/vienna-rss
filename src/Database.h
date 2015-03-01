//
//  Database.h
//  Vienna
//
//  Created by Steve on Tue Feb 03 2004.
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
#import "FMDB.h"
#import "Folder.h"
#import "Field.h"
#import "Criteria.h"

@interface Database : NSObject {
	BOOL initializedfoldersDict;
	BOOL initializedSmartfoldersDict;
	BOOL readOnly;
	int databaseVersion;
	int countOfUnread;
	NSThread * mainThread;
	BOOL inTransaction;
	NSString * searchString;
	NSMutableArray * fieldsOrdered;
	NSMutableDictionary * fieldsByName;
	NSMutableDictionary * fieldsByTitle;
	NSMutableDictionary * foldersDict;
	NSMutableDictionary * smartfoldersDict;
	dispatch_queue_t _transactionQueue;
	dispatch_queue_t _execQueue;
	Folder * trashFolder;
	Folder * searchFolder;
    FMDatabaseQueue *databaseQueue;
}

@property(nonatomic, retain) Folder * trashFolder;
@property(nonatomic, retain) Folder * searchFolder;
@property(nonatomic, retain) FMDatabaseQueue * databaseQueue;

// General database functions
+(instancetype)sharedManager;
-(BOOL)initDatabase;
-(void)syncLastUpdate;
-(NSInteger)databaseVersion;
-(void)compactDatabase;
-(void)reindexDatabase;
-(NSInteger)countOfUnread;
-(BOOL)readOnly;
-(void)close;

// Fields functions
-(void)addField:(NSString *)name type:(NSInteger)type tag:(NSInteger)tag sqlField:(NSString *)sqlField visible:(BOOL)visible width:(NSInteger)width;
-(NSArray *)arrayOfFields;
-(Field *)fieldByName:(NSString *)name;

// Folder functions
-(void)initFolderArray;
-(NSInteger)firstFolderId;
-(NSInteger)trashFolderId;
-(NSInteger)searchFolderId;
-(NSArray *)arrayOfAllFolders;
-(NSArray *)arrayOfFolders:(NSInteger)parentId;
-(Folder *)folderFromID:(NSInteger)wantedId;
-(Folder *)folderFromFeedURL:(NSString *)wantedFeedURL;
-(Folder *)folderFromName:(NSString *)wantedName;
-(NSInteger)addFolder:(NSInteger)parentId afterChild:(NSInteger)predecessorId folderName:(NSString *)name type:(NSInteger)type canAppendIndex:(BOOL)canAppendIndex;
-(BOOL)deleteFolder:(NSInteger)folderId;
-(BOOL)setFolderName:(NSInteger)folderId newName:(NSString *)newName;
-(BOOL)setFolderDescription:(NSInteger)folderId newDescription:(NSString *)newDescription;
-(BOOL)setFolderHomePage:(NSInteger)folderId newHomePage:(NSString *)newLink;
-(BOOL)setFolderFeedURL:(NSInteger)folderId newFeedURL:(NSString *)newFeedURL;
-(BOOL)setFolderUsername:(NSInteger)folderId newUsername:(NSString *)name;
-(void)purgeDeletedArticles;
-(void)purgeArticlesOlderThanDays:(NSUInteger)daysToKeep;
-(BOOL)markFolderRead:(NSInteger)folderId;
-(void)clearFolderFlag:(NSInteger)folderId flagToClear:(NSUInteger)flag;
-(void)setFolderFlag:(NSInteger)folderId flagToSet:(NSUInteger)flag;
-(void)setFolderUnreadCount:(Folder *)folder adjustment:(NSUInteger)adjustment;
-(void)setFolderLastUpdate:(NSInteger)folderId lastUpdate:(NSDate *)lastUpdate;
-(void)setFolderLastUpdateString:(NSInteger)folderId lastUpdateString:(NSString *)lastUpdateString;
-(BOOL)setParent:(NSInteger)newParentID forFolder:(NSInteger)folderId;
-(BOOL)setFirstChild:(NSInteger)childId forFolder:(NSInteger)folderId;
-(BOOL)setNextSibling:(NSUInteger)nextSiblingId forFolder:(NSInteger)folderId;
-(void)handleAutoSortFoldersTreeChange:(NSNotification *)notification;

// RSS folder functions
+(NSString *)untitledFeedFolderName;
-(NSInteger)addRSSFolder:(NSString *)feedName underParent:(NSInteger)parentId afterChild:(NSInteger)predecessorId subscriptionURL:(NSString *)url;

// Open Reader folder functions
-(NSInteger)addGoogleReaderFolder:(NSString *)feedName underParent:(NSInteger)parentId afterChild:(NSInteger)predecessorId subscriptionURL:(NSString *)url;

// Search folder functions
-(void)setSearchString:(NSString *)newSearchString;

// Smart folder functions
-(void)initSmartfoldersDict;
-(NSInteger)addSmartFolder:(NSString *)folderName underParent:(NSInteger)parentId withQuery:(CriteriaTree *)criteriaTree;
-(BOOL)updateSearchFolder:(NSInteger)folderId withFolder:(NSString *)folderName withQuery:(CriteriaTree *)criteriaTree;
-(CriteriaTree *)searchStringForSmartFolder:(NSInteger)folderId;
-(NSString *)criteriaToSQL:(CriteriaTree *)criteriaTree;

// Article functions
-(BOOL)createArticle:(NSInteger)folderID article:(Article *)article guidHistory:(NSArray *)guidHistory;
-(BOOL)deleteArticle:(NSInteger)folderId guid:(NSString *)guid;
-(NSArray *)arrayOfUnreadArticlesRefs:(NSInteger)folderId;
-(NSArray *)arrayOfArticles:(NSInteger)folderId filterString:(NSString *)filterString;
-(void)markArticleRead:(NSInteger)folderId guid:(NSString *)guid isRead:(BOOL)isRead;
-(void)markArticleFlagged:(NSInteger)folderId guid:(NSString *)guid isFlagged:(BOOL)isFlagged;
-(void)markArticleDeleted:(NSInteger)folderId guid:(NSString *)guid isDeleted:(BOOL)isDeleted;
-(void)markUnreadArticlesFromFolder:(Folder *)folder guidArray:(NSArray *)guidArray;
-(void)markStarredArticlesFromFolder:(Folder *)folder guidArray:(NSArray *)guidArray;
-(BOOL)isTrashEmpty;
-(NSArray *)guidHistoryForFolderId:(NSInteger)folderId;
@end
