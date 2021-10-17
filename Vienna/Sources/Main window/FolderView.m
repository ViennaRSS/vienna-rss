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
#import "TreeNode.h"
#import "AppController.h"
#import "FoldersFilterable.h"

@implementation FolderView {
    NSPredicate*            _filterPredicate;
    FoldersFilterableDataSourceImpl* _filterDataSource;
    NSDictionary*           _prefilterState;
    id _directDataSource;
}

@dynamic delegate;

/* becomeFirstResponder
 * Let the delegate prepare for the outline view to become first responder.
 */
-(BOOL)becomeFirstResponder
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
    if ([((NSTextField *)responder).identifier isEqualToString:@"TextField"] &&
        event.type == NSEventTypeRightMouseDown) {
        return NO;
    }

    // This prevents the unread count from responding to mouse clicks; it will
    // behave like a view instead of a button. The clicks will fall through to
    // enclosing outline-view cell instead.
    if ([((NSButton *)responder).identifier isEqualToString:@"CountButton"]) {
        return NO;
    }

    return [super validateProposedFirstResponder:responder forEvent:event];
}

/* draggingSession:sourceOperationMaskForDraggingContext
 * Let the control know the expected behaviour for local and external drags.
 */
-(NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    switch(context) {
        case NSDraggingContextWithinApplication:
            return NSDragOperationMove|NSDragOperationGeneric;
        default:
            return NSDragOperationCopy;
    }
}

/* keyDown
 * Here is where we handle special keys when the outline view
 * has the focus so we can do custom things.
 */
-(void)keyDown:(NSEvent *)theEvent
{
	if (theEvent.characters.length == 1)
	{
		unichar keyChar = [theEvent.characters characterAtIndex:0];
		if ([APPCONTROLLER handleKeyDown:keyChar withFlags:theEvent.modifierFlags])
			return;
	}
	[super keyDown:theEvent];
}

/* setDataSource
 * Called when the data source changes.
 */
-(void)setDataSource:(id)aSource
{
    _directDataSource = aSource;
    _filterDataSource = [[FoldersFilterableDataSourceImpl alloc] initWithDataSource:aSource];
       super.dataSource = aSource;
}

/* reloadData
 * Called when the user reloads the view data.
 */
- (void)reloadData
{
    if (_filterDataSource && _filterPredicate) {
        [_filterDataSource reloadData:self];
    } else {
        [super reloadData];
    }
}

- (NSPredicate*)filterPredicate {
    return _filterPredicate;
}

- (void)setFilterPredicate:(NSPredicate *)filterPredicate {
    if (_filterPredicate == filterPredicate)
        return;

    if (_filterPredicate == nil) {
        _prefilterState = self.vna_state;
    }

    _filterPredicate = filterPredicate;
    if (_filterDataSource && _filterPredicate){
        [_filterDataSource setFilterPredicate:_filterPredicate outlineView:self];
        super.dataSource = _filterDataSource;
    }
    else{
        super.dataSource = _directDataSource;
    }

    [super reloadData];

    if (_filterPredicate) {
        [self expandItem:nil expandChildren:YES];
        self.vna_selectionState = _prefilterState[@"Selection"];
    }
    else if (_prefilterState) {
        self.vna_state = _prefilterState;
        _prefilterState = nil;
    }
}

/* copy
 * Handle the Copy action when the outline view has focus.
 */
-(IBAction)copy:(id)sender
{
	if (self.selectedRow >= 0)
	{
		NSMutableArray * array = [NSMutableArray arrayWithCapacity:self.numberOfSelectedRows];
		NSIndexSet * selectedRowIndexes = self.selectedRowIndexes;
		NSUInteger  item = selectedRowIndexes.firstIndex;
		
		while (item != NSNotFound)
		{
			id node = [self itemAtRow:item];
			[array addObject:node];
			item = [selectedRowIndexes indexGreaterThanIndex:item];
		}
        [self.delegate copyTableSelection:array toPasteboard:NSPasteboard.generalPasteboard];
	}
}

/* delete
 * Handle the Delete action when the outline view has focus.
 */
-(IBAction)delete:(id)sender
{
	[APPCONTROLLER deleteFolder:self];
}

/* validateMenuItem
 * This is our override where we handle item validation for the
 * commands that we own.
 */
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(copy:))
	{
		return (self.selectedRow >= 0);
	}
	if (menuItem.action == @selector(delete:))
	{
        return [self.delegate canDeleteFolderAtRow:self.selectedRow];
	}
	if (menuItem.action == @selector(selectAll:))
	{
		return YES;
	}
	return NO;
}

@end
