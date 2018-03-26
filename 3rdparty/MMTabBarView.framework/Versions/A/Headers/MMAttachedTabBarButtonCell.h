//
//  MMAttachedTabBarButtonCell.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/5/12.
//
//

#import "MMTabBarButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@class MMAttachedTabBarButton;

@interface MMAttachedTabBarButtonCell : MMTabBarButtonCell

@property (assign) BOOL isOverflowButton;

/**
 *  The control view
 * 
 *  TODO: fix, rename "attachedTabBarButton"
 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-property-type"
@property (assign) MMAttachedTabBarButton *controlView;
#pragma clang diagnostic pop

@end

NS_ASSUME_NONNULL_END
