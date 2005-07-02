//
//  ImageAndTextCell.m
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

#import "ImageAndTextCell.h"

/* All of this stuff taken from public stuff published
 * by Apple.
 */

@implementation ImageAndTextCell

-copyWithZone:(NSZone *)zone\
{
	ImageAndTextCell *cell = (ImageAndTextCell *)[super copyWithZone:zone];
	cell->image = [image retain];
	cell->offset = offset;
	return cell;
}

-(void)setOffset:(int)newOffset
{
	offset = newOffset;
}

-(int)offset
{
	return offset;
}

-(void)setImage:(NSImage *)anImage
{
	if (anImage != image)
	{
		[image release];
		image = nil;
		if (anImage)
			image = [anImage retain];
	}
}

-(NSImage *)image
{
	return [[image retain] autorelease];
}

-(NSRect)imageFrameForCellFrame:(NSRect)cellFrame
{
	if (image != nil)
	{
		NSRect imageFrame;
		imageFrame.size = [image size];
		imageFrame.origin = cellFrame.origin;
		imageFrame.origin.x += 3;
		imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
		return imageFrame;
	}
	return NSZeroRect;
}

-(void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
	NSRect textFrame, imageFrame;
	NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
	[super editWithFrame: textFrame inView: controlView editor:textObj delegate:anObject event: theEvent];
}

-(void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength
{
	NSRect textFrame, imageFrame;
	NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
	[super selectWithFrame: textFrame inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	int drawingOffset = (offset * 10);
	int cellContentWidth;

	cellContentWidth = [self cellSizeForBounds:cellFrame].width;
	if (image != nil)
		cellContentWidth += [image size].width + 3;
	if (drawingOffset + cellContentWidth > cellFrame.size.width)
	{
		drawingOffset = cellFrame.size.width - cellContentWidth;
		if (drawingOffset < 0)
			drawingOffset = 0;
	}
	cellFrame.origin.x += drawingOffset;
	if (image != nil)
	{
		NSSize	imageSize;
		NSRect	imageFrame;

		imageSize = [image size];
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
		if ([self drawsBackground])
		{
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.origin.x += 3;
		imageFrame.size = imageSize;
		
		if ([controlView isFlipped])
			imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
		else
			imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
		
		[image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}
	[super drawWithFrame:cellFrame inView:controlView];
}

-(NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	cellSize.width += (image ? [image size].width : 0) + 3;
	cellSize.height = [image size].height + 4;
	return cellSize;
}

/* dealloc
 * Delete our resources.
 */
-(void)dealloc
{
	[image release];
	[super dealloc];
}
@end