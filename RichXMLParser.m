//
//  RichXMLParser.m
//  Vienna
//
//  Created by Steve on 5/22/05.
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

#import "RichXMLParser.h"
#import <CoreFoundation/CoreFoundation.h>
#import "StringExtensions.h"
#import "ArrayExtensions.h"

@interface FeedItem (Private)
	-(void)setTitle:(NSString *)newTitle;
	-(void)setDescription:(NSString *)newDescription;
	-(void)setAuthor:(NSString *)newAuthor;
	-(void)setDate:(NSDate *)newDate;
	-(void)setGuid:(NSString *)newGuid;
	-(void)setLink:(NSString *)newLink;
@end

@interface RichXMLParser (Private)
	-(void)reset;
	-(NSData *)preFlightValidation:(NSData *)xmlData;
	-(NSStringEncoding)parseEncodingType:(NSData *)xmlData;
	-(BOOL)initRSSFeed:(XMLParser *)feedTree isRDF:(BOOL)isRDF;
	-(XMLParser *)channelTree:(XMLParser *)feedTree;
	-(BOOL)initRSSFeedHeader:(XMLParser *)feedTree;
	-(BOOL)initRSSFeedItems:(XMLParser *)feedTree;
	-(BOOL)initAtomFeed:(XMLParser *)feedTree;
	-(void)parseSequence:(XMLParser *)seqTree;
	-(void)setTitle:(NSString *)newTitle;
	-(void)setLink:(NSString *)newLink;
	-(void)setDescription:(NSString *)newDescription;
	-(void)setLastModified:(NSDate *)newDate;
	-(NSString *)stripHTMLTags:(NSString *)htmlString;
	-(void)ensureTitle:(FeedItem *)item;
	-(NSString *)guidFromItem:(FeedItem *)item;
@end

@implementation FeedItem

/* init
 * Creates a FeedItem instance
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		[self setTitle:@""];
		[self setDescription:@""];
		[self setAuthor:@""];
		[self setGuid:@""];
		[self setDate:nil];
		[self setLink:@""];
	}
	return self;
}

/* setTitle
 * Set the item title.
 */
-(void)setTitle:(NSString *)newTitle
{
	[newTitle retain];
	[title release];
	title = newTitle;
}

/* setDescription
 * Set the item description.
 */
-(void)setDescription:(NSString *)newDescription
{
	[newDescription retain];
	[description release];
	description = newDescription;
}

/* setAuthor
 * Set the item author.
 */
-(void)setAuthor:(NSString *)newAuthor
{
	[newAuthor retain];
	[author release];
	author = newAuthor;
}

/* setDate
 * Set the item date
 */
-(void)setDate:(NSDate *)newDate
{
	[newDate retain];
	[date release];
	date = newDate;
}

/* setGuid
 * Set the item GUID.
 */
-(void)setGuid:(NSString *)newGuid
{
	[newGuid retain];
	[guid release];
	guid = newGuid;
}

/* setLink
 * Set the item link.
 */
-(void)setLink:(NSString *)newLink
{
	[newLink retain];
	[link release];
	link = newLink;
}

/* title
 * Returns the item title.
 */
-(NSString *)title
{
	return title;
}

/* description
 * Returns the item description
 */
-(NSString *)description
{
	return description;
}

/* author
 * Returns the item author
 */
-(NSString *)author
{
	return author;
}

/* date
 * Returns the item date
 */
-(NSDate *)date
{
	return date;
}

/* guid
 * Returns the item GUID.
 */
-(NSString *)guid
{
	return guid;
}

/* link
 * Returns the item link.
 */
-(NSString *)link
{
	return link;
}

/* dealloc
 * Clean up when we're released.
 */
-(void)dealloc
{
	[guid release];
	[title release];
	[description release];
	[author release];
	[date release];
	[link release];
	[super dealloc];
}
@end

@implementation RichXMLParser

