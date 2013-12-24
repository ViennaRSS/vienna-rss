//
//  PXListView+UserInteraction.m
//  PXListView
//
//  Created by Alex Rozanski on 27/03/2011.
//  Copyright 2011 Alex Rozanski. All rights reserved.
//

#import <iso646.h>

#import "PXListView+UserInteraction.h"
#import "PXListView+Private.h"

// Apple sadly doesn't provide CGFloat variants of these:
#if CGFLOAT_IS_DOUBLE
#define CGFLOATABS(n)	fabs(n)
#else
#define CGFLOATABS(n)	fabsf(n)
#endif

// This is a renamed copy of UKIsDragStart from <http://github.com/uliwitness/UliKit>:
static PXIsDragStartResult PXIsDragStart( NSEvent *startEvent, NSTimeInterval theTimeout )
{
	if( theTimeout == 0.0 )
		theTimeout = 1.5;
	
	NSPoint			startPos = [startEvent locationInWindow];
	NSTimeInterval	startTime = [NSDate timeIntervalSinceReferenceDate];
	NSDate*			expireTime = [NSDate dateWithTimeIntervalSinceReferenceDate: startTime +theTimeout];
	
	NSAutoreleasePool	*pool = nil;
	while( ([expireTime timeIntervalSinceReferenceDate] -[NSDate timeIntervalSinceReferenceDate]) > 0 )
	{
		[pool release];
		pool = [[NSAutoreleasePool alloc] init];
		
		NSEvent*	currEvent = [NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSRightMouseUpMask | NSOtherMouseUpMask
								 | NSLeftMouseDraggedMask | NSRightMouseDraggedMask | NSOtherMouseDraggedMask
												untilDate: expireTime inMode: NSEventTrackingRunLoopMode dequeue: YES];
		if( currEvent )
		{
			switch( [currEvent type] )
			{
				case NSLeftMouseUp:
				case NSRightMouseUp:
				case NSOtherMouseUp:
				{
					[pool release];
					return PXIsDragStartMouseReleased;	// Mouse released within the wait time.
					break;
				}
					
				case NSLeftMouseDragged:
				case NSRightMouseDragged:
				case NSOtherMouseDragged:
				{
					NSPoint	newPos = [currEvent locationInWindow];
					CGFloat	xMouseMovement = CGFLOATABS(newPos.x -startPos.x);
					CGFloat	yMouseMovement = CGFLOATABS(newPos.y -startPos.y);
					if( xMouseMovement > 2 or yMouseMovement > 2 )
					{
						[pool release];
						return (xMouseMovement > yMouseMovement) ? PXIsDragStartMouseMovedHorizontally : PXIsDragStartMouseMovedVertically;	// Mouse moved within the wait time, probably a drag!
					}
					break;
				}
			}
		}
		
	}
	
	[pool release];
	return PXIsDragStartTimedOut;	// If they held the mouse that long, they probably wanna drag.
}


@implementation PXListView (UserInteraction)

#pragma mark -
#pragma mark NSResponder

- (BOOL)canBecomeKeyView
{
	return YES;
}


- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	return YES;
}


- (BOOL)resignFirstResponder
{
	return YES;
}

#pragma mark -
#pragma mark Keyboard Handling

- (void)keyDown:(NSEvent *)theEvent
{
	[self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}


- (void)moveUp:(id)sender
{
    if([_selectedRows count]>0) {
        NSUInteger firstIndex = [_selectedRows firstIndex];
        
        if(firstIndex>0) {
            NSUInteger newRow = firstIndex-1;
            [self setSelectedRow:newRow];
            [self scrollRowToVisible:newRow];
        }
    }
}


- (void)moveDown:(id)sender
{
    if([_selectedRows count]>0) {
        NSUInteger lastIndex = [_selectedRows lastIndex];
        
        if(lastIndex<(_numberOfRows-1)) {
            NSUInteger newRow = lastIndex+1;
            [self setSelectedRow:newRow];
            [self scrollRowToVisible:newRow];
        }
    }
}


- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
	if([menuItem action] == @selector(selectAll:))
	{
		return _allowsMultipleSelection && [_selectedRows count] != _numberOfRows;	// No "select all" if everything's already selected or we can only select one row.
	}
	
    if([menuItem action] == @selector(deselectAll:))
	{
		return _allowsEmptySelection && [_selectedRows count] != 0;	// No "deselect all" if nothing's selected or we must have at least one row selected.
	}
    
    return NO;
}

