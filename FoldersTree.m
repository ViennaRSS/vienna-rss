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
#import "TexturedHeader.h"
#import "ViennaApp.h"

// Private functions
@interface FoldersTree (Private)
	-(void)setFolderListFont;
	-(NSArray *)archiveState;
	-(void)unarchiveState:(NSArray *)stateArray;
	-(void)reloadDatabase:(NSArray *)stateArray;
	-(void)loadTree:(NSArray *)listOfFolders rootNode:(TreeNode *)node;
	-(void)handleDoubleClick:(id)sender;
	-(void)handleFolderAdded:(NSNotification *)nc;
	-(void)handleFolderUpdate:(NSNotification *)nc;
	-(void)handleFolderDeleted:(NSNotification *)nc;
	-(void)handleFolderFontChange:(NSNotification *)note;
	-(void)reloadFolderItem:(id)node reloadChildren:(BOOL)flag;
	-(void)expandToParent:(TreeNode *)node;
	-(BOOL)copyTableSelection:(NSArray *)items toPasteboard:(NSPasteboard *)pboard;
	-(void)moveFolders:(NSArray *)array;
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
		rootNode = [[TreeNode alloc] init:nil folder:nil canHaveChildren:YES];
		blockSelectionHandler = NO;
		db = nil;
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

	// Register to be notified when folders are added or removed
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleFolderUpdate:) name:@"MA_Notify_FoldersUpdated" object:nil];
	[nc addObserver:self selector:@selector(handleFolderAdded:) name:@"MA_Notify_FolderAdded" object:nil];
	[nc addObserver:self selector:@selector(handleFolderDeleted:) name:@"MA_Notify_FolderDeleted" object:nil];
	[nc addObserver:self selector:@selector(outlineViewMenuInvoked:) name:@"MA_Notify_RightClickOnObject" object:nil];
	[nc addObserver:self selector:@selector(autoCollapseFolder:) name:@"MA_Notify_AutoCollapseFolder" object:nil];
	[nc addObserver:self selector:@selector(handleFolderFontChange:) name:@"MA_Notify_FolderFontChange" object:nil];
	[nc addObserver:self selector:@selector(handleRefreshStatusChange:) name:@"MA_Notify_RefreshStatus" object:nil];
	
	// Our folders have images next to them.
	tableColumn = [outlineView tableColumnWithIdentifier:@"folderColumns"];
	imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	[tableColumn setDataCell:imageAndTextCell];

	// Create and set whatever font we're using for the folders
	[self setFolderListFont];

	// Set header
	[folderHeader setStringValue:NSLocalizedString(@"Folders", nil)];

	// Dynamically create the popup menu. This is one less thing to
	// explicitly localise in the NIB file.
	NSMenu * folderMenu = [[NSMenu alloc] init];
	[folderMenu addItem:copyOfMenuWithAction(@selector(refreshSelectedSubscriptions:))];
	[folderMenu addItem:[NSMenuItem separatorItem]];
	[folderMenu addItem:copyOfMenuWithAction(@selector(editFolder:))];
	[folderMenu addItem:copyOfMenuWithAction(@selector(deleteFolder:))];
	[folderMenu addItem:copyOfMenuWithAction(@selector(renameFolder:))];
	[folderMenu addItem:[NSMenuItem separatorItem]];
	[folderMenu addItem:copyOfMenuWithAction(@selector(markAllRead:))];
	[folderMenu addItem:[NSMenuItem separatorItem]];
	[folderMenu addItem:copyOfMenuWithAction(@selector(viewSourceHomePage:))];
	[folderMenu addItem:copyOfMenuWithAction(@selector(validateFeed:))];

	// Want tooltips
	[outlineView setEnableTooltips:YES];
	[popupMenu setToolTip:NSLocalizedString(@"Additional actions for the selected folder", nil)];
	[newSubButton setToolTip:NSLocalizedString(@"Create a new subscription", nil)];
	[refreshButton setToolTip:NSLocalizedString(@"Refresh all your subscriptions", nil)];

	// Allow double-click a node to edit the node
	[outlineView setDoubleAction:@selector(handleDoubleClick:)];
	[outlineView setTarget:self];

	// Don't resize the column when items are expanded as this messes up
	// the placement of the unread count button.
	[outlineView setAutoresizesOutlineColumn:NO];

	// Set the menu for the popup button
	[popupMenu setMenu:folderMenu];
	[outlineView setMenu:folderMenu];
	[folderMenu release];

	// Register for dragging
	[outlineView registerForDraggedTypes:[NSArray arrayWithObjects:MA_PBoardType_FolderList, MA_PBoardType_RSSSource, nil]]; 
	[outlineView setVerticalMotionCanBeginDrag:YES];
}

