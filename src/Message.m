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
#import "StringExtensions.h"
#import "XMLParser.h"
#import "CalendarExtensions.h"

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
NSString * MA_Field_Enclosure = @"Enclosure";
NSString * MA_Field_EnclosureDownloaded = @"EnclosureDownloaded";
NSString * MA_Field_HasEnclosure = @"HasEnclosure";

@implementation Article

/* initWithGuid
 */
-(id)initWithGuid:(NSString *)theGuid
{
	if ((self = [super init]) != nil)
	{
		articleData = [[NSMutableDictionary alloc] init];
		commentsArray = [[NSMutableArray alloc] init];
		readFlag = NO;
		revisedFlag = NO;
		markedFlag = NO;
		deletedFlag = NO;
		hasEnclosureFlag = NO;
		enclosureDownloadedFlag = NO;
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
	[articleData removeObjectForKey:MA_Field_Summary];
}

/* setEnclosure
 */
-(void)setEnclosure:(NSString *)newEnclosure
{
	if (newEnclosure)
		[articleData setObject:newEnclosure forKey:MA_Field_Enclosure];
	else
		[articleData removeObjectForKey:MA_Field_Enclosure];
}

/* markEnclosureDownloaded
 */
-(void)markEnclosureDownloaded:(BOOL)flag
{
	enclosureDownloadedFlag = flag;
}

/* setHasEnclosure
 */
-(void)setHasEnclosure:(BOOL)flag
{
	hasEnclosureFlag = flag;
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

/* accessInstanceVariablesDirectly
 * Override this so that KVC doesn't get the articleData ivar
 */
+(BOOL)accessInstanceVariablesDirectly
{
	return NO;
}

/* valueForKeyPath:
 * Override valueForKeyPath: for backward compatibility with article list sort descriptors
 */
-(id)valueForKeyPath:(NSString *)keyPath
{
	if ([keyPath hasPrefix:@"articleData."])
	{
		NSString * key = [keyPath substringFromIndex:[@"articleData." length]];
		if ([key isEqualToString:MA_Field_Date])
		{
			return [self date];
		}
		else if ([key isEqualToString:MA_Field_Author])
		{
			return [self author];
		}
		else if ([key isEqualToString:MA_Field_Subject])
		{
			return [self title];
		}
		else if ([key isEqualToString:MA_Field_Link])
		{
			return [self link];
		}
		else if ([key isEqualToString:MA_Field_Summary])
		{
			return [self summary];
		}
		else
		{
			return [super valueForKeyPath:keyPath];
		}
	}
	else
	{
		return [super valueForKeyPath:keyPath];
	}
}

/* Accessor functions
 */
-(BOOL)isRead					{ return readFlag; }
-(BOOL)isRevised				{ return revisedFlag; }
-(BOOL)isFlagged				{ return markedFlag; }
-(BOOL)isDeleted				{ return deletedFlag; }
-(BOOL)hasComments				{ return [commentsArray count] > 0; }
-(BOOL)hasEnclosure				{ return hasEnclosureFlag; }
-(BOOL)enclosureDownloaded		{ return enclosureDownloadedFlag; }
-(int)status					{ return status; }
-(int)folderId					{ return [[articleData objectForKey:MA_Field_Folder] intValue]; }
-(NSString *)author				{ return [articleData objectForKey:MA_Field_Author]; }
-(NSString *)link				{ return [articleData objectForKey:MA_Field_Link]; }
-(NSString *)guid				{ return [articleData objectForKey:MA_Field_GUID]; }
-(int)parentId					{ return [[articleData objectForKey:MA_Field_Parent] intValue]; }
-(NSString *)title				{ return [articleData objectForKey:MA_Field_Subject]; }
-(NSString *)summary
{
	NSString * summary = [articleData objectForKey:MA_Field_Summary];
	if (summary == nil)
	{
		summary = [[articleData objectForKey:MA_Field_Text] summaryTextFromHTML];
		if (summary == nil)
			summary = @"";
		[articleData setObject:summary forKey:MA_Field_Summary];
	}
	return summary;
}
-(NSDate *)date					{ return [articleData objectForKey:MA_Field_Date]; }
-(NSDate *)createdDate			{ return [articleData objectForKey:MA_Field_CreatedDate]; }
-(NSString *)body				{ return [articleData objectForKey:MA_Field_Text]; }
-(NSString *)enclosure			{ return [articleData objectForKey:MA_Field_Enclosure]; }

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
	NSUInteger index = [folder indexOfArticle:self];
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

/* tagArticleLink
 * Returns the article link as a safe string.
 */
-(NSString *)tagArticleLink
{
	return SafeString([self link]);
}

/* tagArticleTitle
 * Returns the article title.
 */
-(NSString *)tagArticleTitle
{
	NSMutableString * articleTitle = [NSMutableString stringWithString:SafeString([self title])];
	[articleTitle replaceString:@"$Article" withString:@"$_%$%_Article"];
	[articleTitle replaceString:@"$Feed" withString:@"$_%$%_Feed"];
	return [XMLParser quoteAttributes:articleTitle];
}

/* tagArticleBody
 * Returns the article body.
 */
-(NSString *)tagArticleBody
{
	NSMutableString * articleBody = [NSMutableString stringWithString:[self body]];
	[articleBody replaceString:@"$Article" withString:@"$_%$%_Article"];
	[articleBody replaceString:@"$Feed" withString:@"$_%$%_Feed"];
	[articleBody fixupRelativeImgTags:[self link]];
	[articleBody fixupRelativeIframeTags:[self link]];
	[articleBody fixupRelativeAnchorTags:[self link]];
	return articleBody;
}

/* tagArticleAuthor
 * Returns the article author as a safe string.
 */
-(NSString *)tagArticleAuthor
{
	return SafeString([self author]);
}

/* tagArticleDate
 * Returns the article date.
 */
-(NSString *)tagArticleDate
{
	return [[[self date] dateWithCalendarFormat:nil timeZone:nil] friendlyDescription];
}

/* tagArticleEnclosureLink
 * Returns the article enclosure link.
 */
-(NSString *)tagArticleEnclosureLink
{
	return SafeString([self enclosure]);
}

/* tagArticleEnclosureFilename
 * Returns the article enclosure file name.
 */
-(NSString *)tagArticleEnclosureFilename
{
	return SafeString([[[self enclosure] lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]);
}

/* tagFeedTitle
 * Returns the article's feed title.
 */
-(NSString *)tagFeedTitle
{
	Folder * folder = [[Database sharedDatabase] folderFromID:[self folderId]];
	return [XMLParser quoteAttributes:SafeString([folder name])];
}

/* tagFeedLink
 * Returns the article's feed URL.
 */
-(NSString *)tagFeedLink
{
	Folder * folder = [[Database sharedDatabase] folderFromID:[self folderId]];
	return SafeString([folder homePage]);
}

/* tagFeedDescription
 * Returns the article's feed description.
 */
-(NSString *)tagFeedDescription
{
	Folder * folder = [[Database sharedDatabase] folderFromID:[self folderId]];
	return [folder feedDescription];
}

/* expandTags
 * Expands recognised tags in theString based on the object values. If cond is YES and all the
 * tags are empty then return the empty string instead.
 */
-(NSString *)expandTags:(NSString *)theString withConditional:(BOOL)cond
{
	NSMutableString * newString = [NSMutableString stringWithString:theString];
	BOOL hasOneTag = NO;
	NSUInteger tagStartIndex = 0;

	while ((tagStartIndex = [newString indexOfCharacterInString:'$' afterIndex:tagStartIndex]) != NSNotFound)
	{
		NSUInteger tagEndIndex = [newString indexOfCharacterInString:'$' afterIndex:tagStartIndex + 1];
		if (tagEndIndex == NSNotFound)
			break;

		NSUInteger tagLength = (tagEndIndex - tagStartIndex) + 1;
		NSString * tagName = [newString substringWithRange:NSMakeRange(tagStartIndex + 1, tagLength - 2)];
		NSString * replacementString = nil;

		// Use the tag name as the selector to a member function that returns the expanded
		// value. If no function exists then we just delete the tag name from the source string.
		NSString * tagSelName = [@"tag" stringByAppendingString:tagName];
		const char * cTagSelName = [tagSelName cStringUsingEncoding:NSASCIIStringEncoding];
		replacementString = [self performSelector:sel_registerName(cTagSelName)];

		if (replacementString == nil)
			[newString deleteCharactersInRange:NSMakeRange(tagStartIndex, tagLength)];
		else
		{
			[newString replaceCharactersInRange:NSMakeRange(tagStartIndex, tagLength) withString:replacementString];
			hasOneTag = YES;

			if (![replacementString isBlank])
				cond = NO;

			tagStartIndex += [replacementString length];
		}
	}
	return (cond && hasOneTag) ? @"" : newString;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[commentsArray release];
	commentsArray=nil;
	[articleData release];
	articleData=nil;
	[super dealloc];
}
@end
