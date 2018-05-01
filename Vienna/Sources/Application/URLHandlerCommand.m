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
 * and manage the following format:
 *
 *   feed://<rss link>
 *
 * Where <rss link> may be preceded by a scheme - either http:// or https://. If no scheme
 * is specified then http:// is implied.
 */
-(id)performDefaultImplementation
{
	NSScanner * scanner = [NSScanner scannerWithString:self.directParameter];
	NSString * urlPrefix = nil;

	[scanner scanUpToString:@":" intoString:&urlPrefix];
	[scanner scanString:@":" intoString:nil];
	if (urlPrefix && [urlPrefix isEqualToString:@"feed"])
	{
		NSString * feedScheme = nil;

		// Throw away the next few bits if they exist
		[scanner scanString:@"//" intoString:nil];
		[scanner scanString:@"http:" intoString:&feedScheme];
		[scanner scanString:@"https:" intoString:&feedScheme];
		[scanner scanString:@"//" intoString:nil];

		// The rest is the interesting part
		NSString * linkPath = nil;

		[scanner scanUpToString:@"" intoString:&linkPath];
		if (linkPath == nil)
			return nil;
		if (feedScheme == nil)
			feedScheme = @"http:";
		linkPath = [NSString stringWithFormat:@"%@//%@", feedScheme, linkPath];

		// Allow the run loop to run first, because this may be called at launch,
		// In which case the db is not fully initialized yet.
		[APPCONTROLLER performSelector:@selector(handleRSSLink:) withObject:linkPath afterDelay:0.0];
	}
	return nil;
}
@end
