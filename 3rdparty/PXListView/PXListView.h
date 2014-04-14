//
//  PXListView.h
//  PXListView
//
//  Created by Alex Rozanski on 29/05/2010.
//  Copyright 2010 Alex Rozanski. http://perspx.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PXListViewDelegate.h"
#import "PXListViewCell.h"


#if DEBUG
#define PXLog(...)	NSLog(__VA_ARGS__)
#endif


@interface PXListView : NSScrollView
{
	id <PXListViewDelegate> _delegate;
	
	NSMutableArray *_reusableCells;
	NSMutableArray *_cellsInViewHierarchy;
	NSRange _currentRange;
	
	NSUInteger _numberOfRows;
	NSMutableIndexSet *_selectedRows;
	
	NSRange _visibleRange;
	CGFloat _totalHeight;
	CGFloat *_cellYOffsets;
	
	CGFloat _cellSpacing;

	BOOL _allowsEmptySelection;
	BOOL _allowsMultipleSelection;
    NSInteger _lastSelectedRow;
    
	BOOL _verticalMotionCanBeginDrag;
    
    BOOL _usesLiveResize;
    CGFloat _widthPriorToResize;
	
	NSUInteger _dropRow;
	PXListViewDropHighlight	_dropHighlight;
}

@property (nonatomic, assign) IBOutlet id <PXListViewDelegate> delegate;

@property (nonatomic, retain) NSIndexSet *selectedRows;
@property (nonatomic, assign) NSUInteger selectedRow;

@property (nonatomic, assign) BOOL allowsEmptySelection;
@property (nonatomic, assign) BOOL allowsMultipleSelection;
@property (nonatomic, assign) BOOL verticalMotionCanBeginDrag;

@property (nonatomic, assign) CGFloat cellSpacing;
@property (nonatomic, assign) BOOL usesLiveResize;

- (void)reloadData;
-(void)reloadRowAtIndex:(NSInteger)inIndex;

- (PXListViewCell*)dequeueCellWithReusableIdentifier:(NSString*)identifier;

- (NSArray*)visibleCells;
-(PXListViewCell *)cellForRowAtIndex:(NSUInteger)inIndex;

- (NSRange)visibleRange;
- (NSRect)rectOfRow:(NSUInteger)row;
- (void)deselectRows;
- (void)selectRowIndexes:(NSIndexSet*)rows byExtendingSelection:(BOOL)doExtend;

- (void)scrollToRow:(NSUInteger)row;
- (void)scrollRowToVisible:(NSUInteger)row;

@end
