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
#import "StringExtensions.h"
#import "ArrayExtensions.h"
#import "XMLTag.h"
#import "FeedItem.h"
#import "NSDate+Vienna.h"

@interface RichXMLParser (Private)
	-(void)reset;
	-(NSData *)preFlightValidation:(NSData *)xmlData;
	-(NSStringEncoding)parseEncodingType:(NSData *)xmlData;
	-(BOOL)initRSSFeed:(NSXMLElement *)rssElement isRDF:(BOOL)isRDF;
    -(NSXMLElement *)channelElementFromRSSElement:(NSXMLElement *)rssElement;
	-(BOOL)initRSSFeedHeaderWithElement:(NSXMLElement *)channelElement;
	-(BOOL)initRSSFeedItems:(NSXMLElement *)startElement;
	-(BOOL)initAtomFeed:(NSXMLElement *)atomElement;
	-(void)parseSequence:(NSXMLElement *)seqElement;
	-(void)setTitle:(NSString *)newTitle;
	-(void)setLink:(NSString *)newLink;
	-(void)setDescription:(NSString *)newDescription;
	-(void)setLastModified:(NSDate *)newDate;
	-(void)ensureTitle:(FeedItem *)item;
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
	//NSData * parsedXmlData = [self preFlightValidation:xmlData];
    NSError *error = nil;
    NSXMLDocument *xmlDocument = [[NSXMLDocument alloc] initWithData:xmlData
                                                                 options:NSXMLNodeOptionsNone
                                                                       error:&error];
    if (!error) {
        if([[xmlDocument.rootElement name] isEqualToString:@"rss"]) {
            success = [self initRSSFeed:xmlDocument.rootElement isRDF:NO];
        }
        else if ([[xmlDocument.rootElement name] isEqualToString:@"rdf:RDF"]) {
            success = [self initRSSFeed:xmlDocument.rootElement isRDF:YES];
        }
        else if ([[xmlDocument.rootElement name] isEqualToString:@"feed"]) {
            success = [self initAtomFeed:xmlDocument.rootElement];
        }
    }
    [xmlDocument release];
    xmlDocument = nil;
    
	return success;
}

/* extractFeeds
 * Given a block of XML data, determine whether this is HTML format and, if so,
 * extract all RSS links in the data. Returns YES if we found any feeds, or NO if
 * this was not HTML.
 */
+(BOOL)extractFeeds:(NSData *)xmlData toArray:(NSMutableArray *)linkArray
{
	BOOL success = NO;
	@try {
	NSArray * arrayOfTags = [XMLTag parserFromData:xmlData];
	if (arrayOfTags != nil)
	{
		for (XMLTag * tag in arrayOfTags)
		{
			NSString * tagName = [tag name];

			if ([tagName isEqualToString:@"rss"] || [tagName isEqualToString:@"rdf:rdf"] || [tagName isEqualToString:@"feed"])
			{
				success = NO;
				break;
			}
			if ([tagName isEqualToString:@"link"])
			{
				NSDictionary * tagAttributes = [tag attributes];
				NSString * linkType = [tagAttributes objectForKey:@"type"];

				// We're looking for the link tag. Specifically we're looking for the one which
				// has application/rss+xml or atom+xml type. There may be more than one which is why we're
				// going to be returning an array.
				if ([linkType isEqualToString:@"application/rss+xml"])
				{
					NSString * href = [tagAttributes objectForKey:@"href"];
					if (href != nil)
						[linkArray addObject:href];
				}
				else if ([linkType isEqualToString:@"application/atom+xml"])
				{
					NSString * href = [tagAttributes objectForKey:@"href"];
					if (href != nil)
						[linkArray addObject:href];
				}
			}
			if ([tagName isEqualToString:@"/head"])
				break;
			success = [linkArray count] > 0;
		}
	}
	}
	@catch (NSException *error) {
		success = NO;
	}
	return success;
}

/* preFlightValidation
 * Try and sanitise the XML data before the XML parser gets a chance to reject it. This
 * should address the most common bad-feed errors until we can change the parser to one
 * that provides us more control.
 */
