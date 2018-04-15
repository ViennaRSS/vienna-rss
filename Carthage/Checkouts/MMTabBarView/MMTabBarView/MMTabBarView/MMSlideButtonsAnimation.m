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

- (instancetype)initWithTabBarButtons:(NSSet *)buttons {

    NSArray *viewAnimations = [self _viewAnimationsForButtons:buttons];

    self = [super initWithViewAnimations:viewAnimations];
    if (self)
        {
        [self setDuration:0.3];
        }
    
    return self;
}

- (void)addAnimationDictionary:(NSDictionary *)aDict {

    NSParameterAssert(aDict != nil);
    
    NSMutableArray *animations = [[self viewAnimations] mutableCopy];
    [animations addObject:aDict];
    [self setViewAnimations:animations];
}

#pragma mark -
#pragma mark Private Methods

- (NSArray *)_viewAnimationsForButtons:(NSSet *)buttons {

    NSMutableArray *animations = [NSMutableArray arrayWithCapacity:[buttons count]];

    NSDictionary *animDict = nil;
    
    for (MMTabBarButton *aButton in buttons) {
    
        animDict = [[NSDictionary alloc] initWithObjectsAndKeys:
            aButton, NSViewAnimationTargetKey,
            [NSValue valueWithRect:[aButton frame]], NSViewAnimationStartFrameKey,
            [NSValue valueWithRect:[aButton stackingFrame]], NSViewAnimationEndFrameKey,
            nil];
            
        [animations addObject:animDict];
        
    }
    
    return animations;
}

@end

NS_ASSUME_NONNULL_END
