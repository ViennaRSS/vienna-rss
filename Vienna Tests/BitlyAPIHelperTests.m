//
//  BitlyAPIHelperTests.m
//  Vienna
//
//  Created by Joshua Pore on 5/08/2015.
//  Copyright (c) 2015 uk.co.opencommunity. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "BitlyAPIHelper.h"

@interface BitlyAPIHelperTests : XCTestCase

@end

@implementation BitlyAPIHelperTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testShortenURL {
    // This tests the bitly shorten URL function
    BitlyAPIHelper * bitlyHelper = [[BitlyAPIHelper alloc] initWithLogin:@"viennarss" andAPIKey:@"R_852929122e82d2af45fe9e238f1012d3"];
    NSString *shortURL = [NSString stringWithString:[bitlyHelper shortenURL:@"http://www.vienna-rss.org"]];
    NSLog(@"shortened URL: %@", shortURL);
    XCTAssertTrue([shortURL containsString:@"bit.ly"]);
}

@end
