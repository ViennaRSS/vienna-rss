//
//  ImageTableHeaderCell.m
//  Vienna
//
//  Copyright 2026 Eitot
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "TableHeaderCell.h"

@implementation VNATableHeaderCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    // In macOS 26, image cells are not drawn correctly. The reason for this
    // appears to be that the interior cell frame is collapsed. By overriding
    // height and Y coordinate, the cell appears to be drawn correctly.
    if (self.type == NSImageCellType) {
        cellFrame.size.height = self.cellSize.height;
        cellFrame.origin.y = 0.0;
    }
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

@end
