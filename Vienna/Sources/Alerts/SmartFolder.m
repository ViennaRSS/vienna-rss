//
//  SmartFolder.m
//  Vienna
//
//  Created by Steve on Sun Apr 18 2004.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "SmartFolder.h"

#import "AppController.h"
#import "Database.h"
#import "Folder.h"
#import "StringExtensions.h"
#import "Vienna-Swift.h"

static NSNibName const VNASmartFolderNibName = @"SearchFolder";

@interface SmartFolder () <NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *folderNameTextField;
@property (weak) IBOutlet NSPredicateEditor *predicateEditor;
@property (weak) IBOutlet NSButton *saveButton;

@property Database *database;
@property NSInteger smartFolderId;
@property NSInteger parentId;

@end

@implementation SmartFolder

// MARK: Initialization

- (instancetype)initWithDatabase:(Database *)database
{
    self = [super init];
    if (self) {
        _smartFolderId = -1;
        _database = database;
        _parentId = VNAFolderTypeRoot;
    }
    return self;
}

// MARK: Presenting the editor

- (void)newCriteria:(NSWindow *)window underParent:(NSInteger)itemId
{
    [self initSearchSheet:@""];
    self.smartFolderId = -1;
    self.parentId = itemId;
    self.folderNameTextField.enabled = YES;

    /// Add a new default criteria row. For this we use the static defaultField
    /// declared at the start of this source and the default operator for that
    /// field, and an empty value.
    NSPredicate *defaultPredicate = [NSPredicate predicateWithFormat:@"'Subject' CONTAINS %@", @""];
    NSPredicate *compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[defaultPredicate]];
    self.predicateEditor.objectValue = compoundPredicate;

    [window beginSheet:self.window completionHandler:nil];
}

- (void)loadCriteria:(NSWindow *)window folderId:(NSInteger)folderId
{
    Folder *folder = [self.database folderFromID:folderId];
    if (folder) {
        [self initSearchSheet:folder.name];
        self.smartFolderId = folderId;
        self.folderNameTextField.enabled = YES;

        // Load the criteria into the fields.
        CriteriaTree *criteriaTree = [self.database searchStringForSmartFolder:folderId];

        self.predicateEditor.objectValue = criteriaTree.predicate;

        [window beginSheet:self.window completionHandler:nil];
    }
}

- (void)initSearchSheet:(NSString *)folderName
{
    if (!self.window) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        [bundle loadNibNamed:VNASmartFolderNibName
                       owner:self
             topLevelObjects:nil];
        self.folderNameTextField.delegate = self;
    }

    [self prepareTemplates];

    // Init the folder name field and disable the Save button if it is blank
    self.folderNameTextField.stringValue = folderName;
    self.saveButton.enabled = !folderName.vna_isBlank;
}

