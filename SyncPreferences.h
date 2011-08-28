//
//  SyncPreferences.h
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SyncMerge;

@interface SyncPreferences : NSWindowController <NSTextFieldDelegate, NSWindowDelegate> {
    NSButton * syncButton;
    NSButton * mergeButton;
    NSButton * createButton;
    NSTextField * username;
    NSSecureTextField * password;
    SyncMerge * merge;
    NSModalSession modalSession;
}

@property (assign) IBOutlet NSButton *syncButton;
@property (assign) IBOutlet NSButton *mergeButton;
@property (assign) IBOutlet NSButton *createButton;
@property (assign) IBOutlet NSTextField *username;
@property (assign) IBOutlet NSSecureTextField *password;

-(IBAction)changeSyncGoogleReader:(id)sender;
-(IBAction)mergeSubscriptions:(id)sender;
-(IBAction)createGoogleAccount:(id)sender;

@end
