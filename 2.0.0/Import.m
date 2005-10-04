//
//  Import.m
//  Vienna
//
//  Created by Steve on 5/27/05.
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

#import "Import.h"
#import "XMLParser.h"
#import "ViennaApp.h"

@implementation AppController (Import)

/* importSubscriptions
 * Import an OPML file which lists RSS feeds.
 */
-(IBAction)importSubscriptions:(id)sender
{
	NSOpenPanel * panel = [NSOpenPanel openPanel];
	[panel beginSheetForDirectory:nil
							 file:nil
							types:nil
				   modalForWindow:mainWindow
					modalDelegate:self
				   didEndSelector:@selector(importOpenPanelDidEnd:returnCode:contextInfo:)
					  contextInfo:nil];
}

/* importOpenPanelDidEnd
 * Called when the user completes the Import open panel
 */
-(void)importOpenPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[panel orderOut:self];
		[self importFromFile:[panel filename]];
	}
}

/* importSubscriptionGroup
 * Import one group of an OPML subscription tree.
 */
-(int)importSubscriptionGroup:(XMLParser *)tree underParent:(int)parentId
{
	int countImported = 0;
	int count = [tree countOfChildren];
	int index;
	
	for (index = 0; index < count; ++index)
	{
		XMLParser * outlineItem = [tree treeByIndex:index];
		NSDictionary * entry = [outlineItem attributesForTree];
		NSString * feedTitle = [XMLParser processAttributes:[entry objectForKey:@"title"]];
		NSString * feedDescription = [XMLParser processAttributes:[entry objectForKey:@"description"]];
		NSString * feedURL = [XMLParser processAttributes:[entry objectForKey:@"xmlUrl"]];
		NSString * feedHomePage = [XMLParser processAttributes:[entry objectForKey:@"htmlUrl"]];
		NSString * bloglinesSubId = [entry objectForKey:@"BloglinesSubId"];
		int bloglinesId = bloglinesSubId ? [bloglinesSubId intValue] : MA_NonBloglines_Folder;

		// Some OPML exports use 'text' instead of 'title'.
		if (feedTitle == nil)
			feedTitle = [XMLParser processAttributes:[entry objectForKey:@"text"]];

		// Do double-decoding of the title to get around a bug in some commercial newsreaders
		// where they double-encode characters
		feedTitle = [XMLParser processAttributes:feedTitle];
		
		if (feedURL == nil)
		{
			// This is a new group so try to create it. If there's an error then default to adding
			// the sub-group items under the parent.
			if (feedTitle != nil)
			{
				int folderId = [db addFolder:parentId folderName:feedTitle type:MA_Group_Folder canAppendIndex:NO];
				if (folderId == -1)
					folderId = MA_Root_Folder;
				countImported += [self importSubscriptionGroup:outlineItem underParent:folderId];
			}
		}
		else if (feedTitle != nil)
		{
			Folder * folder;
			int folderId;

			if ((folder = [db folderFromFeedURL:feedURL]) != nil)
				folderId = [folder itemId];
			else
			{
				folderId = [db addRSSFolder:feedTitle underParent:parentId subscriptionURL:feedURL];
				++countImported;
			}
			[db setBloglinesId:folderId newBloglinesId:bloglinesId];
			if (feedDescription != nil)
				[db setFolderDescription:folderId newDescription:feedDescription];
			if (feedHomePage != nil)
				[db setFolderHomePage:folderId newHomePage:feedHomePage];
		}
	}
	return countImported;
}

/* importFromFile
 * Import a list of RSS subscriptions.
 */
-(void)importFromFile:(NSString *)importFileName
{
	NSData * data = [NSData dataWithContentsOfFile:[importFileName stringByExpandingTildeInPath]];
	BOOL hasError = NO;
	int countImported = 0;

	if (data != nil)
	{
		XMLParser * tree = [[XMLParser alloc] init];
		if (![tree setData:data])
		{
			NSRunAlertPanel(NSLocalizedString(@"Error importing subscriptions title", nil),
							NSLocalizedString(@"Error importing subscriptions body", nil),
							NSLocalizedString(@"OK", nil), nil, nil);
			hasError = YES;
		}
		else
		{
			XMLParser * bodyTree = [tree treeByPath:@"opml/body"];
			countImported = [self importSubscriptionGroup:bodyTree underParent:MA_Root_Folder];
		}
		[tree release];
	}

	// Announce how many we successfully imported
	if (!hasError)
	{
		NSString * successString = [NSString stringWithFormat:NSLocalizedString(@"%d subscriptions successfully imported", nil), countImported];
		NSRunAlertPanel(NSLocalizedString(@"RSS Subscription Import Title", nil), successString, NSLocalizedString(@"OK", nil), nil, nil);
	}
}
@end
