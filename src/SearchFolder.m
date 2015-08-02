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
#import "PopUpButtonExtensions.h"

// Tags for the three fields that define a criteria. We set these here
// rather than in IB to be consistent.
#define MA_SFEdit_FieldTag			1000
#define MA_SFEdit_OperatorTag		1001
#define MA_SFEdit_ValueTag			1002
#define MA_SFEdit_FlagValueTag		1003
#define MA_SFEdit_DateValueTag		1004
#define MA_SFEdit_NumberValueTag	1005
#define MA_SFEdit_AddTag			1006
#define MA_SFEdit_RemoveTag			1007
#define MA_SFEdit_FolderValueTag	1008

@interface SmartFolder (Private)
	-(void)initFolderValueField:(int)parentId atIndent:(int)indentation;
	-(void)initSearchSheet:(NSString *)folderName;
	-(void)displaySearchSheet:(NSWindow *)window;
	-(void)initForField:(NSString *)fieldName inRow:(NSView *)row;
	-(void)setOperatorsPopup:(NSPopUpButton *)popUpButton, ...;
	-(void)addCriteria:(NSUInteger )index;
	-(void)addDefaultCriteria:(int)index;
	-(void)removeCriteria:(int)index;
	-(void)removeAllCriteria;
	-(void)resizeSearchWindow;
@end

@implementation SmartFolder

/* initWithDatabase
 * Just init the search criteria class.
 */
-(id)initWithDatabase:(Database *)newDb
{
	if ((self = [super init]) != nil)
	{
		totalCriteria = 0;
		smartFolderId = -1;
		db = newDb;
		firstRun = YES;
		parentId = MA_Root_Folder;
		arrayOfViews = [[NSMutableArray alloc] init];
	}
	return self;
}

/* newCriteria
 * Initialises the smart folder panel with a single empty criteria to get
 * started.
 */
-(void)newCriteria:(NSWindow *)window underParent:(int)itemId
{
	[self initSearchSheet:@""];
	smartFolderId = -1;
	parentId = itemId;
	[smartFolderName setEnabled:YES];

	// Add a default criteria.
	[self addDefaultCriteria:0];
	[self displaySearchSheet:window];
}

/* loadCriteria
 * Loads the criteria for the specified folder.
 */
