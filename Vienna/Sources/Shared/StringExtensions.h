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

@import Foundation;
@import WebKit;

#define SafeString(s)   ((s) ?: @"")

@interface NSMutableString (MutableStringExtensions)
- (void)replaceString:(NSString *_Nonnull)source withString:(NSString *_Nonnull)dest;
- (void)fixupRelativeImgTags:(NSString *_Nonnull)baseURL;
- (void)fixupRelativeAnchorTags:(NSString *_Nonnull)baseURL;
- (void)fixupRelativeIframeTags:(NSString *_Nonnull)baseURL;
@end

@interface NSString (StringExtensions)
+ (NSString *_Nonnull)stringByRemovingHTML:(NSString *_Nonnull)theString;
+ (NSString *_Nonnull)mapEntityToString:(NSString *_Nonnull)entityString;
+ (NSString *_Nonnull)stringByConvertingHTMLEntities:(NSString *_Nonnull)stringToProcess;
+ (NSString *_Nullable)toBase64String:(NSString *_Nullable)stringToProcess;
+ (NSString *_Nullable)fromBase64String:(NSString *_Nullable)stringToProcess;
+ (NSString *_Nonnull)stringByCleaningURLString:(NSString *_Nullable)urlString;
@property (nonatomic, readonly, copy) NSString *_Nonnull firstNonBlankLine;
@property (nonatomic, readonly, copy) NSString *_Nonnull summaryTextFromHTML;
@property (nonatomic, readonly, copy) NSString *_Nonnull titleTextFromHTML;
- (NSUInteger)indexOfCharacterInString:(char)ch afterIndex:(NSUInteger)startIndex;
@property (nonatomic, readonly, copy) NSString *_Nonnull stringByEscapingExtendedCharacters;
@property (nonatomic, readonly, copy) NSString *_Nonnull stringByUnescapingExtendedCharacters;
- (NSString *_Nonnull)stringByAppendingURLComponent:(NSString *_Nullable)newComponent;
- (BOOL)hasCharacter:(char)ch;
@property (nonatomic, readonly, copy) NSString *_Nonnull convertStringToValidPath;
- (NSComparisonResult)numericCompare:(NSString *_Nonnull)aString;
@property (nonatomic, readonly, copy) NSString *_Nonnull normalised;
@property (nonatomic, readonly, copy) NSString *_Nonnull baseURL;
@property (nonatomic, readonly, copy) NSString *_Nonnull host;
@property (nonatomic, readonly, copy) NSString *_Nonnull trim;
@property (nonatomic, readonly) NSInteger hexValue;
@property (nonatomic, getter = isBlank, readonly) BOOL blank;
@end
