//
//  NewGroupFolder.m
//  Vienna
//
//  Created by Steve on 6/4/05.
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

#import "NewGroupFolder.h"
#import "StringExtensions.h"
#import "AppController.h"
#import "Folder.h"
#import "Database.h"

@interface NewGroupFolder ()

-(void)enableSaveButton;

@end

@implementation NewGroupFolder {
    IBOutlet NSWindow *newGroupFolderWindow;
    IBOutlet NSTextField *folderName;
    IBOutlet NSButton *saveButton;
    IBOutlet NSButton *cancelButton;
    NSInteger parentId;
}

/* newGroupFolder
 * Display the sheet to create a new group folder.
 */
-(void)newGroupFolder:(NSWindow *)window underParent:(NSInteger)itemId
{
	if (!newGroupFolderWindow) {
		NSArray * objects;
		[[NSBundle bundleForClass:[self class]] loadNibNamed:@"GroupFolder" owner:self topLevelObjects:&objects];
		self.topObjects = objects;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:folderName];
	}

	// Reset from the last time we used this sheet.
	parentId = itemId;
	folderName.stringValue = @"";
	[self enableSaveButton];
    [window beginSheet:newGroupFolderWindow completionHandler:nil];
}

/* doSave
 * Create the new folder.
 */
-(IBAction)doSave:(id)sender
{
	NSString * folderNameString = folderName.stringValue.vna_trimmed;
	
	// Create the new folder in the database
	NSInteger newFolderId = [[Database sharedManager] addFolder:parentId
													 afterChild:-1
													 folderName:folderNameString
														   type:VNAFolderTypeGroup
												 canAppendIndex:NO];

	// Close the window
	[newGroupFolderWindow.sheetParent endSheet:newGroupFolderWindow];
	[newGroupFolderWindow orderOut:self];
	
	if (newFolderId != -1) {
		[APPCONTROLLER selectFolder:newFolderId];
	}
}

/* doCancel
 * Handle the Cancel button.
 */
-(IBAction)doCancel:(id)sender
{
	[newGroupFolderWindow.sheetParent endSheet:newGroupFolderWindow];
	[newGroupFolderWindow orderOut:self];
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
	NSString * folderNameString = folderName.stringValue;
	saveButton.enabled = !folderNameString.vna_isBlank;
}

/* dealloc
 * Clean up after ourselves.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
