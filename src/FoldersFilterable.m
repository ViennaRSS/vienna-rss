//
//  FoldersFilterable.m
//  Vienna
//
//  Created by wolf on 1/10/16.
//  Copyright © 2016 uk.co.opencommunity. All rights reserved.
//

#import "FoldersFilterable.h"

@implementation FoldersFilterableDataSource

- (instancetype)initWithDataSource:(id <NSOutlineViewDataSource>)dataSource {
    self = [super init];
    if (!self)
        return nil;

    _dataSource = dataSource;
    return self;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    return [_dataSource outlineView:outlineView numberOfChildrenOfItem:item];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    return [_dataSource outlineView:outlineView child:index ofItem:item];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [_dataSource outlineView:outlineView isItemExpandable:item];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    return [_dataSource outlineView:outlineView objectValueForTableColumn:tableColumn byItem:item];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    [_dataSource outlineView:outlineView setObjectValue:object forTableColumn:tableColumn byItem:item];
}

- (id)outlineView:(NSOutlineView *)outlineView itemForPersistentObject:(id)object {
    return [_dataSource outlineView:outlineView itemForPersistentObject:object];
}

- (id)outlineView:(NSOutlineView *)outlineView persistentObjectForItem:(id)item {
    return [_dataSource outlineView:outlineView persistentObjectForItem:item];
}

- (void)outlineView:(NSOutlineView *)outlineView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    [_dataSource outlineView:outlineView sortDescriptorsDidChange:oldDescriptors];
}

