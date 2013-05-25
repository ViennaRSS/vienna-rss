//
//  PXListView.m
//  PXListView
//
//  Created by Alex Rozanski on 29/05/2010.
//  Copyright 2010 Alex Rozanski. http://perspx.com. All rights reserved.
//

#import "PXListView.h"
#import "PXListView+Private.h"

#import "PXListViewCell.h"
#import "PXListViewCell+Private.h"
#import "PXListView+UserInteraction.h"

NSString * const PXListViewSelectionDidChange = @"PXListViewSelectionDidChange";


@implementation PXListView

@synthesize cellSpacing = _cellSpacing;
@synthesize allowsMultipleSelection = _allowsMultipleSelection;
@synthesize allowsEmptySelection = _allowsEmptySelection;
@synthesize verticalMotionCanBeginDrag = _verticalMotionCanBeginDrag;
@synthesize usesLiveResize = _usesLiveResize;

#pragma mark -
#pragma mark Init/Dealloc

- (id)initWithFrame:(NSRect)theFrame
{
	if((self = [super initWithFrame:theFrame]))
	{
		_reusableCells = [[NSMutableArray alloc] init];
		_visibleCells = [[NSMutableArray alloc] init];
		_selectedRows = [[NSMutableIndexSet alloc] init];
		_allowsEmptySelection = YES;
        _usesLiveResize = YES;
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	if((self = [super initWithCoder:decoder]))
	{
		_reusableCells = [[NSMutableArray alloc] init];
		_visibleCells = [[NSMutableArray alloc] init];
		_selectedRows = [[NSMutableIndexSet alloc] init];
		_allowsEmptySelection = YES;
        _usesLiveResize = YES;
	}
	
	return self;
}

- (void)awakeFromNib
{
	//Subscribe to scrolling notification:
	NSClipView *contentView = [self contentView];
	[contentView setPostsBoundsChangedNotifications: YES];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contentViewBoundsDidChange:)
												 name:NSViewBoundsDidChangeNotification
											   object:contentView];
	
	//Tag ourselves onto the document view:
	[[self documentView] setListView: self];
}

- (void)dealloc
{
	[self setDelegate:nil]; // otherwise delegate is left observing notifications from deallocated PXListView
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_reusableCells release], _reusableCells = nil;
	[_visibleCells release], _visibleCells = nil;
	[_selectedRows release], _selectedRows = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Data Handling

- (id<PXListViewDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<PXListViewDelegate>)delegate
{
    [[NSNotificationCenter defaultCenter] removeObserver:_delegate
                                                    name:PXListViewSelectionDidChange
                                                  object:self];
     
    _delegate = delegate;
    
    if([_delegate respondsToSelector:@selector(listViewSelectionDidChange:)]) {
        [[NSNotificationCenter defaultCenter] addObserver:_delegate
                                                 selector:@selector(listViewSelectionDidChange:)
                                                     name:PXListViewSelectionDidChange
                                                   object:self];
    }
}

-(void)reloadRowAtIndex:(NSInteger)inIndex;
{
    [self cacheCellLayout];
    [self layoutCells];
    //[self layoutCellsForResizeEvent];
}

- (void)reloadData
{
	id <PXListViewDelegate> delegate = [self delegate];
	
	// Move all visible cells to the reusable cells array
	NSUInteger numCells = [_visibleCells count];
	for (NSUInteger i = 0; i < numCells; i++)
	{
		PXListViewCell *cell = [_visibleCells objectAtIndex:i];
		[_reusableCells addObject:cell];
		[cell setHidden:YES];
	}
	
	[_visibleCells removeAllObjects];
	free(_cellYOffsets);
	
	[_selectedRows removeAllIndexes];
    _lastSelectedRow = -1;
	
	if([delegate conformsToProtocol:@protocol(PXListViewDelegate)])
	{
		_numberOfRows = [delegate numberOfRowsInListView:self];
		[self cacheCellLayout];
		
		NSRange visibleRange = [self visibleRange];
		_currentRange = visibleRange;
		[self addCellsFromVisibleRange];
		
		[self layoutCells];
	}
}

- (NSUInteger)numberOfRows
{
	return _numberOfRows;
}

#pragma mark -
#pragma mark Cell Handling

-(void)enqueueCell:(PXListViewCell*)cell
{
	if (cell != nil)
	{
		[_reusableCells addObject:cell];
		[_visibleCells removeObject:cell];
		[cell setHidden:YES];
	}
}

