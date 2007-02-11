//
//  SourceListSplitView.m
//  Vienna
//
//  Created by Michael Stroeck on 06.02.07.
//  Copyright 2007 Michael Stroeck. All rights reserved.
//

#import "SourceListSplitView.h"

#define MIN_LEFT_VIEW_WIDTH 72
#define MIN_RIGHT_VIEW_WIDTH 400

@implementation SourceListSplitView

-(void)awakeFromNib
{
	[super awakeFromNib];
	[self setDelegate:self];
	leftSubview = [[self subviews] objectAtIndex:0];
	rightSubview = [[self subviews] objectAtIndex:1];
}

- (float)dividerThickness
{
	return 1.0;
}

- (void)drawDividerInRect:(NSRect)aRect
{
	[[NSColor blackColor] set];
	NSRectFill (aRect);
}

- (float)splitView:(KFSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return (proposedMin + MIN_LEFT_VIEW_WIDTH);
}

- (float)splitView:(KFSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	return (proposedMax - MIN_RIGHT_VIEW_WIDTH);
}

- (void)splitView:(id)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	float newHeight = [sender frame].size.height;
	float newWidth = [sender frame].size.width - [leftSubview frame].size.width - [self dividerThickness];

	NSRect newFrame = [leftSubview frame];
	newFrame.size.height = newHeight;
	[leftSubview setFrame:newFrame];

	newFrame = [rightSubview frame];
	newFrame.size.width = newWidth;
	newFrame.size.height = newHeight;
	[rightSubview setFrame:newFrame];
	
	[sender adjustSubviews];
}

@end
