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
#import "BezierPathExtensions.h"
#import "FolderView.h"
#import "TreeNode.h"

#define PROGRESS_INDICATOR_LEFT_MARGIN	1


/* All of this stuff taken from public stuff published
 * by Apple.
 */
@implementation ImageAndTextCell

/* init
 * Initialise a default instance of our cell.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		image = nil;
		auxiliaryImage = nil;
		offset = 0;
		hasCount = NO;
		count = 0;
		[self setCountBackgroundColour:[NSColor shadowColor]];
	}
	return self;
}

-copyWithZone:(NSZone *)zone\
{
	ImageAndTextCell *cell = (ImageAndTextCell *)[super copyWithZone:zone];
	cell->image = image;
	cell->auxiliaryImage = auxiliaryImage;
	cell->offset = offset;
	cell->hasCount = hasCount;
	cell->count = count;
	cell->inProgress = inProgress;
	cell->countBackgroundColour = countBackgroundColour;
	cell->item = item;	

	return cell;
}

/* setOffset
 * Sets the new offset at which the cell contents will be drawn.
 */
-(void)setOffset:(NSInteger)newOffset
{
	offset = newOffset;
}

/* offset
 * Returns the current cell offset in effect.
 */
-(NSInteger)offset
{
	return offset;
}

/* setImage
 * Set the new image for the cell.
 */
-(void)setImage:(NSImage *)anImage
{
	image = anImage;
}

/* image
 * Return the current image.
 */
-(NSImage *)image
{
	return image;
}

/* setAuxiliaryImage
 * Sets the auxiliary image to be displayed. Nil removes any existing
 * auxiliary image.
 */
-(void)setAuxiliaryImage:(NSImage *)newAuxiliaryImage
{
	auxiliaryImage = newAuxiliaryImage;
}

/* auxiliaryImage
 * Returns the current auxiliary image.
 */
-(NSImage *)auxiliaryImage
{
	return auxiliaryImage;;
}

/* setCount
 * Sets the value to be displayed in the count button.
 */
-(void)setCount:(NSInteger)newCount
{
	count = newCount;
	hasCount = YES;
}

/* clearCount
 * Removes the count button.
 */
-(void)clearCount
{
	hasCount = NO;
}

/* setCountBackgroundColour
 * Sets the colour used for the count button background.
 */
-(void)setCountBackgroundColour:(NSColor *)newColour
{
	countBackgroundColour = newColour;
}

/* setInProgress
 * Set whether an active progress should be shown for the item. This should be used in a willDisplayCell: style method.
 */
-(void)setInProgress:(BOOL)newInProgress
{
	inProgress = newInProgress;
}

/* setItem
 * Set the item which is being displayed. This should be used in a willDisplayCell: style method.
 */
-(void)setItem:(TreeNode *)newItem
{
	item = newItem;
}

/* drawCellImage
 * Just draw the cell image.
 */
