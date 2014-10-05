//
//  SubscriptionModelTests.m
//  Vienna
//
//  Created by Joshua Pore on 5/10/2014.
//  Copyright (c) 2014 uk.co.opencommunity. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "SubscriptionModel.h"

@interface SubscriptionModelTests : XCTestCase {
    SubscriptionModel *subscriptionModel;
}

@end

@implementation SubscriptionModelTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    subscriptionModel = [[SubscriptionModel alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [subscriptionModel release];
    subscriptionModel = nil;
}

- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