- (PXListViewCell*)dequeueCellWithReusableIdentifier: (NSString*)identifier
{
	if([_reusableCells count] == 0)
	{
		return nil;
	}
	
	//Search backwards looking for a match since removing from end of array is generally quicker
	for(NSUInteger i = [_reusableCells count]; i>0;i--)
	{
		PXListViewCell *cell = [_reusableCells objectAtIndex:(i-1)];
		
		if([[cell reusableIdentifier] isEqualToString:identifier])
		{
			//Make sure it doesn't get dealloc'd early:
			[[cell retain] autorelease];            
			[_reusableCells removeObjectAtIndex:(i-1)];
			[cell prepareForReuse];
			
			return cell;
		}
	}
	
	return nil;
}

- (NSArray*)visibleCells
{
    return [[_visibleCells copy] autorelease];
}

- (NSRange)visibleRange
{
	NSRect visibleRect = [[self contentView] documentVisibleRect];
	NSUInteger startRow = NSUIntegerMax;
	NSUInteger endRow = NSUIntegerMax;
	
	BOOL inRange = NO;
	for(NSUInteger i = 0; i < _numberOfRows; i++)
	{
		if(NSIntersectsRect([self rectOfRow:i], visibleRect))
		{
			if(startRow == NSUIntegerMax)
			{
				startRow = i;
				inRange = YES;
			}
		}
		else
		{
			if(inRange)
			{
				endRow = i;
				break;
			}
		}
	}
	
	if(endRow == NSUIntegerMax)
	{
		endRow = _numberOfRows; 
	}
	
	return NSMakeRange(startRow, endRow-startRow);
}

- (PXListViewCell*)visibleCellForRow:(NSUInteger)row
{
	PXListViewCell *outCell = nil;
	
	for(PXListViewCell *cell in _visibleCells)
	{
		if([cell row] == row)
		{
			outCell = cell;
			break;
		}
	}
	
	return outCell;
}

-(PXListViewCell *)cellForRowAtIndex:(NSUInteger)inIndex
{
    return [self visibleCellForRow:inIndex];
}

- (NSArray*)visibleCellsForRowIndexes:(NSIndexSet*)rows
{
	NSMutableArray *theCells = [NSMutableArray array];
	
	for(PXListViewCell *cell in _visibleCells)
	{
		if([rows containsIndex:[cell row]])
		{
			[theCells addObject:cell];
		}
	}
	
	return theCells;
}

- (void)addCellsFromVisibleRange
{
	id<PXListViewDelegate>	delegate = [self delegate];
	
	if([delegate conformsToProtocol: @protocol(PXListViewDelegate)])
	{
		NSRange visibleRange = [self visibleRange];
		
		for(NSUInteger i = visibleRange.location; i < NSMaxRange(visibleRange); i++)
		{
			id cell = nil;
            cell = [delegate listView: self cellForRow: i];
			[_visibleCells addObject:cell];
			
			[self layoutCell:cell atRow:i];
		}
	}
}

- (void)updateCells
{	
	NSRange visibleRange = [self visibleRange];
	NSRange intersectionRange = NSIntersectionRange(visibleRange, _currentRange);
	
	//Have the cells we need to display actually changed?
	if((visibleRange.location == _currentRange.location) && (NSMaxRange(visibleRange) == NSMaxRange(_currentRange))) {
		return;
	}
	
	if((intersectionRange.location == 0) && (intersectionRange.length == 0))
	{
		// We'll have to rebuild all the cells:
		[_reusableCells addObjectsFromArray:_visibleCells];
		[_visibleCells removeAllObjects];
		[[self documentView] setSubviews:[NSArray array]];
		[self addCellsFromVisibleRange];
	}
	else
	{
		if(visibleRange.location < _currentRange.location) // Add top. 
		{
			for( NSUInteger i = _currentRange.location; i > visibleRange.location; i-- )
			{
				NSUInteger newRow = i -1;
				PXListViewCell *cell = [[self delegate] listView:self cellForRow:newRow];
                
				[_visibleCells insertObject: cell atIndex:0];
				[self layoutCell:cell atRow:newRow];
			}
		}
        
		if(visibleRange.location > _currentRange.location) // Remove top.
		{
			for(NSUInteger i = visibleRange.location; i > _currentRange.location; i--)
			{
				[self enqueueCell:[_visibleCells objectAtIndex:0]];
			}
		}
		
		if(NSMaxRange(visibleRange) > NSMaxRange(_currentRange)) // Add bottom.
		{
			for(NSUInteger i = NSMaxRange(_currentRange); i < NSMaxRange(visibleRange); i++)
			{
				NSInteger newRow = i;
				PXListViewCell *cell = [[self delegate] listView:self cellForRow: newRow];
                
				[_visibleCells addObject:cell];
				[self layoutCell:cell atRow:newRow];
			}
		}
		
        if(NSMaxRange(visibleRange) < NSMaxRange(_currentRange)) // Remove bottom.
		{
			for(NSUInteger i = NSMaxRange(_currentRange); i > NSMaxRange(visibleRange); i--)
			{
				[self enqueueCell:[_visibleCells lastObject]];
			}
		}
	}
	
	_currentRange = visibleRange;
}

