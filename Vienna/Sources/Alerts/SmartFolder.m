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
#import "NSPredicateEditor+Private.h"
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
#ifdef DEBUG
        [self prepareDevelopmentOptionsButton];
#endif
    }

    [self prepareTemplates];

    // Init the folder name field and disable the Save button if it is blank
    self.folderNameTextField.stringValue = folderName;
    self.saveButton.enabled = !folderName.vna_isBlank;
}

// When changing any NSPredicateEditorRowTemplate instances, remember to also
// generate localzable strings (using `-logFormattingStrings`) and update the
// Predicates.strings files.
//
// The source strings are based on SQL column names, NSPredicate operators,
// scalar values and constant values as well as text. These source strings
// should match all possible NSPredicateEditorRowTemplate combinations, so that
// each one can be localized to display differently in the UI.
//
// NSPredicateEditor dynamically creates the UI based on the localized strings.
// Localized strings must include the same number of arguments as their source
// strings, but the arguments can be rearranged, with the exception of the first
// argument. Any text within square brackets is displayed as a (pop-up) button
// title or a menu-item title; text outside of the square brackets is displayed
// as a label instead. You can combine strings by including mutiple variants in
// the square brackets.
//
// NSPredicateEditor will create a row of UI components for each string, but
// will merge arguments where possible into pop-up buttons or menus to avoid
// duplicate entries. The format should therefore be as consistent as possible
// across each group of strings.
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

    // subject / author / text contains / = / != <text>
    NSArray<NSExpression *> *textLeftExpressions = @[
        [NSExpression expressionForConstantValue:MA_Field_Text],
        [NSExpression expressionForConstantValue:MA_Field_Author],
        [NSExpression expressionForConstantValue:MA_Field_Subject]
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

    // subject / author / text does not contain
    NSArray *doesNotContainLeftExpressions = @[
        [NSExpression expressionForConstantValue: MA_Field_Text],
        [NSExpression expressionForConstantValue: MA_Field_Subject],
        [NSExpression expressionForConstantValue: MA_Field_Author]];
    [rowTemplates addObject:[[VNADoesNotContainPredicateEditorRowTemplate alloc] initWithLeftExpressions:doesNotContainLeftExpressions]];

    [rowTemplates addObject:[VNASeparatorPredicateEditorRowTemplate new]];

    // date < / > days / weeks / months / years old
    NSPredicateEditorRowTemplate *dateCompareTemplate = [[VNADateWithUnitPredicateEditorRowTemplate alloc] 
                                                         initWithLeftExpressions:@[
                                                            [NSExpression expressionForConstantValue:MA_Field_LastUpdate],
                                                            [NSExpression expressionForConstantValue:MA_Field_PublicationDate]]];
    [rowTemplates addObject:dateCompareTemplate];

    // date = / < / <= today / yesterday / lastWeek
    NSArray<NSExpression *> *todayRightExpressions = @[
        [NSExpression expressionForConstantValue:@"today"]
    ];
    NSArray *todayOperators = @[
        @(NSEqualToPredicateOperatorType),
        @(NSLessThanPredicateOperatorType),
        @(NSLessThanOrEqualToPredicateOperatorType),
    ];
    NSPredicateEditorRowTemplate *todayTemplate = [[NSPredicateEditorRowTemplate alloc]
                                                   initWithLeftExpressions:@[
                                                      [NSExpression expressionForConstantValue:MA_Field_LastUpdate],
                                                      [NSExpression expressionForConstantValue:MA_Field_PublicationDate]]
                                                  rightExpressions:todayRightExpressions
                                                  modifier:NSDirectPredicateModifier
                                                  operators:todayOperators
                                                  options:0];
    [rowTemplates addObject:todayTemplate];

    // date = / >= / < / <= yesterday
    NSArray<NSExpression *> *yesterdayRightExpressions = @[
        [NSExpression expressionForConstantValue:@"yesterday"]
    ];
    NSArray *yesterdayOperators = @[
        @(NSEqualToPredicateOperatorType),
        @(NSLessThanPredicateOperatorType),
        @(NSLessThanOrEqualToPredicateOperatorType),
        @(NSGreaterThanOrEqualToPredicateOperatorType)
    ];
    NSPredicateEditorRowTemplate *yesterdayTemplate = [[NSPredicateEditorRowTemplate alloc]
                                                       initWithLeftExpressions:@[
                                                           [NSExpression expressionForConstantValue:MA_Field_LastUpdate],
                                                           [NSExpression expressionForConstantValue:MA_Field_PublicationDate]]
                                                       rightExpressions:yesterdayRightExpressions
                                                       modifier:NSDirectPredicateModifier
                                                       operators:yesterdayOperators
                                                       options:0];
    [rowTemplates addObject:yesterdayTemplate];

    // date = / > / >= / < / <= last week
    NSArray<NSExpression *> *weekRightExpressions = @[
        [NSExpression expressionForConstantValue:@"last week"]
    ];
    NSArray *weekOperators = @[
        @(NSEqualToPredicateOperatorType),
        @(NSGreaterThanPredicateOperatorType),
        @(NSGreaterThanOrEqualToPredicateOperatorType),
        @(NSLessThanPredicateOperatorType),
        @(NSLessThanOrEqualToPredicateOperatorType)
    ];
    NSPredicateEditorRowTemplate *dateTemplate = [[NSPredicateEditorRowTemplate alloc]
                                                  initWithLeftExpressions:@[
                                                      [NSExpression expressionForConstantValue:MA_Field_LastUpdate],
                                                      [NSExpression expressionForConstantValue:MA_Field_PublicationDate]]
                                                  rightExpressions:weekRightExpressions
                                                  modifier:NSDirectPredicateModifier
                                                  operators:weekOperators
                                                  options:0];
    [rowTemplates addObject:dateTemplate];

    [rowTemplates addObject:[VNASeparatorPredicateEditorRowTemplate new]];

    // read / flagged / deleted / has_enclosure = YES / NO
    NSArray<NSExpression *> *booleanLeftExpressions = @[
        [NSExpression expressionForConstantValue:MA_Field_Read],
        [NSExpression expressionForConstantValue:MA_Field_Flagged],
        [NSExpression expressionForConstantValue:MA_Field_Deleted],
        [NSExpression expressionForConstantValue:MA_Field_HasEnclosure]
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

    [rowTemplates addObject:[VNASeparatorPredicateEditorRowTemplate new]];

    // folder is / is not
    NSArray<NSExpression *> *folders = [self fillFolderValueField:VNAFolderTypeRoot atIndent:0];
    NSPredicateEditorRowTemplate *folderTemplate = [[NSPredicateEditorRowTemplate alloc]
        initWithLeftExpressions:@[[NSExpression expressionForConstantValue:MA_Field_Folder]]
               rightExpressions:folders
                       modifier:NSDirectPredicateModifier
                      operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType)]
                        options:0];
    [rowTemplates addObject:folderTemplate];

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

