//
//  PSMTexturedMetalTabStyle.h
//  PSMTabBarControl
//
//  Created by Christopher Cahoon on 5/8/2014.
//  Based on PSMMetalTabStyle.h
//  Created by John Pannell on 2/17/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.

#import <Cocoa/Cocoa.h>
#import "PSMTabStyle.h"

@interface PSMTexturedMetalTabStyle : NSObject <PSMTabStyle> {
	NSImage					*metalCloseButton;
	NSImage					*metalCloseButtonDown;
	NSImage					*metalCloseButtonOver;
	NSImage					*metalCloseDirtyButton;
	NSImage					*metalCloseDirtyButtonDown;
	NSImage					*metalCloseDirtyButtonOver;
	NSImage					*_addTabButtonImage;
	NSImage					*_addTabButtonPressedImage;
	NSImage					*_addTabButtonRolloverImage;

	NSDictionary			*_objectCountStringAttributes;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
- (instancetype)initWithCoder:(NSCoder *)aDecoder;

@end
