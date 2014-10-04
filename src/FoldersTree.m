//
//  FoldersTree.m
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
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

#import "FoldersTree.h"
#import "ImageAndTextCell.h"
#import "AppController.h"
#import "Constants.h"
#import "Preferences.h"
#import "HelperFunctions.h"
#import "StringExtensions.h"
#import "FolderView.h"
#import "PopupButton.h"
#import "ViennaApp.h"
#import "BrowserView.h"
#import "GoogleReader.h"

// Private functions
@interface FoldersTree (Private)
	-(void)setFolderListFont;
	-(NSArray *)archiveState;
	-(void)unarchiveState:(NSArray *)stateArray;
	-(void)reloadDatabase:(NSArray *)stateArray;
	-(BOOL)loadTree:(NSArray *)listOfFolders rootNode:(TreeNode *)node;
	-(void)setManualSortOrderForNode:(TreeNode *)node;
	-(void)handleDoubleClick:(id)sender;
	-(void)handleAutoSortFoldersTreeChange:(NSNotification *)nc;
	-(void)handleFolderAdded:(NSNotification *)nc;
	-(void)handleFolderNameChange:(NSNotification *)nc;
	-(void)handleFolderUpdate:(NSNotification *)nc;
	-(void)handleFolderDeleted:(NSNotification *)nc;
	-(void)handleShowFolderImagesChange:(NSNotification *)nc;
	-(void)handleFolderFontChange:(NSNotification *)nc;
	-(void)reloadFolderItem:(id)node reloadChildren:(BOOL)flag;
	-(void)expandToParent:(TreeNode *)node;
	-(BOOL)copyTableSelection:(NSArray *)items toPasteboard:(NSPasteboard *)pboard;
    -(BOOL)moveFolders:(NSArray *)array withGoogleSync:(BOOL)sync;
	-(void)enableFoldersRenaming:(id)sender;
	-(void)enableFoldersRenamingAfterDelay;
@end

@implementation FoldersTree

/* initWithFrame
 * Initialise ourself.
 */
-(id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		// Root node is never displayed since we always display from
		// the second level down. It simply provides a convenient way
		// of containing the other nodes.
		rootNode = [[TreeNode alloc] init:nil atIndex:0 folder:nil canHaveChildren:YES];
		blockSelectionHandler = NO;
		canRenameFolders = NO;
		folderErrorImage = nil;
		refreshProgressImage = nil;
	}
	return self;
}

/* awakeFromNib
 * Do things that only make sense once the NIB is loaded.
 */
-(void)awakeFromNib
{
	NSTableColumn * tableColumn;
	ImageAndTextCell * imageAndTextCell;

	// Our folders have images next to them.
	tableColumn = [outlineView tableColumnWithIdentifier:@"folderColumns"];
	imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	[imageAndTextCell setEditable:YES];
	[tableColumn setDataCell:imageAndTextCell];

	// Folder image
	folderErrorImage = [NSImage imageNamed:@"folderError.tiff"];
    folderErrorImage.accessibilityDescription = NSLocalizedString(@"Error", nil);
	refreshProgressImage = [NSImage imageNamed:@"refreshProgress.tiff"];
	
	// Create and set whatever font we're using for the folders
	[self setFolderListFont];

	// Set background colour
	[outlineView setBackgroundColor:[NSColor colorWithCalibratedRed:0.84 green:0.87 blue:0.90 alpha:1.00]];
		
	// Allow a second click in a node to edit the node
	[outlineView setAction:@selector(handleSingleClick:)];
	[outlineView setDoubleAction:@selector(handleDoubleClick:)];
	[outlineView setTarget:self];

	// Initially size the outline view column to be the correct width
	[outlineView sizeLastColumnToFit];

	// Don't resize the column when items are expanded as this messes up
	// the placement of the unread count button.
	[outlineView setAutoresizesOutlineColumn:NO];

	// Register for dragging
	[outlineView registerForDraggedTypes:[NSArray arrayWithObjects:MA_PBoardType_FolderList, MA_PBoardType_RSSSource, @"WebURLsWithTitlesPboardType", NSStringPboardType, nil]]; 
	[outlineView setVerticalMotionCanBeginDrag:YES];
	
	// Make sure selected row is visible
	[outlineView scrollRowToVisible:[outlineView selectedRow]];

    [outlineView accessibilitySetOverrideValue:NSLocalizedString(@"Folders", nil) forAttribute:NSAccessibilityDescriptionAttribute];
}

/* setOutlineViewBackgroundColor
 * Sets the color of the background view. 
 */

-(void)setOutlineViewBackgroundColor: (NSColor *)color;
{
	[outlineView setBackgroundColor: color];
}

/* initialiseFoldersTree
 * Do the things to initialize the folder tree from the database
 */
-(void)initialiseFoldersTree
{
	// Want tooltips
	[outlineView setEnableTooltips:YES];
	
	// Set the menu for the popup button
	[outlineView setMenu:[APPCONTROLLER folderMenu]];
	
	blockSelectionHandler = YES;
	[self reloadDatabase:[[Preferences standardPreferences] arrayForKey:MAPref_FolderStates]];
	blockSelectionHandler = NO;
	
	// Register for notifications
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleFolderUpdate:) name:@"MA_Notify_FoldersUpdated" object:nil];
	[nc addObserver:self selector:@selector(handleFolderNameChange:) name:@"MA_Notify_FolderNameChanged" object:nil];
	[nc addObserver:self selector:@selector(handleFolderAdded:) name:@"MA_Notify_FolderAdded" object:nil];
	[nc addObserver:self selector:@selector(handleFolderDeleted:) name:@"MA_Notify_FolderDeleted" object:nil];
	[nc addObserver:self selector:@selector(handleFolderFontChange:) name:@"MA_Notify_FolderFontChange" object:nil];
	[nc addObserver:self selector:@selector(handleShowFolderImagesChange:) name:@"MA_Notify_ShowFolderImages" object:nil];
	[nc addObserver:self selector:@selector(handleAutoSortFoldersTreeChange:) name:@"MA_Notify_AutoSortFoldersTreeChange" object:nil];
    [nc addObserver:self selector:@selector(handleGRSFolderChange:) name:@"MA_Notify_GRSFolderChange" object:nil];
}

-(void)handleGRSFolderChange:(NSNotification *)nc
{
    // No need to sync with Google because this is triggered when Open Reader
    // folder layout has changed. Making a sync call would be redundant.
    [self moveFolders:[nc object] withGoogleSync:NO];
}

/* handleFolderFontChange
 * Called when the user changes the folder font and/or size in the Preferences
 */
-(void)handleFolderFontChange:(NSNotification *)nc
{
	[self setFolderListFont];
	[outlineView reloadData];
}

