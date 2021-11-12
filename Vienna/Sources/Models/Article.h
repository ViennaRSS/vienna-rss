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

extern NSString * _Nonnull MA_Field_GUID;
extern NSString * _Nullable MA_Field_Subject;
extern NSString * _Nullable MA_Field_Author;
extern NSString * _Nullable MA_Field_Link;
extern NSString * _Nullable MA_Field_Date;
extern NSString * _Nullable MA_Field_Read;
extern NSString * _Nullable MA_Field_Flagged;
extern NSString * _Nullable MA_Field_Comments;
extern NSString * _Nullable MA_Field_Deleted;
extern NSString * _Nullable MA_Field_Text;
extern NSString * _Nullable MA_Field_Folder;
extern NSString * _Nullable MA_Field_Parent;
extern NSString * _Nullable MA_Field_Headlines;
extern NSString * _Nullable MA_Field_Summary;
extern NSString * _Nullable MA_Field_CreatedDate;
extern NSString * _Nullable MA_Field_Enclosure;
extern NSString * _Nullable MA_Field_EnclosureDownloaded;
extern NSString * _Nullable MA_Field_HasEnclosure;

@class Folder;

// Article field IDs
typedef NS_ENUM(NSInteger, ArticleFieldID) {
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

typedef NS_ENUM(NSInteger, ArticleStatus) {
    ArticleStatusEmpty = 0,
    ArticleStatusNew,
    ArticleStatusUpdated
};

@interface Article : NSObject {
    NSMutableDictionary * articleData;
    NSMutableArray * commentsArray;
    BOOL readFlag;
    BOOL revisedFlag;
    BOOL markedFlag;
    BOOL deletedFlag;
    BOOL enclosureDownloadedFlag;
    BOOL hasEnclosureFlag;
    NSInteger status;
}

// Accessor functions
-(instancetype _Nonnull)initWithGuid:(NSString * _Nonnull)theGuid /*NS_DESIGNATED_INITIALIZER*/;
@property (nonatomic) NSInteger parentId;
@property (nonnull, nonatomic, copy) NSString *guid;
@property (nullable, nonatomic, copy) NSString *author;
@property (nullable, nonatomic, copy) NSString *body;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *link;
@property (readonly, nullable, nonatomic) NSString *summary;
@property (nullable, nonatomic, copy) NSString *enclosure;
@property (nullable, nonatomic, copy) NSDate *date;
@property (nullable, nonatomic, copy) NSDate *createdDate;
@property (nullable, nonatomic, readonly) Folder *containingFolder;
@property (nonatomic) NSInteger folderId;
@property (nonatomic, getter=isRead, readonly) BOOL read;
@property (nonatomic, getter=isRevised, readonly) BOOL revised;
@property (nonatomic, getter=isFlagged, readonly) BOOL flagged;
@property (nonatomic, getter=isDeleted, readonly) BOOL deleted;
@property (nonatomic, readonly) BOOL hasComments;
@property (nonatomic) BOOL hasEnclosure;
@property (nonatomic, readonly) BOOL enclosureDownloaded;
@property (nonatomic) NSInteger status;
-(void)markRead:(BOOL)flag;
-(void)markRevised:(BOOL)flag;
-(void)markFlagged:(BOOL)flag;
-(void)markDeleted:(BOOL)flag;
-(void)markEnclosureDownloaded:(BOOL)flag;

@end
