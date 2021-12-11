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

#import "Article.h"
#import "StringExtensions.h"
#import "Vienna-Swift.h"

@implementation ArticleConverter

@synthesize htmlTemplate, cssStylesheet, jsScript;

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
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

    while ((tagStartIndex = [newString vna_indexOfCharacterInString:'$' afterIndex:tagStartIndex]) != NSNotFound)
    {
        NSUInteger tagEndIndex = [newString vna_indexOfCharacterInString:'$' afterIndex:tagStartIndex + 1];
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
        IMP imp = [theArticle methodForSelector:selector];
        NSString * (*func)(id, SEL) = (void *)imp;
        replacementString = func(theArticle, selector);

        if (replacementString == nil)
            [newString deleteCharactersInRange:NSMakeRange(tagStartIndex, tagLength)];
        else
        {
            [newString replaceCharactersInRange:NSMakeRange(tagStartIndex, tagLength) withString:replacementString];
            hasOneTag = YES;

            if (!replacementString.vna_isBlank)
                cond = NO;

            tagStartIndex += replacementString.length;
        }
    }
    return (cond && hasOneTag) ? @"" : newString;
}

/* articleTextFromArray
 * Create an HTML string comprising all articles in the specified array formatted using
 * the currently selected template.
 */
-(NSString *)articleTextFromArray:(NSArray<Article *> *)msgArray
{
    NSUInteger index;

    NSMutableString * htmlText = [[NSMutableString alloc] initWithString:@"<!DOCTYPE html><html><head><meta  http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\">"];
    // the link for the first article will be the base URL for resolving relative URLs
    [htmlText appendString:@"<base href=\""];
    [htmlText appendString:[NSString vna_stringByCleaningURLString:msgArray[0].link]];
    [htmlText appendString:@"\">"];
    if (self.cssStylesheet != nil && self.cssStylesheet.length != 0) {
        [htmlText appendString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\""];
        [htmlText appendString:self.cssStylesheet];
        [htmlText appendString:@"\">"];
    }
    if (self.jsScript != nil && self.jsScript.length != 0) {
        [htmlText appendString:@"<script type=\"text/javascript\" src=\""];
        [htmlText appendString:self.jsScript];
        [htmlText appendString:@"\"></script>"];
    }
    [htmlText appendString:@"<meta http-equiv=\"Pragma\" content=\"no-cache\">"];
    [htmlText appendString:@"</head><body>"];
    for (index = 0; index < msgArray.count; ++index) {
        Article * theArticle = msgArray[index];

        // Load the selected HTML template for the current view style and plug in the current
        // article values and style sheet setting.
        NSMutableString * htmlArticle;
        if (self.htmlTemplate == nil || self.htmlTemplate.length == 0) {
            NSMutableString * articleBody = [NSMutableString stringWithString:SafeString(theArticle.body)];
            [articleBody vna_fixupRelativeImgTags:SafeString([theArticle link])];
            [articleBody vna_fixupRelativeIframeTags:SafeString([theArticle link])];
            [articleBody vna_fixupRelativeAnchorTags:SafeString([theArticle link])];
            htmlArticle = [[NSMutableString alloc] initWithString:articleBody];
        } else {
            htmlArticle = [[NSMutableString alloc] initWithString:@""];
            NSScanner * scanner = [NSScanner scannerWithString:self.htmlTemplate];
            NSString * theString = nil;
            BOOL stripIfEmpty = NO;

            // Handle conditional tag expansion. Sections in <!-- cond:noblank--> and <!--end-->
            // are stripped out if all the tags inside are blank.
            while(!scanner.atEnd) {
                if ([scanner scanUpToString:@"<!--" intoString:&theString]) {
                    [htmlArticle appendString:[self expandTagsOfArticle:theArticle intoTemplate:theString withConditional:stripIfEmpty]];
                }
                if ([scanner scanString:@"<!--" intoString:nil]) {
                    NSString * commentTag = nil;

                    if ([scanner scanUpToString:@"-->" intoString:&commentTag] && commentTag != nil) {
                        commentTag = commentTag.vna_trimmed;
                        if ([commentTag isEqualToString:@"cond:noblank"]) {
                            stripIfEmpty = YES;
                        }
                        if ([commentTag isEqualToString:@"end"]) {
                            stripIfEmpty = NO;
                        }
                        [scanner scanString:@"-->" intoString:nil];
                    }
                }
            }
        }

        // Separate each article with a horizontal divider line
        if (index > 0) {
            [htmlText appendString:@"<hr><br />"];
        }
        [htmlText appendString:htmlArticle];
    }
    [htmlText appendString:@"</body></html>"];
    return htmlText;
}

@end
