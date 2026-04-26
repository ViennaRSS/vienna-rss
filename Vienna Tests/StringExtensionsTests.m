//
//  StringExtensionsTests.m
//  Vienna Tests
//
//  Copyright 2026 Eitot
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

@import XCTest;

#import "StringExtensions.h"

@interface VNAStringExtensionsTests : XCTestCase

@end

@implementation VNAStringExtensionsTests

- (void)testIndexOfCharacterFromIndex
{
    XCTAssertEqual([@"" vna_indexOfCharacter:'$' fromIndex:0], NSNotFound);
    XCTAssertEqual([@"$" vna_indexOfCharacter:'$' fromIndex:0], 0);
    XCTAssertEqual([@"$" vna_indexOfCharacter:'$' fromIndex:1], NSNotFound);
    XCTAssertEqual([@" $" vna_indexOfCharacter:'$' fromIndex:0], 1);
    XCTAssertEqual([@" $" vna_indexOfCharacter:'$' fromIndex:1], 1);
    XCTAssertEqual([@" $ " vna_indexOfCharacter:'$' fromIndex:0], 1);
    XCTAssertEqual([@" $ " vna_indexOfCharacter:'$' fromIndex:1], 1);
    XCTAssertEqual([@" $ " vna_indexOfCharacter:'$' fromIndex:2], NSNotFound);
    XCTAssertEqual([@"&nbsp;" vna_indexOfCharacter:'&' fromIndex:0], 0);
    XCTAssertEqual([@"&nbsp;" vna_indexOfCharacter:';' fromIndex:1], 5);
}

@end
