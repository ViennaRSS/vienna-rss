//
//  ArticleListView.m
//  Vienna
//
//  Created by Steve on 8/27/05.
//  Copyright (c) 2004-2017 Steve Palmer and Vienna contributors. All rights reserved.
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

// Handle the Horizontal (also known as Report) and Vertical (also known as Condensed) layouts

#import "ArticleListView.h"
#import "Preferences.h"
#import "Constants.h"
#import "DateFormatterExtension.h"
#import "AppController.h"
#import "ArticleController.h"
#import "MessageListView.h"
#import "ArticleView.h"
#import "StringExtensions.h"
#import "HelperFunctions.h"
#import "ArticleRef.h"
#import "Field.h"
#import "BrowserPane.h"
#import "ProgressTextCell.h"
#import "Article.h"
#import "Folder.h"
#import "EnclosureView.h"
#import "BrowserView.h"
#import "Database.h"
#import "Vienna-Swift.h"

@interface ArticleListView ()

@property (nonatomic) OverlayStatusBar *statusBar;
@property (weak, nonatomic) IBOutlet NSStackView *contentStackView;

-(void)initTableView;
-(BOOL)copyTableSelection:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard;
-(void)setTableViewFont;
-(void)showSortDirection;
-(void)handleReadingPaneChange:(NSNotificationCenter *)nc;
-(BOOL)viewNextUnreadInCurrentFolder:(NSInteger)currentRow;
-(void)markCurrentRead:(NSTimer *)aTimer;
-(void)refreshImmediatelyArticleAtCurrentRow;
-(void)refreshArticleAtCurrentRow;
-(void)makeRowSelectedAndVisible:(NSInteger)rowIndex;
-(void)updateArticleListRowHeight;
-(void)setOrientation:(NSInteger)newLayout;
-(void)showEnclosureView;
-(void)hideEnclosureView;
-(void)setError:(NSError *)newError;
-(void)handleError:(NSError *)error withDataSource:(WebDataSource *)dataSource;
-(void)endMainFrameLoad;

@end

@implementation ArticleListView

/* initWithFrame
 * Initialise our view.
 */
-(instancetype)initWithFrame:(NSRect)frame
{
    self= [super initWithFrame:frame];
    if (self)
	{
        isChangingOrientation = NO;
		isInTableInit = NO;
		blockSelectionHandler = NO;
		markReadTimer = nil;
		lastError = nil;
		isCurrentPageFullHTML = NO;
		isLoadingHTMLArticle = NO;
		currentURL = nil;
    }
    return self;
}

/* awakeFromNib
 * Do things that only make sense once the NIB is loaded.
 */
-(void)awakeFromNib
{
	// Register for notification
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleArticleListFontChange:) name:@"MA_Notify_ArticleListFontChange" object:nil];
	[nc addObserver:self selector:@selector(handleReadingPaneChange:) name:@"MA_Notify_ReadingPaneChange" object:nil];
	[nc addObserver:self selector:@selector(handleLoadFullHTMLChange:) name:@"MA_Notify_LoadFullHTMLChange" object:nil];
	[nc addObserver:self selector:@selector(handleRefreshArticle:) name:@"MA_Notify_ArticleViewChange" object:nil];

	// Make us the frame load and UI delegate for the web view
	articleText.UIDelegate = self;
	articleText.frameLoadDelegate = self;
	[articleText setOpenLinksInNewBrowser:YES];

	[articleText setMaintainsBackForwardList:NO];
	[articleText.backForwardList setPageCacheSize:0];

    [self initialiseArticleView];
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
	
	// Create report and condensed view attribute dictionaries
	NSMutableParagraphStyle * style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	style.lineBreakMode = NSLineBreakByTruncatingTail;
	style.tighteningFactorForTruncation = 0.0;
	
	reportCellDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, nil];
	unreadReportCellDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, nil];
		
	selectionDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor whiteColor], NSForegroundColorAttributeName, nil];
	unreadTopLineDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor blackColor], NSForegroundColorAttributeName, nil];
	topLineDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor blackColor], NSForegroundColorAttributeName, nil];
	unreadTopLineSelectionDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor whiteColor], NSForegroundColorAttributeName, nil];
	middleLineDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor blueColor], NSForegroundColorAttributeName, nil];
	linkLineDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor blueColor], NSForegroundColorAttributeName, nil];
	bottomLineDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor grayColor], NSForegroundColorAttributeName, nil];
	
	
	// Set the reading pane orientation
	[self setOrientation:prefs.layout];
	
	// Initialise the article list view
	[self initTableView];

	// Make sure we skip the column filter button in the Tab order
	articleList.nextKeyView = articleText;
	
	// Done initialising
	isAppInitialising = NO;

    [NSUserDefaults.standardUserDefaults addObserver:self
                                          forKeyPath:MAPref_ShowStatusBar
                                             options:NSKeyValueObservingOptionInitial
                                             context:nil];
}

// MARK: - WebUIDelegate methods


/* createWebViewWithRequest
 * Called when the browser wants to create a new window. The request is opened in a new tab.
 */
-(WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	[self.controller openURL:request.URL inPreferredBrowser:YES];
	// Change this to handle modifier key?
	// Is this covered by the webView policy?
	return nil;
}

/* runJavaScriptAlertPanelWithMessage
 * Called when the browser wants to display a JavaScript alert panel containing the specified message.
 */
- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = NSLocalizedString(@"JavaScript", @"");
    alert.informativeText = message;
    [alert runModal];
}

/* runJavaScriptConfirmPanelWithMessage
 * Called when the browser wants to display a JavaScript confirmation panel with the specified message.
 */
- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = NSLocalizedString(@"JavaScript", @"");
    alert.informativeText = message;
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"Title of a button on an alert")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Title of a button on an alert")];
    NSModalResponse alertResponse = [alert runModal];

	return alertResponse == NSAlertFirstButtonReturn;
}

/* mouseDidMoveOverElement
 * Called from the webview when the user positions the mouse over an element. If it's a link
 * then echo the URL to the status bar like Safari does.
 */
- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation
  modifierFlags:(NSUInteger)modifierFlags {
    if (self.statusBar) {
        NSURL *url = [elementInformation valueForKey:@"WebElementLinkURL"];
        self.statusBar.label = url.absoluteString;
    }
}

/* contextMenuItemsForElement
 * Creates a new context menu for our article's web view.
 */
