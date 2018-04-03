//
//  MMTabBarView.Private.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 23/05/15.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@interface MMTabBarView (PrivateDrawing)

- (void)_drawInteriorInRect:(NSRect)rect;

@property (readonly) NSRect _addTabButtonRect;
@property (readonly) NSRect _overflowButtonRect;

@property (assign) BOOL isReorderingTabViewItems;

#pragma mark Private Actions

- (void)_overflowMenuAction:(id)sender;
- (void)_didClickTabButton:(id)sender;
- (void)_didClickCloseButton:(id)sender;

@end

NS_ASSUME_NONNULL_END
