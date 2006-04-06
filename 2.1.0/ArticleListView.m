//
//  ArticleListView.m
//  Vienna
//
//  Created by Steve on 8/27/05.
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

#import "ArticleListView.h"
#import "Preferences.h"
#import "Constants.h"
#import "AppController.h"
#import "SplitViewExtensions.h"
#import "MessageListView.h"
#import "ArticleView.h"
#import "FoldersTree.h"
#import "CalendarExtensions.h"
#import "StringExtensions.h"
#import "HelperFunctions.h"
#import "ArticleRef.h"
#import "ArticleFilter.h"
#import "XMLParser.h"
#import "WebKit/WebFrame.h"
#import "WebKit/WebUIDelegate.h"
#import "WebKit/WebDataSource.h"
#import "WebKit/WebFrameView.h"
#import "WebKit/WebBackForwardList.h"

// Private functions
@interface ArticleListView (Private)
	-(void)setArticleListHeader;
	-(void)initTableView;
	-(BOOL)initForStyle:(NSString *)styleName;
	-(BOOL)copyTableSelection:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard;
	-(BOOL)currentCacheContainsFolder:(int)folderId;
	-(void)setTableViewFont;
	-(void)showSortDirection;
	-(void)setSortColumnIdentifier:(NSString *)str;
	-(void)selectArticleAfterReload;
	-(void)handleFolderNameChange:(NSNotification *)nc;
	-(void)handleFolderUpdate:(NSNotification *)nc;
	-(void)handleStyleChange:(NSNotificationCenter *)nc;
	-(void)handleReadingPaneChange:(NSNotificationCenter *)nc;
	-(BOOL)scrollToArticle:(NSString *)guid;
	-(void)selectFirstUnreadInFolder;
	-(void)makeRowSelectedAndVisible:(int)rowIndex;
	-(BOOL)viewNextUnreadInCurrentFolder:(int)currentRow;
	-(void)loadMinimumFontSize;
	-(void)markCurrentRead:(NSTimer *)aTimer;
	-(void)refreshImmediatelyArticleAtCurrentRow;
	-(void)refreshArticleAtCurrentRow:(BOOL)delayFlag;
	-(NSArray *)wrappedMarkAllReadInArray:(NSArray *)folderArray withUndo:(BOOL)undoFlag needRefresh:(BOOL *)needRefreshPtr;
	-(void)innerMarkReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag;
	-(void)reloadArrayOfArticles;
	-(NSArray *)applyFilter:(NSArray *)unfilteredArray;
	-(void)refreshArticlePane;
	-(void)updateArticleListRowHeight;
	-(void)setOrientation:(BOOL)flag;
	-(void)fixupRelativeImgTags:(NSMutableString *)text baseURL:(NSString *)baseURL;
	-(void)printDocument;
@end

static const int MA_Minimum_ArticleList_Pane_Width = 80;
static const int MA_Minimum_Article_Pane_Width = 80;

@implementation ArticleListView

/* initWithFrame
 * Initialise our view.
 */
-(id)initWithFrame:(NSRect)frame
{
    if (([super initWithFrame:frame]) != nil)
	{
		db = nil;
		isBacktracking = NO;
		isChangingOrientation = NO;
		isInTableInit = NO;
		blockSelectionHandler = NO;
		blockMarkRead = NO;
		guidOfArticleToSelect = nil;
		stylePathMappings = nil;
		markReadTimer = nil;
		selectionTimer = nil;
		htmlTemplate = nil;
		cssStylesheet = nil;
    }
    return self;
}

/* awakeFromNib
 * Do things that only make sense once the NIB is loaded.
 */
-(void)awakeFromNib
{
	// Set default values to generate article sort descriptors
	articleSortSpecifiers = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"containingFolder.name", @"key",
			@"compare:", @"selector",
			nil], MA_Field_Folder,
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"isRead", @"key",
			@"compare:", @"selector",
			nil], MA_Field_Read,
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"isFlagged", @"key",
			@"compare:", @"selector",
			nil], MA_Field_Flagged,
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"hasComments", @"key",
			@"compare:", @"selector",
			nil], MA_Field_Comments,
		[NSDictionary dictionaryWithObjectsAndKeys:
			[@"articleData." stringByAppendingString:MA_Field_Date], @"key",
			@"compare:", @"selector",
			nil], MA_Field_Date,
		[NSDictionary dictionaryWithObjectsAndKeys:
			[@"articleData." stringByAppendingString:MA_Field_Author], @"key",
			@"caseInsensitiveCompare:", @"selector",
			nil], MA_Field_Author,
		[NSDictionary dictionaryWithObjectsAndKeys:
			[@"articleData." stringByAppendingString:MA_Field_Subject], @"key",
			@"numericCompare:", @"selector",
			nil], MA_Field_Headlines,
		[NSDictionary dictionaryWithObjectsAndKeys:
			[@"articleData." stringByAppendingString:MA_Field_Subject], @"key",
			@"numericCompare:", @"selector",
			nil], MA_Field_Subject,
		[NSDictionary dictionaryWithObjectsAndKeys:
			[@"articleData." stringByAppendingString:MA_Field_Link], @"key",
			@"caseInsensitiveCompare:", @"selector",
			nil], MA_Field_Link,
		[NSDictionary dictionaryWithObjectsAndKeys:
			[@"articleData." stringByAppendingString:MA_Field_Summary], @"key",
			@"caseInsensitiveCompare:", @"selector",
			nil], MA_Field_Summary,
		nil];
	
	// Register to be notified when folders are added or removed
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleArticleListFontChange:) name:@"MA_Notify_ArticleListFontChange" object:nil];
	[nc addObserver:self selector:@selector(handleStyleChange:) name:@"MA_Notify_StyleChange" object:nil];
	[nc addObserver:self selector:@selector(handleReadingPaneChange:) name:@"MA_Notify_ReadingPaneChange" object:nil];
	[nc addObserver:self selector:@selector(handleFolderUpdate:) name:@"MA_Notify_FoldersUpdated" object:nil];
	[nc addObserver:self selector:@selector(handleFolderNameChange:) name:@"MA_Notify_FolderNameChanged" object:nil];
	[nc addObserver:self selector:@selector(handleFilterChange:) name:@"MA_Notify_FilteringChange" object:nil];

	// Create a backtrack array
	Preferences * prefs = [Preferences standardPreferences];
	backtrackArray = [[BackTrackArray alloc] initWithMaximum:[prefs backTrackQueueSize]];

	// Set header text
	[articleListHeader setStringValue:NSLocalizedString(@"Articles", nil)];

	// Make us the frame load and UI delegate for the web view
	[articleText setUIDelegate:self];
	[articleText setFrameLoadDelegate:self];
	[articleText setOpenLinksInNewBrowser:YES];
	
	// Disable caching
	[articleText setMaintainsBackForwardList:NO];
	[[articleText backForwardList] setPageCacheSize:0];

	// Do safe initialisation
	[controller doSafeInitialisation];
}

/* setController
 * Sets the controller used by this view.
 */
-(void)setController:(AppController *)theController
{
	controller = theController;
	db = [[controller database] retain];
	[articleText setController:controller];
}

/* initialiseArticleView
 * Do the things to initialise the article view from the database. This is the
 * only point during initialisation where the database is guaranteed to be
 * ready for use.
 */
-(void)initialiseArticleView
{
	Preferences * prefs = [Preferences standardPreferences];

	// Mark the start of the init phase
	isAppInitialising = YES;
	
	// Create condensed view attribute dictionaries
	selectionDict = [[NSMutableDictionary alloc] init];
	topLineDict = [[NSMutableDictionary alloc] init];
	middleLineDict = [[NSMutableDictionary alloc] init];
	linkLineDict = [[NSMutableDictionary alloc] init];
	bottomLineDict = [[NSMutableDictionary alloc] init];
	
	// Set the reading pane orientation
	[self setOrientation:[prefs readingPaneOnRight]];
	
	// Initialise the article list view
	[self initTableView];

	// Select the user's current style or revert back to the
	// default style otherwise.
	[self initForStyle:[prefs displayStyle]];

	// Restore the split bar position
	[splitView2 setLayout:[prefs objectForKey:@"SplitView2Positions"]];
	[splitView2 setDelegate:self];

	// Select the first conference
	int previousFolderId = [prefs integerForKey:MAPref_CachedFolderID];
	NSString * previousArticleGuid = [prefs stringForKey:MAPref_CachedArticleGUID];
	if ([previousArticleGuid isBlank])
		previousArticleGuid = nil;
	[self selectFolderAndArticle:previousFolderId guid:previousArticleGuid];
	
	// Done initialising
	isAppInitialising = NO;
}

/* constrainMinCoordinate
 * Make sure the article pane width isn't shrunk beyond a minimum width. Otherwise it looks
 * untidy.
 */
-(float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return (sender == splitView2 && offset == 0) ? MA_Minimum_ArticleList_Pane_Width : proposedMin;
}

/* constrainMaxCoordinate
 * Make sure that the article pane isn't shrunk beyond a minimum size otherwise the splitview
 * or controls within it start resizing odd.
 */
-(float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	if (sender == splitView2 && offset == 0)
	{
		NSRect mainFrame = [[splitView2 superview] frame];
		return (tableLayout == MA_Condensed_Layout) ?
			mainFrame.size.width - MA_Minimum_Article_Pane_Width :
			mainFrame.size.height - MA_Minimum_Article_Pane_Width;
	}
	return proposedMax;
}

/* resizeSubviewsWithOldSize
 * Constrain the article list pane to a fixed width.
 */
