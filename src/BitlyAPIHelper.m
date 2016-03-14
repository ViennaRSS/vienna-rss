//
//  BitlyAPIHelper.h
//  Vienna
//
//  Created by Michael Stroeck on 15.01.10.
//  Copyright 2010 Michael Stroeck. All rights reserved.
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

#import "BitlyAPIHelper.h"
#import "HelperFunctions.h"

// bit.ly defaults to delivering results via JSON, but we want to use XML here, that's why whe use &format=xml
static NSString * BitlyApiBaseUrl = @"http://api.bit.ly/%@?version=2.0.1&login=%@&apiKey=%@&format=xml&";

@implementation BitlyAPIHelper

/* initWithLoginName:
 * Designated initialiser. We always use Vienna's API key and login at the moment, but I'm leaving it
 * like this to be flexible. We may want to provide a way to for users to use their own bit.ly login.
 */
-(BitlyAPIHelper*)initWithLogin: (NSString*) bitlyLogin andAPIKey: (NSString*) bitlyApiKey 
{
	login = [bitlyLogin copy];
	apiKey = [bitlyApiKey copy];
	return self;
}

/* shortenURL:
 * Uses the bit.ly API to shorten long URLs, especially for use in sharing-plugins.
 */
- (NSString*)shortenURL: (NSString*)longURL 
{
	// The next few lines incrementally build the request...
	NSString * requestURLString = [NSString stringWithFormat:BitlyApiBaseUrl, @"shorten", login, apiKey];
	longURL = cleanedUpAndEscapedUrlFromString(longURL).absoluteString;
	NSString * parameters = [NSString stringWithFormat:@"longUrl=%@", longURL];
	requestURLString = [requestURLString stringByAppendingString:parameters];	
	NSURL *finishedRequestURL = [NSURL URLWithString:requestURLString];
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:finishedRequestURL];
	
	// ... which is then finally sent to bit.ly's servers.
	NSHTTPURLResponse* urlResponse = nil;  	
	NSError *error = [[NSError alloc] init];
	NSData * data = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];	
	
	// If the response is OK, use Vienna's XML parser stuff to get the data we need.
	if (urlResponse.statusCode >= 200 && urlResponse.statusCode < 300)
	{
		//TODO: Robust error-handling.
        NSError *error = nil;
        NSXMLDocument *bitlyResponse = [[NSXMLDocument alloc] initWithData:data options:NSXMLNodeOptionsNone error:&error];
        if (error) {
            // TODO: Present error-message to the user?
            NSLog(@"URL shortening with bit.ly failed: %@", error);
            return nil;
        }
        
        error = nil;
        NSXMLNode *shortUrlNode = [bitlyResponse nodesForXPath:@".//bitly/results/nodeKeyVal/shortUrl" error:&error].firstObject;
        
        if (error) {
            // TODO: Present error-message to the user?
            NSLog(@"Processing xml xpath from bit.ly failed: %@", error);
            return nil;
        } else {
            return shortUrlNode.stringValue;
        }
        
	}
	// TODO: Present error-message to the user?
	NSLog(@"URL shortening with bit.ly failed!");
	NSBeep();
	return nil;
}

@end