/* setController
 * Sets the controller used by this view.
 */
-(void)setController:(AppController *)theController
{
	controller = theController;
	db = [[controller database] retain];
}

/* initialiseFoldersTree
 * Do the things to initialize the folder tree from the database
 */
-(void)initialiseFoldersTree
{
	blockSelectionHandler = YES;
	[self reloadDatabase:[[NSUserDefaults standardUserDefaults] arrayForKey:MAPref_FolderStates]];
	blockSelectionHandler = NO;
}

/* handleFolderFontChange
 * Called when the user changes the folder font and/or size in the Preferences
 */
-(void)handleFolderFontChange:(NSNotification *)note
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
	cellFont = [NSFont fontWithName:[prefs folderListFont] size:[prefs folderListFontSize]];
	boldCellFont = [[NSFontManager sharedFontManager] convertWeight:YES ofFont:cellFont];
	
	height = [boldCellFont defaultLineHeightForFont];
	[outlineView setRowHeight:height + 3];
}

/* reloadDatabase
 * Refresh the folders tree and restore the specified archived state
 */
-(void)reloadDatabase:(NSArray *)stateArray
{
	[rootNode removeChildren];
	[self loadTree:[db arrayOfFolders:MA_Root_Folder] rootNode:rootNode];
	[outlineView reloadData];
	[self unarchiveState:stateArray];
}

/* saveFolderSettings
 * Preserve the expanded/collapsed and selection state of the folders list
 * into the user's preferences.
 */
-(void)saveFolderSettings
{
	[[NSUserDefaults standardUserDefaults] setObject:[self archiveState] forKey:MAPref_FolderStates];
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
			NSDictionary * newDict = [[NSMutableDictionary alloc] init];
			[newDict setValue:[NSNumber numberWithInt:[node nodeId]] forKey:@"NodeID"];
			[newDict setValue:[NSNumber numberWithBool:isItemExpanded] forKey:@"ExpandedState"];
			[newDict setValue:[NSNumber numberWithBool:isItemSelected] forKey:@"SelectedState"];
			[archiveArray addObject:newDict];
			[newDict release];
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
	NSEnumerator * enumerator = [stateArray objectEnumerator];
	NSDictionary * dict;
	
	while ((dict = [enumerator nextObject]) != nil)
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
				[outlineView selectRow:[outlineView rowForItem:node] byExtendingSelection:YES];
		}
	}
	[outlineView sizeToFit];
}

/* loadTree
 * Recursive routine that populates the folder list
 */
-(void)loadTree:(NSArray *)listOfFolders rootNode:(TreeNode *)node
{
	NSEnumerator * enumerator = [listOfFolders objectEnumerator];
	Folder * folder;

	while ((folder = [enumerator nextObject]) != nil)
	{
		int itemId = [folder itemId];
		NSArray * listOfSubFolders = [db arrayOfFolders:itemId];
		int count = [listOfSubFolders count];
		TreeNode * subNode;

		subNode = [[TreeNode alloc] init:node folder:folder canHaveChildren:(count > 0)];
		if (count)
			[self loadTree:listOfSubFolders rootNode:subNode];
	}	
}

/* folders
 * Returns an array that contains the specified folder and all
 * sub-folders.
 */
