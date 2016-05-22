//
//  ArticleTests.m
//  Vienna
//
//  Copyright © 2016 uk.co.opencommunity. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Article.h"

static NSString * const GUID = @"07f446d2-8d6b-4d99-b488-cebc9eac7c33";
static NSString * const Author = @"Author McAuthorface";
static NSString * const Title = @"Lorem ipsum dolor sit amet";
static NSString * const Link = @"http://www.vienna-rss.org";
static NSString * const Enclosure = @"http://vienna-rss.sourceforge.net/img/vienna_logo.png";
static NSString * const EnclosureFilename = @"vienna_logo.png"; // last path component of Enclosure
static NSString * const Body =
    @"<p><strong>Pellentesque habitant morbi tristique</strong> senectus et netus "
    "et malesuada fames ac turpis egestas. Vestibulum tortor quam, feugiat vitae, "
    "ultricies eget, tempor sit amet, ante. Donec eu libero sit amet quam egestas semper."
    "<em>Aenean ultricies mi vitae est.</em> Mauris placerat eleifend leo. Quisque sit amet "
    "est et sapien ullamcorper pharetra. Vestibulum erat wisi, condimentum sed, <code>commodo "
    "vitae</code>, ornare sit amet, wisi. Aenean fermentum, elit eget tincidunt condimentum, "
    "eros ipsum rutrum orci, sagittis tempus lacus enim ac dui. "
    "<a href=\"#\">Donec non enim</a> in turpis pulvinar facilisis. Ut felis.</p>";


@interface ArticleTests : XCTestCase

@property (nonatomic, strong) Article *article;

@end

@implementation ArticleTests

- (void)setUp
{
    [super setUp];

    self.article = [[Article alloc] initWithGuid:GUID];
}

- (void)testAccessInstanceVariablesDirectly
{
    XCTAssertFalse([Article accessInstanceVariablesDirectly]);
}

#pragma mark - Test custom setters

- (void)testTitle
{
    self.article.title = Title;

    XCTAssertEqualObjects(self.article.title, Title);
}

- (void)testAuthor
{
    self.article.author = Author;

    XCTAssertEqualObjects(self.article.author, Author);
}

- (void)testLink
{
    self.article.link = Link;

    XCTAssertEqualObjects(self.article.link, Link);
}

- (void)testDate
{
    NSDate *date = [NSDate date];

    self.article.date = date;

    XCTAssertEqualObjects(self.article.date, date);
}

- (void)testDateCreated
{
    NSDate *date = [NSDate date];

    self.article.createdDate = date;

    XCTAssertEqualObjects(self.article.createdDate, date);
}

- (void)testBody
{
    self.article.body = Body;

    XCTAssertEqualObjects(self.article.body, Body);
}

- (void)testEnclosure
{
    self.article.enclosure = Enclosure;

    XCTAssertEqualObjects(self.article.enclosure, Enclosure);
}

- (void)testEnclosureRemoval
{
    self.article.enclosure = nil;

    XCTAssertNil(self.article.enclosure);
}

- (void)testHasEnclosure
{
    self.article.hasEnclosure = YES;

    XCTAssert(self.article.hasEnclosure);
}

- (void)testFolderId
{
    NSInteger folderId = 111;

    self.article.folderId = folderId;

    XCTAssertEqual(self.article.folderId, folderId);
}

- (void)testGuid
{
    self.article.guid = GUID;

    XCTAssertEqualObjects(self.article.guid, GUID);
}

- (void)testParentId
{
    NSInteger parentId = 222;

    self.article.parentId = parentId;

    XCTAssertEqual(self.article.parentId, parentId);
}

- (void)testStatus
{
    NSInteger status = ArticleStatusNew;

    self.article.status = status;

    XCTAssertEqual(self.article.status, status);
}

- (void)testMarkRead
{
    XCTAssertFalse(self.article.isRead);

    [self.article markRead:YES];

    XCTAssert(self.article.isRead);
}

- (void)testMarkRevised
{
    XCTAssertFalse(self.article.isRevised);

    [self.article markRevised:YES];

    XCTAssert(self.article.isRevised);
}

- (void)testMarkDeleted
{
    XCTAssertFalse(self.article.isDeleted);

    [self.article markDeleted:YES];

    XCTAssert(self.article.isDeleted);
}

