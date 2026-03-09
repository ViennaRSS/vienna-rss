//
//  NewSubscription.m
//  Vienna
//
//  Created by Steve on 4/23/05.
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

#import "NewSubscription.h"
#import "StringExtensions.h"
#import "Folder.h"
#import "Database.h"

@interface NewSubscription ()

-(void)loadRSSFeedBundle;
-(void)enableSaveButton;

@end

@implementation NewSubscription {
    IBOutlet NSTextField *editFeedURL;
    IBOutlet NSButton *saveButton;
    IBOutlet NSButton *editCancelButton;
    IBOutlet NSWindow *editRSSFeedWindow;
    Database *db;
    NSInteger editFolderId;
}

/* initWithDatabase
 * Just init the RSS feed class.
 */
-(instancetype)initWithDatabase:(Database *)newDb
{
	if ((self = [super init]) != nil) {
		db = newDb;
		editFolderId = -1;
	}
	return self;
}

/* editSubscription
 * Edit an existing RSS subscription.
 */
-(void)editSubscription:(NSWindow *)window folderId:(NSInteger)folderId
{
	[self loadRSSFeedBundle];

	Folder * folder = [db folderFromID:folderId];
	if (folder != nil) {
		editFeedURL.stringValue = folder.feedURL;
		[self enableSaveButton];
		editFolderId = folderId;
		
		// Open the edit sheet.
        [window beginSheet:editRSSFeedWindow completionHandler:nil];
	}
}

/* loadRSSFeedBundle
 * Load the RSS feed bundle if not already.
 */
-(void)loadRSSFeedBundle
{
	if (!editRSSFeedWindow) {
		NSArray * objects;
		[[NSBundle bundleForClass:[self class]] loadNibNamed:@"RSSFeed" owner:self topLevelObjects:&objects];
		self.topObjects = objects;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange2:) name:NSControlTextDidChangeNotification object:editFeedURL];
	}
}

/* doSave
 * Save changes to the RSS feed information.
 */
-(IBAction)doSave:(id)sender
{
	NSString * feedURLString = editFeedURL.stringValue.vna_trimmed;

	// Save the new information to the database
    [[Database sharedManager] setFeedURL:feedURLString forFolder:editFolderId];
	
	// Close the window
	[editRSSFeedWindow.sheetParent endSheet:editRSSFeedWindow];
	[editRSSFeedWindow orderOut:self];
}

/* doEditCancel
 * Handle the Cancel button.
 */
-(IBAction)doEditCancel:(id)sender
{
	[editRSSFeedWindow.sheetParent endSheet:editRSSFeedWindow];
	[editRSSFeedWindow orderOut:self];
}

/* handleTextDidChange2 [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Save button if the input fields are empty or enable it otherwise.
 */
-(void)handleTextDidChange2:(NSNotification *)aNotification
{
	[self enableSaveButton];
}

/* enableSaveButton
 * Enable or disable the Save button depending on whether or not there is a non-blank
 * string in the input fields.
 */
-(void)enableSaveButton
{
	NSString * feedURLString = editFeedURL.stringValue;
	saveButton.enabled = !feedURLString.vna_isBlank;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
