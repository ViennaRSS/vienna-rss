//
//  Message.h
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

#import <Foundation/Foundation.h>

extern NSString * MA_Field_GUID;
extern NSString * MA_Field_Subject;
extern NSString * MA_Field_Author;
extern NSString * MA_Field_Link;
extern NSString * MA_Field_Date;
extern NSString * MA_Field_Read;
extern NSString * MA_Field_Flagged;
extern NSString * MA_Field_Comments;
extern NSString * MA_Field_Deleted;
extern NSString * MA_Field_Text;
extern NSString * MA_Field_Folder;
extern NSString * MA_Field_Parent;
extern NSString * MA_Field_Headlines;
extern NSString * MA_Field_Summary;

// Article status values
#define MA_MsgStatus_Empty		0
#define MA_MsgStatus_New		1
#define MA_MsgStatus_Updated	2

// Article field IDs
#define MA_FieldID_GUID			400
#define MA_FieldID_Subject		401
#define MA_FieldID_Author		402
#define MA_FieldID_Date			403
#define MA_FieldID_Parent		404
#define MA_FieldID_Read			405
#define MA_FieldID_Flagged		406
#define MA_FieldID_Text			407
#define MA_FieldID_Folder		408
#define MA_FieldID_Link			409
#define MA_FieldID_Comments		410
#define MA_FieldID_Headlines	411
#define MA_FieldID_Deleted		412
#define MA_FieldID_Summary		413

@class Folder;
@interface Article : NSObject {
	NSMutableDictionary * articleData;
	NSMutableArray * commentsArray;
	BOOL readFlag;
	BOOL markedFlag;
	BOOL deletedFlag;
	int status;
}

// Accessor functions
-(id)initWithGuid:(NSString *)theGuid;
-(int)parentId;
-(NSString *)guid;
-(NSString *)author;
-(NSString *)body;
-(NSString *)title;
-(NSString *)link;
-(NSString *)summary;
-(NSDate *)date;
-(Folder *)containingFolder;
-(int)folderId;
-(BOOL)isRead;
-(BOOL)isFlagged;
-(BOOL)isDeleted;
-(BOOL)hasComments;
-(int)status;
-(void)setGuid:(NSString *)newGuid;
-(void)setParentId:(int)newParentId;
-(void)setTitle:(NSString *)newTitle;
-(void)setLink:(NSString *)newLink;
-(void)setAuthor:(NSString *)newAuthor;
-(void)setFolderId:(int)newFolderId;
-(void)setDate:(NSDate *)newDate;
-(void)setBody:(NSString *)newText;
-(void)setSummary:(NSString *)newSummary;
-(void)setStatus:(int)newStatus;
-(void)markRead:(BOOL)flag;
-(void)markFlagged:(BOOL)flag;
-(void)markDeleted:(BOOL)flag;
-(NSDictionary *)articleData;
@end