#pragma mark -
#pragma mark Selection

- (void)selectAll:(id)sender
{
	if(_allowsMultipleSelection) {
		[self setSelectedRows:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _numberOfRows)]];
	}
}

- (void)deselectAll:(id)sender
{
	[self setSelectedRows:[NSIndexSet indexSet]];
}

- (void)setSelectedRow:(NSUInteger)row
{
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection: NO];
}


- (NSUInteger)selectedRow
{
	if( [_selectedRows count] == 1 ) {
		return [_selectedRows firstIndex];
	}
	else {
		//This gives -1 for 0 selected items (backwards compatible) *and* for multiple selections.
		return NSUIntegerMax;
	}
}


- (void)setSelectedRows:(NSIndexSet *)rowIndexes
{
	[self selectRowIndexes:rowIndexes byExtendingSelection:NO];
}


- (NSIndexSet*)selectedRows
{
	return _selectedRows;	// +++ Copy/autorelease?
}


- (void)selectRowIndexes:(NSIndexSet*)rows byExtendingSelection:(BOOL)shouldExtend
{
    NSMutableIndexSet *updatedCellIndexes = [NSMutableIndexSet indexSet];
    
	if(!shouldExtend) {
        [updatedCellIndexes addIndexes:_selectedRows];
		[_selectedRows removeAllIndexes];
	}
	
	[_selectedRows addIndexes:rows];
    [updatedCellIndexes addIndexes:rows]; 
    
	NSArray *updatedCells = [self visibleCellsForRowIndexes:updatedCellIndexes];
	for(PXListViewCell *cell in updatedCells)
	{
		[cell setNeedsDisplay:YES];
	}
    
    [self postSelectionDidChangeNotification];
}


- (void)deselectRowIndexes:(NSIndexSet*)rows
{
	NSArray *oldSelectedCells = [self visibleCellsForRowIndexes:rows];
	[_selectedRows removeIndexes:rows];
	
	for(PXListViewCell *oldSelectedCell in oldSelectedCells)
	{
		[oldSelectedCell setNeedsDisplay:YES];
	}
    
    [self postSelectionDidChangeNotification];
}


- (void)deselectRows
{
	[self deselectRowIndexes:_selectedRows];
}

- (void)postSelectionDidChangeNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:PXListViewSelectionDidChange object:self];
}

#pragma mark -
#pragma mark Layout

- (NSRect)contentViewRect
{
	NSRect frame = [self frame];
	NSSize frameSize = NSMakeSize(NSWidth(frame), NSHeight(frame));
	BOOL hasVertScroller = NSHeight(frame) < _totalHeight;
	NSSize availableSize = [[self class] contentSizeForFrameSize:frameSize
										   hasHorizontalScroller:NO
											 hasVerticalScroller:hasVertScroller
													  borderType:[self borderType]];
	
	return NSMakeRect(0.0f, 0.0f, availableSize.width, availableSize.height);
}

- (NSRect)rectOfRow:(NSUInteger)row
{
	id <PXListViewDelegate> delegate = [self delegate];
	
	if([delegate conformsToProtocol:@protocol(PXListViewDelegate)])
	{
        CGFloat cellWidth = NSWidth([self contentViewRect]);
        if([self inLiveResize]&&![self usesLiveResize]) {
            cellWidth = _widthPriorToResize;
        }

		CGFloat rowHeight = [delegate listView:self heightOfRow:row];
		
		return NSMakeRect(0.0f, _cellYOffsets[row], cellWidth, rowHeight);
	}
	
	return NSZeroRect;
}

