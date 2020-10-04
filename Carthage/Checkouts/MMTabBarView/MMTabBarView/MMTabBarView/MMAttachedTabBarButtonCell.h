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
 */
@property (nullable, weak) MMAttachedTabBarButton *attachedTabBarButton;

@end

NS_ASSUME_NONNULL_END
