//
//  CriteriaTests.m
//  Vienna
//
//  Created by Joshua Pore on 5/08/2015.
//  Copyright (c) 2015 uk.co.opencommunity. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "Criteria.h"

@interface CriteriaTests : XCTestCase

@end

@implementation CriteriaTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}



- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}
@end
                                    

@interface CriteriaTreeTests : XCTestCase

@end

@implementation CriteriaTreeTests


- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testCriteriaTreeInitWithString {
    // This tests initialising a CriteriaTree with a string.
    // Only called by the Database class when loading smart folders
    NSString *criteriaTreeString = @"<?xml version=\"1.0\" encoding=\"utf-8\"?><criteriagroup condition=\"all\"><criteria field=\"Flagged\"><operator>1</operator><value>Yes</value></criteria></criteriagroup>";
    
    CriteriaTree *testCriteriaTree = [[CriteriaTree alloc] initWithString:criteriaTreeString];
    NSArray *allCriteria = [testCriteriaTree criteriaEnumerator].allObjects;
    XCTAssertTrue([allCriteria.firstObject isKindOfClass:Criteria.class], @"Pass");

}

- (void)testCriteriaTreeInitWithString2 {
    // This tests initialising a CriteriaTree with a string that has
    // multiple criteria.
    // Only called by the Database class when loading smart folders
    NSString *criteriaTreeString = @"<?xml version=\"1.0\" encoding=\"utf-8\"?><criteriagroup condition=\"all\"><criteria field=\"Flagged\"><operator>1</operator><value>Yes</value></criteria><criteria field=\"Date\"><operator>1</operator><value>today</value></criteria></criteriagroup>";
    
    CriteriaTree *testCriteriaTree = [[CriteriaTree alloc] initWithString:criteriaTreeString];
    NSArray *allCriteria = [testCriteriaTree criteriaEnumerator].allObjects;
    XCTAssertGreaterThan(allCriteria.count, 1, @"Pass");
}

- (void)testCriteriaTreeString {
    // This tests returning a criteria tree as an XML string
    NSString *criteriaTreeString = @"<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\"?><criteriagroup condition=\"all\"><criteria field=\"Flagged\"><operator>1</operator><value>Yes</value></criteria></criteriagroup>";
    
    CriteriaTree *testCriteriaTree = [[CriteriaTree alloc] initWithString:criteriaTreeString];
    XCTAssertEqualObjects([testCriteriaTree string].lowercaseString, criteriaTreeString.lowercaseString);
}

@end
