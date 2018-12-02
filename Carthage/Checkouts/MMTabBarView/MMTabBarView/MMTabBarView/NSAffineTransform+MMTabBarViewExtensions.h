//
//  NSAffineTransform+MMTabBarViewExtensions.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/26/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface NSAffineTransform (MMTabBarViewExtensions)

- (NSAffineTransform *)mm_flipVertical:(NSRect)bounds;

@end

NS_ASSUME_NONNULL_END
