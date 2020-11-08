//
//  MMTabDragView.m
//  MMTabBarView
//
//  Created by Kent Sutherland on 6/17/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#import "MMTabDragView.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMTabDragView

- (instancetype)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_alpha = 1.0;
	}
	return self;
}

- (void)drawRect:(NSRect)rect {
	//1.0 fade means show the primary image
	//0.0 fade means show the secondary image
	CGFloat primaryAlpha = _alpha + 0.001, alternateAlpha = 1.001 - _alpha;
	NSRect srcRect;
	srcRect.origin = NSZeroPoint;
	srcRect.size = _image.size;

	[_image drawInRect:self.bounds fromRect:srcRect operation:NSCompositeSourceOver fraction:primaryAlpha respectFlipped:YES hints:nil];
	srcRect.size = _alternateImage.size;
	[_alternateImage drawInRect:self.bounds fromRect:srcRect operation:NSCompositeSourceOver fraction:alternateAlpha respectFlipped:YES hints:nil];
}

@end

NS_ASSUME_NONNULL_END
