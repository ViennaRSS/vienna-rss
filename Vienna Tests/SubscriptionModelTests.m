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

- (void)testVerificationOfCompleteFileURLS {
    // Test that when passed a complete file URL, the verification doesn't change the original
    NSURL *unverifiedURL = [NSURL URLWithString:@"file:///Users/test/test.xml"];
    NSURL *expectedURL = [NSURL URLWithString:@"file:///Users/test/test.xml"];
    
    XCTAssertEqualObjects(expectedURL, [subscriptionModel verifiedFeedURLFromURL:unverifiedURL]);
}

- (void)testVerificationOfCompleteWebURLS {
    // Test that then passed a complete web URL to an rss feed, the verification doesn't change the original
    NSURL *unverifiedURL = [NSURL URLWithString:@"http://www.abc.net.au/news/feed/51120/rss.xml"];
    NSURL *expectedURL = [NSURL URLWithString:@"http://www.abc.net.au/news/feed/51120/rss.xml"];
    
    XCTAssertEqualObjects(expectedURL, [subscriptionModel verifiedFeedURLFromURL:unverifiedURL]);
}

- (void)testVerificationOfIncompleteWebURLS {
    // Test that when passed a URL without an rss feed in the path component and without a scheme
    // that the returned URL is correct
    NSURL *unverifiedURL = [NSURL URLWithString:@"abc.net.au/news"];
    NSURL *expectedURL = [NSURL URLWithString:@"http://abc.net.au/news/feed/51120/rss.xml"];
    
    XCTAssertEqualObjects(expectedURL, [subscriptionModel verifiedFeedURLFromURL:unverifiedURL]);
    
}



@end
