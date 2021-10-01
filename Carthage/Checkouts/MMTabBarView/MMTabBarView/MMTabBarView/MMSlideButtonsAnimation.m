//
//  MMSlideButtonsAnimation.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/12/12.
//
//

#import "MMSlideButtonsAnimation.h"

#import "MMTabBarButton.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMSlideButtonsAnimation

- (instancetype)initWithTabBarButtons:(NSSet<__kindof MMTabBarButton *> *)buttons {

    NSArray<NSDictionary<NSViewAnimationKey, id> *> *viewAnimations = [self _viewAnimationsForButtons:buttons];

    self = [super initWithViewAnimations:viewAnimations];
    if (self)
        {
        [self setDuration:0.3];
        }
    
    return self;
}

- (void)addAnimationDictionary:(NSDictionary<NSViewAnimationKey, id> *)aDict {

    NSParameterAssert(aDict != nil);
    
    NSMutableArray<NSDictionary<NSViewAnimationKey, id> *> *animations = [self.viewAnimations mutableCopy];
    [animations addObject:aDict];
    [self setViewAnimations:animations];
}

#pragma mark -
#pragma mark Private Methods

- (NSArray<NSDictionary<NSViewAnimationKey, id> *> *)_viewAnimationsForButtons:(NSSet<__kindof MMTabBarButton *> *)buttons {

    NSMutableArray<NSDictionary<NSViewAnimationKey, id> *> *animations = [NSMutableArray arrayWithCapacity:buttons.count];

    NSDictionary<NSViewAnimationKey, id> *animDict = nil;
    
    for (MMTabBarButton *aButton in buttons) {
		animDict = @{
			NSViewAnimationTargetKey: aButton,
			NSViewAnimationStartFrameKey: [NSValue valueWithRect:aButton.frame],
			NSViewAnimationEndFrameKey: [NSValue valueWithRect:aButton.stackingFrame]
		};
        [animations addObject:animDict];        
    }
    
    return animations;
}

@end

NS_ASSUME_NONNULL_END
