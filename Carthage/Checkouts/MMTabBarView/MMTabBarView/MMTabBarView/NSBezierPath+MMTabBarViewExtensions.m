//
//  NSBezierPath+MMTabBarViewExtensions.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/26/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#import "NSBezierPath+MMTabBarViewExtensions.h"

#import "NSAffineTransform+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSBezierPath (MMTabBarViewExtensions)

+ (NSBezierPath *)bezierPathWithCardInRect:(NSRect)aRect radius:(CGFloat)radius capMask:(MMBezierShapeCapMask)mask {

    NSBezierPath *bezier = [self _bezierPathWithCardInRect:aRect radius:radius capMask:mask];

        // Flip the final NSBezierPath.
    if (mask & MMBezierShapeFlippedVertically)
        [bezier transformUsingAffineTransform:[NSAffineTransform.transform mm_flipVertical:bezier.bounds]];
    
    return bezier;
}

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)aRect radius:(CGFloat)radius capMask:(MMBezierShapeCapMask)mask {

    NSBezierPath *bezier = [self _bezierPathWithRoundedRect:aRect radius:radius capMask:mask];

        // Flip the final NSBezierPath.
    if (mask & MMBezierShapeFlippedVertically)
        [bezier transformUsingAffineTransform:[NSAffineTransform.transform mm_flipVertical:bezier.bounds]];
    
    return bezier;
}

#pragma mark -
#pragma mark Private Methods

+ (NSBezierPath *)_bezierPathWithCardInRect:(NSRect)aRect radius:(CGFloat)radius capMask:(MMBezierShapeCapMask)mask {

    NSBezierPath *bezier = NSBezierPath.bezierPath;

    if (mask & MMBezierShapeLeftCap) {
        [bezier moveToPoint: NSMakePoint(NSMinX(aRect),NSMaxY(aRect))];
        [bezier appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(aRect),NSMinY(aRect)) toPoint:NSMakePoint(NSMidX(aRect),NSMinY(aRect)) radius:radius];
    } else {
        if (mask & MMBezierShapeFillPath) {
            [bezier moveToPoint: NSMakePoint(NSMinX(aRect),NSMaxY(aRect))];
            [bezier lineToPoint:NSMakePoint(NSMinX(aRect), NSMinY(aRect))];
        } else {
            [bezier moveToPoint:NSMakePoint(NSMinX(aRect), NSMinY(aRect))];
        }
    }
    
    if (mask & MMBezierShapeRightCap) {
        [bezier appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(aRect),NSMinY(aRect)) toPoint:NSMakePoint(NSMaxX(aRect),NSMaxY(aRect)) radius:radius];
        [bezier lineToPoint: NSMakePoint(NSMaxX(aRect),NSMaxY(aRect))];
    } else {

        [bezier lineToPoint: NSMakePoint(NSMaxX(aRect),NSMinY(aRect))];
        if (mask & MMBezierShapeFillPath)
            [bezier lineToPoint: NSMakePoint(NSMaxX(aRect),NSMaxY(aRect))];
    }
    
    return bezier;
}

+ (NSBezierPath *)_bezierPathWithRoundedRect:(NSRect)aRect radius:(CGFloat)radius capMask:(MMBezierShapeCapMask)mask {

    NSBezierPath *bezier = NSBezierPath.bezierPath;

    [bezier moveToPoint: NSMakePoint(NSMidX(aRect),NSMaxY(aRect))];
    if (mask & MMBezierShapeLeftCap) {
        [bezier appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(aRect),NSMaxY(aRect)) toPoint:NSMakePoint(NSMinX(aRect),NSMinY(aRect)) radius:radius];
        [bezier appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(aRect),NSMinY(aRect)) toPoint:NSMakePoint(NSMidX(aRect),NSMinY(aRect)) radius:radius];
        [bezier lineToPoint:NSMakePoint(NSMidX(aRect),NSMinY(aRect))];
    } else {
        [bezier lineToPoint:NSMakePoint(NSMinX(aRect),NSMaxY(aRect))];
        if (mask & MMBezierShapeFillPath)
            [bezier lineToPoint:NSMakePoint(NSMinX(aRect),NSMinY(aRect))];
        else
            [bezier moveToPoint:NSMakePoint(NSMinX(aRect),NSMinY(aRect))];
        [bezier lineToPoint:NSMakePoint(NSMidX(aRect),NSMinY(aRect))];
    }
    
    if (mask & MMBezierShapeRightCap) {
        [bezier appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect)) toPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect)) radius:radius];
        [bezier appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect)) toPoint:NSMakePoint(NSMidX(aRect), NSMaxY(aRect)) radius:radius];
        [bezier closePath];
    } else {
        [bezier lineToPoint:NSMakePoint(NSMaxX(aRect),NSMinY(aRect))];
        if (mask & MMBezierShapeFillPath)
            [bezier lineToPoint:NSMakePoint(NSMaxX(aRect),NSMaxY(aRect))];
        else
            [bezier moveToPoint:NSMakePoint(NSMaxX(aRect),NSMaxY(aRect))];
        [bezier lineToPoint:NSMakePoint(NSMidX(aRect),NSMaxY(aRect))];
        [bezier closePath];
    }
 
    return bezier;
}
@end

NS_ASSUME_NONNULL_END
