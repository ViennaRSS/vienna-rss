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
#import "Database.h"

// The names here are internal field names, not for localisation.
NSString * MA_Field_GUID = @"GUID";
NSString * MA_Field_Subject = @"Subject";
NSString * MA_Field_Author = @"Author";
NSString * MA_Field_Link = @"Link";
NSString * MA_Field_Date = @"Date";
NSString * MA_Field_Comments = @"Comments";
NSString * MA_Field_Read = @"Read";
NSString * MA_Field_Flagged = @"Flagged";
NSString * MA_Field_Deleted = @"Deleted";
NSString * MA_Field_Text = @"Text";
NSString * MA_Field_Folder = @"Folder";
NSString * MA_Field_Parent = @"Parent";
NSString * MA_Field_Headlines = @"Headlines";
NSString * MA_Field_Summary = @"Summary";
NSString * MA_Field_CreatedDate = @"CreatedDate";

@implementation Article

/* initWithGuid
 */
-(id)initWithGuid:(NSString *)theGuid
{
	if ((self = [super init]) != nil)
	{
		articleData = [[NSMutableDictionary dictionary] retain];
		commentsArray = [[NSMutableArray alloc] init];
		readFlag = NO;
		revisedFlag = NO;
		markedFlag = NO;
		deletedFlag = NO;
		status = MA_MsgStatus_Empty;
		[self setFolderId:-1];
		[self setGuid:theGuid];
		[self setParentId:0];
	}
	return self;
}

/* setTitle
 */
-(void)setTitle:(NSString *)newTitle
{
	[articleData setObject:newTitle forKey:MA_Field_Subject];
}

/* setAuthor
 */
-(void)setAuthor:(NSString *)newAuthor
{
	[articleData setObject:newAuthor forKey:MA_Field_Author];
}

/* setLink
 */
-(void)setLink:(NSString *)newLink
{
	[articleData setObject:newLink forKey:MA_Field_Link];
}

/* setDate
 * Sets the date when the article was published.
 */
-(void)setDate:(NSDate *)newDate
{
	[articleData setObject:newDate forKey:MA_Field_Date];
}

/* setCreatedDate
 * Sets the date when the article was first created in the database.
 */
-(void)setCreatedDate:(NSDate *)newCreatedDate
{
	[articleData setObject:newCreatedDate forKey:MA_Field_CreatedDate];
}

/* setBody
 */
-(void)setBody:(NSString *)newText
{
	[articleData setObject:newText forKey:MA_Field_Text];
}

/* setSummary
 */
-(void)setSummary:(NSString *)newSummary
{
	[articleData setObject:newSummary forKey:MA_Field_Summary];
}

/* markRead
 */
-(void)markRead:(BOOL)flag
{
	readFlag = flag;
}

/* markRevised
 */
-(void)markRevised:(BOOL)flag
{
	revisedFlag = flag;
}

/* markFlagged
 */
-(void)markFlagged:(BOOL)flag
{
	markedFlag = flag;
}

/* markDeleted
 */
-(void)markDeleted:(BOOL)flag
{
	deletedFlag = flag;
}

/* Accessor functions
 */
-(NSDictionary *)articleData	{ return articleData; }
-(BOOL)isRead					{ return readFlag; }
-(BOOL)isRevised				{ return revisedFlag; }
-(BOOL)isFlagged				{ return markedFlag; }
-(BOOL)isDeleted				{ return deletedFlag; }
-(BOOL)hasComments				{ return [commentsArray count] > 0; }
-(int)status					{ return status; }
-(int)folderId					{ return [[articleData objectForKey:MA_Field_Folder] intValue]; }
-(NSString *)author				{ return [articleData objectForKey:MA_Field_Author]; }
-(NSString *)link				{ return [articleData objectForKey:MA_Field_Link]; }
-(NSString *)guid				{ return [articleData objectForKey:MA_Field_GUID]; }
-(int)parentId					{ return [[articleData objectForKey:MA_Field_Parent] intValue]; }
-(NSString *)title				{ return [articleData objectForKey:MA_Field_Subject]; }
-(NSString *)summary			{ return [articleData objectForKey:MA_Field_Summary]; }
-(NSDate *)date					{ return [articleData objectForKey:MA_Field_Date]; }
-(NSDate *)createdDate;			{ return [articleData objectForKey:MA_Field_CreatedDate]; }
-(NSString *)body				{ return [articleData objectForKey:MA_Field_Text]; }

/* containingFolder
 */
-(Folder *)containingFolder
{
	return [[Database sharedDatabase] folderFromID:[self folderId]];
}

/* setFolderId
 */
-(void)setFolderId:(int)newFolderId
{
	[articleData setObject:[NSNumber numberWithInt:newFolderId] forKey:MA_Field_Folder];
}

/* setGuid
 */
-(void)setGuid:(NSString *)newGuid
{
	[articleData setObject:newGuid forKey:MA_Field_GUID];
}

/* setParentId
 */
-(void)setParentId:(int)newParentId
{
	[articleData setObject:[NSNumber numberWithInt:newParentId] forKey:MA_Field_Parent];
}

/* setStatus
 */
-(void)setStatus:(int)newStatus
{
	status = newStatus;
}

/* description
 * Return a human readable description of this article for debugging.
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"{GUID=%@ title=\"%@\"", [self guid], [self title]];
}

/* objectSpecifier
 * Create an object specifier for this object using the folder container.
 */
-(NSScriptObjectSpecifier *)objectSpecifier
{
	Folder * folder = [[Database sharedDatabase] folderFromID:[self folderId]];
	unsigned index = [folder indexOfArticle:self];
	if (index != NSNotFound)
	{
		NSScriptObjectSpecifier * containerRef = [folder objectSpecifier];
		return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:(NSScriptClassDescription *)[Folder classDescription]
																			 containerSpecifier:containerRef
																							key:@"articles"
																						  index:index] autorelease];
	}
	return nil;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[commentsArray release];
	[articleData release];
	[super dealloc];
}
@end
