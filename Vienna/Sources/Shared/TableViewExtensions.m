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

@dynamic delegate;

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
}

/* menuForEvent
 * Handle menu by moving the selection.
 */
-(NSMenu *)menuForEvent:(NSEvent *)theEvent
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:menuWillAppear:)]) {
        [(id)self.delegate tableView:self menuWillAppear:theEvent];
    }
	return self.selectedRow >= 0 ? self.menu : nil;
}

@end
