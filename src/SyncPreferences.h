//
//  SyncPreferences.h
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SyncPreferences : NSWindowController <NSTextFieldDelegate, NSWindowDelegate> {
    NSButton * syncButton;
    NSButton * createButton;
    NSModalSession modalSession;
}

@property (assign) IBOutlet NSButton *syncButton;
@property (assign) IBOutlet NSButton *createButton;

-(IBAction)changeSyncGoogleReader:(id)sender;
-(IBAction)createGoogleAccount:(id)sender;

@end
