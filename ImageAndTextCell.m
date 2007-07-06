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

#define PROGRESS_INDICATOR_DIMENSION	16
#define PROGRESS_INDICATOR_LEFT_MARGIN	1

@interface NSObject (ProgressIndicatorSupportingItem)
	-(NSProgressIndicator *)progressIndicator;
	-(void)setProgressIndicator:(NSProgressIndicator *)progressIndicator;
@end

@interface ImageAndTextCell (Private)
	-(void)configureProgressAnimation;
@end

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

		progressIndicators = [[NSMutableArray alloc] init];
	}
	return self;
}

-copyWithZone:(NSZone *)zone\
{
	ImageAndTextCell *cell = (ImageAndTextCell *)[super copyWithZone:zone];
	cell->image = [image retain];
	cell->auxiliaryImage = [auxiliaryImage retain];
	cell->offset = offset;
	cell->hasCount = hasCount;
	cell->count = count;
	cell->inProgress = inProgress;
	cell->countBackgroundColour = [countBackgroundColour retain];
	cell->item = item;	
	cell->progressIndicators = [[NSMutableArray alloc] init];
	cell->animationTimer = nil;

	return cell;
}

/* setOffset
 * Sets the new offset at which the cell contents will be drawn.
 */
-(void)setOffset:(int)newOffset
{
	offset = newOffset;
}

/* offset
 * Returns the current cell offset in effect.
 */
-(int)offset
{
	return offset;
}

/* setImage
 * Set the new image for the cell.
 */
-(void)setImage:(NSImage *)anImage
{
	[anImage retain];
	[image release];
	image = anImage;
}

/* image
 * Return the current image.
 */
-(NSImage *)image
{
	return [[image retain] autorelease];
}

/* setAuxiliaryImage
 * Sets the auxiliary image to be displayed. Nil removes any existing
 * auxiliary image.
 */
-(void)setAuxiliaryImage:(NSImage *)newAuxiliaryImage
{
	[newAuxiliaryImage retain];
	[auxiliaryImage release];
	auxiliaryImage = newAuxiliaryImage;
}

/* auxiliaryImage
 * Returns the current auxiliary image.
 */
-(NSImage *)auxiliaryImage
{
	return auxiliaryImage;
}

/* setCount
 * Sets the value to be displayed in the count button.
 */
-(void)setCount:(int)newCount
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
	[newColour retain];
	[countBackgroundColour release];
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
-(void)setItem:(id)inItem
{
	item = inItem;
}

/* configureProgressAnimation
 */
-(void)configureProgressAnimation
{
	if (!animationTimer && [progressIndicators count])
	{
		// See animateProgressIndicators: for what's going on here.
		// NSProgressIndicator animates 12 times per second by default

		animationTimer = [[NSTimer timerWithTimeInterval:1.0/12.0
												  target:self
												selector:@selector(animateProgressIndicators:)
												userInfo:nil
												 repeats:YES] retain];
		// A progress indicator must continue animating even while a menu or modal dialogue is displayed
		[[NSRunLoop currentRunLoop] addTimer:animationTimer forMode:NSEventTrackingRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:animationTimer forMode:NSDefaultRunLoopMode];

	}
	else if (animationTimer && ![progressIndicators count])
	{
		[animationTimer invalidate];
		[animationTimer release];
		animationTimer = nil;
	}
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
		
		if ([controlView isFlipped])
			imageFrame.origin.y += ceil((cellFrame->size.height + imageFrame.size.height) / 2);
		else
			imageFrame.origin.y += ceil((cellFrame->size.height - imageFrame.size.height) / 2);
		
		[image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}
}