/* setFolderListFont
 * Creates or updates the fonts used by the article list. The folder
 * list isn't automatically refreshed afterward - call reloadData for that.
 */
-(void)setFolderListFont
{
	int height;

	[cellFont release];
	[boldCellFont release];

	Preferences * prefs = [Preferences standardPreferences];
	cellFont = [[NSFont fontWithName:[prefs folderListFont] size:[prefs folderListFontSize]] retain];
	boldCellFont = [[[NSFontManager sharedFontManager] convertWeight:YES ofFont:cellFont] retain];

	height = [[APPCONTROLLER layoutManager] defaultLineHeightForFont:boldCellFont];
	[outlineView setRowHeight:height + 5];
	[outlineView setIntercellSpacing:NSMakeSize(10, 2)];
}

/* reloadDatabase
 * Refresh the folders tree and restore the specified archived state
 */
-(void)reloadDatabase:(NSArray *)stateArray
{
	[rootNode removeChildren];
	if (![self loadTree:[[Database sharedDatabase] arrayOfFolders:MA_Root_Folder] rootNode:rootNode])
	{
		[[Preferences standardPreferences] setFoldersTreeSortMethod:MA_FolderSort_ByName];
		[rootNode removeChildren];
		[self loadTree:[[Database sharedDatabase] arrayOfFolders:MA_Root_Folder] rootNode:rootNode];
	}
	[outlineView reloadData];
	[self unarchiveState:stateArray];
}

/* saveFolderSettings
 * Preserve the expanded/collapsed and selection state of the folders list
 * into the user's preferences.
 */
-(void)saveFolderSettings
{
	[[Preferences standardPreferences] setArray:[self archiveState] forKey:MAPref_FolderStates];
}

/* archiveState
 * Creates an NSArray of states for every item in the tree that has a non-normal state.
 */
-(NSArray *)archiveState
{
	NSMutableArray * archiveArray = [NSMutableArray arrayWithCapacity:16];
	int count = [outlineView numberOfRows];
	int index;

	for (index = 0; index < count; ++index)
	{
		TreeNode * node = (TreeNode *)[outlineView itemAtRow:index];
		BOOL isItemExpanded = [outlineView isItemExpanded:node];
		BOOL isItemSelected = [outlineView isRowSelected:index];

		if (isItemExpanded || isItemSelected)
		{
			NSDictionary * newDict = [NSMutableDictionary dictionary];
			[newDict setValue:[NSNumber numberWithInt:[node nodeId]] forKey:@"NodeID"];
			[newDict setValue:[NSNumber numberWithBool:isItemExpanded] forKey:@"ExpandedState"];
			[newDict setValue:[NSNumber numberWithBool:isItemSelected] forKey:@"SelectedState"];
			[archiveArray addObject:newDict];
		}
	}
	return archiveArray;
}

/* unarchiveState
 * Unarchives an array of states.
 * BUGBUG: Restoring multiple selections is not working.
 */
-(void)unarchiveState:(NSArray *)stateArray
{
	for (NSDictionary * dict in stateArray)
	{
		int folderId = [[dict valueForKey:@"NodeID"] intValue];
		TreeNode * node = [rootNode nodeFromID:folderId];
		if (node != nil)
		{
			BOOL doExpandItem = [[dict valueForKey:@"ExpandedState"] boolValue];
			BOOL doSelectItem = [[dict valueForKey:@"SelectedState"] boolValue];
			if ([outlineView isExpandable:node] && doExpandItem)
				[outlineView expandItem:node];
			if (doSelectItem)
			{
				int row = [outlineView rowForItem:node];
				if (row >= 0)
				{
					NSIndexSet * indexes = [NSIndexSet indexSetWithIndex:(NSUInteger )row];
					[outlineView selectRowIndexes:indexes byExtendingSelection:YES];
				}
			}
		}
	}
	[outlineView sizeToFit];
}

/* loadTree
 * Recursive routine that populates the folder list
 */
-(BOOL)loadTree:(NSArray *)listOfFolders rootNode:(TreeNode *)node
{
	Folder * folder;
	if ([[Preferences standardPreferences] foldersTreeSortMethod] != MA_FolderSort_Manual)
	{
		for (folder in listOfFolders)
		{
			int itemId = [folder itemId];
			NSArray * listOfSubFolders = [[Database sharedDatabase] arrayOfFolders:itemId];
			int count = [listOfSubFolders count];
			TreeNode * subNode;

			subNode = [[TreeNode alloc] init:node atIndex:-1 folder:folder canHaveChildren:(count > 0)];
			if (count)
				[self loadTree:listOfSubFolders rootNode:subNode];

			[subNode release];
		}
	}
	else
	{
		NSArray * listOfFolderIds = [listOfFolders valueForKey:@"itemId"];
		NSUInteger index = 0;
		NSInteger nextChildId = (node == rootNode) ? [[Database sharedDatabase] firstFolderId] : [[node folder] firstChildId];
		while (nextChildId > 0)
		{
			NSUInteger  listIndex = [listOfFolderIds indexOfObject:[NSNumber numberWithInt:nextChildId]];
			if (listIndex == NSNotFound)
			{
				NSLog(@"Cannot find child with id %ld for folder with id %ld", (long)nextChildId, (long)[node nodeId]);
				return NO;
			}
			folder = [listOfFolders objectAtIndex:listIndex];
			NSArray * listOfSubFolders = [[Database sharedDatabase] arrayOfFolders:nextChildId];
			NSUInteger count = [listOfSubFolders count];
			TreeNode * subNode;
			
			subNode = [[TreeNode alloc] init:node atIndex:index folder:folder canHaveChildren:(count > 0)];
			if (count)
			{
				if (![self loadTree:listOfSubFolders rootNode:subNode])
				{
					[subNode release];
					return NO;
				}
			}
			[subNode release];
			nextChildId = [folder nextSiblingId];
			++index;
		}
		if (index < [listOfFolders count])
		{
			NSLog(@"Missing children for folder with id %ld, %ld", (long)nextChildId, (long)[node nodeId]);
			return NO;
		}
	}
	return YES;
}

/* folders
 * Returns an array that contains the all RSS folders in the database
 * ordered by the order in which they appear in the folders list view.
 */
-(NSArray *)folders:(int)folderId
{
	NSMutableArray * array = [NSMutableArray array];
	TreeNode * node;

	if (!folderId)
		node = rootNode;
	else
		node = [rootNode nodeFromID:folderId];
	if ([node folder] != nil && (IsRSSFolder([node folder]) || IsGoogleReaderFolder([node folder])))
		[array addObject:[node folder]];
	node = [node firstChild];
	while (node != nil)
	{
		[array addObjectsFromArray:[self folders:[node nodeId]]];
		node = [node nextSibling];
	}
	return array;
}

