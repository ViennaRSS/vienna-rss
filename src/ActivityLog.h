//
//  ActivityLog.h
//  Vienna
//
//  Created by Steve on 6/21/05.
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

#import <Cocoa/Cocoa.h>

@interface ActivityItem : NSObject {
	NSString * name;
	NSString * status;
	NSMutableArray * details;
}

// Accessor functions
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, readonly, copy) NSString *details;
-(void)appendDetail:(NSString *)aString;
-(void)clearDetails;
@end

@interface ActivityLog : NSObject {
	NSMutableArray * log;
}

// Accessor functions
+(ActivityLog *)defaultLog;
@property (nonatomic, readonly, copy) NSArray *allItems;
-(ActivityItem *)itemByName:(NSString *)theName;
-(void)sortUsingDescriptors:(NSArray *)sortDescriptors;
@end