-(void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	float dividerThickness = [sender dividerThickness];
	id sv1 = [[sender subviews] objectAtIndex:0];
	id sv2 = [[sender subviews] objectAtIndex:1];
	NSRect leftFrame = [sv1 frame];
	NSRect rightFrame = [sv2 frame];
	NSRect newFrame = [sender frame];
	
	if (sender == splitView2)
	{
		if (isChangingOrientation)
			[splitView2 adjustSubviews];
		else
		{
			leftFrame.origin = NSMakePoint(0, 0);
			if (tableLayout == MA_Condensed_Layout)
			{
				leftFrame.size.height = newFrame.size.height;
				rightFrame.size.width = newFrame.size.width - leftFrame.size.width - dividerThickness;
				rightFrame.size.height = newFrame.size.height;
				rightFrame.origin.x = leftFrame.size.width + dividerThickness;
			}
			else
			{
				leftFrame.size.width = newFrame.size.width;
				rightFrame.size.height = newFrame.size.height - leftFrame.size.height - dividerThickness;
				rightFrame.size.width = newFrame.size.width;
				rightFrame.origin.y = leftFrame.size.height + dividerThickness;
			}
			[sv1 setFrame:leftFrame];
			[sv2 setFrame:rightFrame];
		}
	}
}

/* createWebViewWithRequest
 * Called when the browser wants to create a new window. The request is opened in a new tab.
 */
-(WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	[controller openURL:[request URL] inPreferredBrowser:YES];
	// Change this to handle modifier key?
	// Is this covered by the webView policy?
	return nil;
}

/* setStatusText
 * Called from the webview when some JavaScript writes status text. Echo this to
 * our status bar.
 */
-(void)webView:(WebView *)sender setStatusText:(NSString *)text
{
	[controller setStatusMessage:text persist:NO];
}

/* mouseDidMoveOverElement
 * Called from the webview when the user positions the mouse over an element. If it's a link
 * then echo the URL to the status bar like Safari does.
 */
-(void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(unsigned int)modifierFlags
{
	NSURL * url = [elementInformation valueForKey:@"WebElementLinkURL"];
	[controller setStatusMessage:(url ? [url absoluteString] : @"") persist:NO];
}

/* contextMenuItemsForElement
 * Creates a new context menu for our web view.
 */
-(NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSURL * urlLink = [element valueForKey:WebElementLinkURLKey];
	return (urlLink != nil) ? [controller contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:defaultMenuItems] : nil;
}

/* initTableView
 * Do all the initialization for the article list table view control
 */
-(void)initTableView
{
	Preferences * prefs = [Preferences standardPreferences];
	
	// Variable initialization here
	currentFolderId = -1;
	currentArrayOfArticles = nil;
	folderArrayOfArticles = nil;
	currentSelectedRow = -1;
	articleListFont = nil;

	// Pre-set sort to what was saved in the preferences
	NSArray * sortDescriptors = [prefs articleSortDescriptors];
	if ([sortDescriptors count] == 0)
	{
		NSSortDescriptor * descriptor = [[[NSSortDescriptor alloc] initWithKey:[@"articleData." stringByAppendingString:MA_Field_Date] ascending:NO] autorelease];
		[prefs setArticleSortDescriptors:[NSArray arrayWithObject:descriptor]];
		[prefs setObject:MA_Field_Date forKey:MAPref_SortColumn];
	}
	[self setSortColumnIdentifier:[prefs stringForKey:MAPref_SortColumn]];
	
	// Initialize the article columns from saved data
	NSArray * dataArray = [prefs arrayForKey:MAPref_ArticleListColumns];
	Field * field;
	unsigned int index;
	
	for (index = 0; index < [dataArray count];)
	{
		NSString * name;
		int width = 100;
		BOOL visible = NO;
		
		name = [dataArray objectAtIndex:index++];
		if (index < [dataArray count])
			visible = [[dataArray objectAtIndex:index++] intValue] == YES;
		if (index < [dataArray count])
			width = [[dataArray objectAtIndex:index++] intValue];
		
		field = [db fieldByName:name];
		[field setVisible:visible];
		[field setWidth:width];
	}
	
	// Get the default list of visible columns
	[self updateVisibleColumns];
	
	// Dynamically create the popup menu. This is one less thing to
	// explicitly localise in the NIB file.
	NSMenu * articleListMenu = [[NSMenu alloc] init];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(markRead:))];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(markFlagged:))];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(deleteMessage:))];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(restoreMessage:))];
	[articleListMenu addItem:[NSMenuItem separatorItem]];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(viewSourceHomePage:))];
	NSMenuItem * alternateItem = copyOfMenuWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	[alternateItem setKeyEquivalentModifierMask:NSShiftKeyMask];
	[alternateItem setAlternate:YES];
	[articleListMenu addItem:alternateItem];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(viewArticlePage:))];
	alternateItem = copyOfMenuWithAction(@selector(viewArticlePageInAlternateBrowser:));
	[alternateItem setKeyEquivalentModifierMask:NSShiftKeyMask];
	[alternateItem setAlternate:YES];
	[articleListMenu addItem:alternateItem];
	[articleList setMenu:articleListMenu];
	[articleListMenu release];

	// Set the target for double-click actions
	[articleList setDoubleAction:@selector(doubleClickRow:)];
	[articleList setAction:@selector(singleClickRow:)];
	[articleList setDelegate:self];
	[articleList setDataSource:self];
	[articleList setTarget:self];

	// Set the default fonts
	[self setTableViewFont];
}

/* singleClickRow
 * Handle a single click action. If the click was in the read or flagged column then
 * treat it as an action to mark the article read/unread or flagged/unflagged. Later
 * trap the comments column and expand/collapse.
 */
-(IBAction)singleClickRow:(id)sender
{
	int row = [articleList clickedRow];
	int column = [articleList clickedColumn];
	if (row >= 0 && row < (int)[currentArrayOfArticles count])
	{
		NSArray * columns = [articleList tableColumns];
		if (column >= 0 && column < (int)[columns count])
		{
			Article * theArticle = [currentArrayOfArticles objectAtIndex:row];
			NSString * columnName = [(NSTableColumn *)[columns objectAtIndex:column] identifier];
			if ([columnName isEqualToString:MA_Field_Read])
			{
				[self markReadByArray:[NSArray arrayWithObject:theArticle] readFlag:![theArticle isRead]];
				return;
			}
			if ([columnName isEqualToString:MA_Field_Flagged])
			{
				[self markFlaggedByArray:[NSArray arrayWithObject:theArticle] flagged:![theArticle isFlagged]];
				return;
			}
		}
	}
}

/* doubleClickRow
 * Handle double-click on the selected article. Open the original feed item in
 * the default browser.
 */
-(IBAction)doubleClickRow:(id)sender
{
	if (currentSelectedRow != -1 && [articleList clickedRow] != -1)
	{
		Article * theArticle = [currentArrayOfArticles objectAtIndex:currentSelectedRow];
		[controller openURLFromString:[theArticle link] inPreferredBrowser:YES];
	}
}

/* updateAlternateMenuTitle
 * Sets the approprate title for the alternate item in the contextual menu
 * when user changes preference for opening pages in external browser
 */
-(void)updateAlternateMenuTitle
{
	NSMenuItem * mainMenuItem;
	NSMenuItem * contextualMenuItem;
	int index;
	NSMenu * articleListMenu = [articleList menu];
	if (articleListMenu == nil)
		return;
	mainMenuItem = menuWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	if (mainMenuItem != nil)
	{
		index = [articleListMenu indexOfItemWithTarget:nil andAction:@selector(viewSourceHomePageInAlternateBrowser:)];
		if (index >= 0)
		{
			contextualMenuItem = [articleListMenu itemAtIndex:index];
			[contextualMenuItem setTitle:[mainMenuItem title]];
		}
	}
	mainMenuItem = menuWithAction(@selector(viewArticlePageInAlternateBrowser:));
	if (mainMenuItem != nil)
	{
		index = [articleListMenu indexOfItemWithTarget:nil andAction:@selector(viewArticlePageInAlternateBrowser:)];
		if (index >= 0)
		{
			contextualMenuItem = [articleListMenu itemAtIndex:index];
			[contextualMenuItem setTitle:[mainMenuItem title]];
		}
	}
}

/* updateVisibleColumns
 * Iterates through the array of visible columns and makes them
 * visible or invisible as needed.
 */
-(void)updateVisibleColumns
{
	NSArray * fields = [db arrayOfFields];
	int count = [fields count];
	int index;

	// Mark we're doing an update of the tableview
	isInTableInit = YES;
	[articleList setAutoresizesAllColumnsToFit:NO];
	
	[self updateArticleListRowHeight];
	
	// Create the new columns
	for (index = 0; index < count; ++index)
	{
		Field * field = [fields objectAtIndex:index];
		NSString * identifier = [field name];
		int tag = [field tag];
		BOOL showField;
		
		// Remove each column as we go.
		NSTableColumn * tableColumn = [articleList tableColumnWithIdentifier:identifier];
		if (tableColumn != nil)
			[articleList removeTableColumn:tableColumn];
		
		// Handle condensed layout vs. table layout
		if (tableLayout == MA_Table_Layout)
			showField = [field visible] && tag != MA_FieldID_Headlines && tag != MA_FieldID_Comments;
		else
		{
			showField = NO;
			if (tag == MA_FieldID_Read || tag == MA_FieldID_Flagged)
				showField = [field visible];
			if (tag == MA_FieldID_Headlines)
				showField = YES;
		}

		// Add to the end only those columns that are visible
		if (showField)
		{
			NSTableColumn * newTableColumn = [[NSTableColumn alloc] initWithIdentifier:identifier];
			NSTableHeaderCell * headerCell = [newTableColumn headerCell];
			BOOL isResizable = (tag != MA_FieldID_Read && tag != MA_FieldID_Flagged && tag != MA_FieldID_Comments);

			// Fix for bug where tableviews with alternating background rows lose their "colour".
			// Only text cells are affected.
			if ([[newTableColumn dataCell] isKindOfClass:[NSTextFieldCell class]])
			{
				[[newTableColumn dataCell] setDrawsBackground:NO];
				[[newTableColumn dataCell] setWraps:YES];
			}

			[headerCell setTitle:[field displayName]];
			[newTableColumn setEditable:NO];
			[newTableColumn setResizable:isResizable];
			[newTableColumn setMinWidth:10];
			[newTableColumn setMaxWidth:1000];
			[newTableColumn setWidth:[field width]];
			[articleList addTableColumn:newTableColumn];
			[newTableColumn release];
		}
	}
	
	// Set the extended date formatter on the Date column
	NSTableColumn * tableColumn = [articleList tableColumnWithIdentifier:MA_Field_Date];
	if (tableColumn != nil)
	{
		if (extDateFormatter == nil)
			extDateFormatter = [[ExtDateFormatter alloc] init];
		[[tableColumn dataCell] setFormatter:extDateFormatter];
	}

	// Set the images for specific header columns
	[articleList setHeaderImage:MA_Field_Read imageName:@"unread_header.tiff"];
	[articleList setHeaderImage:MA_Field_Flagged imageName:@"flagged_header.tiff"];
	
	// Initialise the sort direction
	[self showSortDirection];	
	
	// In condensed mode, the summary field takes up the whole space
	if (tableLayout == MA_Condensed_Layout)
		[articleList setAutoresizesAllColumnsToFit:YES];
	
	// Done
	isInTableInit = NO;
}

