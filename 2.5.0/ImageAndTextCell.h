//
//  ImageAndTextCell.h
//  Vienna
//
//  Created by Steve on Sat Jan 31 2004.
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

@interface ImageAndTextCell : NSTextFieldCell {
	@private
	NSImage	* image;
	NSImage * auxiliaryImage;
	NSColor * countBackgroundColour;
	int offset;
	int count;
	BOOL hasCount;
	BOOL inProgress;
	
	id item;
	NSMutableArray *progressIndicators;
}

// Accessor functions
-(void)setOffset:(int)offset;
-(void)setImage:(NSImage *)anImage;
-(void)setAuxiliaryImage:(NSImage *)anAuxiliaryImage;
-(void)setCount:(int)newCount;
-(void)clearCount;
-(void)setCountBackgroundColour:(NSColor *)newColour;
-(NSImage *)image;
-(NSImage *)auxiliaryImage;
-(int)offset;
-(void)drawCellImage:(NSRect *)cellFrame inView:(NSView *)controlView;
- (void)setInProgress:(BOOL)newInProgress;
- (void)setItem:(id)inItem;
@end