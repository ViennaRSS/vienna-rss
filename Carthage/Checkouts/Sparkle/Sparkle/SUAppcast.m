//
//  SUAppcast.m
//  Sparkle
//
//  Created by Andy Matuschak on 3/12/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#import "SUAppcast.h"
#import "SUAppcastItem.h"
#import "SULog.h"
#import "SULocalizations.h"
#import "SUErrors.h"

#import "SPUURLRequest.h"
#import "SUOperatingSystem.h"
#import "SPUDownloadData.h"
#import "SPUDownloaderDelegate.h"
#import "SPUDownloaderDeprecated.h"
#import "SPUDownloaderSession.h"

#include "AppKitPrevention.h"

@interface NSXMLElement (SUAppcastExtensions)
@property (readonly, copy) NSDictionary *attributesAsDictionary;
@end

@implementation NSXMLElement (SUAppcastExtensions)
- (NSDictionary *)attributesAsDictionary
{
    NSEnumerator *attributeEnum = [[self attributes] objectEnumerator];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    for (NSXMLNode *attribute in attributeEnum) {
        NSString *attrName = [attribute name];
        if (!attrName) {
            continue;
        }
        NSString *attributeStringValue = [attribute stringValue];
        if (attributeStringValue != nil) {
            [dictionary setObject:attributeStringValue forKey:attrName];
        }
    }
    return dictionary;
}
@end

@interface SUAppcast () <SPUDownloaderDelegate>

@property (strong) void (^completionBlock)(NSError *);
@property (strong) SPUDownloader *download;
@property (copy) NSArray *items;
- (void)reportError:(NSError *)error;
- (NSXMLNode *)bestNodeInNodes:(NSArray *)nodes;

@end

@implementation SUAppcast

@synthesize completionBlock;
@synthesize userAgentString;
@synthesize httpHeaders;
@synthesize download;
@synthesize items;

- (void)fetchAppcastFromURL:(NSURL *)url inBackground:(BOOL)background completionBlock:(void (^)(NSError *))block
{
    self.completionBlock = block;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
    if (background) {
        request.networkServiceType = NSURLNetworkServiceTypeBackground;
    }

    if (self.userAgentString) {
        [request setValue:self.userAgentString forHTTPHeaderField:@"User-Agent"];
    }

    if (self.httpHeaders) {
        for (NSString *key in self.httpHeaders) {
            NSString *value = [self.httpHeaders objectForKey:key];
            [request setValue:value forHTTPHeaderField:key];
        }
    }

    [request setValue:@"application/rss+xml,*/*;q=0.1" forHTTPHeaderField:@"Accept"];

    
    if (SUAVAILABLE(10, 9)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        self.download = [[SPUDownloaderSession alloc] initWithDelegate:self];
#pragma clang diagnostic pop
    }
    else {
        self.download = [[SPUDownloaderDeprecated alloc] initWithDelegate:self];
    }
    
    SPUURLRequest *urlRequest = [SPUURLRequest URLRequestWithRequest:request];
    [self.download startTemporaryDownloadWithRequest:urlRequest];
}

- (void)downloaderDidSetDestinationName:(NSString *)__unused destinationName temporaryDirectory:(NSString *)__unused temporaryDirectory
{
}

- (void)downloaderDidReceiveExpectedContentLength:(int64_t)__unused expectedContentLength
{
}

- (void)downloaderDidReceiveDataOfLength:(uint64_t)__unused length
{
}

