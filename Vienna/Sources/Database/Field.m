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

@implementation Field

// MARK: Initialization

- (instancetype)init
{
    self = [super init];

    if (self) {
        _name = nil;
        _displayName = nil;
        _sqlField = nil;
        _tag = -1;
        _type = VNAFieldTypeInteger;
        _width = 20;
        _visible = NO;
    }

    return self;
}

// MARK: Overrides

- (NSString *)description
{
    return [NSString stringWithFormat:@"('%@', displayName='%@', sqlField='%@'"
                                       ", tag=%ld, width=%ld, visible=%d)",
                                      self.name, self.displayName,
                                      self.sqlField, self.tag, self.width,
                                      self.visible];
}

// MARK: - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];

    if (self) {
        _displayName = [coder decodeObject];
        _name = [coder decodeObject];
        _sqlField = [coder decodeObject];
        [coder decodeValueOfObjCType:@encode(bool) at:&_visible];
        [coder decodeValueOfObjCType:@encode(NSInteger) at:&_width];
        [coder decodeValueOfObjCType:@encode(NSInteger) at:&_tag];
        [coder decodeValueOfObjCType:@encode(NSInteger) at:&_type];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.displayName];
    [coder encodeObject:self.name];
    [coder encodeObject:self.sqlField];
    [coder encodeValueOfObjCType:@encode(bool) at:&_visible];
    [coder encodeValueOfObjCType:@encode(NSInteger) at:&_width];
    [coder encodeValueOfObjCType:@encode(NSInteger) at:&_tag];
    [coder encodeValueOfObjCType:@encode(NSInteger) at:&_type];
}

@end
