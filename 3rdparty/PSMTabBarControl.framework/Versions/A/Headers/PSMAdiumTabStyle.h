//
//  PSMAdiumTabStyle.h
//  PSMTabBarControl
//
//  Created by Kent Sutherland on 5/26/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PSMTabStyle.h"

@interface PSMAdiumTabStyle : NSObject <PSMTabStyle>
{
	NSImage									*_closeButton;
	NSImage									*_closeButtonDown;
	NSImage									*_closeButtonOver;
	NSImage									*_closeDirtyButton;
	NSImage									*_closeDirtyButtonDown;
	NSImage									*_closeDirtyButtonOver;
	NSImage									*_addTabButtonImage;
	NSImage									*_addTabButtonPressedImage;
	NSImage									*_addTabButtonRolloverImage;
	NSImage									*_gradientImage;

	NSDictionary								*_objectCountStringAttributes;

	PSMTabBarOrientation						orientation;
	PSMTabBarControl							*tabBar;

	BOOL										_drawsUnified;
	BOOL										_drawsRight;
}

- (void)loadImages;

- (BOOL)drawsUnified;
- (void)setDrawsUnified:(BOOL)value;
- (BOOL)drawsRight;
- (void)setDrawsRight:(BOOL)value;

- (void)drawInteriorWithTabCell:(PSMTabBarCell *)cell inView:(NSView*)controlView;

- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

@end