#pragma mark - Mouse Events

- (void)handleMouseDown:(NSEvent*)theEvent inCell:(PXListViewCell*)theCell // Central funnel for cell clicks so cells don't have to know about multi-selection, modifiers etc.
{
    //Send a double click delegate message if the row has been double clicked
    if([theEvent clickCount]>1) {
        if([[self delegate] respondsToSelector:@selector(listView:rowDoubleClicked:)]) {
            [[self delegate] listView:self rowDoubleClicked:[theCell row]];
        }
    }
    
    // theEvent is NIL if we get a "press" action from accessibility. In that case, try to toggle, so users can selectively turn on/off an item.
    [[self window] makeFirstResponder:self];
    
    BOOL		tryDraggingAgain = YES;
    BOOL		shouldToggle = theEvent == nil || ([theEvent modifierFlags] & NSCommandKeyMask) || ([theEvent modifierFlags] & NSShiftKeyMask);	// +++ Shift should really be a continuous selection.
    BOOL		isSelected = [_selectedRows containsIndex: [theCell row]];
    NSIndexSet	*clickedIndexSet = [NSIndexSet indexSetWithIndex: [theCell row]];
    
    // If a cell is already selected, we can drag it out, in which case we shouldn't toggle it:
    if( theEvent && isSelected && [self attemptDragWithMouseDown: theEvent inCell: theCell] )
        return;
    
    if( _allowsMultipleSelection )
    {
        if( isSelected && shouldToggle )
        {
            if( [_selectedRows count] == 1 && !_allowsEmptySelection )
                return;
            [self deselectRowIndexes: clickedIndexSet];
        }
        else if( !isSelected && shouldToggle )
            [self selectRowIndexes: clickedIndexSet byExtendingSelection: YES];
        else if( !isSelected && !shouldToggle )
            [self selectRowIndexes: clickedIndexSet byExtendingSelection: NO];
        else if( isSelected && !shouldToggle && [_selectedRows count] != 1 )
        {
            [self selectRowIndexes: clickedIndexSet byExtendingSelection: NO];
            tryDraggingAgain = NO;
        }
    }
    else if( shouldToggle && _allowsEmptySelection )
    {
        if( isSelected )
        {
            [self deselectRowIndexes: clickedIndexSet];
            tryDraggingAgain = NO;
        }
        else
            [self selectRowIndexes: clickedIndexSet byExtendingSelection: NO];
    }
    else
    {
        [self selectRowIndexes: clickedIndexSet byExtendingSelection: NO];
    }
    
    // If a user selects a cell, they need to be able to drag it off right away, so check for that case here:
    if( tryDraggingAgain && theEvent && [_selectedRows containsIndex: [theCell row]] )
        [self attemptDragWithMouseDown: theEvent inCell: theCell];
}


- (void)handleMouseDownOutsideCells: (NSEvent*)theEvent
{
#pragma unused(theEvent)
    //[[self window] makeFirstResponder: self];
    //
	if( _allowsEmptySelection )
		[self deselectRows];
	else if( _numberOfRows > 1 )
	{
		NSUInteger	idx = 0;
		NSPoint		pos = [self convertPoint: [theEvent locationInWindow] fromView: nil];
		for( NSUInteger x = 0; x < _numberOfRows; x++ )
		{
			if( _cellYOffsets[x] > pos.y )
				break;
			
			idx = x;
		}
		
		[self setSelectedRow: idx];
	}
}

