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

#import <Foundation/Foundation.h>
#import "SQLDatabase.h"
#import "Folder.h"
#import "Field.h"
#import "Criteria.h"

@interface Database : NSObject {
	SQLDatabase * sqlDatabase;
	BOOL initializedFoldersArray;
	BOOL initializedSmartFoldersArray;
	BOOL readOnly;
	int databaseVersion;
	int countOfUnread;
	NSThread * mainThread;
	BOOL inTransaction;
	Folder * trashFolder;
	NSMutableArray * fieldsOrdered;
	NSMutableDictionary * fieldsByName;
	NSMutableDictionary * fieldsByTitle;
	NSMutableDictionary * foldersArray;
	NSMutableDictionary * smartFoldersArray;
}

// General database functions
+(Database *)sharedDatabase;
-(BOOL)initDatabase:(NSString *)databaseFileName;
-(void)syncLastUpdate;
-(int)databaseVersion;
-(void)beginTransaction;
-(void)commitTransaction;
-(void)compactDatabase;
-(int)countOfUnread;
-(BOOL)readOnly;
-(void)close;

// Fields functions
-(void)addField:(NSString *)name type:(int)type tag:(int)tag sqlField:(NSString *)sqlField visible:(BOOL)visible width:(int)width;
-(NSArray *)arrayOfFields;
-(Field *)fieldByName:(NSString *)name;

// Folder functions
-(void)initFolderArray;
-(int)firstFolderId;
-(int)trashFolderId;
-(NSArray *)arrayOfAllFolders;
-(NSArray *)arrayOfFolders:(int)parentId;
-(Folder *)folderFromID:(int)wantedId;
-(Folder *)folderFromFeedURL:(NSString *)wantedFeedURL;
-(Folder *)folderFromName:(NSString *)wantedName;
-(int)addFolder:(int)parentId afterChild:(int)predecessorId folderName:(NSString *)name type:(int)type canAppendIndex:(BOOL)canAppendIndex;
-(BOOL)deleteFolder:(int)folderId;
-(BOOL)setFolderName:(int)folderId newName:(NSString *)newName;
-(BOOL)setFolderDescription:(int)folderId newDescription:(NSString *)newDescription;
-(BOOL)setFolderHomePage:(int)folderId newHomePage:(NSString *)newLink;
-(BOOL)setFolderFeedURL:(int)folderId newFeedURL:(NSString *)newFeedURL;
-(BOOL)setFolderUsername:(int)folderId newUsername:(NSString *)name;
-(void)purgeDeletedArticles;
-(void)purgeArticlesOlderThanDays:(int)daysToKeep;
-(BOOL)markFolderRead:(int)folderId;
-(void)clearFolderFlag:(int)folderId flagToClear:(unsigned int)flag;
-(void)setFolderFlag:(int)folderId flagToSet:(unsigned int)flag;
-(void)setFolderUnreadCount:(Folder *)folder adjustment:(int)adjustment;
-(void)setFolderLastUpdate:(int)folderId lastUpdate:(NSDate *)lastUpdate;
-(void)setFolderLastUpdateString:(int)folderId lastUpdateString:(NSString *)lastUpdateString;
-(BOOL)setParent:(int)newParentID forFolder:(int)folderId;
-(BOOL)setFirstChild:(int)childId forFolder:(int)folderId;
-(BOOL)setNextSibling:(int)nextSiblingId forFolder:(int)folderId;
-(BOOL)setBloglinesId:(int)folderId newBloglinesId:(long)bloglinesId;
-(void)handleAutoSortFoldersTreeChange:(NSNotification *)notification;

// RSS folder functions
+(NSString *)untitledFeedFolderName;
-(int)addRSSFolder:(NSString *)feedName underParent:(int)parentId afterChild:(int)predecessorId subscriptionURL:(NSString *)url;

// smart folder functions
-(void)initSmartFoldersArray;
-(int)addSmartFolder:(NSString *)folderName underParent:(int)parentId withQuery:(CriteriaTree *)criteriaTree;
-(BOOL)updateSearchFolder:(int)folderId withFolder:(NSString *)folderName withQuery:(CriteriaTree *)criteriaTree;
-(CriteriaTree *)searchStringForSearchFolder:(int)folderId;
-(NSString *)criteriaToSQL:(CriteriaTree *)criteriaTree;

// Article functions
-(BOOL)createArticle:(int)folderID article:(Article *)article;
-(BOOL)deleteArticle:(int)folderId guid:(NSString *)guid;
-(NSArray *)arrayOfUnreadArticles:(int)folderId;
-(NSArray *)arrayOfArticles:(int)folderId filterString:(NSString *)filterString;
-(void)markArticleRead:(int)folderId guid:(NSString *)guid isRead:(BOOL)isRead;
-(void)markArticleFlagged:(int)folderId guid:(NSString *)guid isFlagged:(BOOL)isFlagged;
-(void)markArticleDeleted:(int)folderId guid:(NSString *)guid isDeleted:(BOOL)isDeleted;
-(BOOL)isTrashEmpty;

@end
