//
//  NSDate+Vienna.m
//  Vienna
//
//  Created by Joshua Pore on 8/08/2015.
//  Copyright (c) 2015 uk.co.opencommunity. All rights reserved.
//

#import "NSDate+Vienna.h"

/* C array of NSDateFormatter format strings. This array is used only once to populate dateFormatterArray.
*
* Note: for every four-digit year entry, we need an earlier two-digit year entry
* so that NSDateFormatter parses two-digit years considering the two-digit-year start date.
*
* For the different date formats, see <http://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns>
*
*/
static NSString * kDateFormats[] = {
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
};
static const size_t kNumberOfDateFormatters = sizeof(kDateFormats) / sizeof(kDateFormats[0]);

// C array of NSDateFormatter's : creating a NSDateFormatter is very expensive, so we create
//  those we need early in the program launch and keep them in memory.
static NSDateFormatter * dateFormatterArray[kNumberOfDateFormatters];

static NSLocale * enUSLocale;

@implementation NSDate (Vienna)


+ (void)load
{
	// Initializes the date formatters
	enUSLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];

	for (NSInteger i=0; i<kNumberOfDateFormatters; i++)
	{
		dateFormatterArray[i] = [[NSDateFormatter alloc] init];
		dateFormatterArray[i].locale = enUSLocale;
		dateFormatterArray[i].timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        dateFormatterArray[i].dateFormat = kDateFormats[i];
	}
}



/* parseXMLDate
 * Parse a date in an XML header into an NSDate.
 *
 */
+ (NSDate *)vna_parseXMLDate:(NSString *)dateString
{
	NSDate *date ;
    NSString *modifiedDateString = [dateString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // test with the date formatters we are aware of
    // exit as soon as we find a match
    for (NSInteger i=0; i<kNumberOfDateFormatters; i++)
    {
        date = [dateFormatterArray[i] dateFromString:modifiedDateString];
        if (date != nil)
        {
            return date;
        }
    }

	return date;
}

@end
