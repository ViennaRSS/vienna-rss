//
//  AsyncConnection.m
//  Vienna
//
//  Created by Steve on 6/16/05.
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

#import "AsyncConnection.h"
#import "StringExtensions.h"

@implementation AsyncConnection

/* init
 * Initialise an instance of the class.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		receivedData = [[NSMutableData alloc] init];
		username = nil;
		password = nil;
		handler = nil;
		delegate = nil;
		didError = NO;
	}
	return self;
}

/* receivedData
 * Return the data received by this connection.
 */
-(NSData *)receivedData
{
	return receivedData;
}

/* didError
 * Returns whether or not the last connection succeeded.
 */
-(BOOL)didError
{
	return didError;
}

/* beginLoadDataFromURL
 * Begin an asynchronous connection using the specified URL, username, password and callback information. On completion of
 * the connection, whether or not the connection succeeded, the callback is invoked. The user will need to query the object
 * passed to determine whether it succeeded and to get at the raw data.
 */
-(BOOL)beginLoadDataFromURL:(NSURL *)theUrl username:(NSString *)theUsername password:(NSString *)thePassword delegate:(id)theDelegate didEndSelector:(SEL)endSelector
{
	[username release];
	[password release];
	username = theUsername;
	password = thePassword;
	delegate = theDelegate;
	handler = endSelector;
	NSURLRequest * theRequest = [NSMutableURLRequest requestWithURL:theUrl cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
	return [NSURLConnection connectionWithRequest:theRequest delegate:self] != nil;
}

/* didReceiveResponse
 * This method is called when the server has determined that it has enough information
 * to create the NSURLResponse it can be called multiple times, for example in the case
 * of a redirect, so each time we reset the data.
 */
-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[receivedData setLength:0];
}

/* didReceiveData
 * We received a new block of data from the remote. Append it to what we
 * have so far.
 */
-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[receivedData appendData:data];
}

/* didFailWithError
 * The remote connection failed somehow. Don't do anything with the data we got
 * so far but report an error against this connection.
 */
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	didError = YES;
	[[NSRunLoop currentRunLoop] performSelector:handler target:delegate argument:self order:0 modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, nil]];
}

/* didReceiveAuthenticationChallenge
 * We got an authentication challenge from the remote site. OK. Dig out that username
 * that ought to be on the folder and try it. Otherwise prompt the user. If this is
 * the second time we got this challenge then the previous credentials didn't work so
 * fail.
 */
-(void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	if ([challenge previousFailureCount] == 0)
	{
		if (![username isBlank])
		{
			NSURLCredential * newCredential = [NSURLCredential credentialWithUser:username password:password persistence:NSURLCredentialPersistencePermanent];
			[[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
			return;
		}
	}
	[[challenge sender] cancelAuthenticationChallenge:challenge];
}

/* willSendRequest
 * Handle connect redirection. Always allow it.
 */
-(NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
	return request;
}

/* connectionDidFinishLoading
 * We're done. Now parse the XML data and add it to the database.
 */
-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	didError = NO;
	[[NSRunLoop currentRunLoop] performSelector:handler target:delegate argument:self order:0 modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, nil]];
}

/* dealloc
 * Clean up after ourselves.
 */
-(void)dealloc
{
	[receivedData release];
	[username release];
	[password release];
	[super dealloc];
}
@end
