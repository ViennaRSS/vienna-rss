//
//  ProgressTextCell.m
//  Vienna
//
//  Created by Curtis Faith on Mon Mar 15, 2010 based on ImageAndTextCell.m
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

#import "ProgressTextCell.h"

#define PROGRESS_INDICATOR_LEFT_MARGIN	2
#define PROGRESS_INDICATOR_DIMENSION 16
#define NO_ROW -1


/* This code originally taken from public stuff published
 * by Apple and put into ImageAndTextCell. The code was modified to
 * handle the case where we are only interested in the progress
 * indicator and we don't have an associated TreeNode item to 
 * handle the indicator for us like we do in our ImageAndTextCell class
 * used for the folder/feed view.
 */
@implementation ProgressTextCell

/* init
 * Initialise a default instance of our cell.
 */
-(instancetype)init
{
	if ((self = [super init]) != nil)
	{
		inProgress = NO;
		progressRow = NO_ROW;
		currentRow = NO_ROW;
		progressIndicator = nil;
	}
	return self;
}

-copyWithZone:(NSZone *)zone\
{
	ProgressTextCell *cell = (ProgressTextCell *)[super copyWithZone:zone];
	cell->inProgress = inProgress;
	cell->progressRow = progressRow;
	cell->currentRow = currentRow;
	cell->progressIndicator = progressIndicator;	

	return cell;
}

/* setInProgress
 * Set whether an active progress indicator should be shown for the row. This 
 * is used in drawInteriorWithFrame: to show and hide the progress indicators. 
 * We need to remember the row because we only want to turn off the progress
 * indicator if we are redrawing the progress row. This method is generally
 * called in an implementation of NSTableView's willDisplayCell:.
 */
-(void)setInProgress:(BOOL)newInProgress forRow:(NSInteger)row;
{
	inProgress = newInProgress;
	if (inProgress)
		progressRow = row;
	currentRow = row;
}

/* drawInteriorWithFrame:inView:
 * Add or remove the progress indicator, if appropriate, and then have the
 * superclass draw the cell.
 */
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// If this row is the current progress row.
	if (currentRow == progressRow)
	{
		// If the cell has a progress indicator, ensure it's framed properly
		// and then reduce cellFrame to keep from overlapping it.
		if (inProgress)
		{
			if (!progressIndicator)
			{
				// Allocate and initialize the spinning progress indicator. 
				NSRect progressRect = NSMakeRect(0, 0, PROGRESS_INDICATOR_DIMENSION, PROGRESS_INDICATOR_DIMENSION);
				progressIndicator = [[NSProgressIndicator alloc] initWithFrame:progressRect];
				progressIndicator.controlSize = NSSmallControlSize;
				progressIndicator.style = NSProgressIndicatorSpinningStyle;
				[progressIndicator setDisplayedWhenStopped:YES];
				[progressIndicator setUsesThreadedAnimation:YES];
			}
			
			// Recompute the new cell frame taking out space on the right for the
			// progress indicator.
			NSRect progressIndicatorFrame;
			NSInteger cellHeight = cellFrame.size.height;
			NSInteger progressIndicatorSize = cellHeight < PROGRESS_INDICATOR_DIMENSION ? cellHeight : PROGRESS_INDICATOR_DIMENSION;
			NSInteger progressOffset = (cellHeight - progressIndicatorSize) / 2;
			NSInteger progressWidth = progressIndicatorSize + PROGRESS_INDICATOR_LEFT_MARGIN ;
			NSDivideRect(cellFrame, &progressIndicatorFrame, &cellFrame, progressWidth, NSMaxXEdge);

			// Set the size for the progress indicator frame and add the margin.
			progressIndicatorFrame.size = NSMakeSize(progressIndicatorSize, progressIndicatorSize);
			progressIndicatorFrame.origin.x += PROGRESS_INDICATOR_LEFT_MARGIN;
			// vertically center
			progressIndicatorFrame.origin.y += progressOffset;

			// Add the progress indicator as a subview of the controlView if 
			// it is not already one.
			if (progressIndicator.superview != controlView)
				[controlView addSubview:progressIndicator];

			// Set the progress indicator frame.
			if (!NSEqualRects(progressIndicator.frame, progressIndicatorFrame))
				progressIndicator.frame = progressIndicatorFrame;
		}
		else
		{
			// Stop the animation and remove from the superview.
			[progressIndicator setDisplayedWhenStopped:NO];
			[progressIndicator stopAnimation:self];
			[progressIndicator.superview setNeedsDisplayInRect:progressIndicator.frame];
			[progressIndicator removeFromSuperviewWithoutNeedingDisplay];
			
			// Release the progress indicator.
			progressIndicator = nil;
		}
	}

	// Draw the text
	cellFrame.origin.y += 1;
	cellFrame.origin.x += 2;
	cellFrame.size.height -= 1;
	[super drawInteriorWithFrame:cellFrame inView:controlView];

	// Now that everything is set, start the animation if necessary
	if (currentRow == progressRow && inProgress) {
		[progressIndicator startAnimation:self];
	}
}

@end