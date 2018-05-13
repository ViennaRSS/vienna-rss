//
//  MMOverflowPopUpButtonCell.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/24/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#import "MMOverflowPopUpButtonCell.h"
#import "NSCell+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMOverflowPopUpButtonCell ()

@end

@implementation MMOverflowPopUpButtonCell
{
    NSImage *_image;
}

- (instancetype)initTextCell:(NSString *)stringValue pullsDown:(BOOL)pullDown {
    self = [super initTextCell:stringValue pullsDown:pullDown];
    if (self) {
        _bezelDrawingBlock = nil;
        _image = nil;
        _secondImage = nil;
        _secondImageAlpha = 0.0;
    }

    return self;
}

#pragma mark -
#pragma mark Accessors

- (NSImage *)image {
    return _image;
}

- (void)setImage:(NSImage *)image {

        // as super class ignores setting image, we store it separately.
    if (_image) {
        _image = nil;
    }
    
    _image = image;
}

#pragma mark -
#pragma mark Drawing

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {

    [self drawBezelWithFrame:cellFrame inView:controlView];
    [self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [self drawImageWithFrame:cellFrame inView:controlView];
}

- (void)drawImageWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {

    if ([self isHighlighted])
        [self drawImage:[self alternateImage] withFrame:cellFrame inView:controlView];
    else {
        [self drawImage:[self image] withFrame:cellFrame inView:controlView];
        
        if (_secondImage) {
            [self drawImage:_secondImage withFrame:cellFrame inView:controlView alpha:_secondImageAlpha];
        }
    }
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView {
    [self drawImage:image withFrame:frame inView:controlView alpha:1.0];
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView alpha:(CGFloat)alpha {

    NSRect theRect = [self _imageRectForBounds:frame forImage:image];
    
    [image drawInRect:theRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:alpha respectFlipped:YES hints:nil];
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView {
    if (_bezelDrawingBlock) {
        _bezelDrawingBlock(self,frame,controlView);
    }
}

#pragma mark -
#pragma mark Copying

- (id)copyWithZone:(nullable NSZone *)zone {
    
    MMOverflowPopUpButtonCell *cellCopy = [super copyWithZone:zone];
    if (cellCopy) {
    
        cellCopy->_image = [_image copyWithZone:zone];
        cellCopy->_secondImage = [_secondImage copyWithZone:zone];
    }
    
    return cellCopy;
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[super encodeWithCoder:aCoder];

	if ([aCoder allowsKeyedCoding]) {
        [aCoder encodeObject:_image forKey:@"MMTabBarOverflowPopUpImage"];
        [aCoder encodeObject:_secondImage forKey:@"MMTabBarOverflowPopUpSecondImage"];
	}
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super initWithCoder:aDecoder])) {
		if ([aDecoder allowsKeyedCoding]) {
        
            _image = [aDecoder decodeObjectForKey:@"MMTabBarOverflowPopUpImage"];
            _secondImage = [aDecoder decodeObjectForKey:@"MMTabBarOverflowPopUpSecondImage"];
		}
	}
	return self;
}

#pragma mark -
#pragma mark Private Methods

-(NSRect)_imageRectForBounds:(NSRect)theRect forImage:(NSImage *)anImage {

    // for legacy reasons the default behavior is to ignore the image edge behavior
    // of the button and draw the image on the right edge.
    // i've introduced a "center image" property so as to avoid causing problems
    // in other themes.
    // the correct change would be to override the prefered edge behavior in each
    // style to correctly position the image then use the default scaling behavior
    // for a button

    if (self.centerImage) {
        NSRect centerRect = NSMakeRect(theRect.origin.x + (theRect.size.width - anImage.size.width) / 2.0f, theRect.origin.y + (theRect.size.height - anImage.size.height) / 2.0f, anImage.size.width, anImage.size.height);
        return NSIntegralRect(centerRect);
    }


    // calculate rect
    NSRect drawingRect = [self drawingRectForBounds:theRect];
        
    NSSize imageSize = [anImage size];
    
    NSSize scaledImageSize = [self mm_scaleImageWithSize:imageSize toFitInSize:NSMakeSize(imageSize.width, drawingRect.size.height) scalingType:NSImageScaleProportionallyDown];

    NSRect result = NSMakeRect(NSMaxX(drawingRect)-scaledImageSize.width, drawingRect.origin.y, scaledImageSize.width, scaledImageSize.height);

    if (scaledImageSize.height < drawingRect.size.height) {
        result.origin.y += ceil((drawingRect.size.height - scaledImageSize.height) / 2.0);
    }

    return NSIntegralRect(result);
}
@end

NS_ASSUME_NONNULL_END