/* saveTableSettings
 * Save the table column settings, specifically the visibility and width.
 */
-(void)saveTableSettings
{
	Preferences * prefs = [Preferences standardPreferences];
	NSArray * fields = [db arrayOfFields];
	NSEnumerator * enumerator = [fields objectEnumerator];
	Field * field;
	
	// Remember the current folder and article
	NSString * guid = (currentSelectedRow >= 0) ? [[currentArrayOfArticles objectAtIndex:currentSelectedRow] guid] : @"";
	[prefs setInteger:currentFolderId forKey:MAPref_CachedFolderID];
	[prefs setString:guid forKey:MAPref_CachedArticleGUID];

	// An array we need for the settings
	NSMutableArray * dataArray = [[NSMutableArray alloc] init];
	
	// Create the new columns
	while ((field = [enumerator nextObject]) != nil)
	{
		[dataArray addObject:[field name]];
		[dataArray addObject:[NSNumber numberWithBool:[field visible]]];
		[dataArray addObject:[NSNumber numberWithInt:[field width]]];
	}
	
	// Save these to the preferences
	[prefs setObject:dataArray forKey:MAPref_ArticleListColumns];

	// Save the split bar position
	[prefs setObject:[splitView2 layout] forKey:@"SplitView2Positions"];

	// We're done
	[dataArray release];
}

/* setTableViewFont
 * Gets the font for the article list and adjusts the table view
 * row height to properly display that font.
 */
-(void)setTableViewFont
{
	[articleListFont release];
	
	Preferences * prefs = [Preferences standardPreferences];
	articleListFont = [NSFont fontWithName:[prefs articleListFont] size:[prefs articleListFontSize]];

	NSMutableParagraphStyle * style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[style setLineBreakMode:NSLineBreakByTruncatingTail];
	
	[topLineDict setObject:articleListFont forKey:NSFontAttributeName];
	[topLineDict setObject:style forKey:NSParagraphStyleAttributeName];
	[topLineDict setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];

	[middleLineDict setObject:articleListFont forKey:NSFontAttributeName];
	[middleLineDict setObject:style forKey:NSParagraphStyleAttributeName];
	[middleLineDict setObject:[NSColor blueColor] forKey:NSForegroundColorAttributeName];
	
	[linkLineDict setObject:articleListFont forKey:NSFontAttributeName];
	[linkLineDict setObject:style forKey:NSParagraphStyleAttributeName];
	[linkLineDict setObject:self forKey:NSLinkAttributeName];
	[linkLineDict setObject:[NSColor blueColor] forKey:NSForegroundColorAttributeName];

	[bottomLineDict setObject:articleListFont forKey:NSFontAttributeName];
	[bottomLineDict setObject:style forKey:NSParagraphStyleAttributeName];
	[bottomLineDict setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];

	[selectionDict setObject:articleListFont forKey:NSFontAttributeName];
	[selectionDict setObject:style forKey:NSParagraphStyleAttributeName];
	[selectionDict setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];

	[self updateArticleListRowHeight];
	[style release];
}

/* updateArticleListRowHeight
 * Compute the number of rows that the current view requires. For table layout, there's just
 * one line. For condensed layout, the number of lines depends on which fields are visible but
 * there's always a minimum of one line anyway.
 */
-(void)updateArticleListRowHeight
{
	int height = [articleListFont defaultLineHeightForFont];
	int numberOfRowsInCell = 1;
	if (tableLayout == MA_Condensed_Layout)
	{
		if ([[db fieldByName:MA_Field_Subject] visible])
			++numberOfRowsInCell;
		if ([[db fieldByName:MA_Field_Link] visible])
			++numberOfRowsInCell;
		if ([[db fieldByName:MA_Field_Summary] visible])
			++numberOfRowsInCell;
	}
	[articleList setRowHeight:(height + 2) * numberOfRowsInCell];
}

/* showSortDirection
 * Shows the current sort column and direction in the table.
 */
-(void)showSortDirection
{
	NSTableColumn * sortColumn = [articleList tableColumnWithIdentifier:sortColumnIdentifier];
	NSString * imageName = ([[[[Preferences standardPreferences] articleSortDescriptors] objectAtIndex:0] ascending]) ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator";
	[articleList setHighlightedTableColumn:sortColumn];
	[articleList setIndicatorImage:[NSImage imageNamed:imageName] inTableColumn:sortColumn];
}

/* sortByIdentifier
 * Sort by the column indicated by the specified column name.
 */
-(void)sortByIdentifier:(NSString *)columnName
{
	Preferences * prefs = [Preferences standardPreferences];
	NSMutableArray * descriptors = [NSMutableArray arrayWithArray:[prefs articleSortDescriptors]];
	if ([sortColumnIdentifier isEqualToString:columnName])
	{
		[descriptors replaceObjectAtIndex:0 withObject:[[descriptors objectAtIndex:0] reversedSortDescriptor]];
	}
	else
	{
		[articleList setIndicatorImage:nil inTableColumn:[articleList tableColumnWithIdentifier:sortColumnIdentifier]];
		[self setSortColumnIdentifier:columnName];
		[prefs setObject:sortColumnIdentifier forKey:MAPref_SortColumn];
		NSSortDescriptor * sortDescriptor;
		NSDictionary * specifier = [articleSortSpecifiers valueForKey:sortColumnIdentifier];
		unsigned int index = [[descriptors valueForKey:@"key"] indexOfObject:[specifier valueForKey:@"key"]];
		if (index == NSNotFound)
		{
			sortDescriptor = [[NSSortDescriptor alloc] initWithKey:[specifier valueForKey:@"key"] ascending:YES selector:NSSelectorFromString([specifier valueForKey:@"selector"])];
		}
		else
		{
			sortDescriptor = [[descriptors objectAtIndex:index] retain];
			[descriptors removeObjectAtIndex:index];
		}
		[descriptors insertObject:sortDescriptor atIndex:0];
		[sortDescriptor release];
	}
	[prefs setArticleSortDescriptors:descriptors];
	blockSelectionHandler = blockMarkRead = YES;
	[self refreshFolder:MA_Refresh_RedrawList];
	blockSelectionHandler = blockMarkRead = NO;
}

/* scrollToArticle
 * Moves the selection to the specified article. Returns YES if we found the
 * article, NO otherwise.
 */
-(BOOL)scrollToArticle:(NSString *)guid
{
	NSEnumerator * enumerator = [currentArrayOfArticles objectEnumerator];
	Article * thisArticle;
	int rowIndex = 0;
	BOOL found = NO;
	
	while ((thisArticle = [enumerator nextObject]) != nil)
	{
		if ([[thisArticle guid] isEqualToString:guid])
		{
			[self makeRowSelectedAndVisible:rowIndex];
			found = YES;
			break;
		}
		++rowIndex;
	}
	return found;
}

/* initStylesMap
 * Initialise the stylePathMappings.
 */
-(NSDictionary *)initStylesMap
{
	if (stylePathMappings == nil)
		stylePathMappings = [[NSMutableDictionary alloc] init];

	NSString * path = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"Styles"];
	loadMapFromPath(path, stylePathMappings, YES, nil);
	
	path = [[Preferences standardPreferences] stylesFolder];
	loadMapFromPath(path, stylePathMappings, YES, nil);
	
	return stylePathMappings;
}

/* stylePathMappings
 */
-(NSDictionary *)stylePathMappings
{
	if (stylePathMappings == nil)
		[self initStylesMap];
	return stylePathMappings;
}

/* handleStyleChange
 * Updates the article pane when the active display style has been changed.
 */
-(void)handleStyleChange:(NSNotificationCenter *)nc
{
	[self initForStyle:[[Preferences standardPreferences] displayStyle]];
}

/* initForStyle
 * Initialise the template and stylesheet for the specified display style if it can be
 * found. Otherwise the existing template and stylesheet are not changed.
 */
