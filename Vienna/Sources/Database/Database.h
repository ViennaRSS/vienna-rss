//
//  Database.h
//  Vienna
//
//  Created by Steve on Tue Feb 03 2004.
//  Copyright (c) 2004-2017 Steve Palmer and Vienna contributors. All rights reserved.
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

@import Foundation;
@import FMDB;

@class Folder;
@class Field;
@class CriteriaTree;
@class Article;

@interface Database : NSObject

extern NSNotificationName const VNADatabaseWillDeleteFolderNotification;
extern NSNotificationName const VNADatabaseDidDeleteFolderNotification;

@property(nonatomic) Folder * trashFolder;
@property(nonatomic) Folder * searchFolder;
@property(nonatomic) FMDatabaseQueue * databaseQueue;
@property (copy, nonatomic) NSString *searchString;

@property (class, readonly) Database *sharedManager NS_SWIFT_NAME(shared);

// General database functions
- (instancetype)initWithDatabaseAtPath:(NSString *)dbPath /*NS_DESIGNATED_INITIALIZER*/;
-(void)syncLastUpdate;
-(void)compactDatabase;
-(void)reindexDatabase;
@property (nonatomic, readonly) NSInteger countOfUnread;
@property (nonatomic, readonly) NSInteger databaseVersion;
@property (nonatomic, readonly) BOOL readOnly;
-(void)close;

// Fields functions
-(void)addField:(NSString *)name type:(NSInteger)type tag:(NSInteger)tag sqlField:(NSString *)sqlField visible:(BOOL)visible width:(NSInteger)width;
-(NSArray *)arrayOfFields;
-(Field *)fieldByName:(NSString *)name;

// Folder functions
@property (nonatomic, readonly) NSInteger firstFolderId;
@property (nonatomic, readonly) NSInteger trashFolderId;
@property (nonatomic, readonly) NSInteger searchFolderId;
-(NSArray *)arrayOfAllFolders;
-(NSArray *)arrayOfFolders:(NSInteger)parentId;
-(Folder *)folderFromID:(NSInteger)wantedId;
-(Folder *)folderFromFeedURL:(NSString *)wantedFeedURL;
-(Folder *)folderFromRemoteId:(NSString *)wantedRemoteId;
-(Folder *)folderFromName:(NSString *)wantedName;
-(NSInteger)addFolder:(NSInteger)parentId afterChild:(NSInteger)predecessorId folderName:(NSString *)name type:(NSInteger)type canAppendIndex:(BOOL)canAppendIndex;
-(BOOL)deleteFolder:(NSInteger)folderId;
-(BOOL)setName:(NSString *)newName forFolder:(NSInteger)folderId;
-(BOOL)setDescription:(NSString *)newDescription forFolder:(NSInteger)folderId;
-(BOOL)setHomePage:(NSString *)homePageURL forFolder:(NSInteger)folderId;
-(BOOL)setFeedURL:(NSString *)feed_url forFolder:(NSInteger)folderId;
-(BOOL)setRemoteId:(NSString *)remoteId forFolder:(NSInteger)folderId;
-(BOOL)setFolderUsername:(NSInteger)folderId newUsername:(NSString *)name;
-(void)purgeDeletedArticles;
-(void)purgeArticlesOlderThanTag:(NSUInteger)tag;
-(BOOL)markFolderRead:(NSInteger)folderId;
-(void)clearFlag:(NSUInteger)flag forFolder:(NSInteger)folderId;
-(void)setFlag:(NSUInteger)flag forFolder:(NSInteger)folderId;
-(void)setFolderUnreadCount:(Folder *)folder adjustment:(NSUInteger)adjustment;
-(void)setLastUpdate:(NSDate *)lastUpdate forFolder:(NSInteger)folderId;
-(void)setLastUpdateString:(NSString *)lastUpdateString forFolder:(NSInteger)folderId;
-(BOOL)setParent:(NSInteger)newParentID forFolder:(NSInteger)folderId;
-(BOOL)setFirstChild:(NSInteger)childId forFolder:(NSInteger)folderId;
-(BOOL)setNextSibling:(NSUInteger)nextSiblingId forFolder:(NSInteger)folderId;
-(NSArray *)minimalCacheForFolder:(NSInteger)folderId;
-(void)handleAutoSortFoldersTreeChange:(NSNotification *)notification;

// RSS folder functions
+(NSString *)untitledFeedFolderName;
-(NSInteger)addRSSFolder:(NSString *)feedName underParent:(NSInteger)parentId afterChild:(NSInteger)predecessorId subscriptionURL:(NSString *)url;

// Open Reader folder functions
-(NSInteger)addOpenReaderFolder:(NSString *)feedName underParent:(NSInteger)parentId afterChild:(NSInteger)predecessorId
        subscriptionURL:(NSString *)url remoteId:(NSString *)remoteId;

// Smart folder functions
-(void)initSmartfoldersDict;
-(NSInteger)addSmartFolder:(NSString *)folderName underParent:(NSInteger)parentId withQuery:(CriteriaTree *)criteriaTree;
-(void)updateSearchFolder:(NSInteger)folderId withFolder:(NSString *)folderName withQuery:(CriteriaTree *)criteriaTree;
-(CriteriaTree *)searchStringForSmartFolder:(NSInteger)folderId;
-(NSString *)criteriaToSQL:(CriteriaTree *)criteriaTree;

// Article functions
-(BOOL)addArticle:(Article *)article toFolder:(NSInteger)folderID;
-(BOOL)updateArticle:(Article *)existingArticle ofFolder:(NSInteger)folderID withArticle:(Article *)article;
-(BOOL)deleteArticle:(Article *)article;
-(NSArray *)arrayOfUnreadArticlesRefs:(NSInteger)folderId;
-(NSArray *)arrayOfArticles:(NSInteger)folderId filterString:(NSString *)filterString;
-(void)markArticleRead:(NSInteger)folderId guid:(NSString *)guid isRead:(BOOL)isRead;
-(void)markArticleFlagged:(NSInteger)folderId guid:(NSString *)guid isFlagged:(BOOL)isFlagged;
-(void)markArticleDeleted:(Article *)article isDeleted:(BOOL)isDeleted;
-(void)markUnreadArticlesFromFolder:(Folder *)folder guidArray:(NSArray *)guidArray;
-(void)markStarredArticlesFromFolder:(Folder *)folder guidArray:(NSArray *)guidArray;
@property (nonatomic, getter=isTrashEmpty, readonly) BOOL trashEmpty;
-(NSArray *)guidHistoryForFolderId:(NSInteger)folderId;
@end
