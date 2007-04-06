//
//  ContentSplitView.m
//
//  Created by Dave Batton, August 2006.
//  http://www.Mere-Mortal-Software.com/
//	
//	Changes by Michael Stroeck on February 11, 2007.
//
//  Copyright 2006 by Dave Batton. Some rights reserved.
//  http://creativecommons.org/licenses/by/2.5/
//
//  This class draws a horizontal splitter like the one seen in Apple Mail (Tiger), below the message list and above the message detail view.
//  It subclasses KFSplitView from Ken Ferry so that the splitter remembers where it was last left. It also allows the splitter to expand and
//  collapse when double-clicked. The splitter thickness is reduced a bit and a background image and dimple are drawn in the splitter.
//
//  Assumes the ContentSplitViewBar and ContentSplitViewDimple images are available.
//

#define MIN_TOP_VIEW_HEIGHT		90
#define MIN_BOTTOM_VIEW_HEIGHT	60
#define DIVIDER_BAR_THICKNESS	8

#import "ContentSplitView.h"

@implementation ContentSplitView

/* awakeFromNib
 */
-(void)awakeFromNib
{
	[self setDelegate:self];
	
	bar = [NSImage imageNamed:@"ContentSplitViewBar.tiff"];
	[bar setFlipped:YES];

	grip = [NSImage imageNamed:@"ContentSplitViewDimple.tiff"];
	[grip setFlipped:YES];
}

/* dividerThickness
 * Returns the thickness of the divider bar.
 */
-(float)dividerThickness
{
	return DIVIDER_BAR_THICKNESS;
}

/* drawDividerInRect
 * Draws the divider bar.
 */
-(void)drawDividerInRect:(NSRect)aRect
{	
	// Create a canvas
	NSImage * canvas = [[[NSImage alloc] initWithSize:aRect.size] autorelease];

	// Draw bar and grip onto the canvas
	NSRect canvasRect = NSMakeRect(0, 0, [canvas size].width, [canvas size].height);
	NSRect gripRect = canvasRect;
	gripRect.origin.x = (NSMidX(canvasRect) - ([grip size].width / 2));
	gripRect.origin.y = (NSMidY(canvasRect) - ([grip size].height / 2));
	[canvas lockFocus];
	[bar setSize:aRect.size];
	[bar drawInRect:canvasRect fromRect:canvasRect operation:NSCompositeSourceOver fraction:1.0];
	[grip drawInRect:gripRect fromRect:canvasRect operation:NSCompositeSourceOver fraction:1.0];
	[canvas unlockFocus];

	// Draw canvas to divider bar
	[self lockFocus];
	[canvas drawInRect:aRect fromRect:canvasRect operation:NSCompositeSourceOver fraction:1.0];
	[self unlockFocus];
}
@end