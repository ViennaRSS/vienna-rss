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
#import "ArticleView.h"
#import "Preferences.h"
#import "Constants.h"
#import "StringExtensions.h"
#import "HelperFunctions.h"
#import "BrowserPane.h"
#import "Article.h"
#import "Folder.h"
#import "TableViewExtensions.h"
#import "Database.h"
#import "Vienna-Swift.h"

#define LISTVIEW_CELL_IDENTIFIER		@"ArticleCellView"
// 300 seems a reasonable value to avoid calculating too many frames before being able to update display
// this is big enough to allow the user to start reading while the frame is being rendered
#define DEFAULT_CELL_HEIGHT	300.0
#define XPOS_IN_CELL	6.0
#define YPOS_IN_CELL	2.0
#define PROGRESS_INDICATOR_DIMENSION 16

@interface UnifiedDisplayView ()

@property (nonatomic) OverlayStatusBar *statusBar;

-(void)initTableView;
-(void)handleReadingPaneChange:(NSNotificationCenter *)nc;
-(void)handleCellDidResize:(NSNotificationCenter *)nc;
-(BOOL)viewNextUnreadInCurrentFolder:(NSInteger)currentRow;
-(void)markCurrentRead:(NSTimer *)aTimer;
-(void)makeRowSelectedAndVisible:(NSInteger)rowIndex;

@end

@implementation UnifiedDisplayView

#pragma mark -
#pragma mark Init/Dealloc

/* initWithFrame
 * Initialise our view.
 */
-(instancetype)initWithFrame:(NSRect)frame
{
    self= [super initWithFrame:frame];
    if (self)
	{
		markReadTimer = nil;
		rowHeightArray = [[NSMutableArray alloc] init];
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
	[nc addObserver:self selector:@selector(handleReadingPaneChange:) name:@"MA_Notify_ReadingPaneChange" object:nil];
	[nc addObserver:self selector:@selector(handleCellDidResize:) name:@"MA_Notify_CellResize" object:nil];

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

	// Set the target for copy, drag...
    articleList.delegate = self;
    articleList.dataSource = self;
    articleList.accessibilityValueDescription = NSLocalizedString(@"Articles", nil);

    [NSUserDefaults.standardUserDefaults addObserver:self
                                          forKeyPath:MAPref_ShowStatusBar
                                             options:NSKeyValueObservingOptionInitial
                                             context:nil];
}

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
    [NSUserDefaults.standardUserDefaults removeObserver:self
                                             forKeyPath:MAPref_ShowStatusBar];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[articleList setDataSource:nil];
	[articleList setDelegate:nil];
	[rowHeightArray removeAllObjects];
}

