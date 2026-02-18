//
//  UnifiedDisplayView.m
//  Vienna
//
//  Created by Steve Palmer, Barijaona Ramaholimihaso and other Vienna contributors
//  Copyright (c) 2004-2021 Vienna contributors. All rights reserved.
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

#import "UnifiedDisplayView.h"
#import "ArticleController.h"
#import "AppController.h"
#import "ArticleCellView.h"
#import "Preferences.h"
#import "Constants.h"
#import "StringExtensions.h"
#import "Article.h"
#import "Folder.h"
#import "Database.h"
#import "FilterBarViewController.h"
#import "NSResponder+EventHandler.h"
#import "Vienna-Swift.h"

#define LISTVIEW_CELL_IDENTIFIER		@"ArticleCellView"
// 300 seems a reasonable value to avoid calculating too many frames before being able to update display
// this is big enough to allow the user to start reading while the frame is being rendered
#define DEFAULT_CELL_HEIGHT	300.0
#define XPOS_IN_CELL	6.0
#define YPOS_IN_CELL	2.0

static void *VNAUnifiedDisplayViewObserverContext = &VNAUnifiedDisplayViewObserverContext;

@interface UnifiedDisplayView () <CustomWKHoverUIDelegate>

@property (nonatomic) OverlayStatusBar *statusBar;

-(void)initTableView;
-(void)handleReadingPaneChange:(NSNotification *)notification;
-(void)handleCellDidResize:(NSNotification *)notification;
-(BOOL)viewNextUnreadInCurrentFolder:(NSInteger)currentRow;
-(void)markCurrentRead:(NSTimer *)aTimer;
-(void)makeRowSelectedAndVisible:(NSInteger)rowIndex;

@end

@implementation UnifiedDisplayView {
    IBOutlet NSTableView *articleList;

    NSTimer *markReadTimer;

    NSMutableArray *rowHeightArray;
}

@synthesize filterBarViewController = _filterBarViewController;

#pragma mark -
#pragma mark Init/Dealloc

/* initWithFrame
 * Initialise our view.
 */
-(instancetype)initWithFrame:(NSRect)frame
{
    self= [super initWithFrame:frame];
    if (self) {
		markReadTimer = nil;
		rowHeightArray = [[NSMutableArray alloc] init];
        _filterBarViewController = [VNAFilterBarViewController instantiateFromNib];
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
	[nc addObserver:self selector:@selector(handleReadingPaneChange:) name:MA_Notify_ReadingPaneChange object:nil];
	[nc addObserver:self selector:@selector(handleStyleChange:) name:MA_Notify_StyleChange object:nil];
	[nc addObserver:self selector:@selector(handleCellDidResize:) name:MA_Notify_CellResize object:nil];

    [self initTableView];
}

/* initTableView
 * Do all the initialization for the article list table view control
 */
-(void)initTableView
{
	// Variable initialization here
	[articleList sizeToFit];
	[articleList setAllowsMultipleSelection:YES];

	NSMenu * articleListMenu = [[NSMenu alloc] init];

	[articleListMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"markRead.menuItem",
																		nil,
																		NSBundle.mainBundle,
																		@"Mark Read",
																		@"Title of a menu item")
							   action:@selector(markAsRead:)
						keyEquivalent:@""];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Mark Unread", @"Title of a menu item")
							   action:@selector(markAsUnread:)
						keyEquivalent:@""];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Mark Flagged", @"Title of a menu item")
							   action:@selector(toggleFlag:)
						keyEquivalent:@""];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Delete Article", @"Title of a menu item")
							   action:@selector(delete:)
						keyEquivalent:@""];
	[articleListMenu addItemWithTitle:NSLocalizedString(@"Restore Article", @"Title of a menu item")
							   action:@selector(restore:)
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

	articleListMenu.delegate = self;
	articleList.menu = articleListMenu;

	// Set the target for copy, drag...
    articleList.delegate = self;
    articleList.dataSource = self;
    articleList.accessibilityValueDescription = NSLocalizedString(@"Articles", nil);

    self.filterBarViewController.filterBarContainer = articleList.enclosingScrollView;

    [NSUserDefaults.standardUserDefaults addObserver:self
                                          forKeyPath:MAPref_ShowStatusBar
                                             options:NSKeyValueObservingOptionInitial
                                             context:VNAUnifiedDisplayViewObserverContext];
}

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
    [NSUserDefaults.standardUserDefaults removeObserver:self
                                             forKeyPath:MAPref_ShowStatusBar
                                                context:VNAUnifiedDisplayViewObserverContext];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[articleList setDataSource:nil];
	[articleList setDelegate:nil];
	[rowHeightArray removeAllObjects];
}

