//
//  FeedCredentials.m
//  Vienna
//
//  Created by Steve on 6/24/05.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
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

#import "FeedCredentials.h"

#import "Constants.h"
#import "Database.h"
#import "DisclosureView.h"
#import "Folder.h"
#import "Preferences.h"
#import "StringExtensions.h"

NSString * const MAPref_ShowDetailsOnFeedCredentialsDialog = @"ShowDetailsOnFeedCredentialsDialog";

static NSNibName const VNAFeedCredentialsNibName = @"FeedCredentials";
static NSUserInterfaceItemIdentifier const VNADisclosureButtonIdentifier = @"DisclosureButton";

@interface FeedCredentials ()

// MARK: Outlets

@property (weak, nonatomic) IBOutlet NSWindow *credentialsWindow;
@property (weak, nonatomic) IBOutlet NSTextField *messageTextField;
@property (weak, nonatomic) IBOutlet NSTextField *userNameTextField;
@property (weak, nonatomic) IBOutlet NSSecureTextField *passwordTextField;
@property (weak, nonatomic) IBOutlet DisclosureView *disclosureView;
@property (weak, nonatomic) IBOutlet NSTextField *feedTextField;
@property (weak, nonatomic) IBOutlet NSTextField *feedURLTextField;
@property (weak, nonatomic) IBOutlet NSButton *okButton;

// MARK: Storage

@property NSArray *topObjects;
@property Folder *folder;

@end

@implementation FeedCredentials

// MARK: Initialization

- (void)requestCredentialsInWindow:(NSWindow *)window forFolder:(Folder *)folder
{
    if (!self.credentialsWindow) {
        NSArray *objects;
        [NSBundle.mainBundle loadNibNamed:VNAFeedCredentialsNibName
                                    owner:self
                          topLevelObjects:&objects];
        self.topObjects = objects;
        self.userNameTextField.delegate = self;
    }

    // Retain the folder as we need it to update the
    // username and/or password.
    self.folder = folder;

    // Show the feed URL in the prompt so the user knows which site credentials
    // are being requested. (We don't use [folder name] here as that is likely
    // to be "Untitled Folder" mostly).
    NSURL *secureURL = [NSURL URLWithString:self.folder.feedURL];
    NSString *prompt =
        [NSString stringWithFormat:NSLocalizedString(
                                       @"The subscription for \"%@\" requires "
                                       @"a user name and password for access.",
                                       nil),
                                   secureURL.host];
    self.messageTextField.stringValue = prompt;

    // Fill out any existing values.
    self.userNameTextField.stringValue = self.folder.username;
    self.passwordTextField.stringValue = self.folder.password;

    // Fill out feed details.
    self.feedTextField.stringValue = self.folder.name;
    self.feedURLTextField.stringValue = self.folder.feedURL;

    // Show or hide the details view.
    Preferences *preferences = Preferences.standardPreferences;
    BOOL showDetails = [preferences boolForKey:MAPref_ShowDetailsOnFeedCredentialsDialog];
    if (showDetails) {
        [self.disclosureView disclose:NO];
    } else {
        [self.disclosureView collapse:NO];
    }

    // Set the focus
    [self.credentialsWindow makeFirstResponder:self.folder.username.vna_isBlank ? self.userNameTextField
                                                                                : self.passwordTextField];

    self.okButton.enabled = !self.userNameTextField.stringValue.vna_isBlank;
    [window beginSheet:self.credentialsWindow completionHandler:nil];
}

// MARK: Actions

- (IBAction)toggleDisclosure:(NSButton *)sender
{
    if (![sender.identifier isEqualToString:VNADisclosureButtonIdentifier]) {
        return;
    }

    BOOL shouldShowDetails = sender.state == NSControlStateValueOn;
    if (shouldShowDetails) {
        [self.disclosureView disclose:YES];
    } else {
        [self.disclosureView collapse:YES];
    }
}

- (IBAction)updateCredentials:(id)sender
{
    NSString *usernameString = self.userNameTextField.stringValue.vna_trimmed;
    NSString *passwordString = self.passwordTextField.stringValue;

    Database *database = Database.sharedManager;
    [database setFolderUsername:self.folder.itemId newUsername:usernameString];
    self.folder.password = passwordString;

    [self.credentialsWindow.sheetParent endSheet:self.credentialsWindow];
    [self.credentialsWindow orderOut:self];

    [NSNotificationCenter.defaultCenter postNotificationName:MA_Notify_GotAuthenticationForFolder
                                                      object:self.folder];
}

- (IBAction)cancel:(id)sender
{
    [self.credentialsWindow.sheetParent endSheet:self.credentialsWindow];
    [self.credentialsWindow orderOut:self];

    [NSNotificationCenter.defaultCenter postNotificationName:MA_Notify_CancelAuthenticationForFolder
                                                      object:self.folder];
}

// MARK: - NSTextFieldDelegate

// This function is called when the contents of the input field is changed. We
// disable the Subscribe button if the input fields are empty or enable it
// otherwise.
- (void)controlTextDidChange:(NSNotification *)obj
{
    self.okButton.enabled = !self.userNameTextField.stringValue.vna_isBlank;
}

@end
