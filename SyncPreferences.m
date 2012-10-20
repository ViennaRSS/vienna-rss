//
//  SyncPreferences.m
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SyncPreferences.h"
#import "GoogleReader.h"
#import "Preferences.h"

@implementation SyncPreferences

@synthesize syncButton, createButton;

-(id)init 
{
    return [super initWithWindowNibName:@"SyncPreferences"];
}

-(id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}


-(void)windowWillClose:(NSNotification *)notification 
{
    Preferences *prefs = [Preferences standardPreferences];
    [prefs setSyncGoogleReader:([syncButton state] == NSOnState)];
    [prefs savePreferences];    
}


-(IBAction)changeSyncGoogleReader:(id)sender 
{
    BOOL sync = [sender state] == NSOnState;
	[[Preferences standardPreferences] setSyncGoogleReader:sync];
	if (sync) {
		[[GoogleReader sharedManager] authenticate];
		[[GoogleReader sharedManager] loadSubscriptions:nil];
	}
	else {
    	[[GoogleReader sharedManager] clearAuthentication];
    };
}

- (IBAction)createGoogleAccount:(id)sender 
{
    NSURL * url = [NSURL URLWithString:@"https://www.google.com/accounts/NewAccount"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleGoogleAuthFailed:) name:@"MA_Notify_GoogleAuthFailed" object:nil];
    
    Preferences * prefs = [Preferences standardPreferences];
	[syncButton setState:[prefs syncGoogleReader] ? NSOnState : NSOffState];
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{    
}

-(void)dealloc
{
    [syncButton release];
    [createButton release];
    [super dealloc];

}

@end
