//
//  BJRWindowWithToolbar.m
//
//  Copyright (c) 2014 Barijaona Ramaholimihaso & Vienna RSS project.
//  All rights reserved.
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
//

#import "BJRWindowWithToolbar.h"

@implementation BJRWindowWithToolbar

// NOTE : as an alternative, we can also override validateMenuItem
// in order to set titles

-(BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    id itemObject = (id)anItem;
	if ( [itemObject action] == @selector(toggleToolbarShown:) && [itemObject respondsToSelector:@selector(setTitle:)] )
	{
		if ([[self toolbar] isVisible])
			[itemObject setTitle:[[NSBundle bundleWithIdentifier:@"com.apple.AppKit"] localizedStringForKey:@"Hide Toolbar" value:@"" table:@"Toolbar"]];
		else
			[itemObject setTitle:[[NSBundle bundleWithIdentifier:@"com.apple.AppKit"] localizedStringForKey:@"Show Toolbar" value:@"" table:@"Toolbar"]];
	}
	return [super validateUserInterfaceItem:anItem];
}

@end
