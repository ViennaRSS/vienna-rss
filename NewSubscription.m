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
#import "AppController.h"
#import "StringExtensions.h"

// Private functions
@interface NewSubscription (Private)
	-(void)loadRSSFeedBundle;
	-(void)setLinkTitle;
	-(void)enableSaveButton;
	-(void)enableSubscribeButton;
@end

@implementation NewSubscription

/* initWithDatabase
 * Just init the RSS feed class.
 */
-(id)initWithDatabase:(Database *)newDb
{
	if ((self = [super init]) != nil)
	{
		db = newDb;
		sourcesDict = nil;
		editFolderId = -1;
		parentId = MA_Root_Folder;
	}
	return self;
}

/* newSubscription
 * Display the sheet to create a new RSS subscription.
 */
-(void)newSubscription:(NSWindow *)window underParent:(int)itemId initialURL:(NSString *)initialURL
{
	[self loadRSSFeedBundle];

	// Load a list of sources from the RSSSources property list. The list of sources
	// is a dictionary of templates which specify how to create the source URL and a
	// display name which acts as the key. This allows us to support additional sources
	// without having to write new code.
	if (!sourcesDict)
	{
		NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
		NSString * pathToPList = [thisBundle pathForResource:@"RSSSources.plist" ofType:@""];
		if (pathToPList != nil)
		{
			sourcesDict = [[NSDictionary dictionaryWithContentsOfFile:pathToPList] retain];
			[feedSource removeAllItems];
			if (sourcesDict)
			{
				NSEnumerator *enumerator = [sourcesDict keyEnumerator];
				NSString * key;

				while ((key = [enumerator nextObject]) != nil)
					[feedSource addItemWithTitle:key];
				[feedSource setEnabled:YES];
				[feedSource selectItemWithTitle:@"URL"];
			}
		}
	}
	if (!sourcesDict)
		[feedSource setEnabled:NO];

	// Look on the pasteboard to see if there's an http:// url and, if so, prime the
	// URL field with it. A handy shortcut.
	if (initialURL != nil)
	{
		[feedURL setStringValue:initialURL];
		[feedSource selectItemWithTitle:@"URL"];
	}
	else
	{
		NSData * pboardData = [[NSPasteboard generalPasteboard] dataForType:NSStringPboardType];
		[feedURL setStringValue:@""];
		if (pboardData != nil)
		{
			NSString * pasteString = [NSString stringWithCString:[pboardData bytes] length:[pboardData length]];
			if (pasteString != nil && ([[pasteString lowercaseString] hasPrefix:@"http://"] || [[pasteString lowercaseString] hasPrefix:@"feed://"]))
			{
				[feedURL setStringValue:pasteString];
				[feedURL selectText:self];
				[feedSource selectItemWithTitle:@"URL"];
			}
		}
	}
	
	// Reset from the last time we used this sheet.
	[self enableSubscribeButton];
	[self setLinkTitle];
	editFolderId = -1;
	parentId = itemId;
	[NSApp beginSheet:newRSSFeedWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

/* editSubscription
 * Edit an existing RSS subscription.
 */
-(void)editSubscription:(NSWindow *)window folderId:(int)folderId
{
	[self loadRSSFeedBundle];

	Folder * folder = [db folderFromID:folderId];
	if (folder != nil)
	{
		[editFeedURL setStringValue:[folder feedURL]];
		[self enableSaveButton];
		editFolderId = folderId;
		[NSApp beginSheet:editRSSFeedWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
	}
}

/* loadRSSFeedBundle
 * Load the RSS feed bundle if not already.
 */
-(void)loadRSSFeedBundle
{
	if (!editRSSFeedWindow || !newRSSFeedWindow)
	{
		[NSBundle loadNibNamed:@"RSSFeed" owner:self];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:feedURL];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange2:) name:NSControlTextDidChangeNotification object:editFeedURL];
	}
}

/* doSubscribe
 * Handle the URL subscription button.
 */