/* updateAlternateMenuTitle
 * Sets the appropriate title for the alternate item in the contextual menu
 * when user changes preferences for opening pages in external browser
 */
-(void)updateAlternateMenuTitle
{
	NSMenuItem * mainMenuItem = menuItemWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	if (mainMenuItem == nil)
		return;
	NSString * menuTitle = [mainMenuItem title];
	int index;
	NSMenu * folderMenu = [outlineView menu];
	if (folderMenu != nil)
	{
		index = [folderMenu indexOfItemWithTarget:nil andAction:@selector(viewSourceHomePageInAlternateBrowser:)];
		if (index >= 0)
		{
			NSMenuItem * contextualItem = [folderMenu itemAtIndex:index];
			[contextualItem setTitle:menuTitle];
		}
	}
}

/* updateFolder
 * Redraws a folder node and optionally recurses up and redraws all our
 * parent nodes too.
 */
-(void)updateFolder:(int)folderId recurseToParents:(BOOL)recurseToParents
{
	TreeNode * node = [rootNode nodeFromID:folderId];
	if (node != nil)
	{
		[outlineView reloadItem:node reloadChildren:YES];
		if (recurseToParents)
		{
			while ([node parentNode] != rootNode)
			{
				node = [node parentNode];
				[outlineView reloadItem:node];
			}
		}
	}
}

/* canDeleteFolderAtRow
 * Returns YES if the folder at the specified row can be deleted, otherwise NO.
 */
-(BOOL)canDeleteFolderAtRow:(int)row
{
	if (row >= 0)
	{
		TreeNode * node = [outlineView itemAtRow:row];
		if (node != nil)
		{
			Folder * folder = [[Database sharedDatabase] folderFromID:[node nodeId]];
			return folder && !IsSearchFolder(folder) && !IsTrashFolder(folder) && ![[Database sharedDatabase] readOnly] && [[outlineView window] isVisible];
		}
	}
	return NO;
}

/* selectFolder
 * Move the selection to the specified folder and make sure
 * it's visible in the UI.
 */
-(BOOL)selectFolder:(int)folderId
{
	TreeNode * node = [rootNode nodeFromID:folderId];
	if (!node)
		return NO;

	// Walk up to our parent
	[self expandToParent:node];
	int rowIndex = [outlineView rowForItem:node];
	if (rowIndex >= 0)
	{
		blockSelectionHandler = YES;
		[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger )rowIndex] byExtendingSelection:NO];
		[outlineView scrollRowToVisible:rowIndex];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderSelectionChange" object:node];
		blockSelectionHandler = NO;
		return YES;
	}
	return NO;
}

/* expandToParent
 * Expands the parent nodes all the way up to the root to ensure
 * that the node containing 'node' is visible.
 */
-(void)expandToParent:(TreeNode *)node
{
	if ([node parentNode])
	{
		[self expandToParent:[node parentNode]];
		[outlineView expandItem:[node parentNode]];
	}
}

/* nextFolderWithUnreadAfterNode
 * Finds the ID of the next folder after the specified node that has
 * unread articles.
 */
-(int)nextFolderWithUnreadAfterNode:(TreeNode *)startingNode
{
	TreeNode * node = startingNode;

	while (node != nil)
	{
		TreeNode * nextNode = nil;
		TreeNode * parentNode = [node parentNode];
		if (([[node folder] childUnreadCount] > 0) && [outlineView isItemExpanded:node])
			nextNode = [node firstChild];
		if (nextNode == nil)
			nextNode = [node nextSibling];
		while (nextNode == nil && parentNode != nil)
		{
			nextNode = [parentNode nextSibling];
			parentNode = [parentNode parentNode];
		}
		if (nextNode == nil)
			nextNode = [rootNode firstChild];

		if (([[nextNode folder] childUnreadCount]) && ![outlineView isItemExpanded:nextNode])
			return [nextNode nodeId];
		
		if ([[nextNode folder] unreadCount])
			return [nextNode nodeId];

		// If we've gone full circle and not found
		// anything, we're out of unread articles
		if (nextNode == startingNode)
			return [startingNode nodeId];

		node = nextNode;
	}
	return -1;
}

/* firstFolderWithUnread
 * Finds the ID of the first folder that has unread articles.
 */
-(int)firstFolderWithUnread
{
	// Get the first Node from the root node.
	TreeNode * firstNode = [rootNode firstChild];
	
	// Now get the ID of the next unread node after it and return it.
	int nextNodeID = [self nextFolderWithUnreadAfterNode:firstNode];
	return nextNodeID;
}

/* nextFolderWithUnread
 * Finds the ID of the next folder after currentFolderId that has
 * unread articles.
 */
-(int)nextFolderWithUnread:(int)currentFolderId
{
	// Get the current Node from the ID.
	TreeNode * currentNode = [rootNode nodeFromID:currentFolderId];
	
	// Now get the ID of the next unread node after it and return it.
	int nextNodeID = [self nextFolderWithUnreadAfterNode:currentNode];
	return nextNodeID;
}

/* groupParentSelection
 * If the selected folder is a group folder, it returns the ID of the group folder
 * otherwise it returns the ID of the parent folder.
 */
-(int)groupParentSelection
{
	Folder * folder = [[Database sharedDatabase] folderFromID:[self actualSelection]];
	return folder ? ((IsGroupFolder(folder)) ? [folder itemId] : [folder parentId]) : MA_Root_Folder;
}

/* actualSelection
 * Return the ID of the selected folder in the folder list.
 */
-(int)actualSelection
{
	TreeNode * node = [outlineView itemAtRow:[outlineView selectedRow]];
	return [node nodeId];
}

/* countOfSelectedFolders
 * Return the total number of folders selected in the tree.
 */
-(int)countOfSelectedFolders
{
	return [outlineView numberOfSelectedRows];
}

/* selectedFolders
 * Returns an exclusive array of all selected folders. Exclusive means that if any folder is
 * a group folder, we don't automatically return a list of all folders within that group.
 */
-(NSArray *)selectedFolders
{
	NSIndexSet * rowIndexes = [outlineView selectedRowIndexes];
	NSUInteger count = [rowIndexes count];
	
	// Make a mutable array
	NSMutableArray * arrayOfSelectedFolders = [NSMutableArray arrayWithCapacity:count];

	if (count > 0)
	{
		NSUInteger index = [rowIndexes firstIndex];
		while (index != NSNotFound)
		{
			TreeNode * node = [outlineView itemAtRow:index];
			Folder * folder = [node folder];
			if (folder != nil)
			{
				[arrayOfSelectedFolders addObject:folder];
			}
			index = [rowIndexes indexGreaterThanIndex:index];
		}
	}
	
	return arrayOfSelectedFolders;
}

/* setManualSortOrderForNode
 * Writes the order of the current folder hierarchy to the database.
 */
