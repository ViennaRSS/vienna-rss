//
//  URLRequestExtensions.h
//  Vienna
//
//  Created by Barijaona Ramaholimihaso on 03/08/2018.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

#import <Foundation/Foundation.h>

// category of NSMutableURLRequest for adding properties with getter and setter
@interface NSMutableURLRequest (userDict)
@property (nullable, copy, setter=setUserInfo:) id userInfo;
// add/set object into current userInfo
-(void)setInUserInfo:(nullable id)object forKey:(nonnull NSString *)key;
-(void)addInfoFromDictionary:(NSDictionary *_Nonnull)additionalDictionary;
@end

// category of "POST" NSMutableURLRequest for setting POST values
@interface NSMutableURLRequest (MutablePostExtensions)
-(void)setPostValue:(nullable NSString *)value forKey:(nonnull NSString *)key;
@end
