//
//  PolishedWindow.h
//  TunesWindow
//
//  Created by Matt Gemmell on 12/02/2006.
//  Copyright 2006 Magic Aubergine. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PolishedWindow : NSWindow {
    BOOL _flat;
    BOOL forceDisplay;
}

- (id)initWithContentRect:(NSRect)contentRect 
                styleMask:(unsigned int)styleMask 
                  backing:(NSBackingStoreType)bufferingType 
                    defer:(BOOL)flag 
                     flat:(BOOL)flat;

- (NSColor *)sizedPolishedBackground;

- (BOOL)flat;
- (void)setFlat:(BOOL)newFlat;

@end
