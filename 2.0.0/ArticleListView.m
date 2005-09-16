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
#import "WebKit/WebPreferences.h"
#import "WebKit/WebFrame.h"
#import "WebKit/WebPolicyDelegate.h"
#import "WebKit/WebUIDelegate.h"
#import "WebKit/WebDataSource.h"
#import "WebKit/WebFrameView.h"

// Private functions
@interface ArticleListView (Private)
	-(void)setArticleListHeader;
	-(void)initTableView;
	-(BOOL)initForStyle:(NSString *)styleName;
	-(BOOL)copyTableSelection:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard;
	-(void)showColumnsForFolder:(int)folderId;
	-(void)setTableViewFont;
	-(void)showSortDirection;
	-(void)setSortColumnIdentifier:(NSString *)str;
	-(void)selectArticleAfterReload;
	-(void)handleMinimumFontSizeChange:(NSNotification *)nc;
	-(void)handleStyleChange:(NSNotificationCenter *)nc;
	-(void)handleReadingPaneChange:(NSNotificationCenter *)nc;
	-(BOOL)scrollToArticle:(NSString *)guid;
	-(void)selectFirstUnreadInFolder;
	-(void)makeRowSelectedAndVisible:(int)rowIndex;
	-(BOOL)viewNextUnreadInCurrentFolder:(int)currentRow;
	-(void)loadMinimumFontSize;
	-(void)markCurrentRead:(NSTimer *)aTimer;
	-(void)refreshArticleAtRow:(int)theRow markRead:(BOOL)markReadFlag;
	-(NSArray *)wrappedMarkAllReadInArray:(NSArray *)folderArray;
	-(void)reloadArrayOfArticles;
	-(void)refreshArticlePane;
	-(void)updateArticleListRowHeight;
	-(void)setOrientation:(BOOL)flag;
	-(void)printDocument;
@end

// Non-class function used for sorting
static int articleSortHandler(id item1, id item2, void * context);

// Static constant strings that are typically never tweaked
static NSString * RSSItemType = @"CorePasteboardFlavorType 0x52535369";

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
		guidOfArticleToSelect = nil;
		stylePathMappings = nil;
		markReadTimer = nil;
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
	// Register to be notified when folders are added or removed
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleArticleListFontChange:) name:@"MA_Notify_ArticleListFontChange" object:nil];
	[nc addObserver:self selector:@selector(handleMinimumFontSizeChange:) name:@"MA_Notify_MinimumFontSizeChange" object:nil];
	[nc addObserver:self selector:@selector(handleStyleChange:) name:@"MA_Notify_StyleChange" object:nil];
	[nc addObserver:self selector:@selector(handleReadingPaneChange:) name:@"MA_Notify_ReadingPaneChange" object:nil];

	// Create condensed view attribute dictionaries
	selectionDict = [[NSMutableDictionary alloc] init];
	topLineDict = [[NSMutableDictionary alloc] init];
	bottomLineDict = [[NSMutableDictionary alloc] init];
	
	// Create a backtrack array
	Preferences * prefs = [Preferences standardPreferences];
	backtrackArray = [[BackTrackArray alloc] initWithMaximum:[prefs backTrackQueueSize]];

	// Set header text
	[articleListHeader setStringValue:NSLocalizedString(@"Articles", nil)];

	// Make us the policy and UI delegate for the web view
	[articleText setPolicyDelegate:self];
	[articleText setUIDelegate:self];
	[articleText setFrameLoadDelegate:self];
	
	// Handle minimum font size
	defaultWebPrefs = [[articleText preferences] retain];
	[self loadMinimumFontSize];
	
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
}

/* initialiseArticleView
 * Do the things to initialise the article view from the database. This is the
 * only point during initialisation where the database is guaranteed to be
 * ready for use.
 */
