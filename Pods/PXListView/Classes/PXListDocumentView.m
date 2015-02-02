//
//  PXListDocumentView.m
//  PXListView
//
//  Created by Alex Rozanski on 29/05/2010.
//  Copyright 2010 Alex Rozanski. http://perspx.com. All rights reserved.
//

#import "PXListDocumentView.h"

#import "PXListView.h"
#import "PXListView+Private.h"
#import "PXListView+UserInteraction.h"

@implementation PXListDocumentView

@synthesize listView = _listView;

- (BOOL)isFlipped
{
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[[self listView] handleMouseDownOutsideCells: theEvent];
}


-(void)	drawRect: (NSRect)dirtyRect
{
#pragma unused(dirtyRect)
	//NSLog( @"drawRect %lu", _dropHighlight );
	
	// We always show the outline:
	if( _dropHighlight != PXListViewDropNowhere )
	{
		CGFloat		lineWidth = 2.0f;
		CGFloat		lineWidthHalf = lineWidth / 2.0f;
		
		[[NSColor selectedControlColor] set];
		[NSBezierPath setDefaultLineWidth: lineWidth];
		[NSBezierPath strokeRect: NSInsetRect([self visibleRect], lineWidthHalf, lineWidthHalf)];
		//NSLog( @"drawing drop outline" );
	}
	
	if( _dropHighlight == PXListViewDropAbove || _dropHighlight == PXListViewDropBelow )	// DropAbove means as first cell, DropBelow after last cell.
	{
		CGFloat		lineWidth = 2.0f;
		NSRect		theBox = ([_listView numberOfRows] == 0) ? NSMakeRect(0,0,[self bounds].size.width,0) : [_listView rectOfRow: [_listView numberOfRows] -1];
		
		theBox.origin.y += theBox.size.height -2.0f;
		theBox.size.height = 2.0f;
		
		[[NSColor alternateSelectedControlColor] set];
		[NSBezierPath setDefaultLineWidth: lineWidth];
		[NSBezierPath strokeRect: theBox];
		//NSLog( @"drawing drop ABOVE indicator" );
	}
}

-(void)	setDropHighlight: (PXListViewDropHighlight)inState
{
	_dropHighlight = inState;
	//NSLog( @"setDropHighlight %lu", _dropHighlight );
	[self setNeedsDisplayInRect: [self visibleRect]];
}

-(PXListViewDropHighlight) dropHighlight
{
	return _dropHighlight;
}
@end
