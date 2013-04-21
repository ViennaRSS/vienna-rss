//
//  PSMCardTabStyle.h
//  PSMTabBarControl
//
//  Created by Michael Monscheuer on 9/3/12.
//
//

#import <Cocoa/Cocoa.h>
#import "PSMTabStyle.h"

@interface PSMCardTabStyle : NSObject <PSMTabStyle>

{
    NSImage *cardCloseButton;
    NSImage *cardCloseButtonDown;
    NSImage *cardCloseButtonOver;
    NSImage *cardCloseDirtyButton;
    NSImage *cardCloseDirtyButtonDown;
    NSImage *cardCloseDirtyButtonOver;
    NSImage *_addTabButtonImage;
    NSImage *_addTabButtonPressedImage;
    NSImage *_addTabButtonRolloverImage;
	    
    CGFloat _leftMargin;
}

@property (assign) CGFloat leftMarginForTabBarControl;

@end
