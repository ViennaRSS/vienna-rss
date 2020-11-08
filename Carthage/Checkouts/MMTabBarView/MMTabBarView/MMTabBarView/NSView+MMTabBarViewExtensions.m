//
//  NSView+MMTabBarExtensions.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/13/12.
//
//

#import "NSView+MMTabBarViewExtensions.h"

#import "MMTabBarView.h"
#import "MMTabBarButton.h"

NS_ASSUME_NONNULL_BEGIN

#define MMDragStartHysteresisX                 5.0
#define MMDragStartHysteresisY                 5.0

@implementation NSView (MMTabBarExtensions)

- (BOOL)mm_dragShouldBeginFromMouseDown:(NSEvent *)mouseDownEvent
                           withExpiration:(NSDate *)expiration
{
    return [self mm_dragShouldBeginFromMouseDown:mouseDownEvent
                                    withExpiration:expiration
                                       xHysteresis:MMDragStartHysteresisX
                                       yHysteresis:MMDragStartHysteresisY];
}

- (BOOL)mm_dragShouldBeginFromMouseDown:(NSEvent *)mouseDownEvent
                          withExpiration:(NSDate *)expiration
                             xHysteresis:(CGFloat)xHysteresis
                             yHysteresis:(CGFloat)yHysteresis {

    NSEvent *nextEvent = nil,
            *firstEvent = nil,
            *dragEvent = nil,
            *mouseUp = nil;
    BOOL dragIt = NO;
    
    while ((nextEvent = [self.window nextEventMatchingMask:(NSLeftMouseUpMask | NSLeftMouseDraggedMask) untilDate:expiration inMode:NSEventTrackingRunLoopMode dequeue:YES]) != nil) {
    
        if (firstEvent == nil) {
            firstEvent = nextEvent;
        }
        
        if (nextEvent.type == NSLeftMouseDragged) {
            CGFloat deltaX = ABS(nextEvent.locationInWindow.x - mouseDownEvent.locationInWindow.x);
            CGFloat deltaY = ABS(nextEvent.locationInWindow.y - mouseDownEvent.locationInWindow.y);
            dragEvent = nextEvent;
        
            if (deltaX >= xHysteresis || deltaY >= yHysteresis) {
                dragIt = YES;
                break;
            }
        } else if (nextEvent.type == NSLeftMouseUp) {
            mouseUp = nextEvent;
            break;
        }
    }
    
    // push back dequeued events
    if (mouseUp != nil) {
        [NSApp postEvent:mouseUp atStart:YES];
    }
    if (dragEvent != nil) {
        [NSApp postEvent:dragEvent atStart:YES];
    }
    if (firstEvent != mouseUp && firstEvent != dragEvent) {
        [NSApp postEvent:firstEvent atStart:YES];
    }
    
    return dragIt;
}

- (NSView *)mm_superviewOfClass:(Class)class {
    NSView *view = self.superview;
    while (view  && ![view isKindOfClass:class])
        view = view.superview;
    return view;
}

-(MMTabBarView *)enclosingTabBarView {
    return (MMTabBarView *)[self mm_superviewOfClass:MMTabBarView.class];
}

- (MMTabBarButton *)enclosingTabBarButton {
    return (MMTabBarButton *)[self mm_superviewOfClass:MMTabBarButton.class];
}

- (void)orderFront {

    NSView *superview = self.superview;
    if (!superview)
        return;
    
    NSMutableArray<__kindof NSView *> *subviews = [superview.subviews mutableCopy];
    [subviews removeObjectIdenticalTo:self];
    [subviews addObject:self];
    [superview setSubviews:subviews];
}

@end

NS_ASSUME_NONNULL_END
