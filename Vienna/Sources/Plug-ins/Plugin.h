//
//  Plugin.h
//  Vienna
//
//  Copyright 2024 Eitot
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

/// The type key in the bundle's Info.plist file.
extern NSString * const VNAPluginTypeInfoPlistKey;

NS_SWIFT_NAME(Plugin)
@interface VNAPlugin : NSObject

/// Initializes a plug-in from the data in the bundle.
///
/// Subclasses must override this method and call the superclass implementation
/// to inherit validation checks for the Info.plist file and common properties.
/// Subclasses should check if the bundle contains the needed data for the
/// plug-in.
- (nullable instancetype)initWithBundle:(NSBundle *)bundle NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// Whether the plug-in can be initialized with the given bundle. This method
/// will be sent before `-initWithBundle:` to find the appropriate plug-in type
/// for the bundle.
///
/// Subclasses must override this method and check whether the Info.plist file
/// has the "Type" key (`VNAPluginTypeInfoPlistKey`) and that its value matches
/// the plug-in type. The default implementation always returns `NO`.
+ (BOOL)canInitWithBundle:(NSBundle *)bundle;

/// The bundle with which the plug-in was initialized. This bundle contains the
/// plug-in data that is accessed through convenience properties.
@property (readonly, nonatomic) NSBundle *bundle;

@property (readonly, nonatomic) NSString *identifier;
@property (readonly, nonatomic) NSString *displayName;

@end

NS_ASSUME_NONNULL_END