-(BOOL)initForStyle:(NSString *)styleName
{
	NSString * path = [[self stylePathMappings] objectForKey:styleName];
	if (path != nil)
	{
		NSString * filePath = [path stringByAppendingPathComponent:@"template.html"];
		NSFileHandle * handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
		if (handle != nil)
		{
			// Sanity check the file. Obviously anything bigger than 0 bytes but smaller than a valid template
			// format is a problem but we'll worry about that later. There's only so much rope we can give.
			NSData * fileData = [handle readDataToEndOfFile];
			if ([fileData length] > 0)
			{
				[htmlTemplate release];
				[cssStylesheet release];
				
				htmlTemplate = [[NSString stringWithCString:[fileData bytes] length:[fileData length]] retain];
				cssStylesheet = [[@"file://localhost" stringByAppendingString:[path stringByAppendingPathComponent:@"stylesheet.css"]] retain];

				// Make sure the template is valid
				NSString * firstLine = [[htmlTemplate firstNonBlankLine] lowercaseString];
				if (![firstLine hasPrefix:@"<html>"] && ![firstLine hasPrefix:@"<!doctype"])
				{
					if (!isAppInitialising)
						[self refreshArticlePane];

					[handle closeFile];
					return YES;
				}
			}
			[handle closeFile];
		}
	}

	// If the template is invalid, revert to the default style
	// which should ALWAYS be valid.
	NSAssert(![styleName isEqualToString:@"Default"], @"Default style is corrupted!");

	// Warn the user.
	NSString * titleText = [NSString stringWithFormat:NSLocalizedString(@"Invalid style title", nil), styleName];
	runOKAlertPanel(titleText, @"Invalid style body");

	// We need to reset the preferences without firing off a notification since we want the
	// style change to happen immediately.
	Preferences * prefs = [Preferences standardPreferences];
	[prefs setDisplayStyle:@"Default" withNotification:NO];
	return [self initForStyle:@"Default"];
}

/* mainView
 * Return the primary view of this view.
 */
-(NSView *)mainView
{
	return articleList;
}

/* articleView
 * Return the article pane view.
 */
-(NSView *)articleView
{
	return articleText;
}

/* canGoForward
 * Return TRUE if we can go forward in the backtrack queue.
 */
-(BOOL)canGoForward
{
	return ![backtrackArray isAtEndOfQueue];
}

/* canGoBack
 * Return TRUE if we can go backward in the backtrack queue.
 */
-(BOOL)canGoBack
{
	return ![backtrackArray isAtStartOfQueue];
}

/* handleGoForward
 * Move forward through the backtrack queue.
 */
-(IBAction)handleGoForward:(id)sender
{
	int folderId;
	NSString * guid;

	if ([backtrackArray nextItemAtQueue:&folderId guidPointer:&guid])
	{
		isBacktracking = YES;
		[self selectFolderAndArticle:folderId guid:guid];
		isBacktracking = NO;
	}
}

/* handleGoBack
 * Move backward through the backtrack queue.
 */
-(IBAction)handleGoBack:(id)sender
{
	int folderId;
	NSString * guid;
	
	if ([backtrackArray previousItemAtQueue:&folderId guidPointer:&guid])
	{
		isBacktracking = YES;
		[self selectFolderAndArticle:folderId guid:guid];
		isBacktracking = NO;
	}
}

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(unsigned int)flags
{
	return [controller handleKeyDown:keyChar withFlags:flags];
}

/* selectedArticle
 * Returns the selected article, or nil if no article is selected.
 */
-(Article *)selectedArticle
{
	return (currentSelectedRow >= 0) ? [currentArrayOfArticles objectAtIndex:currentSelectedRow] : nil;
}

/* printDocument
 * Print the active article.
 */
-(void)printDocument:(id)sender
{
	[articleText printDocument:sender];
}

/* handleFilterChange
 * Update the list of articles when the user changes the filter.
 */
-(void)handleFilterChange:(NSNotification *)nc
{
	[self refreshFolder:MA_Refresh_ReapplyFilter];
}

/* handleFolderNameChange
 * Some folder metadata changed. Update the article list header and the
 * current article with a possible name change.
 */
-(void)handleFolderNameChange:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	if (folderId == currentFolderId)
	{
		[self setArticleListHeader];
		[self refreshArticlePane];
	}
}

/* handleFolderUpdate
 * Called if a folder content has changed.
 */
-(void)handleFolderUpdate:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	if (folderId == 0 || folderId == currentFolderId || [self currentCacheContainsFolder:folderId])
		[self refreshFolder:MA_Refresh_ReloadFromDatabase];
	else
	{
		Folder * folder = [db folderFromID:currentFolderId];
		if (IsSmartFolder(folder))
			[self refreshFolder:MA_Refresh_ReloadFromDatabase];
	}
}

/* handleArticleListFontChange
 * Called when the user changes the article list font and/or size in the Preferences
 */
-(void)handleArticleListFontChange:(NSNotification *)note
{
	[self setTableViewFont];
	[articleList reloadData];
}

/* handleReadingPaneChange
 * Respond to the change to the reading pane orientation.
 */
-(void)handleReadingPaneChange:(NSNotificationCenter *)nc
{
	[self setOrientation:[[Preferences standardPreferences] readingPaneOnRight]];
	[self updateVisibleColumns];
	[articleList reloadData];
}

/* setOrientation
 * Adjusts the article view orientation and updates the article list row
 * height to accommodate the summary view
 */
-(void)setOrientation:(BOOL)flag
{
	isChangingOrientation = YES;
	tableLayout = flag ? MA_Condensed_Layout : MA_Table_Layout;
	[splitView2 setVertical:flag];
	[splitView2 display];
	isChangingOrientation = NO;
}

/* tableLayout
 * Returns the active table layout.
 */
-(int)tableLayout
{
	return tableLayout;
}

/* sortColumnIdentifier
 */
-(NSString *)sortColumnIdentifier
{
	return sortColumnIdentifier;
}

/* setSortColumnIdentifier
 */
-(void)setSortColumnIdentifier:(NSString *)str
{
	[str retain];
	[sortColumnIdentifier release];
	sortColumnIdentifier = str;
}

/* sortArticles
 * Re-orders the articles in currentArrayOfArticles by the current sort order
 */
-(void)sortArticles
{
	NSArray * sortedArrayOfArticles;
	
	sortedArrayOfArticles = [currentArrayOfArticles sortedArrayUsingDescriptors:[[Preferences standardPreferences] articleSortDescriptors]];
	NSAssert([sortedArrayOfArticles count] == [currentArrayOfArticles count], @"Lost articles from currentArrayOfArticles during sort");
	[currentArrayOfArticles release];
	currentArrayOfArticles = [sortedArrayOfArticles retain];
}

/* makeRowSelectedAndVisible
 * Selects the specified row in the table and makes it visible by
 * scrolling it to the center of the table.
 */
-(void)makeRowSelectedAndVisible:(int)rowIndex
{
	if (rowIndex == currentSelectedRow)
		[self refreshArticleAtCurrentRow:NO];
	else
	{
		[articleList selectRow:rowIndex byExtendingSelection:NO];
		if (currentSelectedRow == -1 || blockSelectionHandler)
		{
			currentSelectedRow = rowIndex;
			[self refreshImmediatelyArticleAtCurrentRow];
		}

		int pageSize = [articleList rowsInRect:[articleList visibleRect]].length;
		int lastRow = [articleList numberOfRows] - 1;
		int visibleRow = currentSelectedRow + (pageSize / 2);

		if (visibleRow > lastRow)
			visibleRow = lastRow;
		[articleList scrollRowToVisible:currentSelectedRow];
		[articleList scrollRowToVisible:visibleRow];
	}
}

/* displayNextUnread
 * Locate the next unread article from the current article onward.
 */
-(void)displayNextUnread
{
	// Mark the current article read
	[self markCurrentRead:nil];

	// Scan the current folder from the selection forward. If nothing found, try
	// other folders until we come back to ourselves.
	if (![self viewNextUnreadInCurrentFolder:currentSelectedRow])
	{
		int nextFolderWithUnread = [foldersTree nextFolderWithUnread:currentFolderId];
		if (nextFolderWithUnread != -1)
		{
			if (nextFolderWithUnread == currentFolderId)
				[self viewNextUnreadInCurrentFolder:-1];
			else
			{
				guidOfArticleToSelect = nil;
				[foldersTree selectFolder:nextFolderWithUnread];
				[[NSApp mainWindow] makeFirstResponder:articleList];
			}
		}
	}
}

/* viewNextUnreadInCurrentFolder
 * Select the next unread article in the current folder after currentRow.
 */
-(BOOL)viewNextUnreadInCurrentFolder:(int)currentRow
{
	int totalRows = [currentArrayOfArticles count];
	if (currentRow < totalRows - 1)
	{
		Article * theArticle;
		
		do {
			theArticle = [currentArrayOfArticles objectAtIndex:++currentRow];
			if (![theArticle isRead])
			{
				[self makeRowSelectedAndVisible:currentRow];
				return YES;
			}
		} while (currentRow < totalRows - 1);
	}
	return NO;
}

/* selectFirstUnreadInFolder
 * Moves the selection to the first unread article in the current article list or the
 * last article if the folder has no unread articles.
 */
-(void)selectFirstUnreadInFolder
{
	if (![self viewNextUnreadInCurrentFolder:-1])
	{
		int count = [currentArrayOfArticles count];
		if (count == 0)
			[[NSApp mainWindow] makeFirstResponder:[foldersTree mainView]];
		else
			[self makeRowSelectedAndVisible:[[[[Preferences standardPreferences] articleSortDescriptors] objectAtIndex:0] ascending] ? 0 : count - 1];
	}
}

/* selectFolderAndArticle
 * Select a folder and select a specified article within the folder.
 */
-(BOOL)selectFolderAndArticle:(int)folderId guid:(NSString *)guid
{
	// If we're in the right folder, easy enough.
	if (folderId == currentFolderId)
		return [self scrollToArticle:guid];

	// Otherwise we force the folder to be selected and seed guidOfArticleToSelect
	// so that after handleFolderSelection has been invoked, it will select the
	// requisite article on our behalf.
	[guidOfArticleToSelect release];
	guidOfArticleToSelect = [guid retain];
	[foldersTree selectFolder:folderId];
	return YES;
}

/* viewLink
 * There's no view link address for article views. If we eventually implement a local
 * scheme such as vienna:<feedurl>/<guid> then we could use that as a link address.
 */
-(NSString *)viewLink
{
	return nil;
}

