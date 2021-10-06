//
//  Field.h
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

@import Foundation;

/// Enum of valid field types.
typedef NS_ENUM(NSUInteger, VNAFieldType) {
    VNAFieldTypeInteger = 1,
    VNAFieldTypeDate,
    VNAFieldTypeString,
    VNAFieldTypeFlag,
    VNAFieldTypeFolder
} NS_SWIFT_NAME(Field.FieldType);

@interface Field : NSObject <NSCoding>

/// The field name is the unlocalised display name; useful for writing to data
/// files where sysName isn't appropriate.
@property (copy, nonatomic) NSString *name;

/// This is the name that is intended to be displayed in the UI.
@property (copy, nonatomic) NSString *displayName;

/// The SQL column name of the field. This must correspond to the name used in
/// the 'create table' statement when the table of which this field is part was
/// originally created.
@property (copy, nonatomic) NSString *sqlField;

/// The tag is simply an unique integer that identifies the field in the same
/// way that the field name is used. I suspect that at some point one of these
/// two will be deprecated for simplicity.
@property (nonatomic) NSInteger tag;

/// Sets the field type. This must be one of the valid values in the FieldType
/// enum. The field type is used to govern how the field value is interpreted.
@property (nonatomic) VNAFieldType type;

/// The default width of the field in the article list view.
@property (nonatomic) NSInteger width;

/// Whether this field is intended to be visible in the article list view by
/// default.
@property (nonatomic) BOOL visible;

@end