/* drawInteriorWithFrame:inView:
 * Draw the cell complete the image and count button if specified.
 */
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// If the cell has a progress indicator, ensure it's framed properly
	// and then reduce cellFrame to keep from overlapping it
	if ([item respondsToSelector:@selector(progressIndicator)])
	{
		NSProgressIndicator *progressIndicator = [item progressIndicator];
		if (!inProgress && progressIndicator)
		{
			[progressIndicator stopAnimation:self];
			[progressIndicator removeFromSuperviewWithoutNeedingDisplay];
			[progressIndicators removeObject:progressIndicator];
			// The item was keeping track of the progress indicator; it is no longer needed
			[item setProgressIndicator:nil];
			[self configureProgressAnimation];
		}
		else if (inProgress)
		{
			if (!progressIndicator)
			{
				progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0,
																						  PROGRESS_INDICATOR_DIMENSION, PROGRESS_INDICATOR_DIMENSION)];
				[progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
				[progressIndicator setDisplayedWhenStopped:YES];
				[progressIndicators addObject:progressIndicator];
				
				// Let the item keep track of this progress indicator for us so we can stop it later
				[item setProgressIndicator:progressIndicator];
				[self configureProgressAnimation];
				[progressIndicator autorelease];
			}

			NSRect progressIndicatorFrame;

			NSDivideRect(cellFrame, &progressIndicatorFrame, &cellFrame, PROGRESS_INDICATOR_DIMENSION + PROGRESS_INDICATOR_LEFT_MARGIN, NSMaxXEdge);

			progressIndicatorFrame.size = NSMakeSize(PROGRESS_INDICATOR_DIMENSION, PROGRESS_INDICATOR_DIMENSION);
			progressIndicatorFrame.origin.x += PROGRESS_INDICATOR_LEFT_MARGIN;

			if ([progressIndicator superview] != controlView)
				[controlView addSubview:progressIndicator];

			if (!NSEqualRects([progressIndicator frame], progressIndicatorFrame)) {
				[progressIndicator setFrame:progressIndicatorFrame];
			}
		}
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
		
		if ([controlView isFlipped])
			imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
		else
			imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
		
		[auxiliaryImage compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}
	
	// If the cell has a count button, draw the count
	// button on the right of the cell.
	if (hasCount)
	{
		NSString * number = [NSString stringWithFormat:@"%i", count];

		// Use the current font point size as a guide for the count font size
		float pointSize = [[self font] pointSize];

		// Create attributes for drawing the count.
		NSDictionary * attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica-Bold" size:pointSize],
			NSFontAttributeName,
			[NSColor whiteColor],
			NSForegroundColorAttributeName,
			nil];
		NSSize numSize = [number sizeWithAttributes:attributes];

		// Compute the dimensions of the count rectangle.
		int cellWidth = MAX(numSize.width + 6, numSize.height + 1) + 1;

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
		[attributes release];
	}

	// Draw the text
	cellFrame.origin.y += 1;
	cellFrame.origin.x += 2;
	
	[super drawInteriorWithFrame:cellFrame inView:controlView];
}

/* selectWithFrame
 * Draws the selection around the cell. We overload this to handle our custom field editor
 * frame in the FolderView class.
 */
-(void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength
{
	if ([controlView isKindOfClass:[FolderView class]])
	{
		aRect.size = [self cellSize];
		if (image != nil)
			aRect.origin.x += [image size].width + 3;
		++aRect.origin.y;
		[controlView performSelector:@selector(prvtResizeTheFieldEditor) withObject:nil afterDelay:0.001];
	}
	[super selectWithFrame:aRect inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

/* animateProgressIndicators:
 * Animate our progress indicators.
 *
 * Why not just use the automatic animation (-[NSProgressIndicator startAnimation:])?
 *   1) It doesn't clip properly for a cell partly off-screen; it relocates the spinner to keep its bottom edge
 *   on-screen at all times. This means that a cell which is partially off-screen won't show its spinner in the right vertical location.
 *   2) It doesn't update properly when scrolling; one frame of a white square is displayed as a progress indicator
 *   moves on- or off- screen by an additional pixel. This occurs with threaded and non-thread indicator behavior.
 *
 * Why use a timer rather than drawing in one of the NSCell drawing methods?
 *   The timer needs to update 12 times per second to be smooth; the NSCell drawing method is only called if the cell contents change
 *   or the user interacts with that cell.
 */
-(void)animateProgressIndicators:(NSTimer *)timer
{
	NSEnumerator *enumerator = [progressIndicators objectEnumerator];
	NSProgressIndicator *indicator;
	
	while ((indicator = [enumerator nextObject])) {
		[indicator animate:nil];
	}	
}

/* dealloc
 * Delete our resources.
 */
-(void)dealloc
{
	[countBackgroundColour release];
	[auxiliaryImage release];
	[image release];
	
	[progressIndicators release];
	[animationTimer invalidate];
	[animationTimer release];
	
	[super dealloc];
}

@end