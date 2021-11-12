//
//  NSFileManager+Paths.h
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

NS_ASSUME_NONNULL_BEGIN

@interface NSFileManager (Paths)

/// The scripts directory for the current user (Library/Application Scripts or
/// Library/Scripts/Applications depending on whether sandboxing is enabled).
@property (readonly, copy, nonatomic) NSURL *vna_applicationScriptsDirectory
    NS_SWIFT_NAME(applicationScriptsDirectory);

/// The application support directory for the current user (Library/Application
/// Support).
@property (readonly, copy, nonatomic) NSURL *vna_applicationSupportDirectory
    NS_SWIFT_NAME(applicationSupportDirectory);

/// The caches directory for the current user (Library/Caches).
@property (readonly, copy, nonatomic) NSURL *vna_cachesDirectory
    NS_SWIFT_NAME(cachesDirectory);

/// The downloads directory for the current user.
@property (readonly, copy, nonatomic) NSURL *vna_downloadsDirectory
    NS_SWIFT_NAME(downloadsDirectory);

@end

NS_ASSUME_NONNULL_END
