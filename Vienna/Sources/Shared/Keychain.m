//
//  Keychain.m
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

#import "Keychain.h"

static NSString * const VNAURLSchemeHTTPS = @"https";

@implementation VNAKeychain

/* getPasswordFromKeychain
 * Retrieves an internet password from the Keychain.
 */
+ (NSString *)getPasswordFromKeychain:(NSString *)username url:(NSString *)url
{
    NSURL *secureUrl = [NSURL URLWithString:url];
    NSString *host = secureUrl.host;
    if (!username || !secureUrl || !host) {
        return @"";
    }

    NSNumber *port = secureUrl.port != nil ? secureUrl.port : ([secureUrl.scheme caseInsensitiveCompare:VNAURLSchemeHTTPS] == NSOrderedSame ? @443 : @80);
    CFStringRef protocol = ([secureUrl.scheme caseInsensitiveCompare:VNAURLSchemeHTTPS] == NSOrderedSame) ? kSecAttrProtocolHTTPS : kSecAttrProtocolHTTP;
    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassInternetPassword,
        (__bridge NSString *)kSecAttrServer: host,
        (__bridge NSString *)kSecAttrAccount: username,
        (__bridge NSString *)kSecAttrPath: @"",
        (__bridge NSString *)kSecAttrPort: port,
        (__bridge NSString *)kSecAttrProtocol: (__bridge NSString *)protocol,
        (__bridge NSString *)kSecAttrAuthenticationType: (__bridge NSString *)kSecAttrAuthenticationTypeDefault,
        (__bridge NSString *)kSecReturnData: @YES
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                          &result);
    if (status != errSecSuccess) {
        if (result) {
            CFRelease(result);
        }
        return @"";
    }
    // The result (CFTypeRef) is a CFDataRef here, because only kSecReturnData
    // was set to YES.
    NSData *passwordData = (__bridge_transfer NSData *)result;
    NSString *password = [[NSString alloc] initWithData:passwordData
                                               encoding:NSUTF8StringEncoding];
    return password;
}

/* setPasswordInKeychain
 * Updates an internet password for the service.
 */
+ (void)setPasswordInKeychain:(NSString *)password
                     username:(NSString *)username
                          url:(NSString *)url
{
    NSURL *secureUrl = [NSURL URLWithString:url];
    NSString *host = secureUrl.host;
    if (!password || !username || !secureUrl || !host) {
        return;
    }

    NSNumber *port = secureUrl.port != nil ? secureUrl.port : ([secureUrl.scheme caseInsensitiveCompare:VNAURLSchemeHTTPS] == NSOrderedSame ? @443 : @80);
    CFStringRef protocol = ([secureUrl.scheme caseInsensitiveCompare:VNAURLSchemeHTTPS] == NSOrderedSame) ? kSecAttrProtocolHTTPS : kSecAttrProtocolHTTP;
    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassInternetPassword,
        (__bridge NSString *)kSecAttrServer: host,
        (__bridge NSString *)kSecAttrAccount: username,
        (__bridge NSString *)kSecAttrPath: @"",
        (__bridge NSString *)kSecAttrPort: port,
        (__bridge NSString *)kSecAttrProtocol: (__bridge NSString *)protocol,
        (__bridge NSString *)kSecAttrAuthenticationType: (__bridge NSString *)kSecAttrAuthenticationTypeDefault
    };
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    if (status == errSecSuccess) {
        NSDictionary *attributes = @{
            (__bridge NSString *)kSecValueData: passwordData
        };
        SecItemUpdate((__bridge CFDictionaryRef)query,
                      (__bridge CFDictionaryRef)attributes);
    } else {
        NSMutableDictionary *mutableQuery = [query mutableCopy];
        mutableQuery[(__bridge NSString *)kSecValueData] = passwordData;
        NSDictionary *attributes = [mutableQuery copy];
        SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
    }
}

/* getWebPasswordFromKeychain
 * Retrieves an web form password from the Keychain.
 */
+ (NSString *)getWebPasswordFromKeychain:(NSString *)username
                                     url:(NSString *)url
{
    NSURL *secureUrl = [NSURL URLWithString:url];
    NSString *host = secureUrl.host;
    if (!username || !secureUrl || !host) {
        return @"";
    }

    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassInternetPassword,
        (__bridge NSString *)kSecAttrServer: host,
        (__bridge NSString *)kSecAttrAccount: username,
        (__bridge NSString *)kSecAttrPath: @"",
        (__bridge NSString *)kSecAttrPort: @0,
        (__bridge NSString *)kSecAttrProtocol: (__bridge NSString *)kSecAttrProtocolHTTPS,
        (__bridge NSString *)kSecAttrAuthenticationType: (__bridge NSString *)kSecAttrAuthenticationTypeHTMLForm,
        (__bridge NSString *)kSecReturnData: @YES
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                          &result);
    if (status != errSecSuccess) {
        if (result) {
            CFRelease(result);
        }
        return @"";
    }
    // The result (CFTypeRef) is a CFDataRef here, because only kSecReturnData
    // was set to YES.
    NSData *passwordData = (__bridge_transfer NSData *)result;
    NSString *password = [[NSString alloc] initWithData:passwordData
                                               encoding:NSUTF8StringEncoding];
    return password;
}

/* getGenericPasswordFromKeychain
 * Retrieves a generic password from the Keychain.
 */
+ (NSString *)getGenericPasswordFromKeychain:(NSString *)username
                                 serviceName:(NSString *)service
{
    if (!username || !service) {
        return @"";
    }

    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
        (__bridge NSString *)kSecAttrService: service,
        (__bridge NSString *)kSecAttrAccount: username,
        (__bridge NSString *)kSecReturnData: @YES
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                          &result);
    if (status != errSecSuccess) {
        if (result) {
            CFRelease(result);
        }
        return @"";
    }
    // The result (CFTypeRef) is a CFDataRef here, because only kSecReturnData
    // was set to YES.
    NSData *passwordData = (__bridge_transfer NSData *)result;
    NSString *password = [[NSString alloc] initWithData:passwordData
                                               encoding:NSUTF8StringEncoding];
    return password;
}

/* deleteGenericPasswordInKeychain
 * delete a generic password for the service.
 */
+ (void)deleteGenericPasswordInKeychain:(NSString *)username
                                service:(NSString *)service
{
    if (!username || !service) {
        return;
    }

    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
        (__bridge NSString *)kSecAttrService: service,
        (__bridge NSString *)kSecAttrAccount: username
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
}

/* setGenericPasswordInKeychain
 * Updates a generic password for the service.
 */
+ (void)setGenericPasswordInKeychain:(NSString *)password
                            username:(NSString *)username
                             service:(NSString *)service
{
    if (!password || !username || !service) {
        return;
    }

    [self deleteGenericPasswordInKeychain:username service:service];

    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attributes = @{
        (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
        (__bridge NSString *)kSecAttrService: service,
        (__bridge NSString *)kSecAttrAccount: username,
        (__bridge NSString *)kSecValueData: passwordData
    };
    SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
}

@end