- (void)handleCellDidResize:(NSNotification *)notification
{
    ArticleCellView * cell = notification.object;
    NSUInteger row = cell.articleRow;
    CGFloat fittingHeight = cell.fittingHeight;
    if (row < rowHeightArray.count) {
        rowHeightArray[row] = @(fittingHeight);
    } else {
        NSInteger toAdd = row - rowHeightArray.count;
        for (NSInteger i = 0; i < toAdd; i++) {
            [rowHeightArray addObject:@(0)];
        }
        [rowHeightArray addObject:@(fittingHeight)];
    }
    [articleList noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:row]];
    [cell setInProgress:NO];
}

#pragma mark - ArticleBaseView delegate

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

/* scrollToArticle
 * Moves the selection to the specified article.
 */
-(void)scrollToArticle:(NSString *)guid
{
	if (guid != nil) {
		NSInteger rowIndex = 0;
		for (Article * thisArticle in self.articleController.allArticles) {
			if ([thisArticle.guid isEqualToString:guid]) {
				[self makeRowSelectedAndVisible:rowIndex];
				return;
			}
			++rowIndex;
		}
	} else {
		[articleList scrollRowToVisible:0];
	}

	[articleList deselectAll:self];
}

#pragma mark -
#pragma mark BaseView delegate

/* mainView
 * Return the primary view of this view.
 */
-(NSView *)mainView
{
	return self;
}

/* performFindPanelAction
 * Implement the search action.
 */
-(void)performFindPanelAction:(NSInteger)actionTag
{
	[self.articleController reloadArrayOfArticles];

	// make sure to not change the mark read while searching
    if (articleList.selectedRow < 0 && self.articleController.allArticles.count > 0 ) {
		BOOL shouldSelectArticle = YES;
		if ([Preferences standardPreferences].markReadInterval > 0.0f) {
			Article * article = self.articleController.allArticles[0u];
			if (!article.isRead) {
				shouldSelectArticle = NO;
			}
		}
		if (shouldSelectArticle) {
			[self makeRowSelectedAndVisible:0];
		}
	}
}

/* saveTableSettings
 * Save the current folder and article
 */
-(void)saveTableSettings
{
	Preferences * prefs = [Preferences standardPreferences];

	// Remember the current folder and article
    NSString * guid = self.selectedArticle.guid;
	[prefs setInteger:self.articleController.currentFolderId forKey:MAPref_CachedFolderID];
	[prefs setString:(guid != nil ? guid : @"") forKey:MAPref_CachedArticleGUID];
}

/* selectedArticle
 * Returns the selected article, or nil if no article is selected.
 */
-(Article *)selectedArticle
{
	NSInteger currentSelectedRow = articleList.selectedRow;
	return (currentSelectedRow >= 0 && currentSelectedRow < self.articleController.allArticles.count) ? self.articleController.allArticles[currentSelectedRow] : nil;
}

/* printDocument
 * Print the active article.
 */
-(void)printDocument:(id)sender
{
	//TODO
}

/* handleReadingPaneChange
 * Respond to the change to the reading pane orientation.
 */
-(void)handleReadingPaneChange:(NSNotification *)notification
{
	if (self == self.articleController.mainArticleView) {
		[articleList reloadData];
	}
}

/* handleStyleChange
 * Respond to an article style change
 */
