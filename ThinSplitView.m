//
//  ThinSplitView.m
//  Vienna
//
//  Created by Steve Palmer on 22/06/2007.
//  Copyright (c) 2004-2007 Steve Palmer. All rights reserved.
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

#import "ThinSplitView.h"

@implementation ThinSplitView

/* dividerThickness
 * Returns the thickness of the divider bar.
 */
-(float)dividerThickness
{
	if ([self isVertical])
		return 1;
	return 8.0;
}

/* drawDividerInRect
 * Draws the divider bar.
 */
-(void)drawDividerInRect:(NSRect)aRect
{
	if ([self isVertical])
	{
		[[NSColor colorWithCalibratedWhite:0.4 alpha:1] set];
		NSRectFill (aRect);
	}
	else
	{
		NSImage * grip = [NSImage imageNamed:@"DBListSplitViewDimple.tiff"];
		NSImage * bar = [NSImage imageNamed:@"DBListSplitViewBar.tiff"];
		[bar setFlipped:YES];
		[grip setFlipped:YES];

		NSImage * canvas = [[[NSImage alloc] initWithSize:aRect.size]  autorelease];
		NSRect canvasRect = NSMakeRect(0, 0, [canvas size].width, [canvas size].height);
		NSRect gripRect = NSMakeRect(0,2, [canvas size].width, [canvas size].height);
		gripRect.origin.x = (NSMidX(aRect)*1 - ([grip size].width/2));

		[canvas lockFocus];
		[bar setSize:aRect.size];
		[bar drawInRect:canvasRect fromRect:canvasRect operation:NSCompositeSourceOver fraction:1.0];
		[grip drawInRect:gripRect fromRect:canvasRect operation:NSCompositeSourceOver fraction:1.0];
		[canvas unlockFocus];

		[self lockFocus];
		[canvas drawInRect:aRect fromRect:canvasRect operation:NSCompositeSourceOver fraction:1.0];
		[self unlockFocus];
	}
}
@end