-(NSArray *)folders:(int)folderId
{
	NSMutableArray * array = [NSMutableArray array];
	TreeNode * node;
	if (!folderId)
		node = rootNode;
	else
		node = [rootNode nodeFromID:folderId];
	
	if ([node folder] != nil)
		[array addObject:[node folder]];
	node = [node firstChild];
	while (node != nil)
	{
		[array addObjectsFromArray:[self folders:[node nodeId]]];
		node = [node nextChild];
	}
	return array;
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
		[outlineView selectRow:rowIndex byExtendingSelection:NO];
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

/* nextFolderWithUnread
 * Finds the ID of the next folder after currentFolderId that has
 * unread articles.
 */
-(int)nextFolderWithUnread:(int)currentFolderId
{
	TreeNode * thisNode = [rootNode nodeFromID:currentFolderId];
	TreeNode * node = thisNode;

	while (node != nil)
	{
		TreeNode * nextNode;
		TreeNode * parentNode = [node parentNode];
		nextNode = [node firstChild];
		if (nextNode == nil)
			nextNode = [node nextChild];
		while (nextNode == nil && parentNode != nil)
		{
			nextNode = [parentNode nextChild];
			parentNode = [parentNode parentNode];
		}
		if (nextNode == nil)
			nextNode = rootNode;

		if (([[nextNode folder] childUnreadCount]) && ![outlineView isItemExpanded:nextNode])
			return [nextNode nodeId];
		
		if ([[nextNode folder] unreadCount])
			return [nextNode nodeId];

		// If we've gone full circle and not found
		// anything, we're out of unread articles
		if (nextNode == thisNode)
			return [thisNode nodeId];

		node = nextNode;
	}
	return -1;
}

/* groupParentSelection
 * If the selected folder is a group folder, it returns the ID of the group folder
 * otherwise it returns the ID of the parent folder.
 */
-(int)groupParentSelection
{
	Folder * folder = [db folderFromID:[self actualSelection]];
	return folder ? ((IsGroupFolder(folder)) ? [folder itemId] : [folder parentId]) : MA_Root_Folder;
}

/* actualSelection
 * Return the index of the primary selected row in the folder list.
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
	int count = [rowIndexes count];
	int index;
	
	// Make a mutable array
	NSMutableArray * arrayOfSelectedFolders = [NSMutableArray arrayWithCapacity:count];

	// Get the indexes into a buffer
	unsigned int * buf = (unsigned int *)malloc(count * sizeof(unsigned int));
	if (buf != 0)
	{
		NSRange range = NSMakeRange([rowIndexes firstIndex], [rowIndexes lastIndex]);
		count = [rowIndexes getIndexes:buf maxCount:count inIndexRange:&range];

		for (index = 0; index < count; ++index)
		{
			TreeNode * node = [outlineView itemAtRow:buf[index]];
			[arrayOfSelectedFolders addObject:[node folder]];
		}
		free(buf);
	}
	return arrayOfSelectedFolders;
}

/* outlineViewMenuInvoked
 * Called when the popup menu is opened on the folder list. We move the
 * selection to whichever node is under the cursor so the context between
 * the menu items and the node is made clear.
 */
-(void)outlineViewMenuInvoked:(NSNotification *)nc
{
	// Find the row under the cursor when the user clicked
	NSEvent * theEvent = [nc object];
	int row = [outlineView rowAtPoint:[outlineView convertPoint:[theEvent locationInWindow] fromView:nil]];
	if (row >= 0)
	{
		// Select the row under the cursor if it isn't already selected
		if ([outlineView numberOfSelectedRows] <= 1)
			[outlineView selectRow:row byExtendingSelection:NO];
	}
}

/* handleRefreshStatusChange
 * Handle a change of the refresh status. We use this to toggle the behaviour of
 * the button between starting and stopping a refresh.
 */
-(void)handleRefreshStatusChange:(NSNotification *)nc
{
	if ([NSApp isRefreshing])
	{
		[refreshButton setAction:@selector(cancelAllRefreshes:)];
		[refreshButton setImage:[NSImage imageNamed:@"stopRefresh.tiff"]];
	}
	else
	{
		[refreshButton setAction:@selector(refreshAllSubscriptions:)];
		[refreshButton setImage:[NSImage imageNamed:@"refresh.tiff"]];
	}
}

/* handleDoubleClick
 * If the user double-clicks a node, send an edit notification.
 */
-(void)handleDoubleClick:(id)sender
{
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	TreeNode * node = [outlineView itemAtRow:[outlineView selectedRow]];

	if (IsRSSFolder([node folder]))
	{
		NSString * urlString = [[node folder] homePage];
		if (urlString && ![urlString isBlank])
			[[NSApp delegate] openURLInBrowser:urlString];
	}
	else
		[nc postNotificationName:@"MA_Notify_EditFolder" object:node];
}

/* handleFolderDeleted
 * Called whenever a folder is removed from the database. We need
 * to delete the associated tree nodes then select the next node, or
 * the previous one if we were at the bottom of the list.
 */
-(void)handleFolderDeleted:(NSNotification *)nc
{
	int currentFolderId = [self actualSelection];
	int folderId = [(NSNumber *)[nc object] intValue];
	TreeNode * thisNode = [rootNode nodeFromID:folderId];
	TreeNode * nextNode;

	// First find the next node we'll select
	if ([thisNode nextChild] != nil)
		nextNode = [thisNode nextChild];
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
	[[TreeNode alloc] init:node folder:newFolder canHaveChildren:NO];
	[self reloadFolderItem:node reloadChildren:YES];
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
		if ([[node folder] childUnreadCount])
			return [NSString stringWithFormat:NSLocalizedString(@"%d unread articles", nil), [[node folder] childUnreadCount]];
	}
	return nil;
}