/* searchPlaceholderString
 * Return the search field placeholder.
 */
-(NSString *)searchPlaceholderString
{
	if (currentFolderId == -1)
		return @"";

	Folder * folder = [db folderFromID:currentFolderId];
	return [NSString stringWithFormat:NSLocalizedString(@"Search in %@", nil), [folder name]];
}

/* performFindPanelAction
 * Implement the search action.
 */
-(void)performFindPanelAction:(int)actionTag
{
	[self refreshFolder:MA_Refresh_ReloadFromDatabase];
	if (currentSelectedRow < 0 && [currentArrayOfArticles count] > 0)
		[self makeRowSelectedAndVisible:0];
}

/* refreshFolder
 * Refreshes the current folder by applying the current sort or thread
 * logic and redrawing the article list. The selected article is preserved
 * and restored on completion of the refresh.
 */
-(void)refreshFolder:(int)refreshFlag
{
	NSString * guid = nil;

	if (currentSelectedRow >= 0)
		guid = [[[currentArrayOfArticles objectAtIndex:currentSelectedRow] guid] retain];
	if (refreshFlag == MA_Refresh_ReloadFromDatabase)
		[self reloadArrayOfArticles];
	if (refreshFlag == MA_Refresh_ReapplyFilter)
	{
		[currentArrayOfArticles release];
		currentArrayOfArticles = [self applyFilter:folderArrayOfArticles];
	}
	[self setArticleListHeader];
	[self sortArticles];
	[self showSortDirection];
	[articleList reloadData];
	if (guid != nil)
	{
		// To avoid upsetting the current displayed article after a refresh, we check to see if the selection has stayed
		// the same and the GUID of the article at the selection is the same. If so, don't refresh anything.
		BOOL isUnchanged = currentSelectedRow >= 0 &&
						   currentSelectedRow < [currentArrayOfArticles count] &&
						   [guid isEqualToString:[[currentArrayOfArticles objectAtIndex:currentSelectedRow] guid]];
		if (!isUnchanged)
		{
			if (![self scrollToArticle:guid])
				currentSelectedRow = -1;
			else
				[self refreshArticlePane];
		}
	}
	[guid release];
}

/* setArticleListHeader
 * Set the article list header caption to the name of the current folder.
 */
-(void)setArticleListHeader
{
	Folder * folder = [db folderFromID:currentFolderId];
	ArticleFilter * filter = [ArticleFilter filterByTag:[[Preferences standardPreferences] filterMode]];
	NSString * captionString = [NSString stringWithFormat:@"%@ (Filtered: %@)", [folder name], NSLocalizedString([filter name], nil)];
	[articleListHeader setStringValue:captionString];
}

/* reloadArrayOfArticles
 * Reload the currentArrayOfArticles from the current folder.
 */
-(void)reloadArrayOfArticles
{
	[folderArrayOfArticles release];
	
	Folder * folder = [db folderFromID:currentFolderId];
	folderArrayOfArticles = [[folder articlesWithFilter:[controller searchString]] retain];
	
	[currentArrayOfArticles release];
	currentArrayOfArticles = [self applyFilter:folderArrayOfArticles];
}

/* applyFilter
 * Apply the active filter to unfilteredArray and return the filtered array.
 * This is done here rather than in the folder management code for simplicity.
 */
-(NSArray *)applyFilter:(NSArray *)unfilteredArray
{
	ArticleFilter * filter = [ArticleFilter filterByTag:[[Preferences standardPreferences] filterMode]];
	if ([filter comparator] == nil)
		return [unfilteredArray retain];

	NSMutableArray * filteredArray = [[NSMutableArray alloc] initWithArray:unfilteredArray];
	int count = [filteredArray count];
	int index;
	
	for (index = count - 1; index >= 0; --index)
	{
		Article * article = [filteredArray objectAtIndex:index];
		if (![ArticleFilter performSelector:[filter comparator] withObject:article])
			[filteredArray removeObjectAtIndex:index];
	}
	return filteredArray;
}

/* selectArticleAfterReload
 * Sets the selection in the article list after the list is reloaded. The value of guidOfArticleToSelect
 * is either MA_Select_None, meaning no selection, MA_Select_Unread meaning select the first unread
 * article from the beginning (after sorting is applied) or it is the ID of a specific article to be
 * selected.
 */
-(void)selectArticleAfterReload
{
	if (guidOfArticleToSelect == nil)
		[self selectFirstUnreadInFolder];
	else
		[self scrollToArticle:guidOfArticleToSelect];
	[guidOfArticleToSelect release];
	guidOfArticleToSelect = nil;
}

/* currentFolderId
 * Return the ID of the folder being displayed in the list.
 */
-(int)currentFolderId
{
	return currentFolderId;
}

/* menuWillAppear
 * Called when the popup menu is opened on the table. We ensure that the item under the
 * cursor is selected.
 */
-(void)tableView:(ExtendedTableView *)tableView menuWillAppear:(NSEvent *)theEvent
{
	int row = [articleList rowAtPoint:[articleList convertPoint:[theEvent locationInWindow] fromView:nil]];
	if (row >= 0)
	{
		// Select the row under the cursor if it isn't already selected
		if ([articleList numberOfSelectedRows] <= 1)
		{
			blockSelectionHandler = YES;
			[articleList selectRow:row byExtendingSelection:NO];
			[self refreshArticleAtCurrentRow:NO];
			blockSelectionHandler = NO;
		}
	}
}

/* selectFolderWithFilter
 * Switches to the specified folder and displays articles filtered by whatever is in
 * the search field.
 */
-(void)selectFolderWithFilter:(int)newFolderId
{
	if (newFolderId != currentFolderId)
	{
		[db flushFolder:currentFolderId];
		[articleList deselectAll:self];
		currentFolderId = newFolderId;
		[self setArticleListHeader];
		[self reloadArrayOfArticles];
		[self sortArticles];
		[articleList reloadData];
		[self selectArticleAfterReload];
	}
}

/* refreshImmediatelyArticleAtCurrentRow
 * Refreshes the article at the current selected row.
 */
-(void)refreshImmediatelyArticleAtCurrentRow
{
	[self refreshArticlePane];
	
	// If we mark read after an interval, start the timer here.
	if (currentSelectedRow >= 0)
	{
		Article * theArticle = [currentArrayOfArticles objectAtIndex:currentSelectedRow];
		if (![theArticle isRead] && !blockMarkRead)
		{
			[markReadTimer invalidate];
			[markReadTimer release];
			markReadTimer = nil;

			float interval = [[Preferences standardPreferences] markReadInterval];
			if (interval > 0 && !isAppInitialising)
				markReadTimer = [[NSTimer scheduledTimerWithTimeInterval:(double)interval
																  target:self
																selector:@selector(markCurrentRead:)
																userInfo:nil
																 repeats:NO] retain];
		}
	}
}

/* startSelectionChange
 * This is the function that is called on the timer to actually handle the
 * selection change.
 */
-(void)startSelectionChange:(NSTimer *)timer
{
	currentSelectedRow = [articleList selectedRow];
	[self refreshImmediatelyArticleAtCurrentRow];
}

/* refreshArticleAtCurrentRow
 * Refreshes the article at the current selected row.
 */
-(void)refreshArticleAtCurrentRow:(BOOL)delayFlag
{
	if (currentSelectedRow < 0)
		[[articleText mainFrame] loadHTMLString:@"<HTML></HTML>" baseURL:nil];
	else
	{
		NSAssert(currentSelectedRow < (int)[currentArrayOfArticles count], @"Out of range row index received");
		[selectionTimer invalidate];
		[selectionTimer release];
		selectionTimer = nil;

		float interval = [[Preferences standardPreferences] selectionChangeInterval];
		if (interval == 0 || !delayFlag)
			[self refreshImmediatelyArticleAtCurrentRow];
		else
			selectionTimer = [[NSTimer scheduledTimerWithTimeInterval:interval
															   target:self
															 selector:@selector(startSelectionChange:) 
															 userInfo:nil 
															  repeats:NO] retain];

		// Add this to the backtrack list
		if (!isBacktracking)
		{
			NSString * guid = [[currentArrayOfArticles objectAtIndex:currentSelectedRow] guid];
			[backtrackArray addToQueue:currentFolderId guid:guid];
		}
	}
}

/* refreshArticlePane
 * Updates the article pane for the current selected articles.
 */