-(IBAction)doSubscribe:(id)sender
{
	NSString * feedURLString = [[feedURL stringValue] trim];

	// Format the URL based on the selected feed source.
	if (sourcesDict != nil)
	{
		NSMenuItem * feedSourceItem = [feedSource selectedItem];
		NSString * key = [feedSourceItem title];
		NSDictionary * itemDict = [sourcesDict valueForKey:key];
		NSString * linkName = [itemDict valueForKey:@"LinkTemplate"];
		if (linkName != nil)
			feedURLString = [NSString stringWithFormat:linkName, feedURLString];
	}

	// Replace feed:// with http:// if necessary
	if ([feedURLString hasPrefix:@"feed://"])
		feedURLString = [NSString stringWithFormat:@"http://%@", [feedURLString substringFromIndex:7]];

	// Create the RSS folder in the database
	if ([db folderFromFeedURL:feedURLString] != nil)
	{
		NSRunAlertPanel(NSLocalizedString(@"Already subscribed title", nil),
						NSLocalizedString(@"Already subscribed body", nil),
						NSLocalizedString(@"OK", nil), nil, nil);
		return;
	}

	// Create then select the new folder.
	int folderId = [db addRSSFolder:[db untitledFeedFolderName] underParent:parentId subscriptionURL:feedURLString];
	[[NSApp delegate] selectFolderAndMessage:folderId messageNumber:MA_Select_Unread];

	// Close the window
	[NSApp endSheet:newRSSFeedWindow];
	[newRSSFeedWindow orderOut:self];
}

/* doSave
 * Save changes to the RSS feed information.
 */
-(IBAction)doSave:(id)sender
{
	NSString * feedURLString = [[editFeedURL stringValue] trim];

	// Save the new information to the database
	[db setFolderFeedURL:editFolderId newFeedURL:feedURLString];
	
	// Close the window
	[NSApp endSheet:editRSSFeedWindow];
	[editRSSFeedWindow orderOut:self];
}

/* doSubscribeCancel
 * Handle the Cancel button.
 */
-(IBAction)doSubscribeCancel:(id)sender
{
	[NSApp endSheet:newRSSFeedWindow];
	[newRSSFeedWindow orderOut:self];
}

/* doEditCancel
 * Handle the Cancel button.
 */
-(IBAction)doEditCancel:(id)sender
{
	[NSApp endSheet:editRSSFeedWindow];
	[editRSSFeedWindow orderOut:self];
}

/* doLinkSourceChanged
 * Called when the user changes the selection in the popup menu.
 */
-(IBAction)doLinkSourceChanged:(id)sender
{
	[self setLinkTitle];
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Subscribe button if the input fields are empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
	[self enableSubscribeButton];
}

/* handleTextDidChange2 [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Save button if the input fields are empty or enable it otherwise.
 */
-(void)handleTextDidChange2:(NSNotification *)aNotification
{
	[self enableSaveButton];
}

/* setLinkTitle
 * Set the text of the label that prompts for the link based on the source
 * that the user selected from the popup menu.
 */
-(void)setLinkTitle
{
	NSMenuItem * feedSourceItem = [feedSource selectedItem];
	NSString * linkTitleString = nil;
	bool showButton = NO;
	if (feedSourceItem != nil)
	{
		NSDictionary * itemDict = [sourcesDict valueForKey:[feedSourceItem title]];
		if (itemDict != nil)
		{
			linkTitleString = [itemDict valueForKey:@"LinkName"];
			showButton = [itemDict valueForKey:@"SiteHomePage"] != nil;
		}
	}
	if (linkTitleString == nil)
		linkTitleString = @"Link";
	[linkTitle setStringValue:[NSString stringWithFormat:@"%@:", linkTitleString]];
	[siteHomePageButton setHidden:!showButton];
}

/* doShowSiteHomePage
 */
-(void)doShowSiteHomePage:(id)sender
{
	NSMenuItem * feedSourceItem = [feedSource selectedItem];
	if (feedSourceItem != nil)
	{
		NSDictionary * itemDict = [sourcesDict valueForKey:[feedSourceItem title]];
		if (itemDict != nil)
		{
			NSString * siteHomePageURL = [itemDict valueForKey:@"SiteHomePage"];
			NSURL * url = [[NSURL alloc] initWithString:siteHomePageURL];
			[[NSWorkspace sharedWorkspace] openURL:url];
			[url release];
		}
	}
}

/* enableSubscribeButton
 * Enable or disable the Subscribe button depending on whether or not there is a non-blank
 * string in the input fields.
 */
-(void)enableSubscribeButton
{
	NSString * feedURLString = [feedURL stringValue];
	[subscribeButton setEnabled:![feedURLString isBlank]];
}

/* enableSaveButton
 * Enable or disable the Save button depending on whether or not there is a non-blank
 * string in the input fields.
 */
-(void)enableSaveButton
{
	NSString * feedURLString = [editFeedURL stringValue];
	[saveButton setEnabled:![feedURLString isBlank]];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[sourcesDict release];
	[db release];
	[super dealloc];
}
@end