-(void)loadCriteria:(NSWindow *)window folderId:(int)folderId
{
	Folder * folder = [db folderFromID:folderId];
	if (folder != nil)
	{
		int index = 0;

		[self initSearchSheet:[folder name]];
		smartFolderId = folderId;
		[smartFolderName setEnabled:YES];

		// Load the criteria into the fields.
		CriteriaTree * criteriaTree = [db searchStringForSmartFolder:folderId];

		// Set the criteria condition
		[criteriaConditionPopup selectItemWithTag:[criteriaTree condition]];

		for (Criteria * criteria in [criteriaTree criteriaEnumerator])
		{
			[self initForField:[criteria field] inRow:searchCriteriaView];

			[fieldNamePopup selectItemWithTitle:NSLocalizedString([criteria field], nil)];
			[operatorPopup selectItemWithTitle:NSLocalizedString([Criteria stringFromOperator:[criteria operator]], nil)];

			Field * field = [nameToFieldMap valueForKey:[criteria field]];
			switch ([field type])
			{
				case MA_FieldType_Flag: {
					[flagValueField selectItemWithTitle:NSLocalizedString([criteria value], nil)];
					break;
				}

				case MA_FieldType_Folder: {
					Folder * folder = [db folderFromName:[criteria value]];
					if (folder != nil)
						[folderValueField selectItemWithTitle:[folder name]];
					break;
				}

				case MA_FieldType_String: {
					[valueField setStringValue:[criteria value]];
					break;
				}

				case MA_FieldType_Integer: {
					[numberValueField setStringValue:[criteria value]];
					break;
				}

				case MA_FieldType_Date: {
					[dateValueField selectItemAtIndex:[dateValueField indexOfItemWithRepresentedObject:[criteria value]]];
					break;
				}
			}

			[self addCriteria:index++];
		}

		// We defer sizing the window until all the criteria are
		// added otherwise it looks crap.
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
		[self setTopObjects:objects];

		// Register our notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:smartFolderName];

		// Create a mapping for field to column names
		nameToFieldMap = [[NSMutableDictionary alloc] init];

		// Initialize the search criteria view popups with all the
		// fields in the database.

		[fieldNamePopup removeAllItems];
		for (Field * field in [db arrayOfFields])
		{
			if ([field tag] != MA_FieldID_Headlines &&
				[field tag] != MA_FieldID_GUID &&
				[field tag] != MA_FieldID_Link &&
				[field tag] != MA_FieldID_Comments &&
				[field tag] != MA_FieldID_Summary &&
				[field tag] != MA_FieldID_Parent &&
				[field tag] != MA_FieldID_Enclosure &&
				[field tag] != MA_FieldID_EnclosureDownloaded)
			{
				[fieldNamePopup addItemWithRepresentedObject:[field displayName] object:field];
				[nameToFieldMap setValue:field forKey:[field name]];
			}
		}
		
		// Set Yes/No values on flag fields
		[flagValueField removeAllItems];
		[flagValueField addItemWithRepresentedObject:NSLocalizedString(@"Yes", nil) object:@"Yes"];
		[flagValueField addItemWithRepresentedObject:NSLocalizedString(@"No", nil) object:@"No"];

		// Set date popup values
		[dateValueField removeAllItems];
		[dateValueField addItemWithRepresentedObject:NSLocalizedString(@"Today", nil) object:@"today"];
		[dateValueField addItemWithRepresentedObject:NSLocalizedString(@"Yesterday", nil) object:@"yesterday"];
		[dateValueField addItemWithRepresentedObject:NSLocalizedString(@"Last Week", nil) object:@"last week"];

		// Initialise the condition popup
		NSString * anyString = NSLocalizedString([CriteriaTree conditionToString:MA_CritCondition_Any], nil);
		NSString * allString = NSLocalizedString([CriteriaTree conditionToString:MA_CritCondition_All], nil);

		[criteriaConditionPopup removeAllItems];
		[criteriaConditionPopup addItemWithTag:anyString tag:MA_CritCondition_Any];
		[criteriaConditionPopup addItemWithTag:allString tag:MA_CritCondition_All];

		// Set the tags on the controls
		[fieldNamePopup setTag:MA_SFEdit_FieldTag];
		[operatorPopup setTag:MA_SFEdit_OperatorTag];
		[valueField setTag:MA_SFEdit_ValueTag];
		[flagValueField setTag:MA_SFEdit_FlagValueTag];
		[dateValueField setTag:MA_SFEdit_DateValueTag];
		[folderValueField setTag:MA_SFEdit_FolderValueTag];
		[numberValueField setTag:MA_SFEdit_NumberValueTag];
		[removeCriteriaButton setTag:MA_SFEdit_RemoveTag];
		[addCriteriaButton setTag:MA_SFEdit_AddTag];
	}

	// Initialise the folder control with a list of all folders
	// in the database.
	[folderValueField removeAllItems];
	[self initFolderValueField:MA_Root_Folder atIndent:0];
	
	// Init the folder name field and disable the Save button if it is blank
	[smartFolderName setStringValue:folderName];
	[saveButton setEnabled:![folderName isBlank]];
}

/* initFolderValueField
 * Fill the folder value field popup menu with a list of all RSS and group
 * folders in the database under the specified folder ID. The indentation value
 * is used to indent the items in the menu when they are part of a group. I've used
 * an increment of 2 which looks clearer than 1 in the UI.
 */
-(void)initFolderValueField:(int)fromId atIndent:(int)indentation
{
	for (Folder * folder in [db arrayOfFolders:fromId])
	{
		if (IsRSSFolder(folder)||IsGoogleReaderFolder(folder)||IsGroupFolder(folder))
		{
			[folderValueField addItemWithTitle:[folder name]];
			NSMenuItem * menuItem = [folderValueField itemWithTitle:[folder name]];
			[menuItem setImage:[folder image]];
			[menuItem setIndentationLevel:indentation];
			if (IsGroupFolder(folder))
				[self initFolderValueField:[folder itemId] atIndent:indentation + 2];
		}
	}
}

/* displaySearchSheet
 * Display the search sheet.
 */