/* init
 * Creates a RichXMLParser instance.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		[self setTitle:@""];
		[self setDescription:@""];
		lastModified = nil;
		link = nil;
		items = nil;
		orderArray = nil;
	}
	return self;
}

/* reset
 * Reset to remove existing feed info.
 */
-(void)reset
{
	[title release];
	[description release];
	[lastModified release];
	[link release];
	[items release];
	title = nil;
	description = nil;
	lastModified = nil;
	link = nil;
	items = nil;
}

/* parseRichXML
 * Given an XML feed in xmlData, parses the feed as either an RSS or an Atom feed.
 * The actual parsed items can subsequently be accessed through the interface.
 */
-(BOOL)parseRichXML:(NSData *)xmlData
{
	BOOL success = NO;
	NS_DURING
	NSData * parsedXmlData = [self preFlightValidation:xmlData];
	if (parsedXmlData && [self setData:parsedXmlData])
	{
		XMLParser * subtree;
		
		// If this RSS?
		if ((subtree = [self treeByName:@"rss"]) != nil)
			success = [self initRSSFeed:subtree isRDF:NO];

		// If this RSS:RDF?
		else if ((subtree = [self treeByName:@"rdf:RDF"]) != nil)
			success = [self initRSSFeed:subtree isRDF:YES];

		// Atom?
		else if ((subtree = [self treeByName:@"feed"]) != nil)
			success = [self initAtomFeed:subtree];
	}
	NS_HANDLER
		success = NO;
	NS_ENDHANDLER
	return success;
}

/* preFlightValidation
 * Try and sanitise the XML data before the XML parser gets a chance to reject it. This
 * should address the most common bad-feed errors until we can change the parser to one
 * that provides us more control.
 */
