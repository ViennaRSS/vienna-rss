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
#import "StringExtensions.h"
#import "BJRWindowWithToolbar.h"
#import "Database.h"


@implementation Import

/* importFromFile
 * Import a list of RSS subscriptions.
 */
+ (void)importFromFile:(NSString *)importFileName
{
    NSData * data = [NSData dataWithContentsOfFile:[importFileName stringByExpandingTildeInPath]];
    BOOL hasError = NO;
    int countImported = 0;
    
    if (data != nil)
    {
        NSError *error = nil;
        NSXMLDocument *opmlDocument = [[NSXMLDocument alloc] initWithData:data
                                                                  options:NSXMLNodeOptionsNone
                                                                    error:&error];
        if (error)
        {
            NSRunAlertPanel(NSLocalizedString(@"Error importing subscriptions title", nil),
                            NSLocalizedString(@"Error importing subscriptions body", nil),
                            NSLocalizedString(@"OK", nil), nil, nil);
            hasError = YES;
        }
        else
        {
            NSArray *outlines = [opmlDocument nodesForXPath:@"opml/body/outline" error:nil];
            
            countImported = [self importSubscriptionGroup:outlines underParent:MA_Root_Folder];
        }
    }
    
    // Announce how many we successfully imported
    if (!hasError)
    {
        NSRunAlertPanel(NSLocalizedString(@"RSS Subscription Import Title", nil), NSLocalizedString(@"%d subscriptions successfully imported", nil), NSLocalizedString(@"OK", nil), nil, nil, countImported);
    }
}


/* importSubscriptionGroup
 * Import one group of an OPML subscription tree.
 */
+ (int)importSubscriptionGroup:(NSArray *)outlines underParent:(int)parentId
{
	int countImported = 0;
	
	for (NSXMLElement *outlineElement in outlines)
	{
        NSString *feedText = [[[outlineElement attributeForName:@"text"]
                                stringValue] stringByEscapingExtendedCharacters];
        NSString *feedDescription = [[[outlineElement attributeForName:@"description"]
                                stringValue] stringByEscapingExtendedCharacters];
        NSString *feedURL = [[[outlineElement attributeForName:@"xmlUrl"]
                              stringValue] stringByEscapingExtendedCharacters];
        NSString *feedHomePage = [[[outlineElement attributeForName:@"htmlUrl"]
                              stringValue] stringByEscapingExtendedCharacters];
        
        Database * dbManager = [Database sharedManager];

		// Some OPML exports use 'title' instead of 'text'.
		if (feedText == nil || [feedText length] == 0u)
		{
            NSString * feedTitle = [[[outlineElement attributeForName:@"title"]
                                     stringValue] stringByEscapingExtendedCharacters];
            if (feedTitle != nil) {
				feedText = feedTitle;
            }
		}

		// Do double-decoding of the title to get around a bug in some commercial newsreaders
		// where they double-encode characters
		feedText = [feedText stringByUnescapingExtendedCharacters];
		
		if (feedURL == nil)
		{
			// This is a new group so try to create it. If there's an error then default to adding
			// the sub-group items under the parent.
			if (feedText != nil)
			{
				int folderId = [dbManager addFolder:parentId afterChild:-1
                                         folderName:feedText type:MA_Group_Folder
                                     canAppendIndex:NO];
                if (folderId == -1) {
					folderId = MA_Root_Folder;
                }
				countImported += [self importSubscriptionGroup:outlineElement.children underParent:folderId];
			}
		}
		else if (feedText != nil)
		{
			Folder * folder;
			int folderId;

			if ((folder = [dbManager folderFromFeedURL:feedURL]) != nil)
				folderId = [folder itemId];
			else
			{
				folderId = [dbManager addRSSFolder:feedText underParent:parentId afterChild:-1 subscriptionURL:feedURL];
				++countImported;
			}
            if (feedDescription != nil) {
                [dbManager setDescription:feedDescription forFolder:folderId];
            }
            if (feedHomePage != nil) {
                [dbManager setHomePage:feedHomePage forFolder:folderId];
            }
		}
	}
	return countImported;
}
@end
