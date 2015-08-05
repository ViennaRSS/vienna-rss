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
#import "BJRWindowWithToolbar.h"

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

	// Localise the strings
	[exportAll setTitle:NSLocalizedString(@"Export all subscriptions", nil)];
	[exportSelected setTitle:NSLocalizedString(@"Export selected subscriptions", nil)];
	[exportWithGroups setTitle:NSLocalizedString(@"Preserve group folders in exported file", nil)];

	[panel setAccessoryView:exportSaveAccessory];
	[panel setAllowedFileTypes:[NSArray arrayWithObject:@"opml"]];
	[panel beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger returnCode) {
		if (returnCode == NSOKButton)
		{
			[panel orderOut:self];

			NSArray * foldersArray = ([exportSelected state] == NSOnState) ? [foldersTree selectedFolders] : [db arrayOfFolders:MA_Root_Folder];
			int countExported = [self exportToFile:[[panel URL] path] from:foldersArray withGroups:([exportWithGroups state] == NSOnState)];
		
			if (countExported < 0)
			{
				NSBeginCriticalAlertSheet(NSLocalizedString(@"Cannot open export file message", nil),
										  NSLocalizedString(@"OK", nil),
										  nil,
										  nil, [NSApp mainWindow], self,
										  nil, nil, nil,
										  NSLocalizedString(@"Cannot open export file message text", nil));
			}
			else
			{
				// Announce how many we successfully imported
				NSRunAlertPanel(NSLocalizedString(@"RSS Subscription Export Title", nil), NSLocalizedString(@"%d subscriptions successfully exported", nil), NSLocalizedString(@"OK", nil), nil, nil, countExported);
			}
		}
	}];
}

/* exportSubscriptionGroup
 * Export one group of folders.
 */
-(int)exportSubscriptionGroup:(XMLParser *)xmlTree fromArray:(NSArray *)feedArray withGroups:(BOOL)groupFlag
{
	int countExported = 0;

	for (Folder * folder in feedArray)
	{
		NSMutableDictionary * itemDict = [[NSMutableDictionary alloc] init];
		NSString * name = [folder name];
		if (IsGroupFolder(folder))
		{
			NSArray * subFolders = [db arrayOfFolders:[folder itemId]];
			
			if (!groupFlag)
				countExported += [self exportSubscriptionGroup:xmlTree fromArray:subFolders withGroups:groupFlag];
			else
			{
				[itemDict setObject:[NSString stringByInsertingHTMLEntities:(name ? name : @"")] forKey:@"text"];
				XMLParser * subTree = [xmlTree addTree:@"outline" withAttributes:itemDict];
				countExported += [self exportSubscriptionGroup:subTree fromArray:subFolders withGroups:groupFlag];
			}
		}
		else if (IsRSSFolder(folder) || IsGoogleReaderFolder(folder))
		{
			NSString * link = [folder homePage];
			NSString * description = [folder feedDescription];
			NSString * url = [folder feedURL];

			[itemDict setObject:@"rss" forKey:@"type"];
			[itemDict setObject:[NSString stringByInsertingHTMLEntities:(name ? name : @"")] forKey:@"text"];
            [itemDict setObject:[NSString stringByInsertingHTMLEntities:(link ? link : @"")] forKey:@"htmlUrl"];
			[itemDict setObject:[NSString stringByInsertingHTMLEntities:(url ? url : @"")] forKey:@"xmlUrl"];
			[itemDict setObject:[NSString stringByInsertingHTMLEntities:description] forKey:@"description"];
			[xmlTree addClosedTree:@"outline" withAttributes:itemDict];
			++countExported;
		}
		[itemDict autorelease];
	}
	return countExported;
}

/* exportToFile
 * Export a list of RSS subscriptions to the specified file. If onlySelected is set then only those
 * folders selected in the folders tree are exported. Otherwise all RSS folders are exported.
 * Returns the number of subscriptions exported, or -1 on error.
 */
-(int)exportToFile:(NSString *)exportFileName from:(NSArray *)foldersArray withGroups:(BOOL)groupFlag
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
		[newTree release];
		return -1; // Indicate an error condition (impossible number of exports)
	}

	// Put some newlines in for readability
	NSMutableString * xmlString = [[NSMutableString alloc] initWithString:[newTree xmlForTree]];
	[xmlString replaceString:@"><" withString:@">\n<"];
	[xmlString appendString:@"\n"];

    NSData *xmlData = [xmlString dataUsingEncoding:NSUTF8StringEncoding]; // [xmlString writeToFile:atomically:] will write xmlString in other encoding than UTF-8
	[xmlString release];
    [xmlData writeToFile:fqFilename atomically:YES];
	
	// Clean up at the end
	[newTree release];
	return countExported;
}
@end
