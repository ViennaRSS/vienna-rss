//
//  KeyChain.m
//  Vienna
//
//  Created by Steve on Sat Jul 9 2005.
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

#import "KeyChain.h"
#import <Security/SecKeychain.h>
#import <Security/SecKeychainItem.h>

@implementation KeyChain

/* getPasswordFromKeychain
 * Retrieves an internet password from the Keychain.
 */
+(NSString *)getPasswordFromKeychain:(NSString *)username url:(NSString *)url
{
	NSURL * secureUrl = [NSURL URLWithString:url];
	const char * cServiceName = [[secureUrl host] UTF8String];
	const char * cUsername = [username UTF8String];
	int portNumber = [secureUrl port] ? [[secureUrl port] intValue] : 80;
	SecProtocolType protocolType = ([[secureUrl scheme] caseInsensitiveCompare:@"https"] == NSOrderedSame) ? kSecProtocolTypeHTTPS : kSecProtocolTypeHTTP;
	NSString * thePassword;

	if (!cServiceName || !cUsername)
		thePassword = @"";
	else
	{
		const char * cPath = "";
		UInt32 passwordLength;
		void * passwordPtr;
		OSStatus status;

		status = SecKeychainFindInternetPassword(NULL,
												 strlen(cServiceName),
												 cServiceName,
												 0,
												 NULL,
												 strlen(cUsername),
												 cUsername,
												 strlen(cPath),
												 cPath,
												 portNumber,
												 protocolType,
												 kSecAuthenticationTypeDefault,
												 &passwordLength,
												 &passwordPtr,
												 NULL);
		if (status != noErr)
			thePassword = @"";
		else
		{
			thePassword = [[[NSString alloc] initWithBytes:passwordPtr length:passwordLength encoding:NSUTF8StringEncoding] autorelease];
			SecKeychainItemFreeContent(NULL, passwordPtr);
		}
	}
	return thePassword;
}

/* setPasswordInKeychain
 * Updates an internet password for the service.
 */
+(void)setPasswordInKeychain:(NSString *)password username:(NSString *)username url:(NSString *)url
{
	NSURL * secureUrl = [NSURL URLWithString:url];
	const char * cServiceName = [[secureUrl host] UTF8String];
	const char * cUsername = [username UTF8String];
	const char * cPath = "";
	int portNumber = [secureUrl port] ? [[secureUrl port] intValue] : 80;
	SecProtocolType protocolType = ([[secureUrl scheme] caseInsensitiveCompare:@"https"] == NSOrderedSame) ? kSecProtocolTypeHTTPS : kSecProtocolTypeHTTP;
	const char * cPassword = [password UTF8String];
	SecKeychainItemRef itemRef;
	OSStatus status;
	
	if (!cServiceName || !cUsername || !cPassword)
		return;
	status = SecKeychainFindInternetPassword(NULL,
											 strlen(cServiceName),
											 cServiceName,
											 0,
											 NULL,
											 strlen(cUsername),
											 cUsername,
											 strlen(cPath),
											 cPath,
											 portNumber,
											 protocolType,
											 kSecAuthenticationTypeDefault,
											 NULL,
											 NULL,
											 &itemRef);
	if (status == noErr)
		SecKeychainItemDelete(itemRef);
	SecKeychainAddInternetPassword(NULL,
								   strlen(cServiceName),
								   cServiceName,
								   0,
								   NULL,
								   strlen(cUsername),
								   cUsername,
								   strlen(cPath),
								   cPath,
								   portNumber,
								   protocolType,
								   kSecAuthenticationTypeDefault,
								   strlen(cPassword),
								   cPassword,
								   NULL);
}
@end
