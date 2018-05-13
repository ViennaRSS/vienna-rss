//
//  NSCell+MMTabBarViewExtensions.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/25/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#import "NSCell+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSCell (MMTabBarViewExtensions)

#pragma mark -
#pragma mark Image Scaling

static inline NSSize mm_scaleProportionally(NSSize imageSize, NSSize canvasSize, BOOL scaleUpOrDown) {

    CGFloat ratio;

    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return NSMakeSize(0, 0);
    }

    // get the smaller ratio and scale the image size with it
    ratio = MIN(canvasSize.width / imageSize.width,
	      canvasSize.height / imageSize.height);
  
    // Only scale down, unless scaleUpOrDown is YES
    if (ratio < 1.0 || scaleUpOrDown)
        {
        imageSize.width *= ratio;
        imageSize.height *= ratio;
        }
    
    return imageSize;
} 

- (NSSize)mm_scaleImageWithSize:(NSSize)imageSize toFitInSize:(NSSize)canvasSize scalingType:(NSImageScaling)scalingType {

    NSSize result;
  
    switch (scalingType)  {
        case NSImageScaleProportionallyDown:
            result = mm_scaleProportionally (imageSize, canvasSize, NO);
            break;
        case NSImageScaleAxesIndependently:
            result = canvasSize;
            break;
        default:
        case NSImageScaleNone:
            result = imageSize;
            break;
        case NSImageScaleProportionallyUpOrDown:
            result = mm_scaleProportionally (imageSize, canvasSize, YES);
            break;
    }
    
    return result;
}

@end

NS_ASSUME_NONNULL_END
