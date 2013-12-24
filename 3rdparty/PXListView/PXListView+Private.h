//
//  PXListView+Private.h
//  PXListView
//
//  Created by Alex Rozanski on 01/06/2010.
//  Copyright 2010 Alex Rozanski. http://perspx.com. All rights reserved.
//

// This is a renamed copy of UKIsDragStart from <http://github.com/uliwitness/UliKit>:
// Possible return values from UKIsDragStart:
enum
{
	PXIsDragStartMouseReleased = 0,
	PXIsDragStartTimedOut,
	PXIsDragStartMouseMovedHorizontally,
	PXIsDragStartMouseMovedVertically
};
typedef NSInteger PXIsDragStartResult;


@interface PXListView ()

- (NSRect)contentViewRect;

- (void)cacheCellLayout;
- (void)layoutCells;
- (void)layoutCell:(PXListViewCell*)cell atRow:(NSUInteger)row;

- (void)addCellsFromVisibleRange;
- (void)addCellsFromExtendedRange;
- (PXListViewCell*)visibleCellForRow:(NSUInteger)row;
- (NSArray*)visibleCellsForRowIndexes:(NSIndexSet*)rows;

- (NSUInteger)numberOfRows;
- (void)deselectRowIndexes:(NSIndexSet*)rows;
- (void)postSelectionDidChangeNotification;

- (void)updateCells;
- (void)enqueueCell:(PXListViewCell*)cell;

- (void)contentViewBoundsDidChange:(NSNotification*)notification;
-(void)layoutCellsForResizeEvent;

@end