-(void)setManualSortOrderForNode:(TreeNode *)node
{
	if (node == nil)
		return;
	Database * db = [Database sharedDatabase];
	int folderId = [node nodeId];
	
	int count = [node countOfChildren];
	if (count > 0)
	{
		[db setFirstChild:[[node childByIndex:0] nodeId] forFolder:folderId];
		[self setManualSortOrderForNode:[node childByIndex:0]];
		int index;
		for (index = 1; index < count; ++index)
		{
			[db setNextSibling:[[node childByIndex:index] nodeId] forFolder:[[node childByIndex:index - 1] nodeId]];
			[self setManualSortOrderForNode:[node childByIndex:index]];
		}
		[db setNextSibling:0 forFolder:[[node childByIndex:index - 1] nodeId]];
	}
	else
		[db setFirstChild:0 forFolder:folderId];
}

/* handleAutoSortFoldersTreeChange
 * Respond to the notification when the preference is changed for automatically or manually sorting the folders tree.
 */
-(void)handleAutoSortFoldersTreeChange:(NSNotification *)nc
{
	int selectedFolderId = [self actualSelection];
	
	if ([[Preferences standardPreferences] foldersTreeSortMethod] == MA_FolderSort_Manual)
	{
		Database * db = [Database sharedDatabase];
		[db doTransactionWithBlock:^(BOOL *rollback) {
		[self setManualSortOrderForNode:rootNode];
		}]; //end transaction block
	}
	
	blockSelectionHandler = YES;
	[self reloadDatabase:[[Preferences standardPreferences] arrayForKey:MAPref_FolderStates]];
	blockSelectionHandler = NO;
	
	// Make sure selected folder is visible
	[self selectFolder:selectedFolderId];
}

/* handleShowFolderImagesChange
 * Respond to the notification sent when the option to show folder images is changed.
 */
-(void)handleShowFolderImagesChange:(NSNotification *)nc
{
	[outlineView reloadData];
}

/* handleSingleClick
 * If the folder is already highlighted, then edit the folder name.
 */
-(void)handleSingleClick:(id)sender
{
	if (canRenameFolders)
	{
		int clickedRow = [outlineView clickedRow];
		if (clickedRow >= 0)
			[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(renameFolderByTimer:) userInfo:[outlineView itemAtRow:clickedRow] repeats:NO];
	}
}

/* handleDoubleClick
 * Handle the user double-clicking a node.
 */
-(void)handleDoubleClick:(id)sender
{
	// Prevent the first click of the double click from triggering immediate folder name editing.
	[self enableFoldersRenamingAfterDelay];
	
	TreeNode * node = [outlineView itemAtRow:[outlineView selectedRow]];

	if (IsRSSFolder([node folder])||IsGoogleReaderFolder([node folder]))
	{
		NSString * urlString = [[node folder] homePage];
		if (urlString && ![urlString isBlank])
			[APPCONTROLLER openURLFromString:urlString inPreferredBrowser:YES];
	}
	else if (IsSmartFolder([node folder]))
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_EditFolder" object:node];
	}
}

/* handleFolderDeleted
 * Called whenever a folder is removed from the database. We need
 * to delete the associated tree nodes then select the next node, or
 * the previous one if we were at the bottom of the list.
 */
-(void)handleFolderDeleted:(NSNotification *)nc
{
	int currentFolderId = [controller currentFolderId];
	int folderId = [(NSNumber *)[nc object] intValue];
	TreeNode * thisNode = [rootNode nodeFromID:folderId];
	TreeNode * nextNode;
	
	// Stop any in process progress indicators.
	[thisNode stopAndReleaseProgressIndicator];

	// First find the next node we'll select
	if ([thisNode nextSibling] != nil)
		nextNode = [thisNode nextSibling];
	else
	{
		nextNode = [thisNode parentNode];
		if ([nextNode countOfChildren] > 1)
			nextNode = [nextNode childByIndex:[nextNode countOfChildren] - 2];
	}

	// Ask our parent to delete us
	TreeNode * ourParent = [thisNode parentNode];
	[ourParent removeChild:thisNode andChildren:YES];
	[self reloadFolderItem:ourParent reloadChildren:YES];

	// Send the selection notification ourselves because if we're deleting at the end of
	// the folder list, the selection won't actually change and outlineViewSelectionDidChange
	// won't get tripped.
	if (currentFolderId == folderId)
	{
		blockSelectionHandler = YES;
		[self selectFolder:[nextNode nodeId]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderSelectionChange" object:nextNode];
		blockSelectionHandler = NO;
	}
}

/* handleFolderNameChange
 * Called whenever we need to redraw a specific folder, possibly because
 * the unread count changed.
 */
-(void)handleFolderNameChange:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	TreeNode * node = [rootNode nodeFromID:folderId];
	TreeNode * parentNode = [node parentNode];

	BOOL moveSelection = (folderId == [self actualSelection]);

	if ([[Preferences standardPreferences] foldersTreeSortMethod] == MA_FolderSort_ByName)
		[parentNode sortChildren:MA_FolderSort_ByName];

	[self reloadFolderItem:parentNode reloadChildren:YES];
	if (moveSelection)
	{
		int row = [outlineView rowForItem:node];
		if (row >= 0)
		{
			blockSelectionHandler = YES;
			NSIndexSet * indexes = [NSIndexSet indexSetWithIndex:(NSUInteger )row];
			[outlineView selectRowIndexes:indexes byExtendingSelection:NO];
			[outlineView scrollRowToVisible:row];
			blockSelectionHandler = NO;
		}
	}
}

/* handleFolderUpdate
 * Called whenever we need to redraw a specific folder, possibly because
 * the unread count changed.
 */
-(void)handleFolderUpdate:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	if (folderId == 0)
		[self reloadFolderItem:rootNode reloadChildren:YES];
	else
		[self updateFolder:folderId recurseToParents:YES];
}

/* handleFolderAdded
 * Called when a new folder is added to the database.
 */
-(void)handleFolderAdded:(NSNotification *)nc
{
	Folder * newFolder = (Folder *)[nc object];
	NSAssert(newFolder, @"Somehow got a NULL folder object here");

	int parentId = [newFolder parentId];
	TreeNode * node = (parentId == MA_Root_Folder) ? rootNode : [rootNode nodeFromID:parentId];
	if (![node canHaveChildren])
		[node setCanHaveChildren:YES];
	
	int childIndex = -1;
	if ([[Preferences standardPreferences] foldersTreeSortMethod] == MA_FolderSort_Manual)
	{
		int nextSiblingId = [newFolder nextSiblingId];
		if (nextSiblingId > 0)
		{
			TreeNode * nextSibling = [node nodeFromID:nextSiblingId];
			if (nextSibling != nil)
				childIndex = [node indexOfChild:nextSibling];
		}
	}
	
	TreeNode * newNode = [[TreeNode alloc] init:node atIndex:childIndex folder:newFolder canHaveChildren:NO];
	[self reloadFolderItem:node reloadChildren:YES];
	[newNode release];
}