- (id <NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item {
    return [_dataSource outlineView:outlineView pasteboardWriterForItem:item];
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forItems:(NSArray *)draggedItems {
    [_dataSource outlineView:outlineView draggingSession:session willBeginAtPoint:screenPoint forItems:draggedItems];
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    [_dataSource outlineView:outlineView draggingSession:session endedAtPoint:screenPoint operation:operation];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
    return [_dataSource outlineView:outlineView writeItems:items toPasteboard:pasteboard];
}

- (void)outlineView:(NSOutlineView *)outlineView updateDraggingItemsForDrag:(id <NSDraggingInfo>)draggingInfo {
    [_dataSource outlineView:outlineView updateDraggingItemsForDrag:draggingInfo];
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
    return [_dataSource outlineView:outlineView validateDrop:info proposedItem:item proposedChildIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
    return [_dataSource outlineView:outlineView acceptDrop:info item:item childIndex:index];
}

- (NSArray *)outlineView:(NSOutlineView *)outlineView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedItems:(NSArray *)items {
    return [_dataSource outlineView:outlineView namesOfPromisedFilesDroppedAtDestination:dropDestination forDraggedItems:items];
}

@end

@implementation FoldersFilterableDataSourceImpl
{
    dispatch_queue_t _queue;
    dispatch_queue_t _queueMap;
    dispatch_group_t _loadGroup;
    NSPredicate*     _filterPredicate;
    NSMapTable*      _filtered;
    NSUInteger       _generation;
    id               _root;
}

- (instancetype)initWithDataSource:(id<NSOutlineViewDataSource>)dataSource {
    _queue     = dispatch_queue_create("com.modclassic.MCFilterableDataSource",     DISPATCH_QUEUE_CONCURRENT);
    _queueMap  = dispatch_queue_create("com.modclassic.MCFilterableDataSource.Map", DISPATCH_QUEUE_SERIAL);
    _loadGroup = dispatch_group_create();
    _root      = [NSNull null];
    return [super initWithDataSource:dataSource];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (_filterPredicate == nil)
        return [_dataSource outlineView:outlineView numberOfChildrenOfItem:item];

    if (item == nil) {
        item = _root;
    }

    dispatch_group_wait(_loadGroup, DISPATCH_TIME_FOREVER);

    NSArray* a = [_filtered objectForKey:item];
    if (a) {
        return a.count;
    }

    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (_filterPredicate == nil)
        return [_dataSource outlineView:outlineView child:index ofItem:item];

    if (item == nil) {
        item = _root;
    }

    dispatch_group_wait(_loadGroup, DISPATCH_TIME_FOREVER);

    NSArray* a = [_filtered objectForKey:item];
    if (a) {
        return a[index];
    }

    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if (_filterPredicate == nil)
        return [_dataSource outlineView:outlineView isItemExpandable:item];

    dispatch_group_wait(_loadGroup, DISPATCH_TIME_FOREVER);

    NSArray* a = [_filtered objectForKey:item];
    if (a) {
        return a.count > 0;
    }

    return NO;
}

- (void)loadDataForItem:(NSOutlineView*)outlineView
                   item:(id)item
                  table:(NSMapTable*)table
              container:(NSMutableArray*)array
             generation:(NSUInteger)generation
              predicate:(NSPredicate*)predicate
            parentGroup:(dispatch_group_t)parentGroup {
    dispatch_group_enter(parentGroup);
    dispatch_async(_queue, ^{
        if (generation != _generation) {
            dispatch_group_leave(parentGroup);
            return;
        }

        NSUInteger count = [_dataSource outlineView:outlineView numberOfChildrenOfItem:item];
        if (count == 0) {
            if (![predicate evaluateWithObject:item]) {
                dispatch_async(_queueMap, ^{
                    [array removeObject:item];
                    dispatch_group_leave(parentGroup);
                });
            }
            else {
                dispatch_group_leave(parentGroup);
            }

            return;
        }

        dispatch_group_t childGroup = dispatch_group_create();
        NSMutableArray*  childArray = [NSMutableArray array];
        BOOL             hasSpinned = NO;

        for (NSUInteger index = 0; index < count; ++index) {
            id   child      = [_dataSource outlineView:outlineView child:index ofItem:item];
            BOOL expandable = [_dataSource outlineView:outlineView isItemExpandable:child];

            if (expandable) {
                if (hasSpinned) {
                    dispatch_async(_queueMap, ^{
                        [childArray addObject:child];
                    });
                }
                else {
                    [childArray addObject:child];
                }

                hasSpinned = YES;
                [self loadDataForItem:outlineView
                                 item:child
                                table:table
                            container:childArray
                           generation:generation
                            predicate:predicate
                          parentGroup:childGroup];
            }
            else {
                if ([predicate evaluateWithObject:child]) {
                    if (hasSpinned) {
                        dispatch_async(_queueMap, ^{
                            [childArray addObject:child];
                        });
                    }
                    else {
                        [childArray addObject:child];
                    }
                }
            }
        }

        dispatch_group_notify(childGroup, _queueMap, ^{
            if ((childArray.count == 0) && (item != nil)) {
                if (![predicate evaluateWithObject:item]) {
                    [array removeObject:item];
                }
            }
            else
                [table setObject:childArray forKey:item? item: _root];

            dispatch_group_leave(parentGroup);
        });
    });
}

- (void)reloadData:(NSOutlineView*)outlineView {
    if (_filterPredicate == nil)
        return;

    _generation++;

    NSMapTable* filtered = [[NSMapTable alloc] initWithKeyOptions:NSMapTableStrongMemory
                                                     valueOptions:NSMapTableStrongMemory
                                                         capacity:0];

    dispatch_async(_queueMap, ^{
        _filtered = filtered;
    });

    [self loadDataForItem:outlineView
                     item:nil
                    table:filtered
                container:[NSMutableArray array]
               generation:_generation
                predicate:_filterPredicate
              parentGroup:_loadGroup];
}

- (void)setFilterPredicate:(NSPredicate *)filterPredicate outlineView:(NSOutlineView*)outlineView {
    _filterPredicate = filterPredicate;
    [self reloadData:outlineView];
}

@end


@implementation NSOutlineView (MCStateSave)

- (NSDictionary*)state {
    return @{
             @"Selection": self.selectionState,
             @"Expansion": self.expansionState,
             @"Scroll":    self.scrollState
             };
}

- (void)setState:(NSDictionary*)state {
    self.expansionState = state[@"Expansion"];
    self.selectionState = state[@"Selection"];
    self.scrollState    = state[@"Scroll"];
}

- (NSDictionary*)scrollState {
    NSClipView* clipView = (NSClipView*)[self superview];
    if (![clipView isKindOfClass:[NSClipView class]])
        return @{};

    NSScrollView* scrollView = (NSScrollView*)[clipView superview];
    if (![scrollView isKindOfClass:[NSScrollView class]])
        return @{};

    return @{
             @"VisibleRect": [NSValue valueWithRect:scrollView.documentVisibleRect]
             };
}

- (void)setScrollState:(NSDictionary*)state {
    NSValue* rectValue = state[@"VisibleRect"];
    if (!rectValue)
        return;

    [self scrollPoint:[rectValue rectValue].origin];
}

- (NSSet*)selectionState {
    NSMutableSet* selectedItems = [NSMutableSet set];
    NSInteger     numberOfRows  = self.numberOfRows;

    for (NSInteger row = 0; row < numberOfRows; row++) {
        if ([self isRowSelected:row]) {
            [selectedItems addObject:[self itemAtRow:row]];
        }
    }

    return [selectedItems copy];
}

- (void)setSelectionState:(NSSet*)newSelection {
    NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];

    for (id wanted in newSelection) {
        NSInteger index = [self rowForItem:wanted];
        if (index < 0)
            continue;

        [indexes addIndex:index];
    }

    [self selectRowIndexes:indexes byExtendingSelection:NO];
}

- (NSArray*)expansionState {
    NSMutableArray* expandedItems = [NSMutableArray array];
    NSInteger       numberOfRows  = self.numberOfRows;

    for (NSInteger row = 0; row < numberOfRows; row++) {
        id item = [self itemAtRow:row];

        if ([self isItemExpanded:item]) {
            [expandedItems addObject:item];
        }
    }

    return [expandedItems copy];
}

- (void)setExpansionState:(NSArray*)newExpansion {
    for (id wanted in newExpansion) {
        [self expandItem:wanted];
    }
}

@end
