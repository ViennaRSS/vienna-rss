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
#import "NSDate+Vienna.h"
#import "Vienna-Swift.h"

@interface RichXMLParser ()

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
-(void)identifyNamespacesPrefixes:(NSXMLElement *)element;

@end

@implementation RichXMLParser

/* parseRichXML
 * Given an XML feed in xmlData, parses the feed as either an RSS or an Atom feed.
 * The actual parsed items can subsequently be accessed through the interface.
 */
-(BOOL)parseRichXML:(NSData *)xmlData
{
    BOOL success = NO;
    NSError * error = nil;
    NSXMLDocument * xmlDocument;

    @try {
        xmlDocument = [[NSXMLDocument alloc] initWithData:xmlData
                                                  options:NSXMLNodeLoadExternalEntitiesNever
                                                    error:&error];
        if (xmlDocument == nil && error != nil) {
            if ([error.domain isEqualToString:NSXMLParserErrorDomain]) {
                // handle here cases identified to cause
                // application crashes caused by
                // NSXMLDocument's -initWithData:options:error
                // when option NSXMLDocumentTidyXML is enabled
                switch (error.code) {
                    case NSXMLParserGTRequiredError:
                        return NO;
                    case NSXMLParserTagNameMismatchError:
                        return NO;
                    case NSXMLParserEmptyDocumentError:
                        return NO;
                }
            }

            // recover some cases like text encoding errors, non standard tags...
            xmlDocument = [[NSXMLDocument alloc] initWithData:xmlData
                                                      options:NSXMLDocumentTidyXML|NSXMLNodeLoadExternalEntitiesNever
                                                        error:&error];
        }
    } @catch (NSException * exception) {
        xmlDocument = nil;
    }

    if (xmlDocument != nil) {
        if ([(xmlDocument.rootElement).name isEqualToString:@"rss"]) {
            success = [self initRSSFeed:xmlDocument.rootElement isRDF:NO];
        } else if ([(xmlDocument.rootElement).name isEqualToString:@"rdf:RDF"]) {
            success = [self initRSSFeed:xmlDocument.rootElement isRDF:YES];
        } else if ([(xmlDocument.rootElement).name isEqualToString:@"feed"]) {
            success = [self initAtomFeed:xmlDocument.rootElement];
        }
    }
    xmlDocument = nil;

    return success;
} /* parseRichXML */

/* initRSSFeed
 * Prime the feed with header and items from an RSS feed
 */
-(BOOL)initRSSFeed:(NSXMLElement *)rssElement isRDF:(BOOL)isRDF
{
    BOOL success = NO;

    [self identifyNamespacesPrefixes:rssElement];
    NSXMLElement * channelElement = [self channelElementFromRSSElement:rssElement];
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
    NSXMLElement * channelElement;

    if ([rssPrefix isEqualToString:@""]) {
        channelElement = [rssElement elementsForName:@"channel"].firstObject;
    } else {
        channelElement = [rssElement elementsForName:[NSString stringWithFormat:@"%@:channel", rssPrefix]].firstObject;
    }
    return channelElement;
}

/**
 *  Identify the prefixes used for namespaces we handle, if defined
 *  If prefixes are not defined in our data, set to frequently used ones
 *
 *  @param element The rss of atom element of the feed
 *
 */
