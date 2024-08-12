//
//  Article+Tags.h
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

#import "Article.h"

NS_ASSUME_NONNULL_BEGIN

@interface Article (Tags)

// The following methods are called dynamically by the ArticleConverter class,
// specifically -expandTagsOfArticle:intoTemplate:withConditional:. It creates
// selectors by appending a tag name to the string "tag", e.g. $ArticleAuthor$
// becomes tagArticleAuthor. The method signatures must not be changed without
// changing the corresponding tag names elsewhere.

- (NSString *)tagArticleTitle;
- (NSString *)tagArticleAuthor;
- (NSString *)tagArticleBody;
- (NSString *)tagArticleDate;
- (NSString *)tagArticleLink;
- (NSString *)tagArticleEnclosureLink;
- (NSString *)tagArticleEnclosureFilename;
- (NSString *)tagFeedTitle;
- (NSString *)tagFeedDescription;
- (NSString *)tagFeedLink;

@end

NS_ASSUME_NONNULL_END
