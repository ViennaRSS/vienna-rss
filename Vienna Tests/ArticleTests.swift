//
//  ArticleTests.swift
//  Vienna Tests
//
//  Copyright 2020
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

import XCTest

class ArticleTests: XCTestCase {

    let guid = "07f446d2-8d6b-4d99-b488-cebc9eac7c33"
    let author = "Author McAuthorface"
    let title = "Lorem ipsum dolor sit amet"
    let link = "http://www.vienna-rss.com"
    let enclosure = "http://vienna-rss.sourceforge.net/img/vienna_logo.png"
    let enclosureFilename = "vienna_logo.png" // last path component of Enclosure
    let body = """
    <p><strong>Pellentesque habitant morbi tristique</strong> senectus et netus
    et malesuada fames ac turpis egestas. Vestibulum tortor quam, feugiat vitae,
    ultricies eget, tempor sit amet, ante. Donec eu libero sit amet quam egestas
    semper. <em>Aenean ultricies mi vitae est.</em> Mauris placerat eleifend
    leo. Quisque sit amet est et sapien ullamcorper pharetra. Vestibulum erat
    wisi, condimentum sed, <code>commodo vitae</code>, ornare sit amet, wisi.
    Aenean fermentum, elit eget tincidunt condimentum, eros ipsum rutrum orci,
    sagittis tempus lacus enim ac dui. <a href="#">Donec non enim</a> in turpis
    pulvinar facilisis. Ut felis.</p>
    """

    var article: Article!
    var articleConverter: WebKitArticleConverter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        self.article = Article(guid: guid)
        self.articleConverter = WebKitArticleConverter()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        self.article = nil
        try super.tearDownWithError()
    }

    // MARK: Article Tests

    func testAccessInstanceVariablesDirectly() {
        XCTAssertFalse(Article.accessInstanceVariablesDirectly)
    }

    // MARK: - Test custom setters

    func testTitle() {
        self.article.title = title

        XCTAssertEqual(self.article.title, title)
    }

    func testAuthor() {
        self.article.author = author

        XCTAssertEqual(self.article.author, author)
    }

    func testLink() {
        self.article.link = link

        XCTAssertEqual(self.article.link, link)
    }

    func testDate() {
        let date = Date()

        self.article.date = date

        XCTAssertEqual(self.article.date, date)
    }

    func testDateCreated() {
        let date = Date()

        self.article.createdDate = date

        XCTAssertEqual(self.article.createdDate, date)
    }

    func testBody() {
        self.article.body = body

        XCTAssertEqual(self.article.body, body)
    }

    func testEnclosure() {
        self.article.enclosure = enclosure

        XCTAssertEqual(self.article.enclosure, enclosure)
    }

    func testEnclosureRemoval() {
        self.article.enclosure = nil

        XCTAssertNil(self.article.enclosure)
    }

    func testHasEnclosure() {
        self.article.hasEnclosure = true

        XCTAssert(self.article.hasEnclosure)
    }

    func testFolderId() {
        let folderId = 111

        self.article.folderId = folderId

        XCTAssertEqual(self.article.folderId, folderId)
    }

    func testGuid() {
        self.article.guid = guid

        XCTAssertEqual(self.article.guid, guid)
    }

    func testParentId() {
        let parentId = 222

        self.article.parentId = parentId

        XCTAssertEqual(self.article.parentId, parentId)
    }

    func testStatus() {
        let status = ArticleStatus.new.rawValue

        self.article.status = status

        XCTAssertEqual(self.article.status, status)
    }

    func testMarkRead() {
        XCTAssertFalse(self.article.isRead)

        self.article.markRead(true)

        XCTAssert(self.article.isRead)
    }

    func testMarkRevised() {
        XCTAssertFalse(self.article.isRevised)

        self.article.markRevised(true)

        XCTAssert(self.article.isRevised)
    }

    func testMarkDeleted() {
        XCTAssertFalse(self.article.isDeleted)

        self.article.markDeleted(true)

        XCTAssert(self.article.isDeleted)
    }

    func testMarkFlagged() {
        XCTAssertFalse(self.article.isFlagged)

        self.article.markFlagged(true)

        XCTAssert(self.article.isFlagged)
    }

    func testMarkEnclosureDowloaded() {
        XCTAssertFalse(self.article.enclosureDownloaded)

        self.article.markEnclosureDownloaded(true)

        XCTAssert(self.article.enclosureDownloaded)
    }

    func testCompatibilityDate() {
        let date = Date()
        let dateKeyPath = "articleData." + MA_Field_Date

        self.article.date = date

        XCTAssertEqual(self.article.value(forKeyPath: dateKeyPath) as? Date, date)
    }

    func testCompatibilityAuthor() {
        let authorKeyPath = "articleData." + MA_Field_Author

        self.article.author = author

        XCTAssertEqual(self.article.value(forKeyPath: authorKeyPath) as? String, author)
    }

    func testCompatibilitySubject() {
        let subject = "Lorem ipsum dolor sit amet"
        let subjectKeyPath = "articleData." + MA_Field_Subject

        self.article.title = subject

        XCTAssertEqual(self.article.value(forKeyPath: subjectKeyPath) as? String, subject)
    }

    func testCompatibilityLink() {
        let link = "http://www.vienna-rss.com"
        let linkKeyPath = "articleData." + MA_Field_Link

        self.article.link = link

        XCTAssertEqual(self.article.value(forKeyPath: linkKeyPath) as? String, link)
    }

    func testCompatibilitySummary() {
        let summary = "Lorem ipsum dolor sit amet"
        let summaryKeyPath = "articleData." + MA_Field_Summary

        self.article.body = summary

        XCTAssertEqual(self.article.value(forKeyPath: summaryKeyPath) as? String, summary)
    }

