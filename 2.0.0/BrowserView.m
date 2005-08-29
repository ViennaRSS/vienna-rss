//
//  BrowserView.m
//  Vienna
//
//  Created by Steve on 8/26/05.
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

#import "BrowserView.h"

@implementation BrowserView

/* initWithFrame
 * Initialises the browser view control.
 */
-(id)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame]) != nil)
	{
		primaryView = nil;
		activeView = nil;
    }
    return self;
}

/* setPrimaryView
 * Sets the primary view. This is the view that is always displayed.
 */
-(void)setPrimaryView:(NSView *)newPrimaryView
{
	[newPrimaryView retain];
	[primaryView release];
	primaryView = newPrimaryView;

	if (activeView == nil)
	{
		[primaryView setFrameSize:[self frame].size];
		[self addSubview:primaryView];
		activeView = primaryView;
	}
}

/* primaryView
 * Returns the primary view.
 */
-(NSView<BaseView> *)primaryView
{
	return primaryView;
}

/* activeView
 * Returns the active view which is the view currently being displayed.
 */
-(NSView<BaseView> *)activeView
{
	return activeView;
}

/* dealloc
 * Clean up behind ourselves.
 */
-(void)dealloc
{
	[primaryView release];
	[super dealloc];
}
@end