#pragma mark -
#pragma mark Drag and Drop

- (BOOL)attemptDragWithMouseDown:(NSEvent*)theEvent inCell:(PXListViewCell*)theCell
{
	PXIsDragStartResult	dragResult = PXIsDragStart( theEvent, 0.0 );
	if( dragResult != PXIsDragStartMouseReleased /*&& (_verticalMotionCanBeginDrag || dragResult != PXIsDragStartMouseMovedVertically)*/ )	// Was a drag, not a click? Cool!
	{
		NSPoint			dragImageOffset = NSZeroPoint;
		NSImage			*dragImage = [self dragImageForRowsWithIndexes: _selectedRows event: theEvent clickedCell: theCell offset: &dragImageOffset];
		NSPasteboard	*dragPasteboard = [NSPasteboard pasteboardWithUniqueName];
		
		if( [_delegate respondsToSelector: @selector(listView:writeRowsWithIndexes:toPasteboard:)]
           and [_delegate listView: self writeRowsWithIndexes: _selectedRows toPasteboard: dragPasteboard] )
		{
			[theCell dragImage: dragImage at: dragImageOffset offset: NSZeroSize event: theEvent
                    pasteboard: dragPasteboard source: self slideBack: YES];
			
			return YES;
		}
	}
	
	return NO;
}

-(NSImage*)	dragImageForRowsWithIndexes: (NSIndexSet *)dragRows event: (NSEvent*)dragEvent clickedCell: (PXListViewCell*)clickedCell offset: (NSPointPointer)dragImageOffset
{
#pragma unused(dragEvent)
	CGFloat		minX = CGFLOAT_MAX, maxX = CGFLOAT_MIN,
    minY = CGFLOAT_MAX, maxY = CGFLOAT_MIN;
	NSPoint		localMouse = [self convertPoint: NSZeroPoint fromView: clickedCell];
    
	if ([clickedCell isFlipped]) {
		localMouse = [self convertPoint:NSMakePoint(0, NSHeight(clickedCell.frame) * 2) fromView:clickedCell];
	}
    
	localMouse.y += [self documentVisibleRect].origin.y;
	
	// Determine how large an image we'll need to hold all cells, with their
	//	*unclipped* rectangles:
	for( PXListViewCell* currCell in _extendedCells )
	{
		NSUInteger		currRow = [currCell row];
		if( [dragRows containsIndex: currRow] )
		{
			NSRect		rowRect = [self rectOfRow: currRow];
			if( rowRect.origin.x < minX )
				minX = rowRect.origin.x;
			if( rowRect.origin.y < minY )
				minY = rowRect.origin.y;
			if( NSMaxX(rowRect) > maxX )
				maxX = NSMaxX(rowRect);
			if( NSMaxY(rowRect) > maxY )
				maxY = NSMaxY(rowRect);
		}
	}
	
	// Now draw all cells into the image at the proper relative position:
	NSSize		imageSize = NSMakeSize( maxX -minX, maxY -minY);
	NSImage*	dragImage = [[[NSImage alloc] initWithSize: imageSize] autorelease];
	
	[dragImage lockFocus];
    
    for( PXListViewCell* currCell in _extendedCells )
    {
        NSUInteger		currRow = [currCell row];
        if( [dragRows containsIndex: currRow] )
        { 
            NSRect				rowRect = [self rectOfRow: currRow];
            NSBitmapImageRep*	bir = [currCell bitmapImageRepForCachingDisplayInRect: [currCell bounds]];
            [currCell cacheDisplayInRect: [currCell bounds] toBitmapImageRep: bir];
            NSPoint				thePos = NSMakePoint( rowRect.origin.x -minX, rowRect.origin.y -minY);
            thePos.y = imageSize.height -(thePos.y +rowRect.size.height);	// Document view is flipped, so flip the coordinates before drawing into image, or the list items will be reversed.
            [bir drawAtPoint: thePos];
        }
    }
    
	[dragImage unlockFocus];
	
	// Give caller the right offset so the image ends up right atop the actual views:
	if( dragImageOffset )
	{
		dragImageOffset->x = -(localMouse.x -minX);
		dragImageOffset->y = (localMouse.y -minY) -imageSize.height;
	}
	
	return dragImage;
}


