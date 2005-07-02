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
#import "Credentials.h"

@interface FeedItem (Private)
	-(void)setTitle:(NSString *)newTitle;
	-(void)setDescription:(NSString *)newDescription;
	-(void)setAuthor:(NSString *)newAuthor;
	-(void)setDate:(NSDate *)newDate;
	-(void)setLink:(NSString *)newLink;
@end

@interface RichXMLParser (Private)
	-(void)reset;
	-(void)getEncoding;
	-(BOOL)initRSSFeed:(XMLParser *)feedTree isRDF:(BOOL)isRDF;
	-(XMLParser *)channelTree:(XMLParser *)feedTree;
	-(BOOL)initRSSFeedHeader:(XMLParser *)feedTree;
	-(BOOL)initRSSFeedItems:(XMLParser *)feedTree;
	-(BOOL)initAtomFeed:(XMLParser *)feedTree;
	-(void)setTitle:(NSString *)newTitle;
	-(void)setLink:(NSString *)newLink;
	-(void)setDescription:(NSString *)newDescription;
	-(void)setLastModified:(NSDate *)newDate;
	-(NSString *)encodedValueOfElement:(XMLParser *)tree;
	-(void)ensureTitle:(FeedItem *)item;
	-(NSString *)processTitleAttributes:(NSString *)stringToProcess;
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
		title = nil;
		description = nil;
		lastModified = nil;
		link = nil;
		items = nil;

		// Create the encoding dictionary that maps encoding names that appear
		// in the ?xml header with NSString encoding values.
		encodingDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:NSUTF8StringEncoding],				@"UTF-8",
			[NSNumber numberWithInt:NSWindowsCP1252StringEncoding],		@"WINDOWS-1252",
			[NSNumber numberWithInt:NSISOLatin1StringEncoding],			@"ISO-8859-1",
			nil,														nil
			];
		encodingScheme = NSUTF8StringEncoding;
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
	if ([self setData:xmlData])
	{
		XMLParser * subtree;
		
		// Get encoding
		[self getEncoding];

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
	return success;
}

/* getEncoding
 * Get the encoding scheme used by strings in this feed. Default to UTF8 if
 * no explicit encoding is specified in the XML header.
 */
