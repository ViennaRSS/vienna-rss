//
//  PSMTabBarController.h
//  PSMTabBarControl
//
//  Created by Kent Sutherland on 11/24/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PSMTabBarControl, PSMTabBarCell;

@interface PSMTabBarController : NSObject <NSMenuDelegate>
{
	PSMTabBarControl	*_control;
	NSMutableArray		*_cellFrames;
	NSMenu				*_overflowMenu;
}

- (instancetype)initWithTabBarControl:(PSMTabBarControl *)control __attribute((objc_designated_initializer));

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMenu *overflowMenu;
- (NSRect)cellFrameAtIndex:(NSInteger)index;

- (void)setSelectedCell:(PSMTabBarCell *)cell;

- (void)layoutCells;

@end
