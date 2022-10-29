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

-(void)fillFolderValueField;
-(void)initSearchSheet:(NSString *)folderName;
-(void)displaySearchSheet:(NSWindow *)window;
-(void)setOperatorsPopup:(NSPopUpButton *)popUpButton operators:(NSArray *)operators;
-(void)addCriteria:(NSUInteger)index;
-(void)addDefaultCriteria;
-(void)removeCriteria:(NSInteger)index;
-(void)removeAllCriteria;
-(void)resizeSearchWindow;

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
		NSInteger index = 0;

		[self initSearchSheet:folder.name];
		smartFolderId = folderId;
		[smartFolderName setEnabled:YES];

		// Load the criteria into the fields.
		CriteriaTree * criteriaTree = [db searchStringForSmartFolder:folderId];

		// Set the criteria condition
		[criteriaConditionPopup selectItemWithTag:criteriaTree.condition];

		for (Criteria * criteria in criteriaTree.criteriaEnumerator)
		{
			//TODO [self initForField:criteria.field inRow:searchCriteriaView];

            [operatorPopup selectItemWithTitle:[Criteria localizedStringFromOperator:criteria.operator]];

			Field * field = [nameToFieldMap valueForKey:criteria.field];
			[fieldNamePopup selectItemWithTitle:field.displayName];
			switch (field.type)
			{
				case VNAFieldTypeFlag: {
					NSInteger tag;
					if([criteria.value isEqualToString:@"Yes"]) {
						tag=1;
					} else {
						tag=2;
					}
					BOOL found = [flagValueField selectItemWithTag:tag];
					NSAssert (found, @"No menu item selected");
					break;
				}

				case VNAFieldTypeFolder: {
					Folder * folder = [db folderFromName:criteria.value];
					if (folder != nil)
						[folderValueField selectItemWithTitle:folder.name];
					break;
				}

				case VNAFieldTypeString: {
					valueField.stringValue = criteria.value;
					break;
				}

				case VNAFieldTypeInteger: {
					numberValueField.stringValue = criteria.value;
					break;
				}

				case VNAFieldTypeDate: {
					[dateValueField selectItemAtIndex:[dateValueField indexOfItemWithRepresentedObject:criteria.value]];
					break;
				}
			}

			[self addCriteria:index++];
		}

		// We defer sizing the window until all the criteria are
		// added and displayed, otherwise it looks crap.
		[self displaySearchSheet:window];
		[self resizeSearchWindow];
	}
}

/* initSearchSheet
 */
-(void)initSearchSheet:(NSString *)folderName
{
	// Clean up from any last run.
	if (totalCriteria > 0)
		[self removeAllCriteria];

	// Initialize UI
	if (!searchWindow)
	{
		NSArray * objects;
		[[NSBundle bundleForClass:[self class]] loadNibNamed:@"SearchFolder" owner:self topLevelObjects:&objects];
		self.topObjects = objects;

		// Register our notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:smartFolderName];
	}

	// Initialise the folder control with a list of all folders
	// in the database.
    [self fillFolderValueField];
	
	// Init the folder name field and disable the Save button if it is blank
	smartFolderName.stringValue = folderName;
	saveButton.enabled = !folderName.vna_isBlank;
}

-(void)fillFolderValueField {
    NSArray<NSExpression *> *folders = [self fillFolderValueField:VNAFolderTypeRoot atIndent:0];

    NSPredicateEditorRowTemplate *folderTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForConstantValue:@"folder"]] rightExpressions:folders modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType)] options:0];

    _predicateEditor.rowTemplates = [_predicateEditor.rowTemplates arrayByAddingObject:folderTemplate];
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
    NSPredicate *defaultPredicate = [NSPredicate predicateWithFormat:@"'subject' CONTAINS %@", @""];
    NSPredicate *compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[defaultPredicate]];
    [[self predicateEditor] setObjectValue:compoundPredicate];
}

/* setOperatorsPopup
 * Fills the specified pop up button field with a list of valid operators.
 */
-(void)setOperatorsPopup:(NSPopUpButton *)popUpButton operators:(NSArray *)operators
{
	for ( NSNumber * number in operators )
	{
        CriteriaOperator operator = number.integerValue;
		NSString * operatorString = [Criteria localizedStringFromOperator:operator];
        [popUpButton addItemWithTitle:operatorString tag:operator];
	}
}

