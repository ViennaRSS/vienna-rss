//
//  NSString+MMTabBarViewExtensions.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/19/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface NSString (MMTabBarViewExtensions)

//  Truncate string to no longer than truncationLength; should be > 10
- (NSString *)stringByTruncatingToLength:(NSUInteger)truncationLength;

@end

NS_ASSUME_NONNULL_END
