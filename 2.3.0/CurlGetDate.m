//
//  CurlGetDate.m
//  CurlGetDate
//
//  Created by Jeffrey Johnson on 8/3/06.
//  Copyright Jeffrey Johnson. All rights reserved.
//

#import "CurlGetDate.h"
#import <curl/curl.h>

@implementation CurlGetDate

+(NSCalendarDate *)getDateFromString:(NSString *)dateString
{
	NSCalendarDate * date = nil;
	const char * asciiDate = [dateString cStringUsingEncoding:NSASCIIStringEncoding]; // curl only accepts English ASCII
	if (asciiDate != NULL)
	{
		time_t theTime = curl_getdate(asciiDate, NULL);
		if (theTime != -1 )
		{
			date = [NSCalendarDate dateWithTimeIntervalSince1970:theTime];
		}
	}
	return date;
}

@end