/* objectValueForTableColumn
 * Returns the actual string that is displayed in the cell. Folders that have child folders with unread
 * articles show the aggregate unread article count.
 */
-(id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node == nil)
		node = rootNode;
	return [node nodeName];
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
		ImageAndTextCell * realCell = (ImageAndTextCell *)cell;

		[realCell setTextColor:([olv isRowSelected:[olv rowForItem:item]]) ? [NSColor whiteColor] : [NSColor blackColor]];
		if (IsSmartFolder([node folder]))  // Because if the search results contain unread articles we don't want the smart folder name to be bold.
		{
			[realCell clearCount];
			[realCell setFont:cellFont];
		}
		else if ([[node folder] unreadCount])
		{
			[realCell setFont:boldCellFont];
			[realCell setCount:[[node folder] unreadCount]];
			[realCell setCountBackgroundColour:[NSColor colorForControlTint:[NSColor currentControlTint]]];
		}
		else if ([[node folder] childUnreadCount] && ![olv isItemExpanded:item])
		{
			[realCell setFont:boldCellFont];
			[realCell setCount:[[node folder] childUnreadCount]];
			[realCell setCountBackgroundColour:[NSColor colorForControlTint:[NSColor currentControlTint]]];
		}
		else
		{
			[realCell clearCount];
			[realCell setFont:cellFont];
		}
		[realCell setImage:[[node folder] image]];
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
	if (!blockSelectionHandler)
	{
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		TreeNode * node = [outlineView itemAtRow:[outlineView selectedRow]];
		[nc postNotificationName:@"MA_Notify_FolderSelectionChange" object:node];
	}
}

/* validateDrop
 * Called when something is being dragged over us. We respond with an NSDragOperation value indicating the
 * feedback for the user given where we are.
 */