-(NSData *)preFlightValidation:(NSData *)xmlData
{
	int count = [xmlData length];
	const unsigned char * srcPtr = [xmlData bytes];
	const unsigned char * srcEndPtr = srcPtr + count;

	// We'll create another data stream with the converted characters
	NSMutableData * newXmlData = [NSMutableData dataWithLength:count];
	char * destPtr = [newXmlData mutableBytes];
	int destCapacity = count;
	int destSize = count;
	int destIndex = 0;

	// Determine XML encoding and BOM
	NSStringEncoding encodedType = [self parseEncodingType:xmlData];
	if (count > 2 && srcPtr[0] == 0xFE && srcPtr[1] == 0xFF)
	{
		// Copy Unicode UTF-16 big-endian BOM.
		destPtr[destIndex++] = srcPtr[0];
		destPtr[destIndex++] = srcPtr[1];
		srcPtr += 2;
	}
	else if (count > 2 && srcPtr[0] == 0xFF && srcPtr[1] == 0xFE)
	{
		// Copy Unicode UTF-16 little-endian BOM.
		destPtr[destIndex++] = srcPtr[0];
		destPtr[destIndex++] = srcPtr[1];
		srcPtr += 2;
	}
	else if (count > 3 && srcPtr[0] == 0xEF && srcPtr[1] == 0xBB && srcPtr[2] == 0xBF)
	{
		// Copy Unicode UTF-8 little-endian BOM.
		destPtr[destIndex++] = srcPtr[0];
		destPtr[destIndex++] = srcPtr[1];
		destPtr[destIndex++] = srcPtr[2];
		srcPtr += 3;
	}
	
	while (srcPtr < srcEndPtr)
	{
		unsigned char ch = *srcPtr++;
		if (ch >= 0xC0 && ch <= 0xFD && srcPtr < srcEndPtr && *srcPtr >= 0x80 && *srcPtr <= 0xBF)
		{
			// Copy UTF-8 lead bytes unchanged. The parser can cope with
			// these fine.
			destPtr[destIndex++] = ch;
			while (srcPtr < srcEndPtr && (*srcPtr & 0x80))
				destPtr[destIndex++] = *srcPtr++;
		}
		else if (ch > 0x7F && encodedType == NSUTF8StringEncoding)
		{
			// Other characters with their high bits set are not valid UTF-8.
			// But regardless of the encoding scheme, their entity equivalents
			// are. So convert them into a hex entity character code.
			if (destSize + 5 > destCapacity)
			{
				[newXmlData setLength:destCapacity += 256];
				destPtr = [newXmlData mutableBytes];
			}
			destPtr[destIndex++] = '&';
			destPtr[destIndex++] = '#';
			destPtr[destIndex++] = 'x';
			destPtr[destIndex++] = "0123456789ABCDEF"[(ch / 16)];
			destPtr[destIndex++] = "0123456789ABCDEF"[(ch % 16)];
			destPtr[destIndex++] = ';';
			destSize += 5;
		}
		else if (ch == '&' && srcPtr < srcEndPtr && *srcPtr != '#')
		{
			// Some feeds use a '&' outside of its intended use as an entity
			// delimiter. So if '&' is followed by a non-alphanumeric, make it
			// into its entity equivalent.
			const unsigned char * srcTmpPtr = srcPtr;
			while (srcTmpPtr < srcEndPtr && isalpha(*srcTmpPtr))
				++srcTmpPtr;
			if (srcTmpPtr < srcEndPtr && *srcTmpPtr == ';')
				destPtr[destIndex++] = '&';
			else
			{
				if (destSize + 4 > destCapacity)
				{
					[newXmlData setLength:destCapacity += 256];
					destPtr = [newXmlData mutableBytes];
				}
				destPtr[destIndex++] = '&';
				destPtr[destIndex++] = 'a';
				destPtr[destIndex++] = 'm';
				destPtr[destIndex++] = 'p';
				destPtr[destIndex++] = ';';
				destSize += 4;
			}
		}
		else
			destPtr[destIndex++] = ch;
	}
	NSAssert(destIndex == destSize, @"Did not copy all data bytes to destination buffer");
	[newXmlData setLength:destIndex];
	
	// Make sure that the last valid character of the feed is '>' otherwise it was truncated. The
	// CFXML parser annoyingly crashes if it is given a truncated feed.
	while (--destIndex > 0 && (destPtr[destIndex] == '\0' || isspace(destPtr[destIndex])));
	return (destPtr[destIndex] == '>') ? newXmlData : nil;
}

/* parseEncodingType
 * Parse off the encoding field.
 */
-(NSStringEncoding)parseEncodingType:(NSData *)xmlData
{
	NSStringEncoding encodingType = NSUTF8StringEncoding;
	const char * textPtr = [xmlData bytes];
	const char * textEndPtr = textPtr + [xmlData length];

	while (textPtr < textEndPtr && *textPtr != '<')
		++textPtr;

	// Scan for the encoding attribute name up until the closing tag
	const char * encodingAttribute = "encoding=";
	const char * encodingAttributePtr = encodingAttribute;
	while (textPtr < textEndPtr && *encodingAttributePtr != '\0' && *textPtr != '>')
	{
		if (*textPtr == *encodingAttributePtr)
			++encodingAttributePtr;
		else
			encodingAttributePtr = encodingAttribute;
		++textPtr;
	}

	// If we found it, parse off the encoding type name
	if (*encodingAttributePtr == '\0')
	{
		if (textPtr < textEndPtr && *textPtr == '"')
			++textPtr;

		// We need to special case UTF-8 as CFStringConvertIANACharSetNameToEncoding
		// doesn't recognise it.
		const char * encodingNamePtr = textPtr;
		const char * utf8EncodingName = "UTF-8";
		const char * utf8EncodingNamePtr = utf8EncodingName;
		while (textPtr < textEndPtr && *textPtr != '"')
		{
			if (toupper(*textPtr) == *utf8EncodingNamePtr)
				++utf8EncodingNamePtr;
			else
				utf8EncodingNamePtr = utf8EncodingName;
			++textPtr;
		}

		// Now extract the encoding name if it wasn't UTF-8
		if (*utf8EncodingNamePtr != '\0')
		{
			CFStringRef encodingName = CFStringCreateWithBytes(kCFAllocatorDefault, (unsigned char *)encodingNamePtr, textPtr - encodingNamePtr, kCFStringEncodingISOLatin1, false);
			encodingType = CFStringConvertIANACharSetNameToEncoding(encodingName);
			CFRelease(encodingName);
		}
	}
	return encodingType;
}

