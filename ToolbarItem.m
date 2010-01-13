//
//  ToolbarItem.m
//  Vienna
//
//  Created by Steve Palmer on 05/07/2007.
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

#import "ToolbarItem.h"
#import "ToolbarButton.h"
#import "PopupButton.h"

#define CenterRect(x,y) (NSMakeRect(((x).width - (y).width)/2, (((x).height - (y).height)/2), (y).width, (y).height))		

@implementation ToolbarItem

/* validate
 * Override validate so that we pass the call to the view target. By default,
 * toolbar items which are based on views don't get any validation.
 */
-(void)validate
{
	if (![NSApp isActive])
		[self setEnabled:NO];
	else 
		[self setEnabled:YES];
	id target = [self target];
	if ([target respondsToSelector:@selector(validateToolbarItem:)])
		[self setEnabled:[target validateToolbarItem:self]];
}

/* setEnabled
 * Extends the setEnabled on the item to pass on the call to the menu attached
 * to a popup button menu item.
 */
-(void)setEnabled:(BOOL)enabled
{
	[super setEnabled:enabled];
	[[self menuFormRepresentation] setEnabled:enabled];
}

/* setView
 * Extends the setView to also set the button min/max size from the view size.
 */
-(void)setView:(NSView *)theView
{
	NSRect fRect = [theView frame];
	[super setView:theView];
	[self setMinSize:fRect.size];
	[self setMaxSize:fRect.size];
}

/* compositeButtonImage
 * Define the toolbar item as a button and initialises it with the necessary
 * attributes and states by compositing a blank button with the specified image
 * from the given folder.
 */
-(void)compositeButtonImage:(NSString *)imageName fromPath:(NSString *)path
{
	NSString * theImage = [NSString stringWithFormat:@"%@.tiff", imageName];
	NSString * theSmallImage = [NSString stringWithFormat:@"small%@.tiff", imageName];
	NSString * resourcePath = [[NSBundle mainBundle] resourcePath];
	NSImage * userImage = [[NSImage alloc] initWithContentsOfFile:[path stringByAppendingPathComponent:theImage]];
	NSSize userImageSize = [userImage size];
	NSRect userImageRect = NSMakeRect(0.0, 0.0, userImageSize.width, userImageSize.height);

	// May not necessarily be a small image in which case we'd need to synthesize one from the large one
	NSImage * smallUserImage = [[NSImage alloc] initWithContentsOfFile:[path stringByAppendingPathComponent:theSmallImage]];
	NSSize smallUserImageSize;
	NSRect smallUserImageRect;

	if (smallUserImage != nil)
	{
		smallUserImageSize = [smallUserImage size];
		smallUserImageRect = NSMakeRect(0.0, 0.0, smallUserImageSize.width, smallUserImageSize.height);
	}
	else
	{
		smallUserImage = [userImage retain];
		smallUserImageSize = NSMakeSize(12.0, 12.0);
		smallUserImageRect = userImageRect;
	}

	NSImage * buttonImage = [[NSImage alloc] initWithContentsOfFile:[resourcePath stringByAppendingPathComponent:@"blankButton.tiff"]];
	NSSize buttonSize = [buttonImage size];
	[buttonImage lockFocus];
	[userImage drawInRect:CenterRect(buttonSize, userImageSize) fromRect:userImageRect operation:NSCompositeSourceOver fraction:1.0];
	[buttonImage unlockFocus];

	NSImage * pressedImage = [[NSImage alloc] initWithContentsOfFile:[resourcePath stringByAppendingPathComponent:@"blankButtonPressed.tiff"]];
	buttonSize = [pressedImage size];
	[pressedImage lockFocus];
	[userImage drawInRect:CenterRect(buttonSize, userImageSize) fromRect:userImageRect operation:NSCompositeSourceOver fraction:1.0];
	[pressedImage unlockFocus];
	
	NSImage * smallNormalImage = [[NSImage alloc] initWithContentsOfFile:[resourcePath stringByAppendingPathComponent:@"blankSmallButton.tiff"]];
	buttonSize = [smallNormalImage size];
	[smallNormalImage lockFocus];
	[smallUserImage drawInRect:CenterRect(buttonSize, smallUserImageSize) fromRect:smallUserImageRect operation:NSCompositeSourceOver fraction:1.0];
	[smallNormalImage unlockFocus];

	NSImage * smallPressedImage = [[NSImage alloc] initWithContentsOfFile:[resourcePath stringByAppendingPathComponent:@"blankSmallButtonPressed.tiff"]];
	buttonSize = [smallPressedImage size];
	[smallPressedImage lockFocus];
	[smallUserImage drawInRect:CenterRect(buttonSize, smallUserImageSize) fromRect:smallUserImageRect operation:NSCompositeSourceOver fraction:1.0];
	[smallPressedImage unlockFocus];
	
	[self setButtonImages:buttonImage
			 pressedImage:pressedImage
		 smallNormalImage:smallNormalImage
		smallPressedImage:smallPressedImage];
	
	[buttonImage release];
	[pressedImage release];
	[smallNormalImage release];
	[smallPressedImage release];
	[smallUserImage release];
	[userImage release];
}