- (void)downloaderDidFinishWithTemporaryDownloadData:(SPUDownloadData * _Nullable)downloadData
{
    if (downloadData != nil) {
        NSError *parseError = nil;
        NSArray *appcastItems = [self parseAppcastItemsFromXMLData:downloadData.data error:&parseError];
        
        if (appcastItems != nil) {
            self.items = appcastItems;
            self.completionBlock(nil);
            self.completionBlock = nil;
        } else {
            NSMutableDictionary *userInfo = [NSMutableDictionary
                                             dictionaryWithObject: SULocalizedString(@"An error occurred while parsing the update feed.", nil)
                                             forKey: NSLocalizedDescriptionKey];
            if (parseError != nil) {
                [userInfo setObject:parseError forKey:NSUnderlyingErrorKey];
            }
            [self reportError:[NSError errorWithDomain:SUSparkleErrorDomain
                                                  code:SUAppcastParseError
                                              userInfo:userInfo]];
        }
    } else {
        SULog(SULogLevelError, @"Temp data download is null in SUAppcast");
        
        NSDictionary *userInfo = [NSDictionary
                                  dictionaryWithObject: SULocalizedString(@"An error occurred while downloading the update feed.", nil)
                                  forKey: NSLocalizedDescriptionKey];
        
        [self reportError:[NSError errorWithDomain:SUSparkleErrorDomain
                                              code:SUDownloadError
                                          userInfo:userInfo]];
    }
}

- (void)downloaderDidFailWithError:(NSError *)error
{
    SULog(SULogLevelError, @"Encountered download feed error: %@", error);
    
    [self reportError:error];
}

- (NSDictionary *)attributesOfNode:(NSXMLElement *)node
{
    NSEnumerator *attributeEnum = [[node attributes] objectEnumerator];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    for (NSXMLNode *attribute in attributeEnum) {
        NSString *attrName = [self sparkleNamespacedNameOfNode:attribute];
        if (!attrName) {
            continue;
        }
        NSString *stringValue = [attribute stringValue];
        if (stringValue) {
            [dictionary setObject:stringValue forKey:attrName];
        }
    }
    return dictionary;
}

-(NSString *)sparkleNamespacedNameOfNode:(NSXMLNode *)node {
    // XML namespace prefix is semantically meaningless, so compare namespace URI
    // NS URI isn't used to fetch anything, and must match exactly, so we look for http:// not https://
    if ([[node URI] isEqualToString:@"http://www.andymatuschak.org/xml-namespaces/sparkle"]) {
        NSString *localName = [node localName];
        assert(localName);
        return [@"sparkle:" stringByAppendingString:localName];
    } else {
        return [node name]; // Backwards compatibility
    }
}

-(NSArray *)parseAppcastItemsFromXMLFile:(NSURL *)appcastURL error:(NSError *__autoreleasing*)errorp {
    NSData *data = [NSData dataWithContentsOfURL:appcastURL];
    return [self parseAppcastItemsFromXMLData:data error:errorp];
}