-(NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	// If this is an URL link, do the link-specific items.
	NSURL * urlLink = [element valueForKey:WebElementLinkURLKey];
	if (urlLink != nil)
		return [self.controller contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
	
	// If we have a full HTML page then do the additional web-page specific items.
	if (isCurrentPageFullHTML)
	{
		WebFrame * frameKey = [element valueForKey:WebElementFrameKey];
		if (frameKey != nil)
			return [self.controller contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
	}
	
	// Remove the reload menu item if we don't have a full HTML page.
	if (!isCurrentPageFullHTML)
	{
		NSMutableArray * newDefaultMenu = [[NSMutableArray alloc] init];
		NSInteger count = defaultMenuItems.count;
		NSInteger index;
		
		// Copy over everything but the reload menu item, which we can't handle if
		// this is not a full HTML page since we don't have an URL.
		for (index = 0; index < count; index++)
		{
			NSMenuItem * menuItem = defaultMenuItems[index];
			if (menuItem.tag != WebMenuItemTagReload)
				[newDefaultMenu addObject:menuItem];
		}
		
		// If we still have some menu items then use that for the new default menu, otherwise
		// set the default items to nil as we may have removed all the items.
		if (newDefaultMenu.count > 0)
			defaultMenuItems = newDefaultMenu;
		else
        {
			defaultMenuItems = nil;
        }
    }

	// Return the default menu items.
    return defaultMenuItems;
}

/* initTableView
 * Do all the initialization for the article list table view control
 */
-(void)initTableView
{
	Preferences * prefs = [Preferences standardPreferences];
	
	// Variable initialization here
	articleListFont = nil;
	articleListUnreadFont = nil;

	// Initialize the article columns from saved data
	NSArray * dataArray = [prefs arrayForKey:MAPref_ArticleListColumns];
	Database * db = [Database sharedManager];
	Field * field;
	NSUInteger  index;
	
	for (index = 0; index < dataArray.count;)
	{
		NSString * name;
		NSInteger width = 100;
		BOOL visible = NO;
		
		name = dataArray[index++];
		if (index < dataArray.count)
			visible = [dataArray[index++] integerValue] == YES;
		if (index < dataArray.count)
			width = [dataArray[index++] integerValue];
		
		field = [db fieldByName:name];
		field.visible = visible;
		field.width = width;
	}
	
	// Set the default fonts
	[self setTableViewFont];
	
	// Get the default list of visible columns
	[self updateVisibleColumns];
	
	// In condensed mode, the summary field takes up the whole space.
	articleList.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;

	NSMenu *articleListMenu = [[NSMenu alloc] init];

	[articleListMenu addItemWithTitle:NSLocalizedString(@"Mark Read", @"Title of a menu item")
							   action:@selector(markRead:)
						keyEquivalent:@""];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Mark Unread", @"Title of a menu item")
							   action:@selector(markUnread:)
						keyEquivalent:@""];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Mark Flagged", @"Title of a menu item")
							   action:@selector(markFlagged:)
						keyEquivalent:@""];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Delete Article", @"Title of a menu item")
							   action:@selector(deleteMessage:)
						keyEquivalent:@""];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Restore Article", @"Title of a menu item")
							   action:@selector(restoreMessage:)
						keyEquivalent:@""];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Download Enclosure", @"Title of a menu item")
							   action:@selector(downloadEnclosure:)
						keyEquivalent:@""];
	[articleListMenu addItem:[NSMenuItem separatorItem]];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Open Subscription Home Page", @"Title of a menu item")
							   action:@selector(viewSourceHomePage:)
						keyEquivalent:@""];
	NSMenuItem *openFeedInBrowser = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Subscription Home Page in External Browser", @"Title of a menu item")
															   action:@selector(viewSourceHomePageInAlternateBrowser:)
														keyEquivalent:@""];
	openFeedInBrowser.keyEquivalentModifierMask = NSAlternateKeyMask;
	openFeedInBrowser.alternate = YES;
	[articleListMenu addItem:openFeedInBrowser];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Open Article Page", @"Title of a menu item")
							   action:@selector(viewArticlePages:)
						keyEquivalent:@""];
	NSMenuItem *openItemInBrowser = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Article Page in External Browser", @"Title of a menu item")
															   action:@selector(viewArticlePagesInAlternateBrowser:)
														keyEquivalent:@""];
	openItemInBrowser.keyEquivalentModifierMask = NSAlternateKeyMask;
	openItemInBrowser.alternate = YES;
	[articleListMenu addItem:openItemInBrowser];

	articleList.menu = articleListMenu;

	// Set the target for double-click actions
	articleList.doubleAction = @selector(doubleClickRow:);
	articleList.action = @selector(singleClickRow:);
	[articleList setDelegate:self];
	[articleList setDataSource:self];
	articleList.target = self;
    [articleList accessibilitySetOverrideValue:NSLocalizedString(@"Articles", nil) forAttribute:NSAccessibilityDescriptionAttribute];
}

/* singleClickRow
 * Handle a single click action. If the click was in the read or flagged column then
 * treat it as an action to mark the article read/unread or flagged/unflagged. Later
 * trap the comments column and expand/collapse. If the click lands on the enclosure
 * colum, download the associated enclosure.
 */
