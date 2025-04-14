//
//  Article+Tags.m
//  Vienna
//
//  Copyright 2024 Eitot
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "Article+Tags.h"

#import "Database.h"
#import "DateFormatterExtension.h"
#import "Folder.h"
#import "HelperFunctions.h"
#import "StringExtensions.h"

@implementation Article (Tags)

- (NSString *)tagArticleTitle
{
    NSMutableString *articleTitle = [NSMutableString stringWithString:SafeString(self.title)];
    [articleTitle vna_replaceString:@"$Article" withString:@"$_%$%_Article"];
    [articleTitle vna_replaceString:@"$Feed" withString:@"$_%$%_Feed"];
    return [NSString vna_stringByConvertingHTMLEntities:articleTitle];
}

- (NSString *)tagArticleAuthor
{
    return SafeString(self.author);
}

- (NSString *)tagArticleBody
{
    NSMutableString *articleBody = [NSMutableString stringWithString:SafeString(self.body)];
    [articleBody vna_replaceString:@"$Article" withString:@"$_%$%_Article"];
    [articleBody vna_replaceString:@"$Feed" withString:@"$_%$%_Feed"];
    [articleBody vna_fixupRelativeImgTags:self.link];
    [articleBody vna_fixupRelativeIframeTags:self.link];
    [articleBody vna_fixupRelativeAnchorTags:self.link];
    return articleBody;
}

- (NSString *)tagArticleDate
{
    return [NSDateFormatter vna_relativeDateStringFromDate:self.lastUpdate];
}

- (NSString *)tagArticlePublicationDate
{
    return [NSDateFormatter vna_relativeDateStringFromDate:self.publicationDate];
}

- (NSString *)tagArticleLink
{
    return cleanedUpUrlFromString(self.link).absoluteString;
}

- (NSString *)tagArticleEnclosureLink
{
    return cleanedUpUrlFromString(self.enclosure).absoluteString;
}

- (NSString *)tagArticleEnclosureFilename
{
    return self.enclosure.lastPathComponent.stringByRemovingPercentEncoding;
}

- (NSString *)tagFeedTitle
{
    Folder *folder = [Database.sharedManager folderFromID:self.folderId];
    return [NSString vna_stringByConvertingHTMLEntities:SafeString(folder.name)];
}

- (NSString *)tagFeedDescription
{
    Folder *folder = [Database.sharedManager folderFromID:self.folderId];
    return folder.feedDescription;
}

- (NSString *)tagFeedLink
{
    Folder *folder = [Database.sharedManager folderFromID:self.folderId];
    return cleanedUpUrlFromString(folder.homePage).absoluteString;
}

@end
