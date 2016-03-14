//
//  AddressBarCell.m
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
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

#import "AddressBarCell.h"

@implementation AddressBarCell

/* initTextCell
 * Initialise a new TextFieldCell subclass.
 */
-(id)initTextCell:(NSString *)inStr
{
	if ((self = [super initTextCell:inStr]) != nil)
	{
		hasSecureImage = NO;
	}
	return self;
}

/* setHasSecureImage
 * Sets whether the address field will show a secure image.
 */
-(void)setHasSecureImage:(BOOL)flag
{
	hasSecureImage = flag;
	[(NSControl*)[self controlView] calcSize];
}

/* hasSecureImage
 * Returns wether the secure image should currently be visible.
 */
-(BOOL)hasSecureImage
{
	return hasSecureImage;
}

/* drawingRectForBounds
 * Reduce the drawing area for the text by the space needed for the image
 * on the left and, optionally, the secure web page image on the right.
 */
-(NSRect)drawingRectForBounds:(NSRect)theRect
{
	const CGFloat imageSpace = 19.0;

	theRect.origin.x += imageSpace;
	theRect.size.width -= imageSpace;
	if (hasSecureImage)
		theRect.size.width -= imageSpace;
	return [super drawingRectForBounds:theRect];
}
@end