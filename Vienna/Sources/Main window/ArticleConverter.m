//
//  ArticleConverter.m
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

#import "ArticleConverter.h"
#import "StringExtensions.h"

@implementation ArticleConverter

@synthesize htmlTemplate, cssStylesheet, jsScript;

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupStyle];
    }
    return self;
}

/* expandTags
 * Expands recognised tags in theString based on the object values. If cond is YES and all the
 * tags are empty then return the empty string instead.
 */
-(NSString *)expandTagsOfArticle:(Article *)theArticle intoTemplate:(NSString *)theString withConditional:(BOOL)cond
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
