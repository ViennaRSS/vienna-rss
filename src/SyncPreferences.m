//
//  SyncPreferences.m
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Updated by Barijaona Ramaholimihaso in July 2013 following Google Reader demise.
//  Copyright 2011-2013 Vienna contributors (see Help/Acknowledgements for list of contributors).
//  All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "SyncPreferences.h"
#import "GoogleReader.h"
#import "Preferences.h"
#import "KeyChain.h"
#import "StringExtensions.h"

@implementation SyncPreferences
static BOOL _credentialsChanged;

@synthesize syncButton;

-(id)init 
{
    return [super initWithWindowNibName:@"SyncPreferences"];
}

-(id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        sourcesDict = nil;
    }
    
    return self;
}


-(void)windowWillClose:(NSNotification *)notification 
{
	// save server and username in Preferences
	// and password as a generic password in current keychain
    Preferences *prefs = [Preferences standardPreferences];
    [prefs setSyncGoogleReader:([syncButton state] == NSOnState)];
    [prefs setSyncServer:[openReaderHost stringValue]];
    [prefs setSyncingUser:[username stringValue]];
    [prefs savePreferences];    
    [KeyChain setGenericPasswordInKeychain:[password stringValue] username:[username stringValue] service:@"Vienna sync"];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if([syncButton state] == NSOnState && _credentialsChanged)
	{
		[[GoogleReader sharedManager] resetAuthentication];
		[[GoogleReader sharedManager] loadSubscriptions:nil];
	}
}


-(IBAction)changeSyncGoogleReader:(id)sender 
{
    // enable/disable syncing
    BOOL sync = [sender state] == NSOnState;
	if (sync) {
		[openReaderSource setEnabled:YES];
		[openReaderHost setEnabled:YES];
		[username setEnabled:YES];
		[password setEnabled:YES];
		_credentialsChanged = YES;
	}
	else {
		[openReaderSource setEnabled:NO];
		[openReaderHost setEnabled:NO];
		[username setEnabled:NO];
		[password setEnabled:NO];
    	[[GoogleReader sharedManager] clearAuthentication];
    };
}

-(IBAction)changeSource:(id)sender;
{
	NSMenuItem * readerItem = [openReaderSource selectedItem];
	NSString * key = [readerItem title];
	NSDictionary * itemDict = [sourcesDict valueForKey:key];
	NSString* hostName = [itemDict valueForKey:@"Address"];
	if (!hostName)
		hostName=@"";
	NSString* hint = [itemDict valueForKey:@"Hint"];
	if (!hint)
		hint=@"";
	[openReaderHost setStringValue:hostName];
	[credentialsInfoText setStringValue:hint];
	if (sender != nil)	//user action
		_credentialsChanged=YES;
}

- (IBAction)visitWebsite:(id)sender
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/", [openReaderHost stringValue]]];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

/* handleUserTextDidChange [delegate]
 * This function is called when the contents of the user field is changed.
 * We use the info to check if the password is already available
 * in a web form
 */
-(void)handleUserTextDidChange:(NSNotification *)aNotification
{
	NSTextField * theField = [aNotification object];
	if (theField == openReaderHost || theField == username)
	{
		if ( !([[openReaderHost stringValue] isBlank] || [[username stringValue] isBlank]) )
		{
			// can we get password via keychain ?
			NSString * thePass = [KeyChain getWebPasswordFromKeychain:[username stringValue] url:[NSString stringWithFormat:@"https://%@", [openReaderHost stringValue]]];
			if (![thePass isBlank])
				[password setStringValue:thePass];
		}
	}
	_credentialsChanged = YES;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleGoogleAuthFailed:) name:@"MA_Notify_GoogleAuthFailed" object:nil];
	[nc addObserver:self selector:@selector(handleUserTextDidChange:) name:NSControlTextDidChangeNotification object:username];
    
    // restore from Preferences and from keychain
    Preferences * prefs = [Preferences standardPreferences];
	[syncButton setState:[prefs syncGoogleReader] ? NSOnState : NSOffState];
	NSString * theUsername = [prefs syncingUser];
	if (!theUsername)
		theUsername=@"";
	NSString * theHost = [prefs syncServer];
	if (!theHost)
		theHost=@"";
	NSString * thePassword = [KeyChain getGenericPasswordFromKeychain:theUsername serviceName:@"Vienna sync"];
	if (!thePassword)
		thePassword=@"";
	[username setStringValue:theUsername];
	[openReaderHost setStringValue:theHost];
	[password setStringValue:thePassword];

	if(![prefs syncGoogleReader])
	{
		[openReaderSource setEnabled:NO];
		[openReaderHost setEnabled:NO];
		[username setEnabled:NO];
		[password setEnabled:NO];
	}
	_credentialsChanged = NO;

	// Load a list of supported servers from the KnownSyncServers property list. The list
	// is a dictionary with display names which act as keys, host names and a help text
	// regarding credentials to enter. This allows us to support additional service
	// providers without having to write new code.
	if (!sourcesDict)
	{
		NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
		NSString * pathToPList = [thisBundle pathForResource:@"KnownSyncServers" ofType:@"plist"];
		if (pathToPList != nil)
		{
			sourcesDict = [[NSDictionary dictionaryWithContentsOfFile:pathToPList] retain];
			[openReaderSource removeAllItems];
			if (sourcesDict)
			{
				[openReaderSource setEnabled:YES];
				BOOL match = NO;
				for (NSString * key in sourcesDict)
				{
					[openReaderSource addItemWithTitle:NSLocalizedString(key, nil)];
					NSDictionary * itemDict = [sourcesDict valueForKey:key];
					if ([theHost isEqualToString:[itemDict valueForKey:@"Address"]])
					{
						[openReaderSource selectItemWithTitle:NSLocalizedString(key, nil)];
						[self changeSource:nil];
						match = YES;
					}
				}
				if (!match)
				{
					[openReaderSource selectItemWithTitle:NSLocalizedString(@"Other", nil)];
					[openReaderHost setStringValue:theHost];
				}
			}
		}
		else
			[openReaderSource setEnabled:NO];
	}
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{    
    if ([[self window] isVisible])
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Open Reader Authentication Failed"];
        [alert setInformativeText:@"Please check username and password you entered for the Open Reader server in Vienna's preferences."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
        [[GoogleReader sharedManager] clearAuthentication];
    }
}

-(void)dealloc
{
    [syncButton release];
    [sourcesDict release];
    [super dealloc];

}

@end