- (void)testMarkFlagged
{
    XCTAssertFalse(self.article.isFlagged);

    [self.article markFlagged:YES];

    XCTAssert(self.article.isFlagged);
}

- (void)testMarkEnclosureDowloaded
{
    XCTAssertFalse(self.article.enclosureDownloaded);

    [self.article markEnclosureDownloaded:YES];

    XCTAssert(self.article.enclosureDownloaded);
}

- (void)testCompatibilityDate
{
    NSDate *date = [NSDate date];
    NSString *dateKeyPath = [@"articleData." stringByAppendingString:MA_Field_Date];

    self.article.date = date;

    XCTAssertEqualObjects([self.article valueForKeyPath:dateKeyPath], date);
}

- (void)testCompatibilityAuthor
{
    NSString *authorKeyPath = [@"articleData." stringByAppendingString:MA_Field_Author];

    self.article.author = Author;

    XCTAssertEqualObjects([self.article valueForKeyPath:authorKeyPath], Author);
}

- (void)testCompatibilitySubject
{
    NSString *subject = @"Lorem ipsum dolor sit amet";
    NSString *subjectKeyPath = [@"articleData." stringByAppendingString:MA_Field_Subject];

    self.article.title = subject;

    XCTAssertEqualObjects([self.article valueForKeyPath:subjectKeyPath], subject);
}

- (void)testCompatibilityLink
{
    NSString *link = @"http://www.vienna-rss.org";
    NSString *linkKeyPath = [@"articleData." stringByAppendingString:MA_Field_Link];

    self.article.link = link;

    XCTAssertEqualObjects([self.article valueForKeyPath:linkKeyPath], link);
}

- (void)testCompatibilitySummary
{
    NSString *summary = @"Lorem ipsum dolor sit amet";
    NSString *summaryKeyPath = [@"articleData." stringByAppendingString:MA_Field_Summary];

    self.article.body = summary;

    XCTAssertEqualObjects([self.article valueForKeyPath:summaryKeyPath], summary);
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

- (void)testDescription
{
    NSString *title = @"Lorem ipsum dolor sit amet";

    self.article.guid = GUID;
    self.article.title = title;

    NSString *expectedDescription =
        [NSString stringWithFormat:@"{GUID=%@ title=\"%@\"", GUID, title];

    XCTAssertEqualObjects(self.article.description, expectedDescription);
}

#pragma mark - Expand tags

- (void)testExpandLinkTag
{
    NSString *string = @"$ArticleLink$";

    NSString *expectedString = [NSString stringWithFormat:@"%@/", Link];

    self.article.link = Link;

    NSString *expandedString = [self.article expandTags:string withConditional:YES];

    XCTAssertEqualObjects(expandedString, expectedString);
}

- (void)testExpandTitleTag
{
    NSString *string = @"$ArticleTitle$";
    NSString *expectedString = Title;

    self.article.title = Title;

    NSString *expandedString = [self.article expandTags:string withConditional:YES];

    XCTAssertEqualObjects(expandedString, expectedString);
}

- (void)testExpandArticleBodyTag
{
    NSString *string = @"$ArticleBody$";
    NSString *expectedString = Body;

    self.article.body = Body;

    NSString *expandedString = [self.article expandTags:string withConditional:YES];

    XCTAssertEqualObjects(expandedString, expectedString);
}

- (void)testExpandArticleAuthorTag
{
    NSString *string = @"$ArticleAuthor$";
    NSString *expectedString = Author;

    self.article.author = Author;

    NSString *expandedString = [self.article expandTags:string withConditional:YES];

    XCTAssertEqualObjects(expandedString, expectedString);
}

- (void)testExpandArticleEnclosureLinkTag
{
    NSString *string = @"$ArticleEnclosureLink$";
    NSString *expectedString = Enclosure;

    self.article.enclosure = Enclosure;

    NSString *expandedString = [self.article expandTags:string withConditional:YES];

    XCTAssertEqualObjects(expandedString, expectedString);
}

- (void)testExpandArticleEnclosureFileName
{
    NSString *string = @"$ArticleEnclosureFilename$";
    NSString *expectedString = EnclosureFilename;

    self.article.enclosure = Enclosure;

    NSString *expandedString = [self.article expandTags:string withConditional:YES];

    XCTAssertEqualObjects(expandedString, expectedString);
}

@end
