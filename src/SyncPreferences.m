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

@implementation SyncPreferences

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
}

- (IBAction)visitWebsite:(id)sender
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/", [openReaderHost stringValue]]];
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
				for (NSString * key in sourcesDict)
				{
					[openReaderSource addItemWithTitle:NSLocalizedString(key, nil)];
				}
				[openReaderSource setEnabled:YES];
				[openReaderSource selectItemWithTitle:NSLocalizedString(@"Other", nil)];
				[self changeSource:nil];
			}
		}
		else
			[openReaderSource setEnabled:NO];
	}
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{    
}

-(void)dealloc
{
    [syncButton release];
    [sourcesDict release];
    [super dealloc];

}

@end
