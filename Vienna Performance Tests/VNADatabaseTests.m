//
//  VNADatabaseTests.m
//  Vienna
//
//  Created by Joshua Pore on 4/03/2015.
//  Copyright (c) 2015 uk.co.opencommunity. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "Database.h"

@interface VNADatabaseTests : XCTestCase {
    FMDatabaseQueue *queue;
}

@end

@implementation VNADatabaseTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    queue = [Database sharedManager].databaseQueue;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [queue close];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        [queue inDatabase:^(FMDatabase *db) {
            FMResultSet *results = [db executeQuery:@"SELECT * from info"];
            while ([results next]) {
                NSLog(@"%@", [results resultDictionary]);
            }
            [results close];
        }];
    }];
}

@end