-(void)	setShowsDropHighlight: (BOOL)inState
{
	[[self documentView] setDropHighlight: (inState ? PXListViewDropOn : PXListViewDropNowhere)];
}


-(NSUInteger)	indexOfRowAtPoint: (NSPoint)pos returningProposedDropHighlight: (PXListViewDropHighlight*)outDropHighlight
{
	*outDropHighlight = PXListViewDropOn;
	
	if( _numberOfRows > 0 )
	{
		NSUInteger	idx = 0;
		for( NSUInteger x = 0; x < _numberOfRows; x++ )
		{
			if( _cellYOffsets[x] > pos.y )
			{
				break;
			}
			
			idx = x;
		}
		
		
		CGFloat		cellHeight = 0,
        cellOffset = 0,
        nextCellOffset = 0;
		if( (idx +1) < _numberOfRows )
		{
			cellOffset = _cellYOffsets[idx];
			nextCellOffset = _cellYOffsets[idx+1];
			cellHeight = nextCellOffset -cellOffset;
		}
		else if( idx < _numberOfRows && _numberOfRows > 0 )	// drag is somewhere close to or beyond end of list.
		{
			PXListViewCell*	theCell = [self visibleCellForRow: idx];
			cellHeight = [theCell frame].size.height;
			cellOffset = [theCell frame].origin.y;
			nextCellOffset = cellOffset +cellHeight;
		}
		else if( idx >= _numberOfRows && _numberOfRows > 0 )	// drag is somewhere close to or beyond end of list.
		{
			cellHeight = 0;
			cellOffset = [[self documentView] frame].size.height;
			nextCellOffset = cellOffset;
			idx = NSUIntegerMax;
		}
        
		if( pos.y < (cellOffset +(cellHeight / 6.0)) )
		{
			*outDropHighlight = PXListViewDropAbove;
		}
		else if( pos.y > (nextCellOffset -(cellHeight / 6.0)) )
		{
			idx++;
			*outDropHighlight = PXListViewDropAbove;
		}
		
		if( idx > _numberOfRows )
			idx = NSUIntegerMax;
		
		return idx;
	}
	else
	{
		return NSUIntegerMax;
	}
}


-(PXListViewCell*)	cellForDropHighlight: (PXListViewDropHighlight*)dhl row: (NSUInteger*)idx
{
	PXListViewCell*		newCell = nil;
	if( (*idx) >= _numberOfRows && _numberOfRows > 0 )
	{
		*dhl = PXListViewDropBelow;
		*idx = _numberOfRows -1;
		newCell = [self visibleCellForRow: _numberOfRows -1];
	}
	else
	{
		newCell = ((*idx) >= _numberOfRows) ? nil : [self visibleCellForRow: *idx];
	}
	
	return newCell;
}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSDragOperation	theOperation = NSDragOperationNone;
	
	NSUInteger				oldDropRow = _dropRow;
	PXListViewDropHighlight	oldDropHighlight = _dropHighlight;
    
	if( [_delegate respondsToSelector: @selector(listView:validateDrop:proposedRow:proposedDropHighlight:)] )
	{
		NSPoint		dragMouse = [[self documentView] convertPoint: [sender draggingLocation] fromView: nil];
		_dropRow = [self indexOfRowAtPoint: dragMouse returningProposedDropHighlight: &_dropHighlight];
		
		theOperation = [_delegate listView: self validateDrop: sender proposedRow: _dropRow
                     proposedDropHighlight: _dropHighlight];
	}
	
	if( theOperation != NSDragOperationNone )
	{
		if( oldDropRow != _dropRow
           || oldDropHighlight != _dropHighlight )
		{
			PXListViewCell*	newCell = [self cellForDropHighlight: &_dropHighlight row: &_dropRow];
			PXListViewCell*	oldCell = [self cellForDropHighlight: &oldDropHighlight row: &oldDropRow];
			
			[oldCell setDropHighlight: PXListViewDropNowhere];
			[newCell setDropHighlight: _dropHighlight];
			PXListViewDropHighlight	dropHL = ((_dropRow == _numberOfRows) ? PXListViewDropAbove : PXListViewDropOn);
			[[self documentView] setDropHighlight: dropHL];
		}
	}
	
	return theOperation;
}


- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender /* if the destination responded to draggingEntered: but not to draggingUpdated: the return value from draggingEntered: is used */
{
	NSDragOperation	theOperation = NSDragOperationNone;
	
	NSUInteger				oldDropRow = _dropRow;
	PXListViewDropHighlight	oldDropHighlight = _dropHighlight;
    
	if( [_delegate respondsToSelector: @selector(listView:validateDrop:proposedRow:proposedDropHighlight:)] )
	{
		NSPoint		dragMouse = [[self documentView] convertPoint: [sender draggingLocation] fromView: nil];
		_dropRow = [self indexOfRowAtPoint: dragMouse returningProposedDropHighlight: &_dropHighlight];
		
		theOperation = [_delegate listView: self validateDrop: sender proposedRow: _dropRow
                     proposedDropHighlight: _dropHighlight];
	}
	
	if( theOperation != NSDragOperationNone )
	{
		if( oldDropRow != _dropRow
           || oldDropHighlight != _dropHighlight )
		{
			PXListViewCell*	newCell = [self cellForDropHighlight: &_dropHighlight row: &_dropRow];
			PXListViewCell*	oldCell = [self cellForDropHighlight: &oldDropHighlight row: &oldDropRow];
			
			[oldCell setDropHighlight: PXListViewDropNowhere];
			[newCell setDropHighlight: _dropHighlight];
			PXListViewDropHighlight	dropHL = ((_dropRow == _numberOfRows) ? PXListViewDropAbove : PXListViewDropOn);
			[[self documentView] setDropHighlight: dropHL];
		}
	}
	else
	{
		[self setShowsDropHighlight: NO];
	}
	
	return theOperation;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
#pragma unused(sender)
	PXListViewCell*	oldCell = _dropRow == NSUIntegerMax ? nil : [self visibleCellForRow: _dropRow];
	[oldCell setDropHighlight: PXListViewDropNowhere];
	
	[self setShowsDropHighlight: NO];
	
	_dropRow = 0;
	_dropHighlight = PXListViewDropNowhere;
}


- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	if( ![[self delegate] respondsToSelector: @selector(listView:acceptDrop:row:dropHighlight:)] )
		return NO;
	
	BOOL	accepted = [[self delegate] listView: self acceptDrop: sender row: _dropRow dropHighlight: _dropHighlight];
	
	_dropRow = 0;
	_dropHighlight = PXListViewDropNowhere;
	
	return accepted;
}


- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
#pragma unused(sender)	
}


- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
#pragma unused(sender)
	PXListViewCell*	oldCell = _dropRow == NSUIntegerMax ? nil : [self visibleCellForRow: _dropRow];
	[oldCell setDropHighlight: PXListViewDropNowhere];
	
	[self setShowsDropHighlight: NO];
}


- (BOOL)wantsPeriodicDraggingUpdates
{
	return YES;
}


-(void)setDropRow:(NSUInteger)row dropHighlight: (PXListViewDropHighlight)dropHighlight
{
	_dropRow = row;
	_dropHighlight = dropHighlight;
	
	[self setNeedsDisplay: YES];
}

@end
