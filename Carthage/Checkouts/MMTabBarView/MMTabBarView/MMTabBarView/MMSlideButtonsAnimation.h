//
//  MMSlideButtonsAnimation.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/12/12.
//
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class MMTabBarButton;

@interface MMSlideButtonsAnimation : NSViewAnimation

- (instancetype)initWithTabBarButtons:(NSSet<__kindof MMTabBarButton *> *)buttons NS_DESIGNATED_INITIALIZER;

- (void)addAnimationDictionary:(NSDictionary<NSViewAnimationKey, id> *)aDict;

@end

NS_ASSUME_NONNULL_END
