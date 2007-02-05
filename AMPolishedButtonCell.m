//
//  AMPolishedButtonCell.m
//  Polished Button
//
//  Created by Andy Matuschak on 7/31/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#import "AMPolishedButtonCell.h"
#import <QuartzCore/QuartzCore.h>

@interface AMPolishedButtonCell (Private)
- (void)setupAppearance;
- (void)drawImageWithFrame:(NSRect)frame inView:(NSButton *)view;
- (void)drawEmbossingHighlightForImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSButton *)view;
@end

@implementation AMPolishedButtonCell

- initWithCoder:(NSCoder *)coder
{
	[super initWithCoder:coder];
	[self setupAppearance];
	return self;
}

- initTextCell:(NSString *)text
{
	[super initTextCell:text];
	[self setupAppearance];
	return self;
}

- initImageCell:(NSImage *)image
{
	[super initImageCell:image];
	[self setupAppearance];
	return self;
}

- (void)setupAppearance
{
	[self setFont:[NSFont boldSystemFontOfSize:11.5]];
}

- (BOOL)isOpaque
{
	return NO;
}

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView*)view
{
	NSString *mode;
	if ([self isHighlighted])
		mode = @"pressed";
	else if (![self isEnabled])
		mode = @"disabled";
	else
		mode = @"normal";
	NSString *prefix = [NSString stringWithFormat:@"button_%@_", mode];
	
	NSImage *left, *right, *middle;
	left = [NSImage imageNamed:[prefix stringByAppendingString:@"left"]];
	middle = [NSImage imageNamed:[prefix stringByAppendingString:@"middle"]];
	right = [NSImage imageNamed:[prefix stringByAppendingString:@"right"]];
	[left setFlipped:[view isFlipped]];
	[middle setFlipped:[view isFlipped]];
	[right setFlipped:[view isFlipped]];
	
	[left drawAtPoint:frame.origin fromRect:(NSRect){NSZeroPoint, [left size]} operation:NSCompositeSourceAtop fraction:1];
	[right drawAtPoint:NSMakePoint(NSMaxX(frame) - [right size].width, frame.origin.y) fromRect:(NSRect){NSZeroPoint, [right size]} operation:NSCompositeSourceAtop fraction:1];
	[middle drawInRect:NSMakeRect(frame.origin.x + [left size].width, frame.origin.y, frame.size.width - [left size].width - [right size].width, [middle size].height) fromRect:(NSRect){NSZeroPoint, [middle size]} operation:NSCompositeSourceAtop fraction:1];
}

- (void)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)view
{
	NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] initWithAttributedString:title] autorelease];
	// First draw the white "embossing" string.
	[string addAttributes:[NSMutableDictionary dictionaryWithObject:[NSColor colorWithCalibratedWhite:1 alpha:0.9] forKey:NSForegroundColorAttributeName] range:NSMakeRange(0, [string length])];
	[super drawTitle:string withFrame:frame inView:view];
	// Then draw the normal string on top.
	[string addAttributes:[NSMutableDictionary dictionaryWithObject:[NSColor colorWithCalibratedWhite:0 alpha:([self isEnabled] ? 0.9 : 0.6)] forKey:NSForegroundColorAttributeName] range:NSMakeRange(0, [string length])];
	[super drawTitle:string withFrame:NSOffsetRect(frame, 0, ([view isFlipped] ? -1 : 1)) inView:view];	
}

- (void)drawImageWithFrame:(NSRect)frame inView:(NSButton *)view
{
	NSImage *image;
	if ([self isHighlighted] && [self alternateImage])
		image = [self alternateImage];
	else
		image = [self image];
#ifdef POLISHED_BUTTON_USES_CORE_IMAGE_BEZELS
	[self drawEmbossingHighlightForImage:image withFrame:frame inView:view];
#endif
	[super drawImage:image withFrame:NSOffsetRect(frame, 0, ([view isFlipped] ? -1 : 1)) inView:view];
}

#ifdef POLISHED_BUTTON_USES_CORE_IMAGE_BEZELS
- (void)drawEmbossingHighlightForImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSButton *)view
{
	// Desaturate the image and pump up its brightness to get a good embossing highlight.
	CIFilter *colorAdjust = [CIFilter filterWithName:@"CIColorControls"];
	[colorAdjust setValue:[NSNumber numberWithFloat:0.0] forKey:@"inputSaturation"];
	[colorAdjust setValue:[NSNumber numberWithFloat:0.75] forKey:@"inputBrightness"];
	[colorAdjust setValue:[CIImage imageWithData:[image TIFFRepresentation]] forKey:@"inputImage"];
	CIImage *result = [colorAdjust valueForKey:@"outputImage"];
	
	if ([view isFlipped])
	{
		// CIImage doesn't have a setFlipped, so we need to flip it the long way.
		CIFilter *transform = [CIFilter filterWithName:@"CIAffineTransform"];
		[transform setValue:result forKey:@"inputImage"];
		NSAffineTransform *affineTransform = [NSAffineTransform transform];
		[affineTransform translateXBy:0 yBy:[image size].height];
		[affineTransform scaleXBy:1 yBy:-1];
		[transform setValue:affineTransform forKey:@"inputTransform"];
		result = [transform valueForKey:@"outputImage"];
	}		
		
	[result drawAtPoint:NSMakePoint(NSMidX(frame) - [image size].width / 2.0, NSMidY(frame) - [image size].width / 2.0) fromRect:(NSRect){NSZeroPoint, [image size]} operation:NSCompositeSourceAtop fraction:([self isEnabled] ? 0.6 : 0.4)];
}
#endif

- (void)drawWithFrame:(NSRect)frame inView:(NSButton *)view
{
	[self drawInteriorWithFrame:frame inView:view];
	if ([self image] && [self imagePosition] != NSNoImage)
		[self drawImageWithFrame:frame inView:view];
	else
		[self drawTitle:[view attributedTitle] withFrame:frame inView:view];
}

@end
