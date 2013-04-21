//
//  PSMOverflowPopUpButton.h
//  NetScrape
//
//  Created by John Pannell on 8/4/04.
//  Copyright 2004 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PSMRolloverButton : NSButton {
	NSImage	*_rolloverImage;
	NSImage	*_usualImage;
}

@property (retain) NSImage *usualImage;
@property (retain) NSImage *rolloverImage;

@end