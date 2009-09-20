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
	time_t theTime = curl_getdate([dateString cString], NULL);
	return (theTime != -1) ? [NSCalendarDate dateWithTimeIntervalSince1970:theTime] : nil;
}

@end
