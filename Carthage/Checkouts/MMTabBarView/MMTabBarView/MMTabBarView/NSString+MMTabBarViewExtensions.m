//
//  NSString+MMTabBarViewExtensions.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/19/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#import "NSString+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSString (MMTabBarViewExtensions)

// Truncate string to no longer than truncationLength; should be > 10
- (NSString *)stringByTruncatingToLength:(NSUInteger)truncationLength {
    NSUInteger len = self.length;
    if (len < truncationLength)
        return [self copy];
        
        // Unicode character 2026 is ellipsis
    return [[self substringToIndex:truncationLength - 10] stringByAppendingString:@"\u2026"];
}

@end

NS_ASSUME_NONNULL_END
