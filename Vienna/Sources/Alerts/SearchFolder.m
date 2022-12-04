//
//  SearchFolder.m
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

#import "SearchFolder.h"
#import "StringExtensions.h"
#import "AppController.h"
#import "HelperFunctions.h"
#import "Article.h"
#import "Folder.h"
#import "Criteria.h"
#import "Field.h"
#import "Database.h"
#import "Vienna-Swift.h"

@interface SmartFolder ()
@property (weak) IBOutlet NSScrollView *predicateView;
@property (weak) IBOutlet NSPredicateEditor *predicateEditor;

-(void)initSearchSheet:(NSString *)folderName;
-(void)displaySearchSheet:(NSWindow *)window;
-(void)addDefaultCriteria;

@end

@implementation SmartFolder

/* initWithDatabase
 * Just init the search criteria class.
 */
-(instancetype)initWithDatabase:(Database *)newDb
{
	if ((self = [super init]) != nil)
	{
		totalCriteria = 0;
		smartFolderId = -1;
		db = newDb;
		onScreen = NO;
		parentId = VNAFolderTypeRoot;
		arrayOfViews = [[NSMutableArray alloc] init];
	}
	return self;
}

/* newCriteria
 * Initialises the smart folder panel with a single default criteria to get
 * started.
 */
-(void)newCriteria:(NSWindow *)window underParent:(NSInteger)itemId
{
    [self initSearchSheet:@""];
    smartFolderId = -1;
    parentId = itemId;
    [smartFolderName setEnabled:YES];

    // Add a default criteria.
	[self addDefaultCriteria];
	[self displaySearchSheet:window];
}

/* loadCriteria
 * Loads the criteria for the specified folder,
 * then display the search sheet.
 */
-(void)loadCriteria:(NSWindow *)window folderId:(NSInteger)folderId
{
	Folder * folder = [db folderFromID:folderId];
	if (folder != nil)
	{
		[self initSearchSheet:folder.name];
		smartFolderId = folderId;
		[smartFolderName setEnabled:YES];

		// Load the criteria into the fields.
		CriteriaTree * criteriaTree = [db searchStringForSmartFolder:folderId];

        [[self predicateEditor] setObjectValue:[criteriaTree predicate]];

		// We defer sizing the window until all the criteria are
		// added and displayed, otherwise it looks crap.
		[self displaySearchSheet:window];
	}
}

/* initSearchSheet
 */
-(void)initSearchSheet:(NSString *)folderName
{
	// Initialize UI
	if (!searchWindow)
	{
		NSArray * objects;
		[[NSBundle bundleForClass:[self class]] loadNibNamed:@"SearchFolder" owner:self topLevelObjects:&objects];
		self.topObjects = objects;

		// Register our notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:smartFolderName];
	}

    [self prepareTemplates];


	// Init the folder name field and disable the Save button if it is blank
	smartFolderName.stringValue = folderName;
	saveButton.enabled = !folderName.vna_isBlank;
}

-(void)prepareTemplates {

    NSMutableArray<NSPredicateEditorRowTemplate *> *rowTemplates = [NSMutableArray array];

    NSArray *compoundTypes = @[
        @(NSAndPredicateType),
        @(NSOrPredicateType),
        @(NSNotPredicateType)
    ];
    NSPredicateEditorRowTemplate *compoundTemplate = [[NSPredicateEditorRowTemplate alloc] initWithCompoundTypes:compoundTypes];
    [rowTemplates addObject:compoundTemplate];

    //not contains
    NSArray *doesNotContainLeftExpressions = @[
        [NSExpression expressionForConstantValue: MA_Field_Text],
        [NSExpression expressionForConstantValue: MA_Field_Subject],
        [NSExpression expressionForConstantValue: MA_Field_Author]];
    [rowTemplates addObject:[[VNANotContainsPredicateEditorRowTemplate alloc] initWithLeftExpressions:doesNotContainLeftExpressions]];

    //folder is / is not
    NSArray<NSExpression *> *folders = [self fillFolderValueField:VNAFolderTypeRoot atIndent:0];

    NSPredicateEditorRowTemplate *folderTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForConstantValue:@"Folder"]] rightExpressions:folders modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType)] options:0];

    [rowTemplates addObject:folderTemplate];

    //read / flagged / deleted = YES / NO
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
    NSPredicateEditorRowTemplate *booleanTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:booleanLeftExpressions rightExpressions:booleanRightExpressions modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];

    [rowTemplates addObject:booleanTemplate];

    //date = / > / >= / < / <= today / yesterday / last week
    NSArray<NSExpression *> *dateRightExpressions = @[
        [NSExpression expressionForConstantValue:@"today"],
        [NSExpression expressionForConstantValue:@"yesterday"],
        [NSExpression expressionForConstantValue:@"last week"]
    ];
    NSPredicateEditorRowTemplate *dateTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForConstantValue:@"Date"]] rightExpressions:dateRightExpressions modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSLessThanPredicateOperatorType), @(NSLessThanOrEqualToPredicateOperatorType), @(NSGreaterThanPredicateOperatorType), @(NSGreaterThanOrEqualToPredicateOperatorType)] options:0];

    [rowTemplates addObject:dateTemplate];

    //subject / author / text contains / = / != <text>
    NSArray<NSExpression *> *textLeftExpressions = @[
        [NSExpression expressionForConstantValue:@"Subject"],
        [NSExpression expressionForConstantValue:@"Author"],
        [NSExpression expressionForConstantValue:@"Text"]
    ];
    NSPredicateEditorRowTemplate *textTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:textLeftExpressions rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType),  @(NSContainsPredicateOperatorType)] options:0];

    [rowTemplates addObject:textTemplate];

    self.predicateEditor.rowTemplates = rowTemplates;
}

