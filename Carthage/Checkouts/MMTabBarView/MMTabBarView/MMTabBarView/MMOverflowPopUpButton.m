//
//  MMOverflowPopUpButton.m
//  MMTabBarView
//
//  Created by John Pannell on 11/4/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import "MMOverflowPopUpButton.h"

#import "MMOverflowPopUpButtonCell.h"
// #import "MMTabBarView.h"

NS_ASSUME_NONNULL_BEGIN

#define StaticImage(name) \
static NSImage* _static##name##Image() \
{ \
    static NSImage* image = nil; \
    if (!image) \
		image = [[NSBundle bundleForClass:MMOverflowPopUpButtonCell.class] imageForResource:@#name]; \
    return image; \
}

@interface MMOverflowPopUpButton ()

@property (assign) CGFloat secondImageAlpha;

@property (assign) BOOL isAnimating; // pulsating animation of image and second image

@end

@implementation MMOverflowPopUpButton

StaticImage(overflowImage)
StaticImage(overflowImagePressed)

@dynamic secondImageAlpha;

+ (nullable Class)cellClass {
    return MMOverflowPopUpButtonCell.class;
}

- (instancetype)initWithFrame:(NSRect)frameRect pullsDown:(BOOL)flag {
	if ((self = [super initWithFrame:frameRect pullsDown:YES]) != nil) {
    
        _isAnimating = NO;
    
		[self setBezelStyle:NSRegularSquareBezelStyle];
		[self setBordered:NO];
		[self setTitle:@""];
		[self setPreferredEdge:NSMaxYEdge];
        
        [self setImage:_staticoverflowImageImage()];
//        [self setSecondImage:_staticoverflowImagePressedImage()];
        [self setAlternateImage:_staticoverflowImagePressedImage()];
        
        [self _startCellAnimationIfNeeded];
	}
	return self;
}


- (void)viewWillMoveToSuperview:(nullable NSView *)newSuperview {
    [super viewWillMoveToSuperview:newSuperview];
    
    [self _stopCellAnimationIfNeeded];
}

- (void)viewDidMoveToSuperview {

    [super viewDidMoveToSuperview];
    
    [self _startCellAnimationIfNeeded];
}

- (void)viewWillMoveToWindow:(nullable NSWindow *)newWindow {

    [super viewWillMoveToWindow:newWindow];
    
    [self _stopCellAnimationIfNeeded];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    
    [self _startCellAnimationIfNeeded];
}

#pragma mark -
#pragma mark Accessors 

- (void)setHidden:(BOOL)flag {

    [super setHidden:flag];

    @synchronized (self) {
        if (flag)
            [self _stopCellAnimationIfNeeded];
        else
            [self _startCellAnimationIfNeeded];
    }
}

- (void)setFrame:(NSRect)frameRect {

    [super setFrame:frameRect];

    @synchronized (self) {
        if (NSEqualRects(NSZeroRect, frameRect))
            [self _stopCellAnimationIfNeeded];
        else
            [self _startCellAnimationIfNeeded];
    }
}

#pragma mark -
#pragma mark Interfacing Cell

- (nullable NSImage *)secondImage {
    return [self.cell secondImage];
}

- (void)setSecondImage:(nullable NSImage *)anImage {

    [self.cell setSecondImage:anImage];
    
    if (!anImage) {
        [self _stopCellAnimationIfNeeded];
    } else {
        [self _startCellAnimationIfNeeded];
    }
}

#pragma mark -
#pragma mark Animation

+ (nullable id)defaultAnimationForKey:(NSString *)key {

    if ([key isEqualToString:@"isAnimating"]) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"secondImageAlpha"];
        animation.fromValue = [NSNumber numberWithFloat:0.0];
        animation.toValue = [NSNumber numberWithFloat:1.0];
        animation.duration = 1.0;
        animation.autoreverses = YES;    
        animation.repeatCount = CGFLOAT_MAX;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        return animation;
    } else {
        return [super defaultAnimationForKey:key];
    }
}

/* currently unused
- (void)mouseDown:(NSEvent *)event {

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:NSMenuDidEndTrackingNotification object:[self menu]];
	[self setNeedsDisplay:YES];
	[super mouseDown:event];
}

- (void)notificationReceived:(NSNotification *)notification {

	[self setNeedsDisplay:YES];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
*/

#pragma mark -
#pragma mark Bezel Drawing

- (nullable MMCellBezelDrawingBlock)bezelDrawingBlock {
    return [self.cell bezelDrawingBlock];
}

- (void)setBezelDrawingBlock:(nullable MMCellBezelDrawingBlock)aBlock {
    [self.cell setBezelDrawingBlock:aBlock];
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[super encodeWithCoder:aCoder];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super initWithCoder:aDecoder])) {
	}
	return self;
}

#pragma mark -
#pragma mark Private Methods

- (void)_startCellAnimationIfNeeded {

    if (self.window == nil || self.isHidden || NSEqualRects(NSZeroRect, self.frame))
        return;

    if ([self.cell secondImage] == nil)
        return;
    
    [self _startCellAnimation];
}

- (void)_startCellAnimation {
    [self.animator setIsAnimating:YES];
}

- (void)_stopCellAnimationIfNeeded {

    if (_isAnimating)
        [self _stopCellAnimation];
}

- (void)_stopCellAnimation {

    [self setIsAnimating:NO];
}

- (CGFloat)secondImageAlpha {
    return [self.cell secondImageAlpha];
}

- (void)setSecondImageAlpha:(CGFloat)value {
	MMOverflowPopUpButtonCell* const cell = self.cell;
	if (cell == nil) {
		return;
	}
    [cell setSecondImageAlpha:value];
    [self updateCell:cell];
}

@end

NS_ASSUME_NONNULL_END
