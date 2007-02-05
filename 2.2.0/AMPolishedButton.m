//
//  AMPolishedButton.m
//  Polished Button
//
//  Created by Andy Matuschak on 7/31/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#import "AMPolishedButton.h"
#import "AMPolishedButtonCell.h"

@interface AMPolishedButton (Private)
- (void)setupPolishedButton;
@end

@implementation AMPolishedButton

+ (Class)cellClass
{
	return [AMPolishedButtonCell class];
}

- initWithCoder:(NSCoder *)coder
{
	[super initWithCoder:coder];
	// For some reason, replacing the cell clobbers the button's enabled status, so we store it and reset it later.
	BOOL enabled = [self isEnabled];
	[self setupPolishedButton];
	[self setEnabled:enabled];
	return self;
}

- (void)setupPolishedButton
{
	AMPolishedButtonCell *cell = [AMPolishedButtonCell alloc];
	if ([[self cell] image] && [[self cell] imagePosition] != NSNoImage)
	{
		[cell initImageCell:[[self cell] image]];
		[cell setAlternateImage:[[self cell] image]];
		[cell setImagePosition:[[self cell] imagePosition]];
	}
	else
	{
		[cell initTextCell:[self title]];
	}
	[cell setButtonType:NSMomentaryChangeButton];
	[cell autorelease];
	[self setCell:cell];
}

@end
