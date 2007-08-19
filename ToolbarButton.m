//
//  ToolbarButton.m
//  Vienna
//
//  Created by Steve Palmer on 04/07/2007.
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
//  

#import "ToolbarButton.h"

@implementation ToolbarButton

/* initWithFrame
 * Initialise a ToolbarButton item. This is a subclass of a toolbar button
 * that responds properly to sizing requests from the toolbar.
 */
-(id)initWithFrame:(NSRect)frameRect withItem:(NSToolbarItem *)tbItem
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		item = tbItem;
		image = nil;
		alternateImage = nil;
		smallImage = nil;
		smallAlternateImage = nil;
		imageSize = NSMakeSize(32.0, 32.0);
		smallImageSize = NSMakeSize(24.0, 24.0);

		// Our toolbar buttons have specific attributes to make them
		// behave like toolbar buttons.
		[self setButtonType:NSMomentaryChangeButton];
		[self setBordered:NO];
		[self setBezelStyle:NSSmallSquareBezelStyle];
		[self setImagePosition:NSImageOnly];
	}
	return self;
}

/* setSmallImage
 * Set the image displayed when the button is made small.
 */
-(void)setSmallImage:(NSImage *)newImage
{
	[newImage retain];
	[smallImage release];
	smallImage = newImage;
	if (smallImage != nil)
		smallImageSize = [smallImage size];
}

/* setSmallAlternateImage
 * Set the alternate image for when the button is made small.
 */
-(void)setSmallAlternateImage:(NSImage *)newImage
{
	[newImage retain];
	[smallAlternateImage release];
	smallAlternateImage = newImage;
}

/* setImage
 * Override the setImage on the NSButton so we can cache the image and button size
 * and return the right size in setControlSize. Also call setScalesWhenResized
 * so we scale the image for small buttons if no alternatives are provided.
 */
-(void)setImage:(NSImage *)newImage
{
	[newImage retain];
	[image release];
	image = newImage;

	[image setScalesWhenResized:YES];
	[super setImage:image];
	if (image != nil)
	{
		imageSize = [image size];
	}
}

/* setAlternateImage
 * Override the setAlternateImage on the NSButton and call setScalesWhenResized
 * on the image so if we don't implement our own small images then we scale
 * properly.
 */
-(void)setAlternateImage:(NSImage *)newImage
{
	[newImage retain];
	[alternateImage release];
	alternateImage = newImage;
	
	[alternateImage setScalesWhenResized:YES];
	[super setAlternateImage:alternateImage];
}

/* controlSize
 * Return the control size. This must be implemented.
 */
-(NSControlSize)controlSize
{
	return [[self cell] controlSize];
}

/* setControlSize
 * Called by the toolbar control when the user changes the toolbar size.
 * We use this to adjust the button image.
 */
-(void)setControlSize:(NSControlSize)size
{
	NSSize s;

	if (size == NSRegularControlSize)
	{
		// When switching to regular size, if we have small versions then we
		// can assume that we're switching from those small versions. So we
		// need to replace the button image.
		[super setImage:image];
		[super setAlternateImage:alternateImage];
		s = imageSize;
	}
	else
	{
		// When switching to small size, use the small size images if they were
		// provided. Otherwise the button will scale the image down for us.
		if (smallImage == nil)
		{
			NSImage * scaledDownImage = [image copy];
			[scaledDownImage setScalesWhenResized:YES];
			// Small size is about 3/4 the size of the regular image or
			// generally 24x24.
			[scaledDownImage setSize:NSMakeSize(imageSize.width * 0.80, imageSize.height * 0.80)];
			[self setSmallImage:scaledDownImage];
			[scaledDownImage release];
		}
		if (smallAlternateImage == nil)
		{
			NSImage * scaledDownAlternateImage = [image copy];
			[scaledDownAlternateImage setScalesWhenResized:YES];
			// Small size is about 3/4 the size of the regular image or
			// generally 24x24.
			[scaledDownAlternateImage setSize:NSMakeSize(imageSize.width * 0.80, imageSize.height * 0.80)];
			[self setSmallImage:scaledDownAlternateImage];
			[scaledDownAlternateImage release];
		}
		[super setImage:smallImage];
		[super setAlternateImage:smallAlternateImage];
		s = smallImageSize;
	}

	[item setMinSize:s];
	[item setMaxSize:s];
}

/* dealloc
 * Clean up afterwards.
 */
-(void)dealloc
{
	[image release];
	[alternateImage release];
	[smallImage release];
	[smallAlternateImage release];
	[super dealloc];
}
@end
