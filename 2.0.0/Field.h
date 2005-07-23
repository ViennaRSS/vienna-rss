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

#import <Foundation/Foundation.h>

// Enum of valid field types.
typedef enum {
	MA_FieldType_Integer = 1,
	MA_FieldType_Date,
	MA_FieldType_String,
	MA_FieldType_Flag,
	MA_FieldType_Folder
} FieldType;

@interface Field : NSObject <NSCoding> {
	NSString * name;
	NSString * displayName;
	NSString * sqlField;
	FieldType type;
	int tag;
	int width;
	BOOL visible;
}

// Accessor functions
-(void)setName:(NSString *)newName;
-(void)setDisplayName:(NSString *)newDisplayName;
-(void)setSqlField:(NSString *)newSqlField;
-(void)setType:(FieldType)newType;
-(void)setTag:(int)newTag;
-(void)setVisible:(BOOL)flag;
-(void)setWidth:(int)newWidth;
-(NSString *)name;
-(NSString *)displayName;
-(NSString *)sqlField;
-(int)tag;
-(FieldType)type;
-(int)width;
-(BOOL)visible;
@end
