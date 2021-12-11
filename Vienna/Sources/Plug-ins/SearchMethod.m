//
//  SearchMethod.m
//  Vienna
//
//  Created by Michael on 19/02/10.
//  Copyright 2010 Michael G. Stroeck. All rights reserved.
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

#import "SearchMethod.h"

#import "AppController.h"
#import "HelperFunctions.h"

static NSString *const VNACodingKeyDisplayName = @"friendlyName";
static NSString *const VNACodingKeyQueryString = @"searchQueryString";

@implementation SearchMethod

// MARK: Initialization

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    self = [self init];

    if (self) {
        _displayName = [[dict valueForKey:@"FriendlyName"] copy];
        _queryString = [[dict valueForKey:@"SearchQueryString"] copy];
        _handler = @selector(performWebSearch:);
    }

    return self;
}

// MARK: Public methods

+ (SearchMethod *)allArticlesSearchMethod
{
    SearchMethod *method = [[SearchMethod alloc] init];
    method.displayName = NSLocalizedString(@"Search all articles",
                                           @"Placeholder title of a search "
                                            "field");
    method.handler = @selector(performAllArticlesSearch);

    return method;
}

+ (SearchMethod *)currentWebPageSearchMethod
{
    SearchMethod *method = [[SearchMethod alloc] init];
    method.displayName = NSLocalizedString(@"Search current web page",
                                           @"Placeholder title of a search "
                                            "field");
    method.handler = @selector(performWebPageSearch);

    return method;
}

// If you add a new one, add it to the array. Remember: arrayWithObjects needs
// a "nil" termination.
+ (NSArray *)builtInSearchMethods
{
    return @[
        [SearchMethod allArticlesSearchMethod],
        [SearchMethod currentWebPageSearchMethod]
    ];
}

- (NSURL *)queryURLforSearchString:(NSString *)searchString
{
    NSURL *queryURL;
    NSString *temp =
        [self.queryString stringByReplacingOccurrencesOfString:@"$SearchTerm$"
                                                    withString:searchString];
    queryURL = cleanedUpUrlFromString(temp);
    return queryURL;
}

// MARK: - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (coder.allowsKeyedCoding) {
        self = [self init];
    } else {
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                             code:NSCoderReadCorruptError
                                         userInfo:nil];
        [coder failWithError:error];
    }

    if (self) {
        _displayName = [coder decodeObjectOfClass:[NSString class]
                                           forKey:VNACodingKeyDisplayName];
        _queryString = [coder decodeObjectOfClass:[NSString class]
                                           forKey:VNACodingKeyQueryString];

        // TODO: Improve compatibility with keyed coding
        //
        // These methods retrieve the value from an undefined coding key. It
        // should be assigned to a defined coding key. One way to do this is by
        // converting the selector from a string (NSSelectorFromString) instead.
        if (@available(macOS 10.13, *)) {
            [coder decodeValueOfObjCType:@encode(SEL)
                                      at:&_handler
                                    size:sizeof(SEL)];
        } else {
            [coder decodeValueOfObjCType:@encode(SEL) at:&_handler];
        }
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                             code:NSCoderReadCorruptError
                                         userInfo:nil];
        [coder failWithError:error];
        return;
    }

    [coder encodeObject:self.displayName forKey:VNACodingKeyDisplayName];
    [coder encodeObject:self.queryString forKey:VNACodingKeyQueryString];

    // TODO: Improve compatibility with keyed coding
    //
    // This method assigns the value to an undefined coding key. It should be
    // assigned to a defined coding key. One way to do this is by converting the
    // selector to a string (NSStringFromSelector) instead.
    [coder encodeValueOfObjCType:@encode(SEL) at:&_handler];
}

@end
