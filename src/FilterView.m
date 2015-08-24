//
//  FilterView.h
//  Vienna
//
//  Created by Steve on 29/7/07.
//  Copyright (c) 2004-2007 Steve Palmer. All rights reserved.
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

#import "FilterView.h"

@implementation FilterView

-(id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		backgroundBrush = nil;
	}
	return self;
}

/* awakeFromNib
 * Our init.
 */
-(void)awakeFromNib
{
	NSString * backgroundBrushURL = [[NSBundle mainBundle] pathForResource:@"filterViewBackground" ofType:@"tiff"];
	backgroundBrush = [[NSImage alloc] initWithContentsOfFile: backgroundBrushURL ];

	// Give the label the typical embossed look
	[[filterByLabel cell] setBackgroundStyle:NSBackgroundStyleRaised];
	// Make sure we localise the label
	[filterByLabel setStringValue:NSLocalizedString(@"Filter by:", nil)];

	// Set some useful tooltips.
	[filterSearchField setToolTip:NSLocalizedString(@"Filter displayed articles by matching text", nil)];
	[filterViewPopUp setToolTip:NSLocalizedString(@"Filter articles", nil)];
    [filterViewPopUp.cell accessibilitySetOverrideValue:filterByLabel.cell forAttribute:NSAccessibilityTitleUIElementAttribute];
	[filterCloseButton setToolTip:NSLocalizedString(@"Close the filter bar", nil)];
	[[filterCloseButton cell] accessibilitySetOverrideValue:NSLocalizedString(@"Close the filter bar", nil) forAttribute:NSAccessibilityTitleAttribute];
}

/* drawRect
 * Draw the filter view background.
 */
-(void)drawRect:(NSRect)rect
{
	NSRect iRect = NSMakeRect(0, 0, 1, [backgroundBrush size].height - 1);					
	[backgroundBrush drawInRect:rect fromRect:iRect operation:NSCompositeSourceOver fraction:1];
}

/* dealloc
 * Release resources at the end.
 */
-(void)dealloc
{
	backgroundBrush=nil;
}
@end
