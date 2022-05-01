//
//  XMLFeed.m
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

#import "XMLFeed.h"

@implementation VNAXMLFeed

- (void)identifyNamespacesPrefixes:(NSXMLElement *)element
{
    self.rdfPrefix = [element resolvePrefixForNamespaceURI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#"];
    if (!self.rdfPrefix) {
        self.rdfPrefix = @"rdf";
    }

    self.mediaPrefix = [element resolvePrefixForNamespaceURI:@"http://search.yahoo.com/mrss/"];
    if (!self.mediaPrefix) {
        self.mediaPrefix = @"media";
    }

    self.encPrefix = [element resolvePrefixForNamespaceURI:@"http://purl.oclc.org/net/rss_2.0/enc#"];
    if (!self.encPrefix) {
        self.encPrefix = @"enc";
    }
}

@end
