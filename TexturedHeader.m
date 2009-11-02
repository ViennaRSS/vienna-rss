//
//  TexturedHeader.m
//  Vienna
//
//  Created by Steve on 1/29/05.
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

#import "TexturedHeader.h"

// Private functions
@interface TexturedHeader (Private)
	-(NSRect)dragImageRect:(NSRect)bounds;
@end

@implementation TexturedHeader

-(id)initWithFrame:(NSRect)frame
{
	if ((self = [super initWithFrame:frame]) != nil)
	{
		metalBg = [[NSImage imageNamed:@"metal_column_header.png"] retain];
		attrs = [[NSMutableDictionary dictionaryWithDictionary:[[self attributedStringValue] attributesAtIndex:0 effectiveRange:NULL]] mutableCopy];
		[attrs setValue:[NSFont systemFontOfSize:11] forKey:@"NSFont"];

		// We want over-long header titles to be truncated in the middle.
        NSMutableParagraphStyle * style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode:NSLineBreakByTruncatingMiddle];
		[attrs setValue:style forKey:NSParagraphStyleAttributeName];
		[style release];

		// Load this even if we don't use it. Not that expensive.
		draggerImage = [NSImage imageNamed:@"draggerImage.png"];

		// Other bits
		attributedStringValue = nil;
		hasDragger = NO;
		isDragging = NO;
		dragOffset = 0;
	}
	return self;
}

/* setDragger
 * Sets whether or not a dragger is displayed on the header. If a dragger is set then
 * the setDelegate function must be called so that dragger events can be fed back to
 * the delegate.
 */
-(void)setDragger:(BOOL)show withSplitView:(NSSplitView *)view;
{
	hasDragger = show;
	splitView = view;	// Weak ref.
	[self display];
}

/* setStringValue
 * Sets the text to be displayed on the header. Cannot be NIL.
 */
-(void)setStringValue:(NSString *)newStringValue
{
	[attributedStringValue release];
	attributedStringValue = [[NSAttributedString alloc] initWithString:newStringValue];
	[self setNeedsDisplay:YES];
}

/* attributedStringValue
 * Returns the text displayed on the header as an attributed string.
 */
-(NSAttributedString *)attributedStringValue
{
	return attributedStringValue;
}

/* stringValue
 * Returns the text displayed on the header as a string.
 */
-(NSString *)stringValue
{
	return [attributedStringValue string];
}

/* drawRect
 * Paint the header.
 */
-(void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	float width = NSWidth(bounds);
	
	[metalBg drawInRect:bounds fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];

	// Draw black text centered. Constrain the draw rectangle to the
	// header size so the truncation works.
	NSString * stringValue = [self stringValue];

	NSRect textRect = bounds;
	if (hasDragger)
		textRect.size.width -= [draggerImage size].width + 2;
	
	NSRect centeredRect;
	centeredRect.size = [stringValue sizeWithAttributes:attrs];
	centeredRect.origin.x = ((textRect.size.width - centeredRect.size.width) / 2.0);
	centeredRect.origin.y = ((textRect.size.height - centeredRect.size.height) / 2.0);
	if (centeredRect.origin.x < 0)
		centeredRect.origin.x = 0;
	if (centeredRect.size.width > width)
		centeredRect.size.width = width;
	
	// Draw text twice -first slightly off-white, and then black 1 pixel higher- to give the standard "embossed" look.
	[attrs setValue:[NSColor colorWithCalibratedWhite:1.0 alpha:0.35] forKey:@"NSColor"];
	[stringValue drawInRect:centeredRect withAttributes:attrs];
	[attrs setValue:[NSColor blackColor] forKey:@"NSColor"];
	centeredRect.origin.y += 1;
	[stringValue drawInRect:centeredRect withAttributes:attrs];

	// Draw the dragger if it is present.
	if (hasDragger)
	{
		NSRect location = [self dragImageRect:bounds];
		[draggerImage drawInRect:location fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
}

/* mouseDown
 * Called when the user clicks in the header. We determine whether we're in the drag area and, if so,
 * we set isDragging so that subsequent mouse move events initiate a drag.
 */
-(void)mouseDown:(NSEvent *)event
{
	if (hasDragger)
	{
		NSPoint clickLocation = [self convertPoint:[event locationInWindow] fromView:nil];
		NSRect location = [self dragImageRect:[self bounds]];
		isDragging = NSPointInRect(clickLocation, location);
		if (isDragging)
		{
			clickLocation = [self convertPoint:[event locationInWindow] fromView:[self superview]];
			dragOffset = NSWidth([[self superview] frame]) - clickLocation.x;
		}
	}
}

/* mouseDragged
 * Handles the actual drag event to resize the splitview associated with this header.
 */
-(void)mouseDragged:(NSEvent *) event
{
	if (isDragging)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewWillResizeSubviewsNotification object:splitView];

		NSPoint clickLocation = [self convertPoint:[event locationInWindow] fromView:[self superview]];

		NSView * boundingView = [[self superview] superview];
		NSRect newFrame = [boundingView frame];
		newFrame.size.width = clickLocation.x + dragOffset;

		id delegate = [splitView delegate];
		if (delegate && [delegate respondsToSelector:@selector(splitView:constrainSplitPosition:ofSubviewAt:)])
		{
			float new = [delegate splitView:splitView constrainSplitPosition:newFrame.size.width ofSubviewAt:0];
			newFrame.size.width = new;
		}

		if (delegate && [delegate respondsToSelector:@selector(splitView:constrainMinCoordinate:ofSubviewAt:)])
		{
			float min = [delegate splitView:splitView constrainMinCoordinate:0. ofSubviewAt:0];
			newFrame.size.width = MAX(min, newFrame.size.width);
		}

		if (delegate && [delegate respondsToSelector:@selector(splitView:constrainMaxCoordinate:ofSubviewAt:)])
		{
			float max = [delegate splitView:splitView constrainMaxCoordinate:0. ofSubviewAt:0];
			newFrame.size.width = MIN(max, newFrame.size.width);
		}
		[boundingView setFrame:newFrame];
		[splitView adjustSubviews];
		[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:splitView];
	}
}

/* dragImageRect
 * Given the bounds of a view, returns the position and size of the dragger image in that view. This
 * works regardless of whether or not hasDragger is set.
 */
-(NSRect)dragImageRect:(NSRect)bounds
{
	NSRect location;
	
	location.size = [draggerImage size];
	location.origin = NSMakePoint(bounds.size.width - [draggerImage size].width, (bounds.size.height - [draggerImage size].height) / 2);
	return location;
}

/* resetCursorRects
 * Called to update the dragger cursor rect if applicable.
 */
-(void)resetCursorRects
{
	[super resetCursorRects];
	if (hasDragger)
		[self addCursorRect:[self dragImageRect:[self bounds]] cursor:[NSCursor resizeLeftRightCursor]];
}

/* dealloc
 * Clean up after ourselves.
 */
-(void)dealloc
{
	[attributedStringValue release];
	[metalBg release];
	[attrs release];
	[super dealloc];
}
@end
