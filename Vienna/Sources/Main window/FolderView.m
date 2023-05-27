//
//  FolderView.m
//  Vienna
//
//  Created by Steve on Tue Apr 06 2004.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FolderView.h"

#import <os/log.h>

#import "AppController.h"
#import "FeedListCellView.h"
#import "FoldersFilterable.h"
#import "TreeNode.h"

#define VNA_LOG os_log_create("--", "FolderView")

VNAFeedListRowHeight const VNAFeedListRowHeightTiny = 20.0;
VNAFeedListRowHeight const VNAFeedListRowHeightSmall = 24.0;
VNAFeedListRowHeight const VNAFeedListRowHeightMedium = 28.0;

static void *ObserverContext = &ObserverContext;

@interface FolderView ()

@property (weak, nonatomic) IBOutlet NSView *floatingResetButtonView;

@end

@implementation FolderView {
    NSPredicate *_filterPredicate;
    FoldersFilterableDataSourceImpl *_filterDataSource;
    NSDictionary *_prefilterState;
    id _directDataSource;
}

@dynamic delegate;

// MARK: Overrides

/* becomeFirstResponder
 * Let the delegate prepare for the outline view to become first responder.
 */
- (BOOL)becomeFirstResponder
{
    [self.delegate folderViewWillBecomeFirstResponder];
    return [super becomeFirstResponder];
}

- (BOOL)validateProposedFirstResponder:(NSResponder *)responder
                              forEvent:(NSEvent *)event
{
    // This prevents the text field in the outline-view cell to respond to right
    // clicks. A right click can enable the text-field editing, e.g. when a cell
    // is selected and the user right clicks on the cell to open the menu. Since
    // this is unwanted behavior, the right click should simply be ignored.
    if ([((id<NSUserInterfaceItemIdentification>)responder).identifier
            isEqualToString:VNAFeedListCellViewTextFieldIdentifier] &&
        event.type == NSEventTypeRightMouseDown) {
        return NO;
    }

    // This prevents the unread count from responding to mouse clicks; it will
    // behave like a view instead of a button. The clicks will fall through to
    // enclosing outline-view cell instead.
    if ([((id<NSUserInterfaceItemIdentification>)responder).identifier
            isEqualToString:VNAFeedListCellViewCountButtonIdentifier]) {
        return NO;
    }

    return [super validateProposedFirstResponder:responder forEvent:event];
}

- (void)keyDown:(NSEvent *)theEvent
{
    if (theEvent.characters.length == 1) {
        unichar keyChar = [theEvent.characters characterAtIndex:0];
        if ([APPCONTROLLER handleKeyDown:keyChar withFlags:theEvent.modifierFlags]) {
            return;
        }
    }
    [super keyDown:theEvent];
}

- (void)setDataSource:(id)aSource
{
    _directDataSource = aSource;
    _filterDataSource = [[FoldersFilterableDataSourceImpl alloc] initWithDataSource:aSource];
    super.dataSource = aSource;
}

- (void)reloadData
{
    if (_filterDataSource && _filterPredicate) {
        [_filterDataSource reloadData:self];
    } else {
        [super reloadData];
    }
}

// MARK: Accessors

- (NSPredicate *)filterPredicate
{
    return _filterPredicate;
}

- (void)setFilterPredicate:(NSPredicate *)filterPredicate
{
    if (_filterPredicate == filterPredicate) {
        return;
    }

    if (_filterPredicate == nil) {
        _prefilterState = self.vna_state;
    }

    _filterPredicate = filterPredicate;
    if (_filterDataSource && _filterPredicate) {
        [_filterDataSource setFilterPredicate:_filterPredicate outlineView:self];
        super.dataSource = _filterDataSource;
    } else {
        super.dataSource = _directDataSource;
    }

    [super reloadData];

    if (_filterPredicate) {
        [self expandItem:nil expandChildren:YES];
        self.vna_selectionState = _prefilterState[@"Selection"];
    } else if (_prefilterState) {
        self.vna_state = _prefilterState;
        _prefilterState = nil;
    }
}

// MARK: Methods