//    func testRandomCompatibilityKeyPath() {
//        let randomArticleDataKeyPath = "articleData.dummyProperty"
//
//        XCTAssertThrowsSpecificNamed(self.article.value(forKeyPath: randomArticleDataKeyPath), NSException, NSUndefinedKeyException);
//    }

//    func testRandomKeyPath() {
//        let randomKeyPath = "dummyProperty"
//
//        XCTAssertThrowsSpecificNamed(self.article.value(forKeyPath: randomKeyPath), NSException, NSUndefinedKeyException);
//    }

    func testDescription() {
        let title = "Lorem ipsum dolor sit amet"

        self.article.guid = guid
        self.article.title = title

        let expectedDescription = String(format: "{GUID=%@ title=\"%@\"", guid, title)

        XCTAssertEqual(self.article.description, expectedDescription)
    }

    // MARK: - Expand tags

    func testExpandLinkTag() {
        let string = "$ArticleLink$/development"

        let expectedString = link + "/development"

        self.article.link = link

        let expandedString = self.articleConverter.expandTags(of: self.article, intoTemplate: string, withConditional: true)

        XCTAssertEqual(expandedString, expectedString)
    }

    func testExpandTitleTag() {
        let string = "$ArticleTitle$"
        let expectedString = title

        self.article.title = title

        let expandedString = self.articleConverter.expandTags(of: self.article, intoTemplate: string, withConditional: true)
        XCTAssertEqual(expandedString, expectedString)
    }

    func testExpandArticleBodyTag() {
        let string = "$ArticleBody$"
        let expectedString = body

        self.article.body = body

        let expandedString = self.articleConverter.expandTags(of: self.article, intoTemplate: string, withConditional: true)

        XCTAssertEqual(expandedString, expectedString)
    }

    func testExpandArticleAuthorTag() {
        let string = "$ArticleAuthor$"
        let expectedString = author

        self.article.author = author

        let expandedString = self.articleConverter.expandTags(of: self.article, intoTemplate: string, withConditional: true)

        XCTAssertEqual(expandedString, expectedString)
    }

    func testExpandArticleEnclosureLinkTag() {
        let string = "$ArticleEnclosureLink$"
        let expectedString = enclosure

        self.article.enclosure = enclosure

        let expandedString = self.articleConverter.expandTags(of: self.article, intoTemplate: string, withConditional: true)

        XCTAssertEqual(expandedString, expectedString)
    }

    func testExpandArticleEnclosureFileName() {
        let string = "$ArticleEnclosureFilename$"
        let expectedString = enclosureFilename

        self.article.enclosure = enclosure

        let expandedString = self.articleConverter.expandTags(of: self.article, intoTemplate: string, withConditional: true)

        XCTAssertEqual(expandedString, expectedString)
    }

    func testURLIDNinArticleView() {

        self.article.link = "http://ουτοπία.δπθ.gr/نجيب_محفوظ/"
        let htmlTextFromIDNALink = self.articleConverter.articleText(from: [ self.article ])

        self.article.link = "http://xn--kxae4bafwg.xn--pxaix.gr/%D9%86%D8%AC%D9%8A%D8%A8_%D9%85%D8%AD%D9%81%D9%88%D8%B8/"
        let htmlTextFromResolvedIDNALink = self.articleConverter.articleText(from: [ self.article ])

        XCTAssertEqual(htmlTextFromIDNALink, htmlTextFromResolvedIDNALink)
    }

}
