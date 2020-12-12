//
//  ArticleConverter.h
//  Vienna
//
//  Copyright 2020 Tassilo Karge
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ArticleConverter : NSObject

@property NSString * htmlTemplate;
@property NSString * cssStylesheet;
@property NSString * jsScript;

-(NSString *)expandTagsOfArticle:(Article *)theArticle intoTemplate:(NSString *)theString withConditional:(BOOL)cond;

/* articleTextFromArray
 * Create an HTML string comprising all articles in the specified array formatted using
 * the currently selected template.
 */
-(NSString *)articleTextFromArray:(NSArray<Article *> *)msgArray;

@end

NS_ASSUME_NONNULL_END