/* reloadFolderItem
 * Wrapper around reloadItem.
 */
-(void)reloadFolderItem:(id)node reloadChildren:(BOOL)flag
{
	if (node == rootNode)
		[outlineView reloadData];
	else
		[outlineView reloadItem:node reloadChildren:YES];
}

/* menuWillAppear
 * Called when the popup menu is opened on the folder list. We move the
 * selection to whichever node is under the cursor so the context between
 * the menu items and the node is made clear.
 */
-(void)outlineView:(FolderView *)olv menuWillAppear:(NSEvent *)theEvent
{
	int row = [olv rowAtPoint:[olv convertPoint:[theEvent locationInWindow] fromView:nil]];
	if (row >= 0)
	{
		// Select the row under the cursor if it isn't already selected
		if ([olv numberOfSelectedRows] <= 1)
			[olv selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger )row] byExtendingSelection:NO];
	}
}

/* isItemExpandable
 * Tell the outline view if the specified item can be expanded. The answer is
 * yes if we have children, no otherwise.
 */
-(BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node == nil)
		node = rootNode;
	return [node canHaveChildren];
}

/* numberOfChildrenOfItem
 * Returns the number of children belonging to the specified item
 */
-(int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node == nil)
		node = rootNode;
	return [node countOfChildren];
}

/* child
 * Returns the child at the specified offset of the item
 */
-(id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node == nil)
		node = rootNode;
	return [node childByIndex:index];
}

/* tooltipForItem [dataSource]
 * For items that have counts, we show a tooltip that aggregates the counts.
 */
-(NSString *)outlineView:(FolderView *)outlineView tooltipForItem:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node != nil)
	{
		if ([[node folder] nonPersistedFlags] & MA_FFlag_Error)
			return NSLocalizedString(@"An error occurred when this feed was last refreshed", nil);
		if ([[node folder] childUnreadCount])
			return [NSString stringWithFormat:NSLocalizedString(@"%d unread articles", nil), [[node folder] childUnreadCount]];
	}
	return nil;
}

/* objectValueForTableColumn
 * Returns the actual string that is displayed in the cell. Folders that have child folders with unread
 * articles show the aggregate unread article count.
 */
