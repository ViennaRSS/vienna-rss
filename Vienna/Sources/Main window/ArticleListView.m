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
#import "ArticleController.h"
#import "StringExtensions.h"
#import "HelperFunctions.h"
#import "Field.h"
#import "ProgressTextCell.h"
#import "Article.h"
#import "Folder.h"
#import "EnclosureView.h"
#import "Database.h"
#import "Vienna-Swift.h"

// Shared defaults key
NSString * const MAPref_ShowEnclosureBar = @"ShowEnclosureBar";

static void *VNAArticleListViewObserverContext = &VNAArticleListViewObserverContext;

@interface ArticleListView ()

@property (weak, nonatomic) IBOutlet NSStackView *contentStackView;
@property (weak, nonatomic) IBOutlet EnclosureView *enclosureView;

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

@property NSView *articleTextView;
@property (strong) NSLayoutConstraint *textViewWidthConstraint;
@property (nonatomic) BOOL imbricatedSplitViewResizes; // used to avoid warnings about missing invalidation for a view's changing state
@property (nonatomic) NSLayoutManager *layoutManager;

// MARK: ArticleView delegate
@property (readwrite, getter=isCurrentPageFullHTML, nonatomic) BOOL currentPageFullHTML;

@end

@implementation ArticleListView {
    IBOutlet MessageListView *articleList;
    NSObject<ArticleContentView, Tab> *articleText;
    IBOutlet NSSplitView *splitView2;

    NSInteger tableLayout;
    BOOL isAppInitialising;
    BOOL isChangingOrientation;
    BOOL isInTableInit;
    BOOL blockSelectionHandler;

    NSTimer *markReadTimer;
    NSFont *articleListFont;
    NSFont *articleListUnreadFont;
    NSMutableDictionary *reportCellDict;
    NSMutableDictionary *unreadReportCellDict;
    NSMutableDictionary *selectionDict;
    NSMutableDictionary *topLineDict;
    NSMutableDictionary *linkLineDict;
    NSMutableDictionary *middleLineDict;
    NSMutableDictionary *bottomLineDict;
    NSMutableDictionary *unreadTopLineDict;
    NSMutableDictionary *unreadTopLineSelectionDict;

    NSURL *currentURL;
    BOOL isLoadingHTMLArticle;
}

/* initWithFrame
 * Initialise our view.
 */
-(instancetype)initWithFrame:(NSRect)frame
{
    self= [super initWithFrame:frame];
    if (self) {
        isChangingOrientation = NO;
		isInTableInit = NO;
		blockSelectionHandler = NO;
		markReadTimer = nil;
		_currentPageFullHTML = NO;
		isLoadingHTMLArticle = NO;
		currentURL = nil;
		self.imbricatedSplitViewResizes = NO;
        _layoutManager = [NSLayoutManager new];
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
	[nc addObserver:self selector:@selector(handleArticleListFontChange:) name:MA_Notify_ArticleListFontChange object:nil];
	[nc addObserver:self selector:@selector(handleReadingPaneChange:) name:MA_Notify_ReadingPaneChange object:nil];
	[nc addObserver:self selector:@selector(handleLoadFullHTMLChange:) name:MA_Notify_LoadFullHTMLChange object:nil];
	[nc addObserver:self selector:@selector(handleRefreshArticle:) name:MA_Notify_ArticleViewChange object:nil];
	[nc addObserver:self selector:@selector(handleArticleViewEnded:) name:MA_Notify_ArticleViewEnded object:nil];

    [self initialiseArticleView];
}

/* initialiseArticleView
 * Do the things to initialise the article view from the database. This is the
 * only point during initialisation where the database is guaranteed to be
 * ready for use.
 */
-(void)initialiseArticleView
{
    WebKitArticleTab *articleTextController = [[WebKitArticleTab alloc] init];
    articleText = articleTextController;
    self.articleTextView = articleTextController.view;

    [self.contentStackView addView:self.articleTextView inGravity:NSStackViewGravityTop];


	Preferences * prefs = [Preferences standardPreferences];

	// Mark the start of the init phase
	isAppInitialising = YES;

    articleText.listView = self;

	// Create report and condensed view attribute dictionaries
	NSMutableParagraphStyle * style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	style.lineBreakMode = NSLineBreakByTruncatingTail;
	style.tighteningFactorForTruncation = 0.0;
	
    reportCellDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor textColor], NSForegroundColorAttributeName, nil];
    unreadReportCellDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor textColor], NSForegroundColorAttributeName, nil];
    		
	selectionDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor whiteColor], NSForegroundColorAttributeName, nil];
	unreadTopLineDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor textColor], NSForegroundColorAttributeName, nil];
	topLineDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor textColor], NSForegroundColorAttributeName, nil];
	unreadTopLineSelectionDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor whiteColor], NSForegroundColorAttributeName, nil];
    middleLineDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor systemBlueColor], NSForegroundColorAttributeName, nil];
    linkLineDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor systemBlueColor], NSForegroundColorAttributeName, nil];
    bottomLineDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor systemGrayColor], NSForegroundColorAttributeName, nil];

	// Set the reading pane orientation
	[self setOrientation:prefs.layout];
	
    // With vertical layout and "Use Web Page for Articles" set, we need to
    // manage article view's width so that it does not grow or shrink randomly
    // on certain sites.
    // The best solution I found is programmatically setting a constraint with a
    // "constant" value.
    // This did not work for me: self.textViewWidthConstraint =
    //     [NSLayoutConstraint constraintWithItem:articleTextView attribute:NSLayoutAttributeWidth
    //         relatedBy:NSLayoutRelationEqual toItem:self.contentStackView attribute:NSLayoutAttributeWidth
    //         multiplier:1.f constant:0.f];
    self.textViewWidthConstraint =
        [NSLayoutConstraint constraintWithItem:self.articleTextView attribute:NSLayoutAttributeWidth
            relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute
            multiplier:0.f constant:self.contentStackView.frame.size.width];
    self.textViewWidthConstraint.priority = NSLayoutPriorityRequired;
    self.articleTextView.translatesAutoresizingMaskIntoConstraints = NO;
    // for some reason, this constraint is necessary for new browser with vertical layout, but it is counterproductive with other configurations
    self.textViewWidthConstraint.active = splitView2.vertical;

	// Initialise the article list view
	[self initTableView];

	// Make sure we skip the column filter button in the Tab order
    articleList.nextKeyView = self.articleTextView;

    // Allow us to control the behavior of the NSSplitView
    splitView2.delegate = self;

	// Done initialising
	isAppInitialising = NO;

    NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
    [userDefaults addObserver:self
                   forKeyPath:MAPref_ShowEnclosureBar
                      options:NSKeyValueObservingOptionNew
                      context:VNAArticleListViewObserverContext];
    [userDefaults addObserver:self
                   forKeyPath:MAPref_ShowUnreadArticlesInBold
                      options:0
                      context:VNAArticleListViewObserverContext];
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
	
	for (index = 0; index < dataArray.count;) {
		NSString * name;
		NSInteger width = 100;
		BOOL visible = NO;
		
		name = dataArray[index++];
		if (index < dataArray.count) {
			visible = [dataArray[index++] integerValue] == YES;
		}
		if (index < dataArray.count) {
			width = [dataArray[index++] integerValue];
		}
		
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
    openFeedInBrowser.keyEquivalentModifierMask = NSEventModifierFlagOption;
	openFeedInBrowser.alternate = YES;
	[articleListMenu addItem:openFeedInBrowser];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Open Article Page", @"Title of a menu item")
							   action:@selector(viewArticlePages:)
						keyEquivalent:@""];
	NSMenuItem *openItemInBrowser = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Article Page in External Browser", @"Title of a menu item")
															   action:@selector(viewArticlePagesInAlternateBrowser:)
														keyEquivalent:@""];
    openItemInBrowser.keyEquivalentModifierMask = NSEventModifierFlagOption;
	openItemInBrowser.alternate = YES;
	[articleListMenu addItem:openItemInBrowser];

	articleList.menu = articleListMenu;

	// Set the target for double-click actions
	articleList.doubleAction = @selector(doubleClickRow:);
	articleList.action = @selector(singleClickRow:);
    articleList.delegate = self;
    articleList.dataSource = self;
	articleList.target = self;
    articleList.accessibilityValueDescription = NSLocalizedString(@"Articles", nil);
}

