//
//  ExportTests.m
//  Vienna
//
//  Created by Joshua Pore on 5/08/2015.
//  Copyright (c) 2015 uk.co.opencommunity. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "Export.h"
#import "Database.h"

@interface Export(Testable)
+ (NSXMLDocument *)opmlDocumentFromFolders:(NSArray *)folders withGroups:(BOOL)groupFlag exportCount:(int *)countExported;
@end

@interface ExportTests : XCTestCase

@end

@implementation ExportTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExportWithoutGroups {
    // Test exporting feeds to opml file without groups
    NSArray *folders = [self foldersArray];
    NSURL *tmpUrl = [NSURL URLWithString:@"/tmp/vienna-test-nogroups.opml"];
    
    NSInteger countExported = [Export exportToFile:tmpUrl.absoluteString from:folders inFoldersTree:nil withGroups:NO];
    XCTAssertGreaterThan(countExported, 0, @"Pass");
}

- (void)testExportWithGroups {
    // Test exporting feeds to opml file without groups
    NSArray *folders = [self foldersArray];
    NSURL *tmpUrl = [NSURL URLWithString:@"/tmp/vienna-test-groups.opml"];
    
    NSInteger countExported = [Export exportToFile:tmpUrl.absoluteString from:folders inFoldersTree:nil withGroups:YES];
    XCTAssertGreaterThan(countExported, 0, @"Pass");
}


// Test helper method to return an array of folders for export
- (NSArray *)foldersArray {
    Database *db = [Database sharedManager];
    NSArray *foldersArray = [db arrayOfAllFolders];
    return foldersArray;
}


@end