-(void)displaySearchSheet:(NSWindow *)window
{
	// Begin the sheet
	[NSApp beginSheet:searchWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];

	// Remember the intial window size after it is first
	// loaded and before any criteria are added that will
	// cause it to be resized. We need to know this to shrink
	// it back to it's default size.
	if (firstRun)
	{
		searchWindowFrame = [NSWindow contentRectForFrameRect:[searchWindow frame] styleMask:[searchWindow styleMask]]; 
		firstRun = NO;
	}
}

/* removeCurrentCriteria
 * Remove the current criteria row
 */
-(IBAction)removeCurrentCriteria:(id)sender
{
	int index = [arrayOfViews indexOfObject:[sender superview]];
	NSAssert(index >= 0 && index < totalCriteria, @"Got an out of bounds index of view in superview");
	[self removeCriteria:index];
	[self resizeSearchWindow];
}

/* addNewCriteria
 * Add another criteria row.
 */
-(IBAction)addNewCriteria:(id)sender
{
	int index = [arrayOfViews indexOfObject:[sender superview]];
	NSAssert(index >= 0 && index < totalCriteria, @"Got an out of bounds index of view in superview");
	[self addDefaultCriteria:index + 1];
	[self resizeSearchWindow];
}

/* addDefaultCriteria
 * Add a new default criteria row. For this we use the static defaultField declared at
 * the start of this source and the default operator for that field, and an empty value.
 */
-(void)addDefaultCriteria:(int)index
{
	Field * defaultField = [db fieldByName:MA_Field_Read];

	[self initForField:[defaultField name] inRow:searchCriteriaView];
	[fieldNamePopup selectItemWithTitle:[defaultField displayName]];
	[valueField setStringValue:@""];
	[self addCriteria:index];
}

/* fieldChanged
 * Handle the case where the field has changed. Update the valid list of
 * operators for the selected field.
 */
-(IBAction)fieldChanged:(id)sender
{
	Field * field = [sender representedObjectForSelection];
	[self initForField:[field name] inRow:[sender superview]];
}

/* initForField
 * Initialise the operator and value fields for the specified field.
 */
-(void)initForField:(NSString *)fieldName inRow:(NSView *)row
{
	Field * field = [nameToFieldMap valueForKey:fieldName];
	NSAssert1(field != nil, @"Got nil field for field '%@'", fieldName);

	// Need to flip on the operator popup for the field that changed
	NSPopUpButton * theOperatorPopup = [row viewWithTag:MA_SFEdit_OperatorTag];
	[theOperatorPopup removeAllItems];	
	switch ([field type])
	{
		case MA_FieldType_Flag:
			[self setOperatorsPopup:theOperatorPopup,
									MA_CritOper_Is,
									0];
			break;

		case MA_FieldType_Folder:
			[self setOperatorsPopup:theOperatorPopup,
									MA_CritOper_Is,
									MA_CritOper_IsNot,
									0];
			break;

		case MA_FieldType_String:
			[self setOperatorsPopup:theOperatorPopup,
									MA_CritOper_Is,
									MA_CritOper_IsNot,
									MA_CritOper_Contains,
									MA_CritOper_NotContains,
									0];
			break;

		case MA_FieldType_Integer:
			[self setOperatorsPopup:theOperatorPopup,
									MA_CritOper_Is,
									MA_CritOper_IsNot,
									MA_CritOper_IsGreaterThan,
									MA_CritOper_IsGreaterThanOrEqual,
									MA_CritOper_IsLessThan,
									MA_CritOper_IsLessThanOrEqual,
									0];
			break;

		case MA_FieldType_Date:
			[self setOperatorsPopup:theOperatorPopup,
									MA_CritOper_Is,
									MA_CritOper_IsAfter,
									MA_CritOper_IsBefore,
									MA_CritOper_IsOnOrAfter,
									MA_CritOper_IsOnOrBefore,
									0];
			break;
	}

	// Show and hide the value fields depending on the type
	NSView * theValueField = [row viewWithTag:MA_SFEdit_ValueTag];
	NSView * theFlagValueField = [row viewWithTag:MA_SFEdit_FlagValueTag];
	NSView * theNumberValueField = [row viewWithTag:MA_SFEdit_NumberValueTag];
	NSView * theDateValueField = [row viewWithTag:MA_SFEdit_DateValueTag];
	NSView * theFolderValueField = [row viewWithTag:MA_SFEdit_FolderValueTag];

	[theFlagValueField setHidden:[field type] != MA_FieldType_Flag];
	[theValueField setHidden:[field type] != MA_FieldType_String];
	[theDateValueField setHidden:[field type] != MA_FieldType_Date];
	[theNumberValueField setHidden:[field type] != MA_FieldType_Integer];
	[theFolderValueField setHidden:[field type] != MA_FieldType_Folder];
}