-(IBAction)singleClickRow:(id)sender
{
	NSInteger row = articleList.clickedRow;
	NSInteger column = articleList.clickedColumn;
	NSArray * allArticles = self.controller.articleController.allArticles;
	
	if (row >= 0 && row < (NSInteger)allArticles.count)
	{
		NSArray * columns = articleList.tableColumns;
		if (column >= 0 && column < (NSInteger)columns.count)
		{
			Article * theArticle = allArticles[row];
			NSString * columnName = ((NSTableColumn *)columns[column]).identifier;
			if ([columnName isEqualToString:MA_Field_Read])
			{
				[self.controller.articleController markReadByArray:@[theArticle] readFlag:!theArticle.read];
				return;
			}
			if ([columnName isEqualToString:MA_Field_Flagged])
			{
				[self.controller.articleController markFlaggedByArray:@[theArticle] flagged:!theArticle.flagged];
				return;
			}
			if ([columnName isEqualToString:MA_Field_HasEnclosure])
			{
				// TODO: Do interesting stuff with the enclosure here.
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
	NSInteger clickedRow = articleList.clickedRow;
	if (clickedRow != -1)
	{
		Article * theArticle = self.controller.articleController.allArticles[clickedRow];
		[self.controller openURLFromString:theArticle.link inPreferredBrowser:YES];
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
	NSInteger index;
	NSMenu * articleListMenu = articleList.menu;
	if (articleListMenu == nil)
		return;
	mainMenuItem = menuItemWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	if (mainMenuItem != nil)
	{
		index = [articleListMenu indexOfItemWithTarget:nil andAction:@selector(viewSourceHomePageInAlternateBrowser:)];
		if (index >= 0)
		{
			contextualMenuItem = [articleListMenu itemAtIndex:index];
			contextualMenuItem.title = mainMenuItem.title;
		}
	}
	mainMenuItem = menuItemWithAction(@selector(viewArticlePagesInAlternateBrowser:));
	if (mainMenuItem != nil)
	{
		index = [articleListMenu indexOfItemWithTarget:nil andAction:@selector(viewArticlePagesInAlternateBrowser:)];
		if (index >= 0)
		{
			contextualMenuItem = [articleListMenu itemAtIndex:index];
			contextualMenuItem.title = mainMenuItem.title;
		}
	}
}

/* ensureSelectedArticle
 * Ensure that there is a selected article and that it is visible.
 */
-(void)ensureSelectedArticle
{
    if (articleList.selectedRow == -1) {
        [self makeRowSelectedAndVisible:0];
    } else {
        [articleList scrollRowToVisible:articleList.selectedRow];
    }
}

/* updateVisibleColumns
 * Iterates through the array of visible columns and makes them
 * visible or invisible as needed.
 */
-(void)updateVisibleColumns
{
	NSArray * fields = [[Database sharedManager] arrayOfFields];
	NSInteger count = fields.count;
	NSInteger index;

	// Save current selection
	NSIndexSet * selArray = articleList.selectedRowIndexes;
	
	// Mark we're doing an update of the tableview
	isInTableInit = YES;
	[articleList setAutosaveName:nil];
	
	[self updateArticleListRowHeight];
	
	// Create the new columns
	for (index = 0; index < count; ++index)
	{
		Field * field = fields[index];
		NSString * identifier = field.name;
		NSInteger tag = field.tag;
		BOOL showField;
		
		// Handle which fields can be visible in the condensed (vertical) layout
		// versus the report (horizontal) layout
		if (tableLayout == MA_Layout_Report)
			showField = field.visible && tag != ArticleFieldIDHeadlines && tag != ArticleFieldIDComments;
		else
		{
			showField = NO;
			if (tag == ArticleFieldIDRead || tag == ArticleFieldIDFlagged || tag == ArticleFieldIDHasEnclosure)
				showField = field.visible;
			if (tag == ArticleFieldIDHeadlines)
				showField = YES;
		}

		// Set column hidden or shown
		NSTableColumn *col = [articleList tableColumnWithIdentifier:identifier];
		col.hidden = !showField;

		// Add to the end only those columns which should be visible
		// and aren't created yet
		if (showField && [articleList columnWithIdentifier:identifier]==-1)
		{
			NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:identifier];
			
			// Replace the normal text field cell with a progress text cell so we can
			// display a progress indicator when loading HTML pages. NOTE: This is handled
			// in willDisplayCell:forTableColumn:row: where it sets the inProgress flag.
			// We need to use a different column for condensed layout vs. table layout.
			BOOL isProgressColumn = NO;
			if (tableLayout == MA_Layout_Report && [column.identifier isEqualToString:MA_Field_Subject])
				isProgressColumn = YES;
			if (tableLayout == MA_Layout_Condensed && [column.identifier isEqualToString:MA_Field_Headlines])
				isProgressColumn = YES;
			
			if (isProgressColumn)
			{
				ProgressTextCell * progressCell;
				
				progressCell = [[ProgressTextCell alloc] init];
				column.dataCell = progressCell;
			}
			else
			{
				BJRVerticallyCenteredTextFieldCell * cell;

				cell = [[BJRVerticallyCenteredTextFieldCell alloc] init];
				column.dataCell = cell;
			}

			BOOL isResizable = (tag != ArticleFieldIDRead && tag != ArticleFieldIDFlagged && tag != ArticleFieldIDComments && tag != ArticleFieldIDHasEnclosure);
			column.resizingMask = (isResizable ? NSTableColumnUserResizingMask : NSTableColumnNoResizing);
			// the headline column is auto-resizable
			column.resizingMask = column.resizingMask | ([column.identifier isEqualToString:MA_Field_Headlines] ? NSTableColumnAutoresizingMask : 0);

			// Set the header attributes.
			NSTableHeaderCell * headerCell = column.headerCell;
			headerCell.title = field.displayName;
			
			// Set the other column atributes.
			[column setEditable:NO];
			column.minWidth = 10;
			[articleList addTableColumn:column];
		}

		// Set column size for visible columns
		if (showField)
		{
			NSTableColumn *column = [articleList tableColumnWithIdentifier:identifier];
			column.width = field.width;
		}
	}
	
	// Set the images for specific header columns
	[articleList setHeaderImage:MA_Field_Read imageName:@"unread_header.tiff"];
	[articleList setHeaderImage:MA_Field_Flagged imageName:@"flagged_header.tiff"];
	[articleList setHeaderImage:MA_Field_HasEnclosure imageName:@"enclosure_header.tiff"];

	// Initialise the sort direction
	[self showSortDirection];	
	
	// Put the selection back
	[articleList selectRowIndexes:selArray byExtendingSelection:NO];
	
	if (tableLayout == MA_Layout_Report)
		articleList.autosaveName = @"Vienna3ReportLayoutColumns";
	else
		articleList.autosaveName = @"Vienna3CondensedLayoutColumns";
	[articleList setAutosaveTableColumns:YES];

	// Done
	isInTableInit = NO;
}

/* saveTableSettings
 * Save the table column settings, specifically the visibility and width.
 */
-(void)saveTableSettings
{
	Preferences * prefs = [Preferences standardPreferences];
	
	// Remember the current folder and article
	NSString * guid = [self.selectedArticle guid];
	[prefs setInteger:self.controller.articleController.currentFolderId forKey:MAPref_CachedFolderID];
	[prefs setString:(guid != nil ? guid : @"") forKey:MAPref_CachedArticleGUID];

	// An array we need for the settings
	NSMutableArray * dataArray = [[NSMutableArray alloc] init];
	
	// Create the new columns
	
	for (Field * field in  [[Database sharedManager] arrayOfFields])
	{
		[dataArray addObject:field.name];
		[dataArray addObject:@(field.visible)];
		[dataArray addObject:@(field.width)];
	}
	
	// Save these to the preferences
	[prefs setObject:dataArray forKey:MAPref_ArticleListColumns];

	// We're done
}

/* setTableViewFont
 * Gets the font for the article list and adjusts the table view
 * row height to properly display that font.
 */
-(void)setTableViewFont
{

	Preferences * prefs = [Preferences standardPreferences];
	articleListFont = [NSFont fontWithName:prefs.articleListFont size:prefs.articleListFontSize];
	articleListUnreadFont = [prefs boolForKey:MAPref_ShowUnreadArticlesInBold] ? [[NSFontManager sharedFontManager] convertWeight:YES ofFont:articleListFont] : articleListFont;

	reportCellDict[NSFontAttributeName] = articleListFont;
	unreadReportCellDict[NSFontAttributeName] = articleListUnreadFont;

	topLineDict[NSFontAttributeName] = articleListFont;
	unreadTopLineDict[NSFontAttributeName] = articleListUnreadFont;
	middleLineDict[NSFontAttributeName] = articleListFont;
	linkLineDict[NSFontAttributeName] = articleListFont;
	bottomLineDict[NSFontAttributeName] = articleListFont;
	selectionDict[NSFontAttributeName] = articleListFont;
	unreadTopLineSelectionDict[NSFontAttributeName] = articleListUnreadFont;
	
	[self updateArticleListRowHeight];
}

/* updateArticleListRowHeight
 * Compute the number of rows that the current view requires. For table layout, there's just
 * one line. For condensed layout, the number of lines depends on which fields are visible but
 * there's always a minimum of one line anyway.
 */
-(void)updateArticleListRowHeight
{
	Database * db = [Database sharedManager];
	CGFloat height = [APPCONTROLLER.layoutManager defaultLineHeightForFont:articleListFont];
	NSInteger numberOfRowsInCell;

	if (tableLayout == MA_Layout_Report)
		numberOfRowsInCell = 1;
	else
	{
		numberOfRowsInCell = 0;
		if ([db fieldByName:MA_Field_Subject].visible)
			++numberOfRowsInCell;
		if ([db fieldByName:MA_Field_Folder].visible || [db fieldByName:MA_Field_Date].visible || [db fieldByName:MA_Field_Author].visible)
			++numberOfRowsInCell;
		if ([db fieldByName:MA_Field_Link].visible)
			++numberOfRowsInCell;
		if ([db fieldByName:MA_Field_Summary].visible)
			++numberOfRowsInCell;
		if (numberOfRowsInCell == 0)
			++numberOfRowsInCell;
	}
	articleList.rowHeight = (height + 2.0f) * (CGFloat)numberOfRowsInCell;
}

/* showSortDirection
 * Shows the current sort column and direction in the table.
 */
-(void)showSortDirection
{
	NSString * sortColumnIdentifier = self.controller.articleController.sortColumnIdentifier;
	
	for (NSTableColumn * column in articleList.tableColumns)
	{
		if ([column.identifier isEqualToString:sortColumnIdentifier])
		{
			NSString * imageName = ([[Preferences standardPreferences].articleSortDescriptors[0] ascending]) ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator";
			articleList.highlightedTableColumn = column;
			[articleList setIndicatorImage:[NSImage imageNamed:imageName] inTableColumn:column];
		}
		else
		{
			// Remove any existing image in the column header.
			[articleList setIndicatorImage:nil inTableColumn:column];
		}
	}
}

/* scrollToArticle
 * Moves the selection to the specified article.
 */
-(void)scrollToArticle:(NSString *)guid
{
	if (guid != nil)
	{
		NSInteger rowIndex = 0;
		for (Article * thisArticle in self.controller.articleController.allArticles)
		{
			if ([thisArticle.guid isEqualToString:guid])
			{
				[self makeRowSelectedAndVisible:rowIndex];
				return;
			}
			++rowIndex;
		}
	}

	[articleList deselectAll:self];
	[self refreshArticleAtCurrentRow];
}

/* mainView
 * Return the primary view of this view.
 */
-(NSView *)mainView
{
	return articleList;
}

/* webView
 * Returns the webview used to display the articles
 */
-(WebView *)webView
{
	return articleText;
}

/* canDeleteMessageAtRow
 * Returns YES if the message at the specified row can be deleted, otherwise NO.
 */
-(BOOL)canDeleteMessageAtRow:(NSInteger)row
{
	return articleList.window.visible && (self.selectedArticle != nil) && ![Database sharedManager].readOnly;
}

/* canGoForward
 * Return TRUE if we can go forward in the backtrack queue.
 */
-(BOOL)canGoForward
{
	return self.controller.articleController.canGoForward;
}

/* canGoBack
 * Return TRUE if we can go backward in the backtrack queue.
 */
-(BOOL)canGoBack
{
	return self.controller.articleController.canGoBack;
}

/* handleGoForward
 * Move forward through the backtrack queue.
 */
-(IBAction)handleGoForward:(id)sender
{
	[self.controller.articleController goForward];
}

/* handleGoBack
 * Move backward through the backtrack queue.
 */
-(IBAction)handleGoBack:(id)sender
{
	[self.controller.articleController goBack];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
};

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger)flags
{
	return [self.controller handleKeyDown:keyChar withFlags:flags];
}

/* selectedArticle
 * Returns the selected article, or nil if no article is selected.
 */
-(Article *)selectedArticle
{
	NSInteger currentSelectedRow = articleList.selectedRow;
	return (currentSelectedRow >= 0 && currentSelectedRow < self.controller.articleController.allArticles.count) ? self.controller.articleController.allArticles[currentSelectedRow] : nil;
}

/* printDocument
 * Print the active article.
 */
-(void)printDocument:(id)sender
{
	[articleText printDocument:sender];
}

/* setError
 * Save the most recent error instance.
 */
-(void)setError:(NSError *)newError
{
	lastError = newError;
}

/* handleArticleListFontChange
 * Called when the user changes the article list font and/or size in the Preferences
 */
-(void)handleArticleListFontChange:(NSNotification *)note
{
	[self setTableViewFont];
	if (self == self.controller.articleController.mainArticleView)
	{
		[articleList reloadData];
	}
}

/* handleLoadFullHTMLChange
 * Called when the user changes the folder setting to load the article in full HTML.
 */
-(void)handleLoadFullHTMLChange:(NSNotification *)note
{
	if (self == self.controller.articleController.mainArticleView)
		[self refreshArticlePane];
}

/* handleReadingPaneChange
 * Respond to the change to the reading pane orientation.
 */
-(void)handleReadingPaneChange:(NSNotificationCenter *)nc
{
	if (self == self.controller.articleController.mainArticleView)
	{
		[self setOrientation:[Preferences standardPreferences].layout];
		[self updateVisibleColumns];
		[articleList reloadData];
	}
}

/* setOrientation
 * Adjusts the article view orientation and updates the article list row
 * height to accommodate the summary view
 */
-(void)setOrientation:(NSInteger)newLayout
{
	isChangingOrientation = YES;
	tableLayout = newLayout;
	splitView2.autosaveName = nil;
	splitView2.vertical = (newLayout == MA_Layout_Condensed);
	splitView2.dividerStyle = (splitView2.vertical ? NSSplitViewDividerStyleThin : NSSplitViewDividerStylePaneSplitter);
	splitView2.autosaveName = (newLayout == MA_Layout_Condensed ? @"Vienna3SplitView2CondensedLayout" : @"Vienna3SplitView2ReportLayout");
	[splitView2 display];
	isChangingOrientation = NO;
}

/* makeRowSelectedAndVisible
 * Selects the specified row in the table and makes it visible by
 * scrolling it to the center of the table.
 */
-(void)makeRowSelectedAndVisible:(NSInteger)rowIndex
{
	if (self.controller.articleController.allArticles.count == 0u)
	{
		[articleList deselectAll:self];
	}
	else if (rowIndex != [articleList selectedRow])
	{
		[articleList selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];

		// make sure our current selection is visible
		[articleList scrollRowToVisible:rowIndex];
		// then try to center it in the list
		NSInteger pageSize = [articleList rowsInRect:articleList.visibleRect].length;
		NSInteger lastRow = articleList.numberOfRows - 1;
		NSInteger visibleRow = rowIndex + (pageSize / 2);

		if (visibleRow > lastRow)
			visibleRow = lastRow;
		[articleList scrollRowToVisible:visibleRow];
	}
}

/*
 * viewNextUnreadInFolder
 * Search the following unread article in the current folder
 * and select it if found
 */
-(BOOL)viewNextUnreadInFolder
{
	return [self viewNextUnreadInCurrentFolder:([articleList selectedRow] + 1)];
}

/* viewNextUnreadInCurrentFolder
 * Select the next unread article in the current folder after currentRow.
 */
-(BOOL)viewNextUnreadInCurrentFolder:(NSInteger)currentRow
{
	if (currentRow < 0)
		currentRow = 0;
	
	NSArray * allArticles = self.controller.articleController.allArticles;
	NSInteger totalRows = allArticles.count;
	Article * theArticle;
	while (currentRow < totalRows)
	{
		theArticle = allArticles[currentRow];
		if (!theArticle.read)
		{
			[self makeRowSelectedAndVisible:currentRow];
			return YES;
		}
		++currentRow;
	}
	return NO;
}

// Display the enclosure view below the article list view.
- (void)showEnclosureView {
    if (![self.contentStackView.views containsObject:enclosureView]) {
        [self.contentStackView addView:enclosureView
                            inGravity:NSStackViewGravityTop];
    }
}

// Hide the enclosure view if it is present.
- (void)hideEnclosureView {
    if ([self.contentStackView.views containsObject:enclosureView]) {
        [self.contentStackView removeView:enclosureView];
    }
}

/* selectFirstUnreadInFolder
 * Moves the selection to the first unread article in the current article list or the
 * first article if the folder has no unread articles.
 */
-(BOOL)selectFirstUnreadInFolder
{
	BOOL result = [self viewNextUnreadInCurrentFolder:-1];
	if (!result)
	{
		NSInteger count = self.controller.articleController.allArticles.count;
		if (count > 0)
			[self makeRowSelectedAndVisible:0];
	}
	return result;
}

/* viewLink
 * There's no view link address for article views. If we eventually implement a local
 * scheme such as vienna:<feedurl>/<guid> then we could use that as a link address.
 */
-(NSString *)viewLink
{
	return nil;
}

/* performFindPanelAction
 * Implement the search action.
 */
-(void)performFindPanelAction:(NSInteger)actionTag
{
	[self.controller.articleController reloadArrayOfArticles];
	
	// This action is send continuously by the filter field, so make sure not the mark read while searching
	if ([articleList selectedRow] < 0 && self.controller.articleController.allArticles.count > 0 )
	{
		BOOL shouldSelectArticle = YES;
		if ([Preferences standardPreferences].markReadInterval > 0.0f)
		{
			Article * article = self.controller.articleController.allArticles[0u];
            if (!article.read) {
				shouldSelectArticle = NO;
            }
		}
        if (shouldSelectArticle) {
			[self makeRowSelectedAndVisible:0];
        }
	}
}

/* refreshFolder
 * Refreshes the current folder by applying the current sort or thread
 * logic and redrawing the article list. The selected article is preserved
 * and restored on completion of the refresh.
 */
-(void)refreshFolder:(NSInteger)refreshFlag
{
	blockSelectionHandler = YES;

    Article * currentSelectedArticle = self.selectedArticle;

    switch (refreshFlag)
    {
        case MA_Refresh_RedrawList:
            break;
        case MA_Refresh_ReapplyFilter:
            [self.controller.articleController refilterArrayOfArticles];
            [self.controller.articleController sortArticles];
            break;
        case MA_Refresh_SortAndRedraw:
            [self.controller.articleController sortArticles];
            break;
    }

	[articleList reloadData];
    [self scrollToArticle:currentSelectedArticle.guid];

	blockSelectionHandler = NO;
}

/* startLoadIndicator
 * add the indicator of articles' data being loaded
 */
-(void)startLoadIndicator
{
	if (progressIndicator == nil)
	{
		progressIndicator = [[NSProgressIndicator alloc] initWithFrame:articleList.visibleRect];
		progressIndicator.style = NSProgressIndicatorSpinningStyle;
		progressIndicator.displayedWhenStopped = NO;
		[articleList addSubview:progressIndicator];
	}
	[progressIndicator startAnimation:self];
}

/* stopLoadIndicator
 * remove the indicator of articles loading
 */
-(void)stopLoadIndicator
{
	[progressIndicator stopAnimation:self];
	[progressIndicator removeFromSuperviewWithoutNeedingDisplay];
	progressIndicator = nil;
}

/* menuWillAppear
 * Called when the popup menu is opened on the table. We ensure that the item under the
 * cursor is selected.
 */
-(void)tableView:(ExtendedTableView *)tableView menuWillAppear:(NSEvent *)theEvent
{
	NSInteger row = [articleList rowAtPoint:[articleList convertPoint:theEvent.locationInWindow fromView:nil]];
	if (row >= 0)
	{
		// Select the row under the cursor if it isn't already selected
		if (articleList.numberOfSelectedRows <= 1)
		{
			[articleList selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		}
	}
}

/* refreshImmediatelyArticleAtCurrentRow
 * Refreshes the article at the current selected row.
 */
-(void)refreshImmediatelyArticleAtCurrentRow
{
	[self refreshArticlePane];
	
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !theArticle.read)
	{
		CGFloat interval = [Preferences standardPreferences].markReadInterval;
		if (interval > 0 && !isAppInitialising)
			markReadTimer = [NSTimer scheduledTimerWithTimeInterval:(double)interval
															 target:self
														   selector:@selector(markCurrentRead:)
														   userInfo:nil
															repeats:NO];
	}
}

/* refreshArticleAtCurrentRow
 * Refreshes the article at the current selected row.
 */
-(void)refreshArticleAtCurrentRow
{
	Article * article = self.selectedArticle;
	if (article == nil)
	{
		[articleText clearHTML];
		[self hideEnclosureView];
	}
	else
	{
		[self refreshImmediatelyArticleAtCurrentRow];
		
		// Add this to the backtrack list
		NSString * guid = [article guid];
		[self.controller.articleController addBacktrack:guid];
	}
}

/* handleRefreshArticle
 * Respond to the notification to refresh the current article pane.
 */
-(void)handleRefreshArticle:(NSNotification *)nc
{
	if (self == self.controller.articleController.mainArticleView && !isAppInitialising)
		[self refreshArticlePane];
}

/* clearCurrentURL
 * Clears the current URL.
 */
-(void)clearCurrentURL
{
	// If we already have an URL release it.
	if (currentURL)
	{
		currentURL = nil;
	}
}

/* loadArticleLink
 * Loads the specified link into the article text view. NOTE: This is done
 * via this selector method so that this is called via the event queue in
 * order to give the WebView drawing a chance to clear out the WebView
 * before this link is loaded.
 */
-(void)loadArticleLink:(NSString *) articleLink
{
	// Remember we're loading from HTML so the status message is set
	// appropriately.
	isLoadingHTMLArticle = YES;
	
	// Load the actual link.
	articleText.mainFrameURL = articleLink;
	
	// Clear the current URL.
	[self clearCurrentURL];
	
	// Remember the new URL.
	currentURL = [[NSURL alloc] initWithString:articleLink];

	// We need to redraw the article list so the progress indicator is shown.
	[articleList setNeedsDisplay];
}

/* url
 * Return the URL of current article.
 */
-(NSURL *)url
{
	if (isCurrentPageFullHTML)
		return currentURL;
	else 
		return nil;
}

/* refreshArticlePane
 * Updates the article pane for the current selected articles.
 */
-(void)refreshArticlePane
{
	NSArray * msgArray = self.markedArticleRange;
	
	if (msgArray.count == 0)
	{
		// Clear the current URL.
		[self clearCurrentURL];

		// We are not a FULL HTML page.
		isCurrentPageFullHTML = NO;
		
		// Clear out the page.
		[articleText clearHTML];
	}
	else
	{
		Article * firstArticle = msgArray[0];
		Folder * folder = [[Database sharedManager] folderFromID:firstArticle.folderId];
		if (folder.loadsFullHTML && msgArray.count == 1)
		{
			// Remember we have a full HTML page so we can setup the context menus
			// appropriately.
			isCurrentPageFullHTML = YES;
			
			// Clear out the text so the user knows something happened in response to the
			// click on the article.
			[articleText clearHTML];
			
			// Now set the article to the URL in the RSS feed's article. NOTE: We use
			// performSelector:withObject:afterDelay: here so that this link load gets
			// queued up into the event loop, otherwise the WebView class won't draw the
			// clearing of the HTML before this new link gets loaded.
			[self performSelector: @selector(loadArticleLink:) withObject:firstArticle.link afterDelay:0.0];
		}
		else
		{
			NSString * htmlText = [articleText articleTextFromArray:msgArray];

			// Clear the current URL.
			[self clearCurrentURL];

			// Remember we do NOT have a full HTML page so we can setup the context menus
			// appropriately.
			isCurrentPageFullHTML = NO;
			
			// Remember we're NOT loading from HTML so the status message is set
			// appropriately.
			isLoadingHTMLArticle = NO;
			
			// Set the article to the HTML from the RSS feed.
			[articleText setHTML:htmlText];
		}
	}
	
	// Show the enclosure view if just one article is selected and it has an
	// enclosure.
	if (msgArray.count != 1)
		[self hideEnclosureView];
	else
	{
		Article * oneArticle = msgArray[0];
		if (!oneArticle.hasEnclosure)
			[self hideEnclosureView];
		else
		{
			[self showEnclosureView];
			[enclosureView setEnclosureFile:oneArticle.enclosure];
		}
	}
}

/* markCurrentRead
 * Mark the current article as read.
 */
-(void)markCurrentRead:(NSTimer *)aTimer
{
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !theArticle.read && ![Database sharedManager].readOnly)
	{
		[self.controller.articleController markReadByArray:@[theArticle] readFlag:YES];
	}
}

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of articles in the current folder.
 */
-(NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return self.controller.articleController.allArticles.count;
}

/* objectValueForTableColumn [datasource]
 * Called by the table view to obtain the object at the specified column and row. This is
 * called often so it needs to be fast.
 */
-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	Database * db = [Database sharedManager];
	NSArray * allArticles = self.controller.articleController.allArticles;
	Article * theArticle;
	
	if(rowIndex < 0 || rowIndex >= allArticles.count)
	    return nil;
	theArticle = allArticles[rowIndex];
	NSString * identifier = aTableColumn.identifier;
	if ([identifier isEqualToString:MA_Field_Read])
	{
		if (!theArticle.read)
			return (theArticle.revised) ? [NSImage imageNamed:@"revised.tiff"] : [NSImage imageNamed:@"unread.tiff"];
		return [NSImage imageNamed:@"alphaPixel.tiff"];
	}
	if ([identifier isEqualToString:MA_Field_Flagged])
	{
		if (theArticle.flagged)
			return [NSImage imageNamed:@"flagged.tiff"];
		return [NSImage imageNamed:@"alphaPixel.tiff"];
	}
	if ([identifier isEqualToString:MA_Field_Comments])
	{
		if (theArticle.hasComments)
			return [NSImage imageNamed:@"comments.tiff"];
		return [NSImage imageNamed:@"alphaPixel.tiff"];
	}
	
	if ([identifier isEqualToString:MA_Field_HasEnclosure])
	{
		if (theArticle.hasEnclosure)
			return [NSImage imageNamed:@"enclosure.tiff"];
		return [NSImage imageNamed:@"alphaPixel.tiff"];
	}
	
	NSMutableAttributedString * theAttributedString;
	if ([identifier isEqualToString:MA_Field_Headlines])
	{
		theAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
		BOOL isSelectedRow = [aTableView isRowSelected:rowIndex] && (NSApp.mainWindow.firstResponder == aTableView);

		if ([db fieldByName:MA_Field_Subject].visible)
		{
			NSDictionary * topLineDictPtr;

			if (theArticle.read)
				topLineDictPtr = (isSelectedRow ? selectionDict : topLineDict);
			else
				topLineDictPtr = (isSelectedRow ? unreadTopLineSelectionDict : unreadTopLineDict);
			NSString * topString = [NSString stringWithFormat:@"%@", theArticle.title];
			NSMutableAttributedString * topAttributedString = [[NSMutableAttributedString alloc] initWithString:topString attributes:topLineDictPtr];
			[topAttributedString fixFontAttributeInRange:NSMakeRange(0u, topAttributedString.length)];
			[theAttributedString appendAttributedString:topAttributedString];
		}

		// Add the summary line that appears below the title.
		if ([db fieldByName:MA_Field_Summary].visible)
		{
			NSString * summaryString = theArticle.summary;
			NSInteger maxSummaryLength = MIN([summaryString length], 150);
			NSString * middleString = [NSString stringWithFormat:@"\n%@", [summaryString substringToIndex:maxSummaryLength]];
			NSDictionary * middleLineDictPtr = (isSelectedRow ? selectionDict : middleLineDict);
			NSMutableAttributedString * middleAttributedString = [[NSMutableAttributedString alloc] initWithString:middleString attributes:middleLineDictPtr];
			[middleAttributedString fixFontAttributeInRange:NSMakeRange(0u, middleAttributedString.length)];
			[theAttributedString appendAttributedString:middleAttributedString];
		}
		
		// Add the link line that appears below the summary and title.
		if ([db fieldByName:MA_Field_Link].visible)
		{
			NSString * articleLink = theArticle.link;
			if (articleLink != nil)
			{
				NSString * linkString = [NSString stringWithFormat:@"\n%@", articleLink];
				NSMutableDictionary * linkLineDictPtr = (isSelectedRow ? selectionDict : linkLineDict);
				NSURL * articleURL = [NSURL URLWithString:articleLink];
				if (articleURL != nil)
				{
					linkLineDictPtr = [linkLineDictPtr mutableCopy];
					linkLineDictPtr[NSLinkAttributeName] = articleURL;
				}
				NSMutableAttributedString * linkAttributedString = [[NSMutableAttributedString alloc] initWithString:linkString attributes:linkLineDictPtr];
				[linkAttributedString fixFontAttributeInRange:NSMakeRange(0u, linkAttributedString.length)];
				[theAttributedString appendAttributedString:linkAttributedString];
			}
		}
		
		// Create the detail line that appears at the bottom.
		NSDictionary * bottomLineDictPtr = (isSelectedRow ? selectionDict : bottomLineDict);
		NSMutableString * summaryString = [NSMutableString stringWithString:@""];
		NSString * delimiter = @"";

		if ([db fieldByName:MA_Field_Folder].visible)
		{
			Folder * folder = [db folderFromID:theArticle.folderId];
			[summaryString appendFormat:@"%@", folder.name];
			delimiter = @" - ";
		}
		if ([db fieldByName:MA_Field_Date].visible)
		{
			[summaryString appendFormat:@"%@%@", delimiter, [NSDateFormatter relativeDateStringFromDate:theArticle.date]];
			delimiter = @" - ";
		}
		if ([db fieldByName:MA_Field_Author].visible)
		{
			if (!theArticle.author.blank)
				[summaryString appendFormat:@"%@%@", delimiter, theArticle.author];
		}
		if (![summaryString isEqualToString:@""])
			summaryString = [NSMutableString stringWithFormat:@"\n%@", summaryString];

		NSMutableAttributedString * summaryAttributedString = [[NSMutableAttributedString alloc] initWithString:summaryString attributes:bottomLineDictPtr];
		[summaryAttributedString fixFontAttributeInRange:NSMakeRange(0u, summaryAttributedString.length)];
		[theAttributedString appendAttributedString:summaryAttributedString];
		return theAttributedString;
	}
	
	NSString * cellString;
	if ([identifier isEqualToString:MA_Field_Date])
	{
        cellString = [NSDateFormatter relativeDateStringFromDate:theArticle.date];
	}
	else if ([identifier isEqualToString:MA_Field_Folder])
	{
		Folder * folder = [db folderFromID:theArticle.folderId];
		cellString = folder.name;
	}
	else if ([identifier isEqualToString:MA_Field_Author])
	{
		cellString = theArticle.author;
	}
	else if ([identifier isEqualToString:MA_Field_Link])
	{
		cellString = theArticle.link;
	}
	else if ([identifier isEqualToString:MA_Field_Subject])
	{
		cellString = theArticle.title;
	}
	else if ([identifier isEqualToString:MA_Field_Summary])
	{
		cellString = theArticle.summary;
	}
	else if ([identifier isEqualToString:MA_Field_Enclosure])
	{
		cellString = theArticle.enclosure;
	}
	else
	{
		cellString = @"";
		[NSException raise:@"ArticleListView unknown table column identifier exception" format:@"Unknown table column identifier: %@", identifier];
	}
	
	theAttributedString = [[NSMutableAttributedString alloc] initWithString:SafeString(cellString) attributes:(theArticle.read ? reportCellDict : unreadReportCellDict)];
	[theAttributedString fixFontAttributeInRange:NSMakeRange(0u, theAttributedString.length)];
    return theAttributedString;
}

