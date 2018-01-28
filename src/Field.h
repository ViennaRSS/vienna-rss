//
//  VField.h
//  Vienna
//
//  Created by Steve on Mon Mar 22 2004.
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

// Enum of valid field types.

typedef NS_ENUM(NSUInteger, FieldType) {
	MA_FieldType_Integer = 1,
	MA_FieldType_Date,
	MA_FieldType_String,
	MA_FieldType_Flag,
	MA_FieldType_Folder
};

@interface Field : NSObject <NSCoding> {
	NSString * name;
	NSString * displayName;
	NSString * sqlField;
	FieldType type;
	NSInteger tag;
	NSInteger width;
	BOOL visible;
}

// Accessors
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *sqlField;
@property (nonatomic) NSInteger tag;
@property (nonatomic) FieldType type;
@property (nonatomic) NSInteger width;
@property (nonatomic) BOOL visible;
@end