-(void)handleStyleChange:(NSNotification *)notification
{
    if (self == self.articleController.mainArticleView) {
        [articleList performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
    }
}

/* makeRowSelectedAndVisible
 * Selects the specified row in the table and makes it visible by
 * scrolling to it.
 */
-(void)makeRowSelectedAndVisible:(NSInteger)rowIndex
{
	if (self.articleController.allArticles.count == 0u) {
		[articleList deselectAll:self];
	} else {
		[articleList selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];
		[articleList scrollRowToVisible:rowIndex];
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

	NSArray * allArticles = self.articleController.allArticles;
	NSInteger totalRows = allArticles.count;
	Article * theArticle;
	while (currentRow < totalRows) {
		theArticle = allArticles[currentRow];
		if (!theArticle.isRead) {
			[self makeRowSelectedAndVisible:currentRow];
			return YES;
		}
		++currentRow;
	}
	return NO;
}

/* selectFirstUnreadInFolder
 * Moves the selection to the first unread article in the current article list or the
 * first article if the folder has no unread articles.
 */
-(BOOL)selectFirstUnreadInFolder
{
	BOOL result = [self viewNextUnreadInCurrentFolder:-1];
	if (!result) {
		NSInteger count = self.articleController.allArticles.count;
		if (count > 0) {
			[self makeRowSelectedAndVisible:0];
		}
	}
	return result;
}

- (void)scrollDownDetailsOrNextUnread
{
    NSScrollView *scrollView = [articleList enclosingScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSPoint newOrigin = [clipView bounds].origin;
    newOrigin.y = newOrigin.y + NSHeight(scrollView.documentVisibleRect) -20;
    if (newOrigin.y < articleList.frame.size.height - 20) {
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0.3];
        [[clipView animator] setBoundsOrigin:newOrigin];
        [scrollView reflectScrolledClipView:[scrollView contentView]];
        [NSAnimationContext endGrouping];
    } else {
        [self.appController skipFolder:nil];
    }
}

- (void)scrollUpDetailsOrGoBack
{
    NSScrollView *scrollView = [articleList enclosingScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSPoint newOrigin = [clipView bounds].origin;
    if (newOrigin.y > 2) {
        newOrigin.y = newOrigin.y - NSHeight(scrollView.documentVisibleRect);
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0.3];
        [[clipView animator] setBoundsOrigin:newOrigin];
        [scrollView reflectScrolledClipView:[scrollView contentView]];
        [NSAnimationContext endGrouping];
    } else {
        [self.articleController goBack:nil];
    }
}

/* refreshFolder
 * Refreshes the current folder by applying the current sort or thread
 * logic and redrawing the article list. The selected article is preserved
 * and restored on completion of the refresh.
 */
-(void)refreshFolder:(NSInteger)refreshFlag
{
    Article * currentSelectedArticle = self.selectedArticle;

    switch (refreshFlag) {
        case VNARefreshRedrawList:
            break;
        case VNARefreshReapplyFilter:
            [self.articleController refilterArrayOfArticles];
            [self.articleController sortArticles];
            break;
        case VNARefreshSortAndRedraw:
            [self.articleController sortArticles];
            break;
    }

	[articleList reloadData];
    [self scrollToArticle:currentSelectedArticle.guid];
}

/* markCurrentRead
 * Mark the current article as read.
 */
-(void)markCurrentRead:(NSTimer *)aTimer
{
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !theArticle.isRead && ![Database sharedManager].readOnly) {
		[self.articleController markReadByArray:@[theArticle] readFlag:YES];
	}
}

#pragma mark -
#pragma mark NSTableViewDelegate

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of articles in the current folder.
 */
-(NSInteger)numberOfRowsInTableView:(NSTableView*)aTableView
{
	return self.articleController.allArticles.count;
}

- (CGFloat)tableView:(NSTableView *)aListView heightOfRow:(NSInteger)row
{
	if (row >= rowHeightArray.count) {
		NSInteger toAdd = row - rowHeightArray.count + 1 ;
		for (NSInteger i = 0 ; i < toAdd ; i++) {
			[rowHeightArray addObject:@(0)];
		}
		return (CGFloat)DEFAULT_CELL_HEIGHT;
	} else {
		id object= rowHeightArray[row];
        CGFloat height = [object doubleValue];
        if (height > 0) {
		    return  (height) ;
		} else {
		    return (CGFloat)DEFAULT_CELL_HEIGHT;
		}
	}
}

/* cellForRow [datasource]
 * Called by the table view to obtain the object at the specified row.
 */
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if (![tableView isEqualTo:articleList]) {
		return nil;
	}

	ArticleCellView *cellView = (ArticleCellView*)[tableView makeViewWithIdentifier:LISTVIEW_CELL_IDENTIFIER owner:self];

	if (cellView == nil) {
		cellView = [[ArticleCellView alloc] initWithFrame:NSMakeRect(
		        XPOS_IN_CELL, YPOS_IN_CELL, tableView.bounds.size.width - XPOS_IN_CELL, DEFAULT_CELL_HEIGHT)];
		cellView.identifier = LISTVIEW_CELL_IDENTIFIER;
	} else {
	    // recycled cell : minimum safety measures
	    [cellView setInProgress:NO];
        self.statusBar.label = nil;
	}

	NSArray * allArticles = self.articleController.allArticles;
	if (row < 0 || row >= allArticles.count) {
	    return nil;
	}

	Article * theArticle = allArticles[row];
	NSInteger articleFolderId = theArticle.folderId;

	cellView.articleController = self.articleController;
	cellView.folderId = articleFolderId;
	cellView.articleRow = row;
	cellView.listView = articleList;
	NSObject<ArticleContentView> *articleContentView = cellView.articleView;
    NSView *view;
    view = (WebKitArticleView *)articleContentView;
    ((CustomWKWebView *)view).hoverUiDelegate = self;
	[view removeFromSuperviewWithoutNeedingDisplay];
	view.frame = cellView.frame;
	[cellView addSubview:view];
	[cellView setInProgress:YES];
	[articleContentView setArticles:@[theArticle]];
    return cellView;
}