-(id)outlineView:(NSOutlineView *)olv objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node == nil)
		node = rootNode;

	static NSDictionary * info = nil;
	if (info == nil)
	{
		NSMutableParagraphStyle * style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
		info = [[NSDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, nil];
		[style release];
	}

	Folder * folder = [node folder];
	int rowIndex = [olv rowForItem:item];
	NSMutableDictionary * myInfo = [NSMutableDictionary dictionaryWithDictionary:info];
	// Set the colour of the text in the cell : default is blackColor
	if (IsUnsubscribed(folder))
		[myInfo setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
	else if ([olv selectedRow] == rowIndex && [olv editedRow] != rowIndex)
		[myInfo setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	// Set the font
	if ([folder unreadCount] ||  ([folder childUnreadCount] && ![olv isItemExpanded:item]))
		[myInfo setObject:boldCellFont forKey:NSFontAttributeName];
	else
		[myInfo setObject:cellFont forKey:NSFontAttributeName];
	
	return [[[NSAttributedString alloc] initWithString:[node nodeName] attributes:myInfo] autorelease];
}

/* willDisplayCell
 * Hook before a cell is displayed to set the correct image for that cell. We use this to show the folder
 * in normal or bold face depending on whether or not the folder (or sub-folders) have unread articles. This
 * is also the place where we set the folder image.
 */
-(void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item 
{
	if ([[tableColumn identifier] isEqualToString:@"folderColumns"]) 
	{
		TreeNode * node = (TreeNode *)item;
		Folder * folder = [node folder];
		ImageAndTextCell * realCell = (ImageAndTextCell *)cell;

		[realCell setItem:item];

		// Use the auxiliary position of the feed item to show
		// the refresh icon if the feed is being refreshed, or an
		// error icon if the feed failed to refresh last time.
		if (IsUpdating(folder))
		{
			[realCell setAuxiliaryImage:nil];
			[realCell setInProgress:YES];
		}
		else if (IsError(folder))
		{
			[realCell setAuxiliaryImage:folderErrorImage];
			[realCell setInProgress:NO];
		}
		else
		{
			[realCell setAuxiliaryImage:nil];
			[realCell setInProgress:NO];
		}

		if (IsSmartFolder(folder))  // Because if the search results contain unread articles we don't want the smart folder name to be bold.
		{
			[realCell clearCount];
		}
		else if ([folder unreadCount])
		{
			[realCell setCount:[folder unreadCount]];
			[realCell setCountBackgroundColour:[NSColor colorForControlTint:[NSColor currentControlTint]]];
		}
		else if ([folder childUnreadCount] && ![olv isItemExpanded:item])
		{
			[realCell setCount:[folder childUnreadCount]];
			[realCell setCountBackgroundColour:[NSColor colorForControlTint:[NSColor currentControlTint]]];
		}
		else
		{
			[realCell clearCount];
		}

		// Only show folder images if the user prefers them.
		Preferences * prefs = [Preferences standardPreferences];
		[realCell setImage:([prefs showFolderImages] ? [folder image] : [folder standardImage])];
	}
}

/* mainView
 * Return the main view of this class.
 */
-(NSView *)mainView
{
	return outlineView;
}

/* outlineViewSelectionDidChange
 * Called when the selection in the folder list has changed.
 */
-(void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	[self enableFoldersRenamingAfterDelay];
	
	if (!blockSelectionHandler)
	{
		TreeNode * node = [outlineView itemAtRow:[outlineView selectedRow]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderSelectionChange" object:node];
	}
}

/* renameFolder
 * Begin in-place editing of the selected folder name.
 */
-(void)renameFolder:(int)folderId
{	
	TreeNode * node = [rootNode nodeFromID:folderId];
	NSInteger rowIndex = [outlineView rowForItem:node];
		
	if (rowIndex != -1)
	{
		[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger )rowIndex] byExtendingSelection:NO];
		[outlineView editColumn:[outlineView columnWithIdentifier:@"folderColumns"] row:rowIndex withEvent:nil select:YES];
	}
}

/* renameFolderByTimer
 * If no disabling events have occurred during the timer interval, rename the folder.
 */
-(void)renameFolderByTimer:(id)sender
{
	if (canRenameFolders)
	{
		[self renameFolder:[(TreeNode *)[sender userInfo] nodeId]];
	}
}

/* enableFoldersRenaming
 * Enable the renaming of folders.
 */
-(void)enableFoldersRenaming:(id)sender
{
	canRenameFolders = YES;
}

/* enableFoldersRenamingAfterDelay
 * Set a timer to enable renaming of folders.
 */
-(void)enableFoldersRenamingAfterDelay
{
	canRenameFolders = NO;
	[NSTimer scheduledTimerWithTimeInterval:[NSEvent doubleClickInterval] target:self selector:@selector(enableFoldersRenaming:) userInfo:nil repeats:NO];
}

/* outlineViewWillBecomeFirstResponder
 * When outline view becomes first responder, bring the article view to the front,
 * and prevent immediate folder renaming.
 */
-(void)outlineViewWillBecomeFirstResponder
{
	[[controller browserView] setActiveTabToPrimaryTab];
	[self enableFoldersRenamingAfterDelay];
}

/* shouldEditTableColumn [delegate]
 * The editing of folder names will be handled by single clicks.
 */
-(BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return NO;
}

/* setObjectValue [datasource]
 * Update the folder name when the user has finished editing it.
 */
-(void)outlineView:(NSOutlineView *)olv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	TreeNode * node = (TreeNode *)item;
	NSString * newName = (NSString *)object;
	Folder * folder = [node folder];
	
	// Remove the "☁️ " symbols on Open Reader feeds
	if (IsGoogleReaderFolder(folder) && [newName hasPrefix:@"☁️ "]) {
		NSString *tmpName = [newName substringFromIndex:3];
		newName = tmpName;
	}
	
	if (![[folder name] isEqualToString:newName])
	{
		Database * db = [Database sharedDatabase];
		if ([db folderFromName:newName] != nil)
			runOKAlertPanel(NSLocalizedString(@"Cannot rename folder", nil), NSLocalizedString(@"A folder with that name already exists", nil));
		else
        {
			[db setFolderName:[folder itemId] newName:newName];
        }
	}
}

/* validateDrop
 * Called when something is being dragged over us. We respond with an NSDragOperation value indicating the
 * feedback for the user given where we are.
 */
-(NSDragOperation)outlineView:(NSOutlineView*)olv validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index
{
	NSPasteboard * pb = [info draggingPasteboard]; 
	NSString * type = [pb availableTypeFromArray:[NSArray arrayWithObjects:MA_PBoardType_FolderList, MA_PBoardType_RSSSource, @"WebURLsWithTitlesPboardType", NSStringPboardType, nil]]; 
	NSDragOperation dragType = ([type isEqualToString:MA_PBoardType_FolderList]) ? NSDragOperationMove : NSDragOperationCopy;

	TreeNode * node = (TreeNode *)item;
	BOOL isOnDropTypeProposal = index == NSOutlineViewDropOnItemIndex;

	// Can't drop anything onto the trash folder.
	if (isOnDropTypeProposal && node != nil && IsTrashFolder([node folder]))
		return NSDragOperationNone; 

	// Can't drop anything onto the search folder.
	if (isOnDropTypeProposal && node != nil && IsSearchFolder([node folder]))
		return NSDragOperationNone; 
	
	// Can't drop anything on smart folders.
	if (isOnDropTypeProposal && node != nil && IsSmartFolder([node folder]))
		return NSDragOperationNone; 
	
	// Can always drop something on a group folder.
	if (isOnDropTypeProposal && node != nil && IsGroupFolder([node folder]))
		return dragType;
	
	// For any other folder, can't drop anything ON them.
	if (index == NSOutlineViewDropOnItemIndex)
		return NSDragOperationNone;
	return NSDragOperationGeneric; 
}

/* writeItems [delegate]
 * Collect the selected folders ready for dragging.
 */
-(BOOL)outlineView:(NSOutlineView *)olv writeItems:(NSArray*)items toPasteboard:(NSPasteboard*)pboard
{
	return [self copyTableSelection:items toPasteboard:pboard];
}

/* copyTableSelection
 * This is the common copy selection code. We build an array of dictionary entries each of
 * which include details of each selected folder in the standard RSS item format defined by
 * Ranchero NetNewsWire. See http://ranchero.com/netnewswire/rssclipboard.php for more details.
 */
-(BOOL)copyTableSelection:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	int count = [items count];
	NSMutableArray * externalDragData = [NSMutableArray arrayWithCapacity:count];
	NSMutableArray * internalDragData = [NSMutableArray arrayWithCapacity:count];
	NSMutableString * stringDragData = [NSMutableString string];
	NSMutableArray * arrayOfURLs = [NSMutableArray arrayWithCapacity:count];
	NSMutableArray * arrayOfTitles = [NSMutableArray arrayWithCapacity:count];
	int index;

	// We'll create the types of data on the clipboard.
	[pboard declareTypes:[NSArray arrayWithObjects:MA_PBoardType_FolderList, MA_PBoardType_RSSSource, @"WebURLsWithTitlesPboardType", NSStringPboardType, nil] owner:self]; 

	// Create an array of NSNumber objects containing the selected folder IDs.
	int countOfItems = 0;
	for (index = 0; index < count; ++index)
	{
		TreeNode * node = [items objectAtIndex:index];
		Folder * folder = [node folder];

		if (IsRSSFolder(folder) || IsGoogleReaderFolder(folder) || IsSmartFolder(folder) || IsGroupFolder(folder) || IsSearchFolder(folder) || IsTrashFolder(folder))
		{
			[internalDragData addObject:[NSNumber numberWithInt:[node nodeId]]];
			++countOfItems;
		}

		if (IsRSSFolder(folder)||IsGoogleReaderFolder(folder))
		{
			NSString * feedURL = [folder feedURL];
			
			NSMutableDictionary * dict = [NSMutableDictionary dictionary];
			[dict setValue:[folder name] forKey:@"sourceName"];
			[dict setValue:[folder description] forKey:@"sourceDescription"];
			[dict setValue:feedURL forKey:@"sourceRSSURL"];
			[dict setValue:[folder homePage] forKey:@"sourceHomeURL"];
			[externalDragData addObject:dict];

			[stringDragData appendString:feedURL];
			[stringDragData appendString:@"\n"];
			
			NSURL * safariURL = [NSURL URLWithString:feedURL];
			if (safariURL != nil && ![safariURL isFileURL])
			{
				if (![@"feed" isEqualToString:[safariURL scheme]])
				{
					feedURL = [NSString stringWithFormat:@"feed:%@", [safariURL resourceSpecifier]];
				}
				[arrayOfURLs addObject:feedURL];
				[arrayOfTitles addObject:[folder name]];
			}
		}
	}

	// Copy the data to the pasteboard 
	[pboard setPropertyList:externalDragData forType:MA_PBoardType_RSSSource];
	[pboard setString:stringDragData forType:NSStringPboardType];
	[pboard setPropertyList:internalDragData forType:MA_PBoardType_FolderList]; 
	[pboard setPropertyList:[NSArray arrayWithObjects:arrayOfURLs, arrayOfTitles, nil] forType:@"WebURLsWithTitlesPboardType"]; 
	return countOfItems > 0; 
}