/* tableViewSelectionDidChange [delegate]
 * Handle the selection changing in the table view unless blockSelectionHandler is set.
 */
-(void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[markReadTimer invalidate];
	markReadTimer = nil;

	if (!blockSelectionHandler)
	{
		[self refreshArticleAtCurrentRow];
	}
}

/* didClickTableColumns
 * Handle the user click in the column header to sort by that column.
 */
-(void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	NSString * columnName = tableColumn.identifier;
	[self.controller.articleController sortByIdentifier:columnName];
	[self showSortDirection];
}

/* tableViewColumnDidResize
 * This notification is called when the user completes resizing a column. We obtain the
 * new column size and save the settings.
 */
-(void)tableViewColumnDidResize:(NSNotification *)notification
{
	if (!isInTableInit && !isAppInitialising && !isChangingOrientation)
	{
		NSTableColumn * tableColumn = notification.userInfo[@"NSTableColumn"];
		Field * field = [[Database sharedManager] fieldByName:tableColumn.identifier];
		NSInteger oldWidth = [notification.userInfo[@"NSOldWidth"] integerValue];
		
		if (oldWidth != tableColumn.width)
		{
			field.width = tableColumn.width;
			[self saveTableSettings];
		}
	}
}

/* writeRowsWithIndexes
 * Called to initiate a drag from MessageListView. Use the common copy selection code to copy to
 * the pasteboard.
 */
