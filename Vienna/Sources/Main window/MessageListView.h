//
//  MessageListView.h
//  Vienna
//
//  Created by Steve on Thu Mar 04 2004.
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

#import "TableViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MessageListViewDelegate <ExtendedTableViewDelegate>

- (BOOL)canDeleteMessageAtRow:(NSInteger)row;

@optional

// TODO: Implement this in UnifiedDisplayView and make it non-optional
- (BOOL)copyTableSelection:(NSIndexSet *)rowIndexes
              toPasteboard:(NSPasteboard *)pboard;

@end

@interface MessageListView : ExtendedTableView <NSMenuItemValidation>

// This property overrides a superclass property.
@property (weak, nullable) id<MessageListViewDelegate> delegate;

- (void)setTableColumnHeaderImage:(NSImage *)image
          forColumnWithIdentifier:(NSUserInterfaceItemIdentifier)identifier;

@end

NS_ASSUME_NONNULL_END
