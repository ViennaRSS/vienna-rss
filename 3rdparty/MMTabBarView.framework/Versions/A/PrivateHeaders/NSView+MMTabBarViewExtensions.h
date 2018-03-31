//
//  NSView+MMTabBarViewExtensions.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/13/12.
//
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MMTabBarView;
@class MMTabBarButton;

@interface NSView (MMTabBarViewExtensions)

- (BOOL)mm_dragShouldBeginFromMouseDown:(NSEvent *)mouseDownEvent withExpiration:(NSDate *)expiration;
- (BOOL)mm_dragShouldBeginFromMouseDown:(NSEvent *)mouseDownEvent withExpiration:(NSDate *)expiration xHysteresis:(CGFloat)xHysteresis yHysteresis:(CGFloat)yHysteresis;

- (NSView *)mm_superviewOfClass:(Class)class;

- (MMTabBarView *)enclosingTabBarView;
- (MMTabBarButton *)enclosingTabBarButton;

- (void)orderFront;

@end

NS_ASSUME_NONNULL_END
