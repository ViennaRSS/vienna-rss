//
//  XMLFeedParser.m
//  Vienna
//
//  Copyright 2004-2005 Steve Palmer
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

#import "XMLFeedParser.h"

#import "AtomFeed.h"
#import "RSSFeed.h"

@implementation VNAXMLFeedParser

- (VNAXMLFeed *)feedWithXMLData:(NSData *)xmlData error:(NSError **)error
{
    NSXMLDocument *xmlDocument = nil;
    NSError *xmlDocumentError = nil;

    @try {
        xmlDocument = [[NSXMLDocument alloc] initWithData:xmlData
                                                  options:NSXMLNodeLoadExternalEntitiesNever
                                                    error:&xmlDocumentError];
        if (!xmlDocument && xmlDocumentError) {
            if ([xmlDocumentError.domain isEqualToString:NSXMLParserErrorDomain]) {
                // handle here cases identified to cause
                // application crashes caused by
                // NSXMLDocument's -initWithData:options:error
                // when option NSXMLDocumentTidyXML is enabled
                switch (xmlDocumentError.code) {
                case NSXMLParserGTRequiredError:
                case NSXMLParserTagNameMismatchError:
                case NSXMLParserEmptyDocumentError:
                    if (error) {
                        *error = xmlDocumentError;
                    }
                    return nil;
                }
            }

            // recover some cases like text encoding errors, non standard tags...
            xmlDocument = [[NSXMLDocument alloc] initWithData:xmlData
                                                      options:NSXMLDocumentTidyXML | NSXMLNodeLoadExternalEntitiesNever
                                                        error:&xmlDocumentError];
        }
    } @catch (NSException * __unused) {
        if (error) {
            if (xmlDocumentError) {
                *error = xmlDocumentError;
            } else {
                *error = [NSError errorWithDomain:NSXMLParserErrorDomain
                                             code:NSXMLParserInternalError
                                         userInfo:nil];
            }
        }
        xmlDocument = nil;
        return nil;
    }

    VNAXMLFeed *feed = nil;

    if (xmlDocument) {
        NSXMLElement *rootElement = xmlDocument.rootElement;
        if ([rootElement.name isEqualToString:@"rss"]) {
            feed = [[VNARSSFeed alloc] initWithXMLRootElement:rootElement
                                                        isRDF:NO];
        } else if ([rootElement.name isEqualToString:@"rdf:RDF"]) {
            feed = [[VNARSSFeed alloc] initWithXMLRootElement:rootElement
                                                        isRDF:YES];
        } else if ([rootElement.name isEqualToString:@"feed"]) {
            feed = [[VNAAtomFeed alloc] initWithXMLRootElement:rootElement];
        }
    }

    if (feed) {
        return feed;
    } else {
        if (error) {
            *error = [NSError errorWithDomain:NSXMLParserErrorDomain
                                         code:NSXMLParserUnknownEncodingError
                                     userInfo:nil];
        }
        return nil;
    }
}

@end
