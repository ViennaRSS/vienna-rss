//
//  Article.h
//  Vienna
//
//  Created by Joshua Pore on 16/11/2014.
//  Copyright (c) 2014 uk.co.opencommunity. All rights reserved.
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

extern NSString *MA_Field_GUID;
extern NSString *MA_Field_Subject;
extern NSString *MA_Field_Author;
extern NSString *MA_Field_Link;
extern NSString *MA_Field_Date;
extern NSString *MA_Field_Read;
extern NSString *MA_Field_Flagged;
extern NSString *MA_Field_Comments;
extern NSString *MA_Field_Deleted;
extern NSString *MA_Field_Text;
extern NSString *MA_Field_Folder;
extern NSString *MA_Field_Parent;
extern NSString *MA_Field_Headlines;
extern NSString *MA_Field_Summary;
extern NSString *MA_Field_CreatedDate;
extern NSString *MA_Field_Enclosure;
extern NSString *MA_Field_EnclosureDownloaded;
extern NSString *MA_Field_HasEnclosure;

@class Folder;

// Article field IDs
typedef NS_ENUM (NSInteger, ArticleFieldID) {
    ArticleFieldIDGUID = 400,
    ArticleFieldIDSubject,
    ArticleFieldIDAuthor,
    ArticleFieldIDDate,
    ArticleFieldIDParent,
    ArticleFieldIDRead,
    ArticleFieldIDFlagged,
    ArticleFieldIDText,
    ArticleFieldIDFolder,
    ArticleFieldIDLink,
    ArticleFieldIDComments,
    ArticleFieldIDHeadlines,
    ArticleFieldIDDeleted,
    ArticleFieldIDSummary,
    ArticleFieldIDCreatedDate, // Not in use?
    ArticleFieldIDEnclosure,
    ArticleFieldIDEnclosureDownloaded,
    ArticleFieldIDHasEnclosure
};

typedef NS_ENUM (NSInteger, ArticleStatus) {
    ArticleStatusEmpty = 0,
    ArticleStatusNew,
    ArticleStatusUpdated
};

@interface Article : NSObject
{
    NSMutableDictionary *articleData;
    NSMutableArray *commentsArray;
    BOOL readFlag;
    BOOL revisedFlag;
    BOOL markedFlag;
    BOOL deletedFlag;
    BOOL enclosureDownloadedFlag;
    BOOL hasEnclosureFlag;
    NSInteger status;
}

// Accessor functions
- (instancetype)initWithGuid:(NSString *)theGuid /*NS_DESIGNATED_INITIALIZER*/;
@property (nonatomic) NSInteger parentId;
@property (nonatomic, copy) NSString *guid;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, readonly, copy) NSString *summary;
@property (nonatomic, copy) NSString *enclosure;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, copy) NSDate *createdDate;
@property (nonatomic, readonly, strong) Folder *containingFolder;
@property (nonatomic) NSInteger folderId;
@property (nonatomic, getter = isRead, readonly) BOOL read;
@property (nonatomic, getter = isRevised, readonly) BOOL revised;
@property (nonatomic, getter = isFlagged, readonly) BOOL flagged;
@property (nonatomic, getter = isDeleted, readonly) BOOL deleted;
@property (nonatomic, readonly) BOOL hasComments;
@property (nonatomic) BOOL hasEnclosure;
@property (nonatomic, readonly) BOOL enclosureDownloaded;
@property (nonatomic) NSInteger status;
- (void)markRead:(BOOL)flag;
- (void)markRevised:(BOOL)flag;
- (void)markFlagged:(BOOL)flag;
- (void)markDeleted:(BOOL)flag;
- (void)markEnclosureDownloaded:(BOOL)flag;
- (NSString *)expandTags:(NSString *)theString withConditional:(BOOL)cond;

@end