/* singleClickRow
 * Handle a single click action. If the click was in the read or flagged column then
 * treat it as an action to mark the article read/unread or flagged/unflagged. If
 * the click lands on the enclosure colum, download the associated enclosure.
 */
-(IBAction)singleClickRow:(id)sender
{
	NSInteger row = articleList.clickedRow;
	NSInteger column = articleList.clickedColumn;
	NSArray * allArticles = self.controller.articleController.allArticles;
	
	if (row >= 0 && row < (NSInteger)allArticles.count) {
		NSArray * columns = articleList.tableColumns;
		if (column >= 0 && column < (NSInteger)columns.count) {
			Article * theArticle = allArticles[row];
			NSString * columnName = ((NSTableColumn *)columns[column]).identifier;
			if ([columnName isEqualToString:MA_Field_Read]) {
				[self.controller.articleController markReadByArray:@[theArticle] readFlag:!theArticle.read];
				return;
			}
			if ([columnName isEqualToString:MA_Field_Flagged]) {
				[self.controller.articleController markFlaggedByArray:@[theArticle] flagged:!theArticle.flagged];
				return;
			}
			if ([columnName isEqualToString:MA_Field_HasEnclosure]) {
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
	if (clickedRow != -1) {
		Article * theArticle = self.controller.articleController.allArticles[clickedRow];
		[self.controller openURLFromString:theArticle.link inPreferredBrowser:YES];
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
	for (index = 0; index < count; ++index) {
		Field * field = fields[index];
		NSString * identifier = field.name;
		NSInteger tag = field.tag;
		BOOL showField;
		
		// Handle which fields can be visible in the condensed (vertical) layout
		// versus the report (horizontal) layout
		if (tableLayout == VNALayoutReport) {
			showField = field.visible && tag != ArticleFieldIDHeadlines;
		} else {
			showField = NO;
			if (tag == ArticleFieldIDRead || tag == ArticleFieldIDFlagged || tag == ArticleFieldIDHasEnclosure) {
				showField = field.visible;
			}
			if (tag == ArticleFieldIDHeadlines) {
				showField = YES;
			}
		}

		// Set column hidden or shown
		NSTableColumn *col = [articleList tableColumnWithIdentifier:identifier];
		col.hidden = !showField;

		// Add to the end only those columns which should be visible
		// and aren't created yet
		if (showField && [articleList columnWithIdentifier:identifier]==-1) {
			NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:identifier];
			
			// Replace the normal text field cell with a progress text cell so we can
			// display a progress indicator when loading HTML pages. NOTE: This is handled
			// in willDisplayCell:forTableColumn:row: where it sets the inProgress flag.
			// We need to use a different column for condensed layout vs. table layout.
			BOOL isProgressColumn = NO;
			if (tableLayout == VNALayoutReport && [column.identifier isEqualToString:MA_Field_Subject]) {
				isProgressColumn = YES;
			}
			if (tableLayout == VNALayoutCondensed && [column.identifier isEqualToString:MA_Field_Headlines]) {
				isProgressColumn = YES;
			}
			
			if (isProgressColumn) {
				ProgressTextCell * progressCell;
				
				progressCell = [[ProgressTextCell alloc] init];
				column.dataCell = progressCell;
			} else {
				VNAVerticallyCenteredTextFieldCell * cell;

				cell = [[VNAVerticallyCenteredTextFieldCell alloc] init];
				column.dataCell = cell;
			}

			BOOL isResizable = (tag != ArticleFieldIDRead && tag != ArticleFieldIDFlagged && tag != ArticleFieldIDHasEnclosure);
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
		if (showField) {
			NSTableColumn *column = [articleList tableColumnWithIdentifier:identifier];
			column.width = field.width;
		}
	}
	
	// Set the images for specific header columns
    if (@available(macOS 11, *)) {
        NSImageSymbolScale scale = NSImageSymbolScaleSmall;
        NSImageSymbolConfiguration *config = nil;
        config = [NSImageSymbolConfiguration configurationWithScale:scale];
        NSImage *readImage = [NSImage imageWithSystemSymbolName:@"circlebadge"
                                       accessibilityDescription:nil];
        readImage = [readImage imageWithSymbolConfiguration:config];
        NSImage *flagImage = [NSImage imageWithSystemSymbolName:@"flag"
                                       accessibilityDescription:nil];
        flagImage = [flagImage imageWithSymbolConfiguration:config];
        NSImage *enclImage = [NSImage imageWithSystemSymbolName:@"paperclip"
                                       accessibilityDescription:nil];
        enclImage = [enclImage imageWithSymbolConfiguration:config];

        [articleList setHeaderImage:MA_Field_Read
                              image:readImage];
        [articleList setHeaderImage:MA_Field_Flagged
                              image:flagImage];
        [articleList setHeaderImage:MA_Field_HasEnclosure
                              image:enclImage];
    } else {
        [articleList setHeaderImage:MA_Field_Read
                              image:[NSImage imageNamed:@"unread_header"]];
        [articleList setHeaderImage:MA_Field_Flagged
                              image:[NSImage imageNamed:@"flagged_header"]];
        [articleList setHeaderImage:MA_Field_HasEnclosure
                              image:[NSImage imageNamed:@"enclosure_header"]];
    }

	// Initialise the sort direction
	[self showSortDirection];	
	
	// Put the selection back
	[articleList selectRowIndexes:selArray byExtendingSelection:NO];
	
	if (tableLayout == VNALayoutReport) {
		articleList.autosaveName = @"Vienna3ReportLayoutColumns";
	} else {
		articleList.autosaveName = @"Vienna3CondensedLayoutColumns";
	}
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
    NSString * guid = self.selectedArticle.guid;
	[prefs setInteger:self.controller.articleController.currentFolderId forKey:MAPref_CachedFolderID];
	[prefs setString:(guid != nil ? guid : @"") forKey:MAPref_CachedArticleGUID];

	// An array we need for the settings
	NSMutableArray * dataArray = [[NSMutableArray alloc] init];
	
	// Create the new columns
	
	for (Field * field in  [[Database sharedManager] arrayOfFields]) {
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
	CGFloat height = [self.layoutManager defaultLineHeightForFont:articleListFont];
	NSInteger numberOfRowsInCell;

	if (tableLayout == VNALayoutReport) {
		numberOfRowsInCell = 1;
	} else {
		numberOfRowsInCell = 0;
		if ([db fieldByName:MA_Field_Subject].visible) {
			++numberOfRowsInCell;
		}
		if ([db fieldByName:MA_Field_Folder].visible || [db fieldByName:MA_Field_Date].visible || [db fieldByName:MA_Field_Author].visible) {
			++numberOfRowsInCell;
		}
		if ([db fieldByName:MA_Field_Link].visible) {
			++numberOfRowsInCell;
		}
		if ([db fieldByName:MA_Field_Summary].visible) {
			++numberOfRowsInCell;
		}
		if (numberOfRowsInCell == 0) {
			++numberOfRowsInCell;
		}
	}
	articleList.rowHeight = (height + 2.0f) * (CGFloat)numberOfRowsInCell;
}

/* showSortDirection
 * Shows the current sort column and direction in the table.
 */
-(void)showSortDirection
{
	NSString * sortColumnIdentifier = self.controller.articleController.sortColumnIdentifier;
	
	for (NSTableColumn * column in articleList.tableColumns) {
		if ([column.identifier isEqualToString:sortColumnIdentifier]) {
			NSString * imageName = ([[Preferences standardPreferences].articleSortDescriptors[0] ascending]) ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator";
			articleList.highlightedTableColumn = column;
			[articleList setIndicatorImage:[NSImage imageNamed:imageName] inTableColumn:column];
		} else {
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
	if (guid != nil) {
		NSInteger rowIndex = 0;
		for (Article * thisArticle in self.controller.articleController.allArticles) {
			if ([thisArticle.guid isEqualToString:guid]) {
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

/* canDeleteMessageAtRow
 * Returns YES if the message at the specified row can be deleted, otherwise NO.
 */
-(BOOL)canDeleteMessageAtRow:(NSInteger)row
{
	return articleList.window.visible && self.selectedArticle != nil && ![Database sharedManager].readOnly;
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

/* makeTextStandardSize
 * Reset webview text size to default
 */
-(IBAction)makeTextStandardSize:(id)sender
{
	[articleText resetTextSize];
}

/* makeTextSmaller
 * Make webview text size smaller
 */
-(IBAction)makeTextSmaller:(id)sender
{
	[articleText decreaseTextSize];
}

/* makeTextLarger
 * Make webview text size larger
 */
-(IBAction)makeTextLarger:(id)sender
{
	[articleText increaseTextSize];
}

/* updateAlternateMenuTitle
 * Sets the approprate title for the alternate item in the contextual menu
 * when user changes preference for opening pages in external browser
 */
- (void)updateAlternateMenuTitle
{
    NSMenuItem *mainMenuItem;
    NSMenuItem *contextualMenuItem;
    NSInteger index;
    NSMenu *articleListMenu = articleList.menu;
    if (articleListMenu == nil) {
        return;
    }
    mainMenuItem = menuItemWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
    if (mainMenuItem != nil) {
        index = [articleListMenu indexOfItemWithTarget:nil andAction:@selector(viewSourceHomePageInAlternateBrowser:)];
        if (index >= 0) {
            contextualMenuItem = [articleListMenu itemAtIndex:index];
            contextualMenuItem.title = mainMenuItem.title;
        }
    }
    mainMenuItem = menuItemWithAction(@selector(viewArticlePagesInAlternateBrowser:));
    if (mainMenuItem != nil) {
        index = [articleListMenu indexOfItemWithTarget:nil andAction:@selector(viewArticlePagesInAlternateBrowser:)];
        if (index >= 0) {
            contextualMenuItem = [articleListMenu itemAtIndex:index];
            contextualMenuItem.title = mainMenuItem.title;
        }
    }
} // updateAlternateMenuTitle

- (BOOL)acceptsFirstResponder
{
	return YES;
}

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

/* handleArticleListFontChange
 * Called when the user changes the article list font and/or size in the Preferences
 */
-(void)handleArticleListFontChange:(NSNotification *)note
{
	[self setTableViewFont];
	if (self == self.controller.articleController.mainArticleView) {
		[articleList reloadData];
	}
}

/* handleLoadFullHTMLChange
 * Called when the user changes the folder setting to load the article in full HTML.
 */
-(void)handleLoadFullHTMLChange:(NSNotification *)note
{
	if (self == self.controller.articleController.mainArticleView) {
		[self refreshArticlePane];
	}
}

/* handleReadingPaneChange
 * Respond to the change to the reading pane orientation.
 */
-(void)handleReadingPaneChange:(NSNotificationCenter *)nc
{
	if (self == self.controller.articleController.mainArticleView) {
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
	splitView2.vertical = (newLayout == VNALayoutCondensed);
	splitView2.dividerStyle = (splitView2.vertical ? NSSplitViewDividerStyleThin : NSSplitViewDividerStylePaneSplitter);
	splitView2.autosaveName = (newLayout == VNALayoutCondensed ? @"Vienna3SplitView2CondensedLayout" : @"Vienna3SplitView2ReportLayout");
	self.textViewWidthConstraint.active = splitView2.vertical;
	[splitView2 display];
	isChangingOrientation = NO;
}

/* makeRowSelectedAndVisible
 * Selects the specified row in the table and makes it visible by
 * scrolling it to the center of the table.
 */
-(void)makeRowSelectedAndVisible:(NSInteger)rowIndex
{
	if (self.controller.articleController.allArticles.count == 0u) {
		[articleList deselectAll:self];
	} else if (rowIndex != articleList.selectedRow) {
		[articleList selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];

		// make sure our current selection is visible
		[articleList scrollRowToVisible:rowIndex];
		// then try to center it in the list
		NSInteger pageSize = [articleList rowsInRect:articleList.visibleRect].length;
		NSInteger lastRow = articleList.numberOfRows - 1;
		NSInteger visibleRow = rowIndex + (pageSize / 2);

		if (visibleRow > lastRow) {
			visibleRow = lastRow;
		}
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
    return [self viewNextUnreadInCurrentFolder:(articleList.selectedRow + 1)];
}

/* viewNextUnreadInCurrentFolder
 * Select the next unread article in the current folder after currentRow.
 */
-(BOOL)viewNextUnreadInCurrentFolder:(NSInteger)currentRow
{
	if (currentRow < 0) {
		currentRow = 0;
	}
	
	NSArray * allArticles = self.controller.articleController.allArticles;
	NSInteger totalRows = allArticles.count;
	Article * theArticle;
	while (currentRow < totalRows) {
		theArticle = allArticles[currentRow];
		if (!theArticle.read) {
			[self makeRowSelectedAndVisible:currentRow];
			return YES;
		}
		++currentRow;
	}
	return NO;
}

// Display the enclosure view below the article list view.
- (void)showEnclosureView {
    NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
    if (![userDefaults boolForKey:MAPref_ShowEnclosureBar]) {
        return;
    }

    if (![self.contentStackView.views containsObject:self.enclosureView]) {
        [self.contentStackView addView:self.enclosureView
                            inGravity:NSStackViewGravityTop];
    }
}

// Hide the enclosure view if it is present.
- (void)hideEnclosureView {
    if ([self.contentStackView.views containsObject:self.enclosureView]) {
        [self.contentStackView removeView:self.enclosureView];
    }
}

/* selectFirstUnreadInFolder
 * Moves the selection to the first unread article in the current article list or the
 * first article if the folder has no unread articles.
 */
-(BOOL)selectFirstUnreadInFolder
{
	BOOL result = [self viewNextUnreadInCurrentFolder:-1];
	if (!result) {
		NSInteger count = self.controller.articleController.allArticles.count;
		if (count > 0) {
			[self makeRowSelectedAndVisible:0];
		}
	}
	return result;
}

-(void)scrollDownDetailsOrNextUnread
{
    if (articleText.canScrollDown) {
        [(NSView *)articleText scrollPageDown:nil];
    } else {
        ArticleController * articleController = self.controller.articleController;
        [articleController markReadByArray:articleController.markedArticleRange readFlag:YES];
        [articleController displayNextUnread];
    }
}

-(void)scrollUpDetailsOrGoBack
{
    if (articleText.canScrollUp) {
        [(NSView *)articleText scrollPageUp:nil];
    } else {
        [self.controller.articleController goBack];
    }
}

/* performFindPanelAction
 * Implement the search action.
 */
-(void)performFindPanelAction:(NSInteger)actionTag
{
	[self.controller.articleController reloadArrayOfArticles];
	
	// This action is send continuously by the filter field, so make sure not the mark read while searching
    if (articleList.selectedRow < 0 && self.controller.articleController.allArticles.count > 0 ) {
		BOOL shouldSelectArticle = YES;
		if ([Preferences standardPreferences].markReadInterval > 0.0f) {
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

    switch (refreshFlag) {
        case VNARefreshRedrawList:
            break;
        case VNARefreshReapplyFilter:
            [self.controller.articleController refilterArrayOfArticles];
            [self.controller.articleController sortArticles];
            break;
        case VNARefreshSortAndRedraw:
            [self.controller.articleController sortArticles];
            break;
    }

	[articleList reloadData];
    [self scrollToArticle:currentSelectedArticle.guid];

	blockSelectionHandler = NO;
}

/* refreshImmediatelyArticleAtCurrentRow
 * Refreshes the article at the current selected row.
 */
-(void)refreshImmediatelyArticleAtCurrentRow
{
	[self refreshArticlePane];
	
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !theArticle.read) {
		CGFloat interval = [Preferences standardPreferences].markReadInterval;
		if (interval > 0 && !isAppInitialising) {
			markReadTimer = [NSTimer scheduledTimerWithTimeInterval:(double)interval
															 target:self
														   selector:@selector(markCurrentRead:)
														   userInfo:nil
															repeats:NO];
		}
	}
}

/* refreshArticleAtCurrentRow
 * Refreshes the article at the current selected row.
 */
-(void)refreshArticleAtCurrentRow
{
	Article * article = self.selectedArticle;
	if (article == nil) {
		[articleText setArticles:@[]];
		[self hideEnclosureView];
	} else {
		[self refreshImmediatelyArticleAtCurrentRow];
		
		// Add this to the backtrack list
        NSString * guid = article.guid;
		[self.controller.articleController addBacktrack:guid];
	}
}

/* handleRefreshArticle
 * Respond to the notification to refresh the current article pane.
 */
-(void)handleRefreshArticle:(NSNotification *)nc
{
	if (self == self.controller.articleController.mainArticleView && !isAppInitialising) {
		[self refreshArticlePane];
	}
}

/* handleArticleViewEnded
 * Handle the end of a load whether or not it completed and whether or not an
 * error occurred.
 */
- (void)handleArticleViewEnded:(NSNotification *)nc
{
    if (nc.object == articleText) {
        [self endMainFrameLoad];
    }
}

/* clearCurrentURL
 * Clears the current URL.
 */
-(void)clearCurrentURL
{
	// If we already have an URL release it.
	if (currentURL) {
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
    [self startMainFrameLoad];
	
	// Load the actual link.
	articleText.tabUrl = cleanedUpUrlFromString(articleLink);
    [articleText loadTab];
	
	// Clear the current URL.
	[self clearCurrentURL];
	
	// Remember the new URL.
	currentURL = [[NSURL alloc] initWithString:articleLink];

	// We need to redraw the article list so the progress indicator is shown.
    articleList.needsDisplay = YES;
}

/* url
 * Return the URL of current article.
 */
-(NSURL *)url
{
	if (self.isCurrentPageFullHTML) {
		return currentURL;
	} else { 
		return nil;
	}
}

/* refreshArticlePane
 * Updates the article pane for the current selected articles.
 */
-(void)refreshArticlePane
{
	NSArray * msgArray = self.markedArticleRange;
	
	if (msgArray.count == 0) {
		// Clear the current URL.
		[self clearCurrentURL];

		// We are not a FULL HTML page.
		self.currentPageFullHTML = NO;
		
		// Clear out the page.
		[articleText setArticles:@[]];
	} else {
		Article * firstArticle = msgArray[0];
		Folder * folder = [[Database sharedManager] folderFromID:firstArticle.folderId];
		if (folder.loadsFullHTML && msgArray.count == 1) {
			if (!self.currentPageFullHTML) {
			    // Clear out the text so the user knows something happened in response to the
			    // click on the article.
			    [articleText setArticles:@[]];
			}

			// Remember we have a full HTML page so we can setup the context menus
			// appropriately.
			self.currentPageFullHTML = YES;
			
			// Now set the article to the URL in the RSS feed's article. NOTE: We use
			// performSelector:withObject:afterDelay: here so that this link load gets
			// queued up into the event loop, otherwise the WebView class won't draw the
			// clearing of the HTML before this new link gets loaded.
			[self performSelector: @selector(loadArticleLink:) withObject:firstArticle.link afterDelay:0.0];
		} else {
			// Clear the current URL.
			[self clearCurrentURL];

			// Remember we do NOT have a full HTML page so we can setup the context menus
			// appropriately.
			self.currentPageFullHTML = NO;
			
			// Remember we're NOT loading from HTML so the status message is set
			// appropriately.
			isLoadingHTMLArticle = NO;
			
			// Set the article to the HTML from the RSS feed.
			[articleText setArticles:msgArray];
		}
	}
	
	// Show the enclosure view if just one article is selected and it has an
	// enclosure.
	if (msgArray.count != 1) {
		[self hideEnclosureView];
	} else {
		Article * oneArticle = msgArray[0];
		if (!oneArticle.hasEnclosure) {
			[self hideEnclosureView];
		} else {
			[self showEnclosureView];
			[self.enclosureView setEnclosureFile:oneArticle.enclosure];
		}
	}
}

/* markCurrentRead
 * Mark the current article as read.
 */
-(void)markCurrentRead:(NSTimer *)aTimer
{
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !theArticle.read && ![Database sharedManager].readOnly) {
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
	
	if(rowIndex < 0 || rowIndex >= allArticles.count) {
		return nil;
	}
	theArticle = allArticles[rowIndex];
	NSString * identifier = aTableColumn.identifier;
	if ([identifier isEqualToString:MA_Field_Read]) {
        if (!theArticle.read) {
            if (@available(macOS 11, *)) {
                NSImage *image = nil;
                if (theArticle.revised) {
                    image = [NSImage imageWithSystemSymbolName:@"sparkles"
                                      accessibilityDescription:nil];
                    // Setting the template property to NO enables the tint color.
                    image.template = NO;
                } else {
                    image = [NSImage imageWithSystemSymbolName:@"circlebadge.fill"
                                      accessibilityDescription:nil];
                    // Setting the template property to NO enables the tint color.
                    image.template = NO;
                }
                return image;
            } else {
                if (theArticle.revised) {
                    return [NSImage imageNamed:@"revised"];
                } else {
                    return [NSImage imageNamed:@"unread"];
                }
            }
        }
        return nil;
	}
	if ([identifier isEqualToString:MA_Field_Flagged]) {
        if (theArticle.flagged) {
            if (@available(macOS 11, *)) {
                NSImage *image = [NSImage imageWithSystemSymbolName:@"flag.fill"
                                           accessibilityDescription:nil];
                // Setting the template property to NO enables the tint color.
                image.template = NO;
                return image;
            } else {
                return [NSImage imageNamed:@"flagged"];
            }
        }
        return nil;
	}
	if ([identifier isEqualToString:MA_Field_HasEnclosure]) {
        if (theArticle.hasEnclosure) {
            if (@available(macOS 11, *)) {
                NSImage *image = [NSImage imageWithSystemSymbolName:@"paperclip"
                                           accessibilityDescription:nil];
                return image;
            } else {
                return [NSImage imageNamed:@"enclosure"];
            }
        }
        return nil;
	}
	
	NSMutableAttributedString * theAttributedString;
	if ([identifier isEqualToString:MA_Field_Headlines]) {
		theAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
		BOOL isSelectedRow = [aTableView isRowSelected:rowIndex] && (NSApp.mainWindow.firstResponder == aTableView);

		if ([db fieldByName:MA_Field_Subject].visible) {
			NSDictionary * topLineDictPtr;

			if (theArticle.read) {
				topLineDictPtr = (isSelectedRow ? selectionDict : topLineDict);
			} else {
				topLineDictPtr = (isSelectedRow ? unreadTopLineSelectionDict : unreadTopLineDict);
			}
			NSString * topString = [NSString stringWithFormat:@"%@", theArticle.title];
			NSMutableAttributedString * topAttributedString = [[NSMutableAttributedString alloc] initWithString:topString attributes:topLineDictPtr];
			[topAttributedString fixFontAttributeInRange:NSMakeRange(0u, topAttributedString.length)];
			[theAttributedString appendAttributedString:topAttributedString];
		}

		// Add the summary line that appears below the title.
		if ([db fieldByName:MA_Field_Summary].visible) {
			NSString * summaryString = theArticle.summary;
			NSInteger maxSummaryLength = MIN([summaryString length], 150);
			NSString * middleString = [NSString stringWithFormat:@"\n%@", [summaryString substringToIndex:maxSummaryLength]];
			NSDictionary * middleLineDictPtr = (isSelectedRow ? selectionDict : middleLineDict);
			NSMutableAttributedString * middleAttributedString = [[NSMutableAttributedString alloc] initWithString:middleString attributes:middleLineDictPtr];
			[middleAttributedString fixFontAttributeInRange:NSMakeRange(0u, middleAttributedString.length)];
			[theAttributedString appendAttributedString:middleAttributedString];
		}
		
		// Add the link line that appears below the summary and title.
		if ([db fieldByName:MA_Field_Link].visible) {
			NSString * articleLink = theArticle.link;
			if (articleLink != nil) {
				NSString * linkString = [NSString stringWithFormat:@"\n%@", articleLink];
				NSMutableDictionary * linkLineDictPtr = (isSelectedRow ? selectionDict : linkLineDict);
				NSURL * articleURL = [NSURL URLWithString:articleLink];
				if (articleURL != nil) {
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

		if ([db fieldByName:MA_Field_Folder].visible) {
			Folder * folder = [db folderFromID:theArticle.folderId];
			[summaryString appendFormat:@"%@", folder.name];
			delimiter = @" - ";
		}
		if ([db fieldByName:MA_Field_Date].visible) {
			[summaryString appendFormat:@"%@%@", delimiter, [NSDateFormatter vna_relativeDateStringFromDate:theArticle.date]];
			delimiter = @" - ";
		}
		if ([db fieldByName:MA_Field_Author].visible) {
			if (!theArticle.author.vna_isBlank) {
				[summaryString appendFormat:@"%@%@", delimiter, theArticle.author];
			}
		}
		if (![summaryString isEqualToString:@""]) {
			summaryString = [NSMutableString stringWithFormat:@"\n%@", summaryString];
		}

		NSMutableAttributedString * summaryAttributedString = [[NSMutableAttributedString alloc] initWithString:summaryString attributes:bottomLineDictPtr];
		[summaryAttributedString fixFontAttributeInRange:NSMakeRange(0u, summaryAttributedString.length)];
		[theAttributedString appendAttributedString:summaryAttributedString];
		return theAttributedString;
	}
	
	NSString * cellString;
	if ([identifier isEqualToString:MA_Field_Date]) {
        cellString = [NSDateFormatter vna_relativeDateStringFromDate:theArticle.date];
	} else if ([identifier isEqualToString:MA_Field_Folder]) {
		Folder * folder = [db folderFromID:theArticle.folderId];
		cellString = folder.name;
	} else if ([identifier isEqualToString:MA_Field_Author]) {
		cellString = theArticle.author;
	} else if ([identifier isEqualToString:MA_Field_Link]) {
		cellString = theArticle.link;
	} else if ([identifier isEqualToString:MA_Field_Subject]) {
		cellString = theArticle.title;
	} else if ([identifier isEqualToString:MA_Field_Summary]) {
		cellString = theArticle.summary;
	} else if ([identifier isEqualToString:MA_Field_Enclosure]) {
		cellString = theArticle.enclosure;
	} else {
		cellString = @"";
		[NSException raise:@"ArticleListView unknown table column identifier exception" format:@"Unknown table column identifier: %@", identifier];
	}
	
	theAttributedString = [[NSMutableAttributedString alloc] initWithString:SafeString(cellString) attributes:(theArticle.read ? reportCellDict : unreadReportCellDict)];
	[theAttributedString fixFontAttributeInRange:NSMakeRange(0u, theAttributedString.length)];
    return theAttributedString;
}

/* menuWillAppear [ExtendedTableView delegate]
 * Called when the popup menu is opened on the table. We ensure that the item under the
 * cursor is selected.
 */
-(void)tableView:(ExtendedTableView *)tableView menuWillAppear:(NSEvent *)theEvent
{
	NSInteger row = [articleList rowAtPoint:[articleList convertPoint:theEvent.locationInWindow fromView:nil]];
	if (row >= 0) {
		// Select the row under the cursor if it isn't already selected
		if (articleList.numberOfSelectedRows <= 1) {
			blockSelectionHandler = YES; // to prevent expansion tooltip from overlapping the menu
			if (row != articleList.selectedRow) {
				[articleList selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
				// will perform a refresh once the menu is deselected
				[self performSelector: @selector(refreshArticleAtCurrentRow) withObject:nil afterDelay:0.0];
			}
			blockSelectionHandler = NO;
		}
	}
}

/* tableViewSelectionDidChange [delegate]
 * Handle the selection changing in the table view unless blockSelectionHandler is set.
 */
-(void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[markReadTimer invalidate];
	markReadTimer = nil;

	if (!blockSelectionHandler) {
		[self refreshArticleAtCurrentRow];
	}
}

/* shouldShowCellExpansionForTableColumn [delegate]
 * Handle expansion tooltip for truncated texts
 */
- (BOOL)tableView:(NSTableView *)tableView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
     // prevent overlapping of contextual menu and expansion tooltip
     return !blockSelectionHandler;
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
	if (!isInTableInit && !isAppInitialising && !isChangingOrientation) {
		NSTableColumn * tableColumn = notification.userInfo[@"NSTableColumn"];
		Field * field = [[Database sharedManager] fieldByName:tableColumn.identifier];
		NSInteger oldWidth = [notification.userInfo[@"NSOldWidth"] integerValue];
		
		if (oldWidth != tableColumn.width) {
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
	if (tableLayout == VNALayoutReport && [columnIdentifer isEqualToString:MA_Field_Subject]) {
		isProgressColumn = YES;
	} else if (tableLayout == VNALayoutCondensed && [columnIdentifer isEqualToString:MA_Field_Headlines]) {
		isProgressColumn = YES;
	}
	
	if (isProgressColumn) {
		ProgressTextCell * realCell = (ProgressTextCell *)cell;
		
		// Set the in-progress flag as appropriate so the progress indicator gets
		// displayed and removed as needed.
		if ([realCell respondsToSelector:@selector(setInProgress:forRow:)]) {
			if (rowIndex == tv.selectedRow && isLoadingHTMLArticle) {
				[realCell setInProgress:YES forRow:rowIndex];
			} else {
				[realCell setInProgress:NO forRow:rowIndex];
			}
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
	[pboard declareTypes:@[VNAPasteboardTypeRSSItem, VNAPasteboardTypeWebURLsWithTitles, NSPasteboardTypeString, NSPasteboardTypeHTML]
                   owner:self];
    if (count == 1) {
        [pboard addTypes:@[VNAPasteboardTypeURL, VNAPasteboardTypeURLName, NSPasteboardTypeURL]
                   owner:self];
    }

	// Open the HTML string
	[fullHTMLText appendString:@"<html><body>"];
	
	// Get all the articles that are being dragged
	NSUInteger msgIndex = rowIndexes.firstIndex;
	while (msgIndex != NSNotFound) {
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
		
		if (count == 1) {
			[pboard setString:msgLink forType:VNAPasteboardTypeURL];
			[pboard setString:msgTitle forType:VNAPasteboardTypeURLName];
			
			// Write the link to the pastboard.
			[[NSURL URLWithString:msgLink] writeToPasteboard:pboard];
		}

		msgIndex = [rowIndexes indexGreaterThanIndex:msgIndex];
	}
	
	// Close the HTML string
	[fullHTMLText appendString:@"</body></html>"];

	// Put string on the pasteboard for external drops.
	[pboard setPropertyList:arrayOfArticles forType:VNAPasteboardTypeRSSItem];
	[pboard setPropertyList:@[arrayOfURLs, arrayOfTitles] forType:VNAPasteboardTypeWebURLsWithTitles];
	[pboard setString:fullPlainText forType:NSPasteboardTypeString];
    [pboard setString:fullHTMLText.vna_stringByEscapingExtendedCharacters forType:NSPasteboardTypeHTML];

	return YES;
}

/* markedArticleRange
 * Retrieve an array of selected articles.
 */
-(NSArray *)markedArticleRange
{
	NSMutableArray * articleArray = nil;
	if (articleList.numberOfSelectedRows > 0) {
		NSIndexSet * rowIndexes = articleList.selectedRowIndexes;
		NSUInteger  rowIndex = rowIndexes.firstIndex;

		articleArray = [NSMutableArray arrayWithCapacity:rowIndexes.count];
		while (rowIndex != NSNotFound) {
			[articleArray addObject:self.controller.articleController.allArticles[rowIndex]];
			rowIndex = [rowIndexes indexGreaterThanIndex:rowIndex];
		}
	}
	return [articleArray copy];
}

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
    [userDefaults removeObserver:self
                      forKeyPath:MAPref_ShowEnclosureBar
                         context:VNAArticleListViewObserverContext];
    [userDefaults removeObserver:self
                      forKeyPath:MAPref_ShowUnreadArticlesInBold
                         context:VNAArticleListViewObserverContext];
	[splitView2 setDelegate:nil];
	[articleList setDelegate:nil];
}

// MARK: Key-value observation

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (context != VNAArticleListViewObserverContext) {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
        return;
    }

    if ([keyPath isEqualToString:MAPref_ShowEnclosureBar]) {
        NSNumber *showEnclosureBar = change[NSKeyValueChangeNewKey];
        if (showEnclosureBar.boolValue) {
            [self refreshArticlePane];
        } else {
            [self hideEnclosureView];
        }
        return;
    }

    if ([keyPath isEqualToString:MAPref_ShowUnreadArticlesInBold]) {
        [self setTableViewFont];
        if (self == self.controller.articleController.mainArticleView) {
            [articleList reloadData];
        }
    }

    //TODO
}

// MARK: ArticleView delegate

@synthesize error;
@synthesize controller;

- (void)startMainFrameLoad
{
    isLoadingHTMLArticle = YES;
}

/// Handle the end of a load whether or not it completed and whether or not an
/// error occurred.
- (void)endMainFrameLoad
{
    if (isLoadingHTMLArticle) {
        isLoadingHTMLArticle = NO;
        articleList.needsDisplay = YES;
    }
}

// MARK : splitView2 delegate

- (void)splitViewWillResizeSubviews:(NSNotification *)notification {
    NSDictionary * info = notification.userInfo;
    NSInteger userResizeKey = ((NSNumber *)info[@"NSSplitViewUserResizeKey"]).integerValue;
    if (userResizeKey == 1) { // user initiated resize
        self.textViewWidthConstraint.active = NO;
        if (self.imbricatedSplitViewResizes) {
            // remove any other constraint affecting articleTextView's horizontal axis,
            // and let autoresizing do the job
            for (NSLayoutConstraint *c in [self.articleTextView constraintsAffectingLayoutForOrientation:NSLayoutConstraintOrientationHorizontal]) {
                if ((c.firstItem == self.articleTextView || c.secondItem == self.articleTextView) && (c != self.textViewWidthConstraint)) {
                    [self.articleTextView removeConstraint:c];
                }
            }
            self.articleTextView.translatesAutoresizingMaskIntoConstraints = YES;
        } else {
            self.imbricatedSplitViewResizes = YES;
        }
    }
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    // update and reactivate constraint
    self.textViewWidthConstraint.constant = self.contentStackView.frame.size.width;
    NSDictionary * info = notification.userInfo;
    NSInteger userResizeKey = ((NSNumber *)info[@"NSSplitViewUserResizeKey"]).integerValue;
    if (userResizeKey == 1) {
        if (self.imbricatedSplitViewResizes) {
            // remove again any other constraint affecting articleTextView's horizontal axis,
            // and let autoresizing do the job
            for (NSLayoutConstraint *c in [self.articleTextView constraintsAffectingLayoutForOrientation:NSLayoutConstraintOrientationHorizontal]) {
                if ((c.firstItem == self.articleTextView || c.secondItem == self.articleTextView) && (c != self.textViewWidthConstraint)) {
                    [self.articleTextView removeConstraint:c];
                }
            }
            self.articleTextView.translatesAutoresizingMaskIntoConstraints = YES;
        } else {
            self.articleTextView.translatesAutoresizingMaskIntoConstraints = NO;
            self.textViewWidthConstraint.active = YES;
        }
        self.imbricatedSplitViewResizes = NO;
    }
}

@end
