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
#import "StringExtensions.h"
#import "BJRWindowWithToolbar.h"
#import "Database.h"

@interface Export()
+ (NSXMLDocument *)opmlDocumentFromFolders:(NSArray *)folders withGroups:(BOOL)groupFlag exportCount:(int *)countExported;
@end

@implementation Export

/* exportSubscriptionGroup
 * Export one group of folders.
 */
+(int)exportSubscriptionGroup:(NSXMLElement *)parentElement fromArray:(NSArray *)feedArray
                   withGroups:(BOOL)groupFlag
{
	int countExported = 0;
    Database *db = [Database sharedManager];
	for (Folder * folder in feedArray)
	{
		NSMutableDictionary * itemDict = [[NSMutableDictionary alloc] init];
		NSString * name = [folder name];
		if (IsGroupFolder(folder))
		{
			NSArray * subFolders = [db arrayOfFolders:[folder itemId]];
			
            if (!groupFlag) {
				countExported += [Export exportSubscriptionGroup:parentElement fromArray:subFolders withGroups:groupFlag];
            }
			else
			{
				[itemDict setObject:[NSString stringByConvertingHTMLEntities:(name ? name : @"")] forKey:@"text"];
                NSXMLElement *outlineElement = [NSXMLElement elementWithName:@"outline"];
                [outlineElement setAttributesWithDictionary:itemDict];
                [parentElement addChild:outlineElement];
				countExported += [Export exportSubscriptionGroup:outlineElement fromArray:subFolders withGroups:groupFlag];
			}
		}
		else if (IsRSSFolder(folder) || IsGoogleReaderFolder(folder))
		{
			NSString * link = [folder homePage];
			NSString * description = [folder feedDescription];
			NSString * url = [folder feedURL];

			[itemDict setObject:@"rss" forKey:@"type"];
			[itemDict setObject:[NSString stringByConvertingHTMLEntities:(name ? name : @"")] forKey:@"text"];
            [itemDict setObject:[NSString stringByConvertingHTMLEntities:(link ? link : @"")] forKey:@"htmlUrl"];
			[itemDict setObject:[NSString stringByConvertingHTMLEntities:(url ? url : @"")] forKey:@"xmlUrl"];
			[itemDict setObject:[NSString stringByConvertingHTMLEntities:description] forKey:@"description"];
            NSXMLElement *outlineElement = [NSXMLElement elementWithName:@"outline"];
            [outlineElement setAttributesWithDictionary:itemDict];
            [parentElement addChild:outlineElement];
			++countExported;
		}
	}
	return countExported;
}

/* exportToFile
 * Export a list of RSS subscriptions to the specified file. If onlySelected is set then only those
 * folders selected in the folders tree are exported. Otherwise all RSS folders are exported.
 * Returns the number of subscriptions exported, or -1 on error.
 */
+(int)exportToFile:(NSString *)exportFileName from:(NSArray *)foldersArray withGroups:(BOOL)groupFlag
{
    int countExported = 0;
    NSXMLDocument *opmlDocument = [Export opmlDocumentFromFolders:foldersArray withGroups:groupFlag exportCount:&countExported];
    	// Now write the complete XML to the file
    
	NSString * fqFilename = [exportFileName stringByExpandingTildeInPath];
	if (![[NSFileManager defaultManager] createFileAtPath:fqFilename contents:nil attributes:nil])
	{
		return -1; // Indicate an error condition (impossible number of exports)
	}

    NSData *xmlData = [opmlDocument XMLDataWithOptions:NSXMLNodePrettyPrint | NSXMLNodeCompactEmptyElement];
    [xmlData writeToFile:fqFilename atomically:YES];
    
	
	return countExported;
}

/**
 *  Creates an OPML NSXMLDocument from an array of feeds
 *
 *  @param folders       An array of Folders (feeds) to export
 *  @param groupFlag     Keep groups in tact or flatten during export
 *  @param countExported An integer pointer to hold the number of exported feeds
 *
 *  @return NSXMLDocument with OPML containing the exported folders
 */
+ (NSXMLDocument *)opmlDocumentFromFolders:(NSArray *)folders withGroups:(BOOL)groupFlag exportCount:(int *)countExported {
    *countExported = 0;
    NSXMLDocument *opmlDocument = [[NSXMLDocument alloc] initWithKind:NSXMLDocumentKind options:NSXMLNodePreserveEmptyElements];
    [opmlDocument setCharacterEncoding:@"UTF-8"];
    [opmlDocument setVersion:@"1.0"];
    [opmlDocument setStandalone:YES];
    
    NSXMLElement *opmlElement = [NSXMLElement elementWithName:@"opml"];
    [opmlElement setAttributesAsDictionary:@{@"version":@"1.0"}];
    
    NSXMLElement *headElement = [NSXMLElement elementWithName:@"head"];
    NSXMLElement *title = [NSXMLElement elementWithName:@"title" stringValue:@"Vienna Subscriptions"];
    NSXMLElement *dateCreated = [NSXMLElement elementWithName:@"dateCreated"
                                                  stringValue:[[NSCalendarDate date] description]];
    [headElement addChild:title];
    [headElement addChild:dateCreated];
    [opmlElement addChild:headElement];
    
    NSXMLElement *bodyElement = [NSXMLElement elementWithName:@"body"];
    *countExported = [Export exportSubscriptionGroup:bodyElement fromArray:folders withGroups:groupFlag];
    
    
    [opmlElement addChild:bodyElement];
    
    [opmlDocument addChild:opmlElement];
    return [opmlDocument autorelease];
}

@end
