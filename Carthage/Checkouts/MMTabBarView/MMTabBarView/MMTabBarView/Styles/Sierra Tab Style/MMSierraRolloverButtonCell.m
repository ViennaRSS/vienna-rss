//
//  MMSierraRolloverButtonCell.m
//  MMTabBarView
//
//  Created by Isaiah Carew on 4/19/17.
//

#import "MMSierraRolloverButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMSierraRolloverButtonCell

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView {
    NSRect customFrame = NSMakeRect(7.0f, 7.0f, 11.0f, 11.0f);
//    NSImage *addImage = [[NSImage alloc] initByReferencingFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:@"SierraTabNew"]];
    NSImage *addImage = [NSImage imageNamed:NSImageNameAddTemplate];
    CGFloat opacity = 1.0f;

    if (controlView.window.isKeyWindow || controlView.window.isMainWindow) {
        if (self.isHighlighted) {
            opacity = 0.470f;
        } else if (self.mouseHovered) {
            opacity = 0.475f;
        } else {
            opacity = 0.45f;
        }
    } else {
        if (self.mouseHovered) {
            opacity = 0.400f;
        } else {
            opacity = 0.350f;
        }
    }

    [addImage drawInRect:customFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:opacity respectFlipped:YES hints:nil];
}

- (NSRect)topBorderRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x, 0, frame.size.width, 1.0f);
}

- (NSRect)leftBorderRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x, 0, 1.0f, frame.size.height - 1.0f);
}

- (NSRect)fillRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x + 1, frame.origin.y + 1, frame.size.width - 1.0f, frame.size.height - 2.0f);
}

- (void)drawActiveBezelWithFrame:(NSRect)frame inView:(NSView *)controlView {
    NSGradient *topBorderGradient = nil;
    NSGradient *leftBorderGradient = nil;
    NSGradient *fillGradient = nil;

    if (self.isHighlighted) {
        topBorderGradient = [MMSierraRolloverButtonCell mouseDownTopBorderGradient];
        leftBorderGradient = [MMSierraRolloverButtonCell mouseDownLeftBorderGradient];
        fillGradient = [MMSierraRolloverButtonCell mouseDownFillGradient];
    } else if (self.mouseHovered) {
        topBorderGradient = [MMSierraRolloverButtonCell hoverTopBorderGradient];
        leftBorderGradient = [MMSierraRolloverButtonCell hoverLeftBorderGradient];
        fillGradient = [MMSierraRolloverButtonCell hoverFillGradient];
    } else {
        topBorderGradient = [MMSierraRolloverButtonCell idleTopBorderGradient];
        leftBorderGradient = [MMSierraRolloverButtonCell idleLeftBorderGradient];
        fillGradient = [MMSierraRolloverButtonCell idleFillGradient];
    }

    [fillGradient drawInRect:[self fillRectWithFrame:frame] angle:90.0f];
    [topBorderGradient drawInRect:[self topBorderRectWithFrame:frame] angle:90.0f];
    [leftBorderGradient drawInRect:[self leftBorderRectWithFrame:frame] angle:90.0f];
}

- (void)drawInactiveBezelWithFrame:(NSRect)frame inView:(NSView *)controlView {
    if (self.mouseHovered) {
        [[MMSierraRolloverButtonCell inactiveHoverFillColor] set];
    } else {
        [[MMSierraRolloverButtonCell inactiveIdleFillColor] set];
    }
    NSRectFill([self fillRectWithFrame:frame]);

    [[MMSierraRolloverButtonCell inactiveBorderColor] set];
    NSFrameRect([self leftBorderRectWithFrame:frame]);
    NSFrameRect([self topBorderRectWithFrame:frame]);
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView {
    if (controlView.window.isKeyWindow || controlView.window.isMainWindow) {
        [self drawActiveBezelWithFrame:frame inView:controlView];
    } else {
        [self drawInactiveBezelWithFrame:frame inView:controlView];
    }
}

#pragma mark - fill gradients

+ (NSGradient *)idleFillGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.698 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.682 alpha:1.0]
                      ]];
    }
    return gradient;
}

+ (NSGradient *)hoverFillGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.663 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.647 alpha:1.0]
                      ]];
    }
    return gradient;
}

+ (NSGradient *)mouseDownFillGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.608 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.557 alpha:1.0]
                      ]];
    }
    return gradient;
}

#pragma mark - top border gradients

+ (NSGradient *)idleTopBorderGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.592 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.588 alpha:1.0]
                      ]];
    }
    return gradient;
}

+ (NSGradient *)hoverTopBorderGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.494 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.490 alpha:1.0]
                      ]];
    }
    return gradient;
}

+ (NSGradient *)mouseDownTopBorderGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.471 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.467 alpha:1.0]
                      ]];
    }
    return gradient;
}


#pragma mark - left-border gradients

+ (NSGradient *)idleLeftBorderGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.588 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.573 alpha:1.0]
                      ]];
    }
    return gradient;
}

+ (NSGradient *)hoverLeftBorderGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.522 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.506 alpha:1.0]
                      ]];
    }
    return gradient;
}

+ (NSGradient *)mouseDownLeftBorderGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.490 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.443 alpha:1.0]
                      ]];
    }
    return gradient;
}

#pragma mark - inactive windows

+ (NSColor *)inactiveIdleFillColor {
    static NSColor *color = nil;
    if (!color) {
        color = [NSColor colorWithCalibratedWhite:0.906 alpha:1.0];
    }
    return color;
}

+ (NSColor *)inactiveHoverFillColor {
    static NSColor *color = nil;
    if (!color) {
        color = [NSColor colorWithCalibratedWhite:0.871 alpha:1.0];
    }
    return color;
}

+ (NSColor *)inactiveBorderColor {
    static NSColor *color = nil;
    if (!color) {
        color = [NSColor colorWithCalibratedWhite:0.784 alpha:1.0];
    }
    return color;
}

@end

NS_ASSUME_NONNULL_END
