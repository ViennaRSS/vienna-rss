//
//  MMCardTabStyle.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/3/12.
//
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif
#import "MMTabStyle.h"
#import "NSBezierPath+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMCardTabStyle : NSObject <MMTabStyle>

@property (assign) CGFloat horizontalInset;
@property (assign) CGFloat topMargin;

#pragma mark Card Tab Style Drawings

// the funnel point for modify tab button drawing in a subclass
- (void)drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView;

@end

NS_ASSUME_NONNULL_END
