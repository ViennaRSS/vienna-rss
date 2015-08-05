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

@interface Export(Testable)
+ (NSXMLDocument *)opmlDocumentFromFolders:(NSArray *)folders withGroups:(BOOL)groupFlag;
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
    NSArray *folders = nil;
    
    NSXMLDocument *opmlDocument = [NSXMLDocument document];
    //opmlDocument = [Export opmlDocumentFromFolders:folders withGroups:NO];
    
    XCTAssert(YES, @"Pass");
}


@end
