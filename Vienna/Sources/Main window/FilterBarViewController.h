//
//  FilterBarViewController.h
//  Vienna
//
//  Copyright 2025 Eitot
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

@import Cocoa;

#import "ArticleListConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface VNAFilterBarViewController : NSViewController

+ (VNAFilterBarViewController *)instantiateFromNib;

// MARK: Filter configuration

@property (nonatomic) NSString *filterString;

@property (nonatomic) NSString *placeholderFilterString;

@property (nonatomic) VNAFilter filterMode;

// MARK: Filter bar presentation

@property (getter=isVisible, nonatomic) BOOL visible;

@property (nullable, weak, nonatomic) id<NSTextFinderBarContainer> filterBarContainer;

// MARK: Event handling

@property (nullable, unsafe_unretained, nonatomic) NSView *nextKeyView;

- (void)beginInteraction;

@end

NS_ASSUME_NONNULL_END
