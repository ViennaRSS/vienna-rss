//
//  WKPreferences+Private.h
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

@import Foundation;

@interface WKPreferences (Private)

#ifdef DEBUG
@property (setter=_setDeveloperExtrasEnabled:, nonatomic) BOOL _developerExtrasEnabled;
#endif

// This is implemented by WKPreferences.elementFullscreenEnabled as of
// macOS 12.3.
@property (setter=_setFullScreenEnabled:, nonatomic) BOOL _fullScreenEnabled
    NS_SWIFT_NAME(_isFullScreenEnabled) NS_DEPRECATED_MAC(10.12, 12.3);

@end
