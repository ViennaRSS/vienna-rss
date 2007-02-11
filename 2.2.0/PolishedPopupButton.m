//
//  PolishedPopupButton.m
//  Vienna
//
//  Created by Michael Stroeck on 11.02.07.
//  Copyright (c) 2007 Michael Stroeck. All rights reserved.
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
#import "PolishedPopupButton.h"

@implementation PolishedPopupButton

/* init
 * Initialises a simple subclass of NSButton that pops up a menu
 * if one is associated with it.
 */

-(id)init
{
	if ((self = [super init]) != nil)
	{
		theMenu = nil;
		popBelow = NO;
		popupFont = [NSFont menuFontOfSize:0];
	}
	return self;
}

/* setSmallMenu
 * Specifies that the popup menu should use a small font.
 */
-(void)setSmallMenu:(BOOL)useSmallMenu
{
	popupFont = [NSFont menuFontOfSize:(useSmallMenu ? 12 : 0)];
	popBelow = YES;
}

/* setMenu
 * Set the menu associated with this button
 */
-(void)setMenu:(NSMenu *)menu
{
	[menu retain];
	[theMenu release];
	theMenu = menu;
}

/* menu
 * Return the current menu associated with the button.
 */
-(NSMenu *)menu
{
	return theMenu;
}

/* mouseDown
 * Handle the mouse down event over the button. If we have a menu associated with
 * ourselves, pop up the menu above the button.
 */
-(void)mouseDown:(NSEvent *)theEvent
{
	if ([self isEnabled] && theMenu != nil)
	{
		[self highlight:YES];
		NSPoint popPoint = NSMakePoint([self bounds].origin.x, [self bounds].origin.y);
		if (popBelow)
			popPoint.y += [self bounds].size.height + 5;
        NSEvent * evt = [NSEvent mouseEventWithType:[theEvent type]
								 location:[self convertPoint:popPoint toView:nil]
							modifierFlags:[theEvent modifierFlags]
								timestamp:[theEvent timestamp]
							 windowNumber:[theEvent windowNumber]
								  context:[theEvent context]
							  eventNumber:[theEvent eventNumber]
							   clickCount:[theEvent clickCount]
								 pressure:[theEvent pressure]];
		[NSMenu popUpContextMenu:theMenu withEvent:evt forView:self withFont:popupFont];
		[self highlight:NO];
	}
}

/* mouseUp
 * Handle the mouse up event over the button.
 */
-(void)mouseUp:(NSEvent *)theEvent
{
	if ([self isEnabled])
		[self highlight:NO];
}

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
	[theMenu release];
	[super dealloc];
}
@end