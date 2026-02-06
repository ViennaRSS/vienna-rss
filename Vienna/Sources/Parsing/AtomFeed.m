//
//  AtomFeed.m
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

#import "AtomFeed.h"

#import "StringExtensions.h"
#import "Vienna-Swift.h"

@interface VNAAtomFeed ()

@property (copy, nonatomic) NSString *atomPrefix;

@end

@implementation VNAAtomFeed

// MARK: Initialization

- (nullable instancetype)initWithXMLRootElement:(NSXMLElement *)rootElement
{
    self = [super init];
    if (self) {
        BOOL success = [self initAtomFeed:rootElement];
        return success ? self : nil;
    }
    return self;
}

/* initAtomFeed
 * Prime the feed with header and items from an Atom feed
 */
- (BOOL)initAtomFeed:(NSXMLElement *)atomElement
{
    BOOL success = NO;

    [self identifyNamespacesPrefixes:atomElement];

    // Look for feed attributes we need to process
    NSString *linkBase = [NSString vna_stringByCleaningURLString:[atomElement attributeForName:@"xml:base"].stringValue];
    if (linkBase == nil) {
        linkBase = [NSString vna_stringByCleaningURLString:self.homePageURL];
    }
    NSURL *linkBaseURL = (linkBase != nil) ? [NSURL URLWithString:linkBase] : nil;

    // Iterate through the atom items
    NSString *defaultAuthor = @"";

    NSMutableArray *items = [NSMutableArray array];

    for (NSXMLElement *atomChildElement in atomElement.children) {
        BOOL isAtomElement = [atomChildElement.prefix isEqualToString:self.atomPrefix];
        NSString *elementTag = atomChildElement.localName;

        // Parse title
        if (isAtomElement && [elementTag isEqualToString:@"title"]) {
            self.title = atomChildElement.stringValue.vna_stringByUnescapingExtendedCharacters.vna_summaryTextFromHTML;
            success = YES;
            continue;
        }

        // Parse description]
        if (isAtomElement && [elementTag isEqualToString:@"subtitle"]) {
            self.feedDescription = atomChildElement.stringValue;
            continue;
        }

        // Parse description
        if (isAtomElement && [elementTag isEqualToString:@"tagline"]) {
            self.feedDescription = atomChildElement.stringValue;
            continue;
        }

        // Parse link
        if (isAtomElement && [elementTag isEqualToString:@"link"]) {
            if ([atomChildElement attributeForName:@"rel"].stringValue == nil ||
                [[atomChildElement attributeForName:@"rel"].stringValue isEqualToString:@"alternate"]) {
                NSString *theLink = [NSString vna_stringByCleaningURLString:[atomChildElement attributeForName:@"href"].stringValue];
                if (theLink != nil) {
                    if ((linkBaseURL != nil) && ![theLink hasPrefix:@"http://"] && ![theLink hasPrefix:@"https://"]) {
                        NSURL *theLinkURL = [NSURL URLWithString:theLink relativeToURL:linkBaseURL];
                        self.homePageURL = theLinkURL ? theLinkURL.absoluteString : theLink;
                    } else {
                        self.homePageURL = theLink;
                    }
                }
            }

            if (linkBase == nil) {
                linkBase = [NSString vna_stringByCleaningURLString:self.homePageURL];
            }

            success = YES;
            continue;
        }

        // Parse author at the feed level. This is the default for any entry
        // that doesn't have an explicit author.
        if (isAtomElement && [elementTag isEqualToString:@"author"]) {
            NSXMLElement *nameElement = [atomChildElement elementsForName:@"name"].firstObject;
            if (nameElement != nil) {
                defaultAuthor = [nameElement.stringValue vna_trimmed];
            }
            success = YES;
            continue;
        }

        // Parse the date when this feed was last updated
        if (isAtomElement && ([elementTag isEqualToString:@"updated"] || [elementTag isEqualToString:@"modified"])) {
            NSString *dateString = atomChildElement.stringValue;
            self.modificationDate = [self dateWithXMLString:dateString];
            success = YES;
            continue;
        }

        // Parse a single item to construct a FeedItem object which is appended to
        // the items array we maintain.
        if (isAtomElement && [elementTag isEqualToString:@"entry"]) {
            VNAXMLFeedItem *newFeedItem = [VNAXMLFeedItem new];
            NSMutableString *articleBody = nil;

            // Look for the xml:base attribute, and use absolute url or stack relative url
            NSString *entryBase = [NSString vna_stringByCleaningURLString:[atomChildElement attributeForName:@"xml:base"].stringValue];

            NSURL *entryBaseURL = [entryBase isEqualToString:@""] ? nil : [NSURL URLWithString:entryBase];
            if ((entryBaseURL != nil) && (linkBaseURL != nil) && (entryBaseURL.scheme == nil)) {
                entryBaseURL = [NSURL URLWithString:entryBase relativeToURL:linkBaseURL];
                if (entryBaseURL != nil) {
                    entryBase = entryBaseURL.absoluteString;
                }
            }

            for (NSXMLElement *itemChildElement in atomChildElement.children) {
                BOOL isArticleElementAtomType = [itemChildElement.prefix isEqualToString:self.atomPrefix];

                NSString *articleItemTag = itemChildElement.localName;

                // Parse item title
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"title"]) {
                    newFeedItem.title = (itemChildElement.stringValue).vna_summaryTextFromHTML;
                    continue;
                }

                // Parse item description
                if (isArticleElementAtomType && ([articleItemTag isEqualToString:@"content"]
                                                 // not in specifications, added for flexibility
                                                 || [articleItemTag isEqualToString:@"description"])) {
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

                // Parse item description
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"summary"] && articleBody == nil) {
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
                        NSStringCompareOptions opts = (NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch);
                        NSRange range = [newFeedItem.authors rangeOfString:authorName
                                                                   options:opts];
                        if (newFeedItem.authors.length > 0 && range.location != NSNotFound) {
                            newFeedItem.authors = [NSString stringWithFormat:NSLocalizedString(@"%@, %@", @"{existing authors}, {new author name}"), newFeedItem.authors, authorName];
                        } else {
                            newFeedItem.authors = authorName;
                        }
                    }
                    continue;
                }

                // Parse item link
                if (isArticleElementAtomType && [articleItemTag isEqualToString:@"link"]) {
                    if ([[itemChildElement attributeForName:@"rel"].stringValue isEqualToString:@"enclosure"] ||
                        [[itemChildElement attributeForName:@"rel"].stringValue isEqualToString:@"http://opds-spec.org/acquisition"]) {
                        NSString *theLink = ([itemChildElement attributeForName:@"href"].stringValue).vna_stringByUnescapingExtendedCharacters;
                        if (theLink != nil) {
                            if ((entryBaseURL != nil) && ([NSURL URLWithString:theLink].scheme == nil)) {
                                NSURL *theLinkURL = [NSURL URLWithString:theLink relativeToURL:entryBaseURL];
                                newFeedItem.enclosure = (theLinkURL != nil) ? theLinkURL.absoluteString : theLink;
                            } else {
                                newFeedItem.enclosure = theLink;
                            }
                        }
                    } else {
                        if ([itemChildElement attributeForName:@"rel"].stringValue == nil ||
                            [[itemChildElement attributeForName:@"rel"].stringValue isEqualToString:@"alternate"]) {
                            NSString *theLink = ([itemChildElement attributeForName:@"href"].stringValue).vna_stringByUnescapingExtendedCharacters;
                            if (theLink != nil) {
                                if ((entryBaseURL != nil) && ([NSURL URLWithString:theLink].scheme == nil)) {
                                    NSURL *theLinkURL = [NSURL URLWithString:theLink relativeToURL:entryBaseURL];
                                    newFeedItem.url = (theLinkURL != nil) ? theLinkURL.absoluteString : theLink;
                                } else {
                                    newFeedItem.url = theLink;
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
                if (isArticleElementAtomType && ([articleItemTag isEqualToString:@"updated"] || [articleItemTag isEqualToString:@"modified"])) {
                    NSString *dateString = itemChildElement.stringValue;
                    NSDate *newDate = [self dateWithXMLString:dateString];
                    if (newFeedItem.modificationDate == nil || [newDate isGreaterThan:newFeedItem.modificationDate]) {
                        newFeedItem.modificationDate = newDate;
                    }
                    continue;
                }

                // Parse item date
                if (isArticleElementAtomType && ([articleItemTag isEqualToString:@"published"]
                                                 // not in specifications, added for flexibility
                                                 || [articleItemTag isEqualToString:@"created"] || [articleItemTag isEqualToString:@"issued"] || [articleItemTag isEqualToString:@"pubDate"])) {
                    NSString *dateString = itemChildElement.stringValue;
                    NSDate *newDate = [self dateWithXMLString:dateString];
                    if (newFeedItem.publicationDate == nil || [newDate isLessThan:newFeedItem.publicationDate]) {
                        newFeedItem.publicationDate = newDate;
                    }
                    continue;
                }

                // Parse associated enclosure
                if ([itemChildElement.prefix isEqualToString:self.mediaPrefix] && [articleItemTag isEqualToString:@"content"]) {
                    if ([itemChildElement attributeForName:@"url"].stringValue) {
                        newFeedItem.enclosure = [itemChildElement attributeForName:@"url"].stringValue;
                    }
                    continue;
                }

                // Parse associated enclosure
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
                    if (!newFeedItem.enclosure || [newFeedItem.enclosure isEqualToString:@""]) {
                        // group's first enclosure
                        NSString *enclosureString = [NSString stringWithFormat:@"%@:content", self.mediaPrefix];
                        newFeedItem.enclosure =
                            ([[itemChildElement elementsForName:enclosureString].firstObject attributeForName:@"url"]).stringValue;
                    }
                    if (!newFeedItem.enclosure || [newFeedItem.enclosure isEqualToString:@""]) {
                        // use first thumbnail as a workaround for enclosure
                        NSString *enclosureString = [NSString stringWithFormat:@"%@:thumbnail", self.mediaPrefix];
                        newFeedItem.enclosure =
                            ([[itemChildElement elementsForName:enclosureString].firstObject attributeForName:@"url"]).stringValue;
                    }
                    if (!articleBody || [articleBody isEqualToString:@""]) {
                        // use enclosure description as a workaround for feed description
                        NSString *descriptionString = [NSString stringWithFormat:@"%@:description", self.mediaPrefix];
                        articleBody =
                            [([itemChildElement elementsForName:descriptionString].firstObject).stringValue mutableCopy];
                    }
                    continue;
                }
            }

            // if we didn't find an author, set it to the default one
            if ([newFeedItem.authors isEqualToString:@""]) {
                newFeedItem.authors = defaultAuthor;
            }

            if ([entryBase isEqualToString:@""]) {
                entryBase = newFeedItem.url ? newFeedItem.url : linkBase;
            }

            // Do relative IMG, IFRAME and A tags fixup
            [articleBody vna_fixupRelativeImgTags:entryBase];
            [articleBody vna_fixupRelativeIframeTags:entryBase];
            [articleBody vna_fixupRelativeAnchorTags:entryBase];
            newFeedItem.content = SafeString(articleBody);

            [items addObject:newFeedItem];
            success = YES;
        }
    }

    self.items = items;

    return success;
}

// MARK: Overrides

- (void)identifyNamespacesPrefixes:(NSXMLElement *)element
{
    [super identifyNamespacesPrefixes:element];

    self.atomPrefix = [element resolvePrefixForNamespaceURI:@"http://www.w3.org/2005/Atom"];
    if (!self.atomPrefix) {
        self.atomPrefix = @"";
    }
}

@end
