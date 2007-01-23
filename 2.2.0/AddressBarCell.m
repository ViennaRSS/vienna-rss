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
		hasFeedIcon = NO;
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

/* FEED DETECTION: As soon as feed detection is implemented, the checks which decide wether to show 
* the feed-icon will have to take place somewhere. There are two identical feed-icons and one lock-icon in 
* BrowserPane.nib. The right feed-icon overlays the lock-icon We need to implement some logic
* to decide wether to show only the right feed icon and hide the lock, or to show the lock and the left
* feed-icon while hiding the right feed-icon. Souds funky, but is actually probably the most straightforward way.
*/

/* setHasFeedIcon
 * Sets wether the address field will show a RSS icon.
 */
-(void)setHasFeedIcon:(BOOL)flag
{
	hasFeedIcon = flag;
	[(NSControl*)[self controlView] calcSize];
}

/* hasFeedIcon
 * Returns wether the feed icon should currently be visible.
 */
-(BOOL)hasFeedIcon
{
	return hasFeedIcon;
}

/* drawingRectForBounds
 * Reduce the drawing area for the text by the space needed for the image
 * on the left and, optionally, the secure web page image on the right.
 */
-(NSRect)drawingRectForBounds:(NSRect)theRect
{
	const float imageSpace = 19.0;
	
	theRect.origin.x += imageSpace;
	theRect.size.width -= imageSpace;
	if (hasSecureImage)
		theRect.size.width -= imageSpace;
	if (hasFeedIcon)
		theRect.size.width -= imageSpace;
	return [super drawingRectForBounds:theRect];
}
@end