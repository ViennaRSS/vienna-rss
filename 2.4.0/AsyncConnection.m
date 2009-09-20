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

#import "ViennaApp.h"
#import "Constants.h"
#import "AsyncConnection.h"
#import "StringExtensions.h"

// Private functions
@interface AsyncConnection (Private)
	-(void)sendConnectionCompleteNotification;
@end

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
		aItem = nil;
		contextData = nil;
		connector = nil;
		httpHeaders = nil;
		URLString = nil;
		status = MA_Connect_Succeeded;
		isConnectionComplete = YES;
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

/* responseHeaders
 * Return the dictionary of the responses from the request. This will be nil if no
 * request has been initiated or any response was obtained.
 */
-(NSDictionary *)responseHeaders
{
	return responseHeaders;
}

/* aItem
 * Return the activity log associated with this connection.
 */
-(ActivityItem *)aItem
{
	return aItem;
}

/* URLString
 * Returns the URL of this connection.
 */
-(NSString *)URLString
{
	return URLString;
}

/* contextData
 * Returns the context data object that was originally passed when the connection
 * was created.
 */
-(id)contextData
{
	return contextData;
}

/* status
 * Return the status of the last connection.
 */
-(ConnectStatus)status
{
	return status;
}

/* setHttpHeaders
 * Set the HTTP header fields to be passed to the connection.
 */
-(void)setHttpHeaders:(NSDictionary *)headerFields
{
	[headerFields retain];
	[httpHeaders release];
	httpHeaders = headerFields;
}

/* setURLString
 * Sets the current URL of this connection.
 */
-(void)setURLString:(NSString *)newURLString
{
	[newURLString retain];
	[URLString release];
	URLString = newURLString;
}

/* beginLoadDataFromURL
 * Begin an asynchronous connection using the specified URL, username, password and callback information. On completion of
 * the connection, whether or not the connection succeeded, the callback is invoked. The user will need to query the object
 * passed to determine whether it succeeded and to get at the raw data.
 */
-(BOOL)beginLoadDataFromURL:(NSURL *)theUrl
				   username:(NSString *)theUsername
				   password:(NSString *)thePassword
				   delegate:(id)theDelegate
				contextData:(id)theData
						log:(ActivityItem *)theItem
			 didEndSelector:(SEL)endSelector
{
	[username release];
	[password release];
	[contextData release];
	[aItem release];

	username = [theUsername retain];
	password = [thePassword retain];
	contextData = [theData retain];
	aItem = [theItem retain];

	delegate = theDelegate;
	handler = endSelector;
	[self setURLString:[theUrl absoluteString]];

	NSMutableURLRequest * theRequest = [NSMutableURLRequest requestWithURL:theUrl cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
	if (theRequest == nil)
		return NO;

	if (httpHeaders != nil)
	{
		NSEnumerator * enumerator = [[httpHeaders allKeys] objectEnumerator];
		NSString * httpFieldName;
		
		while ((httpFieldName = [enumerator nextObject]) != nil)
		{
			NSString * fieldValue = [httpHeaders valueForKey:httpFieldName];
			if (fieldValue != nil && ![fieldValue isBlank])
				[theRequest addValue:[httpHeaders valueForKey:httpFieldName] forHTTPHeaderField:httpFieldName];
		}
	}

	// Some sites refuse to respond without a User-agent string.
	[theRequest addValue:[NSString stringWithFormat:MA_DefaultUserAgentString, [((ViennaApp *)NSApp) applicationVersion]] forHTTPHeaderField:@"User-agent"];
	
	// According to the svn log, the following line was added to fix handling of MSN Spaces RSS feeds.
	// However, according to NSURLRequest.h in Tiger, the BOOL value is ignored.
	// On Leopard, it's not ignored, and we want cookie handling, so I'm commenting out the line.
	//[theRequest setHTTPShouldHandleCookies:NO];

	status = MA_Connect_Stopped;
	isConnectionComplete = NO;
	
	// Changed to not use the [NSURLConnection connectionWithRequest:delegate:  and then retain,
	// no sense putting it in an autorelease pool if it has no reason to be there
	connector = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	return connector != nil;
}

/* cancel
 * Cancel the existing connection.
 */
-(void)cancel
{
	if (!isConnectionComplete)
	{
		isConnectionComplete = YES;
		[aItem setStatus:NSLocalizedString(@"Refresh cancelled", nil)];
		status = MA_Connect_Cancelled;
		[connector cancel];
		[self sendConnectionCompleteNotification];
	}
	else if (status == MA_Connect_NeedCredentials)
	{
		[aItem setStatus:NSLocalizedString(@"Refresh cancelled", nil)];
		status = MA_Connect_Cancelled;
		[connector cancel];
		// Complete notification already scheduled.
	}
}

/* close
 * Closes the active connection.
 */
-(void)close
{
	[connector cancel];
	[connector release];
	connector = nil;
}

/* sendConnectionCompleteNotification
 * Sends a connection completion notification to the main code.
 */
-(void)sendConnectionCompleteNotification
{
	isConnectionComplete = YES;
	[[NSRunLoop currentRunLoop] performSelector:handler target:delegate argument:self order:0 modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, nil]];
}

