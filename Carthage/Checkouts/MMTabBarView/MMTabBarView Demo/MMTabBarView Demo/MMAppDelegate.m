//
//  MMAppDelegate.m
//  MMTabBarView Demo
//
//  Created by Michael Monscheuer on 9/19/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#import "MMAppDelegate.h"

#import "DemoWindowController.h"

@implementation MMAppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)pNotification {
    [NSColorPanel.sharedColorPanel setShowsAlpha:YES];

	[self newWindow:self];
}
- (IBAction)newWindow:(id)sender {
        // create window controller
	DemoWindowController *newWindowController = [[DemoWindowController alloc] initWithWindowNibName:@"DemoWindow"];
        // load window (as we need the nib file to be loaded before we can proceed
    [newWindowController loadWindow];
        // add the default tabs
	[newWindowController addDefaultTabs];
        // finally show the window
	[newWindowController showWindow:self];    
}

@end
