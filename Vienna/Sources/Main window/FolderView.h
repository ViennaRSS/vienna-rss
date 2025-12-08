//
//  FolderView.h
//  Vienna
//
//  Created by Steve on Tue Apr 06 2004.
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

@import Cocoa;

#import "FeedListConstants.h"
#import "FolderViewDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface FolderView : NSOutlineView <NSMenuItemValidation>

// This class is initialized in Interface Builder (-initWithCoder:).
- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic) VNAFeedListSizeMode sizeMode;
- (CGFloat)rowHeightForSize:(VNAFeedListSizeMode)sizeMode;

- (void)reloadDataWhilePreservingSelection;
- (void)reloadDataForRowIndexWhilePreservingSelection:(NSInteger)rowIndex;
- (void)showResetButton:(BOOL)enabled;

// This property overrides a superclass property.
@property (nullable, weak) id<FolderViewDelegate> delegate;

@property (nullable, nonatomic) NSPredicate *filterPredicate;

@end

NS_ASSUME_NONNULL_END