/* initRSSFeed
 * Prime the feed with header and items from an RSS feed
 */
-(BOOL)initRSSFeed:(XMLParser *)feedTree isRDF:(BOOL)isRDF
{
	BOOL success = [self initRSSFeedHeader:[self channelTree:feedTree]];
	if (success)
	{
		if (isRDF)
			success = [self initRSSFeedItems:feedTree];
		else
			success = [self initRSSFeedItems:[self channelTree:feedTree]];
	}
	return success;
}

/* channelTree
 * Return the root of the RSS feed's channel.
 */
-(XMLParser *)channelTree:(XMLParser *)feedTree
{
	XMLParser * channelTree = [feedTree treeByName:@"channel"];
	if (channelTree == nil)
		channelTree = [feedTree treeByName:@"rss:channel"];
	return channelTree;
}

/* initRSSFeedHeader
 * Parse an RSS feed header items.
 */
-(BOOL)initRSSFeedHeader:(XMLParser *)feedTree
{
	BOOL success = YES;
	
	// Iterate through the channel items
	int count = [feedTree countOfChildren];
	int index;
	
	for (index = 0; index < count; ++index)
	{
		XMLParser * subTree = [feedTree treeByIndex:index];
		NSString * nodeName = [subTree nodeName];

		// Parse title
		if ([nodeName isEqualToString:@"title"])
		{
			[self setTitle:[XMLParser processAttributes:[subTree valueOfElement]]];
			continue;
		}

		// Parse items group which dictates the sequence of the articles.
		if ([nodeName isEqualToString:@"items"])
		{
			XMLParser * seqTree = [subTree treeByName:@"rdf:Seq"];
			if (seqTree != nil)
				[self parseSequence:seqTree];
		}

		// Parse description
		if ([nodeName isEqualToString:@"description"])
		{
			[self setDescription:[subTree valueOfElement]];
			continue;
		}			
		
		// Parse link
		if ([nodeName isEqualToString:@"link"])
		{
			[self setLink:[XMLParser processAttributes:[subTree valueOfElement]]];
			continue;
		}			
		
		// Parse the date when this feed was last updated
		if ([nodeName isEqualToString:@"lastBuildDate"])
		{
			NSString * dateString = [subTree valueOfElement];
			[self setLastModified:[XMLParser parseXMLDate:dateString]];
			continue;
		}
		
		// Parse item date
		if ([nodeName isEqualToString:@"dc:date"])
		{
			NSString * dateString = [subTree valueOfElement];
			[self setLastModified:[XMLParser parseXMLDate:dateString]];
			continue;
		}

		// Parse item date
		if ([nodeName isEqualToString:@"pubDate"])
		{
			NSString * dateString = [subTree valueOfElement];
			[self setLastModified:[XMLParser parseXMLDate:dateString]];
			continue;
		}
	}
	return success;
}

/* parseSequence
 * Parses an RDF sequence and initialises orderArray with the appropriate sequence.
 * The RSS parser will then use this to order the actual items appropriately.
 */
-(void)parseSequence:(XMLParser *)seqTree
{
	int count = [seqTree countOfChildren];
	int index;

	[orderArray release];
	orderArray = [[NSMutableArray alloc] initWithCapacity:count];
	for (index = 0; index < count; ++index)
	{
		XMLParser * subTree = [seqTree treeByIndex:index];
		if ([[subTree nodeName] isEqualToString:@"rdf:li"])
		{
			NSString * resourceString = [subTree valueOfAttribute:@"rdf:resource"];
			if (resourceString == nil)
				resourceString = [subTree valueOfAttribute:@"resource"];
			if (resourceString != nil)
				[orderArray addObject:resourceString];
		}
	}
}

