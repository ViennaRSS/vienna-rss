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
#import "AGKeyChain.h"
#import "SyncMerge.h"

@implementation SyncPreferences

@synthesize syncButton, mergeButton, createButton;
@synthesize username;
@synthesize password;

-(id)init 
{
    return [super initWithWindowNibName:@"SyncPreferences"];
}

-(id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        merge = [[SyncMerge alloc] init];
        [merge retain];
    }
    
    return self;
}

-(void)savePassword:(NSString *)pass forUser:(NSString *)user 
{
    if (![AGKeychain checkForExistanceOfKeychainItem:@"Vienna: GoogleReaderSync" withItemKind:@"application password" forUsername:user]) 
        [AGKeychain addKeychainItem:@"Vienna: GoogleReaderSync" withItemKind:@"application password" forUsername:user withPassword:pass];
    else 
        [AGKeychain modifyKeychainItem:@"Vienna: GoogleReaderSync" withItemKind:@"application password" forUsername:user withNewPassword:pass];
}

-(void)windowWillClose:(NSNotification *)notification 
{
    Preferences *prefs = [Preferences standardPreferences];
    [prefs setSyncGoogleReader:([syncButton state] == NSOnState)];
    [prefs setGoogleUsername:[username stringValue]];
    [prefs savePreferences];
    
    [self savePassword:password.stringValue forUser:username.stringValue];
}

-(BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor 
{
    Preferences *prefs = [Preferences standardPreferences];
    NSString *val = [fieldEditor string];
    
    if (control.tag == 0) // Username
    { 
        [prefs setGoogleUsername:val];
        if ([[password stringValue] length] > 0)
            [self savePassword:[password stringValue] forUser:val];
    } 
    else if (control.tag == 1 && [[username stringValue] length] > 0) // Password
        [self savePassword:val forUser:[username stringValue]];
    
    return YES;
}

-(IBAction)changeSyncGoogleReader:(id)sender 
{
    BOOL sync = [sender state] == NSOnState;
	[[Preferences standardPreferences] setSyncGoogleReader:sync];
}

-(IBAction)mergeSubscriptions:(id)sender 
{
    modalSession = [[NSApplication sharedApplication] beginModalSessionForWindow:[merge window]];
    [merge setSession:modalSession];
    [merge beginMerge];
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
    [username setStringValue:[prefs googleUsername]];
    
    NSString *pass = [AGKeychain getPasswordFromKeychainItem:@"Vienna: GoogleReaderSync" withItemKind:@"application password" forUsername:[prefs googleUsername]];
    if ([pass length] > 0)
        [password setStringValue:pass];
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{    
    if ([merge running]) 
    {
        [merge close];
        [[NSApplication sharedApplication] endModalSession:modalSession];

        /*NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Google Authentication Failed"];
        [alert setInformativeText:@"Please check your Google username and password in Vienna's preferences."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];*/
    }
}

-(void)dealloc
{
    [syncButton release];
    [mergeButton release];
    [createButton release];
    [username release];
    [password release];
    [merge release];

}

@end
