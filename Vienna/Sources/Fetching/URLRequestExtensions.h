//
//  URLRequestExtensions.h
//  Vienna
//
//  Created by Barijaona Ramaholimihaso on 03/08/2018.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

// category of NSMutableURLRequest for adding properties with getter and setter
@interface NSMutableURLRequest (userDict)

@property (setter=vna_setUserInfo:, copy, nullable) id vna_userInfo;
// add/set object into current userInfo
-(void)vna_setInUserInfo:(nullable id)object forKey:(NSString *)key;
-(void)vna_addInfoFromDictionary:(nullable NSDictionary *)additionalDictionary;

@end

// category of "POST" NSMutableURLRequest for setting POST values
@interface NSMutableURLRequest (MutablePostExtensions)

- (void)vna_setPostValue:(nullable NSString *)value
                  forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