/* didReceiveResponse
 * This method is called when the server has determined that it has enough information
 * to create the NSURLResponse it can be called multiple times, for example in the case
 * of a redirect, so each time we reset the data.
 */
-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[receivedData setLength:0];
	if ([response isKindOfClass:[NSHTTPURLResponse class]])
	{
		NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
		[responseHeaders release];
		responseHeaders = [[httpResponse allHeaderFields] retain];
		
		// Report HTTP code to the log
		if (aItem != nil)
		{
			NSEnumerator * enumerator = [responseHeaders keyEnumerator];
			NSMutableString * headerDetail = [[NSMutableString alloc] init];
			NSString * headerField;

			NSString * logText = [NSString stringWithFormat:NSLocalizedString(@"HTTP code %d reported from server", nil), [httpResponse statusCode]];
			[aItem appendDetail:logText];
			
			// Add the HTTP headers details to the log for this connection for
			// debugging purposes.
			[headerDetail setString:NSLocalizedString(@"Headers:\n", nil)];
			while ((headerField = [enumerator nextObject]) != nil)
				[headerDetail appendFormat:@"\t%@: %@\n", headerField, [[httpResponse allHeaderFields] valueForKey:headerField]];
			
			[aItem appendDetail:headerDetail];
			[headerDetail release];
		}
		
		// Get the HTTP response code and handle appropriately:
		// Code 200 means OK, more data to come.
		// Code 304 means the feed hasn't changed since the last refresh.
		// Code 410 means the feed has been intentionally removed by the server.
		if ([httpResponse statusCode] == 200)
		{
			// Is this GZIP encoded?
			// If so, report it to the detail log.
			NSString * contentEncoding = [responseHeaders valueForKey:@"Content-Encoding"];
			if ([[contentEncoding lowercaseString] isEqualToString:@"gzip"])
				[aItem appendDetail:NSLocalizedString(@"Article feed will be compressed", nil)];
		}
		else if ([httpResponse statusCode] == 410)
		{
			// The URL has been intentionally removed.
			[connection cancel];

			// Report to the activity log
			[aItem setStatus:NSLocalizedString(@"Feed has been removed by the server", nil)];

			// Complete this connection
			status = MA_Connect_URLIsGone;
			[self sendConnectionCompleteNotification];
		}
		else if ([httpResponse statusCode] == 304)
		{
			// The feed hasn't changed since our last modification so abort this
			// connection to save time.
			[connection cancel];
			
			// Report to the activity log
			[aItem setStatus:NSLocalizedString(@"No new articles available", nil)];

			// Complete this connection
			status = MA_Connect_Stopped;
			[self sendConnectionCompleteNotification];
		}
	}
}

/* didReceiveData
 * We received a new block of data from the remote. Append it to what we
 * have so far.
 */
-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[receivedData appendData:data];
}

