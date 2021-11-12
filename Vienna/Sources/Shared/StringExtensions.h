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
- (void)vna_replaceString:(NSString *_Nonnull)source withString:(NSString *_Nonnull)dest;
- (void)vna_fixupRelativeImgTags:(NSString *_Nonnull)baseURL;
- (void)vna_fixupRelativeAnchorTags:(NSString *_Nonnull)baseURL;
- (void)vna_fixupRelativeIframeTags:(NSString *_Nonnull)baseURL;
@end

@interface NSString (StringExtensions)
+ (NSString *_Nonnull)vna_stringByRemovingHTML:(NSString *_Nonnull)theString;
+ (NSString *_Nonnull)vna_mapEntityToString:(NSString *_Nonnull)entityString;
+ (NSString *_Nonnull)vna_stringByConvertingHTMLEntities:(NSString *_Nonnull)stringToProcess;
+ (NSString *_Nullable)vna_toBase64String:(NSString *_Nullable)stringToProcess;
+ (NSString *_Nullable)vna_fromBase64String:(NSString *_Nullable)stringToProcess;
+ (NSString *_Nonnull)vna_stringByCleaningURLString:(NSString *_Nullable)urlString;
@property (nonatomic, readonly, copy) NSString *_Nonnull vna_firstNonBlankLine;
@property (nonatomic, readonly, copy) NSString *_Nonnull vna_summaryTextFromHTML;
@property (nonatomic, readonly, copy) NSString *_Nonnull vna_titleTextFromHTML;
- (NSUInteger)vna_indexOfCharacterInString:(char)ch afterIndex:(NSUInteger)startIndex;
@property (nonatomic, readonly, copy) NSString *_Nonnull vna_stringByEscapingExtendedCharacters;
@property (nonatomic, readonly, copy) NSString *_Nonnull vna_stringByUnescapingExtendedCharacters;
- (NSString *_Nonnull)vna_stringByAppendingURLComponent:(NSString *_Nullable)newComponent;
- (BOOL)vna_hasCharacter:(char)ch;
@property (nonatomic, readonly, copy) NSString *_Nonnull vna_convertStringToValidPath;
- (NSComparisonResult)vna_numericCompare:(NSString *_Nonnull)aString;
@property (nonatomic, readonly, copy) NSString *_Nonnull vna_normalised;
@property (nonatomic, readonly, copy) NSString *_Nonnull vna_baseURL;
@property (nonatomic, readonly, copy) NSString *_Nonnull vna_host;
@property (nonatomic, readonly, copy) NSString *_Nonnull vna_trimmed;
@property (nonatomic, readonly) NSInteger vna_hexValue;
@property (nonatomic, readonly) BOOL vna_isBlank;

@end