-(BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(nonnull NSPasteboard *)pboard
{
	return [self copyTableSelection:rowIndexes toPasteboard:pboard];
}

/* willDisplayCell
 * Hook before a cell is displayed to set the cell's loading HTML flag for 
 * the progress indicator.
 */
-(void)tableView:(NSTableView *)tv willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex 
{
	NSString * columnIdentifer = tableColumn.identifier;	
	BOOL isProgressColumn = NO;

	// We need to use a different column for condensed layout vs. table layout.
	if (tableLayout == MA_Layout_Report && [columnIdentifer isEqualToString:MA_Field_Subject])
		isProgressColumn = YES;
	else if (tableLayout == MA_Layout_Condensed && [columnIdentifer isEqualToString:MA_Field_Headlines])
		isProgressColumn = YES;
	
	if (isProgressColumn)
	{
		ProgressTextCell * realCell = (ProgressTextCell *)cell;
		
		// Set the in-progress flag as appropriate so the progress indicator gets
		// displayed and removed as needed.
		if ([realCell respondsToSelector:@selector(setInProgress:forRow:)])
		{
			if (rowIndex == [tv selectedRow] && isLoadingHTMLArticle)
				[realCell setInProgress:YES forRow:rowIndex];
			else
				[realCell setInProgress:NO forRow:rowIndex];
        }
	}
}

/* copyTableSelection
 * This is the common copy selection code. We build an array of dictionary entries each of
 * which include details of each selected article in the standard RSS item format defined by
 * Ranchero NetNewsWire. See http://ranchero.com/netnewswire/rssclipboard.php for more details.
 */
-(BOOL)copyTableSelection:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray * arrayOfArticles = [[NSMutableArray alloc] init];
	NSMutableArray * arrayOfURLs = [[NSMutableArray alloc] init];
	NSMutableArray * arrayOfTitles = [[NSMutableArray alloc] init];
	NSMutableString * fullHTMLText = [[NSMutableString alloc] init];
	NSMutableString * fullPlainText = [[NSMutableString alloc] init];
	Database * db = [Database sharedManager];
	NSInteger count = rowIndexes.count;
	
	// Set up the pasteboard
	[pboard declareTypes:@[MA_PBoardType_RSSItem, @"WebURLsWithTitlesPboardType", NSStringPboardType, NSHTMLPboardType] owner:self];
	if (count == 1)
		[pboard addTypes:@[MA_PBoardType_url, MA_PBoardType_urln, NSURLPboardType] owner:self];
	
	// Open the HTML string
	[fullHTMLText appendString:@"<html><body>"];
	
	// Get all the articles that are being dragged
	NSUInteger msgIndex = rowIndexes.firstIndex;
	while (msgIndex != NSNotFound)
	{
		Article * thisArticle = self.controller.articleController.allArticles[msgIndex];
		Folder * folder = [db folderFromID:thisArticle.folderId];
		NSString * msgText = thisArticle.body;
		NSString * msgTitle = thisArticle.title;
		NSString * msgLink = thisArticle.link;
		
		[arrayOfURLs addObject:msgLink];
		[arrayOfTitles addObject:msgTitle];

		NSMutableDictionary * articleDict = [NSMutableDictionary dictionary];
		[articleDict setValue:msgTitle forKey:@"rssItemTitle"];
		[articleDict setValue:msgLink forKey:@"rssItemLink"];
		[articleDict setValue:msgText forKey:@"rssItemDescription"];
		[articleDict setValue:folder.name forKey:@"sourceName"];
		[articleDict setValue:folder.homePage forKey:@"sourceHomeURL"];
		[articleDict setValue:folder.feedURL forKey:@"sourceRSSURL"];
		[arrayOfArticles addObject:articleDict];

		// Plain text
		[fullPlainText appendFormat:@"%@\n%@\n\n", msgTitle, msgText];
		
		// Add HTML version too.
		[fullHTMLText appendFormat:@"<a href=\"%@\">%@</a><br />%@<br /><br />", msgLink, msgTitle, msgText];
		
		if (count == 1)
		{
			[pboard setString:msgLink forType:MA_PBoardType_url];
			[pboard setString:msgTitle forType:MA_PBoardType_urln];
			
			// Write the link to the pastboard.
			[[NSURL URLWithString:msgLink] writeToPasteboard:pboard];
		}

		msgIndex = [rowIndexes indexGreaterThanIndex:msgIndex];
	}
	
	// Close the HTML string
	[fullHTMLText appendString:@"</body></html>"];

	// Put string on the pasteboard for external drops.
	[pboard setPropertyList:arrayOfArticles forType:MA_PBoardType_RSSItem];
	[pboard setPropertyList:@[arrayOfURLs, arrayOfTitles] forType:@"WebURLsWithTitlesPboardType"];
	[pboard setString:fullPlainText forType:NSStringPboardType];
	[pboard setString:fullHTMLText.stringByEscapingExtendedCharacters forType:NSHTMLPboardType];

	return YES;
}