- (CGFloat)rowHeightForSize:(VNAFeedListSizeMode)sizeMode
{
    // As of macOS 11 no inter-cell spacing is applied. Since the row heights
    // (see below) were based on macOS 11+, they look taller on older systems
    // because of the additional inter-cell spacing.
    CGFloat cellSpacing = self.intercellSpacing.height;

    switch (sizeMode) {
    case VNAFeedListSizeModeTiny:
        return VNAFeedListRowHeightTiny - cellSpacing;
    case VNAFeedListSizeModeSmall:
        return VNAFeedListRowHeightSmall - cellSpacing;
    case VNAFeedListSizeModeMedium:
        return VNAFeedListRowHeightMedium - cellSpacing;
    default:
        os_log_fault(VNA_LOG, "Invalid cell view size");
        return -1.0;
    }
}

- (void)reloadDataWhilePreservingSelection
{
    NSRange rowsRange = NSMakeRange(0, self.numberOfRows);
    NSRange columnsRange = NSMakeRange(0, self.numberOfColumns);
    NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndexesInRange:rowsRange];
    NSIndexSet *columnIndexes = [NSIndexSet indexSetWithIndexesInRange:columnsRange];
    [self reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];
}

- (void)reloadDataForRowIndexWhilePreservingSelection:(NSInteger)rowIndex
{
    NSRange range = NSMakeRange(0, self.numberOfColumns);
    NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndex:rowIndex];
    NSIndexSet *columnIndexes = [NSIndexSet indexSetWithIndexesInRange:range];
    [self reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];
}

- (void)showResetButton:(BOOL)flag
{
    NSView *floatingView = self.floatingResetButtonView;
    NSScrollView *scrollView = self.enclosingScrollView;
    NSClipView *contentView = scrollView.contentView;
    if (flag) {
        [scrollView addFloatingSubview:floatingView
                               forAxis:NSEventGestureAxisVertical];
        CGFloat height = floatingView.frame.size.height;
        NSEdgeInsets insets = NSEdgeInsetsMake(height, 0.0, 0.0, 0.0);
        contentView.automaticallyAdjustsContentInsets = NO;
        contentView.contentInsets = insets;
        scrollView.scrollerInsets = insets;
        NSView *superView = floatingView.superview;
        NSArray<NSLayoutConstraint *> *constraints = @[
            [floatingView.topAnchor constraintEqualToAnchor:superView.topAnchor],
            [floatingView.leadingAnchor constraintEqualToAnchor:superView.leadingAnchor],
            [floatingView.trailingAnchor constraintEqualToAnchor:superView.trailingAnchor]
        ];
        [NSLayoutConstraint activateConstraints:constraints];
    } else {
        [floatingView removeFromSuperview];
        scrollView.scrollerInsets = NSEdgeInsetsZero;
        contentView.contentInsets = NSEdgeInsetsZero;
        contentView.automaticallyAdjustsContentInsets = YES;
    }
}

// MARK: Actions

- (IBAction)copy:(id)sender
{
    if (self.selectedRow >= 0) {
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.numberOfSelectedRows];
        NSIndexSet *selectedRowIndexes = self.selectedRowIndexes;
        NSUInteger item = selectedRowIndexes.firstIndex;

        while (item != NSNotFound) {
            id node = [self itemAtRow:item];
            [array addObject:node];
            item = [selectedRowIndexes indexGreaterThanIndex:item];
        }
        [self.delegate copyTableSelection:array toPasteboard:NSPasteboard.generalPasteboard];
    }
}

- (IBAction)delete:(id)sender
{
    [APPCONTROLLER deleteFolder:self];
}

// MARK: - NSDraggingSource

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    switch (context) {
    case NSDraggingContextWithinApplication:
        return NSDragOperationMove | NSDragOperationGeneric;
    default:
        return NSDragOperationCopy;
    }
}

// MARK: - NSMenuItemValidation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if (menuItem.action == @selector(copy:)) {
        return (self.selectedRow >= 0);
    }
    if (menuItem.action == @selector(delete:)) {
        return [self.delegate canDeleteFolderAtRow:self.selectedRow];
    }
    if (menuItem.action == @selector(selectAll:)) {
        return YES;
    }
    return NO;
}

@end
