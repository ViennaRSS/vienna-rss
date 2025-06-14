//
//  XMLFeed.m
//  Vienna
//
//  Copyright 2004-2005 Steve Palmer, 2015 Joshua Pore
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

// MARK: Public methods

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

- (nullable NSDate *)dateWithXMLString:(NSString *)dateString
{
    NSDate *date = nil;
    NSString *modifiedDateString = [dateString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    static NSMutableArray<NSDateFormatter *> *dateFormatters = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Important: For every four-digit year entry, we need an earlier two-digit
        // year entry so that NSDateFormatter parses two-digit years considering the
        // two-digit-year start date.
        //
        // For the different date formats, see http://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns
        NSArray<NSString *> *dateFormats = @[
            // Most frequent and compliant dates :
            // 2010-09-28T15:31:25Z / 2010-09-28T17:31:25+02:00 / Sat, 13 Dec 2008 18:45:15 +0300 / Sat, 13 Dec 2008 18:45:15 EAT
            @"yy-MM-dd'T'HH:mm:ssXXXXX",      @"yyyy-MM-dd'T'HH:mm:ssXXXXX",
            @"EEE, dd MMM yy HH:mm:ss XXXX",  @"EEE, dd MMM yyyy HH:mm:ss XXXX",
            @"EEE, dd MMM yy HH:mm:ss zzz",   @"EEE, dd MMM yyyy HH:mm:ss zzz",
            // 2010-09-28T17:31:25+0200
            @"yy-MM-dd'T'HH:mm:ssXXXX",       @"yyyy-MM-dd'T'HH:mm:ssXXXX",
            // 2010-09-28T15:31:25.815+02:00
            @"yy-MM-dd'T'HH:mm:ss.SSSXXXX",   @"yyyy-MM-dd'T'HH:mm:ss.SSSXXXX",
            @"yy-MM-dd'T'HH:mm:ss.SSSXXXXX",  @"yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            // Fri, 12 Dec 2008 18:45:15 -08:00
            @"EEE, dd MMM yy HH:mm:ss XXXXX", @"EEE, dd MMM yyyy HH:mm:ss XXXXX",
            @"EEE, dd MMM yy HH:mm:ss",       @"EEE, dd MMM yyyy HH:mm:ss",
            // Other exotic and non standard date formats
            @"yy-MM-dd HH:mm:ss XXXX",        @"yyyy-MM-dd HH:mm:ss XXXX",
            @"yy-MM-dd HH:mm:ss XXXXX",       @"yyyy-MM-dd HH:mm:ss XXXXX",
            @"yy-MM-dd HH:mm:ss zzz",         @"yyyy-MM-dd HH:mm:ss zzz",
            @"EEE dd MMM yy HH:mm:ss zzz",    @"EEE dd MMM yyyy HH:mm:ss zzz",
            @"EEE dd MMM yy HH:mm:ss XXXX",   @"EEE dd MMM yyyy HH:mm:ss XXXX",
            @"EEE dd MMM yy HH:mm:ss XXXXX",  @"EEE dd MMM yyyy HH:mm:ss XXXXX",
            @"EEE dd MMM yy HH:mm:ss",        @"EEE dd MMM yyyy HH:mm:ss",
            @"EEEE dd MMMM yy",               @"EEEE dd MMMM yyyy",
            @"dd MMM yy HH:mm:ss zzz",        @"dd MMM yyyy HH:mm:ss zzz",
            @"dd MMM yy HH:mm:ss XXXX",       @"dd MMM yyyy HH:mm:ss XXXX",
            @"dd MMM yy HH:mm:ss XXXXX",      @"dd MMM yyyy HH:mm:ss XXXXX",
        ];
        dateFormatters = [[NSMutableArray alloc] initWithCapacity:dateFormats.count];
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        NSTimeZone *timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        for (NSString *dateFormat in dateFormats) {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.locale = locale;
            dateFormatter.timeZone = timeZone;
            dateFormatter.dateFormat = dateFormat;
            [dateFormatters addObject:dateFormatter];
        }
    });

    // test with the date formatters we are aware of
    // exit as soon as we find a match
    for (NSDateFormatter *dateFormatter in dateFormatters) {
        date = [dateFormatter dateFromString:modifiedDateString];
        if (date) {
            return date;
        }
    }

    // If no date matches, return nil.
    return nil;
}

@end