-(void)initialiseArticleView
{
	// Mark the start of the init phase
	isAppInitialising = YES;
	
	// Set the reading pane orientation
	[self setOrientation:[[Preferences standardPreferences] readingPaneOnRight]];

	// Initialise the article list view
	[self initTableView];
	
	// Select the default style
	Preferences * prefs = [Preferences standardPreferences];
	if (![self initForStyle:[prefs displayStyle]])
		[prefs setDisplayStyle:@"Default"];

	// Restore the split bar position
	[splitView2 loadLayoutWithName:@"SplitView2Positions"];
	[splitView2 setDelegate:self];

	// Select the first conference
	int previousFolderId = [[NSUserDefaults standardUserDefaults] integerForKey:MAPref_CachedFolderID];
	[self selectFolderAndArticle:previousFolderId guid:nil];
	
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

/* decidePolicyForNavigationAction
 * Called by the web view to get our policy on handling navigation actions. Since we want links clicked in the
 * web view to open in an external browser, we trap the link clicked action and launch the URL ourselves.
 */
-(void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	int navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] intValue];
	if (navType == WebNavigationTypeLinkClicked)
	{
		[listener ignore];
		[controller openURLInBrowserWithURL:[request URL]];
	}
	[listener use];
}

/* decidePolicyForNewWindowAction
 * Called by the web view to get our policy on handling actions that would open a new window. Since we want links clicked in the
 * web view to open in an external browser, we trap the link clicked action and launch the URL ourselves.
 */
-(void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
	int navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] intValue];
	if (navType == WebNavigationTypeLinkClicked)
	{
		[listener ignore];
		[controller openURLInBrowserWithURL:[request URL]];
	}
	[listener use];
}

/* createWebViewWithRequest
 * Called when the browser wants to create a new window. The request is opened in a new tab.
 */
-(WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	[controller openURLInBrowserWithURL:[request URL]];
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
	return (urlLink != nil) ? [controller contextMenuItemsLink:urlLink defaultMenuItems:defaultMenuItems] : nil;
}

/* initTableView
 * Do all the initialization for the article list table view control
 */
-(void)initTableView
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	// Variable initialization here
	currentFolderId = -1;
	currentArrayOfArticles = nil;
	currentSelectedRow = -1;
	articleListFont = nil;
	
	// Pre-set sort to what was saved in the preferences
	[self setSortColumnIdentifier:[defaults stringForKey:MAPref_SortColumn]];
	sortDirection = [defaults integerForKey:MAPref_SortDirection];
	sortColumnTag = [[db fieldByName:sortColumnIdentifier] tag];
	
	// Initialize the article columns from saved data
	NSArray * dataArray = [defaults arrayForKey:MAPref_ArticleListColumns];
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
	
	// Remember the folder column state
	Field * folderField = [db fieldByName:MA_Field_Folder];
	previousFolderColumnState = [folderField visible];	

	// Dynamically create the popup menu. This is one less thing to
	// explicitly localise in the NIB file.
	NSMenu * articleListMenu = [[NSMenu alloc] init];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(markRead:))];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(markFlagged:))];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(deleteMessage:))];
	[articleListMenu addItem:[NSMenuItem separatorItem]];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(viewSourceHomePage:))];
	[articleListMenu addItem:copyOfMenuWithAction(@selector(viewArticlePage:))];
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
	if (currentSelectedRow != -1)
	{
		Article * theArticle = [currentArrayOfArticles objectAtIndex:currentSelectedRow];
		[controller openURLInBrowser:[theArticle link]];
	}
}

/* showColumnsForFolder
 * Display the columns for the specific folder.
 */