/* setButtonImage
 * Define the toolbar item as a button and initialises it with the necessary
 * attributes and states using the specified image name.
 */
-(void)setButtonImage:(NSString *)imageName
{
	NSString * normalImage = [NSString stringWithFormat:@"%@.tiff", imageName];
	NSString * pressedImage = [NSString stringWithFormat:@"%@Pressed.tiff", imageName];
	NSString * smallNormalImage = [NSString stringWithFormat:@"%@Small.tiff", imageName];
	NSString * smallPressedImage = [NSString stringWithFormat:@"%@SmallPressed.tiff", imageName];

	[self setButtonImages:[NSImage imageNamed:normalImage]
			 pressedImage:[NSImage imageNamed:pressedImage]
		 smallNormalImage:[NSImage imageNamed:smallNormalImage]
		smallPressedImage:[NSImage imageNamed:smallPressedImage]];
}

/* setButtonImages
 * Define the toolbar item as a button and initialises it with the necessary
 * attributes and states using the specified set of images for each state.
 */
-(void)setButtonImages:(NSImage *)buttonImage pressedImage:(NSImage *)pressedImage smallNormalImage:(NSImage *)smallNormalImage smallPressedImage:(NSImage *)smallPressedImage
{
	NSSize buttonSize = [buttonImage size];
	ToolbarButton * button = [[ToolbarButton alloc] initWithFrame:NSMakeRect(0, 0, buttonSize.width, buttonSize.height) withItem:self];

	[button setImage:buttonImage];
	[button setAlternateImage:pressedImage];
	[button setSmallImage:smallNormalImage];
	[button setSmallAlternateImage:smallPressedImage];
	
	// Save the current target and action and reapply them afterward because assigning a view
	// causes them to be deleted.
	id currentTarget = [self target];
	SEL currentAction = [self action];
	[self setView:button];
	[self setTarget:currentTarget];
	[self setAction:currentAction];

	[button release];
}

/* setPopup
 * Defines the toolbar item as a popup button and initialises it with the specified
 * images and menu.
 */
-(void)setPopup:(NSString *)imageName withMenu:(NSMenu *)theMenu
{
	NSString * normalImage = [NSString stringWithFormat:@"%@.tiff", imageName];
	NSString * pressedImage = [NSString stringWithFormat:@"%@Pressed.tiff", imageName];
	NSString * smallNormalImage = [NSString stringWithFormat:@"%@Small.tiff", imageName];
	NSString * smallPressedImage = [NSString stringWithFormat:@"%@SmallPressed.tiff", imageName];
	
	NSImage * buttonImage = [NSImage imageNamed:normalImage];
	NSSize buttonSize = [buttonImage size];
	PopupButton * button = [[PopupButton alloc] initWithFrame:NSMakeRect(0, 0, buttonSize.width, buttonSize.height) withItem:self];
	
	[button setImage:buttonImage];
	[button setAlternateImage:[NSImage imageNamed:pressedImage]];
	[button setSmallImage:[NSImage imageNamed:smallNormalImage]];
	[button setSmallAlternateImage:[NSImage imageNamed:smallPressedImage]];
	
	[self setView:button];
	
	NSMenuItem * menuItem = [[[NSMenuItem alloc] init] autorelease];
	[button setTheMenu:theMenu];
	[button setPopupBelow:YES];
	[menuItem setSubmenu:[button theMenu]];
	[menuItem setTitle:[self label]];
	[self setMenuFormRepresentation:menuItem];
	
	[button release];
}
@end