-(void)identifyNamespacesPrefixes:(NSXMLElement *)element
{
    // default : empty
    rssPrefix = [element resolvePrefixForNamespaceURI:@"http://purl.org/net/rss1.1#"];     // RSS 1.1
    if (!rssPrefix) {
        rssPrefix = [element resolvePrefixForNamespaceURI:@"http://purl.org/rss/1.0/"];     // RSS 1.0
    }
    if (!rssPrefix) {
        rssPrefix = @"";
    }

    // default : 'rdf'
    rdfPrefix = [element resolvePrefixForNamespaceURI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#"];
    if (!rdfPrefix) {
        rdfPrefix = @"rdf";
    }

    // default : empty
    atomPrefix = [element resolvePrefixForNamespaceURI:@"http://www.w3.org/2005/Atom"];
    if (!atomPrefix) {
        atomPrefix = @"";
    }

    // default : 'dc'
    dcPrefix = [element resolvePrefixForNamespaceURI:@"http://purl.org/dc/elements/1.1/"];
    if (!dcPrefix) {
        dcPrefix = @"dc";
    }

    // default : 'content'
    contentPrefix = [element resolvePrefixForNamespaceURI:@"http://purl.org/rss/1.0/modules/content/"];
    if (!contentPrefix) {
        contentPrefix = @"content";
    }

    // default : 'media'
    mediaPrefix = [element resolvePrefixForNamespaceURI:@"http://search.yahoo.com/mrss/"];
    if (!mediaPrefix) {
        mediaPrefix = @"media";
    }

    // default : 'enc'
    encPrefix = [element resolvePrefixForNamespaceURI:@"http://purl.oclc.org/net/rss_2.0/enc#"];
    if (!encPrefix) {
        encPrefix = @"enc";
    }
} /* identifyNamespacesPrefixes */

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
    for (NSXMLElement * element in channelElement.children) {
        NSString * channelItemTag = element.localName;
        BOOL isRSSElement = [element.prefix isEqualToString:rssPrefix];

        // Parse title
        if (isRSSElement && [channelItemTag isEqualToString:@"title"]) {
            [self setTitle:(element.stringValue).vna_stringByUnescapingExtendedCharacters];
            success = YES;
            continue;
        }
        // Parse items group which dictates the sequence of the articles.
        if (isRSSElement && [channelItemTag isEqualToString:@"items"]) {
            NSXMLElement * seqElement = [element elementsForName:[NSString stringWithFormat:@"%@:Seq", rdfPrefix]].firstObject;

            if (seqElement != nil) {
                [self parseSequence:seqElement];
            }
        }

        // Parse description
        if (isRSSElement && [channelItemTag isEqualToString:@"description"]) {
            [self setDescription:element.stringValue];
            success = YES;
            continue;
        }

        // Parse link
        if (isRSSElement && [channelItemTag isEqualToString:@"link"]) {
            [self setLink:(element.stringValue).vna_stringByUnescapingExtendedCharacters];
            success = YES;
            continue;
        }

        // Parse the date when this feed was last updated
        if ((isRSSElement && [channelItemTag isEqualToString:@"lastBuildDate"]) ||
            (isRSSElement && [channelItemTag isEqualToString:@"pubDate"]) ||
            ([element.prefix isEqualToString:dcPrefix] && [channelItemTag isEqualToString:@"date"]) ) {
            NSString * dateString = element.stringValue;
            [self setLastModified:[NSDate vna_parseXMLDate:dateString]];
            success = YES;
            continue;
        }
    }
    return success;
} /* initRSSFeedHeaderWithElement */


/**
 *  Parses an RDF sequence and initialises orderArray with the appropriate sequence.
 *  The RSS parser will then use this to order the actual items appropriately.
 *
 *  @param seqElement the sequence element
 */
