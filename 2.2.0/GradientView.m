//
//  GradientView.m
//  Vienna
//
//  Created by Michael Stroeck on 06.02.07.
//  Copyright 2007 Michael Stroeck. All rights reserved.
//

#import "GradientView.h"
#import "CTGradient.h"

@implementation GradientView

- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    return self;
}

- (void)drawRect:(NSRect)rect 
{
	NSColor *topColor = [NSColor whiteColor];
	NSColor *bottomColor = [NSColor grayColor];
	CTGradient *gradient = [CTGradient gradientWithBeginningColor:topColor
													  endingColor:bottomColor];
	[gradient fillRect:[self bounds] angle:270];
}
@end
