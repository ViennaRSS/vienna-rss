//
//  ProgressTextCell.h
//  Vienna
//
//  Created by Curtis Faith on Mon Mar 15, 2010 based on ImageAndTextCell.h
//  Copyright (c) 2004-2014 Steve Palmer and Vienna contributors (see Help/Acknowledgements for list of contributors). All rights reserved.
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

/* ProgressTextCell
 * This class is used to draw a progress indicator next to the text for a text cell. If you set
 * the inProgress flag to true then it will draw the progress indicator.
 */
@interface ProgressTextCell : NSTextFieldCell {
	@private

	BOOL inProgress;
	NSInteger progressRow;
	NSInteger currentRow;
	
	NSProgressIndicator * progressIndicator;
}

// Accessor functions
-(void)setInProgress:(BOOL)newInProgress forRow:(NSInteger)row;
@end