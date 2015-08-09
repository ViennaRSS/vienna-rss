//
//  NSDate+Vienna.m
//  Vienna
//
//  Created by Joshua Pore on 8/08/2015.
//  Copyright (c) 2015 uk.co.opencommunity. All rights reserved.
//

#import "NSDate+Vienna.h"
#import "AppController.h"

@implementation NSDate (Vienna)


/* parseXMLDate
 * Parse a date in an XML header into an NSCalendarDate. This is horribly expensive and needs
 * to be replaced with a parser that can handle these formats:
 *
 *   2005-10-23T10:12:22-4:00
 *   2005-10-23T10:12:22
 *   2005-10-23T10:12:22Z
 *   Mon, 10 Oct 2005 10:12:22 -4:00
 *   10 Oct 2005 10:12:22 -4:00
 *
 * These are the formats that I've discovered so far.
 */
+ (NSDate *)parseXMLDate:(NSString *)dateString
{
    int yearValue = 0;
    int monthValue = 1;
    int dayValue = 0;
    int hourValue = 0;
    int minuteValue = 0;
    int secondValue = 0;
    int tzOffset = 0;
    
    //We handle garbage there! (At least 1/1/00, so four digit)
    if ([[dateString stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] length] < 4) return nil;
    
    NSDate *curlDate = [AppController getDateFromString:dateString];
    
    if (curlDate != nil)
        return curlDate;
    
    // Otherwise do it ourselves.
    // Expect the string to be loosely like a ISO 8601 subset
    NSScanner * scanner = [NSScanner scannerWithString:dateString];
    
    [scanner setScanLocation:0u];
    if (![scanner scanInt:&yearValue])
        return nil;
    if (yearValue < 100)
        yearValue += 2000;
    if ([scanner scanString:@"-" intoString:nil])
    {
        if (![scanner scanInt:&monthValue])
            return nil;
        if (monthValue < 1 || monthValue > 12)
            return nil;
        if ([scanner scanString:@"-" intoString:nil])
        {
            if (![scanner scanInt:&dayValue])
                return nil;
            if (dayValue < 1 || dayValue > 31)
                return nil;
        }
    }
    
    // Parse the time portion.
    // (I discovered that GMail sometimes returns a timestamp with 24 as the hour
    // portion although this is clearly contrary to the RFC spec. So be
    // prepared for things like this.)
    if ([scanner scanString:@"T" intoString:nil])
    {
        if (![scanner scanInt:&hourValue])
            return nil;
        hourValue %= 24;
        if ([scanner scanString:@":" intoString:nil])
        {
            if (![scanner scanInt:&minuteValue])
                return nil;
            if (minuteValue < 0 || minuteValue > 59)
                return nil;
            if ([scanner scanString:@":" intoString:nil] || [scanner scanString:@"." intoString:nil])
            {
                if (![scanner scanInt:&secondValue])
                    return nil;
                if (secondValue < 0 || secondValue > 59)
                    return nil;
                // Drop any fractional seconds
                if ([scanner scanString:@"." intoString:nil])
                {
                    if (![scanner scanInt:nil])
                        return nil;
                }
            }
        }
    }
    else
    {
        // If no time is specified, set the time to 11:59pm,
        // so new articles within the last 24 hours are detected.
        hourValue = 23;
        minuteValue = 59;
    }
    
    // At this point we're at any potential timezone
    // tzOffset needs to be the number of seconds since GMT
    if ([scanner scanString:@"Z" intoString:nil])
        tzOffset = 0;
    else if (![scanner isAtEnd])
    {
        if (![scanner scanInt:&tzOffset])
            return nil;
        if (tzOffset > 12)
            return nil;
    }
    
    // Now combine the whole thing into a date we know about.
    NSTimeZone * tzValue = [NSTimeZone timeZoneForSecondsFromGMT:tzOffset * 60 * 60];
    return [NSCalendarDate dateWithYear:yearValue month:monthValue day:dayValue hour:hourValue minute:minuteValue second:secondValue timeZone:tzValue];
}

@end