/* initRSSFeedItems
 * Parse the items from an RSS feed
 */
-(BOOL)initRSSFeedItems:(XMLParser *)feedTree
{
	BOOL success = YES;

	// Allocate an items array
	NSAssert(items == nil, @"initRSSFeedItems called more than once per initialisation");
	items = [[NSMutableArray alloc] initWithCapacity:10];
	
	// Iterate through the channel items
	int count = [feedTree countOfChildren];
	int index;

	for (index = 0; index < count; ++index)
	{
		XMLParser * subTree = [feedTree treeByIndex:index];
		NSString * nodeName = [subTree nodeName];
		
		// Parse a single item to construct a FeedItem object which is appended to
		// the items array we maintain.
		if ([nodeName isEqualToString:@"item"])
		{
			FeedItem * newItem = [[FeedItem alloc] init];
			int itemCount = [subTree countOfChildren];
			BOOL hasDetailedContent = NO;
			BOOL hasGUID = NO;
			BOOL hasLink = NO;
			int itemIndex;

			// Check for rdf:about so we can identify this item in the orderArray.
			NSString * itemIdentifier = [subTree valueOfAttribute:@"rdf:about"];

			for (itemIndex = 0; itemIndex < itemCount; ++itemIndex)
			{
				XMLParser * subItemTree = [subTree treeByIndex:itemIndex];
				NSString * itemNodeName = [subItemTree nodeName];

				// Parse item title
				if ([itemNodeName isEqualToString:@"title"])
				{
					NSString * newTitle = [XMLParser processAttributes:[[subItemTree valueOfElement] firstNonBlankLine]];
					[newItem setTitle:[self stripHTMLTags:newTitle]];
					continue;
				}
				
				// Parse item description
				if ([itemNodeName isEqualToString:@"description"] && !hasDetailedContent)
				{
					[newItem setDescription:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse GUID. The GUID may optionally have a permaLink attribute
				// in which case this is also the article link unless overridden by
				// an explicit link tag.
				if ([itemNodeName isEqualToString:@"guid"])
				{
					NSString * permaLink = [subItemTree valueOfAttribute:@"isPermaLink"];
					if (permaLink && [permaLink isEqualToString:@"true"] && !hasLink)
						[newItem setLink:[subItemTree valueOfElement]];
					[newItem setGuid:[subItemTree valueOfElement]];
					hasGUID = YES;
					continue;
				}

				// Parse detailed item description. This overrides the existing
				// description for this item.
				if ([itemNodeName isEqualToString:@"content:encoded"])
				{
					[newItem setDescription:[subItemTree valueOfElement]];
					hasDetailedContent = YES;
					continue;
				}
				
				// Parse item author
				if ([itemNodeName isEqualToString:@"author"])
				{
					[newItem setAuthor:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse item author
				if ([itemNodeName isEqualToString:@"dc:creator"])
				{
					[newItem setAuthor:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse item date
				if ([itemNodeName isEqualToString:@"dc:date"])
				{
					NSString * dateString = [subItemTree valueOfElement];
					[newItem setDate:[XMLParser parseXMLDate:dateString]];
					continue;
				}
				
				// Parse item link
				if ([itemNodeName isEqualToString:@"link"])
				{
					NSString * linkName = [[subItemTree valueOfElement] trim];
					[newItem setLink:linkName];
					hasLink = YES;
					continue;
				}
				
				// Parse item date
				if ([itemNodeName isEqualToString:@"pubDate"])
				{
					NSString * dateString = [subItemTree valueOfElement];
					[newItem setDate:[XMLParser parseXMLDate:dateString]];
					continue;
				}
			}

			// If no link, set it to the feed link if there is one
			if (!hasLink && [self link])
				[newItem setLink:[self link]];

			// Derive any missing title
			[self ensureTitle:newItem];

			// If no explicit GUID is specified, use a concatenated hash of attributes for the GUID
			if (!hasGUID)
				[newItem setGuid:[self guidFromItem:newItem]];
            
			// Add this item in the proper location in the array
			int indexOfItem = itemIdentifier ? [orderArray indexOfStringInArray:itemIdentifier] : NSNotFound;
			if (indexOfItem == NSNotFound)
				indexOfItem = [items count];
			[items insertObject:newItem atIndex:indexOfItem];
			[newItem release];
		}
	}

	// Now scan the array and set the article date if it is missing. We'll use the
	// last modified date of the feed and set each article to be 1 second older than the
	// previous one. So the array is effectively newest first.
	NSDate * itemDate = [self lastModified];
	if (itemDate == nil)
		itemDate = [NSDate date];
	for (index = 0; index < [items count]; ++index)
	{
		FeedItem * anItem = [items objectAtIndex:index];
		if ([anItem date] == nil)
			[anItem setDate:itemDate];
		itemDate = [itemDate addTimeInterval:-1.0];
	}
	return success;
}

/* initAtomFeed
 * Prime the feed with header and items from an Atom feed
 */
-(BOOL)initAtomFeed:(XMLParser *)feedTree
{
	BOOL success = YES;
	
	// Allocate an items array
	NSAssert(items == nil, @"initAtomFeed called more than once per initialisation");
	items = [[NSMutableArray alloc] initWithCapacity:10];
	
	// Look for feed attributes we need to process
	NSString * linkBase = [[feedTree valueOfAttribute:@"xml:base"] stringByDeletingLastURLComponent];

	// Iterate through the atom items
	NSString * defaultAuthor = @"";
	int count = [feedTree countOfChildren];
	int index;
	
	for (index = 0; index < count; ++index)
	{
		XMLParser * subTree = [feedTree treeByIndex:index];
		NSString * nodeName = [subTree nodeName];

		// Parse title
		if ([nodeName isEqualToString:@"title"])
		{
			[self setTitle:[XMLParser processAttributes:[subTree valueOfElement]]];
			continue;
		}
		
		// Parse description
		if ([nodeName isEqualToString:@"tagline"])
		{
			[self setDescription:[subTree valueOfElement]];
			continue;
		}			

		// Parse link
		if ([nodeName isEqualToString:@"link"])
		{
			if ([subTree valueOfAttribute:@"rel"] == nil || [[subTree valueOfAttribute:@"rel"] isEqualToString:@"alternate"])
			{
				if (linkBase != nil)
					[self setLink:[linkBase stringByAppendingURLComponent:[subTree valueOfAttribute:@"href"]]];
				else
					[self setLink:[subTree valueOfAttribute:@"href"]];
			}
			continue;
		}			
		
		// Parse author at the feed level. This is the default for any entry
		// that doesn't have an explicit author.
		if ([nodeName isEqualToString:@"author"])
		{
			XMLParser * emailTree = [subTree treeByName:@"name"];
			if (emailTree != nil)
				defaultAuthor = [emailTree valueOfElement];
			continue;
		}
		
		// Parse the date when this feed was last updated
		if ([nodeName isEqualToString:@"modified"])
		{
			NSString * dateString = [subTree valueOfElement];
			[self setLastModified:[XMLParser parseXMLDate:dateString]];
			continue;
		}
		
		// Parse a single item to construct a FeedItem object which is appended to
		// the items array we maintain.
		if ([nodeName isEqualToString:@"entry"])
		{
			FeedItem * newItem = [[FeedItem alloc] init];
			[newItem setAuthor:defaultAuthor];
			int itemCount = [subTree countOfChildren];
			int itemIndex;
			BOOL hasGUID = NO;
			BOOL hasLink = NO;

			// Look for and stack the xml:base attribute
			NSString * entryBase = [subTree valueOfAttribute:@"xml:base"];
			if (entryBase != nil && linkBase != nil)
				entryBase = [linkBase stringByAppendingURLComponent:entryBase];

			for (itemIndex = 0; itemIndex < itemCount; ++itemIndex)
			{
				XMLParser * subItemTree = [subTree treeByIndex:itemIndex];
				NSString * itemNodeName = [subItemTree nodeName];
				
				// Parse item title
				if ([itemNodeName isEqualToString:@"title"])
				{
					NSString * newTitle = [XMLParser processAttributes:[[subItemTree valueOfElement] firstNonBlankLine]];
					NSString * titleType = [subItemTree valueOfAttribute:@"type"];

					if ([titleType isEqualToString:@"html"] || [titleType isEqualToString:@"xhtml"])
						[newItem setTitle:[self stripHTMLTags:newTitle]];
					[newItem setTitle:newTitle];
					continue;
				}

				// Parse item description
				if ([itemNodeName isEqualToString:@"content"])
				{
					[newItem setDescription:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse item description
				if ([itemNodeName isEqualToString:@"summary"])
				{
					[newItem setDescription:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse item author
				if ([itemNodeName isEqualToString:@"author"])
				{
					XMLParser * emailTree = [subItemTree treeByName:@"name"];
					[newItem setAuthor:[emailTree valueOfElement]];
					continue;
				}
				
				// Parse item link
				if ([itemNodeName isEqualToString:@"link"])
				{
					if ([subItemTree valueOfAttribute:@"rel"] == nil || [[subItemTree valueOfAttribute:@"rel"] isEqualToString:@"alternate"])
					{
						if (entryBase != nil)
							[newItem setLink:[entryBase stringByAppendingURLComponent:[subItemTree valueOfAttribute:@"href"]]];
						else
							[newItem setLink:[subItemTree valueOfAttribute:@"href"]];
						hasLink = YES;
					}
					continue;
				}
				
				// Parse item link
				if ([itemNodeName isEqualToString:@"id"])
				{
					[newItem setGuid:[subItemTree valueOfElement]];
					hasGUID = YES;
					continue;
				}

				// Parse item date
				if ([itemNodeName isEqualToString:@"modified"])
				{
					NSString * dateString = [subItemTree valueOfElement];
					NSDate * newDate = [XMLParser parseXMLDate:dateString];
					if ([newItem date] == nil || [newDate isGreaterThan:[newItem date]])
						[newItem setDate:newDate];
					continue;
				}

				// Parse item date
				if ([itemNodeName isEqualToString:@"created"])
				{
					NSString * dateString = [subItemTree valueOfElement];
					NSDate * newDate = [XMLParser parseXMLDate:dateString];
					if ([newItem date] == nil || [newDate isGreaterThan:[newItem date]])
						[newItem setDate:newDate];
					continue;
				}
				
				// Parse item date
				if ([itemNodeName isEqualToString:@"updated"])
				{
					NSString * dateString = [subItemTree valueOfElement];
					NSDate * newDate = [XMLParser parseXMLDate:dateString];
					if ([newItem date] == nil || [newDate isGreaterThan:[newItem date]])
						[newItem setDate:newDate];
					continue;
				}
			}

			// If no explicit GUID is specified, use the link as the GUID
			if (!hasGUID)
				[newItem setGuid:[self guidFromItem:newItem]];

			// Derive any missing title
			[self ensureTitle:newItem];
			[items addObject:newItem];
			[newItem release];
		}
	}
	
	return success;
}

/* setTitle
 * Set this feed's title string.
 */
-(void)setTitle:(NSString *)newTitle
{
	[newTitle retain];
	[title release];
	title = newTitle;
}

/* setDescription
 * Set this feed's description string.
 */
-(void)setDescription:(NSString *)newDescription
{
	[newDescription retain];
	[description release];
	description = newDescription;
}

/* setLink
 * Sets this feed's link
 */
-(void)setLink:(NSString *)newLink
{
	[newLink retain];
	[link release];
	link = newLink;
}

/* setLastModified
 * Set the date when this feed was last updated.
 */
-(void)setLastModified:(NSDate *)newDate
{
	[newDate retain];
	[lastModified release];
	lastModified = newDate;
}

/* title
 * Return the title string.
 */
-(NSString *)title
{
	return title;
}

/* description
 * Return the description string.
 */
-(NSString *)description
{
	return description;
}

/* link
 * Returns the URL of this feed
 */
-(NSString *)link
{
	return link;
}

/* items
 * Returns the array of items.
 */
-(NSArray *)items
{
	return items;
}

/* lastModified
 * Returns the feed's last update
 */
-(NSDate *)lastModified
{
	return lastModified;
}

/* stripHTMLTags
 * Strip off HTML tags from title strings. This code takes stricter approach to
 * HTML removal because some feeds use HTML tags in the title which are actually part
 * of the title rather than presentation data. So we only remove tags which:
 * 
 * 1. Have a corresponding </tag> instruction.
 * 2. Are followed immediately by a non-space character.
 */
-(NSString *)stripHTMLTags:(NSString *)htmlString
{
	NSMutableString * rawString = [[NSMutableString alloc] initWithString:htmlString];
	int openTagIndex = 0;

	while ((openTagIndex = [rawString indexOfCharacterInString:'<' afterIndex:openTagIndex]) != NSNotFound)
	{
		int closeTagIndex;
		if ((closeTagIndex = [rawString indexOfCharacterInString:'>' afterIndex:openTagIndex]) != NSNotFound)
		{
			if (closeTagIndex + 1 < [rawString length] && !isspace([rawString characterAtIndex:closeTagIndex+1]))
			{
				NSString * tagName = [rawString substringWithRange:NSMakeRange(openTagIndex + 1, closeTagIndex - openTagIndex - 1)];
				NSString * closingTag = [NSString stringWithFormat:@"</%@>", tagName];
				NSRange openingTagRange = NSMakeRange(openTagIndex, closeTagIndex - openTagIndex + 1);
				NSRange closingTagRange = [rawString rangeOfString:closingTag options:NSLiteralSearch range:NSMakeRange(closeTagIndex, [rawString length] - closeTagIndex)];
				
				if (closingTagRange.location != NSNotFound)
				{
					[rawString deleteCharactersInRange:closingTagRange];
					[rawString deleteCharactersInRange:openingTagRange];
				}
			}			
		}
		++openTagIndex;
	}
	return rawString;
}

/* guidFromItem
 * This routine attempts to synthesize a GUID from an incomplete item that lacks an
 * ID field. Generally we'll have three things to work from: a link, a title and a
 * description. The link alone is not sufficiently unique and I've seen feeds where
 * the description is also not unique. The title field generally does vary but we need
 * to be careful since separate articles with different descriptions may have the same
 * title. The solution is to hash the link and title and build a GUID from those.
 */
-(NSString *)guidFromItem:(FeedItem *)item
{
	return [NSString stringWithFormat:@"%X-%X", [[item link] hash], [[item title] hash]];
}

/* ensureTitle
 * Make sure we have a title and synthesize one from the description if we don't.
 */
-(void)ensureTitle:(FeedItem *)item
{
	if (![item title] || [[item title] isBlank])
	{
		NSString * newTitle = [XMLParser processAttributes:[NSString stringByRemovingHTML:[item description]]];
		if ([newTitle isBlank])
			newTitle = NSLocalizedString(@"(No title)", nil);
		[item setTitle:newTitle];
	}
}

/* dealloc
 * Clean up afterwards.
 */
-(void)dealloc
{
	[orderArray release];
	[title release];
	[description release];
	[lastModified release];
	[link release];
	[items release];
	[super dealloc];
}
@end
