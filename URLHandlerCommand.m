//
//  URLHandlerCommand.m
//  Vienna
//
//  Created by Steve on Wed Feb 04 2004.
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

#import "URLHandlerCommand.h"
#import "AppController.h"

@implementation ViennaScriptCommand

/* performDefaultImplementation
 * This is the entry point for all link handlers associated with Vienna. Currently we parse
 * and manage the following formats:
 *
 *   cix:<conference/topic>:<messagenumber>
 *   feed://<rss link>
 */
-(id)performDefaultImplementation
{
	NSScanner * scanner = [NSScanner scannerWithString:[self directParameter]];
	NSString * urlPrefix;

	[scanner scanUpToString:@":" intoString:&urlPrefix];
	[scanner scanString:@":" intoString:nil];
	if ([urlPrefix isEqualToString:@"feed"])
	{
		NSString * feedScheme = nil;

		// Throw away the next few bits if they exist
		[scanner scanString:@"//" intoString:nil];
		[scanner scanString:@"http:" intoString:&feedScheme];
		[scanner scanString:@"https:" intoString:&feedScheme];
		[scanner scanString:@"//" intoString:nil];

		// The rest is the interesting part
		NSString * linkPath;

		[scanner scanUpToString:@"" intoString:&linkPath];
		if (feedScheme == nil)
			feedScheme = @"http:";
		linkPath = [NSString stringWithFormat:@"%@//%@", feedScheme, linkPath];

		AppController * app = [NSApp delegate];
		[app handleRSSLink:linkPath];
	}
	return nil;
}
@end
