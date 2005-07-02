//
//  Message.m
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

#import "Message.h"

// The names here must correspond to the messageList identifiers
NSString * MA_Column_MessageId = @"headerNumber";
NSString * MA_Column_MessageTitle = @"headerTitle";
NSString * MA_Column_MessageFrom = @"headerFrom";
NSString * MA_Column_MessageLink = @"headerLink";
NSString * MA_Column_MessageDate = @"headerDate";
NSString * MA_Column_MessageComments = @"headerComments";
NSString * MA_Column_MessageUnread = @"headerUnread";
NSString * MA_Column_MessageFlagged = @"headerFlagged";
NSString * MA_Column_MessageText = @"headerText";
NSString * MA_Column_MessageFolderId = @"headerFolder";
NSString * MA_Column_MessageParentId = @"headerParent";

@implementation Message

/* initWithData
 */
-(id)initWithInfo:(int)newMessageId
{
	if ((self = [super init]) != nil)
	{
		messageData = [[NSMutableDictionary dictionary] retain];
		commentsArray = [[NSMutableArray alloc] init];
		readFlag = NO;
		markedFlag = NO;
		messageStatus = MA_MsgStatus_Empty;
		[self setFolderId:-1];
		[self setNumber:newMessageId];
		[self setParentId:0];
	}
	return self;
}

/* setTitle
 */
-(void)setTitle:(NSString *)newMessageTitle
{
	[messageData setObject:newMessageTitle forKey:MA_Column_MessageTitle];
}

/* setAuthor
 */
-(void)setAuthor:(NSString *)newAuthor
{
	[messageData setObject:newAuthor forKey:MA_Column_MessageFrom];
}

/* setLink
 */
-(void)setLink:(NSString *)newLink
{
	[messageData setObject:newLink forKey:MA_Column_MessageLink];
}

/* setDate
 */
-(void)setDate:(NSDate *)newMessageDate
{
	[messageData setObject:newMessageDate forKey:MA_Column_MessageDate];
}

/* setText
 */
-(void)setText:(NSString *)newText
{
	[messageData setObject:newText forKey:MA_Column_MessageText];
}

/* markRead
 */
-(void)markRead:(BOOL)flag
{
	readFlag = flag;
}

/* markFlagged
 */
-(void)markFlagged:(BOOL)flag
{
	markedFlag = flag;
}

/* Accessor functions
 */
-(NSDictionary *)messageData	{ return messageData; }
-(BOOL)isRead					{ return readFlag; }
-(BOOL)isFlagged				{ return markedFlag; }
-(BOOL)hasComments				{ return [commentsArray count] > 0; }
-(int)status					{ return messageStatus; }
-(int)folderId					{ return [[messageData objectForKey:MA_Column_MessageFolderId] intValue]; }
-(NSString *)author				{ return [messageData objectForKey:MA_Column_MessageFrom]; }
-(NSString *)link				{ return [messageData objectForKey:MA_Column_MessageLink]; }
-(int)number					{ return [[messageData objectForKey:MA_Column_MessageId] intValue]; }
-(int)parentId					{ return [[messageData objectForKey:MA_Column_MessageParentId] intValue]; }
-(NSString *)title				{ return [messageData objectForKey:MA_Column_MessageTitle]; }
-(NSString *)text				{ return [messageData objectForKey:MA_Column_MessageText]; }
-(NSDate *)date					{ return [messageData objectForKey:MA_Column_MessageDate]; }

/* setFolderId
 */
-(void)setFolderId:(int)newFolderId
{
	[messageData setObject:[NSNumber numberWithInt:newFolderId] forKey:MA_Column_MessageFolderId];
}

/* setNumber
 */
-(void)setNumber:(int)newMessageId
{
	[messageData setObject:[NSNumber numberWithInt:newMessageId] forKey:MA_Column_MessageId];
}

/* setParentId
 */
-(void)setParentId:(int)newParentId
{
	[messageData setObject:[NSNumber numberWithInt:newParentId] forKey:MA_Column_MessageParentId];
}

/* setStatus
 */
-(void)setStatus:(int)newStatus
{
	messageStatus = newStatus;
}

/* description
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"Message ID %u (retain=%d)", [self number], [self retainCount]];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[commentsArray release];
	[messageData release];
	[super dealloc];
}
@end