/* doSave
 * Create a CriteriaTree from the criteria rows and save this to the
 * database.
 */
-(IBAction)doSave:(id)sender
{
    if (smartFolderId == -1)
    {
        AppController * controller = APPCONTROLLER;
        //smartFolderId = [[Database sharedManager] addSmartFolder:folderName underParent:parentId withQuery:criteriaTree];
        //[controller selectFolder:smartFolderId];
    }
    else
    {
        //[[Database sharedManager] updateSearchFolder:smartFolderId withFolder:folderName withQuery:criteriaTree];
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

/* removeAllCriteria
 * Remove all existing criteria (i.e. reset the views back to defaults).
 */
-(void)removeAllCriteria
{
	NSInteger c;

	NSArray * subviews = searchCriteriaSuperview.subviews;
	for (c = subviews.count - 1; c >= 0; --c)
	{
		NSView * row = subviews[c];
		[row removeFromSuperview];
	}
	[arrayOfViews removeAllObjects];
	totalCriteria = 0;
	// reset the dialog sheet size
	[searchWindow setFrame:searchWindowFrame display:NO];
}

/* removeCriteria
 * Remove the criteria at the specified index.
 */
-(void)removeCriteria:(NSInteger)index
{
	NSInteger rowHeight = searchCriteriaView.frame.size.height;
	NSInteger c;

	// Do nothing if there's just one criteria
	if (totalCriteria <= 1)
		return;
	
	// Remove the view from the parent view
	NSView * row = arrayOfViews[index];
	[row removeFromSuperview];
	[arrayOfViews removeObject:row];
	--totalCriteria;
	
	// Shift up the remaining subviews
	for (c = index ; c < arrayOfViews.count; ++c) {
		NSView * row = arrayOfViews[c];
		NSPoint origin = row.frame.origin;
		[row setFrameOrigin:NSMakePoint(origin.x, origin.y + rowHeight)];
	}
}

/* addCriteria
 * Add a new criteria clause. Before calling this function, initialise the
 * searchView with the settings to be added.
 */
-(void)addCriteria:(NSUInteger)index
{
	NSData * archRow;
	NSInteger rowHeight = searchCriteriaView.frame.size.height;
	NSUInteger  c;

	if (index > arrayOfViews.count)
		index = arrayOfViews.count;

	// Now add the new subview
    //
    // FIXME: NSArchiver and NSUnarchiver are deprecated since macOS 10.13
    //
    // NSArchiver and NSUnarchiver are used here to copy searchCriteriaView.
    // NSKeyedArchiver is not a replacement for this.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	archRow = [NSArchiver archivedDataWithRootObject:searchCriteriaView];
	NSRect bounds = searchCriteriaSuperview.bounds;
	NSView * row = (NSView *)[NSUnarchiver unarchiveObjectWithData:archRow];
#pragma clang diagnostic pop
	if (onScreen) {
		[row setFrameOrigin:NSMakePoint(bounds.origin.x, bounds.origin.y + (NSInteger)(totalCriteria - 1 - index) * rowHeight)];
	} else {  // computation is affected by resizeSearchWindow being called only once, after the search panel is displayed
		[row setFrameOrigin:NSMakePoint(bounds.origin.x, bounds.origin.y  - index * rowHeight)];
	}
	[searchCriteriaSuperview addSubview:row];
	[arrayOfViews insertObject:row atIndex:index];

	// Shift down the existing subviews by rowHeight
	for (c = index + 1; c < arrayOfViews.count; ++c) {
		NSView * row = arrayOfViews[c];
		NSPoint origin = row.frame.origin;
		[row setFrameOrigin:NSMakePoint(origin.x, origin.y - rowHeight)];
	}
	// Bump up the criteria count
	++totalCriteria;
}

/* resizeSearchWindow
 * Resize the search window for the number of criteria 
 */
-(void)resizeSearchWindow
{
	NSRect newFrame;

	newFrame = searchWindowFrame;
	if (totalCriteria > 0)
	{
		NSInteger rowHeight = searchCriteriaView.frame.size.height;
		NSInteger additionalHeight = rowHeight * (totalCriteria - 1);
		newFrame.origin.y -= additionalHeight;
		newFrame.size.height += additionalHeight;
		newFrame = [NSWindow frameRectForContentRect:newFrame styleMask:searchWindow.styleMask];
	}
	[searchWindow setFrame:newFrame display:YES animate:YES];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