- (void)prepareTemplates
{
    NSMutableArray<NSPredicateEditorRowTemplate *> *rowTemplates = [NSMutableArray array];

    NSArray *compoundTypes = @[
        @(NSAndPredicateType),
        @(NSOrPredicateType),
        @(NSNotPredicateType)
    ];
    NSPredicateEditorRowTemplate *compoundTemplate = [[NSPredicateEditorRowTemplate alloc] initWithCompoundTypes:compoundTypes];
    [rowTemplates addObject:compoundTemplate];

    // not contains
    NSArray *doesNotContainLeftExpressions = @[
        [NSExpression expressionForConstantValue: MA_Field_Text],
        [NSExpression expressionForConstantValue: MA_Field_Subject],
        [NSExpression expressionForConstantValue: MA_Field_Author]];
    [rowTemplates addObject:[[VNANotContainsPredicateEditorRowTemplate alloc] initWithLeftExpressions:doesNotContainLeftExpressions]];

    // folder is / is not
    NSArray<NSExpression *> *folders = [self fillFolderValueField:VNAFolderTypeRoot atIndent:0];

    NSPredicateEditorRowTemplate *folderTemplate = [[NSPredicateEditorRowTemplate alloc]
        initWithLeftExpressions:@[[NSExpression expressionForConstantValue:@"Folder"]]
               rightExpressions:folders
                       modifier:NSDirectPredicateModifier
                      operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType)]
                        options:0];

    [rowTemplates addObject:folderTemplate];

    // read / flagged / deleted = YES / NO
    NSArray<NSExpression *> *booleanLeftExpressions = @[
        [NSExpression expressionForConstantValue:@"Read"],
        [NSExpression expressionForConstantValue:@"Flagged"],
        [NSExpression expressionForConstantValue:@"Deleted"],
        [NSExpression expressionForConstantValue:@"HasEnclosure"]
    ];
    NSArray<NSExpression *> *booleanRightExpressions = @[
        [NSExpression expressionForConstantValue:@"Yes"],
        [NSExpression expressionForConstantValue:@"No"]
    ];
    NSPredicateEditorRowTemplate *booleanTemplate =
        [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:booleanLeftExpressions
                                                     rightExpressions:booleanRightExpressions
                                                             modifier:NSDirectPredicateModifier
                                                            operators:@[@(NSEqualToPredicateOperatorType)]
                                                              options:0];

    [rowTemplates addObject:booleanTemplate];

    // date = / > / >= / < / <= today / yesterday / last week
    NSArray<NSExpression *> *dateRightExpressions = @[
        [NSExpression expressionForConstantValue:@"today"],
        [NSExpression expressionForConstantValue:@"yesterday"],
        [NSExpression expressionForConstantValue:@"last week"]
    ];
    NSPredicateEditorRowTemplate *dateTemplate = [[NSPredicateEditorRowTemplate alloc]
        initWithLeftExpressions:@[[NSExpression expressionForConstantValue:@"Date"]]
               rightExpressions:dateRightExpressions
                       modifier:NSDirectPredicateModifier
                      operators:@[
                          @(NSEqualToPredicateOperatorType),
                          @(NSLessThanPredicateOperatorType),
                          @(NSLessThanOrEqualToPredicateOperatorType),
                          @(NSGreaterThanPredicateOperatorType),
                          @(NSGreaterThanOrEqualToPredicateOperatorType)
                      ]
                        options:0];

    [rowTemplates addObject:dateTemplate];

    // subject / author / text contains / = / != <text>
    NSArray<NSExpression *> *textLeftExpressions = @[
        [NSExpression expressionForConstantValue:@"Subject"],
        [NSExpression expressionForConstantValue:@"Author"],
        [NSExpression expressionForConstantValue:@"Text"]
    ];
    NSPredicateEditorRowTemplate *textTemplate = [[NSPredicateEditorRowTemplate alloc]
             initWithLeftExpressions:textLeftExpressions
        rightExpressionAttributeType:NSStringAttributeType
                            modifier:NSDirectPredicateModifier
                           operators:@[
                               @(NSEqualToPredicateOperatorType),
                               @(NSNotEqualToPredicateOperatorType),
                               @(NSContainsPredicateOperatorType)
                           ]
                             options:0];

    [rowTemplates addObject:textTemplate];

    self.predicateEditor.rowTemplates = rowTemplates;
}

/// Fill the folder value field popup menu with a list of all RSS and group
/// folders in the database under the specified folder ID. The indentation value
/// is used to indent the items in the menu when they are part of a group. I've
/// used an increment of 2 which looks clearer than 1 in the UI.
- (NSArray<NSExpression *> *)fillFolderValueField:(NSInteger)fromId
                                         atIndent:(NSInteger)indentation
{
    NSMutableArray<NSExpression *> *expressions = [NSMutableArray array];
    NSArray *folders = [self.database arrayOfFolders:fromId];
    NSArray *sortedFolders = [folders sortedArrayUsingSelector:@selector(folderNameCompare:)];
    for (Folder *folder in sortedFolders) {
        if (folder.type == VNAFolderTypeRSS ||
            folder.type == VNAFolderTypeOpenReader ||
            folder.type == VNAFolderTypeGroup) {
            NSString *indentSpaces = [@"" stringByPaddingToLength:indentation * 2
                                                       withString:@" "
                                                  startingAtIndex:0];
            NSString *constantValue = [indentSpaces stringByAppendingString:folder.name];
            [expressions addObject:[NSExpression expressionForConstantValue:constantValue]];
            if (folder.type == VNAFolderTypeGroup) {
                [expressions addObjectsFromArray:[self fillFolderValueField:folder.itemId
                                                                   atIndent:indentation + 1]];
            }
        }
    }
    return expressions;
}

// MARK: Responder actions

- (IBAction)doCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window];
    [self.window orderOut:self];
}

- (IBAction)doSave:(id)sender
{
    NSString *folderName = self.folderNameTextField.stringValue;
    CriteriaTree *criteriaTree = [[CriteriaTree alloc] initWithPredicate:self.predicateEditor.objectValue];

    if (self.smartFolderId == -1) {
        AppController *controller = APPCONTROLLER;
        self.smartFolderId = [Database.sharedManager addSmartFolder:folderName
                                                        underParent:self.parentId
                                                          withQuery:criteriaTree];
        [controller selectFolder:self.smartFolderId];
    } else {
        [Database.sharedManager updateSearchFolder:self.smartFolderId
                                        withFolder:folderName
                                         withQuery:criteriaTree];
    }

    [self.window.sheetParent endSheet:self.window];
    [self.window orderOut:self];
}

// MARK: - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField *textField = obj.object;
    NSString *folderName = textField.stringValue;
    self.saveButton.enabled = !folderName.vna_isBlank;
}

@end
