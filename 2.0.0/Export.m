//
//  Export.m
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

#import "Export.h"
#import "FoldersTree.h"
#import "XMLParser.h"
#import "StringExtensions.h"

@implementation AppController (Export)

/* exportSubscriptions
 * Export the list of RSS subscriptions as an OPML file.
 */
-(IBAction)exportSubscriptions:(id)sender
{
	NSSavePanel * panel = [NSSavePanel savePanel];

	// If multiple selections in the folder list, default to selected folders
	// for simplicity.
	if ([foldersTree countOfSelectedFolders] > 1)
	{
		[exportSelected setState:NSOnState];
		[exportAll setState:NSOffState];
	}
	else
	{
		[exportSelected setState:NSOffState];
		[exportAll setState:NSOnState];
	}
	
	[panel setAccessoryView:exportSaveAccessory];
	[panel setAllowedFileTypes:[NSArray arrayWithObject:@"opml"]];
	[panel beginSheetForDirectory:nil
							 file:@""
				   modalForWindow:mainWindow
					modalDelegate:self
				   didEndSelector:@selector(exportSavePanelDidEnd:returnCode:contextInfo:)
					  contextInfo:nil];
}

/* exportSavePanelDidEnd
 * Called when the user completes the Export save panel
 */
-(void)exportSavePanelDidEnd:(NSSavePanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[panel orderOut:self];

		NSArray * foldersArray = ([exportSelected state] == NSOnState) ? [foldersTree selectedFolders] : [db arrayOfFolders:MA_Root_Folder];
		[self exportToFile:[panel filename] from:foldersArray withGroups:([exportWithGroups state] == NSOnState)];
	}
}

/* exportSubscriptionGroup
 * Export one group of folders.
 */
-(int)exportSubscriptionGroup:(XMLParser *)xmlTree fromArray:(NSArray *)feedArray withGroups:(BOOL)groupFlag
{
	NSEnumerator * enumerator = [feedArray objectEnumerator];
	int countExported = 0;
	Folder * folder;

	while ((folder = [enumerator nextObject]) != nil)
	{
		NSMutableDictionary * itemDict = [NSMutableDictionary dictionary];
		NSString * name = [folder name];
		if (IsGroupFolder(folder))
		{
			NSArray * subFolders = [db arrayOfFolders:[folder itemId]];
			
			if (!groupFlag)
				countExported += [self exportSubscriptionGroup:xmlTree fromArray:subFolders withGroups:groupFlag];
			else
			{
				[itemDict setObject:[XMLParser quoteAttributes:(name ? name : @"")] forKey:@"title"];
				[itemDict setObject:[XMLParser quoteAttributes:(name ? name : @"")] forKey:@"text"];
				XMLParser * subTree = [xmlTree addTree:@"outline" withAttributes:itemDict];
				countExported += [self exportSubscriptionGroup:subTree fromArray:subFolders withGroups:groupFlag];
			}
		}
		else if (IsRSSFolder(folder))
		{
			NSString * link = [folder homePage];
			NSString * description = [folder feedDescription];
			NSString * url = [folder feedURL];

			[itemDict setObject:@"rss" forKey:@"type"];
			[itemDict setObject:[XMLParser quoteAttributes:(name ? name : @"")] forKey:@"title"];
			[itemDict setObject:[XMLParser quoteAttributes:(name ? name : @"")] forKey:@"text"];
			[itemDict setObject:[XMLParser quoteAttributes:(link ? link : @"")] forKey:@"htmlUrl"];
			[itemDict setObject:[XMLParser quoteAttributes:(url ? url : @"")] forKey:@"xmlUrl"];
			[itemDict setObject:[XMLParser quoteAttributes:(description ? description : @"")] forKey:@"description"];
			[xmlTree addClosedTree:@"outline" withAttributes:itemDict];
			++countExported;
		}
	}
	return countExported;
}

/* exportToFile
 * Export a list of RSS subscriptions to the specified file. If onlySelected is set then only those
 * folders selected in the folders tree are exported. Otherwise all RSS folders are exported.
 */
-(void)exportToFile:(NSString *)exportFileName from:(NSArray *)foldersArray withGroups:(BOOL)groupFlag
{
	XMLParser * newTree = [[XMLParser alloc] initWithEmptyTree];
	XMLParser * opmlTree = [newTree addTree:@"opml" withAttributes:[NSDictionary dictionaryWithObject:@"1.0" forKey:@"version"]];

	// Create the header section
	XMLParser * headTree = [opmlTree addTree:@"head"];
	if (headTree != nil)
	{
		[headTree addTree:@"title" withElement:@"Vienna Subscriptions"];
		[headTree addTree:@"dateCreated" withElement:[[NSCalendarDate date] description]];
	}
	
	// Create the body section
	XMLParser * bodyTree = [opmlTree addTree:@"body"];
	int countExported = [self exportSubscriptionGroup:bodyTree fromArray:foldersArray withGroups:groupFlag];

	// Now write the complete XML to the file
	NSString * fqFilename = [exportFileName stringByExpandingTildeInPath];
	if (![[NSFileManager defaultManager] createFileAtPath:fqFilename contents:nil attributes:nil])
	{
		NSBeginCriticalAlertSheet(NSLocalizedString(@"Cannot open export file message", nil),
								  NSLocalizedString(@"OK", nil),
								  nil,
								  nil, [NSApp mainWindow], self,
								  nil, nil, nil,
								  NSLocalizedString(@"Cannot open export file message text", nil));
		[newTree release];
		return;
	}

	// Put some newlines in for readability
	NSMutableString * xmlString = [[NSMutableString alloc] initWithString:[newTree xmlForTree]];
	[xmlString replaceString:@"><" withString:@">\n<"];

	[xmlString writeToFile:fqFilename atomically:YES];
	[xmlString release];

	// Announce how many we successfully imported
	NSString * successString = [NSString stringWithFormat:NSLocalizedString(@"%d subscriptions successfully exported", nil), countExported];
	NSRunAlertPanel(NSLocalizedString(@"RSS Subscription Export Title", nil), successString, NSLocalizedString(@"OK", nil), nil, nil);
	
	// Clean up at the end
	[newTree release];
}
@end