/* tableViewSelectionDidChange [delegate]
 * Handle the selection changing in the table view.
 */
-(void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
}

/* tableViewColumnDidResize
 * This notification is called when the user completes resizing a column.
 */
- (void)tableViewColumnDidResize:(NSNotification *)notification
{
    if ([notification.object isEqualTo:articleList]) {
        [articleList sizeToFit];
        [articleList reloadData];
     }
}

/* copyTableSelection
 * This is the common copy selection code. We build an array of dictionary entries each of
 * which include details of each selected article in the standard RSS item format defined by
 * Ranchero NetNewsWire. See http://ranchero.com/netnewswire/rssclipboard.php for more details.
 */
-(BOOL)copyIndexesSelection:(NSIndexSet*)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray * arrayOfArticles = [[NSMutableArray alloc] init];
	NSMutableArray * arrayOfURLs = [[NSMutableArray alloc] init];
	NSMutableArray * arrayOfTitles = [[NSMutableArray alloc] init];
	NSMutableString * fullHTMLText = [[NSMutableString alloc] init];
	NSMutableString * fullPlainText = [[NSMutableString alloc] init];
	Database * db = [Database sharedManager];
	NSInteger count = rowIndexes.count;

	// Set up the pasteboard
	[pboard declareTypes:@[VNAPasteboardTypeRSSItem, VNAPasteboardTypeWebURLsWithTitles, NSPasteboardTypeString, NSPasteboardTypeHTML] owner:self];
    if (count == 1) {
        [pboard addTypes:@[NSPasteboardTypeURL, VNAPasteboardTypeURLName]
                   owner:self];
    }

	// Open the HTML string
	[fullHTMLText appendString:@"<html style=\"font-family:sans-serif;\">"
                                "<head><meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\"></head><body>"];

	// Get all the articles that are being dragged
	NSUInteger msgIndex = rowIndexes.firstIndex;
	while (msgIndex != NSNotFound) {
		Article * thisArticle = self.articleController.allArticles[msgIndex];
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
        [fullPlainText appendFormat:@"%@\n%@\n\n", msgTitle, thisArticle.summary];

		// Add HTML version too.
		[fullHTMLText appendFormat:@"<div class=\"info\"><a href=\"%@\">%@</a><div>"
                                    "<div class=\"articleBodyStyle\">%@</div><br>", msgLink, msgTitle, msgText];

		if (count == 1) {
			[pboard setString:msgLink forType:NSPasteboardTypeURL];
			[pboard setString:msgTitle forType:VNAPasteboardTypeURLName];

			// Write the link to the pastboard.
			[[NSURL URLWithString:msgLink] writeToPasteboard:pboard];
		}

		//increment
    	msgIndex = [rowIndexes indexGreaterThanIndex: msgIndex];
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

/* writeRowsWithIndexes
 * Use the common copy selection code to copy to
 * the pasteboard.
 */
-(BOOL)tableView:(NSTableView*)aListView writeRowsWithIndexes:(NSIndexSet*)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	return [self copyIndexesSelection:rowIndexes toPasteboard:pboard];
}

