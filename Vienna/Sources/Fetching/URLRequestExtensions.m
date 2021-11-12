//
//  URLRequestExtensions.m
//  Vienna
//
//  Created by Barijaona Ramaholimihaso on 03/08/2018.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

#import "URLRequestExtensions.h"

// we extend the capabilities of NSMutableURLRequest and store and retrieve specific request data
// by using NSURLProtocol’s class methods propertyForKey:inRequest: and setProperty:forKey:inRequest:
@implementation NSMutableURLRequest (userDict)

-(id)vna_userInfo
{
    return [NSURLProtocol propertyForKey:NSStringFromSelector(@selector(vna_userInfo)) inRequest:self];
}

-(void)vna_setUserInfo:(id)userDict
{
    [NSURLProtocol setProperty:userDict forKey:NSStringFromSelector(@selector(vna_userInfo)) inRequest:self];
}

-(void)vna_setInUserInfo:(id)object forKey:(NSString *)key
{
    NSMutableDictionary *workingDict =
        [((NSDictionary *)[NSURLProtocol propertyForKey:NSStringFromSelector(@selector(vna_userInfo)) inRequest:self]) mutableCopy];
    if (workingDict == nil) {
        workingDict = [[NSMutableDictionary alloc] init];
    }

    [workingDict setObject:object forKeyedSubscript:key];
    [NSURLProtocol setProperty:[NSDictionary dictionaryWithDictionary:workingDict] forKey:NSStringFromSelector(@selector(vna_userInfo))
                     inRequest:self];
}

-(void)vna_addInfoFromDictionary:(NSDictionary *)additionalDictionary
{
    NSDictionary *currentDict = [NSURLProtocol propertyForKey:NSStringFromSelector(@selector(vna_userInfo)) inRequest:self];
    if (currentDict == nil) {
        [NSURLProtocol setProperty:additionalDictionary forKey:NSStringFromSelector(@selector(vna_userInfo)) inRequest:self];
    } else {
        NSMutableDictionary *workingDict = [NSMutableDictionary dictionaryWithDictionary:currentDict];
        [workingDict addEntriesFromDictionary:additionalDictionary];
        [NSURLProtocol setProperty:[NSDictionary dictionaryWithDictionary:workingDict] forKey:NSStringFromSelector(@selector(vna_userInfo))
                         inRequest:self];
    }
}

@end

// create or extend HTTP body (for "application/x-www-form-urlencoded" content type)
@implementation NSMutableURLRequest (MutablePostExtensions)

-(void)vna_setPostValue:(NSString *)value forKey:(NSString *)key
{
    NSMutableData *data1;
    NSData *data2;
    NSString *stringData;

    data1 = [NSMutableData dataWithData:self.HTTPBody];
    // reference for our character set : unreserved characters in section 2.3 of RFC3986
    NSCharacterSet * charSet = [NSCharacterSet characterSetWithCharactersInString:
	    @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    stringData = [NSString stringWithFormat:@"%@=%@",
        [key stringByAddingPercentEncodingWithAllowedCharacters:charSet],
        [value stringByAddingPercentEncodingWithAllowedCharacters:charSet]];
    if (data1.length > 0) {
        stringData = [NSString stringWithFormat:@"&%@", stringData];
    }
    data2 = [stringData dataUsingEncoding:NSUTF8StringEncoding];
    [data1 appendData:data2];
    self.HTTPBody = data1;
    [self setValue:[NSString stringWithFormat:@"%lu", (unsigned long)data1.length] forHTTPHeaderField:@"Content-Length"];
}

@end
