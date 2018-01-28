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
* For the different date formats, see <http://unicode.org/reports/tr35/#Date_Format_Patterns>
* IMPORTANT hack : remove in these strings any colon [:] beginning from character # 20 (first char is #0)
* We do so because some servers incorrectly return strings with a colon (:) in timezone indication
* which NSDateFormatter refuses to handle
*
*/
static NSString * kDateFormats[] = {
	// 2010-09-28T15:31:25Z and 2010-09-28T17:31:25+02:00
	@"yy-MM-dd'T'HH:mm:ssZZZ",     @"yyyy-MM-dd'T'HH:mm:ssZZZ",
	// 2010-09-28T15:31:25.815+02:00
	@"yy-MM-dd'T'HH:mm:ss.SSSZZZ", @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZ",
	// "Sat, 13 Dec 2008 18:45:15 EAT" and "Fri, 12 Dec 2008 18:45:15 -08:00"
	@"EEE, dd MMM yy HH:mmss zzz", @"EEE, dd MMM yyyy HH:mmss zzz",
	@"EEE, dd MMM yy HH:mmss ZZZ", @"EEE, dd MMM yyyy HH:mmss ZZZ",
	@"EEE, dd MMM yy HH:mmss",     @"EEE, dd MMM yyyy HH:mmss",
	// Required by compatibility with older OS X versions
	@"yy-MM-dd'T'HH:mm:ss'Z'",     @"yyyy-MM-dd'T'HH:mm:ss'Z'",
	@"yy-MM-dd'T'HH:mm:ss.SSS'Z'", @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
	// Other exotic and non standard date formats
	@"yy-MM-dd HH:mm:ss ZZZ",      @"yyyy-MM-dd HH:mm:ss ZZZ",
	@"yy-MM-dd HH:mm:ss zzz",      @"yyyy-MM-dd HH:mm:ss zzz",
	@"EEE dd MMM yy HH:mmss zzz",  @"EEE dd MMM yyyy HH:mmss zzz",
	@"EEE dd MMM yy HH:mmss ZZZ",  @"EEE dd MMM yyyy HH:mmss ZZZ",
	@"EEE dd MMM yy HH:mmss",      @"EEE dd MMM yyyy HH:mmss",
	@"EEEE dd MMMM yy",            @"EEEE dd MMMM yyyy",
};
static const size_t kNumberOfDateFormatters = sizeof(kDateFormats) / sizeof(kDateFormats[0]);

// C array of NSDateFormatter's : creating a NSDateFormatter is very expensive, so we create
//  those we need early in the program launch and keep them in memory.
static NSDateFormatter * dateFormatterArray[kNumberOfDateFormatters];

static NSLock * dateFormatters_lock;
static NSLocale * enUSLocale;
static BOOL threadSafe;

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

	// end of initialization of date formatters

	if (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_9)
        threadSafe=YES;
    else
	{
        // Initializes our multi-thread lock
        dateFormatters_lock = [[NSLock alloc] init];
        threadSafe=NO;
    }
}



/* parseXMLDate
 * Parse a date in an XML header into an NSCalendarDate.
 *
 */
+ (NSDate *)parseXMLDate:(NSString *)dateString
{
	NSDate *date ;
    NSString *modifiedDateString ;
	// Hack : remove colon in timezone as NSDateFormatter doesn't recognize them
	if (dateString.length > 20)
	{
        modifiedDateString = [dateString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    	modifiedDateString = [modifiedDateString
                            stringByReplacingOccurrencesOfString:@":" withString:@""
                            options:0 range:NSMakeRange(20,modifiedDateString.length-20)];
    }
    else
    {
        modifiedDateString = dateString;
    }

	if (threadSafe)
	{
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
	}
	else
	{
        // NSDateFormatter is thread safe on OS X 10.9 and later only
        // so we manage the issue with this lock
        [dateFormatters_lock lock];
        for (NSInteger i=0; i<kNumberOfDateFormatters; i++)
        {
            date = [dateFormatterArray[i] dateFromString:modifiedDateString];
            if (date != nil)
            {
                [dateFormatters_lock unlock];
                return date;
            }
        }
        [dateFormatters_lock unlock];
	}

	// expensive last resort attempt
	date = [NSDate dateWithNaturalLanguageString:dateString locale:enUSLocale];
	return date;
    
}

@end
