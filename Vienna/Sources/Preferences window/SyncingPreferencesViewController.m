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
#import "Keychain.h"
#import "Preferences.h"
#import "StringExtensions.h"
#import "SyncingPreferencesViewController.h"

@interface SyncingPreferencesViewController ()

@end

@implementation SyncingPreferencesViewController
static BOOL _credentialsChanged;

static NSString *syncScheme;
static NSString *serverAndPath;
static NSURL *serverURL;
static NSString *syncingUser;

@synthesize syncButton;

- (void)viewWillAppear {
    // Set up to be notified
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleGoogleAuthFailed:) name:@"MA_Notify_GoogleAuthFailed" object:nil];
    [nc addObserver:self selector:@selector(handleServerTextDidChange:) name:NSControlTextDidChangeNotification object:openReaderHost];
    [nc addObserver:self selector:@selector(handleUserTextDidChange:) name:NSControlTextDidChangeNotification object:username];
    [nc addObserver:self selector:@selector(handlePasswordTextDidChange:) name:NSControlTextDidChangeNotification object:password];

    if([NSViewController instancesRespondToSelector:@selector(viewWillAppear)]) {
        [super viewWillAppear];
    }
    // Do view setup here.
    sourcesDict = nil;
    
    // restore from Preferences and from keychain
    Preferences * prefs = [Preferences standardPreferences];
    syncButton.state = prefs.syncGoogleReader ? NSControlStateValueOn : NSControlStateValueOff;
    syncingUser = prefs.syncingUser;
    if (!syncingUser) {
        syncingUser=@"";
    }
    syncScheme = prefs.syncScheme;
    if (!syncScheme) {
        syncScheme = @"https";
    }
    serverAndPath = prefs.syncServer;
    if (!serverAndPath) {
        serverAndPath=@"";
    }
    serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", syncScheme, serverAndPath]];
    NSString * thePassword = [VNAKeychain getGenericPasswordFromKeychain:syncingUser serviceName:@"Vienna sync"];
    if (!thePassword)
        thePassword=@"";
    username.stringValue = syncingUser;
    openReaderHost.stringValue = serverAndPath;
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
                    if ([serverAndPath isEqualToString:[itemDict valueForKey:@"Address"]])
                    {
                        [openReaderSource selectItemWithTitle:key];
                        [self changeSource:nil];
                        match = YES;
                    }
                }
                if (!match)
                {
                    [openReaderSource selectItemWithTitle:NSLocalizedString(@"Other", nil)];
                    openReaderHost.stringValue = serverURL.absoluteString;
                }
            }
        }
        else
            [openReaderSource setEnabled:NO];
    }
    
}

#pragma mark - Vienna Prferences


-(void)viewWillDisappear
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    Preferences * prefs = [Preferences standardPreferences];
    prefs.syncScheme = syncScheme;
    prefs.syncServer = serverAndPath;
    prefs.syncingUser = syncingUser;
    if(syncButton.state == NSControlStateValueOn && _credentialsChanged)
    {
        [[OpenReader sharedManager] resetAuthentication];
        [[OpenReader sharedManager] loadSubscriptions];
    }
    [super viewWillDisappear];
}


-(IBAction)changeSyncOpenReader:(id)sender
{
    // enable/disable syncing
    BOOL sync = [sender state] == NSControlStateValueOn;
    Preferences *prefs = [Preferences standardPreferences];
    prefs.syncGoogleReader = sync;
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

-(IBAction)changeSource:(id)sender
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
    [[NSWorkspace sharedWorkspace] openURL:serverURL];
}

/* handleServerTextDidChange [delegate]
 * This function is called when the contents of the server field is changed.
 * We use the info to check if the password is already available
 * in a web form
 */
-(void)handleServerTextDidChange:(NSNotification *)aNotification
{
    _credentialsChanged = YES;
    NSString *theString  = openReaderHost.stringValue.vna_trimmed;
    NSURL *url = [NSURL URLWithString:theString];
    if (url.scheme) {
        syncScheme = url.scheme;
        if (url.host) {
            serverAndPath = [theString substringFromIndex:[theString rangeOfString:url.host].location];
        } else {
            serverAndPath = @"";
        }
    } else {
        syncScheme = @"https";
        serverAndPath = theString;
    }
    serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", syncScheme, serverAndPath]];
    if ( !((openReaderHost.stringValue).vna_isBlank || (username.stringValue).vna_isBlank) )
    {
        // can we get password via keychain ?
        NSString * thePass = [VNAKeychain getWebPasswordFromKeychain:username.stringValue url:[NSString stringWithFormat:@"%@://%@", syncScheme, serverURL.host]];
        if (!thePass.vna_isBlank)
        {
            password.stringValue = thePass;
            [VNAKeychain setGenericPasswordInKeychain:thePass username:username.stringValue service:@"Vienna sync"];
        }
    }
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
    [VNAKeychain deleteGenericPasswordInKeychain:prefs.syncingUser service:@"Vienna sync"];
    if ( !((openReaderHost.stringValue).vna_isBlank || (username.stringValue).vna_isBlank) )
    {
        // can we get password via keychain ?
        NSString * thePass = [VNAKeychain getWebPasswordFromKeychain:username.stringValue url:[NSString stringWithFormat:@"%@://%@", syncScheme, serverURL.host]];
        if (!thePass.vna_isBlank)
        {
            password.stringValue = thePass;
            [VNAKeychain setGenericPasswordInKeychain:password.stringValue username:username.stringValue service:@"Vienna sync"];
        }
    }
    syncingUser = username.stringValue;
}

/* handlePasswordTextDidChange [delegate]
 * This function is called when the contents of the user field is changed.
 * We use the info to check if the password is already available
 * in a web form
 */
-(void)handlePasswordTextDidChange:(NSNotification *)aNotification
{
    _credentialsChanged = YES;
    [VNAKeychain setGenericPasswordInKeychain:password.stringValue username:username.stringValue service:@"Vienna sync"];
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{    
    if (self.view.window.visible)
    {
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"Open Reader Authentication Failed",nil);
        if (![nc.object isEqualToString:@""]) {
            alert.informativeText = nc.object;
        } else {
            alert.informativeText = NSLocalizedString(@"Make sure the username and password needed to access the Open Reader server are correctly set in Vienna's preferences. Also check your network access.",nil);
        }
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