-(void)refreshArticlePane
{
	NSArray * msgArray = [self markedArticleRange];
	int folderIdToUse = currentFolderId;
	int index;

	NSMutableString * htmlText = [[NSMutableString alloc] initWithString:@"<html><head>"];
	if (cssStylesheet != nil)
	{
		[htmlText appendString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\""];
		[htmlText appendString:cssStylesheet];
		[htmlText appendString:@"\"/>"];
	}
	[htmlText appendString:@"<meta http-equiv=\"Pragma\" content=\"no-cache\">"];
	[htmlText appendString:@"<title>$ArticleTitle$</title></head><body>"];
	for (index = 0; index < [msgArray count]; ++index)
	{
		Article * theArticle = [msgArray objectAtIndex:index];
		Folder * folder = [db folderFromID:[theArticle folderId]];

		// Use the first article as the base URL
		if (index == 0)
			folderIdToUse = [theArticle folderId];

		// Cache values for things we're going to be plugging into the template and set
		// defaults for things that are missing.
		NSMutableString * articleBody = [NSMutableString stringWithString:[theArticle body]];
		NSMutableString * articleTitle = [NSMutableString stringWithString:([theArticle title] ? [theArticle title] : @"")];
		NSString * articleDate = [[[theArticle date] dateWithCalendarFormat:nil timeZone:nil] friendlyDescription];
		NSString * articleLink = [theArticle link] ? [theArticle link] : @"";
		NSString * articleAuthor = [theArticle author] ? [theArticle author] : @"";
		NSString * folderTitle = [folder name] ? [folder name] : @"";
		NSString * folderLink = [folder homePage] ? [folder homePage] : @"";
		NSString * folderDescription = [folder feedDescription] ? [folder feedDescription] : @"";

		// Do relative IMG tag fixup
		[self fixupRelativeImgTags:articleBody baseURL:[articleLink stringByDeletingLastURLComponent]];
	
		// Load the selected HTML template for the current view style and plug in the current
		// article values and style sheet setting.
		NSMutableString * htmlArticle;
		if (htmlTemplate == nil)
			htmlArticle = [[NSMutableString alloc] initWithString:articleBody];
		else
		{
			htmlArticle = [[NSMutableString alloc] initWithString:htmlTemplate];

			[articleBody replaceString:@"$Article" withString:@"$_%$%_Article"];
			[articleBody replaceString:@"$Feed" withString:@"$_%$%_Feed"];

			[articleTitle replaceString:@"$Article" withString:@"$_%$%_Article"];
			[articleTitle replaceString:@"$Feed" withString:@"$_%$%_Feed"];

			[htmlArticle replaceString:@"$ArticleLink$" withString:articleLink];
			[htmlArticle replaceString:@"$ArticleTitle$" withString:[XMLParser quoteAttributes:articleTitle]];
			[htmlArticle replaceString:@"$ArticleBody$" withString:articleBody];
			[htmlArticle replaceString:@"$ArticleAuthor$" withString:articleAuthor];
			[htmlArticle replaceString:@"$ArticleDate$" withString:articleDate];
			[htmlArticle replaceString:@"$FeedTitle$" withString:[XMLParser quoteAttributes:folderTitle]];
			[htmlArticle replaceString:@"$FeedLink$" withString:folderLink];
			[htmlArticle replaceString:@"$FeedDescription$" withString:folderDescription];
			[htmlArticle replaceString:@"$_%$%_" withString:@"$"];
		}

		// Separate each article with a horizontal divider line
		if (index > 0)
			[htmlText appendString:@"<hr><br />"];
		[htmlText appendString:htmlArticle];
		[htmlArticle release];
	}

	// Here we ask the webview to do all the hard work. There's an idiosyncracy in loadHTMLString:baseURL: that it
	// requires a URL to an actual file as the second parameter or it won't work.
	// BUGBUG: If you select multiple articles that come from different folders and each one has relative links
	//  to a different feed base, then only the first article's links will be fixed up correctly by Webkit.
	[htmlText appendString:@"</body></html>"];

	Folder * folder = [db folderFromID:folderIdToUse];
	NSString * urlString = [folder feedURL] ? [folder feedURL] : @"";
	const char * utf8String = [htmlText UTF8String];
	[[articleText mainFrame] loadData:[NSData dataWithBytes:utf8String length:strlen(utf8String)]
							 MIMEType:@"text/html" 
					 textEncodingName:@"utf-8" 
							  baseURL:[NSURL URLWithString:urlString]];
	[htmlText release];
}

/* fixupRelativeImgTags
 * Scans the text for <img...> tags that have relative links in the src attribute and fixes
 * up the relative links to be absolute to the base URL.
 */
-(void)fixupRelativeImgTags:(NSMutableString *)text baseURL:(NSString *)baseURL
{
	int textLength = [text length];
	NSRange srchRange;
	
	srchRange.location = 0;
	srchRange.length = textLength;
	while ((srchRange = [text rangeOfString:@"<img" options:NSLiteralSearch range:srchRange]), srchRange.location != NSNotFound)
	{
		srchRange.length = textLength - srchRange.location;
		NSRange srcRange = [text rangeOfString:@"src=\"" options:NSLiteralSearch range:srchRange];
		if (srcRange.location != NSNotFound)
		{
			// Find the src parameter range.
			int index = srcRange.location + srcRange.length;
			srcRange.location += srcRange.length;
			srcRange.length = 0;
			while (index < textLength && [text characterAtIndex:index] != '"')
			{
				++index;
				++srcRange.length;
			}
			
			// Now extract the source parameter
			NSString * srcPath = [text substringWithRange:srcRange];
			if (srcPath && ![srcPath hasPrefix:@"http://"])
			{
				srcPath = [baseURL stringByAppendingURLComponent:srcPath];
				[text replaceCharactersInRange:srcRange withString:srcPath];
				textLength = [text length];
			}
			
			// Start searching again from beyond the URL
			srchRange.location = srcRange.location + [srcPath length];
		}
		else
			++srchRange.location;
		srchRange.length = textLength - srchRange.location;
	}
}

/* markCurrentRead
 * Mark the current article as read.
 */
-(void)markCurrentRead:(NSTimer *)aTimer
{
	if (currentSelectedRow != -1 && ![db readOnly])
	{
		Article * theArticle = [currentArrayOfArticles objectAtIndex:currentSelectedRow];
		if (![theArticle isRead])
			[self markReadByArray:[NSArray arrayWithObject:theArticle] readFlag:YES];
	}
}

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of articles in the current folder.
 */
-(int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [currentArrayOfArticles count];
}

/* objectValueForTableColumn [datasource]
 * Called by the table view to obtain the object at the specified column and row. This is
 * called often so it needs to be fast.
 */
-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	Article * theArticle;
	
	NSParameterAssert(rowIndex >= 0 && rowIndex < (int)[currentArrayOfArticles count]);
	theArticle = [currentArrayOfArticles objectAtIndex:rowIndex];
	if ([[aTableColumn identifier] isEqualToString:MA_Field_Read])
	{
		if (![theArticle isRead])
			return [NSImage imageNamed:@"unread.tiff"];
		return [NSImage imageNamed:@"alphaPixel.tiff"];
	}
	if ([[aTableColumn identifier] isEqualToString:MA_Field_Flagged])
	{
		if ([theArticle isFlagged])
			return [NSImage imageNamed:@"flagged.tiff"];
		return [NSImage imageNamed:@"alphaPixel.tiff"];
	}
	if ([[aTableColumn identifier] isEqualToString:MA_Field_Comments])
	{
		if ([theArticle hasComments])
			return [NSImage imageNamed:@"comments.tiff"];
		return [NSImage imageNamed:@"alphaPixel.tiff"];
	}
	if ([[aTableColumn identifier] isEqualToString:MA_Field_Date])
	{
		return [[theArticle articleData] objectForKey:[aTableColumn identifier]];
	}
	if ([[aTableColumn identifier] isEqualToString:MA_Field_Headlines])
	{
		NSMutableAttributedString * theAttributedString = [[NSMutableAttributedString alloc] init];
		BOOL isSelectedRow = [aTableView isRowSelected:rowIndex] && ([[NSApp mainWindow] firstResponder] == aTableView);

		if ([[db fieldByName:MA_Field_Subject] visible])
		{
			NSDictionary * topLineDictPtr = (isSelectedRow ? selectionDict : topLineDict);
			NSString * topString = [NSString stringWithFormat:@"%@\n", [theArticle title]];
			[theAttributedString appendAttributedString:[[[NSAttributedString alloc] initWithString:topString attributes:topLineDictPtr] autorelease]];
		}

		// Add the summary line that appears below the title.
		if ([[db fieldByName:MA_Field_Summary] visible])
		{
			NSString * summaryString = [theArticle summary];
			int maxSummaryLength = MIN([summaryString length], 80);
			NSString * middleString = [NSString stringWithFormat:@"%@\n", [summaryString substringToIndex:maxSummaryLength]];
			NSDictionary * middleLineDictPtr = (isSelectedRow ? selectionDict : middleLineDict);
			[theAttributedString appendAttributedString:[[[NSAttributedString alloc] initWithString:middleString attributes:middleLineDictPtr] autorelease]];
		}
		
		// Add the link line that appears below the summary and title.
		if ([[db fieldByName:MA_Field_Link] visible])
		{
			NSString * linkString = [NSString stringWithFormat:@"%@\n", [theArticle link]];
			NSDictionary * linkLineDictPtr = (isSelectedRow ? selectionDict : linkLineDict);
			[linkLineDict setObject:[NSURL URLWithString:[theArticle link]] forKey:NSLinkAttributeName];
			[theAttributedString appendAttributedString:[[[NSAttributedString alloc] initWithString:linkString attributes:linkLineDictPtr] autorelease]];
		}
		
		// Create the detail line that appears at the bottom.
		NSDictionary * bottomLineDictPtr = (isSelectedRow ? selectionDict : bottomLineDict);
		NSMutableString * summaryString = [NSMutableString stringWithString:@""];
		NSString * delimiter = @"";

		if ([[db fieldByName:MA_Field_Folder] visible])
		{
			Folder * folder = [db folderFromID:[theArticle folderId]];
			[summaryString appendString:[folder name]];
			delimiter = @" - ";
		}
		if ([[db fieldByName:MA_Field_Date] visible])
		{
			NSCalendarDate * anDate = [[theArticle date] dateWithCalendarFormat:nil timeZone:nil];
			[summaryString appendFormat:@"%@%@", delimiter,[anDate friendlyDescription]];
			delimiter = @" - ";
		}
		if ([[db fieldByName:MA_Field_Author] visible])
		{
			if (![[theArticle author] isBlank])
				[summaryString appendFormat:@"%@%@", delimiter, [theArticle author]];
		}
		[theAttributedString appendAttributedString:[[[NSAttributedString alloc] initWithString:summaryString attributes:bottomLineDictPtr] autorelease]];
		return [theAttributedString autorelease];
	}

	// Only string articleData objects should make it from here.
	NSString * cellString;
	if (![[aTableColumn identifier] isEqualToString:MA_Field_Folder])
		cellString = [[theArticle articleData] objectForKey:[aTableColumn identifier]];
	else
	{
		Folder * folder = [db folderFromID:[theArticle folderId]];
		cellString = [folder name];
	}

	// Return the cell string with a paragraph style that will truncate over-long strings by placing
	// ellipsis in the middle to fit within the cell.
    static NSDictionary * info = nil;
    if (info == nil)
	{
        NSMutableParagraphStyle * style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode:NSLineBreakByTruncatingTail];
        info = [[NSDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, nil];
        [style release];
    }
    return [[[NSAttributedString alloc] initWithString:cellString attributes:info] autorelease];
}