-(void)parseSequence:(NSXMLElement *)seqElement
{
    orderArray = [[NSMutableArray alloc] init];
    for (NSXMLElement * element in seqElement.children) {
        if ([element.name isEqualToString:[NSString stringWithFormat:@"%@:li", rdfPrefix]]) {
            NSString * resourceString = [element attributeForName:[NSString stringWithFormat:@"%@:resource", rdfPrefix]].stringValue;
            if (resourceString == nil) {
                resourceString = [element attributeForName:@"resource"].stringValue;
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

    for (NSXMLElement * element in startElement.children) {
        // Parse a single item to construct a FeedItem object which is appended to
        // the items array we maintain.
        if ([element.prefix isEqualToString:rssPrefix] && [element.localName isEqualToString:@"item"]) {
            FeedItem * newFeedItem = [FeedItem new];
            NSMutableString * articleBody = nil;
            BOOL hasDetailedContent = NO;
            BOOL hasLink = NO;

            // Check for rdf:about so we can identify this item in the orderArray.
            NSString * itemIdentifier = [element attributeForName:[NSString stringWithFormat:@"%@:about", rdfPrefix]].stringValue;

            for (NSXMLElement * itemChildElement in element.children) {
                BOOL isRSSElement = [itemChildElement.prefix isEqualToString:rssPrefix];
                NSString * articleItemTag = itemChildElement.localName;

                // Parse item title
                if (isRSSElement && [articleItemTag isEqualToString:@"title"]) {
                    newFeedItem.title = (itemChildElement.stringValue).vna_summaryTextFromHTML;
                    continue;
                }

                // Parse item description
                if (isRSSElement && [articleItemTag isEqualToString:@"description"] &&
                    !hasDetailedContent) {
                    NSString * type = [itemChildElement attributeForName:@"type"].stringValue;
                    if ([type isEqualToString:@"xhtml"]) {
                        articleBody = [NSMutableString stringWithString:itemChildElement.XMLString];
                    } else if (type != nil && ![type isEqualToString:@"text/xml"] && ![type isEqualToString:@"text/html"] &&
                               [type rangeOfString:@"text" options:NSRegularExpressionSearch | NSCaseInsensitiveSearch].location != NSNotFound) {
                        // 'type' attribute is 'text*' and not 'text/xml' nor 'text/html'
                        articleBody = [[NSString vna_stringByConvertingHTMLEntities:itemChildElement.stringValue] mutableCopy];
                    } else {
                        articleBody = [NSMutableString stringWithString:itemChildElement.stringValue];
                    }
                    continue;
                }

                // Parse GUID. The GUID may optionally have a permaLink attribute
                // in which case this is also the article link unless overridden by
                // an explicit link tag.
                if (isRSSElement && [articleItemTag isEqualToString:@"guid"]) {
                    NSString * permaLink = [itemChildElement
                                            attributeForName:@"isPermaLink"].stringValue;

                    if (permaLink && [permaLink isEqualToString:@"true"] && !hasLink) {
                        newFeedItem.link = itemChildElement.stringValue;
                    }
                    newFeedItem.guid = itemChildElement.stringValue;
                    continue;
                }

                // Parse detailed item description. This overrides the existing
                // description for this item.
                if ([itemChildElement.prefix isEqualToString:contentPrefix] && [articleItemTag isEqualToString:@"encoded"]) {
                    articleBody = [NSMutableString stringWithString:itemChildElement.stringValue];
                    hasDetailedContent = YES;
                    continue;
                }

                // Parse item author
                if ( (isRSSElement && [articleItemTag isEqualToString:@"author"])
                     || ([itemChildElement.prefix isEqualToString:dcPrefix] && [articleItemTag isEqualToString:@"creator"]) ) {
                    NSString *authorName = [itemChildElement.stringValue vna_trimmed];

                    // the author is in the feed's entry
                    if (authorName) {
                        // if we currently have a string set as the author then append the new author name
                        // else we currently don't have an author set, so set it to the first author
                        if (newFeedItem.author.length > 0
                            && [newFeedItem.author rangeOfString:authorName
                                                         options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)].location != NSNotFound) {
                            newFeedItem.author = [NSString stringWithFormat:NSLocalizedString(@"%@, %@", @"{existing authors}, {new author name}"), newFeedItem.author, authorName];
                        } else {
                            newFeedItem.author = authorName;
                        }
                    }
                    continue;
                }

                // Parse item date
                if ( (isRSSElement && [articleItemTag isEqualToString:@"pubDate"])
                     || ([itemChildElement.prefix isEqualToString:dcPrefix] && [articleItemTag isEqualToString:@"date"]) ) {
                    NSString * dateString = itemChildElement.stringValue;
                    newFeedItem.date = [NSDate vna_parseXMLDate:dateString];
                    continue;
                }

                // Parse item link
                if (isRSSElement && [articleItemTag isEqualToString:@"link"]) {
                    newFeedItem.link = (itemChildElement.stringValue).vna_stringByUnescapingExtendedCharacters;
                    hasLink = YES;
                    continue;
                }

                // Parse associated enclosure
                if ( (isRSSElement && [articleItemTag isEqualToString:@"enclosure"])
                     || ([itemChildElement.prefix isEqualToString:mediaPrefix] && [articleItemTag isEqualToString:@"content"]) ) {
                    if ([itemChildElement attributeForName:@"url"].stringValue) {
                        newFeedItem.enclosure = [itemChildElement attributeForName:@"url"].stringValue;
                    }
                    continue;
                }
                if ([itemChildElement.prefix isEqualToString:encPrefix] && [articleItemTag isEqualToString:@"enclosure"]) {
                    if ([itemChildElement attributeForName:@"url"].stringValue) {
                        newFeedItem.enclosure = [itemChildElement attributeForName:@"url"].stringValue;
                    }
                    NSString * resourceString = [NSString stringWithFormat:@"%@:resource", rdfPrefix];
                    if ([itemChildElement attributeForName:resourceString].stringValue) {
                        newFeedItem.enclosure = [itemChildElement attributeForName:resourceString].stringValue;
                    }
                    continue;
                }

                // Parse media group
                if ([itemChildElement.prefix isEqualToString:mediaPrefix] && [articleItemTag isEqualToString:@"group"]) {
                    if ([newFeedItem.enclosure isEqualToString:@""]) {
                        // group's first enclosure
                        NSString *enclosureString = [NSString stringWithFormat:@"%@:content", mediaPrefix];
                        newFeedItem.enclosure =
                            ([[itemChildElement elementsForName:enclosureString].firstObject attributeForName:@"url"]).stringValue;
                    }
                    if (!articleBody) {
                        // use enclosure description as a workaround for feed description
                        NSString *descriptionString = [NSString stringWithFormat:@"%@:description", mediaPrefix];
                        articleBody =
                            [([itemChildElement elementsForName:descriptionString].firstObject).stringValue mutableCopy];
                    }
                    continue;
                }
            }

            // If no link, set it to the feed link if there is one
            if (!hasLink && self.link) {
                newFeedItem.link = self.link;
            }

            // Do relative IMG, IFRAME and A tags fixup
            [articleBody vna_fixupRelativeImgTags:self.link];
            [articleBody vna_fixupRelativeIframeTags:self.link];
            [articleBody vna_fixupRelativeAnchorTags:self.link];
            newFeedItem.feedItemDescription = SafeString(articleBody);

            // Derive any missing title
            [self ensureTitle:newFeedItem];

            // Add this item in the proper location in the array
            NSUInteger index = orderArray && itemIdentifier ? [orderArray indexOfObject:itemIdentifier] : NSNotFound;
            if (index == NSNotFound || index >= items.count) {
                [items addObject:newFeedItem];
            } else {
                [items insertObject:newFeedItem atIndex:index];
            }
        }
    }

    return success;
} /* initRSSFeedItems */

/* initAtomFeed
 * Prime the feed with header and items from an Atom feed
 */
-(BOOL)initAtomFeed:(NSXMLElement *)atomElement
{
    BOOL success = NO;

    [self identifyNamespacesPrefixes:atomElement];

    // Allocate an items array
    NSAssert(items == nil, @"initAtomFeed called more than once per initialisation");
    items = [[NSMutableArray alloc] init];

    // Look for feed attributes we need to process
    NSString * linkBase = [NSString vna_stringByCleaningURLString:[atomElement attributeForName:@"xml:base"].stringValue];
    if (linkBase == nil) {
        linkBase = [NSString vna_stringByCleaningURLString:self.link];
    }
    NSURL * linkBaseURL = (linkBase != nil) ? [NSURL URLWithString:linkBase] : nil;

    // Iterate through the atom items
    NSString * defaultAuthor = @"";

    for (NSXMLElement * atomChildElement in atomElement.children) {
        BOOL isAtomElement =  [atomChildElement.prefix isEqualToString:atomPrefix];
        NSString * elementTag = atomChildElement.localName;

        // Parse title
        if (isAtomElement && [elementTag isEqualToString:@"title"]) {
            [self setTitle:(atomChildElement.stringValue).vna_stringByUnescapingExtendedCharacters.vna_summaryTextFromHTML];
            success = YES;
            continue;
        }

        // Parse description]
        if (isAtomElement && [elementTag isEqualToString:@"subtitle"]) {
            [self setDescription:atomChildElement.stringValue];
            continue;
        }

        // Parse description
        if (isAtomElement && [elementTag isEqualToString:@"tagline"]) {
            [self setDescription:atomChildElement.stringValue];
            continue;
        }

        // Parse link
        if (isAtomElement && [elementTag isEqualToString:@"link"]) {
            if ([atomChildElement attributeForName:@"rel"].stringValue == nil ||
                [[atomChildElement attributeForName:@"rel"].stringValue isEqualToString:@"alternate"]) {
                NSString * theLink = [NSString vna_stringByCleaningURLString:[atomChildElement attributeForName:@"href"].stringValue];
                if (theLink != nil) {
                    if ((linkBaseURL != nil) && ![theLink hasPrefix:@"http://"] && ![theLink hasPrefix:@"https://"]) {
                        NSURL * theLinkURL = [NSURL URLWithString:theLink relativeToURL:linkBaseURL];
                        [self setLink:(theLinkURL != nil) ? theLinkURL.absoluteString : theLink];
                    } else {
                        [self setLink:theLink];
                    }
                }
            }

            if (linkBase == nil) {
                linkBase = [NSString vna_stringByCleaningURLString:self.link];
            }

            success = YES;
            continue;
        }

        // Parse author at the feed level. This is the default for any entry
        // that doesn't have an explicit author.
        if (isAtomElement && [elementTag isEqualToString:@"author"]) {
            NSXMLElement * nameElement = [atomChildElement elementsForName:@"name"].firstObject;
            if (nameElement != nil) {
                defaultAuthor = [nameElement.stringValue vna_trimmed];
            }
            success = YES;
            continue;
        }

        // Parse the date when this feed was last updated
        if (isAtomElement && [elementTag isEqualToString:@"updated"]) {
            NSString * dateString = atomChildElement.stringValue;
            [self setLastModified:[NSDate vna_parseXMLDate:dateString]];
            success = YES;
            continue;
        }

        // Parse the date when this feed was last updated
        if (isAtomElement && [elementTag isEqualToString:@"modified"]) {
            NSString * dateString = atomChildElement.stringValue;
            [self setLastModified:[NSDate vna_parseXMLDate:dateString]];
            success = YES;
            continue;
        }

        // Parse a single item to construct a FeedItem object which is appended to
        // the items array we maintain.
        if (isAtomElement && [elementTag isEqualToString:@"entry"]) {
            FeedItem * newFeedItem = [FeedItem new];
            NSMutableString * articleBody = nil;

            // Look for the xml:base attribute, and use absolute url or stack relative url
            NSString * entryBase = [NSString vna_stringByCleaningURLString:[atomChildElement attributeForName:@"xml:base"].stringValue];
            if (entryBase == nil) {
                entryBase = linkBase;
            }

            NSURL * entryBaseURL = (entryBase != nil) ? [NSURL URLWithString:entryBase] : nil;
            if ((entryBaseURL != nil) && (linkBaseURL != nil) && (entryBaseURL.scheme == nil)) {
                entryBaseURL = [NSURL URLWithString:entryBase relativeToURL:linkBaseURL];
                if (entryBaseURL != nil) {
                    entryBase = entryBaseURL.absoluteString;
                }
            }

            for (NSXMLElement * itemChildElement in atomChildElement.children) {
                BOOL isArticleElementAtomType = [itemChildElement.prefix isEqualToString:atomPrefix];

                NSString * articleItemTag = itemChildElement.localName;

                // Parse item title
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"title"]) {
                    newFeedItem.title = (itemChildElement.stringValue).vna_summaryTextFromHTML;
                    continue;
                }

                // Parse item description
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"content"]) {
                    NSString * type = [itemChildElement attributeForName:@"type"].stringValue;
                    if ([type isEqualToString:@"xhtml"]) {
                        articleBody = [NSMutableString stringWithString:itemChildElement.XMLString];
                    } else if (type != nil && ![type isEqualToString:@"text/xml"] && ![type isEqualToString:@"text/html"] &&
                               [type rangeOfString:@"text" options:NSRegularExpressionSearch | NSCaseInsensitiveSearch].location != NSNotFound) {
                        // 'type' attribute is 'text*' and not 'text/xml' nor 'text/html'
                        articleBody = [[NSString vna_stringByConvertingHTMLEntities:itemChildElement.stringValue] mutableCopy];
                    } else {
                        articleBody = [NSMutableString stringWithString:itemChildElement.stringValue];
                    }
                    continue;
                }

                // Parse item description
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"summary"] && articleBody == nil) {
                    NSString * type = [itemChildElement attributeForName:@"type"].stringValue;
                    if ([type isEqualToString:@"xhtml"]) {
                        articleBody = [NSMutableString stringWithString:itemChildElement.XMLString];
                    } else if (type != nil && ![type isEqualToString:@"text/xml"] &&  ![type isEqualToString:@"text/html"] &&
                               [type rangeOfString:@"text" options:NSRegularExpressionSearch | NSCaseInsensitiveSearch].location != NSNotFound) {
                        // 'type' attribute is 'text*' and not 'text/xml' nor 'text/html'
                        articleBody = [[NSString vna_stringByConvertingHTMLEntities:itemChildElement.stringValue] mutableCopy];
                    } else {
                        articleBody = [NSMutableString stringWithString:itemChildElement.stringValue];
                    }
                    continue;
                }

                // Parse item author
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"author"]) {
                    NSString *authorName = ([itemChildElement elementsForName:@"name"].firstObject).stringValue;
                    authorName = [authorName vna_trimmed];
                    if (!authorName) {
                        authorName = ([itemChildElement elementsForName:@"email"].firstObject).stringValue;
                    }
                    // the author is in the feed's entry
                    if (authorName) {
                        // if we currently have a string set as the author then append the new author name
                        // else we currently don't have an author set, so set it to the first author
                        if (newFeedItem.author.length > 0
                            && [newFeedItem.author rangeOfString:authorName
                                                         options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)].location != NSNotFound) {
                            newFeedItem.author = [NSString stringWithFormat:NSLocalizedString(@"%@, %@", @"{existing authors}, {new author name}"), newFeedItem.author, authorName];
                        } else {
                            newFeedItem.author = authorName;
                        }
                    }
                    continue;
                }

                // Parse item link
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"link"]) {
                    if ([[itemChildElement attributeForName:@"rel"].stringValue isEqualToString:@"enclosure"] ||
                        [[itemChildElement attributeForName:@"rel"].stringValue isEqualToString:@"http://opds-spec.org/acquisition"]) {
                        NSString * theLink = ([itemChildElement attributeForName:@"href"].stringValue).vna_stringByUnescapingExtendedCharacters;
                        if (theLink != nil) {
                            if ((entryBaseURL != nil) && ([NSURL URLWithString:theLink].scheme == nil)) {
                                NSURL * theLinkURL = [NSURL URLWithString:theLink relativeToURL:entryBaseURL];
                                newFeedItem.enclosure = (theLinkURL != nil) ? theLinkURL.absoluteString : theLink;
                            } else {
                                newFeedItem.enclosure = theLink;
                            }
                        }
                    } else {
                        if ([itemChildElement attributeForName:@"rel"].stringValue == nil ||
                            [[itemChildElement attributeForName:@"rel"].stringValue isEqualToString:@"alternate"]) {
                            NSString * theLink = ([itemChildElement attributeForName:@"href"].stringValue).vna_stringByUnescapingExtendedCharacters;
                            if (theLink != nil) {
                                if ((entryBaseURL != nil) && ([NSURL URLWithString:theLink].scheme == nil)) {
                                    NSURL * theLinkURL = [NSURL URLWithString:theLink relativeToURL:entryBaseURL];
                                    newFeedItem.link = (theLinkURL != nil) ? theLinkURL.absoluteString : theLink;
                                } else {
                                    newFeedItem.link = theLink;
                                }
                            }
                        }
                        continue;
                    }
                }

                // Parse item id
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"id"]) {
                    newFeedItem.guid = itemChildElement.stringValue;
                    continue;
                }

                // Parse item date
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"modified"]) {
                    NSString * dateString = itemChildElement.stringValue;
                    NSDate * newDate = [NSDate vna_parseXMLDate:dateString];
                    if (newFeedItem.date == nil || [newDate isGreaterThan:newFeedItem.date]) {
                        newFeedItem.date = newDate;
                    }
                    continue;
                }

                // Parse item date
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"created"]) {
                    NSString * dateString = itemChildElement.stringValue;
                    NSDate * newDate = [NSDate vna_parseXMLDate:dateString];
                    if (newFeedItem.date == nil || [newDate isGreaterThan:newFeedItem.date]) {
                        newFeedItem.date = newDate;
                    }
                    continue;
                }

                // Parse item date
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"updated"]) {
                    NSString * dateString = itemChildElement.stringValue;
                    NSDate * newDate = [NSDate vna_parseXMLDate:dateString];
                    if (newFeedItem.date == nil || [newDate isGreaterThan:newFeedItem.date]) {
                        newFeedItem.date = newDate;
                    }
                    continue;
                }

                // Parse associated enclosure
                if ([itemChildElement.prefix isEqualToString:mediaPrefix] && [articleItemTag isEqualToString:@"content"]) {
                    if ([itemChildElement attributeForName:@"url"].stringValue) {
                        newFeedItem.enclosure = [itemChildElement attributeForName:@"url"].stringValue;
                    }
                    continue;
                }

                // Parse associated enclosure
                if ([itemChildElement.prefix isEqualToString:encPrefix] && [articleItemTag isEqualToString:@"enclosure"]) {
                    if ([itemChildElement attributeForName:@"url"].stringValue) {
                        newFeedItem.enclosure = [itemChildElement attributeForName:@"url"].stringValue;
                    }
                    NSString * resourceString = [NSString stringWithFormat:@"%@:resource", rdfPrefix];
                    if ([itemChildElement attributeForName:resourceString].stringValue) {
                        newFeedItem.enclosure = [itemChildElement attributeForName:resourceString].stringValue;
                    }
                    continue;
                }

                // Parse media group
                if ([itemChildElement.prefix isEqualToString:mediaPrefix] && [articleItemTag isEqualToString:@"group"]) {
                    if ([newFeedItem.enclosure isEqualToString:@""]) {
                        // group's first enclosure
                        NSString *enclosureString = [NSString stringWithFormat:@"%@:content", mediaPrefix];
                        newFeedItem.enclosure =
                            ([[itemChildElement elementsForName:enclosureString].firstObject attributeForName:@"url"]).stringValue;
                    }
                    if (!articleBody) {
                        // use enclosure description as a workaround for feed description
                        NSString *descriptionString = [NSString stringWithFormat:@"%@:description", mediaPrefix];
                        articleBody =
                            [([itemChildElement elementsForName:descriptionString].firstObject).stringValue mutableCopy];
                    }
                    continue;
                }
            }

            // if we didn't find an author, set it to the default one
            if ([newFeedItem.author isEqualToString:@""]) {
                newFeedItem.author = defaultAuthor;
            }

            // Do relative IMG, IFRAME and A tags fixup
            [articleBody vna_fixupRelativeImgTags:entryBase];
            [articleBody vna_fixupRelativeIframeTags:entryBase];
            [articleBody vna_fixupRelativeAnchorTags:entryBase];
            newFeedItem.feedItemDescription = SafeString(articleBody);

            // Derive any missing title
            [self ensureTitle:newFeedItem];
            [items addObject:newFeedItem];
            success = YES;
        }
    }

    return success;
} /* initAtomFeed */

/* setTitle
 * Set this feed's title string.
 */
-(void)setTitle:(NSString *)newTitle
{
    title = newTitle;
}

/* setDescription
 * Set this feed's description string.
 */
-(void)setDescription:(NSString *)newDescription
{
    description = newDescription;
}

/* setLink
 * Sets this feed's link
 */
-(void)setLink:(NSString *)newLink
{
    link = newLink;
}

/* setLastModified
 * Set the date when this feed was last updated.
 */
-(void)setLastModified:(NSDate *)newDate
{
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
    return [items copy];
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
    if (!item.title || item.title.vna_isBlank) {
        NSString * newTitle = item.feedItemDescription.vna_titleTextFromHTML.vna_stringByUnescapingExtendedCharacters;
        if (newTitle.vna_isBlank) {
            newTitle = NSLocalizedString(@"(No title)", nil);
        }
        item.title = newTitle;
    }
}

@end
