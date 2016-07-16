//
//  RichXMLParserTests.m
//  Vienna
//
//  Created by Joshua Pore on 7/08/2015.
//  Copyright (c) 2015 uk.co.opencommunity. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "RichXMLParser.h"

@interface RichXMLParserTests : XCTestCase

@end

@implementation RichXMLParserTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testParseRichXML {
    BOOL success = NO;
    // Test extracting feeds to an array
    NSURL *url = [NSURL fileURLWithPath:@"/Users/josh/test.rdf"];
    // old parser
    NSData *feedData = [NSData dataWithContentsOfURL:url];
    RichXMLParser *oldParser = [[RichXMLParser alloc] init];
    BOOL oldParsedOK = [oldParser parseRichXML:feedData];
    // new parser
    if (oldParsedOK){
        
    }
//    XCTAssertTrue(success, "Pass");
}

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
