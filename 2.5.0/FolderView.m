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
#import "ImageAndTextCell.h"
#import "TreeNode.h"

@interface NSObject (FoldersViewDelegate)
	-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(unsigned int)flags;
	-(BOOL)copyTableSelection:(NSArray *)items toPasteboard:(NSPasteboard *)pboard;
	-(BOOL)canDeleteFolderAtRow:(int)row;
	-(IBAction)deleteFolder:(id)sender;
	-(void)outlineViewWillBecomeFirstResponder;
@end

@implementation FolderView

/* init
 * Our initialisation.
 */
-(id)init
{
	if ((self = [super init]) != nil)
		useTooltips = NO;
	return self;
}

/* awakeFromNib
 * Our init.
 */
-(void)awakeFromNib
{
	NSString * blueGradientURL = [[NSBundle mainBundle] pathForResource:@"selBlue" ofType:@"tiff"];
	blueGradient = [[NSImage alloc] initWithContentsOfFile: blueGradientURL ];
	
	NSString * grayGradientURL = [[NSBundle mainBundle] pathForResource:@"selGray" ofType:@"tiff"];
	grayGradient = [[NSImage alloc] initWithContentsOfFile: grayGradientURL ];

	iRect = NSMakeRect(0,0,1,[blueGradient size].height-1);					
	[grayGradient setFlipped:YES];
	
	// Add the notifications for collapse and expand.
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(outlineViewItemDidExpand:) name:NSOutlineViewItemDidExpandNotification object:(id)self];
	[nc addObserver:self selector:@selector(outlineViewItemDidCollapse:) name:NSOutlineViewItemDidCollapseNotification object:(id)self];
}

/* becomeFirstResponder
 * Let the delegate prepare for the outline view to become first responder.
 */
-(BOOL)becomeFirstResponder
{
	[[self delegate] outlineViewWillBecomeFirstResponder];
	return [super becomeFirstResponder];
}

/* draggingSourceOperationMaskForLocal
 * Let the control know the expected behaviour for local and external drags.
 */
-(NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	if (isLocal)
		return NSDragOperationMove|NSDragOperationGeneric;
	return NSDragOperationCopy;
}

/* setEnableTooltips
 * Sets whether or not the outline view uses tooltips.
 */
-(void)setEnableTooltips:(BOOL)flag
{
	useTooltips = flag;
	[self buildTooltips];
}

/* keyDown
 * Here is where we handle special keys when the outline view
 * has the focus so we can do custom things.
 */
-(void)keyDown:(NSEvent *)theEvent
{
	if ([[theEvent characters] length] == 1)
	{
		unichar keyChar = [[theEvent characters] characterAtIndex:0];
		if ([[NSApp delegate] handleKeyDown:keyChar withFlags:[theEvent modifierFlags]])
			return;
	}
	[super keyDown:theEvent];
}

/* buildTooltips
 * Create the tooltip rectangles each time the control contents change.
 */
-(void)buildTooltips
{
	NSRange range;
	unsigned int index;

	[self removeAllToolTips];

	// If not using tooltips or the data source doesn't implement tooltipForItem,
	// then exit now.
	if (!useTooltips || ![_dataSource respondsToSelector:@selector(outlineView:tooltipForItem:)])
		return;

	range = [self rowsInRect:[self visibleRect]];
	for (index = range.location; index < NSMaxRange(range); index++)
	{
		NSString *tooltip;
		id item;

		item = [self itemAtRow:index];
		tooltip = [_dataSource outlineView:self tooltipForItem:item];
		if (tooltip)
			[self addToolTipRect:[self rectOfRow:index] owner:self userData:NULL];
	}
}

/* stringForToolTip [delegate]
 * Callback function from the view to request the actual tooltip string.
 */
-(NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)data
{
	int row;

	row = [self rowAtPoint:point];
	return [_dataSource outlineView:self tooltipForItem:[self itemAtRow:row]];
}

/* resetCursorRects
 * Called when the view scrolls. All the tooltip rectangles need to be recomputed.
 */
-(void)resetCursorRects
{
	[self buildTooltips];
}

/* setDataSource
 * Called when the data source changes. Since we rely on the data source to provide the
 * tooltip strings, we have to rebuild the tooltips using the new source.
 */
-(void)setDataSource:(id)aSource
{
	[super setDataSource:aSource];
	[self buildTooltips];
}