- (void)cacheCellLayout
{
	id <PXListViewDelegate> delegate = [self delegate];
	
	if([delegate conformsToProtocol:@protocol(PXListViewDelegate)])
	{
		CGFloat totalHeight = 0;
		
		//Allocate the offset caching array
		_cellYOffsets = (CGFloat*)malloc(sizeof(CGFloat)*_numberOfRows);
		
		for( NSUInteger i = 0; i < _numberOfRows; i++ )
		{
			_cellYOffsets[i] = totalHeight;
			CGFloat cellHeight = [delegate listView:self heightOfRow:i];
			
			totalHeight += cellHeight +[self cellSpacing];
		}
		
		_totalHeight = totalHeight;
		
		NSRect bounds = [self bounds];
		CGFloat documentHeight = _totalHeight>NSHeight(bounds)?_totalHeight: (NSHeight(bounds) -2);
		
		[[self documentView] setFrame:NSMakeRect(0.0f, 0.0f, NSWidth([self contentViewRect]), documentHeight)];
	}
}

- (void)layoutCells
{	
	//Set the frames of the cells
	for(id cell in _visibleCells)
	{
		NSInteger row = [cell row];
		[cell setFrame:[self rectOfRow:row]];
        [cell layoutSubviews];
	}
	
	NSRect bounds = [self bounds];
	CGFloat documentHeight = _totalHeight>NSHeight(bounds)?_totalHeight:(NSHeight(bounds) -2);
	
	//Set the new height of the document view
	[[self documentView] setFrame:NSMakeRect(0.0f, 0.0f, NSWidth([self contentViewRect]), documentHeight)];
}

- (void)layoutCell:(PXListViewCell*)cell atRow:(NSUInteger)row
{
	[[self documentView] addSubview:cell];
    [cell setFrame:[self rectOfRow:row]];
    
	[cell setListView:self];
	[cell setRow:row];
	[cell setHidden:NO];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
	//If our frame is autosized (not dragged using the sizing handle), we can handle this
	//message to resize the visible cells
	[super resizeWithOldSuperviewSize:oldBoundsSize];
	
	if(![self inLiveResize]||[self usesLiveResize])
	{
		[_visibleCells removeAllObjects];
		[[self documentView] setSubviews:[NSArray array]];
		
		[self cacheCellLayout];
		[self addCellsFromVisibleRange];
		
		_currentRange = [self visibleRange];
	}
    else if([self inLiveResize]&&![self usesLiveResize]) {
        [self updateCells];
    }
}

#pragma mark -
#pragma mark Scrolling

- (void)contentViewBoundsDidChange:(NSNotification *)notification
{
	[self updateCells];
}

- (void)scrollToRow:(NSUInteger)row
{
    if(row >= _numberOfRows) {
        return;
    }
    
    // Use minimal scroll necessary, so we don't force the selection to upper left of window:
	NSRect visibleRect = [self documentVisibleRect];
	NSRect rowRect = [self rectOfRow:row];
	
	NSPoint newScrollPoint = rowRect.origin;
    
    //Have we over-scrolled?
	if(NSMaxY(rowRect) > NSMaxY(visibleRect)) {
		newScrollPoint.y = _totalHeight - NSHeight(visibleRect);
    }
	
	[[self contentView] scrollToPoint:newScrollPoint];
	[self reflectScrolledClipView:[self contentView]];
}

- (void)scrollRowToVisible:(NSUInteger)row
{
	if(row >= _numberOfRows) {
		return;
    }
	
	// Use minimal scroll necessary, so we don't force the selection to upper left of window:
	NSRect visibleRect = [self documentVisibleRect];
	NSRect rowRect = [self rectOfRow:row];
    
	if(NSContainsRect(visibleRect, rowRect)) {	// Already visible, no need to scroll.
		return;
    }
	
	NSPoint newScrollPoint = rowRect.origin;
    
    //Have we over-scrolled?
	if(NSMaxY(rowRect) > NSMaxY(visibleRect)) {
		newScrollPoint.y = _totalHeight - NSHeight(visibleRect);
    }
	
	[[self contentView] scrollToPoint:newScrollPoint];
	[self reflectScrolledClipView:[self contentView]];
}