/* moveFoldersUndo
 * Undo handler to move folders back.
 */
-(void)moveFoldersUndo:(id)anObject
{
	[self moveFolders:(NSArray *)anObject withGoogleSync:YES];
}

/* moveFolders
 * Reparent folders using the information in the specified array. The array consists of
 * a collection of NSNumber triples: the first number is the ID of the folder to move,
 * the second number is the ID of the parent to which the folder should be moved,
 * the third number is the ID of the folder's new predecessor sibling.
 */
-(BOOL)moveFolders:(NSArray *)array withGoogleSync:(BOOL)sync
{
	NSAssert(([array count] % 3) == 0, @"Incorrect number of items in array passed to moveFolders");
	int count = [array count];
	__block int index = 0;

	// Need to create a running undo array
	NSMutableArray * undoArray = [[NSMutableArray alloc] initWithCapacity:count];

	// Internal drag and drop so we're just changing the parent IDs around. One thing
	// we have to watch for is to make sure that we don't re-parent to a subordinate
	// folder.
	Database * db = [Database sharedDatabase];
	BOOL autoSort = [[Preferences standardPreferences] foldersTreeSortMethod] != MA_FolderSort_Manual;

	[db doTransactionWithBlock:^(BOOL *rollback) {
	while (index < count)
	{
		int folderId = [[array objectAtIndex:index++] intValue];
		int newParentId = [[array objectAtIndex:index++] intValue];
		int newPredecessorId = [[array objectAtIndex:index++] intValue];
		Folder * folder = [db folderFromID:folderId];
		int oldParentId = [folder parentId];
		
		TreeNode * node = [rootNode nodeFromID:folderId];
		TreeNode * oldParent = [rootNode nodeFromID:oldParentId];
		int oldChildIndex = [oldParent indexOfChild:node];
		int oldPredecessorId = (oldChildIndex > 0) ? [[oldParent childByIndex:(oldChildIndex - 1)] nodeId] : 0;
		TreeNode * newParent = [rootNode nodeFromID:newParentId];
		TreeNode * newPredecessor = [newParent nodeFromID:newPredecessorId];
		if ((newPredecessor == nil) || (newPredecessor == newParent))
			newPredecessorId = 0;
		int newChildIndex = (newPredecessorId > 0) ? ([newParent indexOfChild:newPredecessor] + 1) : 0;
        
		if (newParentId == oldParentId)
		{
			// With automatic sorting, moving under the same parent is impossible.
			if (autoSort)
				continue;
			// No need to move if destination is the same as origin.
			if (newPredecessorId == oldPredecessorId)
				continue;
			// Adjust the index for the removal of the old child.
			if (newChildIndex > oldChildIndex)
				--newChildIndex;
		}
		else
		{
			if (![newParent canHaveChildren])
				[newParent setCanHaveChildren:YES];
			if ([db setParent:newParentId forFolder:folderId])
			{
				if (IsGoogleReaderFolder(folder))
				{
					GoogleReader * myGoogle = [GoogleReader sharedManager];
					// remove old label
					NSString * folderName = [[db folderFromID:oldParentId] name];
					[myGoogle setFolderName:folderName forFeed:[folder feedURL] set:FALSE];
					// add new label
					folderName = [[db folderFromID:newParentId] name];
					[myGoogle setFolderName:folderName forFeed:[folder feedURL] set:TRUE];
				}
			}
			else
				continue;
		}
		
		if (!autoSort)
		{
			if (oldPredecessorId > 0)
			{
				if (![db setNextSibling:[folder nextSiblingId] forFolder:oldPredecessorId])
					continue;
			}
			else
			{
				if (![db setFirstChild:[folder nextSiblingId] forFolder:oldParentId])
					continue;
			}
		}
		
		[node retain];
		[oldParent removeChild:node andChildren:NO];
		[newParent addChild:node atIndex:newChildIndex];
		[node release];
		
		// Put at beginning of undoArray in order to undo moves in reverse order.
		[undoArray insertObject:[NSNumber numberWithInt:folderId] atIndex:0u];
		[undoArray insertObject:[NSNumber numberWithInt:oldParentId] atIndex:1u];
		[undoArray insertObject:[NSNumber numberWithInt:oldPredecessorId] atIndex:2u];
		
		if (!autoSort)
		{
			if (newPredecessorId > 0)
			{
				if (![db setNextSibling:[[db folderFromID:newPredecessorId] nextSiblingId] forFolder:folderId])
					continue;
				[db setNextSibling:folderId forFolder:newPredecessorId];
			}
			else
			{
				int oldFirstChildId = (newParent == rootNode) ? [db firstFolderId] : [[newParent folder] firstChildId];
				if (![db setNextSibling:oldFirstChildId forFolder:folderId])
					continue;
				[db setFirstChild:folderId forFolder:newParentId];
			}
		}
	}
	}]; //end transaction block
	
	// If undo array is empty, then nothing has been moved.
	if ([undoArray count] == 0u)
	{
		[undoArray release];
		return NO;
	}
	
	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	[undoManager registerUndoWithTarget:self selector:@selector(moveFoldersUndo:) object:undoArray];
	[undoManager setActionName:NSLocalizedString(@"Move Folders", nil)];
	[undoArray release];
	
	// Make the outline control reload its data
	[outlineView reloadData];

	// If any parent was a collapsed group, expand it now
	for (index = 0; index < count; index += 2)
	{
		int newParentId = [[array objectAtIndex:++index] intValue];
		if (newParentId != MA_Root_Folder)
		{
			TreeNode * parentNode = [rootNode nodeFromID:newParentId];
			if (![outlineView isItemExpanded:parentNode] && [outlineView isExpandable:parentNode])
				[outlineView expandItem:parentNode];
		}
	}
	
	// Properly set selection back to the original items. This has to be done after the
	// refresh so that rowForItem returns the new positions.
	NSMutableIndexSet * selIndexSet = [[NSMutableIndexSet alloc] init];
	int selRowIndex = 9999;
	for (index = 0; index < count; index += 2)
	{
		int folderId = [[array objectAtIndex:index++] intValue];
		int rowIndex = [outlineView rowForItem:[rootNode nodeFromID:folderId]];
		selRowIndex = MIN(selRowIndex, rowIndex);
		[selIndexSet addIndex:rowIndex];
	}
	[outlineView scrollRowToVisible:selRowIndex];
	[outlineView selectRowIndexes:selIndexSet byExtendingSelection:NO];
	[selIndexSet release];
	return YES;
}

