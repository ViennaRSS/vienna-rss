//
//  SyncingPreferencesViewController.m
//  Vienna
//
//  Created by Joshua Pore on 22/11/2014.
//  Copyright (c) 2014 uk.co.opencommunity. All rights reserved.
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

#import "OpenReader.h"
#import "KeyChain.h"
#import "Preferences.h"
#import "StringExtensions.h"
#import "SyncingPreferencesViewController.h"

@interface SyncingPreferencesViewController ()

@end

@implementation SyncingPreferencesViewController
static BOOL _credentialsChanged;

@synthesize syncButton;


- (instancetype)init {
	if ((self = [super initWithNibName:@"SyncingPreferencesView" bundle:nil]) != nil)
	{
        // Set up to be notified if preferences change outside this window
        NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(handleGoogleAuthFailed:) name:@"MA_Notify_GoogleAuthFailed" object:nil];
        [nc addObserver:self selector:@selector(handleServerTextDidChange:) name:NSControlTextDidChangeNotification object:openReaderHost];
        [nc addObserver:self selector:@selector(handleUserTextDidChange:) name:NSControlTextDidChangeNotification object:username];
        [nc addObserver:self selector:@selector(handlePasswordTextDidChange:) name:NSControlTextDidEndEditingNotification object:password];
	}
	return self;
}

- (void)viewWillAppear {
    if([NSViewController instancesRespondToSelector:@selector(viewWillAppear)]) {
        [super viewWillAppear];
    }
    // Do view setup here.
    sourcesDict = nil;
    
    // restore from Preferences and from keychain
    Preferences * prefs = [Preferences standardPreferences];
    syncButton.state = prefs.syncGoogleReader ? NSOnState : NSOffState;
    NSString * theUsername = prefs.syncingUser;
    if (!theUsername)
        theUsername=@"";
    NSString * theHost = prefs.syncServer;
    if (!theHost)
        theHost=@"";
    NSString * thePassword = [KeyChain getGenericPasswordFromKeychain:theUsername serviceName:@"Vienna sync"];
    if (!thePassword)
        thePassword=@"";
    username.stringValue = theUsername;
    openReaderHost.stringValue = theHost;
    password.stringValue = thePassword;
    
    if(!prefs.syncGoogleReader)
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
            sourcesDict = [NSDictionary dictionaryWithContentsOfFile:pathToPList];
            [openReaderSource removeAllItems];
            if (sourcesDict)
            {
                [openReaderSource setEnabled:YES];
                BOOL match = NO;
                for (NSString * key in sourcesDict)
                {
                    [openReaderSource addItemWithTitle:key];
                    NSDictionary * itemDict = [sourcesDict valueForKey:key];
                    if ([theHost isEqualToString:[itemDict valueForKey:@"Address"]])
                    {
                        [openReaderSource selectItemWithTitle:key];
                        [self changeSource:nil];
                        match = YES;
                    }
                }
                if (!match)
                {
                    [openReaderSource selectItemWithTitle:NSLocalizedString(@"Other", nil)];
                    openReaderHost.stringValue = theHost;
                }
            }
        }
        else
            [openReaderSource setEnabled:NO];
    }
    
}



#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier {
    return @"SyncingPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"sync"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Syncing", @"Toolbar item name for the Syncing preference pane");
}

#pragma mark - Vienna Prferences


-(void)windowWillClose:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if(syncButton.state == NSOnState && _credentialsChanged)
    {
        [[OpenReader sharedManager] resetAuthentication];
        [[OpenReader sharedManager] loadSubscriptions];
    }
}


-(IBAction)changeSyncOpenReader:(id)sender
{
    // enable/disable syncing
    BOOL sync = [sender state] == NSOnState;
    Preferences *prefs = [Preferences standardPreferences];
    prefs.syncGoogleReader = sync;
    [prefs savePreferences];
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
        [[OpenReader sharedManager] clearAuthentication];
    };
}

-(IBAction)changeSource:(id)sender;
{
    NSMenuItem * readerItem = openReaderSource.selectedItem;
    NSString * key = readerItem.title;
    NSDictionary * itemDict = [sourcesDict valueForKey:key];
    NSString* hostName = [itemDict valueForKey:@"Address"];
    if (!hostName)
        hostName=@"";
    NSString* hint = [itemDict valueForKey:@"Hint"];
    if (!hint)
        hint=@"";
    openReaderHost.stringValue = hostName;
    credentialsInfoText.stringValue = hint;
    if (sender != nil)	//user action
        [self handleServerTextDidChange:nil];
}

- (IBAction)visitWebsite:(id)sender
{
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/", openReaderHost.stringValue]];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

/* handleServerTextDidChange [delegate]
 * This function is called when the contents of the server field is changed.
 * We use the info to check if the password is already available
 * in a web form
 */
-(void)handleServerTextDidChange:(NSNotification *)aNotification
{
    _credentialsChanged = YES;
    Preferences *prefs = [Preferences standardPreferences];
    if ( !((openReaderHost.stringValue).blank || (username.stringValue).blank) )
    {
        // can we get password via keychain ?
        NSString * thePass = [KeyChain getWebPasswordFromKeychain:username.stringValue url:[NSString stringWithFormat:@"https://%@", openReaderHost.stringValue]];
        if (!thePass.blank)
        {
            password.stringValue = thePass;
            [KeyChain setGenericPasswordInKeychain:password.stringValue username:username.stringValue service:@"Vienna sync"];
        }
    }
    prefs.syncServer = openReaderHost.stringValue;
    [prefs savePreferences];
}

/* handleUserTextDidChange [delegate]
 * This function is called when the contents of the user field is changed.
 * We use the info to check if the password is already available
 * in a web form
 */
-(void)handleUserTextDidChange:(NSNotification *)aNotification
{
    _credentialsChanged = YES;
    Preferences *prefs = [Preferences standardPreferences];
    [KeyChain deleteGenericPasswordInKeychain:prefs.syncingUser service:@"Vienna sync"];
    if ( !((openReaderHost.stringValue).blank || (username.stringValue).blank) )
    {
        // can we get password via keychain ?
        NSString * thePass = [KeyChain getWebPasswordFromKeychain:username.stringValue url:[NSString stringWithFormat:@"https://%@", openReaderHost.stringValue]];
        if (!thePass.blank)
        {
            password.stringValue = thePass;
            [KeyChain setGenericPasswordInKeychain:password.stringValue username:username.stringValue service:@"Vienna sync"];
        }
    }
    prefs.syncingUser = username.stringValue;
    [prefs savePreferences];
}

/* handlePasswordTextDidChange [delegate]
 * This function is called when the contents of the user field is changed.
 * We use the info to check if the password is already available
 * in a web form
 */
-(void)handlePasswordTextDidChange:(NSNotification *)aNotification
{
    _credentialsChanged = YES;
    [KeyChain setGenericPasswordInKeychain:password.stringValue username:username.stringValue service:@"Vienna sync"];
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{    
    if (self.view.window.visible)
    {
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"Open Reader Authentication Failed",nil);
        alert.informativeText = NSLocalizedString(@"Make sure the username and password needed to access the Open Reader server are correctly set in Vienna's preferences.\nAlso check your network access.",nil);
        [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
            [[OpenReader sharedManager] clearAuthentication];
        }];
    }
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    syncButton=nil;
    sourcesDict=nil;
    
}

@end