// MARK: Development options

#ifdef DEBUG

- (void)prepareDevelopmentOptionsButton
{
    NSPopUpButton *button = [[NSPopUpButton alloc] initWithFrame:NSZeroRect
                                                       pullsDown:YES];
    [button addItemWithTitle:NSLocalizedString(@"Development Options",
                                               @"Do not localize")];
    [button.menu addItemWithTitle:NSLocalizedString(@"Log Predicate String",
                                                    @"Do not localize")
                           action:@selector(logPredicateString)
                    keyEquivalent:@""];
    [button.menu addItemWithTitle:NSLocalizedString(@"Log Formatting Strings",
                                                    @"Do not localize")
                           action:@selector(logFormattingStrings)
                    keyEquivalent:@""];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [self.window.contentView addSubview:button];
    NSArray *vConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[button]"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{@"button": button}];
    NSArray *hConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:[button]-|"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{@"button": button}];
    [NSLayoutConstraint activateConstraints:vConstraints];
    [NSLayoutConstraint activateConstraints:hConstraints];
}

- (void)logPredicateString
{
    NSLog(@"Predicate: %@", self.predicateEditor.predicate.description);
}

- (void)logFormattingStrings
{
    if ([self.predicateEditor respondsToSelector:@selector(_generateFormattingDictionaryStringsFile)]) {
        NSData *data = [self.predicateEditor _generateFormattingDictionaryStringsFile];
        NSString *strings = [[NSString alloc] initWithData:data
                                                  encoding:NSUTF16StringEncoding];
        NSLog(@"Formatting dictionary strings file:\n%@", strings);
    }
}

#endif

// MARK: - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField *textField = obj.object;
    NSString *folderName = textField.stringValue;
    self.saveButton.enabled = !folderName.vna_isBlank;
}

@end
