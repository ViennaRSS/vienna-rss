//
//  CurlGetDate.h
//  CurlGetDate
//
//  Created by Jeffrey Johnson on 8/3/06.
//  Copyright Jeffrey Johnson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CurlGetDate : NSObject
{
}

+(NSCalendarDate *)getDateFromString:(NSString *)dateString;

@end