/* willCacheResponse
 * Handle the connection's caching of the response data. We return nil to tell it not to cache anything in order to
 * try and cut down our memory usage.
 */
-(NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	return nil;
}

/* didFailWithError
 * The remote connection failed somehow. Don't do anything with the data we got
 * so far but report an error against this connection.
 */
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	// Report the failure to the log
	NSString * logText = [NSString stringWithFormat:NSLocalizedString(@"Error: %@", nil), [error localizedDescription]];
	[aItem setStatus:logText];
	
	// More details to go into the log for troubleshooting
	// purposes.
	NSMutableString * logDetail = [[NSMutableString alloc] init];
	[logDetail appendFormat:NSLocalizedString(@"Connection error (%d, %@):\n", nil), [error code], [error domain]];
	if ([error localizedDescription] != nil)
		[logDetail appendFormat:NSLocalizedString(@"\tDescription: %@\n", nil), [error localizedDescription]];
	
	NSString * suggestionString = [error localizedRecoverySuggestion];
	if (suggestionString != nil)
		[logDetail appendFormat:NSLocalizedString(@"\tSuggestion: %@\n", nil), suggestionString];
	
	NSString * reasonString = [error localizedFailureReason];
	if (reasonString != nil)
		[logDetail appendFormat:NSLocalizedString(@"\tCause: %@\n", nil), reasonString];
	
	[aItem appendDetail:logDetail];
	[logDetail release];
	
	// Complete the connection
	if (status != MA_Connect_NeedCredentials)
		status = MA_Connect_Failed;
	[self sendConnectionCompleteNotification];
}

/* didReceiveAuthenticationChallenge
 * We got an authentication challenge from the remote site. OK. Dig out that username
 * that ought to be on the folder and try it. Otherwise prompt the user. If this is
 * the second time we got this challenge then the previous credentials didn't work so
 * fail.
 */
-(void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	BOOL succeeded = NO;
	if ([challenge previousFailureCount] < 2)
	{
		if (![username isBlank])
		{
			NSURLCredential * newCredential = [NSURLCredential credentialWithUser:username password:password persistence:NSURLCredentialPersistencePermanent];
			[[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
			
			// More details in the log
			NSString * logText = [NSString stringWithFormat:NSLocalizedString(@"Attempting authentication for user '%@'", nil), username];
			[aItem appendDetail:logText];
			succeeded = YES;
		}
	}
	else
	{
		// Report the failure to the log (both as status and detail)
		NSString * logText = [NSString stringWithFormat:NSLocalizedString(@"Authentication failed for user '%@'", nil), username];
		[aItem setStatus:logText];
		[aItem appendDetail:logText];
	}
	
	// If we failed, cancel the authentication challenge which will, in turn, cancel the
	// entire connection.
	if (!succeeded)
	{
		[[challenge sender] cancelAuthenticationChallenge:challenge];
		status = MA_Connect_NeedCredentials;
	}
}

/* willSendRequest
 * Handle connect redirection. Always allow it.
 */
-(NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
	NSString * newURLString = [[request URL] absoluteString];
	NSString * text = [NSString stringWithFormat:NSLocalizedString(@"Redirecting to %@", nil), newURLString];
	[self setURLString:newURLString];
	/*if ([redirectResponse isKindOfClass:[NSHTTPURLResponse class]])
	{
		NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)redirectResponse;
		if ([httpResponse statusCode] == 301)
		{
			status = MA_Connect_PermanentRedirect;
			[delegate performSelector:handler withObject:self];
		}
	}*/
	[aItem appendDetail:text];
	return request;
}

/* connectionDidFinishLoading
 * Called when all data has been retrieved.
 */
-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	status = MA_Connect_Succeeded;
	[self sendConnectionCompleteNotification];
}

/* dealloc
 * Clean up after ourselves.
 */
-(void)dealloc
{
	[connector release];
	[httpHeaders release];
	[responseHeaders release];
	[contextData release];
	[URLString release];
	[receivedData release];
	[username release];
	[password release];
	[aItem release];
	[super dealloc];
}

@end
