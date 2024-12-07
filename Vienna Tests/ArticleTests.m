//
//  VNAArticleTests.m
//  Vienna
//
//  Copyright © 2016 uk.co.opencommunity. All rights reserved.
//

@import XCTest;

#import "Article.h"
#import "Vienna_Tests-Swift.h"

static NSString * const guid = @"07f446d2-8d6b-4d99-b488-cebc9eac7c33";

@interface VNAArticleTests : XCTestCase

@property (nonatomic) Article *article;

@end

@implementation VNAArticleTests

- (void)setUp
{
    self.article = [[Article alloc] initWithGUID:guid];
}

- (void)tearDown
{
    self.article = nil;
}

- (void)testRandomCompatibilityKeyPath
{
    NSString *randomArticleDataKeyPath = [@"articleData." stringByAppendingString:@"dummyProperty"];

    XCTAssertThrowsSpecificNamed([self.article valueForKeyPath:randomArticleDataKeyPath],
                                 NSException,
                                 NSUndefinedKeyException);
}

- (void)testRandomKeyPath
{
    NSString *randomKeyPath = @"dummyProperty";

    XCTAssertThrowsSpecificNamed([self.article valueForKeyPath:randomKeyPath],
                                 NSException,
                                 NSUndefinedKeyException);
}

@end
