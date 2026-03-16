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

@class Folder;

NS_ASSUME_NONNULL_BEGIN

extern NSString * const MA_Field_GUID;
extern NSString * const MA_Field_Subject;
extern NSString * const MA_Field_Author;
extern NSString * const MA_Field_Link;
extern NSString * const MA_Field_LastUpdate;
extern NSString * const MA_Field_Read;
extern NSString * const MA_Field_Flagged;
extern NSString * const MA_Field_Deleted;
extern NSString * const MA_Field_Text;
extern NSString * const MA_Field_Folder;
extern NSString * const MA_Field_Parent;
extern NSString * const MA_Field_Headlines;
extern NSString * const MA_Field_Summary;
extern NSString * const MA_Field_PublicationDate;
extern NSString * const MA_Field_Enclosure;
extern NSString * const MA_Field_EnclosureDownloaded;
extern NSString * const MA_Field_HasEnclosure;

typedef NS_ENUM(NSInteger, ArticleStatus) {
    ArticleStatusEmpty = 0,
    ArticleStatusNew,
    ArticleStatusUpdated
} NS_SWIFT_NAME(Article.Status);

@interface Article : NSObject

- (instancetype)initWithGUID:(NSString *)guid NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic) NSInteger parentId;
@property (nonatomic, copy) NSString *guid;
@property (nullable, nonatomic, copy) NSString *author;
@property (nullable, nonatomic, copy) NSString *body;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *link;
@property (readonly, nullable, nonatomic) NSString *summary;
@property (nullable, nonatomic, copy) NSString *enclosure;
@property (nullable, nonatomic) NSDate *lastUpdate;
@property (nullable, nonatomic) NSDate *publicationDate;
@property (nullable, nonatomic, readonly) Folder *containingFolder;
@property (nonatomic) NSInteger folderId;
@property (nonatomic, getter=isRead) BOOL read;
@property (nonatomic, getter=isRevised) BOOL revised;
@property (nonatomic, getter=isFlagged) BOOL flagged;
@property (nonatomic, getter=isDeleted) BOOL deleted;
@property (nonatomic) BOOL hasEnclosure;
@property (nonatomic) BOOL enclosureDownloaded;
@property (nonatomic) ArticleStatus status;

@end

NS_ASSUME_NONNULL_END
