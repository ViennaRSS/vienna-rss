/*
 *  DisclosureView.h
 *  Vienna
 *
 *
 *  Copyright 2017
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

@import Cocoa;

@interface DisclosureView : NSView

// This class is initialized in Interface Builder (-initWithCoder:).
- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic) IBOutlet NSView *disclosedView;
@property (readonly, getter=isDisclosed, nonatomic) BOOL disclosed;

- (void)collapse:(BOOL)animate;
- (void)disclose:(BOOL)animate;

@end
