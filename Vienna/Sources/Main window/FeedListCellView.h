//
//  FeedListCellView.h
//  Vienna
//
//  Copyright 2021 Joshua Pore, 2021-2022 Eitot
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

#import "FeedListConstants.h"

NS_ASSUME_NONNULL_BEGIN

extern NSUserInterfaceItemIdentifier const VNAFeedListCellViewIdentifier;
extern NSUserInterfaceItemIdentifier const VNAFeedListCellViewTextFieldIdentifier;
extern NSUserInterfaceItemIdentifier const VNAFeedListCellViewCountButtonIdentifier;

@interface VNAFeedListCellView : NSTableCellView

@property (nonatomic) VNAFeedListSizeMode sizeMode;
@property (nonatomic) BOOL inProgress;
@property (nonatomic) NSInteger unreadCount;
@property (nonatomic) BOOL canShowUnreadCount;
@property (nonatomic) BOOL showError;
@property (getter=isEmphasized, nonatomic) BOOL emphasized;
@property (getter=isInactive, nonatomic) BOOL inactive;

@end

NS_ASSUME_NONNULL_END
