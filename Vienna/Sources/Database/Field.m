//
//  Field.m
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

#import "Field.h"

static NSString * const VNACodingKeyDisplayName = @"displayName";
static NSString * const VNACodingKeyName = @"name";
static NSString * const VNACodingKeySQLField = @"sqlField";
static NSString * const VNACodingKeyTag = @"tag";
static NSString * const VNACodingKeyType = @"type";
static NSString * const VNACodingKeyVisible = @"visible";
static NSString * const VNACodingKeyWidth = @"width";
static NSString * const VNACodingKeyCustomizationOptions = @"customizationOptions";

@implementation Field

// MARK: Initialization

- (instancetype)init
{
    self = [super init];
    if (self) {
        _name = nil;
        _displayName = nil;
        _sqlField = nil;
        _type = VNAFieldTypeInteger;
        _width = 20;
        _visible = NO;
        _customizationOptions = (VNAFieldCustomizationVisibility |
                                 VNAFieldCustomizationResizing |
                                 VNAFieldCustomizationSorting);
    }
    return self;
}

// MARK: Overrides

- (NSString *)description
{
    return [NSString stringWithFormat:@"('%@', displayName='%@', sqlField='%@'"
                                       ", width=%ld, visible=%d"
                                       ", customizationOptions=%lu)",
                                      self.name, self.displayName,
                                      self.sqlField, self.width,
                                      self.isVisible, self.customizationOptions];
}

// MARK: - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        if (coder.allowsKeyedCoding) {
            _name = [coder decodeObjectOfClass:[NSString class]
                                        forKey:VNACodingKeyName];
            _displayName = [coder decodeObjectOfClass:[NSString class]
                                               forKey:VNACodingKeyDisplayName];
            _sqlField = [coder decodeObjectOfClass:[NSString class]
                                            forKey:VNACodingKeySQLField];
            _type = [coder decodeIntegerForKey:VNACodingKeyType];
            _width = [coder decodeIntegerForKey:VNACodingKeyWidth];
            _visible = [coder decodeBoolForKey:VNACodingKeyVisible];
            _customizationOptions = [coder decodeIntegerForKey:VNACodingKeyCustomizationOptions];
        } else {
            // NSUnarchiver is deprecated since macOS 10.13 and replaced with
            // NSKeyedUnarchiver. For backwards-compatibility with NSArchiver,
            // decoding using NSUnarchiver is still supported.
            //
            // Important: The order in which the values are decoded must match
            // the order in which they were encoded. Changing the code below can
            // lead to decoding failure.
            _displayName = [coder decodeObject];
            _name = [coder decodeObject];
            _sqlField = [coder decodeObject];
            [coder decodeValueOfObjCType:@encode(bool)
                                      at:&_visible
                                    size:sizeof(bool)];
            [coder decodeValueOfObjCType:@encode(NSInteger)
                                      at:&_width
                                    size:sizeof(NSInteger)];
            // Previously created archives still have the tag property.
            NSInteger tag;
            [coder decodeValueOfObjCType:@encode(NSInteger)
                                      at:&tag
                                    size:sizeof(NSInteger)];
            [coder decodeValueOfObjCType:@encode(NSInteger)
                                      at:&_type
                                    size:sizeof(NSInteger)];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArchiveOperationException
                    format:@"Coder does not support keyed coding."];
        return;
    }
    [coder encodeObject:self.name forKey:VNACodingKeyName];
    [coder encodeObject:self.displayName forKey:VNACodingKeyDisplayName];
    [coder encodeObject:self.sqlField forKey:VNACodingKeySQLField];
    [coder encodeInteger:self.type forKey:VNACodingKeyType];
    [coder encodeInteger:self.width forKey:VNACodingKeyWidth];
    [coder encodeBool:self.isVisible forKey:VNACodingKeyVisible];
    [coder encodeInteger:self.customizationOptions forKey:VNACodingKeyCustomizationOptions];
}

@end
