//
//  XMLTag.h
//  Vienna
//
//  Created by Steve Palmer on 04/03/2007.
//  Copyright (c) 2004-2007 Steve Palmer. All rights reserved.
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

#import <Cocoa/Cocoa.h>

@interface XMLTag : NSObject {
	NSString * name;
	NSDictionary * attributes;
}

// Public functions
+(NSArray *)parserFromData:(NSData *)xmlData;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSDictionary *attributes;
@end
