//
//  ExtDateFormatter.m
//  Vienna
//
//  Created by Steve on Thu Apr 01 2004.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
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

#import "ExtDateFormatter.h"
#import "CalendarExtensions.h"

@implementation ExtDateFormatter

/* stringForObjectValue
 * Returns a date formatted using the friendly date format implemented by our
 * own ExtendedCalendarDate.
 */
-(NSString *)stringForObjectValue:(id)anObject
{
	// This is a DATE formatter, you wally!
	if (![anObject isKindOfClass:[NSDate class]])
		return nil;

	NSCalendarDate * anDate = [anObject dateWithCalendarFormat:nil timeZone:nil];
	return [anDate friendlyDescription];
}

/* getObjectValue
 * Given a string, returns the NSDate object representing that string.
 */
-(BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error
{
	// Aw. Fuggedaboutit!
	return NO;
}
@end