/* reloadData
 * Called when the user reloads the view data. Again, the tooltips need to be recomputed
 * using the new data.
 */
-(void)reloadData
{
	[super reloadData];
	[self buildTooltips];
}

/* noteNumberOfRowsChanged
 * Called by the user to tell the view to re-request data. Again, this could mean the
 * contents changing => tooltips change.
 */
-(void)noteNumberOfRowsChanged
{
	[super noteNumberOfRowsChanged];
	[self buildTooltips];
}

/* outlineViewItemDidExpand
 * Our own notification when the user expanded a node. Guess what we need to
 * do here?
 */
-(void)outlineViewItemDidExpand:(NSNotification *)notification
{
	// Rebuild the tooltips if required.
	if (useTooltips  == YES)
		[self buildTooltips];
}

/* outlineViewItemDidCollapse
 * If I have to explain it to you now, go back to the top of this source file
 * and re-read the comments.
 */
-(void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	// Rebuild the tooltips if required.
	if (useTooltips  == YES)
		[self buildTooltips];
	
	// Have the collapsed item remove any progress indicators.
	TreeNode * collapsedItem = [[notification userInfo] objectForKey:@"NSObject"];
	[collapsedItem stopAndReleaseProgressIndicator];
	
}

/* menuForEvent
 * Handle menu by moving the selection.
 */
-(NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(outlineView:menuWillAppear:)])
		[[self delegate] outlineView:self menuWillAppear:theEvent];
	return [self menu];
}

/* copy
 * Handle the Copy action when the outline view has focus.
 */
-(IBAction)copy:(id)sender
{
	if ([self selectedRow] >= 0)
	{
		NSMutableArray * array = [NSMutableArray arrayWithCapacity:[self numberOfSelectedRows]];
		NSIndexSet * selectedRowIndexes = [self selectedRowIndexes];
		unsigned int item = [selectedRowIndexes firstIndex];
		
		while (item != NSNotFound)
		{
			id node = [self itemAtRow:item];
			[array addObject:node];
			item = [selectedRowIndexes indexGreaterThanIndex:item];
		}
		[[self delegate] copyTableSelection:array toPasteboard:[NSPasteboard generalPasteboard]];
	}
}

/* delete
 * Handle the Delete action when the outline view has focus.
 */
-(IBAction)delete:(id)sender
{
	[[NSApp delegate] deleteFolder:self];
}

/* validateMenuItem
 * This is our override where we handle item validation for the
 * commands that we own.
 */
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(copy:))
	{
		return ([self selectedRow] >= 0);
	}
	if ([menuItem action] == @selector(delete:))
	{
		return [[self delegate] canDeleteFolderAtRow:[self selectedRow]];
	}
	if ([menuItem action] == @selector(selectAll:))
	{
		return YES;
	}
	return NO;
}

/* _highlightColorForCell
 * Ensure that the default outline/table view doesn't draw its own
 * selection.
 */
-(id)_highlightColorForCell:(NSCell *)cell
{
	return nil;
}

/* highlightSelectionInClipRect
 * Draw the hightlight selection using the gradient.
 */
-(void)highlightSelectionInClipRect:(NSRect)rect
{
	NSIndexSet * selectedRowIndexes = [self selectedRowIndexes];
	unsigned int rowIndex = [selectedRowIndexes firstIndex];

	while (rowIndex != NSNotFound)
	{
		NSRect selectedRect = [self rectOfRow:rowIndex];
		if (NSIntersectsRect(selectedRect, rect))
		{
			[blueGradient setFlipped:YES];
			[blueGradient drawInRect:selectedRect fromRect:iRect operation:NSCompositeSourceOver fraction:1];
			[blueGradient setFlipped:NO];

			if ([self editedRow] == -1)
			{
				if ([[self window] firstResponder] != self || ![[self window] isKeyWindow])
					[grayGradient drawInRect:selectedRect fromRect:iRect operation:NSCompositeSourceOver fraction:1];
			}
			if ([self editedRow] != -1)
				[self performSelector:@selector(prvtResizeTheFieldEditor) withObject:nil afterDelay:0.001];
		}
		rowIndex = [selectedRowIndexes indexGreaterThanIndex:rowIndex];
	}
}