/* markedArticleRange
 * Retrieve an array of selected articles.
 */
-(NSArray *)markedArticleRange
{
	NSMutableArray * articleArray = nil;
	if (articleList.numberOfSelectedRows > 0)
	{
		NSIndexSet * rowIndexes = articleList.selectedRowIndexes;
		NSUInteger  rowIndex = rowIndexes.firstIndex;

		articleArray = [NSMutableArray arrayWithCapacity:rowIndexes.count];
		while (rowIndex != NSNotFound)
		{
			[articleArray addObject:self.controller.articleController.allArticles[rowIndex]];
			rowIndex = [rowIndexes indexGreaterThanIndex:rowIndex];
		}
	}
	return [articleArray copy];
}

/* didStartProvisionalLoadForFrame
 * Invoked when a new client request is made by sender to load a provisional data source for frame.
 */
-(void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
	if (frame == articleText.mainFrame)
	{
		[self setError:nil];
	}
	
}

/* didCommitLoadForFrame
 * Invoked when data source of frame has started to receive data.
 */
-(void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
}

/* didFailProvisionalLoadWithError
 * Invoked when a location request for frame has failed to load.
 */
-(void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	if (frame == articleText.mainFrame)
	{
		[self handleError:error withDataSource: frame.provisionalDataSource];
	}
}