/* setOperatorsPopup
 * Fills the specified pop up button field with a list of valid operators.
 */
-(void)setOperatorsPopup:(NSPopUpButton *)popUpButton, ...
{
	va_list arguments;
	va_start(arguments, popUpButton);
	CriteriaOperator operator;

	while ((operator = va_arg(arguments, int)) != 0)
	{
		NSString * operatorString = NSLocalizedString([Criteria stringFromOperator:operator], nil);
		[popUpButton addItemWithTag:operatorString tag:operator];
	}
}

/* doSave
 * Create a CriteriaTree from the criteria rows and save this to the
 * database.
 */
-(IBAction)doSave:(id)sender
{
	NSString * folderName = [[smartFolderName stringValue] trim];
	NSAssert(![folderName isBlank], @"doSave called with empty folder name");
	NSUInteger  c;

	// Check whether there is another folder with the same name.
	Folder * folder = [db folderFromName:folderName];
	if (folder != nil && [folder itemId] != smartFolderId)
	{
		runOKAlertPanel(NSLocalizedString(@"Cannot rename folder", nil), NSLocalizedString(@"A folder with that name already exists", nil));
		return;
	}

	// Build the criteria string
	CriteriaTree * criteriaTree = [[CriteriaTree alloc] init];
	for (c = 0; c < [arrayOfViews count]; ++c)
	{
		NSView * row = [arrayOfViews objectAtIndex:c];
		NSPopUpButton * theField = [row viewWithTag:MA_SFEdit_FieldTag];
		NSPopUpButton * theOperator = [row viewWithTag:MA_SFEdit_OperatorTag];

		Field * field = [theField representedObjectForSelection];
		CriteriaOperator operator = [theOperator tagForSelection];
		NSString * valueString;

		if ([field type] == MA_FieldType_Flag)
		{
			NSPopUpButton * theValue = [row viewWithTag:MA_SFEdit_FlagValueTag];
			valueString = [theValue representedObjectForSelection];
		}
		else if ([field type] == MA_FieldType_Date)
		{
			NSPopUpButton * theValue = [row viewWithTag:MA_SFEdit_DateValueTag];
			valueString = [theValue representedObjectForSelection];
		}
		else if ([field type] == MA_FieldType_Folder)
		{
			NSPopUpButton * theValue = [row viewWithTag:MA_SFEdit_FolderValueTag];
			valueString = [theValue titleOfSelectedItem];
		}
		else if ([field type] == MA_FieldType_Integer)
		{
			NSTextField * theValue = [row viewWithTag:MA_SFEdit_NumberValueTag];
			valueString = [theValue stringValue];
		}
		else
		{
			NSTextField * theValue = [row viewWithTag:MA_SFEdit_ValueTag];
			valueString = [theValue stringValue];
		}

		Criteria * newCriteria = [[Criteria alloc] initWithField:[field name] withOperator:operator withValue:valueString];
		[criteriaTree addCriteria:newCriteria];
		[newCriteria release];
	}

	// Set the criteria condition
	[criteriaTree setCondition:[criteriaConditionPopup selectedTag]];
	
	if (smartFolderId == -1)
	{
		AppController * controller = APPCONTROLLER;
		smartFolderId = [[Database sharedManager] addSmartFolder:folderName underParent:parentId withQuery:criteriaTree];
		[controller selectFolder:smartFolderId];
	}
	else
    {
		[[Database sharedManager] updateSearchFolder:smartFolderId withFolder:folderName withQuery:criteriaTree];
    }

	[criteriaTree release];
	
	[NSApp endSheet:searchWindow];
	[searchWindow orderOut:self];
}

