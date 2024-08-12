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
#import "Folder.h"
#import "StringExtensions.h"

// The names here are internal field names, not for localisation.
NSString * const MA_Field_GUID = @"GUID";
NSString * const MA_Field_Subject = @"Subject";
NSString * const MA_Field_Author = @"Author";
NSString * const MA_Field_Link = @"Link";
NSString * const MA_Field_LastUpdate = @"Date";
NSString * const MA_Field_Read = @"Read";
NSString * const MA_Field_Flagged = @"Flagged";
NSString * const MA_Field_Deleted = @"Deleted";
NSString * const MA_Field_Text = @"Text";
NSString * const MA_Field_Folder = @"Folder";
NSString * const MA_Field_Parent = @"Parent";
NSString * const MA_Field_Headlines = @"Headlines";
NSString * const MA_Field_Summary = @"Summary";
NSString * const MA_Field_PublicationDate = @"PublicationDate";
NSString * const MA_Field_Enclosure = @"Enclosure";
NSString * const MA_Field_EnclosureDownloaded = @"EnclosureDownloaded";
NSString * const MA_Field_HasEnclosure = @"HasEnclosure";

@implementation Article {
    NSMutableDictionary *articleData;
}

- (instancetype)initWithGUID:(NSString *)guid
{
    self = [super init];
    if (self) {
        articleData = [[NSMutableDictionary alloc] init];
        // Use the setters to populate the articleData dictionary.
        self.guid = guid;
        self.folderId = -1;
        self.parentId = 0;
    }
    return self;
}

/* setTitle
 */
-(void)setTitle:(NSString *)newTitle
{
    articleData[MA_Field_Subject] = [newTitle copy];
}

/* setAuthor
 */
-(void)setAuthor:(NSString *)newAuthor
{
    articleData[MA_Field_Author] = [newAuthor copy];
}

/* setLink
 */
-(void)setLink:(NSString *)newLink
{
    articleData[MA_Field_Link] = [newLink copy];
}

/* setDate
 * Sets the date when the article was published.
 */
-(void)setLastUpdate:(NSDate *)lastUpdate
{
    articleData[MA_Field_LastUpdate] = lastUpdate;
}

/*
 * Sets the date when the article was first published or added to the database.
 */
- (void)setPublicationDate:(NSDate *)publicationDate
{
    articleData[MA_Field_PublicationDate] = publicationDate;
}

/* setBody
 */
-(void)setBody:(NSString *)newText
{
    articleData[MA_Field_Text] = [newText copy];
    [articleData removeObjectForKey:MA_Field_Summary];
}

/* setEnclosure
 */
-(void)setEnclosure:(NSString *)enclosure
{
    NSString *newEnclosure = [enclosure copy];
    if (newEnclosure) {
        articleData[MA_Field_Enclosure] = newEnclosure;
    } else {
        [articleData removeObjectForKey:MA_Field_Enclosure];
    }
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
    if ([keyPath hasPrefix:@"articleData."]) {
        NSString * key = [keyPath substringFromIndex:(@"articleData.").length];
        if ([key isEqualToString:MA_Field_LastUpdate]) {
            return self.lastUpdate;
        } else if ([key isEqualToString:MA_Field_PublicationDate]) {
            return self.publicationDate;
        } else if ([key isEqualToString:MA_Field_Author]) {
            return self.author;
        } else if ([key isEqualToString:MA_Field_Subject]) {
            return self.title;
        } else if ([key isEqualToString:MA_Field_Link]) {
            return self.link;
        } else if ([key isEqualToString:MA_Field_Summary]) {
            return self.summary;
        } else {
            return [super valueForKeyPath:keyPath];
        }
    } else {
        return [super valueForKeyPath:keyPath];
    }
}

/* Accessor functions
 */
-(NSInteger)folderId			{ return [articleData[MA_Field_Folder] integerValue]; }
-(NSString *)author				{ return articleData[MA_Field_Author]; }
-(NSString *)link				{ return articleData[MA_Field_Link]; }
-(NSString *)guid				{ return articleData[MA_Field_GUID]; }
-(NSInteger)parentId			{ return [articleData[MA_Field_Parent] integerValue]; }
-(NSString *)title				{ return articleData[MA_Field_Subject]; }
-(NSString *)summary
{
    NSString * summary = articleData[MA_Field_Summary];
    if (summary == nil) {
        summary = [articleData[MA_Field_Text] vna_summaryTextFromHTML];
        if (summary == nil) {
            summary = @"";
        }
        articleData[MA_Field_Summary] = summary;
    }
    return summary;
}
-(NSDate *)lastUpdate			{ return articleData[MA_Field_LastUpdate]; }
-(NSDate *)publicationDate		{ return articleData[MA_Field_PublicationDate]; }
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
    articleData[MA_Field_GUID] = [newGuid copy];
}

/* setParentId
 */
-(void)setParentId:(NSInteger)newParentId
{
    articleData[MA_Field_Parent] = @(newParentId);
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
    if (index != NSNotFound) {
        NSScriptObjectSpecifier * containerRef = folder.objectSpecifier;
        return [[NSIndexSpecifier allocWithZone:nil] initWithContainerClassDescription:(NSScriptClassDescription *)[Folder classDescription]
                                                                             containerSpecifier:containerRef
                                                                                            key:@"articles"
                                                                                          index:index];
    }
    return nil;
}

@end
