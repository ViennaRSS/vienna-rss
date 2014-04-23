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
	-(NSString *)firstNonBlankLine;
	-(NSString *)summaryTextFromHTML;
	-(NSString *)titleTextFromHTML;
	-(NSUInteger)indexOfCharacterInString:(char)ch afterIndex:(NSUInteger)startIndex;
	-(NSString *)stringByEscapingExtendedCharacters;
	-(NSString *)stringByUnescapingExtendedCharacters;
	-(NSString *)stringByDeletingLastURLComponent;
	-(NSString *)lastURLComponent;
	-(NSString *)stringByAppendingURLComponent:(NSString *)newComponent;
	-(BOOL)hasCharacter:(char)ch;
	-(NSString *)firstWord;
	-(NSString *)convertStringToValidPath;
	-(NSComparisonResult)numericCompare:(NSString *)aString;
	-(NSString *)normalised;
	-(NSString *)baseURL;
	-(NSString *)host;
	-(NSString *)trim;
	-(int)hexValue;
	-(BOOL)isBlank;
@end