/* doCancel
 */
-(IBAction)doCancel:(id)sender
{
	[NSApp endSheet:searchWindow];
	[searchWindow orderOut:self];
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Save button if the input field is empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
	NSString * folderName = [smartFolderName stringValue];
	[saveButton setEnabled:![folderName isBlank]];
}

/* removeAllCriteria
 * Remove all existing criteria (i.e. reset the views back to defaults).
 */
-(void)removeAllCriteria
{
	int c;

	NSArray * subviews = [searchCriteriaSuperview subviews];
	for (c = [subviews count] - 1; c >= 0; --c)
	{
		NSView * row = [subviews objectAtIndex:c];
		[row removeFromSuperview];
	}
	[arrayOfViews removeAllObjects];
	totalCriteria = 0;
}

/* removeCriteria
 * Remove the criteria at the specified index.
 */
-(void)removeCriteria:(int)index
{
	int rowHeight = [searchCriteriaView frame].size.height;
	int c;

	// Do nothing if there's just one criteria
	if (totalCriteria <= 1)
		return;
	
	// Remove the view from the parent view
	NSView * row = [arrayOfViews objectAtIndex:index];
	[row removeFromSuperview];
	[arrayOfViews removeObject:row];
	--totalCriteria;
	
	// Shift the subviews
	for (c = 0; c < index; ++c)
	{
		NSView * row = [arrayOfViews objectAtIndex:c];
		NSPoint origin = [row frame].origin;
		[row setFrameOrigin:NSMakePoint(origin.x, origin.y - rowHeight)];
	}
}

/* addCriteria
 * Add a new criteria clause. Before calling this function, initialise the
 * searchView with the settings to be added.
 */
-(void)addCriteria:(NSUInteger )index
{
	NSData * archRow;
	NSView * previousRow = nil;
	int rowHeight = [searchCriteriaView frame].size.height;
	NSUInteger  c;

	// Bump up the criteria count
	++totalCriteria;
	if (!firstRun)
		[self resizeSearchWindow];

	// Shift the existing subviews up by rowHeight
	if (index > [arrayOfViews count])
		index = [arrayOfViews count];
	for (c = 0; c < index; ++c)
	{
		NSView * row = [arrayOfViews objectAtIndex:c];
		NSPoint origin = [row frame].origin;
		[row setFrameOrigin:NSMakePoint(origin.x, origin.y + rowHeight)];
		previousRow = row;
	}

	// Now add the new subview
	archRow = [NSArchiver archivedDataWithRootObject:searchCriteriaView];
	NSRect bounds = [searchCriteriaSuperview bounds];
	NSView * row = (NSView *)[NSUnarchiver unarchiveObjectWithData:archRow];
	[row setFrameOrigin:NSMakePoint(bounds.origin.x, bounds.origin.y + (((totalCriteria - 1) - index) * rowHeight))];
	[searchCriteriaSuperview addSubview:[row retain]];
	[arrayOfViews insertObject:row atIndex:index];

	// Link the previous row to the next one so that the Tab key behaves
	// properly through the entire sheet.
	// BUGBUG: This doesn't work and I can't figure out why not yet. This needs to be fixed.
	if (previousRow)
	{
		NSView * lastKeyView = [previousRow nextKeyView];
		[previousRow setNextKeyView:row];
		[row setNextKeyView:lastKeyView];
	}
	[searchCriteriaSuperview display];
	[row release];
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
		int rowHeight = [searchCriteriaView frame].size.height;
		int newHeight = newFrame.size.height + rowHeight * (totalCriteria - 1);
		newFrame.origin.y += newFrame.size.height;
		newFrame.origin.y -= newHeight;
		newFrame.size.height = newHeight;
		newFrame = [NSWindow frameRectForContentRect:newFrame styleMask:[searchWindow styleMask]];
	}
	[searchWindow setFrame:newFrame display:YES animate:YES];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[arrayOfViews release];
	arrayOfViews=nil;
	[nameToFieldMap release];
	nameToFieldMap=nil;
	[db release];
	db=nil;
	[_topObjects release];
	_topObjects=nil;
	[super dealloc];
}
@end
