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
	IBOutlet NSPopUpButton * openReaderSource; //List of known service providers
	NSDictionary * sourcesDict;
    IBOutlet NSTextField * credentialsInfoText;
	IBOutlet NSTextField * openReaderHost;
	IBOutlet NSTextField * username;
    IBOutlet NSSecureTextField * password;
}

@property (assign) IBOutlet NSButton *syncButton;

-(IBAction)changeSyncGoogleReader:(id)sender;
-(IBAction)changeSource:(id)sender;
-(IBAction)visitWebsite:(id)sender;
@end
