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

@implementation TexturedHeader

-(id)initWithFrame:(NSRect)frame
{
	if ((self = [super initWithFrame:frame]) != nil)
	{
		metalBg = [[NSImage imageNamed:@"metal_column_header.png"] retain];
		attrs = [[NSMutableDictionary dictionaryWithDictionary:[[self attributedStringValue] attributesAtIndex:0 effectiveRange:NULL]] mutableCopy];
		[attrs setValue:[NSFont systemFontOfSize:10] forKey:@"NSFont"];

		// We want over-long header titles to be truncated in the middle.
        NSMutableParagraphStyle * style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode:NSLineBreakByTruncatingMiddle];
		[attrs setValue:style forKey:NSParagraphStyleAttributeName];
		[style release];

		attributedStringValue = nil;
	}
	return self;
}

-(void)setStringValue:(NSString *)newStringValue
{
	[attributedStringValue release];
	attributedStringValue = [[NSAttributedString alloc] initWithString:newStringValue];
	[self display];
}

-(NSAttributedString *)attributedStringValue
{
	return attributedStringValue;
}

-(NSString *)stringValue
{
	return [attributedStringValue string];
}

-(void)drawRect:(NSRect)rect
{
	// Draw metalBg lowest pixel along the bottom of inFrame.
	NSRect tempSrc = NSZeroRect;
	tempSrc.size = [metalBg size];
	tempSrc.origin.y = tempSrc.size.height - 1.0;
	tempSrc.size.height = 1.0;

	NSRect tempDst = rect;
	tempDst.origin.y = rect.size.height - 1.0;
	tempDst.size.height = 1.0;
	[metalBg drawInRect:tempDst fromRect:tempSrc operation:NSCompositeSourceOver fraction:1.0];

	// Draw rest of metalBg along width of inFrame.
	tempSrc.origin.y = 0.0;
	tempSrc.size.height = [metalBg size].height - 1.0;

	tempDst.origin.y = 1.0;
	tempDst.size.height = rect.size.height - 2.0;
	[metalBg drawInRect:tempDst fromRect:tempSrc operation:NSCompositeSourceOver fraction:1.0];

	// Draw black text centered. Constrain the draw rectangle to the
	// header size so the truncation works.
	float offset = 0.5;

	NSRect centeredRect = rect;
	centeredRect.size = [[self stringValue] sizeWithAttributes:attrs];
	centeredRect.origin.x = ((rect.size.width - centeredRect.size.width) / 2.0) - offset;
	centeredRect.origin.y = ((rect.size.height - centeredRect.size.height) / 2.0) + offset;

	centeredRect.origin.x += offset;
	centeredRect.origin.y -= offset;
	if (centeredRect.origin.x < 0)
		centeredRect.origin.x = 0;
	if (centeredRect.size.width > rect.size.width)
		centeredRect.size.width = rect.size.width;
	
	// Draw text twice -first slightly off-white, and then black 1 pixel higher- to give the standard "embossed" look.
	[attrs setValue:[NSColor colorWithCalibratedWhite:1.0 alpha:0.7] forKey:@"NSColor"];
	[[self stringValue] drawInRect:centeredRect withAttributes:attrs];
	[attrs setValue:[NSColor blackColor] forKey:@"NSColor"];
	centeredRect.origin.y += 1;
	[[self stringValue] drawInRect:centeredRect withAttributes:attrs];


}

-(void)dealloc
{
	[attributedStringValue release];
	[metalBg release];
	[attrs release];
	[super dealloc];
}
@end