/* acceptDrop
 * Accept a drop on or between nodes either from within the folder view or from outside.
 */
-(BOOL)outlineView:(NSOutlineView *)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)targetItem childIndex:(int)child
{ 
	__block int childIndex = child;
	NSPasteboard * pb = [info draggingPasteboard];
	NSString * type = [pb availableTypeFromArray:[NSArray arrayWithObjects:MA_PBoardType_FolderList, MA_PBoardType_RSSSource, @"WebURLsWithTitlesPboardType", NSStringPboardType, nil]];
	TreeNode * node = targetItem ? (TreeNode *)targetItem : rootNode;

	int parentId = [node nodeId];
	if ((childIndex == NSOutlineViewDropOnItemIndex) || (childIndex < 0))
		childIndex = 0;

	// Check the type
	if ([type isEqualToString:NSStringPboardType])
	{
		// This is possibly a URL that we'll handle as a potential feed subscription. It's
		// not our call to make though.
		int predecessorId = (childIndex > 0) ? [[node childByIndex:(childIndex - 1)] nodeId] : 0;
		[APPCONTROLLER createNewSubscription:[pb stringForType:type] underFolder:parentId afterChild:predecessorId];
		return YES;
	}
	if ([type isEqualToString:MA_PBoardType_FolderList])
	{
		Database * db = [Database sharedDatabase];
		NSArray * arrayOfSources = [pb propertyListForType:type];
		int count = [arrayOfSources count];
		int index;
		int predecessorId = (childIndex > 0) ? [[node childByIndex:(childIndex - 1)] nodeId] : 0;

		// Create an NSArray of triples (folderId, newParentId, predecessorId) that will be passed to moveFolders
		// to do the actual move.
		NSMutableArray * array = [[NSMutableArray alloc] initWithCapacity:count * 3];
		int trashFolderId = [db trashFolderId];
		for (index = 0; index < count; ++index)
		{
			int folderId = [[arrayOfSources objectAtIndex:index] intValue];
			
			// Don't allow the trash folder to move under a group folder, because the group folder could get deleted.
			// Also, don't allow perverse moves.  We should probably do additional checking: not only whether the new parent
			// is the folder itself but also whether the new parent is a subfolder.
			if (((folderId == trashFolderId) && (node != rootNode)) || (folderId == parentId) || (folderId == predecessorId))
				continue;
			[array addObject:[NSNumber numberWithInt:folderId]];
			[array addObject:[NSNumber numberWithInt:parentId]];
			[array addObject:[NSNumber numberWithInt:predecessorId]];
			predecessorId = folderId;
		}

		// Do the move
		BOOL result = [self moveFolders:array withGoogleSync:YES];
		[array release];
		return result;
	}
	if ([type isEqualToString:MA_PBoardType_RSSSource])
	{
		Database * db = [Database sharedDatabase];
		NSArray * arrayOfSources = [pb propertyListForType:type];
		int count = [arrayOfSources count];
		int index;
		
		// This is an RSS drag using the protocol defined by Ranchero for NetNewsWire. See
		// http://ranchero.com/netnewswire/rssclipboard.php for more details.
		//
		__block int folderToSelect = -1;
		for (index = 0; index < count; ++index)
		{
			[db doTransactionWithBlock:^(BOOL *rollback) {
			NSDictionary * sourceItem = [arrayOfSources objectAtIndex:index];
			NSString * feedTitle = [sourceItem valueForKey:@"sourceName"];
			NSString * feedHomePage = [sourceItem valueForKey:@"sourceHomeURL"];
			NSString * feedURL = [sourceItem valueForKey:@"sourceRSSURL"];
			NSString * feedDescription = [sourceItem valueForKey:@"sourceDescription"];

			if ((feedURL != nil) && [db folderFromFeedURL:feedURL] == nil)
			{
				int predecessorId = (childIndex > 0) ? [[node childByIndex:(childIndex - 1)] nodeId] : 0;
				int folderId = [db addRSSFolder:feedTitle underParent:parentId afterChild:predecessorId subscriptionURL:feedURL];
				if (feedDescription != nil)
					[db setFolderDescription:folderId newDescription:feedDescription];
				if (feedHomePage != nil)
					[db setFolderHomePage:folderId newHomePage:feedHomePage];
				if (folderId > 0)
					folderToSelect = folderId;
				++childIndex;
			}
			}]; //end transaction block
		}

		// If parent was a group, expand it now
		if (parentId != MA_Root_Folder)
			[outlineView expandItem:[rootNode nodeFromID:parentId]];
		
		// Select a new folder
		if (folderToSelect > 0)
			[self selectFolder:folderToSelect];
		
		return YES;
	}
	if ([type isEqualToString:@"WebURLsWithTitlesPboardType"])
	{
		Database * db = [Database sharedDatabase];
		NSArray * webURLsWithTitles = [pb propertyListForType:type];
		NSArray * arrayOfURLs = [webURLsWithTitles objectAtIndex:0];
		NSArray * arrayOfTitles = [webURLsWithTitles objectAtIndex:1];
		int count = [arrayOfURLs count];
		int index;
		
		__block int folderToSelect = -1;
		for (index = 0; index < count; ++index)
		{
			[db doTransactionWithBlock:^(BOOL *rollback) {
			NSString * feedTitle = [arrayOfTitles objectAtIndex:index];
			NSString * feedURL = [arrayOfURLs objectAtIndex:index];
			NSURL * draggedURL = [NSURL URLWithString:feedURL];
			if (([draggedURL scheme] != nil) && [[draggedURL scheme] isEqualToString:@"feed"])
				feedURL = [NSString stringWithFormat:@"http:%@", [draggedURL resourceSpecifier]];
			
			if ([db folderFromFeedURL:feedURL] == nil)
			{
				int predecessorId = (childIndex > 0) ? [[node childByIndex:(childIndex - 1)] nodeId] : 0;
				int newFolderId = [db addRSSFolder:feedTitle underParent:parentId afterChild:predecessorId subscriptionURL:feedURL];
				if (newFolderId > 0)
					folderToSelect = newFolderId;
				++childIndex;
			}
			}]; //end transaction block
		}
		
		// If parent was a group, expand it now
		if (parentId != MA_Root_Folder)
			[outlineView expandItem:[rootNode nodeFromID:parentId]];
		
		// Select a new folder
		if (folderToSelect > 0)
			[self selectFolder:folderToSelect];
		
		return YES;
	}
	return NO; 
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[cellFont release];
	cellFont=nil;
	[boldCellFont release];
	boldCellFont=nil;
	[folderErrorImage release];
	folderErrorImage=nil;
	[refreshProgressImage release];
	refreshProgressImage=nil;
	[rootNode release];
	rootNode=nil;
	[super dealloc];
}
@end
