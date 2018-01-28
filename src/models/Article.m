//
//  Article.m
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


#import "Article.h"
#import "Database.h"
#import "StringExtensions.h"
#import "CalendarExtensions.h"
#import "HelperFunctions.h"

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
-(instancetype)initWithGuid:(NSString *)theGuid
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
        status = ArticleStatusEmpty;
        self.folderId = -1;
        self.guid = theGuid;
        self.parentId = 0;
    }
    return self;
}

/* setTitle
 */
-(void)setTitle:(NSString *)newTitle
{
    articleData[MA_Field_Subject] = newTitle;
}

/* setAuthor
 */
-(void)setAuthor:(NSString *)newAuthor
{
    articleData[MA_Field_Author] = newAuthor;
}

/* setLink
 */
-(void)setLink:(NSString *)newLink
{
    articleData[MA_Field_Link] = newLink;
}

/* setDate
 * Sets the date when the article was published.
 */
-(void)setDate:(NSDate *)newDate
{
    articleData[MA_Field_Date] = newDate;
}

/* setCreatedDate
 * Sets the date when the article was first created in the database.
 */
-(void)setCreatedDate:(NSDate *)newCreatedDate
{
    articleData[MA_Field_CreatedDate] = newCreatedDate;
}

/* setBody
 */
-(void)setBody:(NSString *)newText
{
    articleData[MA_Field_Text] = newText;
    [articleData removeObjectForKey:MA_Field_Summary];
}

/* setEnclosure
 */
