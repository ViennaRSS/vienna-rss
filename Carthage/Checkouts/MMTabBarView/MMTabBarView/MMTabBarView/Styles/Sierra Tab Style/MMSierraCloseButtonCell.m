//
//  MMSierraCloseButtonCell.m
//  MMTabBarView
//
//  Created by Isaiah Carew on 4/23/17.
//  Copyright © 2017 Michael Monscheuer. All rights reserved.
//

#import "MMSierraCloseButtonCell.h"
#import "MMSierraCloseButton.h"

@implementation MMSierraCloseButtonCell

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView {
    static NSImage *closeImage = nil;
    static NSImage *editedImage = nil;

    if (!closeImage) {
        closeImage = [[MMTabBarView bundle] imageForResource:@"MMSierraTabClose"];
    }

    if (!editedImage) {
        editedImage = [[MMTabBarView bundle] imageForResource:@"MMSierraTabEdited"];
    }

    NSView *tabButtonView = controlView.superview;
    if (![tabButtonView isKindOfClass:NSButton.class]) return;
    MMTabBarButton *tabButton = (MMTabBarButton *)tabButtonView;

    NSImage *customImage = nil;
    NSRect customFrame = NSMakeRect(4.0, 4.0, 8.0, 8.0);
    if (tabButton.isEdited) {
        customImage = editedImage;
    } else {
        customImage = closeImage;
    }


    CGFloat opacity = 1.0;
    if (controlView.window.isKeyWindow || controlView.window.isMainWindow) {
        if (self.isHighlighted) {
            opacity = 0.470;
        } else if (self.mouseHovered) {
            opacity = 0.475;
        } else {
            opacity = 0.45;
        }
    } else {
        if (self.mouseHovered) {
            opacity = 0.400;
        } else {
            opacity = 0.350;
        }
    }

    [customImage drawInRect:customFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:opacity respectFlipped:YES hints:nil];
}

- (NSRect)topBorderRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x, 0, frame.size.width, 1.0);
}

- (NSRect)leftBorderRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x, 0, 1.0, frame.size.height - 1.0);
}

- (NSRect)fillRectWithFrame:(NSRect)frame {
    return NSMakeRect(frame.origin.x + 1, frame.origin.y + 1, frame.size.width - 1.0, frame.size.height - 2.0);
}

- (void)drawActiveBezelWithFrame:(NSRect)frame inView:(NSView *)controlView {
    NSGradient *fillGradient = nil;

    NSView *tabButtonView = controlView.superview;
    if (![tabButtonView isKindOfClass:NSButton.class]) return;
    NSButton *tabButton = (NSButton *)tabButtonView;

    if (tabButton.state == NSOnState) {
        if (self.isHighlighted) {
            fillGradient = [MMSierraCloseButtonCell selectedMouseDownFillGradient];
        } else {
            fillGradient = [MMSierraCloseButtonCell selectedHoverFillGradient];
        }
    } else {
        if (self.isHighlighted) {
            fillGradient = [MMSierraCloseButtonCell unselectedMouseDownFillGradient];
        } else {
            fillGradient = [MMSierraCloseButtonCell unselectedHoverFillGradient];
        }
    }

    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:frame radius:2.0 capMask:MMBezierShapeAllCaps];
    [fillGradient drawInBezierPath:path angle:90.0];
}

- (void)drawInactiveBezelWithFrame:(NSRect)frame inView:(NSView *)controlView {
    if (self.isHighlighted) {
        [[MMSierraCloseButtonCell inactiveSelectedFillColor] set];
    } else {
        [[MMSierraCloseButtonCell inactiveUnselectedFillColor] set];
    }

    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:frame radius:2.0 capMask:MMBezierShapeAllCaps];
    [path fill];
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView {
    // no bezel if not hovering
    if (!self.mouseHovered) return;

    if (controlView.window.isKeyWindow || controlView.window.isMainWindow) {
        [self drawActiveBezelWithFrame:frame inView:controlView];
    } else {
        [self drawInactiveBezelWithFrame:frame inView:controlView];
    }
}

#pragma mark - fill gradients

+ (NSGradient *)selectedHoverFillGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.718 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.702 alpha:1.0]
                      ]];
    }
    return gradient;
}

+ (NSGradient *)selectedMouseDownFillGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.667 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.651 alpha:1.0]
                      ]];
    }
    return gradient;
}

+ (NSGradient *)unselectedHoverFillGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.584 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.569 alpha:1.0]
                      ]];
    }
    return gradient;
}

+ (NSGradient *)unselectedMouseDownFillGradient {
    static NSGradient *gradient = nil;
    if (!gradient) {
        gradient = [[NSGradient alloc] initWithColors:
                    @[
                      [NSColor colorWithCalibratedWhite:0.541 alpha:1.0],
                      [NSColor colorWithCalibratedWhite:0.525 alpha:1.0]
                      ]];
    }
    return gradient;
}

#pragma mark - inactive windows

+ (NSColor *)inactiveSelectedFillColor {
    static NSColor *color = nil;
    if (!color) {
        color = [NSColor colorWithCalibratedWhite:0.871 alpha:1.0];
    }
    return color;
}

+ (NSColor *)inactiveUnselectedFillColor {
    static NSColor *color = nil;
    if (!color) {
        color = [NSColor colorWithCalibratedWhite:0.792 alpha:1.0];
    }
    return color;
}

@end
