//
//  WKWebViewConfiguration+Private.h
//  Vienna
//
//  Copyright 2021 Eitot
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

@import Foundation;

@interface WKWebViewConfiguration (Private)

// This is implemented by WKWebpagePreferences.allowsContentJavaScript as of
// macOS 11.
@property (setter=_setAllowsJavaScriptMarkup:, nonatomic) BOOL _allowsJavaScriptMarkup NS_DEPRECATED_MAC(10.12, 11);

@end