- (void)handleCellDidResize:(NSNotification *)nc
{
    ArticleCellView * cell = nc.object;
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

#pragma mark -
#pragma mark WebUIDelegate

/* createWebViewWithRequest
 * Called when the browser wants to create a new window. The request is opened in a new tab.
 */
-(WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	[self.controller openURL:request.URL inPreferredBrowser:YES];
	// Change this to handle modifier key?
	// Is this covered by the webView policy?
	[NSApp.mainWindow makeFirstResponder:self];
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

	// If we still have some useful menu items (other than Webkit's Web Inspector)
	// then use them for the new default menu
	if (newDefaultMenu.count > 0 && ![newDefaultMenu[0] isSeparatorItem])
		defaultMenuItems = [newDefaultMenu copy];
	// otherwise set the default items to nil as we may have removed all the items.
	else
	{
		defaultMenuItems = nil;
	}

	// Return the default menu items.
    return defaultMenuItems;
}

#pragma mark -
#pragma mark WebFrameLoadDelegate

/* didFailLoadWithError
 * Invoked when a location request for frame has failed to load.
 */
-(void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)webFrame
{
	// Not really errors. Load is cancelled or a plugin is grabbing the URL and will handle it by itself.
	if (!([error.domain isEqualToString:WebKitErrorDomain] && (error.code == NSURLErrorCancelled || error.code == WebKitErrorPlugInWillHandleLoad)))
	{
		id obj = sender.superview;
		if ([obj isKindOfClass:[ArticleCellView class]])
		{
			ArticleCellView * cell = (ArticleCellView *)obj;
			[cell setInProgress:NO];
			NSUInteger row= cell.articleRow;
			NSArray * allArticles = self.controller.articleController.allArticles;
			if (row < (NSInteger)allArticles.count)
			{
				[articleList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
			}
		}
		else
			// TODO : what should we do ?
			NSLog(@"Webview error %@ associated to object of class %@", error, [obj class]);
	}
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)webFrame
{
    id obj = sender.superview;
    if ([obj isKindOfClass:[ArticleCellView class]]) {
        ArticleCellView *cell = (ArticleCellView *)obj;
        [cell setInProgress:NO];
    }
}

#pragma mark -
#pragma mark webView progress notifications

/* webViewLoadFinished
 * Invoked when a web view load has finished
 * (called via a WebViewProgressFinishedNotification notification)
 */
- (void)webViewLoadFinished:(NSNotification *)notification
{
    id obj = notification.object;
    if([obj isKindOfClass:[ArticleView class]])
    {
		ArticleView * sender = (ArticleView *)obj;
		id objView = sender.superview;
		if ([objView isKindOfClass:[ArticleCellView class]])
		{
			ArticleCellView * cell = (ArticleCellView *)objView;
			NSUInteger row= [articleList rowForView:objView];
			if (row == cell.articleRow && row < self.controller.articleController.allArticles.count
			  && cell.folderId == [self.controller.articleController.allArticles[row] folderId])
			{	//relevant cell
                NSString* offsetHeight;
                CGFloat fittingHeight;

                [sender forceJavascript];
                offsetHeight = [sender stringByEvaluatingJavaScriptFromString:@"document.documentElement.offsetHeight"];
                [sender useUserPrefsForJavascript];
                fittingHeight = offsetHeight.doubleValue;
                //get the rect of the current webview frame
                NSRect webViewRect = sender.frame;
                //calculate the new frame
                NSRect newWebViewRect = NSMakeRect(0,
                                           0,
                                           NSWidth(webViewRect),
                                           fittingHeight);
                //set the new frame to the webview
                sender.frame = newWebViewRect;
                cell.fittingHeight = fittingHeight;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_CellResize" object:cell];
            }
            else {	//non relevant cell
                [cell setInProgress:NO];
                if (row < self.controller.articleController.allArticles.count)
                {
                    [articleList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
                }
            }
		} else {
			// not an ArticleCellView anymore
			// ???
		}
	}
}

#pragma mark -
#pragma ArticleBaseView delegate

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
	[self.controller.articleController reloadArrayOfArticles];

	// make sure to not change the mark read while searching
    if (articleList.selectedRow < 0 && self.controller.articleController.allArticles.count > 0 )
	{
		BOOL shouldSelectArticle = YES;
		if ([Preferences standardPreferences].markReadInterval > 0.0f)
		{
			Article * article = self.controller.articleController.allArticles[0u];
			if (!article.read)
				shouldSelectArticle = NO;
		}
		if (shouldSelectArticle)
			[self makeRowSelectedAndVisible:0];
	}
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

/* saveTableSettings
 * Save the current folder and article
 */
-(void)saveTableSettings
{
	Preferences * prefs = [Preferences standardPreferences];

	// Remember the current folder and article
    NSString * guid = self.selectedArticle.guid;
	[prefs setInteger:self.controller.articleController.currentFolderId forKey:MAPref_CachedFolderID];
	[prefs setObject:(guid != nil ? guid : @"") forKey:MAPref_CachedArticleGUID];
}

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger)flags
{
	return [self.controller handleKeyDown:keyChar withFlags:flags];
}

/* canDeleteMessageAtRow
 * Returns YES if the message at the specified row can be deleted, otherwise NO.
 */
-(BOOL)canDeleteMessageAtRow:(NSInteger)row
{
	return articleList.window.visible && self.selectedArticle != nil && ![Database sharedManager].readOnly;
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
	//TODO
}

/* handleReadingPaneChange
 * Respond to the change to the reading pane orientation.
 */
-(void)handleReadingPaneChange:(NSNotificationCenter *)nc
{
	if (self == self.controller.articleController.mainArticleView)
	{
		[articleList reloadData];
	}
}

/* makeRowSelectedAndVisible
 * Selects the specified row in the table and makes it visible by
 * scrolling to it.
 */
-(void)makeRowSelectedAndVisible:(NSInteger)rowIndex
{
	if (self.controller.articleController.allArticles.count == 0u)
	{
		[articleList deselectAll:self];
	}
	else
	{
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
        [self.controller skipFolder:nil];
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
        [self.controller.articleController goBack];
    }
}

/* viewLink
 * There's no view link address for article views. If we eventually implement a local
 * scheme such as vienna:<feedurl>/<guid> then we could use that as a link address.
 */
-(NSString *)viewLink
{
	return nil;
}

/* refreshFolder
 * Refreshes the current folder by applying the current sort or thread
 * logic and redrawing the article list. The selected article is preserved
 * and restored on completion of the refresh.
 */
-(void)refreshFolder:(NSInteger)refreshFlag
{
    Article * currentSelectedArticle = self.selectedArticle;

    switch (refreshFlag)
    {
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
}

/* startLoadIndicator
 * add the indicator of articles' data being loaded
 */
-(void)startLoadIndicator
{
	if (progressIndicator == nil)
	{
		NSRect progressIndicatorFrame;
		progressIndicatorFrame.size = NSMakeSize(articleList.visibleRect.size.width, PROGRESS_INDICATOR_DIMENSION);
		progressIndicatorFrame.origin = articleList.visibleRect.origin;
		progressIndicator = [[NSProgressIndicator alloc] initWithFrame:progressIndicatorFrame];
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

#pragma mark -
#pragma mark NSTableViewDelegate

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of articles in the current folder.
 */
-(NSInteger)numberOfRowsInTableView:(NSTableView*)aTableView
{
	return self.controller.articleController.allArticles.count;
}

- (CGFloat)tableView:(NSTableView *)aListView heightOfRow:(NSInteger)row
{
	if (row >= rowHeightArray.count)
	{
		NSInteger toAdd = row - rowHeightArray.count + 1 ;
		for (NSInteger i = 0 ; i < toAdd ; i++) {
			[rowHeightArray addObject:@(0)];
		}
		return (CGFloat)DEFAULT_CELL_HEIGHT;
	}
	else
	{
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
	if (![tableView isEqualTo:articleList])
		return nil;

	ArticleCellView *cellView = (ArticleCellView*)[tableView makeViewWithIdentifier:LISTVIEW_CELL_IDENTIFIER owner:self];

	if (cellView == nil)
	{
		cellView = [[ArticleCellView alloc] initWithFrame:NSMakeRect(
		        XPOS_IN_CELL, YPOS_IN_CELL, tableView.bounds.size.width - XPOS_IN_CELL, DEFAULT_CELL_HEIGHT)];
		cellView.identifier = LISTVIEW_CELL_IDENTIFIER;
	} else {
	    // recycled cell : minimum safety measures
	    [cellView setInProgress:NO];
        self.statusBar.label = nil;
	}

	NSArray * allArticles = self.controller.articleController.allArticles;
	if (row < 0 || row >= allArticles.count)
	    return nil;

	Article * theArticle = allArticles[row];
	NSInteger articleFolderId = theArticle.folderId;

	cellView.folderId = articleFolderId;
	cellView.articleRow = row;
	cellView.listView = articleList;
	NSObject<ArticleContentView> *articleContentView = cellView.articleView;
    NSView *view;
    if ([articleContentView isKindOfClass:WebKitArticleView.class])
    {
        view = (WebKitArticleView *)articleContentView;
        ((CustomWKWebView *)view).hoverListener = self;
    } else {
        view = ((ArticleView *) articleContentView);
    }
	[view removeFromSuperviewWithoutNeedingDisplay];
	view.frame = cellView.frame;
	[cellView addSubview:view];
	[cellView setInProgress:YES];
	[articleContentView setArticles:@[theArticle]];
    return cellView;
}

/* menuWillAppear [ExtendedTableView delegate]
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
	[articleList scrollRowToVisible:row];
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
        if (@available(macOS 10.13, *)) {
            [pboard addTypes:@[VNAPasteboardTypeURL, VNAPasteboardTypeURLName, NSPasteboardTypeURL] owner:self];
        } else {
            [pboard addTypes:@[VNAPasteboardTypeURL, VNAPasteboardTypeURLName, NSURLPboardType] owner:self];
        }
    }

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
			[pboard setString:msgLink forType:VNAPasteboardTypeURL];
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

/* delete
 * Handle the Delete action when the article list has focus.
 */
-(IBAction)delete:(id)sender
{
	[APPCONTROLLER deleteMessage:self];
}

/* validateMenuItem
 * This is our override where we handle item validation for the
 * commands that we own.
 */
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(copy:))
	{
		return (articleList.numberOfSelectedRows > 0);
	}
	if (menuItem.action == @selector(delete:))
	{
        return [self canDeleteMessageAtRow:articleList.selectedRow];
	}
	if (menuItem.action == @selector(selectAll:))
	{
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
	if (articleList.selectedRowIndexes.count > 0)
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

#pragma mark -
#pragma mark Keyboard (NSResponder)

- (BOOL)acceptsFirstResponder
{
	return YES;
}

-(BOOL)becomeFirstResponder
{
    NSInteger currentSelectedRow = articleList.selectedRow;
	if (currentSelectedRow >= 0 && currentSelectedRow < self.controller.articleController.allArticles.count)
    {
		[articleList selectRowIndexes:[NSIndexSet indexSetWithIndex:currentSelectedRow] byExtendingSelection:NO];
    }
    else if (self.controller.articleController.allArticles.count != 0u)
    {
		[articleList selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
	[NSApp.mainWindow makeFirstResponder:articleList];
    return YES;
}

/* keyDown
 * Here is where we handle special keys when this view
 * has the focus so we can do custom things.
 */
-(void)keyDown:(NSEvent *)theEvent
{
	if (theEvent.characters.length == 1)
	{
		unichar keyChar = [theEvent.characters characterAtIndex:0];
		if ([self.controller handleKeyDown:keyChar withFlags:theEvent.modifierFlags])
			return;
	}
	[self interpretKeyEvents:@[theEvent]];
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
            [articleList.enclosingScrollView addSubview:self.statusBar];
        } else if (!isStatusBarShown && self.statusBar) {
            [self.statusBar removeFromSuperview];
            self.statusBar = nil;
        }
    }
}

// MARK: WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:CustomWKWebView.mouseDidEnterName]) {
        NSString * link = (NSString *)message.body;
        self.statusBar.label = link;
    } else if ([message.name isEqualToString:CustomWKWebView.mouseDidExitName]) {
        self.statusBar.label = nil;
    }
}
@end
