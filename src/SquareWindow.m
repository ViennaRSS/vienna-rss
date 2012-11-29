//
//  SquareWindow.m
//  Vienna
//
//  Created by Steve on 10/14/05.
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
#import "SquareWindow.h"

@implementation SquareWindow

/* initWithContentRect
 * Subclass the designated initialiser for NSWindow to set the square bottom edge style using the
 * undocumented setBottomCornerRounded function.
 */
-(id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)styleMask backing:(NSBackingStoreType)backingType defer:(BOOL)flag
{
	if ((self = [super initWithContentRect:contentRect styleMask:styleMask backing:backingType defer:flag]) != nil)
	{
		if ([self respondsToSelector:@selector(setBottomCornerRounded:)])
			[self setBottomCornerRounded:NO];	
	}
	return self;
}
@end
