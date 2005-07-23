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
NSString * MA_Field_Number = @"Number";
NSString * MA_Field_Subject = @"Subject";
NSString * MA_Field_Author = @"Author";
NSString * MA_Field_Link = @"Link";
NSString * MA_Field_Date = @"Date";
NSString * MA_Field_Comments = @"Comments";
NSString * MA_Field_Read = @"Read";
NSString * MA_Field_Flagged = @"Flagged";
NSString * MA_Field_Text = @"Text";
NSString * MA_Field_Folder = @"Folder";
NSString * MA_Field_Parent = @"Parent";
NSString * MA_Field_Headlines = @"Headlines";

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
	[messageData setObject:newMessageTitle forKey:MA_Field_Subject];
}

/* setAuthor
 */
-(void)setAuthor:(NSString *)newAuthor
{
	[messageData setObject:newAuthor forKey:MA_Field_Author];
}

/* setLink
 */
-(void)setLink:(NSString *)newLink
{
	[messageData setObject:newLink forKey:MA_Field_Link];
}

/* setDate
 */
-(void)setDate:(NSDate *)newMessageDate
{
	[messageData setObject:newMessageDate forKey:MA_Field_Date];
}

/* setText
 */
-(void)setText:(NSString *)newText
{
	[messageData setObject:newText forKey:MA_Field_Text];
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
-(int)folderId					{ return [[messageData objectForKey:MA_Field_Folder] intValue]; }
-(NSString *)author				{ return [messageData objectForKey:MA_Field_Author]; }
-(NSString *)link				{ return [messageData objectForKey:MA_Field_Link]; }
-(int)number					{ return [[messageData objectForKey:MA_Field_Number] intValue]; }
-(int)parentId					{ return [[messageData objectForKey:MA_Field_Parent] intValue]; }
-(NSString *)title				{ return [messageData objectForKey:MA_Field_Subject]; }
-(NSString *)text				{ return [messageData objectForKey:MA_Field_Text]; }
-(NSDate *)date					{ return [messageData objectForKey:MA_Field_Date]; }

/* setFolderId
 */
-(void)setFolderId:(int)newFolderId
{
	[messageData setObject:[NSNumber numberWithInt:newFolderId] forKey:MA_Field_Folder];
}

/* setNumber
 */
-(void)setNumber:(int)newMessageId
{
	[messageData setObject:[NSNumber numberWithInt:newMessageId] forKey:MA_Field_Number];
}

/* setParentId
 */
-(void)setParentId:(int)newParentId
{
	[messageData setObject:[NSNumber numberWithInt:newParentId] forKey:MA_Field_Parent];
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