/* willDisplayCell [delegate]
 * Catch the table view before it displays a cell.
 */
-(void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if (![aCell isKindOfClass:[NSImageCell class]])
	{
		[aCell setTextColor:[NSColor blackColor]];
		[aCell setFont:articleListFont];
	}
}

/* tableViewSelectionDidChange [delegate]
 * Handle the selection changing in the table view unless blockSelectionHandler is set.
 */
-(void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if (!blockSelectionHandler)
	{
		currentSelectedRow = [articleList selectedRow];
		[self refreshArticleAtCurrentRow:YES];
	}
}

/* didClickTableColumns
 * Handle the user click in the column header to sort by that column.
 */
-(void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	NSString * columnName = [tableColumn identifier];
	[self sortByIdentifier:columnName];
}

/* tableViewColumnDidResize
 * This notification is called when the user completes resizing a column. We obtain the
 * new column size and save the settings.
 */
-(void)tableViewColumnDidResize:(NSNotification *)notification
{
	if (!isInTableInit && !isAppInitialising && !isChangingOrientation)
	{
		NSTableColumn * tableColumn = [[notification userInfo] objectForKey:@"NSTableColumn"];
		Field * field = [db fieldByName:[tableColumn identifier]];
		int oldWidth = [[[notification userInfo] objectForKey:@"NSOldWidth"] intValue];
		
		if (oldWidth != [tableColumn width])
		{
			[field setWidth:[tableColumn width]];
			[self saveTableSettings];
		}
	}
}

/* writeRows
 * Called to initiate a drag from MessageListView. Use the common copy selection code to copy to
 * the pasteboard.
 */
-(BOOL)tableView:(NSTableView *)tv writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	return [self copyTableSelection:rows toPasteboard:pboard];
}

/* copyTableSelection
 * This is the common copy selection code. We build an array of dictionary entries each of
 * which include details of each selected article in the standard RSS item format defined by
 * Ranchero NetNewsWire. See http://ranchero.com/netnewswire/rssclipboard.php for more details.
 */
-(BOOL)copyTableSelection:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray * arrayOfArticles = [[NSMutableArray alloc] init];
	NSMutableString * fullHTMLText = [[NSMutableString alloc] init];
	NSMutableString * fullPlainText = [[NSMutableString alloc] init];
	int count = [rows count];
	int index;
	
	// Set up the pasteboard
	[pboard declareTypes:[NSArray arrayWithObjects:MA_PBoardType_RSSItem, NSStringPboardType, NSHTMLPboardType, nil] owner:self];
	
	// Open the HTML string
	[fullHTMLText appendString:@"<html><body>"];
	
	// Get all the articles that are being dragged
	for (index = 0; index < count; ++index)
	{
		int msgIndex = [[rows objectAtIndex:index] intValue];
		Article * thisArticle = [currentArrayOfArticles objectAtIndex:msgIndex];
		Folder * folder = [db folderFromID:[thisArticle folderId]];
		NSString * msgText = [thisArticle body];
		NSString * msgTitle = [thisArticle title];
		NSString * msgLink = [thisArticle link];

		NSMutableDictionary * articleDict = [[NSMutableDictionary alloc] init];
		[articleDict setValue:msgTitle forKey:@"rssItemTitle"];
		[articleDict setValue:msgLink forKey:@"rssItemLink"];
		[articleDict setValue:msgText forKey:@"rssItemDescription"];
		[articleDict setValue:[folder name] forKey:@"sourceName"];
		[articleDict setValue:[folder homePage] forKey:@"sourceHomeURL"];
		[articleDict setValue:[folder feedURL] forKey:@"sourceRSSURL"];
		[arrayOfArticles addObject:articleDict];
		[articleDict release];

		// Plain text
		[fullPlainText appendFormat:@"%@\n%@\n\n", msgTitle, msgText];
		
		// Add HTML version too.
		[fullHTMLText appendFormat:@"<a href=\"%@\">%@</a><br />%@<br /><br />", msgLink, msgTitle, msgText];
	}
	
	// Close the HTML string
	[fullHTMLText appendString:@"</body></html>"];

	// Put string on the pasteboard for external drops.
	[pboard setPropertyList:arrayOfArticles forType:MA_PBoardType_RSSItem];
	[pboard setString:fullPlainText forType:NSStringPboardType];
	[pboard setString:[fullHTMLText stringByEscapingExtendedCharacters] forType:NSHTMLPboardType];

	[arrayOfArticles release];
	[fullHTMLText release];
	[fullPlainText release];
	return YES;
}

/* markedArticleRange
 * Retrieve an array of selected articles.
 */
-(NSArray *)markedArticleRange
{
	NSMutableArray * articleArray = nil;
	if ([articleList numberOfSelectedRows] > 0)
	{
		NSEnumerator * enumerator = [articleList selectedRowEnumerator];
		NSNumber * rowIndex;

		articleArray = [NSMutableArray arrayWithCapacity:16];
		while ((rowIndex = [enumerator nextObject]) != nil)
			[articleArray addObject:[currentArrayOfArticles objectAtIndex:[rowIndex intValue]]];
	}
	return articleArray;
}

/* markDeletedUndo
 * Undo handler to restore a series of deleted articles.
 */
-(void)markDeletedUndo:(id)anObject
{
	[self markDeletedByArray:(NSArray *)anObject deleteFlag:NO];
}

/* markUndeletedUndo
 * Undo handler to delete a series of articles.
 */
-(void)markUndeletedUndo:(id)anObject
{
	[self markDeletedByArray:(NSArray *)anObject deleteFlag:YES];
}

/* markDeletedByArray
 * Helper function. Takes as an input an array of articles and deletes or restores
 * the articles.
 */