-(NSArray *)parseAppcastItemsFromXMLData:(NSData *)appcastData error:(NSError *__autoreleasing*)errorp {
    if (errorp) {
        *errorp = nil;
    }

    if (!appcastData) {
        return nil;
    }

    NSUInteger options = NSXMLNodeLoadExternalEntitiesNever; // Prevent inclusion from file://
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithData:appcastData options:options error:errorp];
	if (nil == document) {
        return nil;
    }

    NSArray *xmlItems = [document nodesForXPath:@"/rss/channel/item" error:errorp];
    if (nil == xmlItems) {
        return nil;
    }

    NSMutableArray *appcastItems = [NSMutableArray array];
    NSEnumerator *nodeEnum = [xmlItems objectEnumerator];
    NSXMLNode *node;

	while((node = [nodeEnum nextObject])) {
        NSMutableDictionary *nodesDict = [NSMutableDictionary dictionary];
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];

        // First, we'll "index" all the first-level children of this appcast item so we can pick them out by language later.
        if ([[node children] count]) {
            node = [node childAtIndex:0];
            while (nil != node) {
                NSString *name = [self sparkleNamespacedNameOfNode:node];
                if (name) {
                    NSMutableArray *nodes = [nodesDict objectForKey:name];
                    if (nodes == nil) {
                        nodes = [NSMutableArray array];
                        [nodesDict setObject:nodes forKey:name];
                    }
                    [nodes addObject:node];
                }
                node = [node nextSibling];
            }
        }

        for (NSString *name in nodesDict) {
            node = [self bestNodeInNodes:[nodesDict objectForKey:name]];
            if ([name isEqualToString:SURSSElementEnclosure]) {
                // enclosure is flattened as a separate dictionary for some reason
                NSDictionary *encDict = [self attributesOfNode:(NSXMLElement *)node];
                [dict setObject:encDict forKey:name];
			}
            else if ([name isEqualToString:SURSSElementPubDate]) {
                // We don't want to parse and create a NSDate instance -
                // that's a risk we can avoid. We don't use the date anywhere other
                // than it being accessible from SUAppcastItem
                NSString *dateString = node.stringValue;
                if (dateString) {
                    [dict setObject:dateString forKey:name];
                }
			}
			else if ([name isEqualToString:SUAppcastElementDeltas]) {
                NSMutableArray *deltas = [NSMutableArray array];
                NSEnumerator *childEnum = [[node children] objectEnumerator];
                for (NSXMLNode *child in childEnum) {
                    if ([[child name] isEqualToString:SURSSElementEnclosure]) {
                        [deltas addObject:[self attributesOfNode:(NSXMLElement *)child]];
                    }
                }
                [dict setObject:deltas forKey:name];
			}
            else if ([name isEqualToString:SUAppcastElementTags]) {
                NSMutableArray *tags = [NSMutableArray array];
                NSEnumerator *childEnum = [[node children] objectEnumerator];
                for (NSXMLNode *child in childEnum) {
                    NSString *childName = child.name;
                    if (childName) {
                        [tags addObject:childName];
                    }
                }
                [dict setObject:tags forKey:name];
            }
			else if (name != nil) {
                // add all other values as strings
                NSString *theValue = [[node stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (theValue != nil) {
                    [dict setObject:theValue forKey:name];
                }
            }
        }

        NSString *errString;
        SUAppcastItem *anItem = [[SUAppcastItem alloc] initWithDictionary:dict failureReason:&errString];
        if (anItem) {
            [appcastItems addObject:anItem];
		}
        else {
            SULog(SULogLevelError, @"Sparkle Updater: Failed to parse appcast item: %@.\nAppcast dictionary was: %@", errString, dict);
            if (errorp) *errorp = [NSError errorWithDomain:SUSparkleErrorDomain
                                                      code:SUAppcastParseError
                                                  userInfo:@{NSLocalizedDescriptionKey: errString}];
            return nil;
        }
    }
    
    self.items = appcastItems;

    return appcastItems;
}

- (void)reportError:(NSError *)error
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{
        NSLocalizedDescriptionKey: SULocalizedString(@"An error occurred in retrieving update information. Please try again later.", nil),
        NSLocalizedFailureReasonErrorKey: [error localizedDescription],
        NSUnderlyingErrorKey: error,
    }];

    NSURL *failingUrl = [error.userInfo objectForKey:NSURLErrorFailingURLErrorKey];
    if (failingUrl) {
        [userInfo setObject:failingUrl forKey:NSURLErrorFailingURLErrorKey];
    }

    self.completionBlock([NSError errorWithDomain:SUSparkleErrorDomain code:SUAppcastError userInfo:userInfo]);
    self.completionBlock = nil;
}

- (NSXMLNode *)bestNodeInNodes:(NSArray *)nodes
{
    // We use this method to pick out the localized version of a node when one's available.
    if ([nodes count] == 1)
        return [nodes objectAtIndex:0];
    else if ([nodes count] == 0)
        return nil;

    NSMutableArray *languages = [NSMutableArray array];
    NSString *lang;
    NSUInteger i;
    for (NSXMLElement *node in nodes) {
        lang = [[node attributeForName:@"xml:lang"] stringValue];
        [languages addObject:(lang ? lang : @"")];
    }
    lang = [[NSBundle preferredLocalizationsFromArray:languages] objectAtIndex:0];
    i = [languages indexOfObject:([languages containsObject:lang] ? lang : @"")];
    if (i == NSNotFound) {
        i = 0;
    }
    return [nodes objectAtIndex:i];
}

- (SUAppcast *)copyWithoutDeltaUpdates {
    SUAppcast *other = [SUAppcast new];
    NSMutableArray *nonDeltaItems = [NSMutableArray new];

    for(SUAppcastItem *item in self.items) {
        if (![item isDeltaUpdate]) [nonDeltaItems addObject:item];
    }

    other.items = nonDeltaItems;
    return other;
}

@end