/* copy
 * Handle the Copy action when the article list has focus.
 */
-(IBAction)copy:(id)sender
{
	[self copyIndexesSelection:articleList.selectedRowIndexes toPasteboard:[NSPasteboard generalPasteboard]];
}

/* validateMenuItem
 * This is our override where we handle item validation for the
 * commands that we own.
 */
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(copy:)) {
		return (articleList.numberOfSelectedRows > 0);
	}
	if (menuItem.action == @selector(selectAll:)) {
		return YES;
	}
	return NO;
}

/* markedArticleRange
 * Retrieve an array of selected articles.
 */
-(NSArray *)markedArticleRange
{
	NSMutableArray * articleArray = nil;
	if (articleList.selectedRowIndexes.count > 0) {
		NSIndexSet * rowIndexes = articleList.selectedRowIndexes;
		NSUInteger  rowIndex = rowIndexes.firstIndex;

		articleArray = [NSMutableArray arrayWithCapacity:rowIndexes.count];
		while (rowIndex != NSNotFound) {
			[articleArray addObject:self.articleController.allArticles[rowIndex]];
			rowIndex = [rowIndexes indexGreaterThanIndex:rowIndex];
		}
	}
	return [articleArray copy];
}

#pragma mark -
#pragma mark Keyboard (NSResponder)

- (BOOL)acceptsFirstResponder
{
	return YES;
}

-(BOOL)becomeFirstResponder
{
    NSInteger currentSelectedRow = articleList.selectedRow;
	if (currentSelectedRow >= 0 && currentSelectedRow < self.articleController.allArticles.count) {
		[articleList selectRowIndexes:[NSIndexSet indexSetWithIndex:currentSelectedRow] byExtendingSelection:NO];
    } else if (self.articleController.allArticles.count != 0u) {
		[articleList selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
	[NSApp.mainWindow makeFirstResponder:articleList];
    return YES;
}

-(void)keyDown:(NSEvent *)event
{
    if ([self vna_handleEvent:event]) {
        return;
    }
    [super keyDown:event];
}

// MARK: Key-value observation

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (context != VNAUnifiedDisplayViewObserverContext) {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
        return;
    }

    if ([keyPath isEqualToString:MAPref_ShowStatusBar]) {
        BOOL isStatusBarShown = [Preferences standardPreferences].showStatusBar;
        if (isStatusBarShown && !self.statusBar) {
            self.statusBar = [OverlayStatusBar new];
            [self addSubview:self.statusBar];
        } else if (!isStatusBarShown && self.statusBar) {
            [self.statusBar removeFromSuperview];
            self.statusBar = nil;
        }
    }
}

// MARK: - NSMenuDelegate

// Called when the popup menu is opened on the table. We ensure that the item
// under the cursor is selected.
- (void)menuWillOpen:(NSMenu *)menu
{
    NSInteger clickedRow = articleList.clickedRow;
    if (clickedRow >= 0) {
        // Select the row under the cursor if it isn't already selected
        if (articleList.numberOfSelectedRows <= 1) {
            [articleList selectRowIndexes:[NSIndexSet indexSetWithIndex:clickedRow]
                     byExtendingSelection:NO];
        }
    }
    [articleList scrollRowToVisible:clickedRow];
}

// MARK: CustomWKHoverUIDelegate

-(void)hoveredWithLink:(NSString *)link {
    self.statusBar.label = link;
}

@end
