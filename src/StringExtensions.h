//
//  StringExtensions.h
//  Vienna
//
//  Created by Steve on Wed Mar 17 2004.
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

#import <Cocoa/Cocoa.h>

#define SafeString(s)   ((s) ? (s) : @"")

@interface NSMutableString (MutableStringExtensions)
	-(void)replaceString:(NSString *)source withString:(NSString *)dest;
	-(void)fixupRelativeImgTags:(NSString *)baseURL;
	-(void)fixupRelativeAnchorTags:(NSString *)baseURL;
	-(void)fixupRelativeIframeTags:(NSString *)baseURL;
@end

@interface NSString (StringExtensions)
	+(NSString *)stringByRemovingHTML:(NSString *)theString;
	+(NSString *)mapEntityToString:(NSString *)entityString;
    +(NSString *)stringByConvertingHTMLEntities:(NSString *)stringToProcess;
	@property (nonatomic, readonly, copy) NSString *firstNonBlankLine;
	@property (nonatomic, readonly, copy) NSString *summaryTextFromHTML;
	@property (nonatomic, readonly, copy) NSString *titleTextFromHTML;
	-(NSUInteger)indexOfCharacterInString:(char)ch afterIndex:(NSUInteger)startIndex;
	@property (nonatomic, readonly, copy) NSString *stringByEscapingExtendedCharacters;
	@property (nonatomic, readonly, copy) NSString *stringByUnescapingExtendedCharacters;
	@property (nonatomic, readonly, copy) NSString *stringByDeletingLastURLComponent;
	@property (nonatomic, readonly, copy) NSString *lastURLComponent;
	-(NSString *)stringByAppendingURLComponent:(NSString *)newComponent;
	-(BOOL)hasCharacter:(char)ch;
	@property (nonatomic, readonly, copy) NSString *firstWord;
	@property (nonatomic, readonly, copy) NSString *convertStringToValidPath;
	-(NSComparisonResult)numericCompare:(NSString *)aString;
	@property (nonatomic, readonly, copy) NSString *normalised;
	@property (nonatomic, readonly, copy) NSString *baseURL;
	@property (nonatomic, readonly, copy) NSString *host;
	@property (nonatomic, readonly, copy) NSString *trim;
	@property (nonatomic, readonly) NSInteger hexValue;
	@property (nonatomic, getter=isBlank, readonly) BOOL blank;
@end
