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
#import "HelperFunctions.h"
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

/* articleTextFromArray
 * Create an HTML string comprising all articles in the specified array formatted using
 * the currently selected template.
 */
-(NSString *)articleTextFromArray:(NSArray<Article *> *)msgArray
{
    NSUInteger index;

    NSMutableString * htmlText = [[NSMutableString alloc] initWithString:@"<!DOCTYPE html><html><head><meta content=\"text/html; charset=UTF-8\">"];
    // the link for the first article will be the base URL for resolving relative URLs
    [htmlText appendString:@"<base href=\""];
    [htmlText appendString:[NSString stringByCleaningURLString:msgArray[0].link]];
    [htmlText appendString:@"\">"];
    if (cssStylesheet != nil && cssStylesheet.length != 0) {
        [htmlText appendString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\""];
        [htmlText appendString:cssStylesheet];
        [htmlText appendString:@"\">"];
    }
    if (jsScript != nil && jsScript.length != 0) {
        [htmlText appendString:@"<script type=\"text/javascript\" src=\""];
        [htmlText appendString:jsScript];
        [htmlText appendString:@"\"></script>"];
    }
    [htmlText appendString:@"<meta http-equiv=\"Pragma\" content=\"no-cache\">"];
    [htmlText appendString:@"</head><body>"];
    for (index = 0; index < msgArray.count; ++index) {
        Article * theArticle = msgArray[index];

        // Load the selected HTML template for the current view style and plug in the current
        // article values and style sheet setting.
        NSMutableString * htmlArticle;
        if (htmlTemplate == nil || htmlTemplate.length == 0) {
            NSMutableString * articleBody = [NSMutableString stringWithString:SafeString(theArticle.body)];
            [articleBody fixupRelativeImgTags:SafeString([theArticle link])];
            [articleBody fixupRelativeIframeTags:SafeString([theArticle link])];
            [articleBody fixupRelativeAnchorTags:SafeString([theArticle link])];
            htmlArticle = [[NSMutableString alloc] initWithString:articleBody];
        } else {
            htmlArticle = [[NSMutableString alloc] initWithString:@""];
            NSScanner * scanner = [NSScanner scannerWithString:htmlTemplate];
            NSString * theString = nil;
            BOOL stripIfEmpty = NO;

            // Handle conditional tag expansion. Sections in <!-- cond:noblank--> and <!--end-->
            // are stripped out if all the tags inside are blank.
            while(!scanner.atEnd) {
                if ([scanner scanUpToString:@"<!--" intoString:&theString]) {
                    [htmlArticle appendString:[theArticle expandTags:theString withConditional:stripIfEmpty]];
                }
                if ([scanner scanString:@"<!--" intoString:nil]) {
                    NSString * commentTag = nil;

                    if ([scanner scanUpToString:@"-->" intoString:&commentTag] && commentTag != nil) {
                        commentTag = commentTag.trim;
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