-(NSDragOperation)outlineView:(NSOutlineView*)olv validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index
{
	NSPasteboard * pb = [info draggingPasteboard]; 
	NSString * type = [pb availableTypeFromArray:[NSArray arrayWithObjects:MA_PBoardType_FolderList, MA_PBoardType_RSSSource, nil]]; 
	NSDragOperation dragType = (type == MA_PBoardType_FolderList) ? NSDragOperationMove : NSDragOperationCopy;

	TreeNode * node = (TreeNode *)item;
	BOOL isOnDropTypeProposal = index == NSOutlineViewDropOnItemIndex;

	// Can't drop anything onto the trash folders.
	if (isOnDropTypeProposal && node != nil && IsTrashFolder([node folder]))
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
	int index;

	// We'll create two types of data on the clipboard.
	[pboard declareTypes:[NSArray arrayWithObjects:MA_PBoardType_FolderList, MA_PBoardType_RSSSource, NSStringPboardType, nil] owner:self]; 

	// Create an array of NSNumber objects containing the selected folder IDs.
	int countOfItems = 0;
	for (index = 0; index < count; ++index)
	{
		TreeNode * node = [items objectAtIndex:index];
		Folder * folder = [node folder];

		if (IsRSSFolder(folder) || IsSmartFolder(folder) || IsGroupFolder(folder))
		{
			[internalDragData addObject:[NSNumber numberWithInt:[node nodeId]]];
			++countOfItems;
		}

		if (IsRSSFolder(folder))
		{
			NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
			[dict setValue:[folder name] forKey:@"sourceName"];
			[dict setValue:[folder description] forKey:@"sourceDescription"];
			[dict setValue:[folder feedURL] forKey:@"sourceRSSURL"];
			[dict setValue:[folder homePage] forKey:@"sourceHomeURL"];
			[externalDragData addObject:dict];
			[dict release];

			[stringDragData appendString:[folder feedURL]];
			[stringDragData appendString:@"\n"];
		}
	}

	// Copy the data to the pasteboard 
	[pboard setPropertyList:externalDragData forType:MA_PBoardType_RSSSource];
	[pboard setString:stringDragData forType:NSStringPboardType];
	[pboard setPropertyList:internalDragData forType:MA_PBoardType_FolderList]; 
	return countOfItems > 0; 
}

/* moveFoldersUndo
 * Undo handler to move folders back.
 */
-(void)moveFoldersUndo:(id)anObject
{
	[self moveFolders:(NSArray *)anObject];
}

/* moveFolders
 * Reparent folders using the information in the specified array. The array consists of
 * a collection of NSNumber pairs: the first number if the ID of the folder to move and
 * the second number is the ID of the parent to which the folder should be moved.
 */
-(void)moveFolders:(NSArray *)array
{
	NSAssert(([array count] & 1) == 0, @"Incorrect number of items in array passed to moveFolders");
	int count = [array count];
	int index = 0;

	// Need to create a running undo array
	NSMutableArray * undoArray = [[NSMutableArray alloc] initWithCapacity:count];

	// Internal drag and drop so we're just changing the parent IDs around. One thing
	// we have to watch for is to make sure that we don't re-parent to a subordinate
	// folder.
	while (index < count)
	{
		int folderId = [[array objectAtIndex:index++] intValue];
		int newParentId = [[array objectAtIndex:index++] intValue];
		Folder * folder = [db folderFromID:folderId];
		int oldParentId = [folder parentId];
		
		TreeNode * node = [rootNode nodeFromID:folderId];
		TreeNode * oldParent = [rootNode nodeFromID:oldParentId];
		TreeNode * newParent = [rootNode nodeFromID:newParentId];

		if (![newParent canHaveChildren])
			[newParent setCanHaveChildren:YES];
		
		[db setParent:newParentId forFolder:folderId];
		[node retain];
		[oldParent removeChild:node andChildren:NO];
		[newParent addChild:node];
		[node release];
		
		[undoArray addObject:[NSNumber numberWithInt:folderId]];
		[undoArray addObject:[NSNumber numberWithInt:oldParentId]];
	}

	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	[undoManager registerUndoWithTarget:self selector:@selector(moveFoldersUndo:) object:undoArray];
	[undoManager setActionName:NSLocalizedString(@"Move Folders", nil)];
	[undoArray release];
	
	// Make the outline control reload its data
	[outlineView reloadData];

	// If any parent was a collapsed group, expand it now
	for (index = 0; index < count; ++index)
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
	for (index = 0; index < count; ++index)
	{
		int folderId = [[array objectAtIndex:index++] intValue];
		int rowIndex = [outlineView rowForItem:[rootNode nodeFromID:folderId]];
		selRowIndex = MIN(selRowIndex, rowIndex);
		[selIndexSet addIndex:rowIndex];
	}
	[outlineView scrollRowToVisible:selRowIndex];
	[outlineView selectRowIndexes:selIndexSet byExtendingSelection:NO];
	[selIndexSet release];
}