-(void)drawCellImage:(NSRect *)cellFrame inView:(NSView *)controlView
{
	if (image != nil)
	{
		NSSize imageSize;
		NSRect imageFrame;
		
		imageSize = [image size];
		NSDivideRect(*cellFrame, &imageFrame, cellFrame, 3 + imageSize.width, NSMinXEdge);
		if ([self drawsBackground])
		{
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.origin.x += 3;
		imageFrame.size = imageSize;
		// vertically center
		imageFrame.origin.y += (cellFrame->size.height - imageSize.height) / 2.0;
		
		[image drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f respectFlipped:YES hints:NULL];

	}
}

/* drawInteriorWithFrame:inView:
 * Draw the cell complete the image and count button if specified.
 */
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// If the cell has a progress indicator, ensure it's framed properly
	// and then reduce cellFrame to keep from overlapping it
	if (inProgress)
	{
		NSProgressIndicator *progressIndicator = [item progressIndicator];
		if (!progressIndicator)
			progressIndicator = [item allocAndStartProgressIndicator];

		NSRect progressIndicatorFrame;

		NSDivideRect(cellFrame, &progressIndicatorFrame, &cellFrame, PROGRESS_INDICATOR_DIMENSION + PROGRESS_INDICATOR_LEFT_MARGIN, NSMaxXEdge);

		progressIndicatorFrame.size = NSMakeSize(PROGRESS_INDICATOR_DIMENSION, PROGRESS_INDICATOR_DIMENSION);
		progressIndicatorFrame.origin.x += PROGRESS_INDICATOR_LEFT_MARGIN;
		progressIndicatorFrame.origin.y += (cellFrame.size.height - PROGRESS_INDICATOR_DIMENSION) / 2.0;

		if (!NSEqualRects([progressIndicator frame], progressIndicatorFrame)) {
			[progressIndicator setFrame:progressIndicatorFrame];

		if ([progressIndicator superview] != controlView)
			[controlView addSubview:progressIndicator];
		}
	}
	else
	{
		[item stopAndReleaseProgressIndicator];
	}


	// If the cell has an image, draw the image and then reduce
	// cellFrame to move the text to the right of the image.
	if (image != nil)
		[self drawCellImage:&cellFrame inView:controlView];

	// If we have an error image, it appears on the right hand side.
	if (auxiliaryImage)
	{
		NSSize imageSize;
		NSRect imageFrame;
		
		imageSize = [auxiliaryImage size];
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMaxXEdge);
		if ([self drawsBackground])
		{
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.size = imageSize;
		// vertically center
		imageFrame.origin.y += (cellFrame.size.height - imageSize.height) / 2.0;
		
		[auxiliaryImage drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f respectFlipped:YES hints:NULL];

	}
	
	// If the cell has a count button, draw the count
	// button on the right of the cell.
	if (hasCount)
	{
		NSString * number = [NSString stringWithFormat:@"%li", (long)count];

		// Use the current font point size as a guide for the count font size
		CGFloat pointSize = [[self font] pointSize];

		// Create attributes for drawing the count.
		NSDictionary * attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica-Bold" size:pointSize],
			NSFontAttributeName,
			[NSColor whiteColor],
			NSForegroundColorAttributeName,
			nil];
		NSSize numSize = [number sizeWithAttributes:attributes];

		// Compute the dimensions of the count rectangle.
		CGFloat cellWidth = MAX(numSize.width + 6.0, numSize.height + 1.0) + 1.0;

		NSRect countFrame;
		NSDivideRect(cellFrame, &countFrame, &cellFrame, cellWidth, NSMaxXEdge);
		if ([self drawsBackground])
		{
			[[self backgroundColor] set];
			NSRectFill(countFrame);
		}

		countFrame.origin.y += 1;
		countFrame.size.height -= 2;
		NSBezierPath * bp = [NSBezierPath bezierPathWithRoundRectInRect:countFrame radius:numSize.height / 2];
		[countBackgroundColour set];
		[bp fill];

		// Draw the count in the rounded rectangle we just created.
		NSPoint point = NSMakePoint(NSMidX(countFrame) - numSize.width / 2.0f,  NSMidY(countFrame) - numSize.height / 2.0f );
		[number drawAtPoint:point withAttributes:attributes];
	}

	// Draw the text
	cellFrame.origin.x += 2;
	cellFrame.size.height -= 1;
	
	[super drawInteriorWithFrame:cellFrame inView:controlView];
}

/* selectWithFrame
 * Draws the selection around the cell. We overload this to handle our custom field editor
 * frame in the FolderView class, and to keep the image visible
 */
-(void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
	if ([controlView isKindOfClass:[FolderView class]])
	{
		if (image != nil)
			aRect.origin.x += [image size].width + 3;
		++aRect.origin.y;
		[controlView performSelector:@selector(prvtResizeTheFieldEditor) withObject:nil afterDelay:0.001];
	}
	[super selectWithFrame:aRect inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

-(NSArray*)accessibilityAttributeNames
{
    static NSArray * attributes = nil;
    if (!attributes)
    {
        NSSet * set = [NSSet setWithArray:[super accessibilityAttributeNames]];
        attributes = [[set setByAddingObject:NSAccessibilityDescriptionAttribute] allObjects];
    }
    return attributes;
}

-(id)accessibilityAttributeValue:(NSString *)attribute
{
    if ([attribute isEqualToString:NSAccessibilityDescriptionAttribute])
    {
        NSMutableArray * bits = [NSMutableArray arrayWithCapacity:3];
        if (auxiliaryImage && auxiliaryImage.accessibilityDescription)
            [bits addObject:auxiliaryImage.accessibilityDescription];
        if (hasCount)
            [bits addObject:[NSString stringWithFormat:NSLocalizedString(@"%d unread articles", nil), count]];
        if (inProgress)
            [bits addObject:NSLocalizedString(@"Loading", nil)];
        if (bits.count)
            return [bits componentsJoinedByString:@", "];
    }
    return [super accessibilityAttributeValue:attribute];
}

/* dealloc
 * Delete our resources.
 */
-(void)dealloc
{
	countBackgroundColour=nil;
	auxiliaryImage=nil;
	image=nil;
}

@end