-(void)getEncoding
{
	XMLParser * xmltree = [self treeByName:@"xml"];
	if (xmltree != nil)
	{
		NSString * encodingString = [xmltree valueOfAttribute:@"encoding"];
		NSString * encodingValue;

		if (encodingString == nil)
			encodingString = @"UTF-8";
		encodingValue = [encodingDictionary valueForKey:[encodingString uppercaseString]];
		if (encodingValue != nil)
			encodingScheme = [encodingValue intValue];
	}
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
			[self setTitle:[self processTitleAttributes:[subTree valueOfElement]]];
			continue;
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
			[self setLink:[subTree valueOfElement]];
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
	}
	return success;
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
			int itemIndex;
			
			for (itemIndex = 0; itemIndex < itemCount; ++itemIndex)
			{
				XMLParser * subItemTree = [subTree treeByIndex:itemIndex];
				NSString * itemNodeName = [subItemTree nodeName];

				// Parse item title
				if ([itemNodeName isEqualToString:@"title"])
				{
					[newItem setTitle:[self processTitleAttributes:[subItemTree valueOfElement]]];
					continue;
				}
				
				// Parse item description
				if ([itemNodeName isEqualToString:@"description"])
				{
					[newItem setDescription:[self encodedValueOfElement:subItemTree]];
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
				
				// Parse item author
				if ([itemNodeName isEqualToString:@"link"])
				{
					[newItem setLink:[subItemTree valueOfElement]];
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

			// Derive any missing title
			[self ensureTitle:newItem];
			[items addObject:newItem];
			[newItem release];
		}
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
	
	// Iterate through the atom items
	int count = [feedTree countOfChildren];
	int index;
	
	for (index = 0; index < count; ++index)
	{
		XMLParser * subTree = [feedTree treeByIndex:index];
		NSString * nodeName = [subTree nodeName];
		
		// Parse title
		if ([nodeName isEqualToString:@"title"])
		{
			[self setTitle:[self processTitleAttributes:[subTree valueOfElement]]];
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
			[self setLink:[subTree valueOfAttribute:@"href"]];
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
			int itemCount = [subTree countOfChildren];
			int itemIndex;
			
			for (itemIndex = 0; itemIndex < itemCount; ++itemIndex)
			{
				XMLParser * subItemTree = [subTree treeByIndex:itemIndex];
				NSString * itemNodeName = [subItemTree nodeName];
				
				// Parse item title
				if ([itemNodeName isEqualToString:@"title"])
				{
					[newItem setTitle:[self processTitleAttributes:[subItemTree valueOfElement]]];
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
				
				// Parse item author
				if ([itemNodeName isEqualToString:@"link"])
				{
					[newItem setLink:[subItemTree valueOfAttribute:@"href"]];
					continue;
				}
				
				// Parse item date
				if ([itemNodeName isEqualToString:@"modified"])
				{
					NSString * dateString = [subItemTree valueOfElement];
					[newItem setDate:[XMLParser parseXMLDate:dateString]];
					continue;
				}
			}

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

/* encodedValueOfElement
 * Gets the element for a tree node and converts it to UTF8 from whatever is set as the
 * native XML encoding scheme.
 *
 * Note: this doesn't do anything right now. I ran into problems dealing with the NSString
 * that CFXML returns me and trying to encode the individual bytes again just caused
 * exceptions to get thrown. Let's come back to this later.
 */
-(NSString *)encodedValueOfElement:(XMLParser *)subTree
{
	return [subTree valueOfElement];
}

/* ensureTitle
 * Make sure we have a title and synthesize one from the description if we don't.
 */
-(void)ensureTitle:(FeedItem *)item
{
	if (![item title] || [[item title] isBlank])
	{
		NSMutableString * aString = [NSMutableString stringWithString:[item description]];
		int maxChrs = [[item description] length];
		int indexOfChr = 0;
		int tagLength = 0;
		int tagStartIndex = 0;
		int lengthToLastWord = 0;
		BOOL isInQuote = NO;
		BOOL isInTag = NO;

		// Rudimentary HTML tag parsing. This could be done by initWithHTML on an attributed string
		// and extracting the raw string but initWithHTML cannot be invoked within an NSURLConnection
		// callback which is where this is probably liable to be used.
		//
		// This code basically throws away all HTML tags up to <br> or <br /> or the first raw newline
		// or until 80 characters have been processed.
		//
		while (indexOfChr < maxChrs)
		{
			unichar ch = [aString characterAtIndex:indexOfChr];
			if (ch == '"')
				isInQuote = !isInQuote;
			if (isInTag)
				++tagLength;
			if (ch == ' ' && !isInTag)
				lengthToLastWord = indexOfChr;
			if (ch == '<' && !isInQuote)
			{
				isInTag = YES;
				tagStartIndex = indexOfChr;
				tagLength = 0;
			}
			if (ch == '>' && isInTag)
			{
				if (++tagLength > 2)
				{
					NSRange tagRange = NSMakeRange(tagStartIndex, tagLength);
					NSString * tag = [[aString substringWithRange:tagRange] lowercaseString];
					[aString deleteCharactersInRange:tagRange];

					// Reset scan to the point where the tag started minus one because
					// we bump up indexOfChr at the end of the loop.
					indexOfChr = tagStartIndex - 1;
					maxChrs = [aString length];
					isInTag = NO;

					if (([tag isEqualToString:@"<br>"] || [tag isEqualToString:@"<br />"]) && indexOfChr >= 0)
					{
						lengthToLastWord = tagStartIndex;
						break;
					}
				}
			}
			if (ch == '\n')
			{
				lengthToLastWord = indexOfChr;
				break;
			}
			if (indexOfChr >= 80 && !isInTag)
				break;
			++indexOfChr;
		}

		// If we got a long word with no spaces then just break the string
		// at the limit.
		if (lengthToLastWord == 0)
			lengthToLastWord = MIN(maxChrs, 80);

		[aString deleteCharactersInRange:NSMakeRange(lengthToLastWord, maxChrs - lengthToLastWord)];
		
		// If we truncated at the end of a word, append ellipsises to show that
		// there was more. Really just a little polish.
		if (lengthToLastWord < indexOfChr)
			[aString appendString:@"..."];
		[item setTitle:aString];
	}
}

/* processTitleAttributes
 * Scan the specified string and convert attribute characters to their literals. Also trim leading and trailing
 * whitespace.
 */
-(NSString *)processTitleAttributes:(NSString *)stringToProcess
{
	NSMutableString * processedString = [[NSMutableString alloc] initWithString:stringToProcess];
	int entityStart;
	int entityEnd;

	entityStart = [processedString indexOfCharacterInString:'&' afterIndex:0];
	while (entityStart != NSNotFound)
	{
		entityEnd = [processedString indexOfCharacterInString:';' afterIndex:entityStart + 1];
		if (entityEnd != NSNotFound)
		{
			NSRange entityRange = NSMakeRange(entityStart, (entityEnd - entityStart) + 1);
			NSString * entityString = [processedString substringWithRange:entityRange];
			NSString * stringToAppend;
			
			if ([entityString characterAtIndex:1] == '#' && entityRange.length > 3)
				stringToAppend = [NSString stringWithFormat:@"%c", [[entityString substringFromIndex:2] intValue]];
			else
			{
				if ([entityString isEqualTo:@"&lt;"])				stringToAppend = @"<";
				else if ([entityString isEqualTo: @"&gt;"])			stringToAppend = @">";
				else if ([entityString isEqualTo: @"&quot;"])		stringToAppend = @"\"";
				else if ([entityString isEqualTo: @"&amp;"])		stringToAppend = @"&";
				else if ([entityString isEqualTo: @"&rsquo;"])		stringToAppend = @"'";
				else if ([entityString isEqualTo: @"&lsquo;"])		stringToAppend = @"'";
				else if ([entityString isEqualTo: @"&apos;"])		stringToAppend = @"'";				
				else												stringToAppend = entityString;
			}
			[processedString replaceCharactersInRange:entityRange withString:stringToAppend];
		}
		entityStart = [processedString indexOfCharacterInString:'&' afterIndex:entityStart + 1];
	}

	NSString * returnString = [processedString trim];
	[processedString release];
	return returnString;
}

/* dealloc
 * Clean up afterwards.
 */
-(void)dealloc
{
	[title release];
	[description release];
	[lastModified release];
	[link release];
	[items release];
	[super dealloc];
}
@end
