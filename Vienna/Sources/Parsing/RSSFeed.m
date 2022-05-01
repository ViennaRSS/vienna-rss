//
//  RSSFeed.m
//  Vienna
//
//  Copyright 2004-2005 Steve Palmer, 2021-2022 Eitot
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "RSSFeed.h"

#import "NSDate+Vienna.h"
#import "StringExtensions.h"
#import "Vienna-Swift.h"

@interface VNARSSFeed ()

@property (nonatomic) NSMutableArray *orderArray;

@property (copy, nonatomic) NSString *rssPrefix;
@property (copy, nonatomic) NSString *dcPrefix;
@property (copy, nonatomic) NSString *contentPrefix;

@end

@implementation VNARSSFeed

// MARK: Initialization

- (nullable instancetype)initWithXMLRootElement:(NSXMLElement *)rootElement
                                          isRDF:(BOOL)isRDF
{
    self = [super init];
    if (self) {
        BOOL success = [self initRSSFeed:rootElement isRDF:isRDF];
        return success ? self : nil;
    }
    return self;
}

/* initRSSFeed
 * Prime the feed with header and items from an RSS feed
 */
- (BOOL)initRSSFeed:(NSXMLElement *)rssElement isRDF:(BOOL)isRDF
{
    BOOL success = NO;

    [self identifyNamespacesPrefixes:rssElement];
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
- (NSXMLElement *)channelElementFromRSSElement:(NSXMLElement *)rssElement
{
    NSXMLElement *channelElement;

    if ([self.rssPrefix isEqualToString:@""]) {
        channelElement = [rssElement elementsForName:@"channel"].firstObject;
    } else {
        channelElement = [rssElement elementsForName:[NSString stringWithFormat:@"%@:channel", self.rssPrefix]].firstObject;
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
- (BOOL)initRSSFeedHeaderWithElement:(NSXMLElement *)channelElement
{
    BOOL success = NO;

    // Iterate through the channel items
    for (NSXMLElement *element in channelElement.children) {
        NSString *channelItemTag = element.localName;
        BOOL isRSSElement = [element.prefix isEqualToString:self.rssPrefix];

        // Parse title
        if (isRSSElement && [channelItemTag isEqualToString:@"title"]) {
            self.title = element.stringValue.vna_stringByUnescapingExtendedCharacters;
            success = YES;
            continue;
        }
        // Parse items group which dictates the sequence of the articles.
        if (isRSSElement && [channelItemTag isEqualToString:@"items"]) {
            NSXMLElement *seqElement = [element elementsForName:[NSString stringWithFormat:@"%@:Seq", self.rdfPrefix]].firstObject;

            if (seqElement != nil) {
                [self parseSequence:seqElement];
            }
        }

        // Parse description
        if (isRSSElement && [channelItemTag isEqualToString:@"description"]) {
            self.feedDescription = element.stringValue;
            success = YES;
            continue;
        }

        // Parse link
        if (isRSSElement && [channelItemTag isEqualToString:@"link"]) {
            self.homePageURL = (element.stringValue).vna_stringByUnescapingExtendedCharacters;
            success = YES;
            continue;
        }

        // Parse the date when this feed was last updated
        if ((isRSSElement && [channelItemTag isEqualToString:@"lastBuildDate"]) ||
            (isRSSElement && [channelItemTag isEqualToString:@"pubDate"]) ||
            ([element.prefix isEqualToString:self.dcPrefix] && [channelItemTag isEqualToString:@"date"])) {
            NSString *dateString = element.stringValue;
            self.modifiedDate = [NSDate vna_parseXMLDate:dateString];
            success = YES;
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
- (void)parseSequence:(NSXMLElement *)seqElement
{
    self.orderArray = [[NSMutableArray alloc] init];
    for (NSXMLElement *element in seqElement.children) {
        if ([element.name isEqualToString:[NSString stringWithFormat:@"%@:li", self.rdfPrefix]]) {
            NSString *resourceString = [element attributeForName:[NSString stringWithFormat:@"%@:resource", self.rdfPrefix]].stringValue;
            if (resourceString == nil) {
                resourceString = [element attributeForName:@"resource"].stringValue;
            }
            if (resourceString != nil) {
                [self.orderArray addObject:resourceString];
            }
        }
    }
}

- (BOOL)initRSSFeedItems:(NSXMLElement *)startElement
{
    BOOL success = YES;
    NSMutableArray *items = [NSMutableArray array];

    for (NSXMLElement *element in startElement.children) {
        // Parse a single item to construct a FeedItem object which is appended to
        // the items array we maintain.
        if ([element.prefix isEqualToString:self.rssPrefix] && [element.localName isEqualToString:@"item"]) {
            VNAXMLFeedItem *newFeedItem = [VNAXMLFeedItem new];
            NSMutableString *articleBody = nil;
            BOOL hasDetailedContent = NO;
            BOOL hasLink = NO;

            // Check for rdf:about so we can identify this item in the orderArray.
            NSString *itemIdentifier = [element attributeForName:[NSString stringWithFormat:@"%@:about", self.rdfPrefix]].stringValue;

            for (NSXMLElement *itemChildElement in element.children) {
                BOOL isRSSElement = [itemChildElement.prefix isEqualToString:self.rssPrefix];
                NSString *articleItemTag = itemChildElement.localName;

                // Parse item title
                if (isRSSElement && [articleItemTag isEqualToString:@"title"]) {
                    newFeedItem.title = (itemChildElement.stringValue).vna_summaryTextFromHTML;
                    continue;
                }

                // Parse item description
                if (isRSSElement && [articleItemTag isEqualToString:@"description"] &&
                    !hasDetailedContent) {
                    NSString *type = [itemChildElement attributeForName:@"type"].stringValue;
                    if ([type isEqualToString:@"xhtml"]) {
                        articleBody = [NSMutableString stringWithString:itemChildElement.XMLString];
                    } else if (type != nil && ![type isEqualToString:@"text/xml"] && ![type isEqualToString:@"text/html"] &&
                               [type rangeOfString:@"text"
                                           options:NSRegularExpressionSearch | NSCaseInsensitiveSearch]
                                       .location != NSNotFound) {
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
                    NSString *permaLink = [itemChildElement
                                              attributeForName:@"isPermaLink"]
                                              .stringValue;

                    if (permaLink && [permaLink isEqualToString:@"true"] && !hasLink) {
                        newFeedItem.url = itemChildElement.stringValue;
                    }
                    newFeedItem.guid = itemChildElement.stringValue;
                    continue;
                }

                // Parse detailed item description. This overrides the existing
                // description for this item.
                if ([itemChildElement.prefix isEqualToString:self.contentPrefix] && [articleItemTag isEqualToString:@"encoded"]) {
                    articleBody = [NSMutableString stringWithString:itemChildElement.stringValue];
                    hasDetailedContent = YES;
                    continue;
                }

                // Parse item author
                if ((isRSSElement && [articleItemTag isEqualToString:@"author"]) || ([itemChildElement.prefix isEqualToString:self.dcPrefix] && [articleItemTag isEqualToString:@"creator"])) {
                    NSString *authorName = [itemChildElement.stringValue vna_trimmed];

                    // the author is in the feed's entry
                    if (authorName) {
                        // if we currently have a string set as the author then append the new author name
                        // else we currently don't have an author set, so set it to the first author
                        if (newFeedItem.authors.length > 0 &&
                            [newFeedItem.authors rangeOfString:authorName
                                                       options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)]
                                    .location != NSNotFound) {
                            newFeedItem.authors = [NSString stringWithFormat:NSLocalizedString(@"%@, %@", @"{existing authors}, {new author name}"), newFeedItem.authors, authorName];
                        } else {
                            newFeedItem.authors = authorName;
                        }
                    }
                    continue;
                }

                // Parse item date
                if ((isRSSElement && [articleItemTag isEqualToString:@"pubDate"]) || ([itemChildElement.prefix isEqualToString:self.dcPrefix] && [articleItemTag isEqualToString:@"date"])) {
                    NSString *dateString = itemChildElement.stringValue;
                    newFeedItem.modifiedDate = [NSDate vna_parseXMLDate:dateString];
                    continue;
                }

                // Parse item link
                if (isRSSElement && [articleItemTag isEqualToString:@"link"]) {
                    newFeedItem.url = (itemChildElement.stringValue).vna_stringByUnescapingExtendedCharacters;
                    hasLink = YES;
                    continue;
                }

                // Parse associated enclosure
                if ((isRSSElement && [articleItemTag isEqualToString:@"enclosure"]) || ([itemChildElement.prefix isEqualToString:self.mediaPrefix] && [articleItemTag isEqualToString:@"content"])) {
                    if ([itemChildElement attributeForName:@"url"].stringValue) {
                        newFeedItem.enclosure = [itemChildElement attributeForName:@"url"].stringValue;
                    }
                    continue;
                }
                if ([itemChildElement.prefix isEqualToString:self.encPrefix] && [articleItemTag isEqualToString:@"enclosure"]) {
                    if ([itemChildElement attributeForName:@"url"].stringValue) {
                        newFeedItem.enclosure = [itemChildElement attributeForName:@"url"].stringValue;
                    }
                    NSString *resourceString = [NSString stringWithFormat:@"%@:resource", self.rdfPrefix];
                    if ([itemChildElement attributeForName:resourceString].stringValue) {
                        newFeedItem.enclosure = [itemChildElement attributeForName:resourceString].stringValue;
                    }
                    continue;
                }

                // Parse media group
                if ([itemChildElement.prefix isEqualToString:self.mediaPrefix] && [articleItemTag isEqualToString:@"group"]) {
                    if ([newFeedItem.enclosure isEqualToString:@""]) {
                        // group's first enclosure
                        NSString *enclosureString = [NSString stringWithFormat:@"%@:content", self.mediaPrefix];
                        newFeedItem.enclosure =
                            ([[itemChildElement elementsForName:enclosureString].firstObject attributeForName:@"url"]).stringValue;
                    }
                    if (!articleBody) {
                        // use enclosure description as a workaround for feed description
                        NSString *descriptionString = [NSString stringWithFormat:@"%@:description", self.mediaPrefix];
                        articleBody =
                            [([itemChildElement elementsForName:descriptionString].firstObject).stringValue mutableCopy];
                    }
                    continue;
                }
            }

            // If no link, set it to the feed link if there is one
            if (!hasLink && self.homePageURL) {
                newFeedItem.url = self.homePageURL;
            }

            // Do relative IMG, IFRAME and A tags fixup
            [articleBody vna_fixupRelativeImgTags:self.homePageURL];
            [articleBody vna_fixupRelativeIframeTags:self.homePageURL];
            [articleBody vna_fixupRelativeAnchorTags:self.homePageURL];
            newFeedItem.content = SafeString(articleBody);

            // Add this item in the proper location in the array
            NSUInteger index = self.orderArray && itemIdentifier ? [self.orderArray indexOfObject:itemIdentifier] : NSNotFound;
            if (index == NSNotFound || index >= items.count) {
                [items addObject:newFeedItem];
            } else {
                [items insertObject:newFeedItem atIndex:index];
            }
        }
    }

    self.items = items;

    return success;
}

// MARK: Overrides

- (void)identifyNamespacesPrefixes:(NSXMLElement *)element
{
    [super identifyNamespacesPrefixes:element];

    self.rssPrefix = [element resolvePrefixForNamespaceURI:@"http://purl.org/net/rss1.1#"]; // RSS 1.1
    if (!self.rssPrefix) {
        self.rssPrefix = [element resolvePrefixForNamespaceURI:@"http://purl.org/rss/1.0/"]; // RSS 1.0
    }
    if (!self.rssPrefix) {
        self.rssPrefix = @"";
    }

    self.dcPrefix = [element resolvePrefixForNamespaceURI:@"http://purl.org/dc/elements/1.1/"];
    if (!self.dcPrefix) {
        self.dcPrefix = @"dc";
    }

    self.contentPrefix = [element resolvePrefixForNamespaceURI:@"http://purl.org/rss/1.0/modules/content/"];
    if (!self.contentPrefix) {
        self.contentPrefix = @"content";
    }
}

@end
