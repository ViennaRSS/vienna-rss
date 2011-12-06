//
//  PSMLiveChatTabStyle.h
//  --------------------
//
//  Created by Keith Blount on 30/04/2006.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PSMTabStyle.h"

@interface PSMLiveChatTabStyle : NSObject <PSMTabStyle> {
	NSImage									*liveChatCloseButton;
	NSImage									*liveChatCloseButtonDown;
	NSImage									*liveChatCloseButtonOver;
	NSImage									*liveChatCloseDirtyButton;
	NSImage									*liveChatCloseDirtyButtonDown;
	NSImage									*liveChatCloseDirtyButtonOver;
	NSImage									*_addTabButtonImage;
	NSImage									*_addTabButtonPressedImage;
	NSImage									*_addTabButtonRolloverImage;

	NSDictionary								*_objectCountStringAttributes;

	CGFloat									leftMargin;
	PSMTabBarControl							*tabBar;
}
- (void)setLeftMarginForTabBarControl:(CGFloat)margin;
@end