-(void)showColumnsForFolder:(int)folderId
{
	Folder * folder = [db folderFromID:folderId];
	Field * folderField = [db fieldByName:MA_Field_Folder];
	BOOL showFolderColumn;
	
	if (folder && (IsSmartFolder(folder) || IsGroupFolder(folder)))
	{
		previousFolderColumnState = [folderField visible];
		showFolderColumn = YES;
	}
	else
		showFolderColumn = previousFolderColumnState;
	
	if ([folderField visible] != showFolderColumn)
	{
		[folderField setVisible:showFolderColumn];
		[self updateVisibleColumns];
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
	
	// Create the new columns
	for (index = 0; index < count; ++index)
	{
		Field * field = [fields objectAtIndex:index];
		NSString * identifier = [field name];
		BOOL showField;
		
		// Remove each column as we go.
		NSTableColumn * tableColumn = [articleList tableColumnWithIdentifier:identifier];
		if (tableColumn != nil)
		{
			if (index + 1 != count)
				[field setWidth:[tableColumn width]];
			[articleList removeTableColumn:tableColumn];
		}
		
		// Handle condensed layout vs. table layout
		if (tableLayout == MA_Table_Layout)
			showField = [field visible] && [field tag] != MA_FieldID_Headlines;
		else
		{
			showField = [field tag] == MA_FieldID_Headlines ||
			[field tag] == MA_FieldID_Read ||
			[field tag] == MA_FieldID_Flagged ||
			[field tag] == MA_FieldID_Comments;
		}
		
		// Add to the end only those columns that are visible
		if (showField)
		{
			NSTableColumn * newTableColumn = [[NSTableColumn alloc] initWithIdentifier:identifier];
			NSTableHeaderCell * headerCell = [newTableColumn headerCell];
			int tag = [field tag];
			BOOL isResizable = (tag != MA_FieldID_Read && tag != MA_FieldID_Flagged && tag != MA_FieldID_Comments);
			
			// Fix for bug where tableviews with alternating background rows lose their "colour".
			// Only text cells are affected.
			if ([[newTableColumn dataCell] isKindOfClass:[NSTextFieldCell class]])
				[[newTableColumn dataCell] setDrawsBackground:NO];
			
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
	[articleList setHeaderImage:MA_Field_Comments imageName:@"comments_header.tiff"];
	
	// Initialise the sort direction
	[self showSortDirection];	
	
	// In condensed mode, the summary field takes up the whole space
	if (tableLayout == MA_Condensed_Layout)
	{
		[articleList sizeLastColumnToFit];
		[articleList setNeedsDisplay];
	}
}

/* saveTableSettings
 * Save the table column settings, specifically the visibility and width.
 */
-(void)saveTableSettings
{
	NSArray * fields = [db arrayOfFields];
	NSEnumerator * enumerator = [fields objectEnumerator];
	Field * field;
	
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
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:dataArray forKey:MAPref_ArticleListColumns];
	[defaults synchronize];

	// Save the split bar position
	[splitView2 storeLayoutWithName:@"SplitView2Positions"];

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
	
	[topLineDict setObject:articleListFont forKey:NSFontAttributeName];
	[topLineDict setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
	
	[bottomLineDict setObject:articleListFont forKey:NSFontAttributeName];
	[bottomLineDict setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
	
	[selectionDict setObject:articleListFont forKey:NSFontAttributeName];
	[selectionDict setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	
	[self updateArticleListRowHeight];
}

/* updateArticleListRowHeight
 */
-(void)updateArticleListRowHeight
{
	int height = [articleListFont defaultLineHeightForFont];
	int numberOfRowsInCell = (tableLayout == MA_Table_Layout) ? 1: 2;
	[articleList setRowHeight:(height + 3) * numberOfRowsInCell];
}

/* showSortDirection
 * Shows the current sort column and direction in the table.
 */
-(void)showSortDirection
{
	NSTableColumn * sortColumn = [articleList tableColumnWithIdentifier:sortColumnIdentifier];
	NSString * imageName = (sortDirection < 0) ? @"NSDescendingSortIndicator" : @"NSAscendingSortIndicator";
	[articleList setHighlightedTableColumn:sortColumn];
	[articleList setIndicatorImage:[NSImage imageNamed:imageName] inTableColumn:sortColumn];
}

/* sortByIdentifier
 * Sort by the column indicated by the specified column name.
 */
-(void)sortByIdentifier:(NSString *)columnName
{
	if ([sortColumnIdentifier isEqualToString:columnName])
		sortDirection *= -1;
	else
	{
		[articleList setIndicatorImage:nil inTableColumn:[articleList tableColumnWithIdentifier:sortColumnIdentifier]];
		[self setSortColumnIdentifier:columnName];
		sortDirection = 1;
		sortColumnTag = [[db fieldByName:sortColumnIdentifier] tag];
		[[NSUserDefaults standardUserDefaults] setObject:sortColumnIdentifier forKey:MAPref_SortColumn];
	}
	[[NSUserDefaults standardUserDefaults] setInteger:sortDirection forKey:MAPref_SortDirection];
	[self showSortDirection];
	[self refreshFolder:NO];
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
	loadMapFromPath(path, stylePathMappings, YES);
	
	path = [[[NSUserDefaults standardUserDefaults] objectForKey:MAPref_StylesFolder] stringByExpandingTildeInPath];
	loadMapFromPath(path, stylePathMappings, YES);
	
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
				
				NSMutableString * newTemplate = [NSMutableString stringWithCString:[fileData bytes] length:[fileData length]];
				cssStylesheet = [[@"file://localhost" stringByAppendingString:[path stringByAppendingPathComponent:@"stylesheet.css"]] retain];

				// Strip off redundant header that were present in old versions of the
				// Vienna styles.
				[newTemplate replaceString:@"<html>" withString:@""];
				[newTemplate replaceString:@"<head>" withString:@""];
				[newTemplate replaceString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"$CSSFilePath$\" />" withString:@""];
				[newTemplate replaceString:@"<title>$ArticleTitle$</title>" withString:@""];
				[newTemplate replaceString:@"</head>" withString:@""];
				[newTemplate replaceString:@"<body>" withString:@""];
				[newTemplate replaceString:@"</body>" withString:@""];
				[newTemplate replaceString:@"</html>" withString:@""];
				htmlTemplate = [newTemplate retain];

				if (!isAppInitialising)
					[self refreshArticlePane];

				[handle closeFile];
				return YES;
			}
			[handle closeFile];
		}
	}
	return NO;
}

/* handleMinimumFontSizeChange
 * Called when the minimum font size for articles is enabled or disabled, or changed.
 */
-(void)handleMinimumFontSizeChange:(NSNotification *)nc
{
	[self loadMinimumFontSize];
	[self refreshArticlePane];
}

/* loadMinimumFontSize
 * Sets up the web preferences for a minimum font size.
 */
-(void)loadMinimumFontSize
{
	Preferences * prefs = [Preferences standardPreferences];
	if (![prefs enableMinimumFontSize])
		[defaultWebPrefs setMinimumFontSize:1];
	else
	{
		int size = [prefs minimumFontSize];
		[defaultWebPrefs setMinimumFontSize:size];
	}
}

/* mainView
 * Return the primary view of this view.
 */
-(NSView *)mainView
{
	return articleList;
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
-(void)handleGoForward
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
-(void)handleGoBack
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
	switch (keyChar)
	{
		case ' ': //SPACE
		{
			NSView * theView = [[[articleText mainFrame] frameView] documentView];
			NSRect visibleRect;
			
			visibleRect = [theView visibleRect];
			if (visibleRect.origin.y + visibleRect.size.height >= [theView frame].size.height)
				[controller viewNextUnread:self];
			else
				[[[articleText mainFrame] webView] scrollPageDown:self];
			return YES;
		}
	}
	return NO;
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
	[self updateArticleListRowHeight];
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
	
	sortedArrayOfArticles = [currentArrayOfArticles sortedArrayUsingFunction:articleSortHandler context:self];
	NSAssert([sortedArrayOfArticles count] == [currentArrayOfArticles count], @"Lost articles from currentArrayOfArticles during sort");
	[currentArrayOfArticles release];
	currentArrayOfArticles = [[NSArray arrayWithArray:sortedArrayOfArticles] retain];
}

/* articleSortHandler
 */
int articleSortHandler(Article * item1, Article * item2, void * context)
{
	ArticleListView * app = (ArticleListView *)context;
	switch (app->sortColumnTag)
	{
		case MA_FieldID_Folder: {
			Folder * folder1 = [app->db folderFromID:[item1 folderId]];
			Folder * folder2 = [app->db folderFromID:[item2 folderId]];
			return [[folder1 name] caseInsensitiveCompare:[folder2 name]] * app->sortDirection;
		}
			
		case MA_FieldID_Read: {
			NSNumber * n1 = [NSNumber numberWithBool:[item1 isRead]];
			NSNumber * n2 = [NSNumber numberWithBool:[item2 isRead]];
			return [n1 compare:n2] * app->sortDirection;
		}
			
		case MA_FieldID_Flagged: {
			NSNumber * n1 = [NSNumber numberWithBool:[item1 isFlagged]];
			NSNumber * n2 = [NSNumber numberWithBool:[item2 isFlagged]];
			return [n1 compare:n2] * app->sortDirection;
		}
			
		case MA_FieldID_Comments: {
			NSNumber * n1 = [NSNumber numberWithBool:[item1 hasComments]];
			NSNumber * n2 = [NSNumber numberWithBool:[item2 hasComments]];
			return [n1 compare:n2] * app->sortDirection;
		}
			
		case MA_FieldID_Date: {
			NSDate * n1 = [[item1 articleData] objectForKey:MA_Field_Date];
			NSDate * n2 = [[item2 articleData] objectForKey:MA_Field_Date];
			return [n1 compare:n2] * app->sortDirection;
		}
			
		case MA_FieldID_Author: {
			NSString * n1 = [[item1 articleData] objectForKey:MA_Field_Author];
			NSString * n2 = [[item2 articleData] objectForKey:MA_Field_Author];
			return [n1 caseInsensitiveCompare:n2] * app->sortDirection;
		}
			
		case MA_FieldID_Headlines:
		case MA_FieldID_Subject: {
			NSString * n1 = [[item1 articleData] objectForKey:MA_Field_Subject];
			NSString * n2 = [[item2 articleData] objectForKey:MA_Field_Subject];
			return [n1 caseInsensitiveCompare:n2] * app->sortDirection;
		}
	}
	return NSOrderedSame;
}

/* makeRowSelectedAndVisible
 * Selects the specified row in the table and makes it visible by
 * scrolling it to the center of the table.
 */
-(void)makeRowSelectedAndVisible:(int)rowIndex
{
	if (rowIndex == currentSelectedRow)
	{
		[articleList selectRow:rowIndex byExtendingSelection:NO];
		[self refreshArticleAtRow:rowIndex markRead:NO];
	}
	else
	{
		[articleList selectRow:rowIndex byExtendingSelection:NO];
		
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
			[self makeRowSelectedAndVisible:(sortDirection < 0) ? 0 : count - 1];
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

/* search
 * Implement the search action.
 */
-(void)search
{
	[self refreshFolder:YES];
}

/* refreshFolder
 * Refreshes the current folder by applying the current sort or thread
 * logic and redrawing the article list. The selected article is preserved
 * and restored on completion of the refresh.
 */
-(void)refreshFolder:(BOOL)reloadData
{
	NSString * guid = nil;
	
	if (currentSelectedRow >= 0)
		guid = [[[currentArrayOfArticles objectAtIndex:currentSelectedRow] guid] retain];
	if (reloadData)
		[self reloadArrayOfArticles];
	[self setArticleListHeader];
	[self sortArticles];
	[self showSortDirection];
	[articleList reloadData];
	if (guid != nil)
	{
		if (![self scrollToArticle:guid])
			currentSelectedRow = -1;
		else
			[self refreshArticlePane];
	}
	[guid release];
}

/* setArticleListHeader
 * Set the article list header caption to the name of the current folder.
 */
-(void)setArticleListHeader
{
	Folder * folder = [db folderFromID:currentFolderId];
	[articleListHeader setStringValue:[folder name]];
}

/* reloadArrayOfArticles
 * Reload the currentArrayOfArticles from the current folder.
 */
-(void)reloadArrayOfArticles
{
	[currentArrayOfArticles release];
	Folder * folder = [db folderFromID:currentFolderId];
	currentArrayOfArticles = [[folder articlesWithFilter:[controller searchString]] retain];
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

/* selectFolderWithFilter
 * Switches to the specified folder and displays articles filtered by whatever is in
 * the search field.
 */
-(void)selectFolderWithFilter:(int)newFolderId
{
	[db flushFolder:currentFolderId];
	[articleList deselectAll:self];
	currentFolderId = newFolderId;
	[self setArticleListHeader];
	[self showColumnsForFolder:currentFolderId];
	[self reloadArrayOfArticles];
	[self sortArticles];
	[articleList reloadData];
	[self selectArticleAfterReload];
}

/* refreshArticleAtRow
 * Refreshes the article at the specified row.
 */
-(void)refreshArticleAtRow:(int)theRow markRead:(BOOL)markReadFlag
{
	if (currentSelectedRow < 0)
		[[articleText mainFrame] loadHTMLString:@"<HTML></HTML>" baseURL:nil];
	else
	{
		NSAssert(currentSelectedRow < (int)[currentArrayOfArticles count], @"Out of range row index received");
		[self refreshArticlePane];
		
		// If we mark read after an interval, start the timer here.
		[markReadTimer invalidate];
		[markReadTimer release];
		markReadTimer = nil;
		
		float interval = [[Preferences standardPreferences] markReadInterval];
		if (interval > 0 && markReadFlag)
			markReadTimer = [[NSTimer scheduledTimerWithTimeInterval:(double)interval
															  target:self
															selector:@selector(markCurrentRead:)
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
	NSArray * msgArray = [[self markedArticleRange] autorelease];
	int index;

	NSMutableString * htmlText = [[NSMutableString alloc] initWithString:@"<html><head><link rel=\"stylesheet\" type=\"text/css\" href=\""];
	[htmlText appendString:cssStylesheet];
	[htmlText appendString:@"\"/><title>$ArticleTitle$</title></head><body>"];

	for (index = 0; index < [msgArray count]; ++index)
	{
		Article * theArticle = [msgArray objectAtIndex:index];
		Folder * folder = [db folderFromID:[theArticle folderId]];

		// Cache values for things we're going to be plugging into the template and set
		// defaults for things that are missing.
		NSString * articleBody = [theArticle body];
		NSString * articleDate = [[[theArticle date] dateWithCalendarFormat:nil timeZone:nil] friendlyDescription];
		NSString * articleLink = [theArticle link] ? [theArticle link] : @"";
		NSString * articleAuthor = [theArticle author] ? [theArticle author] : @"";
		NSString * articleTitle = [theArticle title] ? [theArticle title] : @"";
		NSString * folderTitle = [folder name] ? [folder name] : @"";
		NSString * folderLink = [folder homePage] ? [folder homePage] : @"";

		// Load the selected HTML template for the current view style and plug in the current
		// article values and style sheet setting.
		NSMutableString * htmlArticle = [[NSMutableString alloc] initWithString:htmlTemplate];
		[htmlArticle replaceString:@"$ArticleLink$" withString:articleLink];
		[htmlArticle replaceString:@"$ArticleTitle$" withString:articleTitle];
		[htmlArticle replaceString:@"$ArticleBody$" withString:articleBody];
		[htmlArticle replaceString:@"$ArticleAuthor$" withString:articleAuthor];
		[htmlArticle replaceString:@"$ArticleDate$" withString:articleDate];
		[htmlArticle replaceString:@"$FeedTitle$" withString:folderTitle];
		[htmlArticle replaceString:@"$FeedLink$" withString:folderLink];

		// Separate each article with a horizontal divider line
		if (index > 0)
			[htmlText appendString:@"<hr><br />"];
		[htmlText appendString:htmlArticle];
		[htmlArticle release];
	}

	// Here we ask the webview to do all the hard work. There's an idiosyncracy in loadHTMLString:baseURL: that it
	// requires a URL to an actual file as the second parameter or it won't work.
	[htmlText appendString:@"</body></html>"];

	Folder * folder = [db folderFromID:currentFolderId];
	NSString * urlString = [folder feedURL] ? [folder feedURL] : @"";
	[[articleText mainFrame] loadHTMLString:htmlText baseURL:[NSURL URLWithString:urlString]];
	[htmlText release];
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
	if ([[aTableColumn identifier] isEqualToString:MA_Field_Folder])
	{
		Folder * folder = [db folderFromID:[theArticle folderId]];
		return [folder name];
	}
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
	if ([[aTableColumn identifier] isEqualToString:MA_Field_Headlines])
	{
		NSMutableAttributedString * theAttributedString = [[NSMutableAttributedString alloc] init];
		BOOL isSelectedRow = [aTableView isRowSelected:rowIndex] && ([[NSApp mainWindow] firstResponder] == aTableView);
		NSDictionary * topLineDictPtr = (isSelectedRow ? selectionDict : topLineDict);
		NSDictionary * bottomLineDictPtr = (isSelectedRow ? selectionDict : bottomLineDict);
		
		NSAttributedString * topString = [[NSAttributedString alloc] initWithString:[theArticle title] attributes:topLineDictPtr];
		[theAttributedString appendAttributedString:topString];
		[topString release];

		// Create the summary line that appears below the title.
		Folder * folder = [db folderFromID:[theArticle folderId]];
		NSCalendarDate * anDate = [[theArticle date] dateWithCalendarFormat:nil timeZone:nil];
		NSMutableString * summaryString = [NSMutableString stringWithFormat:@"\n%@ - %@", [folder name], [anDate friendlyDescription]];
		if (![[theArticle author] isBlank])
			[summaryString appendFormat:@" - %@", [theArticle author]];
		
		NSAttributedString * bottomString = [[NSAttributedString alloc] initWithString:summaryString attributes:bottomLineDictPtr];
		[theAttributedString appendAttributedString:bottomString];
		[bottomString release];
		return [theAttributedString autorelease];
	}
	return [[theArticle articleData] objectForKey:[aTableColumn identifier]];
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
 * Handle the selection changing in the table view.
 */
-(void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	currentSelectedRow = [articleList selectedRow];
	[self refreshArticleAtRow:currentSelectedRow markRead:!isAppInitialising];
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
	NSTableColumn * tableColumn = [[notification userInfo] objectForKey:@"NSTableColumn"];
	Field * field = [db fieldByName:[tableColumn identifier]];
	int oldWidth = [[[notification userInfo] objectForKey:@"NSOldWidth"] intValue];
	
	if (oldWidth != [tableColumn width])
	{
		[field setWidth:[tableColumn width]];
		[self saveTableSettings];
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
	[pboard declareTypes:[NSArray arrayWithObjects:RSSItemType, NSStringPboardType, NSHTMLPboardType, nil] owner:self];
	
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
	[pboard setPropertyList:arrayOfArticles forType:RSSItemType];
	[pboard setString:fullHTMLText forType:NSHTMLPboardType];
	[pboard setString:fullPlainText forType:NSStringPboardType];
	
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
	NSArray * articleArray = nil;
	if ([articleList numberOfSelectedRows] > 0)
	{
		NSEnumerator * enumerator = [articleList selectedRowEnumerator];
		NSMutableArray * newArray = [[NSMutableArray alloc] init];
		NSNumber * rowIndex;
		
		while ((rowIndex = [enumerator nextObject]) != nil)
			[newArray addObject:[currentArrayOfArticles objectAtIndex:[rowIndex intValue]]];
		articleArray = [newArray retain];
		[newArray release];
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
			if ([theArticle folderId] == currentFolderId)
				[arrayCopy removeObject:theArticle];
		}
		else
		{
			if ([theArticle folderId] == currentFolderId)
				[arrayCopy addObject:theArticle];
		}
	}
	[db commitTransaction];
	[currentArrayOfArticles release];
	currentArrayOfArticles = arrayCopy;
	
	// If we've added articles back to the array, we need to resort to put
	// them back in the right place.
	if (!deleteFlag)
		[self sortArticles];
	
	// If any of the articles we deleted were unread then the
	// folder's unread count just changed.
	if (needFolderRedraw)
		[foldersTree updateFolder:currentFolderId recurseToParents:YES];
	
	// Compute the new place to put the selection
	if (currentSelectedRow >= (int)[currentArrayOfArticles count])
		currentSelectedRow = [currentArrayOfArticles count] - 1;
	[self makeRowSelectedAndVisible:currentSelectedRow];
	[articleList reloadData];
	
	// Read and/or unread count may have changed
	if (needFolderRedraw)
		[controller showUnreadCountOnApplicationIcon];
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
	
	// Blow away the undo stack here since undo actions may refer to
	// articles that have been deleted. This is a bit of a cop-out but
	// it's the easiest approach for now.
	[controller clearUndoStack];
	
	// If any of the articles we deleted were unread then the
	// folder's unread count just changed.
	if (needFolderRedraw)
		[foldersTree updateFolder:currentFolderId recurseToParents:YES];
	
	// Compute the new place to put the selection
	if (currentSelectedRow >= (int)[currentArrayOfArticles count])
		currentSelectedRow = [currentArrayOfArticles count] - 1;
	[self makeRowSelectedAndVisible:currentSelectedRow];
	[articleList reloadData];
	
	// Read and/or unread count may have changed
	if (needFolderRedraw)
		[controller showUnreadCountOnApplicationIcon];
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
	NSEnumerator * enumerator = [articleArray objectEnumerator];
	Article * theArticle;
	int lastFolderId = -1;
	int folderId;
	
	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markReadUndoAction = readFlag ? @selector(markUnreadUndo:) : @selector(markReadUndo:);
	[undoManager registerUndoWithTarget:self selector:markReadUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Mark Read", nil)];
	
	[markReadTimer invalidate];
	[markReadTimer release];
	markReadTimer = nil;

	[db beginTransaction];
	while ((theArticle = [enumerator nextObject]) != nil)
	{
		folderId = [theArticle folderId];
		[db markArticleRead:folderId guid:[theArticle guid] isRead:readFlag];
		if (folderId != currentFolderId)
		{
			[theArticle markRead:readFlag];
			[db flushFolder:folderId];
		}
		if (folderId != lastFolderId && lastFolderId != -1)
			[foldersTree updateFolder:lastFolderId recurseToParents:YES];
		lastFolderId = folderId;
	}
	[db commitTransaction];
	[articleList reloadData];
	
	if (lastFolderId != -1)
		[foldersTree updateFolder:lastFolderId recurseToParents:YES];
	[foldersTree updateFolder:currentFolderId recurseToParents:YES];
	
	// The info bar has a count of unread articles so we need to
	// update that.
	[controller showUnreadCountOnApplicationIcon];
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
-(void)markAllReadByArray:(NSArray *)folderArray
{
	NSArray * refArray = [self wrappedMarkAllReadInArray:folderArray];
	if (refArray != nil && [refArray count] > 0)
	{
		NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
		[undoManager registerUndoWithTarget:self selector:@selector(markAllReadUndo:) object:refArray];
		[undoManager setActionName:NSLocalizedString(@"Mark All Read", nil)];
	}
	[controller showUnreadCountOnApplicationIcon];
}

/* wrappedMarkAllReadInArray
 * Given an array of folders, mark all the articles in those folders as read and
 * return a reference array listing all the articles that were actually marked.
 */
-(NSArray *)wrappedMarkAllReadInArray:(NSArray *)folderArray
{
	NSMutableArray * refArray = [NSMutableArray array];
	NSEnumerator * enumerator = [folderArray objectEnumerator];
	Folder * folder;
	
	while ((folder = [enumerator nextObject]) != nil)
	{
		int folderId = [folder itemId];
		if (IsGroupFolder(folder))
		{
			[refArray addObjectsFromArray:[self wrappedMarkAllReadInArray:[db arrayOfFolders:folderId]]];
			if (folderId == currentFolderId)
				[self refreshFolder:YES];
		}
		else if (!IsSmartFolder(folder))
		{
			[refArray addObjectsFromArray:[db arrayOfUnreadArticles:folderId]];
			if ([db markFolderRead:folderId])
			{
				[foldersTree updateFolder:folderId recurseToParents:YES];
				if (folderId == currentFolderId)
					[articleList reloadData];
			}
		}
		else
		{
			// For smart folders, we only mark all read the current folder to
			// simplify things.
			if (folderId == currentFolderId)
				[self markReadByArray:currentArrayOfArticles readFlag:YES];
		}
	}
	return refArray;
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
				[self refreshFolder:YES];
		}
		lastFolderId = folderId;
	}
	[db commitTransaction];
	
	if (lastFolderId != -1)
	{
		[foldersTree updateFolder:lastFolderId recurseToParents:YES];
		if (lastFolderId == currentFolderId)
			[self refreshFolder:YES];
	}

	// The info bar has a count of unread articles so we need to
	// update that.
	[controller showUnreadCountOnApplicationIcon];
}

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
	[markReadTimer release];
	[currentArrayOfArticles release];
	[backtrackArray release];
	[articleListFont release];
	[defaultWebPrefs release];
	[guidOfArticleToSelect release];
	[selectionDict release];
	[topLineDict release];
	[bottomLineDict release];
	[super dealloc];
}
@end