/* acceptDrop
 * Accept a drop on or between nodes either from within the folder view or from outside.
 */
-(BOOL)outlineView:(NSOutlineView *)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)targetItem childIndex:(int)childIndex
{ 
	NSPasteboard * pb = [info draggingPasteboard]; 
	NSString * type = [pb availableTypeFromArray:[NSArray arrayWithObjects:MA_PBoardType_FolderList, MA_PBoardType_RSSSource, nil]]; 

	// Get index of folder at drop location. If this is a group folder then
	// it gets used as the parent
	TreeNode * node = targetItem ? (TreeNode *)targetItem : rootNode;
	if (childIndex != NSOutlineViewDropOnItemIndex)
	{
		if (childIndex >= [node countOfChildren])
			childIndex = [node countOfChildren] - 1;
		NSAssert(childIndex >= 0, @"childIndex not expected to go < 0 at this point");
		node = [node childByIndex:childIndex];
	}

	int parentID = (IsGroupFolder([node folder])) ? [[node folder] itemId] : [[node folder] parentId];

	// Check the type 
	if (type == MA_PBoardType_FolderList)
	{
		NSArray * arrayOfSources = [pb propertyListForType:type];
		int count = [arrayOfSources count];
		int index;

		// Create an NSArray of pairs (folderId, newParentId) that will be passed to moveFolders
		// to do the actual move.
		NSMutableArray * array = [[NSMutableArray alloc] initWithCapacity:count * 2];
		for (index = 0; index < count; ++index)
		{
			int folderId = [[arrayOfSources objectAtIndex:index] intValue];
			[array addObject:[NSNumber numberWithInt:folderId]];
			[array addObject:[NSNumber numberWithInt:parentID]];
		}

		// Do the move
		[self moveFolders:array];
		[array release];
		return YES;
	}
	if (type == MA_PBoardType_RSSSource)
	{
		NSArray * arrayOfSources = [pb propertyListForType:type];
		int count = [arrayOfSources count];
		int index;
		
		// This is an RSS drag using the protocol defined by Ranchero for NetNewsWire. See
		// http://ranchero.com/netnewswire/rssclipboard.php for more details.
		//
		for (index = 0; index < count; ++index)
		{
			NSDictionary * sourceItem = [arrayOfSources objectAtIndex:index];
			NSString * feedTitle = [sourceItem valueForKey:@"sourceName"];
			NSString * feedHomePage = [sourceItem valueForKey:@"sourceHomeURL"];
			NSString * feedURL = [sourceItem valueForKey:@"sourceRSSURL"];
			NSString * feedDescription = [sourceItem valueForKey:@"sourceDescription"];

			if ((feedURL != nil) && [db folderFromFeedURL:feedURL] == nil)
			{
				int folderId = [db addRSSFolder:feedTitle underParent:parentID subscriptionURL:feedURL];
				if (feedDescription != nil)
					[db setFolderDescription:folderId newDescription:feedDescription];
				if (feedHomePage != nil)
					[db setFolderHomePage:folderId newHomePage:feedHomePage];
			}
		}

		// If parent was a group, expand it now
		if (parentID != MA_Root_Folder)
			[outlineView expandItem:[rootNode nodeFromID:parentID]];
		return YES;
	}
	return NO; 
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self];
	[db release];
	[cellFont release];
	[boldCellFont release];
	[rootNode release];
	[super dealloc];
}
@end