#pragma mark -
#pragma mark Sizing

- (void)viewWillStartLiveResize
{
    _widthPriorToResize = NSWidth([self contentViewRect]);
    if([self usesLiveResize])
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowSizing:) name:NSSplitViewDidResizeSubviewsNotification object:self.superview];
}

-(void)layoutCellsForResizeEvent 
{
    //Change the layout of the cells
    [_visibleCells removeAllObjects];
    [[self documentView] setSubviews:[NSArray array]];
    
    [self cacheCellLayout];
    [self addCellsFromVisibleRange];
    
    if ([_delegate conformsToProtocol:@protocol(PXListViewDelegate)])
    {
        CGFloat totalHeight = 0;
        
        for (NSUInteger i = 0; i < _numberOfRows; i++)
        {
            CGFloat cellHeight = [_delegate listView:self heightOfRow:i];
            totalHeight += cellHeight +[self cellSpacing];
        }
        
        _totalHeight = totalHeight;
        
        NSRect bounds = [self bounds];
        CGFloat documentHeight = _totalHeight > NSHeight(bounds) ? _totalHeight:(NSHeight(bounds) - 2);
        
        [[self documentView] setFrame:NSMakeRect(0.0f, 0.0f, NSWidth([self contentViewRect]), documentHeight)];
    }
    
    _currentRange = [self visibleRange];
}

-(void)viewDidEndLiveResize
{
    [super viewDidEndLiveResize];
    
    //If we use live resize the view will already be up to date
    if (![self usesLiveResize])
    {
        [self layoutCellsForResizeEvent];
    }
    if ([self usesLiveResize])
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSSplitViewDidResizeSubviewsNotification object:self.superview];
}

-(void)windowSizing:(NSNotification *)inNot
{
    [self layoutCellsForResizeEvent];
}

#pragma mark -
#pragma mark Accessibility

-(NSArray*)	accessibilityAttributeNames
{
	NSMutableArray*	attribs = [[[super accessibilityAttributeNames] mutableCopy] autorelease];
	
	[attribs addObject: NSAccessibilityRoleAttribute];
	[attribs addObject: NSAccessibilityVisibleChildrenAttribute];
	[attribs addObject: NSAccessibilitySelectedChildrenAttribute];
	[attribs addObject: NSAccessibilityOrientationAttribute];
	[attribs addObject: NSAccessibilityEnabledAttribute];
	
	return attribs;
}

- (BOOL)accessibilityIsAttributeSettable:(NSString *)attribute
{
	if( [attribute isEqualToString: NSAccessibilityRoleAttribute]
		|| [attribute isEqualToString: NSAccessibilityVisibleChildrenAttribute]
		|| [attribute isEqualToString: NSAccessibilitySelectedChildrenAttribute]
		|| [attribute isEqualToString: NSAccessibilityContentsAttribute]
		|| [attribute isEqualToString: NSAccessibilityOrientationAttribute]
		|| [attribute isEqualToString: NSAccessibilityChildrenAttribute]
		|| [attribute isEqualToString: NSAccessibilityEnabledAttribute] )
	{
		return NO;
	}
	else
		return [super accessibilityIsAttributeSettable: attribute];
}


-(id)	accessibilityAttributeValue: (NSString *)attribute
{
	if( [attribute isEqualToString: NSAccessibilityRoleAttribute] )
	{
		return NSAccessibilityListRole;
	}
	else if( [attribute isEqualToString: NSAccessibilityVisibleChildrenAttribute]
				|| [attribute isEqualToString: NSAccessibilityContentsAttribute]
				|| [attribute isEqualToString: NSAccessibilityChildrenAttribute] )
	{
		return _visibleCells;
	}
	else if( [attribute isEqualToString: NSAccessibilitySelectedChildrenAttribute] )
	{
		return [self visibleCellsForRowIndexes: _selectedRows];
	}
	else if( [attribute isEqualToString: NSAccessibilityOrientationAttribute] )
	{
		return NSAccessibilityVerticalOrientationValue;
	}
	else if( [attribute isEqualToString: NSAccessibilityEnabledAttribute] )
	{
		return [NSNumber numberWithBool: YES];
	}
	else
		return [super accessibilityAttributeValue: attribute];
}


-(BOOL)	accessibilityIsIgnored
{
	return NO;
}

@end
