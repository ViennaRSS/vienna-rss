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

#import "TreeFilterView.h"

@implementation TreeFilterView

-(instancetype)initWithFrame:(NSRect)frameRect
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

    // Set some useful tooltips.
    [filterSearchField setToolTip:NSLocalizedString(@"Filter folders", nil)];
    [filterSearchField.cell setPlaceholderString:NSLocalizedString(@"Filter folders", nil)];
}

/* drawRect
 * Draw the filter view background.
 */
-(void)drawRect:(NSRect)rect
{
    NSRect iRect = NSMakeRect(0, 0, 1, backgroundBrush.size.height - 1);
    [backgroundBrush drawInRect:rect fromRect:iRect operation:NSCompositeSourceOver fraction:1];
}

@end
