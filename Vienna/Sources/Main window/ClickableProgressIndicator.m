//
//  ClickableProgressIndicator.m
//  Vienna
//
//  Created by Evan Schoenberg on 6/2/07.
//

#import "ClickableProgressIndicator.h"

@implementation ClickableProgressIndicator

- (void)setTarget:(id)inTarget
{
	target = inTarget;
}
- (void)setAction:(SEL)inAction
{
	action = inAction;
}
- (void)mouseDown:(NSEvent *)inEvent
{
	if (target && action)
	{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[target performSelector:action withObject:self];
#pragma clang diagnostic pop
	}
	else
		[super mouseDown:inEvent];
}

@end