/* prvtResizeTheFieldEditor
 * (Code copyright (c) 2005 Ryan Stevens and used with permission. Some additional modifications made.)
 * Resize the field editor on the edit cell so that we display an iTunes-like border around the text
 * being edited.
 */
-(void)prvtResizeTheFieldEditor
{
	id editor = [[self window] fieldEditor:YES forObject:self];
	NSRect editRect = NSIntersectionRect([self rectOfColumn:[self editedColumn]], [self rectOfRow:[self editedRow]]);
	NSRect frame = [[editor superview] frame];
	NSLayoutManager * layoutManager = [editor layoutManager];
	
	[layoutManager boundingRectForGlyphRange:NSMakeRange(0, [layoutManager numberOfGlyphs]) inTextContainer:[editor textContainer]];
	frame.size.width = [layoutManager usedRectForTextContainer:[editor textContainer]].size.width;
	
	if (editRect.size.width > frame.size.width)
		[[editor superview] setFrame:frame];
	else
	{
		frame.size.width = editRect.size.width-4;
		[[editor superview] setFrame:frame];
	}
	
	[editor setNeedsDisplay:YES];
	
	if ([self lockFocusIfCanDraw])
	{
		id clipView = [[[self window] fieldEditor:YES forObject:self] superview];
		NSRect borderRect = [clipView frame];

		// Get rid of the white border, leftover from resizing the fieldEditor..
		editRect.origin.x -= 6;
		editRect.size.width += 6;
		[blueGradient setFlipped:YES];
		[blueGradient drawInRect:editRect fromRect:iRect operation:NSCompositeSourceOver fraction:1];
		[blueGradient setFlipped:NO];
		
		// Put back any cell image
		int editColumnIndex = [self editedColumn];
		if (editColumnIndex != -1)
		{
			NSTableColumn * editColumn = [[self tableColumns] objectAtIndex:editColumnIndex];
			ImageAndTextCell * fieldCell = [editColumn dataCell];
			if ([fieldCell respondsToSelector:@selector(drawCellImage:inView:)])
			{
				// The fieldCell needs to be primed with the image for the cell.
				[[self delegate] outlineView:self willDisplayCell:fieldCell forTableColumn:editColumn item:[self itemAtRow:[self editedRow]]];

				NSRect cellRect = [self frameOfCellAtColumn:editColumnIndex row:[self editedRow]];
				[fieldCell drawCellImage:&cellRect inView:clipView];
			}
		}

		// Fix up the borderRect..
		borderRect.origin.y -= 1;
		borderRect.origin.x -= 1;
		borderRect.size.height += 2;
		borderRect.size.width += 2;
		
		// Draw the border...
		[[NSColor whiteColor] set];
		NSFrameRect(borderRect);
		
		[self unlockFocus];
	}
}

/* textDidChange
 * When the cell contents are edited, redraw the border so it wraps the text
 * rather than the cell.
 */
-(void)textDidChange:(NSNotification *)aNotification
{
	[super textDidChange:aNotification];
	[self prvtResizeTheFieldEditor];
}

/* textDidEndEditing
 * Code from Omni that ensures that when the user hits the Enter key, we finish editing and do NOT move to the next
 * cell which is the default outlineview control cell editing behaviour.
 */
-(void)textDidEndEditing:(NSNotification *)notification;
{
	// This is ugly, but just about the only way to do it. NSTableView is determined to select and edit something else, even the
	// text field that it just finished editing, unless we mislead it about what key was pressed to end editing.
	if ([[[notification userInfo] objectForKey:@"NSTextMovement"] intValue] == NSReturnTextMovement)
	{
		NSMutableDictionary *newUserInfo;
		NSNotification *newNotification;
		
		newUserInfo = [NSMutableDictionary dictionaryWithDictionary:[notification userInfo]];
		[newUserInfo setObject:[NSNumber numberWithInt:NSIllegalTextMovement] forKey:@"NSTextMovement"];
		newNotification = [NSNotification notificationWithName:[notification name] object:[notification object] userInfo:newUserInfo];
		[super textDidEndEditing:newNotification];
		
		// For some reason we lose firstResponder status when when we do the above.
		[[self window] makeFirstResponder:self];
	}
	else
		[super textDidEndEditing:notification];
}

/* dealloc
 * Clean up.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[grayGradient release];
	[blueGradient release];
	[super dealloc];
}
@end
