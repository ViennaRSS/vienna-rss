//
//  NSPredicateEditor+Private.h
//  Vienna
//
//  Copyright 2022 Eitot
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

#ifdef DEBUG

@import Cocoa;

@interface NSPredicateEditor (Private)

/// Returns an NSData object containing a UTF-16 encoded NSString object which
/// represents a [Localizable].strings file.
///
/// - SeeAlso: https://tyler.io/how-to-set-custom-display-values-and-localize-nspredicateeditor/
- (id)_generateFormattingDictionaryStringsFile;

@end

#endif
