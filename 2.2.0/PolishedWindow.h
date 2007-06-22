//
//  PolishedWindow.h
//  TunesWindow
//
//  Created by Matt Gemmell on 12/02/2006.
//  Copyright 2006 Magic Aubergine. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SquareWindow.h"

@interface PolishedWindow : SquareWindow {
    BOOL forceDisplay;
}

// Public functions
-(NSColor *)sizedPolishedBackground;
@end
