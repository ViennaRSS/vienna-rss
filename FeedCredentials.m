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
#import "Credentials.h"
#import "StringExtensions.h"

// Private functions
@interface FeedCredentials (Private)
	-(void)enableOKButton;
@end

@implementation FeedCredentials

/* initWithDatabase
 * Initialise an instance of ourselves with the specified database
 */
-(id)initWithDatabase:(Database *)newDb
{
	if ((self = [super init]) != nil)
	{
		folder = nil;
		db = newDb;
	}
	return self;
}

/* credentialsForFolder
 * Obtains the credentials for the specified folder.
 */
-(void)credentialsForFolder:(NSWindow *)window folder:(Folder *)aFolder
{
	if (credentialsWindow == nil)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:userName];
		[NSBundle loadNibNamed:@"FeedCredentials" owner:self];
	}

	// Retain the folder as we need it to update the
	// username and/or password.
	[aFolder retain];
	[folder release];
	folder = aFolder;

	// Show the feed URL in the prompt so the user knows which site credentials are being
	// requested. (We don't use [folder name] here as that is likely to be "Untitled Folder" mostly).
	NSString * prompt = [NSString stringWithFormat:NSLocalizedString(@"Credentials Prompt", nil), [folder feedURL]];
	[promptString setStringValue:prompt];

	// Fill out any existing values.
	[userName setStringValue:[folder username]];
	if (![[folder username] isBlank])
		[password setStringValue:[Credentials getPasswordFromKeychain:[folder username] url:[folder feedURL]]];

	[self enableOKButton];
	[NSApp beginSheet:credentialsWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

/* doCancelButton
 * Respond to the Cancel button being clicked. Just close the UI.
 */
-(IBAction)doCancelButton:(id)sender
{
	[NSApp endSheet:credentialsWindow];
	[credentialsWindow orderOut:self];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_CancelAuthenticationForFolder" object:folder];
	[folder release];
}

/* doOKButton
 * Respond to the OK button being clicked.
 */
-(IBAction)doOKButton:(id)sender
{
	NSString * usernameString = [[userName stringValue] trim];
	NSString * passwordString = [password stringValue];

	[db setFolderUsername:[folder itemId] newUsername:usernameString];
	[Credentials setPasswordInKeychain:passwordString username:usernameString url:[folder feedURL]];
	
	[NSApp endSheet:credentialsWindow];
	[credentialsWindow orderOut:self];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_GotAuthenticationForFolder" object:folder];
	[folder release];
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Subscribe button if the input fields are empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
	[self enableOKButton];
}

/* enableSaveButton
 * Enable or disable the Save button depending on whether or not there is a non-blank
 * string in the input fields.
 */
-(void)enableOKButton
{
	[okButton setEnabled:![[userName stringValue] isBlank]];
}

/* dealloc
 * Clean up after ourself.
 */
-(void)dealloc
{
	[super dealloc];
}
@end
