//
//  RenameFolder.m
//  Vienna
//
//  Created by Steve on 2/16/06.
//  Copyright (c) 2004-2006 Steve Palmer. All rights reserved.
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

#import "RenameFolder.h"
#import "StringExtensions.h"
#import "HelperFunctions.h"

// Private functions
@interface RenameFolder (Private)
	-(void)enableSaveButton;
@end

@implementation RenameFolder

/* renameFolder
 * Display the sheet to rename the specified folder.
 */
-(void)renameFolder:(NSWindow *)window folderId:(NSInteger)itemId
{
	if (!renameFolderWindow)
	{
		[NSBundle loadNibNamed:@"RenameFolder" owner:self];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:folderName];
	}

	// Reset from the last time we used this sheet.
	folderId = itemId;
	Folder * folder = [[Database sharedManager] folderFromID:folderId];
	[folderName setStringValue:[folder name]];

	[self enableSaveButton];
	[NSApp beginSheet:renameFolderWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

/* doRename
 * Rename the folder.
 */
-(IBAction)doRename:(id)sender
{
	NSString * newName = [[folderName stringValue] trim];
	Database * db = [Database sharedManager];
	Folder * folder = [db folderFromID:folderId];
	
	if ([[folder name] isEqualToString:newName])
	{
		[renameFolderWindow orderOut:sender];
		[NSApp endSheet:renameFolderWindow returnCode:0];
	}
	else
	{
		if ([db folderFromName:newName] != nil)
			runOKAlertPanel(@"Cannot rename folder", @"A folder with that name already exists");
		else
		{
			[db setFolderName:folderId newName:newName];
			[renameFolderWindow orderOut:sender];
			[NSApp endSheet:renameFolderWindow returnCode:1];
		}
	}
}

/* doCancel
 * Handle the Cancel button.
 */
-(IBAction)doCancel:(id)sender
{
	[NSApp endSheet:renameFolderWindow];
	[renameFolderWindow orderOut:self];
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Save button if the input fields are empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
	[self enableSaveButton];
}

/* enableSaveButton
 * Enable or disable the Save button depending on whether or not there is a non-blank
 * string in the input fields.
 */
-(void)enableSaveButton
{
	NSString * folderNameString = [folderName stringValue];
	[renameButton setEnabled:![folderNameString isBlank]];
}

/* dealloc
 * Clean up after ourselves.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}
@end
