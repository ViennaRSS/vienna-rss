//
//  MMTabBarViewler.h
//  MMTabBarView
//
//  Created by Kent Sutherland on 11/24/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class MMTabBarView, MMAttachedTabBarButton;

@interface MMTabBarController : NSObject <NSMenuDelegate>

- (instancetype)initWithTabBarView:(MMTabBarView *)aTabBarView;

@property (readonly) NSMenu *overflowMenu;

- (void)layoutButtons;

@end

NS_ASSUME_NONNULL_END
