//
//  TableViewExtensions.m
//  Vienna
//
//  Created by Steve on Thu Jun 17 2004.
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

#import "TableViewExtensions.h"

@implementation ExtendedTableView

/* setDelegate
 * Override the setDelegate for NSTableView so that we record whether or not the
 * delegate supports tooltips:
 *
 * toolTipForTableColumn should be implemented by the delegate to return the tooltip string for a
 * specified row of the table.
 *
 * tableViewShouldDisplayCellToolTips should be implemented by the delegate to indicate whether or
 * not tooltips should be shown. This is provided separately from toolTipForTableColumn to allow the
 * delegate to selectively turn tooltips on or off based on user preferences.
 */
-(void)setDelegate:(id)delegate
{
    if (delegate != self.delegate)
	{
        super.delegate = delegate;
		delegateImplementsShouldDisplayToolTips = ((delegate && [delegate respondsToSelector:@selector(tableViewShouldDisplayCellToolTips:)]) ? YES : NO);
		delegateImplementsToolTip = ((delegate && [delegate respondsToSelector:@selector(tableView:toolTipForTableColumn:row:)]) ? YES : NO);
	}
}

/* reloadData
 * Override the reloadData for NSTableView to reset the tooltip cursor
 * rectangles.
 */
-(void)reloadData
{
	[super reloadData];
	[self resetCursorRects];
}

/* resetCursorRects
 * Compute the tooltip cursor rectangles based on the height and position of the tableview rows.
 */
-(void)resetCursorRects
{
	[self removeAllToolTips];
    if (delegateImplementsShouldDisplayToolTips && [(id)self.delegate tableViewShouldDisplayCellToolTips:self])
	{
		NSRect visibleRect = self.visibleRect;
		NSIndexSet *columnIndexes = [self columnIndexesInRect:visibleRect];
		NSRange rowRange = [self rowsInRect:visibleRect];
		NSRect frameOfCell;
		NSInteger col, row;
		
		col = columnIndexes.firstIndex;
		while (col != NSNotFound)
		{
			for (row = rowRange.location; row < rowRange.location + rowRange.length; row++)
			{
				frameOfCell = [self frameOfCellAtColumn:col row:row];
				[self addToolTipRect:frameOfCell owner:self userData:NULL];
			}
			col = [columnIndexes indexGreaterThanIndex:col];
		}
	}
}

/* stringForToolTip
 * Request the delegate to retrieve the string to be displayed in the tooltip.
 */
-(NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)matrix
{
	NSInteger rowIndex = [self rowAtPoint:point];
	NSInteger columnIndex = [self columnAtPoint:point];
	NSTableColumn *tableColumn = (columnIndex != -1) ? self.tableColumns[columnIndex] : nil;
    return (columnIndex != -1) ? [(id)self.delegate tableView:self toolTipForTableColumn:tableColumn row:rowIndex] : @"";
}

/* menuForEvent
 * Handle menu by moving the selection.
 */
-(NSMenu *)menuForEvent:(NSEvent *)theEvent
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:menuWillAppear:)])
        [(id)self.delegate tableView:self menuWillAppear:theEvent];
	return self.selectedRow >= 0 ? self.menu : nil;
}

/* setHeaderImage
 * Set the image in the header for a column
 */
-(void)setHeaderImage:(NSString *)identifier imageName:(NSString *)name
{
	NSTableColumn * tableColumn = [self tableColumnWithIdentifier:identifier];
	NSTableHeaderCell * headerCell = tableColumn.headerCell;
	headerCell.image = [NSImage imageNamed:name];
	
	NSImageCell * imageCell = [[NSImageCell alloc] init];
	tableColumn.dataCell = imageCell;
}
@end  