/* fillFolderValueField
 * Fill the folder value field popup menu with a list of all RSS and group
 * folders in the database under the specified folder ID. The indentation value
 * is used to indent the items in the menu when they are part of a group. I've used
 * an increment of 2 which looks clearer than 1 in the UI.
 */
-(NSArray<NSExpression *> *)fillFolderValueField:(NSInteger)fromId atIndent:(NSInteger)indentation
{
    NSMutableArray<NSExpression *> *folderExpressions = [NSMutableArray array];
	for (Folder * folder in [[db arrayOfFolders:fromId] sortedArrayUsingSelector:@selector(folderNameCompare:)])
	{
		if (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader || folder.type == VNAFolderTypeGroup)
        {
            NSString *indentSpaces = [@"" stringByPaddingToLength:indentation * 2 withString:@" " startingAtIndex:0];
            [folderExpressions addObject:[NSExpression expressionForConstantValue:[indentSpaces stringByAppendingString:folder.name]]];
            if (folder.type == VNAFolderTypeGroup) {
                [folderExpressions addObjectsFromArray:[self fillFolderValueField:folder.itemId atIndent:indentation + 1]];
            }
		}
	}
    return folderExpressions;
}

/* displaySearchSheet
 * Display the search sheet.
 */
-(void)displaySearchSheet:(NSWindow *)window
{
	// Begin the sheet
	onScreen = YES;
	[window beginSheet:searchWindow completionHandler:nil];
	// Remember the initial size of the dialog sheet
	// before addition of any criteria that would
	// cause it to be resized. We need to know this
	// to shrink it back to its default size.
	searchWindowFrame = [NSWindow contentRectForFrameRect:searchWindow.frame styleMask:searchWindow.styleMask];
}

/* addDefaultCriteria
 * Add a new default criteria row. For this we use the static defaultField declared at
 * the start of this source and the default operator for that field, and an empty value.
 */
-(void)addDefaultCriteria
{
    NSPredicate *defaultPredicate = [NSPredicate predicateWithFormat:@"'Subject' CONTAINS %@", @""];
    NSPredicate *compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[defaultPredicate]];

    [[self predicateEditor] setObjectValue:compoundPredicate];
}

/* doSave
 * Create a CriteriaTree from the criteria rows and save this to the
 * database.
 */
-(IBAction)doSave:(id)sender
{
    NSString *folderName = smartFolderName.stringValue;
    CriteriaTree *criteriaTree = [[CriteriaTree alloc] initWithPredicate:[self.predicateEditor objectValue]];

    if (smartFolderId == -1) {
        AppController * controller = APPCONTROLLER;
        smartFolderId = [[Database sharedManager] addSmartFolder:folderName underParent:parentId withQuery:criteriaTree];
        [controller selectFolder:smartFolderId];
    } else {
        [[Database sharedManager] updateSearchFolder:smartFolderId withFolder:folderName withQuery:criteriaTree];
    }

    [searchWindow.sheetParent endSheet:searchWindow];
	[searchWindow orderOut:self];
	onScreen = NO;
}

/* doCancel
 */
-(IBAction)doCancel:(id)sender
{
	[searchWindow.sheetParent endSheet:searchWindow];
	[searchWindow orderOut:self];
	onScreen = NO;
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Save button if the input field is empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
	NSString * folderName = smartFolderName.stringValue;
	saveButton.enabled = !folderName.vna_isBlank;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