-(void)markDeletedByArray:(NSArray *)articleArray deleteFlag:(BOOL)deleteFlag
{
	NSEnumerator * enumerator = [articleArray objectEnumerator];
	Article * theArticle;
	
	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markDeletedUndoAction = deleteFlag ? @selector(markDeletedUndo:) : @selector(markUndeletedUndo:);
	[undoManager registerUndoWithTarget:self selector:markDeletedUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Delete", nil)];
	
	// We will make a new copy of the currentArrayOfArticles with the selected articles removed.
	NSMutableArray * arrayCopy = [[NSMutableArray alloc] initWithArray:currentArrayOfArticles];
	BOOL needFolderRedraw = NO;
	
	// Iterate over every selected article in the table and set the deleted
	// flag on the article while simultaneously removing it from our copy of
	// currentArrayOfArticles.
	[db beginTransaction];
	while ((theArticle = [enumerator nextObject]) != nil)
	{
		if (![theArticle isRead])
			needFolderRedraw = YES;
		[db markArticleDeleted:[theArticle folderId] guid:[theArticle guid] isDeleted:deleteFlag];
		if (deleteFlag)
		{
			if ([self currentCacheContainsFolder:[theArticle folderId]])
				[arrayCopy removeObject:theArticle];
		}
		else
		{
			if (currentFolderId == [db trashFolderId])
				[arrayCopy removeObject:theArticle];
			else if ([theArticle folderId] == currentFolderId)
				[arrayCopy addObject:theArticle];
		}
	}
	[db commitTransaction];
	[currentArrayOfArticles release];
	currentArrayOfArticles = arrayCopy;
	[articleList reloadData];
	
	// If we've added articles back to the array, we need to resort to put
	// them back in the right place.
	if (!deleteFlag)
		[self sortArticles];
	
	// If any of the articles we deleted were unread then the
	// folder's unread count just changed.
	if (needFolderRedraw)
		[foldersTree updateFolder:currentFolderId recurseToParents:YES];
	
	// Compute the new place to put the selection
	int nextRow = [[articleList selectedRowIndexes] firstIndex];
	currentSelectedRow = -1;
	if (nextRow < 0 || nextRow >= (int)[currentArrayOfArticles count])
		nextRow = [currentArrayOfArticles count] - 1;
	[self makeRowSelectedAndVisible:nextRow];

	// Read and/or unread count may have changed
	if (needFolderRedraw)
		[controller showUnreadCountOnApplicationIconAndWindowTitle];
}

/* deleteSelectedArticles
 * Physically delete all selected articles in the article list.
 */
-(void)deleteSelectedArticles
{		
	// Make a new copy of the currentArrayOfArticles with the selected article removed.
	NSMutableArray * arrayCopy = [[NSMutableArray alloc] initWithArray:currentArrayOfArticles];
	BOOL needFolderRedraw = NO;
	
	// Iterate over every selected article in the table and remove it from
	// the database.
	NSEnumerator * enumerator = [articleList selectedRowEnumerator];
	NSNumber * rowIndex;

	[db beginTransaction];
	while ((rowIndex = [enumerator nextObject]) != nil)
	{
		Article * theArticle = [currentArrayOfArticles objectAtIndex:[rowIndex intValue]];
		if (![theArticle isRead])
			needFolderRedraw = YES;
		if ([db deleteArticle:[theArticle folderId] guid:[theArticle guid]])
			[arrayCopy removeObject:theArticle];
	}
	[db commitTransaction];
	[currentArrayOfArticles release];
	currentArrayOfArticles = arrayCopy;
	[articleList reloadData];

	// Blow away the undo stack here since undo actions may refer to
	// articles that have been deleted. This is a bit of a cop-out but
	// it's the easiest approach for now.
	[controller clearUndoStack];
	
	// If any of the articles we deleted were unread then the
	// folder's unread count just changed.
	if (needFolderRedraw)
		[foldersTree updateFolder:currentFolderId recurseToParents:YES];
	
	// Compute the new place to put the selection
	int nextRow = [[articleList selectedRowIndexes] firstIndex];
	currentSelectedRow = -1;
	if (nextRow < 0 || nextRow >= (int)[currentArrayOfArticles count])
		nextRow = [currentArrayOfArticles count] - 1;
	[self makeRowSelectedAndVisible:nextRow];
	
	// Read and/or unread count may have changed
	if (needFolderRedraw)
		[controller showUnreadCountOnApplicationIconAndWindowTitle];
}

/* markUnflagUndo
 * Undo handler to un-flag an array of articles.
 */
-(void)markUnflagUndo:(id)anObject
{
	[self markFlaggedByArray:(NSArray *)anObject flagged:NO];
}

/* markFlagUndo
 * Undo handler to flag an array of articles.
 */
-(void)markFlagUndo:(id)anObject
{
	[self markFlaggedByArray:(NSArray *)anObject flagged:YES];
}

/* markFlaggedByArray
 * Mark the specified articles in articleArray as flagged.
 */
-(void)markFlaggedByArray:(NSArray *)articleArray flagged:(BOOL)flagged
{
	NSEnumerator * enumerator = [articleArray objectEnumerator];
	Article * theArticle;
	
	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markFlagUndoAction = flagged ? @selector(markUnflagUndo:) : @selector(markFlagUndo:);
	[undoManager registerUndoWithTarget:self selector:markFlagUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Flag", nil)];
	
	[db beginTransaction];
	while ((theArticle = [enumerator nextObject]) != nil)
	{
		[theArticle markFlagged:flagged];
		[db markArticleFlagged:[theArticle folderId] guid:[theArticle guid] isFlagged:flagged];
	}
	[db commitTransaction];
	[articleList reloadData];
}

/* markUnreadUndo
 * Undo handler to mark an array of articles unread.
 */
-(void)markUnreadUndo:(id)anObject
{
	[self markReadByArray:(NSArray *)anObject readFlag:NO];
}

/* markReadUndo
 * Undo handler to mark an array of articles read.
 */
-(void)markReadUndo:(id)anObject
{
	[self markReadByArray:(NSArray *)anObject readFlag:YES];
}

/* markReadByArray
 * Helper function. Takes as an input an array of articles and marks those articles read or unread.
 */
-(void)markReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag
{
	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markReadUndoAction = readFlag ? @selector(markUnreadUndo:) : @selector(markReadUndo:);
	[undoManager registerUndoWithTarget:self selector:markReadUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Mark Read", nil)];
	
	[markReadTimer invalidate];
	[markReadTimer release];
	markReadTimer = nil;

	[db beginTransaction];
	[self innerMarkReadByArray:articleArray readFlag:readFlag];
	[db commitTransaction];
	[articleList reloadData];

	[foldersTree updateFolder:currentFolderId recurseToParents:YES];
	
	// The info bar has a count of unread articles so we need to
	// update that.
	[controller showUnreadCountOnApplicationIconAndWindowTitle];
}

/* innerMarkReadByArray
 * Marks all articles in the specified array read or unread.
 */
-(void)innerMarkReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag
{
	NSEnumerator * enumerator = [articleArray objectEnumerator];
	int lastFolderId = -1;
	Article * theArticle;

	while ((theArticle = [enumerator nextObject]) != nil)
	{
		int folderId = [theArticle folderId];
		[db markArticleRead:folderId guid:[theArticle guid] isRead:readFlag];
		[theArticle markRead:readFlag];
		if (folderId != lastFolderId && lastFolderId != -1)
			[foldersTree updateFolder:lastFolderId recurseToParents:YES];
		lastFolderId = folderId;
	}
	if (lastFolderId != -1)
		[foldersTree updateFolder:lastFolderId recurseToParents:YES];
}

/* markAllReadUndo
 * Undo the most recent Mark All Read.
 */
-(void)markAllReadUndo:(id)anObject
{
	[self markAllReadByReferencesArray:(NSArray *)anObject readFlag:NO];
}

/* markAllReadRedo
 * Redo the most recent Mark All Read.
 */
-(void)markAllReadRedo:(id)anObject
{
	[self markAllReadByReferencesArray:(NSArray *)anObject readFlag:YES];
}

/* markAllReadByArray
 * Given an array of folders, mark all the articles in those folders as read and
 * return a reference array listing all the articles that were actually marked.
 */
-(void)markAllReadByArray:(NSArray *)folderArray withUndo:(BOOL)undoFlag
{
	NSArray * refArray = nil;
	BOOL flag = NO;

	[db beginTransaction];
	refArray = [self wrappedMarkAllReadInArray:folderArray withUndo:undoFlag needRefresh:&flag];
	[db commitTransaction];
	if (refArray != nil && [refArray count] > 0)
	{
		NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
		[undoManager registerUndoWithTarget:self selector:@selector(markAllReadUndo:) object:refArray];
		[undoManager setActionName:NSLocalizedString(@"Mark All Read", nil)];
	}
	if (flag)
		[self refreshFolder:MA_Refresh_ReloadFromDatabase];
	[controller showUnreadCountOnApplicationIconAndWindowTitle];
}

/* wrappedMarkAllReadInArray
 * Given an array of folders, mark all the articles in those folders as read and
 * return a reference array listing all the articles that were actually marked.
 */
-(NSArray *)wrappedMarkAllReadInArray:(NSArray *)folderArray withUndo:(BOOL)undoFlag needRefresh:(BOOL *)needRefreshPtr
{
	NSMutableArray * refArray = [NSMutableArray array];
	NSEnumerator * enumerator = [folderArray objectEnumerator];
	Folder * folder;

	NSAssert(needRefreshPtr != nil, @"needRefresh pointer cannot be nil");
	while ((folder = [enumerator nextObject]) != nil)
	{
		int folderId = [folder itemId];
		if (IsGroupFolder(folder))
		{
			if (undoFlag)
				[refArray addObjectsFromArray:[self wrappedMarkAllReadInArray:[db arrayOfFolders:folderId] withUndo:undoFlag needRefresh:needRefreshPtr]];
			if ([self currentCacheContainsFolder:folderId])
				*needRefreshPtr = YES;
		}
		else if (!IsSmartFolder(folder))
		{
			if (undoFlag)
				[refArray addObjectsFromArray:[db arrayOfUnreadArticles:folderId]];
			if ([db markFolderRead:folderId])
			{
				[foldersTree updateFolder:folderId recurseToParents:YES];
				if ([self currentCacheContainsFolder:folderId])
					*needRefreshPtr = YES;
			}
		}
		else
		{
			// For smart folders, we only mark all read the current folder to
			// simplify things.
			if (folderId == currentFolderId)
			{
				if (undoFlag)
					[refArray addObjectsFromArray:currentArrayOfArticles];
				[self innerMarkReadByArray:currentArrayOfArticles readFlag:YES];
				[articleList reloadData];
			}
		}
	}
	return refArray;
}

/* currentCacheContainsFolder
 * Scans the current article cache to determine if any article is a member of the specified
 * folder and returns YES if so.
 */
-(BOOL)currentCacheContainsFolder:(int)folderId
{
	int count = [currentArrayOfArticles count];
	int index = 0;
	
	while (index < count)
	{
		Article * anArticle = [currentArrayOfArticles objectAtIndex:index];
		if ([anArticle folderId] == folderId)
			return YES;
		++index;
	}
	return NO;
}

/* markAllReadByReferencesArray
 * Given an array of references, mark all those articles read or unread.
 */
-(void)markAllReadByReferencesArray:(NSArray *)refArray readFlag:(BOOL)readFlag
{
	NSEnumerator * enumerator = [refArray objectEnumerator];
	ArticleReference * ref;
	int lastFolderId = -1;

	// Set up to undo or redo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markAllReadUndoAction = readFlag ? @selector(markAllReadUndo:) : @selector(markAllReadRedo:);
	[undoManager registerUndoWithTarget:self selector:markAllReadUndoAction object:refArray];
	[undoManager setActionName:NSLocalizedString(@"Mark All Read", nil)];
	
	[db beginTransaction];
	while ((ref = [enumerator nextObject]) != nil)
	{
		int folderId = [ref folderId];
		[db markArticleRead:folderId guid:[ref guid] isRead:readFlag];
		if (folderId != lastFolderId && lastFolderId != -1)
		{
			[foldersTree updateFolder:lastFolderId recurseToParents:YES];
			if (lastFolderId == currentFolderId)
				[self refreshFolder:MA_Refresh_ReloadFromDatabase];
		}
		lastFolderId = folderId;
	}
	[db commitTransaction];
	
	if (lastFolderId != -1)
	{
		[foldersTree updateFolder:lastFolderId recurseToParents:YES];
		if (lastFolderId == currentFolderId)
			[self refreshFolder:MA_Refresh_ReloadFromDatabase];
		else
		{
			Folder * currentFolder = [db folderFromID:currentFolderId];
			if (IsSmartFolder(currentFolder))
				[articleList reloadData];
		}
	}

	// The info bar has a count of unread articles so we need to
	// update that.
	[controller showUnreadCountOnApplicationIconAndWindowTitle];
}

-(void)handleMakeTextSmaller{}
-(void)handleMakeTextLarger{}

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[db release];
	[stylePathMappings release];
	[cssStylesheet release];
	[htmlTemplate release];
	[extDateFormatter release];
	[selectionTimer release];
	[markReadTimer release];
	[folderArrayOfArticles release];
	[currentArrayOfArticles release];
	[backtrackArray release];
	[articleListFont release];
	[guidOfArticleToSelect release];
	[selectionDict release];
	[topLineDict release];
	[middleLineDict release];
	[linkLineDict release];
	[bottomLineDict release];
	[articleSortSpecifiers release];
	[super dealloc];
}
@end