/* didFailLoadWithError
 * Invoked when a location request for frame has failed to load.
 */
-(void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	if (frame == articleText.mainFrame)
	{
		// Not really errors. Load is cancelled or a plugin is grabbing the URL and will handle it by itself.
		if (!([error.domain isEqualToString:WebKitErrorDomain] && (error.code == NSURLErrorCancelled || error.code == WebKitErrorPlugInWillHandleLoad)))
			[self handleError:error withDataSource:frame.dataSource];
		[self endMainFrameLoad];
	}
}

-(void)handleError:(NSError *)error withDataSource:(WebDataSource *)dataSource
{
	// Remember the error.
	[self setError:error];
	
	// Load the localized verion of the error page
	WebFrame * frame = articleText.mainFrame;
	NSString * pathToErrorPage = [[NSBundle bundleForClass:[self class]] pathForResource:@"errorpage" ofType:@"html"];
	if (pathToErrorPage != nil)
	{
		NSString *errorMessage = [NSString stringWithContentsOfFile:pathToErrorPage encoding:NSUTF8StringEncoding error:NULL];
		errorMessage = [errorMessage stringByReplacingOccurrencesOfString: @"$ErrorInformation" withString: error.localizedDescription];
		if (errorMessage != nil)
			[frame loadAlternateHTMLString:errorMessage baseURL:[NSURL fileURLWithPath:pathToErrorPage isDirectory:NO] forUnreachableURL:dataSource.request.URL];
	}		
}

