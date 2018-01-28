//
//  PSMOverflowPopUpButton.h
//  PSMTabBarControl
//
//  Created by John Pannell on 11/4/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PSMOverflowPopUpButton : NSPopUpButton {
	NSImage									*_PSMTabBarOverflowPopUpImage;
	NSImage									*_PSMTabBarOverflowDownPopUpImage;
	BOOL									_down;
	BOOL									_animatingAlternateImage;
	NSTimer									*_animationTimer;
	CGFloat									_animationValue;
}

- (instancetype)initWithFrame:(NSRect)frameRect pullsDown:(BOOL)flag __attribute((objc_designated_initializer));

//alternate image display
@property (NS_NONATOMIC_IOSONLY) BOOL animatingAlternateImage;

// archiving
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (instancetype)initWithCoder:(NSCoder *)aDecoder __attribute((objc_designated_initializer));
@end
