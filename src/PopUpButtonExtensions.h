//
//  PopUpButtonExtensions.h
//  Vienna
//
//  Created by Steve on 7/16/05.
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

#import <Cocoa/Cocoa.h>

@interface NSPopUpButton (PopUpButtonExtensions)
	-(void)addItemWithTitle:(NSString *)title image:(NSImage *)image;
	-(void)addItemWithTarget:(NSString *)title target:(SEL)target;
	-(void)addItemWithTag:(NSString *)title tag:(NSInteger)tag;
	-(void)addItemWithRepresentedObject:(NSString *)title object:(id)object;
	-(void)insertItemWithTag:(NSString *)title tag:(NSInteger)tag atIndex:(NSInteger)index;
	-(id)representedObjectForSelection;
	-(NSInteger)tagForSelection;
	-(void)addSeparator;
@end