/* endMainFrameLoad
 * Handle the end of a load whether or not it completed and whether or not an error
 * occurred. The error variable is nil for no error or it contains the most recent
 * NSError incident.
 */
-(void)endMainFrameLoad
{
	if (isLoadingHTMLArticle)
	{
		isLoadingHTMLArticle = NO;
		[articleList setNeedsDisplay];
	}
}

/* didFinishLoadForFrame
 * Invoked when a location request for frame has successfully; that is, when all the resources are done loading.
 */
-(void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if (frame == articleText.mainFrame)
		[self endMainFrameLoad];
}

-(void)webViewLoadFinished:(NSNotification *)notification
{
}

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSUserDefaults.standardUserDefaults removeObserver:self
                                             forKeyPath:MAPref_ShowStatusBar];
	[articleText setUIDelegate:nil];
	[articleText setFrameLoadDelegate:nil];
	[splitView2 setDelegate:nil];
	[articleList setDelegate:nil];
}

// MARK: Key-value observation

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:MAPref_ShowStatusBar]) {
        BOOL isStatusBarShown = [Preferences standardPreferences].showStatusBar;
        if (isStatusBarShown && !self.statusBar) {
            self.statusBar = [OverlayStatusBar new];
            [articleText addSubview:self.statusBar];
        } else if (!isStatusBarShown && self.statusBar) {
            [self.statusBar removeFromSuperview];
            self.statusBar = nil;
        }
    }
}

@end