-(void)setEnclosure:(NSString *)newEnclosure
{
    if (newEnclosure)
        articleData[MA_Field_Enclosure] = newEnclosure;
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
        NSString * key = [keyPath substringFromIndex:(@"articleData.").length];
        if ([key isEqualToString:MA_Field_Date])
        {
            return self.date;
        }
        else if ([key isEqualToString:MA_Field_Author])
        {
            return self.author;
        }
        else if ([key isEqualToString:MA_Field_Subject])
        {
            return self.title;
        }
        else if ([key isEqualToString:MA_Field_Link])
        {
            return self.link;
        }
        else if ([key isEqualToString:MA_Field_Summary])
        {
            return self.summary;
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
-(BOOL)hasComments				{ return commentsArray.count > 0; }
-(BOOL)hasEnclosure				{ return hasEnclosureFlag; }
-(BOOL)enclosureDownloaded		{ return enclosureDownloadedFlag; }
-(NSInteger)status				{ return status; }
-(NSInteger)folderId			{ return [articleData[MA_Field_Folder] integerValue]; }
-(NSString *)author				{ return articleData[MA_Field_Author]; }
-(NSString *)link				{ return articleData[MA_Field_Link]; }
-(NSString *)guid				{ return articleData[MA_Field_GUID]; }
-(NSInteger)parentId			{ return [articleData[MA_Field_Parent] integerValue]; }
-(NSString *)title				{ return articleData[MA_Field_Subject]; }
-(NSString *)summary
{
    NSString * summary = articleData[MA_Field_Summary];
    if (summary == nil)
    {
        summary = [articleData[MA_Field_Text] summaryTextFromHTML];
        if (summary == nil)
            summary = @"";
        articleData[MA_Field_Summary] = summary;
    }
    return summary;
}
-(NSDate *)date					{ return articleData[MA_Field_Date]; }
-(NSDate *)createdDate			{ return articleData[MA_Field_CreatedDate]; }
-(NSString *)body				{ return articleData[MA_Field_Text]; }
-(NSString *)enclosure			{ return articleData[MA_Field_Enclosure]; }

/* containingFolder
 */
-(Folder *)containingFolder
{
    return [[Database sharedManager] folderFromID:self.folderId];
}

/* setFolderId
 */
-(void)setFolderId:(NSInteger)newFolderId
{
    articleData[MA_Field_Folder] = @(newFolderId);
}

/* setGuid
 */
-(void)setGuid:(NSString *)newGuid
{
    articleData[MA_Field_GUID] = newGuid;
}

/* setParentId
 */
-(void)setParentId:(NSInteger)newParentId
{
    articleData[MA_Field_Parent] = @(newParentId);
}

/* setStatus
 */
-(void)setStatus:(NSInteger)newStatus
{
    status = newStatus;
}

/* description
 * Return a human readable description of this article for debugging.
 */
-(NSString *)description
{
    return [NSString stringWithFormat:@"{GUID=%@ title=\"%@\"", self.guid, self.title];
}

/* objectSpecifier
 * Create an object specifier for this object using the folder container.
 */
-(NSScriptObjectSpecifier *)objectSpecifier
{
    Folder * folder = [[Database sharedManager] folderFromID:self.folderId];
    NSUInteger index = [folder indexOfArticle:self];
    if (index != NSNotFound)
    {
        NSScriptObjectSpecifier * containerRef = folder.objectSpecifier;
        return [[NSIndexSpecifier allocWithZone:nil] initWithContainerClassDescription:(NSScriptClassDescription *)[Folder classDescription]
                                                                             containerSpecifier:containerRef
                                                                                            key:@"articles"
                                                                                          index:index];
    }
    return nil;
}

/* tagArticleLink
 * Returns the article link as a safe string.
 */
-(NSString *)tagArticleLink
{
    return [cleanedUpAndEscapedUrlFromString(self.link) absoluteString];
}

/* tagArticleTitle
 * Returns the article title.
 */
-(NSString *)tagArticleTitle
{
    NSMutableString * articleTitle = [NSMutableString stringWithString:SafeString([self title])];
    [articleTitle replaceString:@"$Article" withString:@"$_%$%_Article"];
    [articleTitle replaceString:@"$Feed" withString:@"$_%$%_Feed"];
    return [NSString stringByConvertingHTMLEntities:articleTitle];
}

/* tagArticleBody
 * Returns the article body.
 */
-(NSString *)tagArticleBody
{
    NSMutableString * articleBody = [NSMutableString stringWithString:SafeString(self.body)];
    [articleBody replaceString:@"$Article" withString:@"$_%$%_Article"];
    [articleBody replaceString:@"$Feed" withString:@"$_%$%_Feed"];
    [articleBody fixupRelativeImgTags:self.link];
    [articleBody fixupRelativeIframeTags:self.link];
    [articleBody fixupRelativeAnchorTags:self.link];
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
    return [self.date dateWithCalendarFormat:nil timeZone:nil].friendlyDescription;
}

/* tagArticleEnclosureLink
 * Returns the article enclosure link.
 */
-(NSString *)tagArticleEnclosureLink
{
    return [cleanedUpAndEscapedUrlFromString(self.enclosure) absoluteString];
}

/* tagArticleEnclosureFilename
 * Returns the article enclosure file name.
 */
-(NSString *)tagArticleEnclosureFilename
{
    return [self.enclosure.lastPathComponent stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

/* tagFeedTitle
 * Returns the article's feed title.
 */
-(NSString *)tagFeedTitle
{
    Folder * folder = [[Database sharedManager] folderFromID:self.folderId];
    return [NSString stringByConvertingHTMLEntities:SafeString([folder name])];
}

/* tagFeedLink
 * Returns the article's feed URL.
 */
-(NSString *)tagFeedLink
{
    Folder * folder = [[Database sharedManager] folderFromID:self.folderId];
    return [cleanedUpAndEscapedUrlFromString(folder.homePage) absoluteString];
}

/* tagFeedDescription
 * Returns the article's feed description.
 */
-(NSString *)tagFeedDescription
{
    Folder * folder = [[Database sharedManager] folderFromID:self.folderId];
    return folder.feedDescription;
}

/* expandTags
 * Expands recognised tags in theString based on the object values. If cond is YES and all the
 * tags are empty then return the empty string instead.
 */
-(NSString *)expandTags:(NSString *)theString withConditional:(BOOL)cond
{
    NSMutableString * newString = [NSMutableString stringWithString:SafeString(theString)];
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
		SEL selector = sel_registerName(cTagSelName);
		// this is equivalent with replacementString = [self performSelector:selector];
		// http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
		// see also : http://stackoverflow.com/questions/7043999/im-writing-a-button-class-in-objective-c-with-arc-how-do-i-prevent-clangs-m
		IMP imp = [self methodForSelector:selector];
		NSString * (*func)(id, SEL) = (void *)imp;
		replacementString = func(self, selector);

        if (replacementString == nil)
            [newString deleteCharactersInRange:NSMakeRange(tagStartIndex, tagLength)];
        else
        {
            [newString replaceCharactersInRange:NSMakeRange(tagStartIndex, tagLength) withString:replacementString];
            hasOneTag = YES;
            
            if (!replacementString.blank)
                cond = NO;
            
            tagStartIndex += replacementString.length;
        }
    }
    return (cond && hasOneTag) ? @"" : newString;
}

@end
