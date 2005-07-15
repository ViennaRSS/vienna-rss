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

extern NSString * MA_Column_MessageId;
extern NSString * MA_Column_MessageTitle;
extern NSString * MA_Column_MessageFrom;
extern NSString * MA_Column_MessageLink;
extern NSString * MA_Column_MessageDate;
extern NSString * MA_Column_MessageUnread;
extern NSString * MA_Column_MessageFlagged;
extern NSString * MA_Column_MessageComments;
extern NSString * MA_Column_MessageText;
extern NSString * MA_Column_MessageFolderId;
extern NSString * MA_Column_MessageParentId;
extern NSString * MA_Column_MessageSummary;

// Custom values for message IDs
#define MA_MsgID_New			-1
#define MA_MsgID_RSSNew			-2

// Message status values
#define MA_MsgStatus_Empty		0
#define MA_MsgStatus_New		1
#define MA_MsgStatus_Updated	2

// Message field IDs
#define MA_ID_MessageId				400
#define MA_ID_MessageTitle			401
#define MA_ID_MessageFrom			402
#define MA_ID_MessageDate			403
#define MA_ID_MessageParentId		404
#define MA_ID_MessageUnread			405
#define MA_ID_MessageFlagged		406
#define MA_ID_MessageText			407
#define MA_ID_MessageFolderId		408
#define MA_ID_MessageLink			409
#define MA_ID_MessageComments		410
#define MA_ID_MessageSummary		411

@interface Message : NSObject {
	NSMutableDictionary * messageData;
	NSMutableArray * commentsArray;
	BOOL readFlag;
	BOOL markedFlag;
	int messageStatus;
}

// Accessor functions
-(id)initWithInfo:(int)messageId;
-(int)number;
-(int)parentId;
-(NSString *)author;
-(NSString *)text;
-(NSString *)title;
-(NSString *)link;
-(NSDate *)date;
-(int)folderId;
-(BOOL)isRead;
-(BOOL)isFlagged;
-(BOOL)hasComments;
-(int)status;
-(void)setNumber:(int)newMessageId;
-(void)setParentId:(int)newParentId;
-(void)setTitle:(NSString *)newMessageTitle;
-(void)setLink:(NSString *)newLink;
-(void)setAuthor:(NSString *)newAuthor;
-(void)setFolderId:(int)newFolderId;
-(void)setDate:(NSDate *)newMessageDate;
-(void)setText:(NSString *)newText;
-(void)setStatus:(int)newStatus;
-(void)markRead:(BOOL)flag;
-(void)markFlagged:(BOOL)flag;
-(NSDictionary *)messageData;
@end