-(NSData *)preFlightValidation:(NSData *)xmlData
{
	NSUInteger count = [xmlData length];
	const unsigned char * srcPtr = [xmlData bytes];
	const unsigned char * srcEndPtr = srcPtr + count;

	// We'll create another data stream with the converted characters
	NSMutableData * newXmlData = [NSMutableData dataWithLength:count];
	char * destPtr = [newXmlData mutableBytes];
	NSUInteger destCapacity = count;
	NSUInteger destSize = count;
	NSUInteger destIndex = 0;

	// Determine XML encoding and BOM
	NSStringEncoding encodedType;

	if ( (count > 2 && srcPtr[0] == 0xFE && srcPtr[1] == 0xFF) ||
		  (count > 2 && srcPtr[0] == 0xFF && srcPtr[1] == 0xFE) )
	{
		// Copy Unicode UTF-16 big/little-endian BOM.
		destPtr[destIndex++] = srcPtr[0];
		destPtr[destIndex++] = srcPtr[1];
		srcPtr += 2;

		char* encodingNameStr = "UTF-16";
		CFStringRef encodingName = CFStringCreateWithBytes(kCFAllocatorDefault, (unsigned char *)encodingNameStr, strlen(encodingNameStr), kCFStringEncodingISOLatin1, false);
		encodedType = CFStringConvertIANACharSetNameToEncoding(encodingName);
		CFRelease(encodingName);
	}

	else if (count > 3 && srcPtr[0] == 0xEF && srcPtr[1] == 0xBB && srcPtr[2] == 0xBF)
	{
		// Copy Unicode UTF-8 little-endian BOM.
		destPtr[destIndex++] = srcPtr[0];
		destPtr[destIndex++] = srcPtr[1];
		destPtr[destIndex++] = srcPtr[2];
		srcPtr += 3;

		char* encodingNameStr = "UTF-8";
		CFStringRef encodingName = CFStringCreateWithBytes(kCFAllocatorDefault, (unsigned char *)encodingNameStr, strlen(encodingNameStr), kCFStringEncodingISOLatin1, false);
		encodedType = CFStringConvertIANACharSetNameToEncoding(encodingName);
		CFRelease(encodingName);
	}

	else
	{
		// Lets see if we have any better luck parsing the XML
		encodedType = [self parseEncodingType:xmlData];
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
-(BOOL)initRSSFeed:(NSXMLElement *)rssElement isRDF:(BOOL)isRDF
{
    BOOL success = NO;
    NSXMLElement *channelElement = [self channelElementFromRSSElement:rssElement];
    success = [self initRSSFeedHeaderWithElement:channelElement];
    if (success) {
        if (isRDF) {
            success = [self initRSSFeedItems:rssElement];
        } else {
            success = [self initRSSFeedItems:channelElement];
        }
    }
    return success;
}

/**
 *  Get the root of the RSS feed's channel.
 *
 *  @param rssElement The rss element of the feed
 *
 *  @return the channel element
 */
-(NSXMLElement *)channelElementFromRSSElement:(NSXMLElement *)rssElement
{
	NSXMLElement *channelElement = [rssElement elementsForName:@"channel"].firstObject;
    if (channelElement == nil) {
        channelElement = [rssElement elementsForName:@"rss:channel"].firstObject;
    }
    return channelElement;
}


/**
 *  Parse an RSS feed's header items
 *
 *  @param channelElement the element containing header items.
 *  This is typically a channel element for RSS feeds
 *
 *  @return YES on success
 */
-(BOOL)initRSSFeedHeaderWithElement:(NSXMLElement *)channelElement
{
	BOOL success = NO;
	
	// Iterate through the channel items
	for (NSXMLElement *element in channelElement.children)
	{
		// Parse title
		if ([element.localName isEqualToString:@"title"])
		{
			[self setTitle:[element.stringValue stringByUnescapingExtendedCharacters]];
            success = YES;
			continue;
		}
		// Parse items group which dictates the sequence of the articles.
		if ([element.localName isEqualToString:@"items"])
		{
            NSXMLElement *seqElement = [element elementsForName:@"rdf:Seq"].firstObject;

            if (seqElement != nil) {
				[self parseSequence:seqElement];
            }
		}

		// Parse description
		if ([element.localName isEqualToString:@"description"])
		{
			[self setDescription:element.stringValue];
			continue;
		}			
		
		// Parse link
		if ([element.localName isEqualToString:@"link"])
		{
			[self setLink:[element.stringValue stringByUnescapingExtendedCharacters]];
			continue;
		}			
		
		// Parse the date when this feed was last updated
		if ([element.localName isEqualToString:@"lastBuildDate"] ||
            [element.localName isEqualToString:@"pubDate"] ||
            [element.localName isEqualToString:@"date"])
		{
			NSString * dateString = element.stringValue;
			[self setLastModified:[NSDate parseXMLDate:dateString]];
			continue;
		}
	}
	return success;
}


/**
 *  Parses an RDF sequence and initialises orderArray with the appropriate sequence.
 *  The RSS parser will then use this to order the actual items appropriately.
 *
 *  @param seqElement the sequence element
 */
-(void)parseSequence:(NSXMLElement *)seqElement
{
	[orderArray release];
	orderArray = [[NSMutableArray alloc] init];
    for (NSXMLElement *element in seqElement.children)
	{
        if ([element.localName isEqualToString:@"li"]) {
            NSString *resourceString = [[element attributeForName:@"rdf:resource"] stringValue];
            if (resourceString == nil) {
                resourceString = [[element attributeForName:@"resource"] stringValue];
            }
            if (resourceString != nil) {
                [orderArray addObject:resourceString];
            }
            
        }
	}
}

/* initRSSFeedItems
 * Parse the items from an RSS feed
 */
-(BOOL)initRSSFeedItems:(NSXMLElement *)startElement
{
	BOOL success = YES;

	// Allocate an items array
	NSAssert(items == nil, @"initRSSFeedItems called more than once per initialisation");
	items = [[NSMutableArray alloc] init];
    
    for (NSXMLElement *element in startElement.children)
	{
		// Parse a single item to construct a FeedItem object which is appended to
		// the items array we maintain.
		if ([element.localName isEqualToString:@"item"])
		{
			FeedItem * newFeedItem = [[FeedItem new] autorelease];
			NSMutableString * articleBody = nil;
			BOOL hasDetailedContent = NO;
			BOOL hasLink = NO;

			// Check for rdf:about so we can identify this item in the orderArray.
            NSString *itemIdentifier = [[element attributeForName:@"rdf:about"] stringValue];

			for (NSXMLElement *itemChildElement in element.children)
			{
				// Parse item title
				if ([itemChildElement.localName isEqualToString:@"title"])
				{
                    [newFeedItem setTitle:[itemChildElement.stringValue summaryTextFromHTML]];
					continue;
				}
				
				// Parse item description
				if (([itemChildElement.localName isEqualToString:@"description"]) &&
                    !hasDetailedContent)
				{
                    articleBody = [NSMutableString stringWithString:itemChildElement.stringValue];
					continue;
				}
				
				// Parse GUID. The GUID may optionally have a permaLink attribute
				// in which case this is also the article link unless overridden by
				// an explicit link tag.
				if ([itemChildElement.localName isEqualToString:@"guid"])
				{
                    NSString * permaLink = [itemChildElement
                                            attributeForName:@"isPermaLink"].stringValue;

                    if (permaLink && [permaLink isEqualToString:@"true"] && !hasLink) {
                        [newFeedItem setLink:itemChildElement.stringValue];
                    }
					[newFeedItem setGuid:itemChildElement.stringValue];
					continue;
				}
				
				// Parse detailed item description. This overrides the existing
				// description for this item.
				if ([itemChildElement.localName isEqualToString:@"encoded"])
				{
                    articleBody = [NSMutableString stringWithString:itemChildElement.stringValue];
					hasDetailedContent = YES;
					continue;
				}
				
                // Parse item author
				if ([itemChildElement.localName isEqualToString:@"author"])
				{
					NSString *authorName = itemChildElement.stringValue;
                    
                    // the author is in the feed's entry
                    if (authorName != nil) {
                        // if we currently have a string set as the author then append the new author name
                        if ([[newFeedItem author] length] > 0) {
                            [newFeedItem setAuthor:[NSString stringWithFormat:
                            NSLocalizedString(@"%@, %@", @"{existing authors},{new author name}"), [newFeedItem author], authorName]];
                        }
                        // else we currently don't have an author set, so set it to the first author
                        else {
                            [newFeedItem setAuthor:authorName];
                        }
                    }
                    continue;
				}
				
				// Parse item date
				if ([itemChildElement.localName isEqualToString:@"date"] ||
                    [itemChildElement.localName isEqualToString:@"pubDate"])
				{
					NSString * dateString = itemChildElement.stringValue;
					[newFeedItem setDate:[NSDate parseXMLDate:dateString]];
					continue;
				}
				
				// Parse item link
				if ([itemChildElement.localName isEqualToString:@"link"])
				{
					[newFeedItem setLink:[itemChildElement.stringValue stringByUnescapingExtendedCharacters]];
					hasLink = YES;
					continue;
				}
				
				// Parse associated enclosure
				if ([itemChildElement.localName isEqualToString:@"enclosure"])
				{
                    if ([itemChildElement attributeForName:@"url"].stringValue) {
                        [newFeedItem setEnclosure:[itemChildElement attributeForName:@"url"].stringValue];
                    }
					continue;
				}

			}
			
			// If no link, set it to the feed link if there is one
			if (!hasLink && [self link])
				[newFeedItem setLink:[self link]];

			// Do relative IMG, IFRAME and A tags fixup
			[articleBody fixupRelativeImgTags:[self link]];
			[articleBody fixupRelativeIframeTags:[self link]];
			[articleBody fixupRelativeAnchorTags:[self link]];
			[newFeedItem setDescription:SafeString(articleBody)];

			// Derive any missing title
			[self ensureTitle:newFeedItem];
			
			// Add this item in the proper location in the array
			NSUInteger indexOfItem = (orderArray && itemIdentifier) ? [orderArray indexOfStringInArray:itemIdentifier] : NSNotFound;
            if (indexOfItem == NSNotFound || indexOfItem >= [items count]) {
				[items addObject:newFeedItem];
            }
            else {
				[items insertObject:newFeedItem atIndex:indexOfItem];
            }
		}
	}

	return success;
}

/* initAtomFeed
 * Prime the feed with header and items from an Atom feed
 */
-(BOOL)initAtomFeed:(NSXMLElement *)atomElement
{
	BOOL success = NO;
	
	// Allocate an items array
	NSAssert(items == nil, @"initAtomFeed called more than once per initialisation");
    items = [[NSMutableArray alloc] init];
	
	// Look for feed attributes we need to process
	NSString * linkBase = [[atomElement attributeForName:@"xml:base"].stringValue stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    if (linkBase == nil) {
		linkBase = [[self link] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
	NSURL * linkBaseURL = (linkBase != nil) ? [NSURL URLWithString:linkBase] : nil;

	// Iterate through the atom items
	NSString * defaultAuthor = @"";

	for (NSXMLElement *atomChildElement in atomElement.children)
	{
		// Parse title
		if ([atomChildElement.localName isEqualToString:@"title"])
		{
			[self setTitle:[[atomChildElement.stringValue stringByUnescapingExtendedCharacters] summaryTextFromHTML]];
            success = YES;
			continue;
		}
		
		// Parse description]
		if ([atomChildElement.localName isEqualToString:@"subtitle"])
		{
			[self setDescription:atomChildElement.stringValue];
			continue;
		}			
		
		// Parse description
		if ([atomChildElement.localName isEqualToString:@"tagline"])
		{
			[self setDescription:atomChildElement.stringValue];
			continue;
		}			

		// Parse link
		if ([atomChildElement.localName isEqualToString:@"link"])
		{
			if ([atomChildElement attributeForName:@"rel"].stringValue == nil ||
                 [[atomChildElement attributeForName:@"rel"].stringValue isEqualToString:@"alternate"])
			{
				NSString * theLink = [[atomChildElement attributeForName:@"href"].stringValue stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				if (theLink != nil)
				{
					if ((linkBaseURL != nil) && ![theLink hasPrefix:@"http://"] && ![theLink hasPrefix:@"https://"])
					{
						NSURL * theLinkURL = [NSURL URLWithString:theLink relativeToURL:linkBaseURL];
						[self setLink:(theLinkURL != nil) ? [theLinkURL absoluteString] : theLink];
					}
					else
						[self setLink:theLink];
				}
			}

			if (linkBase == nil)
				linkBase = [[self link] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

			continue;
		}			
		
		// Parse author at the feed level. This is the default for any entry
		// that doesn't have an explicit author.
		if ([atomChildElement.localName isEqualToString:@"author"])
		{
            NSXMLElement *nameElement = [atomChildElement elementsForName:@"name"].firstObject;
			if (nameElement != nil)
				defaultAuthor = nameElement.stringValue;
			continue;
		}
		
		// Parse the date when this feed was last updated
		if ([atomChildElement.localName isEqualToString:@"updated"])
		{
			NSString * dateString = atomChildElement.stringValue;
			[self setLastModified:[NSDate parseXMLDate:dateString]];
			continue;
		}
		
		// Parse the date when this feed was last updated
		if ([atomChildElement.localName isEqualToString:@"modified"])
		{
			NSString * dateString = atomChildElement.stringValue;
			[self setLastModified:[NSDate parseXMLDate:dateString]];
			continue;
		}
		
		// Parse a single item to construct a FeedItem object which is appended to
		// the items array we maintain.
		if ([atomChildElement.localName isEqualToString:@"entry"])
		{
			FeedItem * newFeedItem = [[FeedItem new] autorelease];
			NSMutableString * articleBody = nil;

			// Look for the xml:base attribute, and use absolute url or stack relative url
            NSString *entryBase = [[atomChildElement attributeForName:@"xml:base"].stringValue stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            if (entryBase == nil) {
				entryBase = linkBase;
            }
            
			NSURL * entryBaseURL = (entryBase != nil) ? [NSURL URLWithString:entryBase] : nil;
			if ((entryBaseURL != nil) && (linkBaseURL != nil) && ([entryBaseURL scheme] == nil))
			{
				entryBaseURL = [NSURL URLWithString:entryBase relativeToURL:linkBaseURL];
				if (entryBaseURL != nil)
					entryBase = [entryBaseURL absoluteString];
			}

			for (NSXMLElement *itemChildElement in atomChildElement.children)
			{
				// Parse item title
				if ([itemChildElement.localName isEqualToString:@"title"])
				{
					[newFeedItem setTitle:[itemChildElement.stringValue summaryTextFromHTML]];
					continue;
				}

				// Parse item description
				if ([itemChildElement.localName isEqualToString:@"content"])
				{
					articleBody = [[[NSMutableString alloc] initWithString:itemChildElement.stringValue] autorelease];
					continue;
				}
				
				// Parse item description
				if ([itemChildElement.localName isEqualToString:@"summary"])
				{
					articleBody = [[[NSMutableString alloc] initWithString:itemChildElement.stringValue] autorelease];
					continue;
				}
				
				// Parse item author
				if ([itemChildElement.localName isEqualToString:@"author"])
				{
					NSString * authorName = [[itemChildElement elementsForName:@"name"].firstObject stringValue];
					if (authorName == nil) {
						authorName = [[itemChildElement elementsForName:@"email"].firstObject stringValue];
                    }
                    // the author is in the feed's entry
					if (authorName != nil) {
						// if we currently have a string set as the author then append the new author name
                        if ([[newFeedItem author] length] > 0) {
                            [newFeedItem setAuthor:[NSString stringWithFormat:NSLocalizedString(@"%@, %@", @"{existing authors},{new author name}"), [newFeedItem author], authorName]];
                        }
                        // else we currently don't have an author set, so set it to the first author
                        else {
                            [newFeedItem setAuthor:authorName];
                        }
                    }
					continue;
				}
				
				// Parse item link
				if ([itemChildElement.localName isEqualToString:@"link"])
				{
					if ([[itemChildElement attributeForName:@"rel"].stringValue isEqualToString:@"enclosure"] ||
                        [[itemChildElement attributeForName:@"rel"].stringValue isEqualToString:@"http://opds-spec.org/acquisition"])
					{
						NSString * theLink = [[itemChildElement attributeForName:@"href"].stringValue stringByUnescapingExtendedCharacters];
						if (theLink != nil)
						{
							if ((entryBaseURL != nil) && ([[NSURL URLWithString:theLink] scheme] == nil))
							{
								NSURL * theLinkURL = [NSURL URLWithString:theLink relativeToURL:entryBaseURL];
								[newFeedItem setEnclosure:(theLinkURL != nil) ? [theLinkURL absoluteString] : theLink];
							}
							else
								[newFeedItem setEnclosure:theLink];
					}
				}
				else
				{
					if ([itemChildElement attributeForName:@"rel"].stringValue == nil ||
                        [[itemChildElement attributeForName:@"rel"].stringValue isEqualToString:@"alternate"])
					{
						NSString * theLink = [[itemChildElement attributeForName:@"href"].stringValue stringByUnescapingExtendedCharacters];
						if (theLink != nil)
						{
							if ((entryBaseURL != nil) && ([[NSURL URLWithString:theLink] scheme] == nil))
							{
								NSURL * theLinkURL = [NSURL URLWithString:theLink relativeToURL:entryBaseURL];
								[newFeedItem setLink:(theLinkURL != nil) ? [theLinkURL absoluteString] : theLink];
							}
							else
								[newFeedItem setLink:theLink];
						}
					}
					continue;
				}
				}
				
				// Parse item id
				if ([itemChildElement.localName isEqualToString:@"id"])
				{
					[newFeedItem setGuid:itemChildElement.stringValue];
					continue;
				}

				// Parse item date
				if ([itemChildElement.localName isEqualToString:@"modified"])
				{
					NSString * dateString = itemChildElement.stringValue;
					NSDate * newDate = [NSDate parseXMLDate:dateString];
					if ([newFeedItem date] == nil || [newDate isGreaterThan:[newFeedItem date]])
						[newFeedItem setDate:newDate];
					continue;
				}

				// Parse item date
				if ([itemChildElement.localName isEqualToString:@"created"])
				{
                    NSString * dateString = itemChildElement.stringValue;
                    NSDate * newDate = [NSDate parseXMLDate:dateString];
                    if ([newFeedItem date] == nil || [newDate isGreaterThan:[newFeedItem date]])
                        [newFeedItem setDate:newDate];
                    continue;
				}
				
				// Parse item date
				if ([itemChildElement.localName isEqualToString:@"updated"])
				{
                    NSString * dateString = itemChildElement.stringValue;
                    NSDate * newDate = [NSDate parseXMLDate:dateString];
                    if ([newFeedItem date] == nil || [newDate isGreaterThan:[newFeedItem date]])
                        [newFeedItem setDate:newDate];
                    continue;
				}
			}

			// if we didn't find an author, set it to the default one
			if ([[newFeedItem author] isEqualToString:@""])
				[newFeedItem setAuthor:defaultAuthor];

			// Do relative IMG, IFRAME and A tags fixup
			[articleBody fixupRelativeImgTags:entryBase];
			[articleBody fixupRelativeIframeTags:entryBase];
			[articleBody fixupRelativeAnchorTags:entryBase];
			[newFeedItem setDescription:SafeString(articleBody)];
			
			// Derive any missing title
			[self ensureTitle:newFeedItem];
			[items addObject:newFeedItem];
            success = YES;
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

/* ensureTitle
 * Make sure we have a title and synthesize one from the description if we don't.
 */
-(void)ensureTitle:(FeedItem *)item
{
	if (![item title] || [[item title] isBlank])
	{
		NSString * newTitle = [[[item description] titleTextFromHTML] stringByUnescapingExtendedCharacters];
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
	orderArray=nil;
	[title release];
	title=nil;
	[description release];
	description=nil;
	[lastModified release];
	lastModified=nil;
	[link release];
	link=nil;
	[items release];
	items=nil;
	[super dealloc];
}
@end
