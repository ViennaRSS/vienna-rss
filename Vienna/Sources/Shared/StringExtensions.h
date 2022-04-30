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

#define SafeString(s) s ? s : @""

NS_ASSUME_NONNULL_BEGIN

@interface NSMutableString (MutableStringExtensions)

- (void)vna_replaceString:(NSString *)source withString:(NSString *)dest;
- (void)vna_fixupRelativeImgTags:(NSString *)baseURL;
- (void)vna_fixupRelativeAnchorTags:(NSString *)baseURL;
- (void)vna_fixupRelativeIframeTags:(NSString *)baseURL;

@end

@interface NSString (StringExtensions)

+ (NSString *)vna_stringByRemovingHTML:(NSString *)theString;
+ (NSString *)vna_mapEntityToString:(NSString *)entityString;
+ (NSString *)vna_stringByConvertingHTMLEntities:(NSString *)stringToProcess;
+ (nullable NSString *)vna_toBase64String:(nullable NSString *)stringToProcess;
+ (nullable NSString *)vna_fromBase64String:(nullable NSString *)stringToProcess;
+ (NSString *)vna_stringByCleaningURLString:(nullable NSString *)urlString;
@property (readonly, nonatomic) NSString *vna_firstNonBlankLine;
@property (readonly, nonatomic) NSString *vna_summaryTextFromHTML;
@property (readonly, nonatomic) NSString *vna_titleTextFromHTML;
- (NSUInteger)vna_indexOfCharacterInString:(char)ch afterIndex:(NSUInteger)startIndex;
@property (readonly, nonatomic) NSString *vna_stringByEscapingExtendedCharacters;
@property (readonly, nonatomic) NSString *vna_stringByUnescapingExtendedCharacters;
- (NSString *)vna_stringByAppendingURLComponent:(nullable NSString *)newComponent;
- (BOOL)vna_hasCharacter:(char)ch;
@property (readonly, nonatomic) NSString *vna_convertStringToValidPath;
- (NSComparisonResult)vna_caseInsensitiveNumericCompare:(NSString *)string;
@property (readonly, nonatomic) NSString *vna_normalised;
@property (readonly, nonatomic) NSString *vna_baseURL;
@property (readonly, nonatomic) NSString *vna_host;
@property (readonly, nonatomic) NSString *vna_trimmed;
@property (readonly, nonatomic) NSInteger vna_hexValue;
@property (readonly, nonatomic) BOOL vna_isBlank;

@end

NS_ASSUME_NONNULL_END
