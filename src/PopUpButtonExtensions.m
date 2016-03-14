//
//  PopUpButtonExtensions.m
//  Vienna
//
//  Created by Steve on 7/16/05.
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

#import "PopUpButtonExtensions.h"

@implementation NSPopUpButton (PopUpButtonExtensions)

/* addItemWithTitle
 * Add an item to the popup button menu with an associated image. The image is rescaled to 16x16 to fit in
 * the menu. I've been trying to figure out how to get the actual menu item height but at a minimum, 16x16
 * is the conventional size for a 'small' document icon. So I'm OK with this for now.
 */
-(void)addItemWithTitle:(NSString *)title image:(NSImage *)image
{
	NSMenuItem * newItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
	[image setSize:NSMakeSize(16, 16)];
	[newItem setImage:image];
	[[self menu] addItem:newItem];
}

/* addItemWithTarget
 * Add an item to the popup button menu with the specified target.
 */
-(void)addItemWithTarget:(NSString *)title target:(SEL)target
{
	NSMenuItem * newItem = [[NSMenuItem alloc] initWithTitle:title action:target keyEquivalent:@""];
	[[self menu] addItem:newItem];
}

/* addItemWithTag
 * Add an item to the popup button menu with the specified tag.
 */
-(void)addItemWithTag:(NSString *)title tag:(NSInteger)tag
{
	NSMenuItem * newItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
	[newItem setTag:tag];
	[[self menu] addItem:newItem];
}

/* addItemWithRepresentedObject
 * Add an item to the popup button menu with the specified represented object.
 */
-(void)addItemWithRepresentedObject:(NSString *)title object:(id)object
{
	NSMenuItem * newItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
	[newItem setRepresentedObject:object];
	[[self menu] addItem:newItem];
}

/* insertItemWithTag
 * Inserts the specified menu item into the popup menu at the given index and assigns it
 * an initial tag value.
 */
-(void)insertItemWithTag:(NSString *)title tag:(NSInteger)tag atIndex:(NSInteger)index
{
	NSMenuItem * newItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
	[newItem setTag:tag];
	[[self menu] insertItem:newItem atIndex:index];
}

/* representedObjectForSelection
 * Returns the represented object associated with the selected item.
 */
-(id)representedObjectForSelection
{
	NSMenuItem * theItem = [self selectedItem];
	return [theItem representedObject];
}

/* tagForSelection
 * Returns the tag associated with the selected item.
 */
-(NSInteger)tagForSelection
{
	NSMenuItem * theItem = [self selectedItem];
	return [theItem tag];
}

/* addSeparator
 * Add a separator item to the popup button menu.
 */
-(void)addSeparator
{
	[[self menu] addItem:[NSMenuItem separatorItem]];
}
@end
