//
//  UnifiedDisplayView.m
//  Vienna
//
//  Created by Steve Palmer, Barijaona Ramaholimihaso and other Vienna contributors
//  Copyright (c) 2004-2014 Vienna contributors. All rights reserved.
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

#define LISTVIEW_CELL_IDENTIFIER		@"ArticleCellView"
// 150 seems a reasonable value to avoid calculating too many frames before being able to update display
#define DEFAULT_CELL_HEIGHT	150
#define XPOS_IN_CELL	6
#define YPOS_IN_CELL	2

// Private functions
@interface UnifiedDisplayView (Private)
	-(void)initTableView;
	-(BOOL)copyTableSelection:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard;
	-(void)selectArticleAfterReload;
	-(void)handleReadingPaneChange:(NSNotificationCenter *)nc;
	-(BOOL)scrollToArticle:(NSString *)guid;
	-(void)selectFirstUnreadInFolder;
	-(BOOL)viewNextUnreadInCurrentFolder:(int)currentRow;
	-(void)markCurrentRead:(NSTimer *)aTimer;
	-(void)makeRowSelectedAndVisible:(int)rowIndex;
	-(void)printDocument;
@end

@implementation UnifiedDisplayView

#pragma mark -
#pragma mark Init/Dealloc

/* initWithFrame
 * Initialise our view.
 */
-(id)initWithFrame:(NSRect)frame
{
    self= [super initWithFrame:frame];
    if (self)
	{
		blockSelectionHandler = NO;
		blockMarkRead = NO;
		guidOfArticleToSelect = nil;
		markReadTimer = nil;
		isCurrentPageFullHTML = NO;
		currentURL = nil;
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
	[nc addObserver:self selector:@selector(handleArticleListStateChange:) name:@"MA_Notify_ArticleListStateChange" object:nil];

}

/* initTableView
 * Do all the initialization for the article list table view control
 */
-(void)initTableView
{
	// Variable initialization here
	currentSelectedRow = -1;

	[articleList setBackgroundColor:[NSColor whiteColor]];
	[articleList setAllowsMultipleSelection:YES];

	// Dynamically create the popup menu. This is one less thing to
	// explicitly localise in the NIB file.
	NSMenu * articleListMenu = [[NSMenu alloc] init];
	[articleListMenu addItem:copyOfMenuItemWithAction(@selector(markRead:))];
	[articleListMenu addItem:copyOfMenuItemWithAction(@selector(markUnread:))];
	[articleListMenu addItem:copyOfMenuItemWithAction(@selector(markFlagged:))];
	[articleListMenu addItem:copyOfMenuItemWithAction(@selector(deleteMessage:))];
	[articleListMenu addItem:copyOfMenuItemWithAction(@selector(restoreMessage:))];
	[articleListMenu addItem:copyOfMenuItemWithAction(@selector(downloadEnclosure:))];
	[articleListMenu addItem:[NSMenuItem separatorItem]];
	[articleListMenu addItem:copyOfMenuItemWithAction(@selector(viewSourceHomePage:))];
	NSMenuItem * alternateItem = copyOfMenuItemWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	[alternateItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
	[alternateItem setAlternate:YES];
	[articleListMenu addItem:alternateItem];
	[articleListMenu addItem:copyOfMenuItemWithAction(@selector(viewArticlePages:))];
	alternateItem = copyOfMenuItemWithAction(@selector(viewArticlePagesInAlternateBrowser:));
	[alternateItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
	[alternateItem setAlternate:YES];
	[articleListMenu addItem:alternateItem];
	[articleList setMenu:articleListMenu];
	[articleListMenu release];

	// Set the target for copy, drag...
	[articleList setDelegate:self];
}

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[articleList setDelegate:nil];
	[markReadTimer release];
	markReadTimer=nil;
	[guidOfArticleToSelect release];
	guidOfArticleToSelect=nil;
	[currentURL release];
	currentURL=nil;
	[rowHeightArray release];
	rowHeightArray=nil;
	[super dealloc];
}

#pragma mark -
#pragma mark WebUIDelegate

/* createWebViewWithRequest
 * Called when the browser wants to create a new window. The request is opened in a new tab.
 */
-(WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	[controller openURL:[request URL] inPreferredBrowser:YES];
	// Change this to handle modifier key?
	// Is this covered by the webView policy?
	[[NSApp mainWindow] makeFirstResponder:self];
	return nil;
}

/* runJavaScriptAlertPanelWithMessage
 * Called when the browser wants to display a JavaScript alert panel containing the specified message.
 */
- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
	NSRunInformationalAlertPanel(NSLocalizedString(@"JavaScript", @""),	// title
		@"%@",	// message placeholder
		NSLocalizedString(@"OK", @""),	// default button
		nil,	// alt button
		nil,	// other button
		message);
}

/* runJavaScriptConfirmPanelWithMessage
 * Called when the browser wants to display a JavaScript confirmation panel with the specified message.
 */
- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
	NSInteger result = NSRunInformationalAlertPanel(NSLocalizedString(@"JavaScript", @""),	// title
		@"%@",	// message placeholder
		NSLocalizedString(@"OK", @""),	// default button
		NSLocalizedString(@"Cancel", @""),	// alt button
		nil,
		message);
	return NSAlertDefaultReturn == result;
}

/* setStatusText
 * Called from the webview when some JavaScript writes status text. Echo this to
 * our status bar.
 */
-(void)webView:(WebView *)sender setStatusText:(NSString *)text
{
	if ([[controller browserView] activeTabItemView] == self)
		[controller setStatusMessage:text persist:NO];
}

/* mouseDidMoveOverElement
 * Called from the webview when the user positions the mouse over an element. If it's a link
 * then echo the URL to the status bar like Safari does.
 */
-(void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(NSUInteger )modifierFlags
{
	NSURL * url = [elementInformation valueForKey:@"WebElementLinkURL"];
	[controller setStatusMessage:(url ? [url absoluteString] : @"") persist:NO];
}

/* contextMenuItemsForElement
 * Creates a new context menu for our article's web view.
 */
-(NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	// If this is an URL link, do the link-specific items.
	NSURL * urlLink = [element valueForKey:WebElementLinkURLKey];
	if (urlLink != nil)
		return [controller contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];

	// If we have a full HTML page then do the additional web-page specific items.
	if (isCurrentPageFullHTML)
	{
		WebFrame * frameKey = [element valueForKey:WebElementFrameKey];
		if (frameKey != nil)
			return [controller contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
	}

	// Remove the reload menu item if we don't have a full HTML page.
	if (!isCurrentPageFullHTML)
	{
		NSMutableArray * newDefaultMenu = [[NSMutableArray alloc] init];
		int count = [defaultMenuItems count];
		int index;

		// Copy over everything but the reload menu item, which we can't handle if
		// this is not a full HTML page since we don't have an URL.
		for (index = 0; index < count; index++)
		{
			NSMenuItem * menuItem = [defaultMenuItems objectAtIndex:index];
			if ([menuItem tag] != WebMenuItemTagReload)
				[newDefaultMenu addObject:menuItem];
		}

		// If we still have some menu items then use that for the new default menu, otherwise
		// set the default items to nil as we may have removed all the items.
		if ([newDefaultMenu count] > 0)
			defaultMenuItems = [newDefaultMenu autorelease];
		else
        {
			defaultMenuItems = nil;
            [newDefaultMenu release];
        }
    }

	// Return the default menu items.
    return defaultMenuItems;
}

#pragma mark -
#pragma mark WebFrameLoadDelegate

/* didCommitLoadForFrame
 * Invoked when content of a frame starts arriving for a webview load
 */
-(void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)webFrame
{
    if([webFrame isEqual:[sender mainFrame]])
    {
		id obj = [sender superview];
		if ([obj isKindOfClass:[ArticleCellView class]]) {
			ArticleCellView * cell = (ArticleCellView *)obj;
			[cell setInProgress:YES];
			NSRect frame = sender.frame;
			frame.size.height = 1;        // Set the height to a small one.
			frame.size.width = 1;
		}
	}
}

/* didFailLoadWithError
 * Invoked when a location request for frame has failed to load.
 */
-(void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)webFrame
{
	// Not really an error. A plugin is grabbing the URL and will handle it by itself.
	if (!([[error domain] isEqualToString:WebKitErrorDomain] && [error code] == WebKitErrorPlugInWillHandleLoad))
	{
		id obj = [sender superview];
		if ([obj isKindOfClass:[ArticleCellView class]])
		{
			ArticleCellView * cell = (ArticleCellView *)obj;
			[cell setInProgress:NO];
			NSUInteger row= [cell articleRow];
			NSArray * allArticles = [articleController allArticles];
			if (row < (NSInteger)[allArticles count])
			{
				NSRect frame = sender.frame;
				frame.size.height = 1;        // Set the height to a small one.
				frame.size.width = 1;
				[articleList reloadRowAtIndex:row];
			}
		}
		else
			// TODO : what should we do ?
			NSLog(@"Webview error associated to object of class %@", [obj class]);
	}
}

#pragma mark -
#pragma mark webView progress notifications

/* webViewLoadFinished
 * Invoked when a web view load has finished
 */
- (void)webViewLoadFinished:(NSNotification *)notification
{
    id obj = [notification object];
    if([obj isKindOfClass:[ArticleView class]])
    {
		ArticleView * sender = (ArticleView *)obj;
		id objView = [sender superview];
		if ([objView isKindOfClass:[ArticleCellView class]])
		{
			ArticleCellView * cell = (ArticleCellView *)objView;
			NSUInteger row= [cell row];
			// get the height of the rendered frame.
			// I have tested many NSHeight([[ ... ] frame]) tricks, but they were unreliable
			// and using DOM to get documentElement scrollHeight and/or offsetHeight was the simplest
			// way to get the height with WebKit
			// Ref : http://james.padolsey.com/javascript/get-document-height-cross-browser/
			//
			// this temporary enable Javascript if it is not enabled, then reset to preference
			[[sender preferences] setJavaScriptEnabled:YES];
			NSString* outputHeight = [sender stringByEvaluatingJavaScriptFromString:@"document.documentElement.scrollHeight"];
			NSString* bodyHeight = [sender stringByEvaluatingJavaScriptFromString:@"document.body.scrollHeight"];
			NSString* clientHeight = [sender stringByEvaluatingJavaScriptFromString:@"document.documentElement.clientHeight"];
			[[sender preferences] setJavaScriptEnabled:[[Preferences standardPreferences] useJavaScript]];
			CGFloat fittingHeight = [outputHeight floatValue];

			//get the rect of the current webview frame
			NSRect webViewRect = [sender frame];
			//calculate the new frame
			NSRect newWebViewRect = NSMakeRect(XPOS_IN_CELL,
									   YPOS_IN_CELL,
									   NSWidth(webViewRect),
									   fittingHeight);
			//set the new frame to the webview
			[sender setFrame:newWebViewRect];
			if (row == [cell articleRow] && row < [[articleController allArticles] count]
			  && [cell folderId] == [[[articleController allArticles] objectAtIndex:row] folderId])
			{	//relevant cell
				if ([bodyHeight isEqualToString:outputHeight] && [bodyHeight isEqualToString:clientHeight]) {
					if (row < [rowHeightArray count])
						[rowHeightArray replaceObjectAtIndex:row withObject:[NSNumber numberWithFloat:fittingHeight]];
					else
					{	NSInteger toAdd = row - [rowHeightArray count] ;
						for (NSInteger i = 0 ; i < toAdd ; i++) {
							[rowHeightArray addObject:[NSNumber numberWithFloat:DEFAULT_CELL_HEIGHT]];
						}
						[rowHeightArray addObject:[NSNumber numberWithFloat:fittingHeight]];
					}
					[cell setInProgress:NO];
					[articleList reloadRowAtIndex:row];
				}
				else
				{
					// something in the dimensions went wrong : force a reload
					[self resubmitWebView:sender];
				}
			}
			else {	//non relevant cell
				[cell setInProgress:NO];
				NSRect frame = sender.frame;
				frame.size.height = 1;        // Set the height to a small one.
				frame.size.width = 1;
				[articleList reloadRowAtIndex:row];
			}
		} else {
			// not an ArticleCellView anymore : reposition it, just in case...
			NSRect frame = sender.frame;
			frame.size.height = 1;        // Set the height to a small one.
			frame.size.width = 1;
		}
	}
}

-(void)resubmitWebView:(WebView *)sender
{
	ArticleCellView * cell = (ArticleCellView *)[sender superview];
	NSUInteger row = [cell row];
	if (cell != nil)
	{
		NSRect frame = sender.frame;
		frame.size.height = 1;        // Set the height to a small one.
		frame.size.width = 1;
		[self webViewLoadFinished:[NSNotification notificationWithName:WebViewProgressFinishedNotification object:sender]];
	}
	else
		[articleList reloadRowAtIndex:row];
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
	mainMenuItem = menuItemWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	if (mainMenuItem != nil)
	{
		index = [articleListMenu indexOfItemWithTarget:nil andAction:@selector(viewSourceHomePageInAlternateBrowser:)];
		if (index >= 0)
		{
			contextualMenuItem = [articleListMenu itemAtIndex:index];
			[contextualMenuItem setTitle:[mainMenuItem title]];
		}
	}
	mainMenuItem = menuItemWithAction(@selector(viewArticlePagesInAlternateBrowser:));
	if (mainMenuItem != nil)
	{
		index = [articleListMenu indexOfItemWithTarget:nil andAction:@selector(viewArticlePagesInAlternateBrowser:)];
		if (index >= 0)
		{
			contextualMenuItem = [articleListMenu itemAtIndex:index];
			[contextualMenuItem setTitle:[mainMenuItem title]];
		}
	}
}

/* ensureSelectedArticle
 * Ensure that there is a selected article and that it is visible.
 */
-(void)ensureSelectedArticle:(BOOL)singleSelection
{
	if (singleSelection)
	{
		int nextRow =[[articleList selectedRows] firstIndex];
		int articlesCount = [[articleController allArticles] count];

		currentSelectedRow = -1;
		if (nextRow < 0 || nextRow >= articlesCount)
			nextRow = articlesCount - 1;
		[self makeRowSelectedAndVisible:nextRow];
	}
	else
	{
		if ([articleList selectedRow] == -1)
			[self makeRowSelectedAndVisible:0];
		else
			[articleList scrollRowToVisible:[articleList selectedRow]];
	}
}

/* scrollToArticle
 * Moves the selection to the specified article. Returns YES if we found the
 * article, NO otherwise.
 */
-(BOOL)scrollToArticle:(NSString *)guid
{
	int rowIndex = 0;
	BOOL found = NO;

	for (Article * thisArticle in [articleController allArticles])
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

#pragma mark -
#pragma mark BaseView delegate

/* mainView
 * Return the primary view of this view.
 */
-(NSView *)mainView
{
	return self;
}

/* webView
 * Returns the webview used to display the articles
 */
-(WebView *)webView
{
	return nil;
}

/* performFindPanelAction
 * Implement the search action.
 */
-(void)performFindPanelAction:(int)actionTag
{
	[self refreshFolder:MA_Refresh_ReloadFromDatabase];

	// This action is send continuously by the filter field, so make sure not the mark read while searching
	if (currentSelectedRow < 0 && [[articleController allArticles] count] > 0 )
	{
		BOOL shouldSelectArticle = YES;
		if ([[Preferences standardPreferences] markReadInterval] > 0.0f)
		{
			Article * article = [[articleController allArticles] objectAtIndex:0u];
			if (![article isRead])
				shouldSelectArticle = NO;
		}
		if (shouldSelectArticle)
			[self makeRowSelectedAndVisible:0];
	}
}

/* canGoForward
 * Return TRUE if we can go forward in the backtrack queue.
 */
-(BOOL)canGoForward
{
	return [articleController canGoForward];
}

/* canGoBack
 * Return TRUE if we can go backward in the backtrack queue.
 */
-(BOOL)canGoBack
{
	return FALSE;
}

/* handleGoForward
 * Move forward through the backtrack queue.
 */
-(IBAction)handleGoForward:(id)sender
{
}

/* handleGoBack
 * Move backward through the backtrack queue.
 */
-(IBAction)handleGoBack:(id)sender
{
}

/* saveTableSettings
 * Save the current folder and article
 */
-(void)saveTableSettings
{
	Preferences * prefs = [Preferences standardPreferences];

	// Remember the current folder and article
	NSString * guid = (currentSelectedRow >= 0 && currentSelectedRow < [[articleController allArticles] count]) ? [[[articleController allArticles] objectAtIndex:currentSelectedRow] guid] : @"";
	[prefs setInteger:[articleController currentFolderId] forKey:MAPref_CachedFolderID];
	[prefs setString:guid forKey:MAPref_CachedArticleGUID];
}

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger )flags
{
	return [controller handleKeyDown:keyChar withFlags:flags];
}

/* canDeleteMessageAtRow
 * Returns YES if the message at the specified row can be deleted, otherwise NO.
 */
-(BOOL)canDeleteMessageAtRow:(int)row
{
	if ((row >= 0) && (row < [[articleController allArticles] count]))
	{
		Article * article = [[articleController allArticles] objectAtIndex:row];
		return (article != nil) && ![[Database sharedDatabase] readOnly] && [[articleList window] isVisible];
	}
	return NO;
}

/* selectedArticle
 * Returns the selected article, or nil if no article is selected.
 */
-(Article *)selectedArticle
{
	return (currentSelectedRow >= 0 && currentSelectedRow < [[articleController allArticles] count]) ? [[articleController allArticles] objectAtIndex:currentSelectedRow] : nil;
}

/* printDocument
 * Print the active article.
 */
-(void)printDocument:(id)sender
{
	//TODO
}

-(void)handleArticleListStateChange:(NSNotification *)note
{
	if (self == [articleController mainArticleView])
	{
		NSInteger folderId = [(Folder *)[note object] itemId];
		NSInteger controllerFolderId = [controller currentFolderId];
		Folder * controllerFolder = [[Database sharedDatabase] folderFromID:controllerFolderId];
		if (folderId == controllerFolderId || ( !IsRSSFolder(controllerFolder) && !IsGoogleReaderFolder(controllerFolder) ))
		{
			[self refreshCurrentFolder];
		}
	}
}

/* handleReadingPaneChange
 * Respond to the change to the reading pane orientation.
 */
-(void)handleReadingPaneChange:(NSNotificationCenter *)nc
{
	if (self == [articleController mainArticleView])
	{
		[articleList reloadData];
	}
}

/* makeRowSelectedAndVisible
 * Selects the specified row in the table and makes it visible by
 * scrolling to it.
 */
-(void)makeRowSelectedAndVisible:(int)rowIndex
{
	if ([[articleController allArticles] count] == 0u)
	{
		currentSelectedRow = -1;
	}
	else
	{
		[articleList setSelectedRow:rowIndex];
		if (currentSelectedRow == -1 || blockSelectionHandler)
		{
			currentSelectedRow = rowIndex;
		}
		[articleList scrollRowToVisible:rowIndex];
	}
}

/* displayFirstUnread
 * Locate the first unread article.
 */
-(void)displayFirstUnread
{
	// Mark the current article read.
	[self markCurrentRead:nil];

	// If there are any unread articles then select the first one in the
	// first folder.
	if ([[Database sharedDatabase] countOfUnread] > 0)
	{
		guidOfArticleToSelect = nil;

		// Get the first folder with unread articles.
		int firstFolderWithUnread = [foldersTree firstFolderWithUnread];

		// Select the folder in the tree view.
		[foldersTree selectFolder:firstFolderWithUnread];

		// Now select the first unread article.
		[self selectFirstUnreadInFolder];
	}
}

/* displayNextUnread
 * Locate the next unread article from the current article onward.
 */
-(void)displayNextUnread
{
	// Save the value of currentSelectedRow.
	int currentRow = currentSelectedRow;

	// Mark the current article read.
	[self markCurrentRead:nil];

	// Scan the current folder from the selection forward. If nothing found, try
	// other folders until we come back to ourselves.
	if (([[Database sharedDatabase] countOfUnread] > 0) && (![self viewNextUnreadInCurrentFolder:currentRow]))
	{
		int nextFolderWithUnread = [foldersTree nextFolderWithUnread:[articleController currentFolderId]];
		if (nextFolderWithUnread != -1)
		{
			if (nextFolderWithUnread == [articleController currentFolderId])
			{
				[self viewNextUnreadInCurrentFolder:-1];
			}
			else
			{
				guidOfArticleToSelect = nil;
				[foldersTree selectFolder:nextFolderWithUnread];
				[self selectFirstUnreadInFolder];
			}
		}
	}
}

/* viewNextUnreadInCurrentFolder
 * Select the next unread article in the current folder after currentRow.
 */
-(BOOL)viewNextUnreadInCurrentFolder:(int)currentRow
{
	if (currentRow < 0)
		currentRow = 0;

	NSArray * allArticles = [articleController allArticles];
	int totalRows = [allArticles count];
	Article * theArticle;
	while (currentRow < totalRows)
	{
		theArticle = [allArticles objectAtIndex:currentRow];
		if (![theArticle isRead])
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
 * last article if the folder has no unread articles.
 */
-(void)selectFirstUnreadInFolder
{
	if (![self viewNextUnreadInCurrentFolder:-1])
	{
		int count = [[articleController allArticles] count];
		if (count > 0)
			[self makeRowSelectedAndVisible:[[[[Preferences standardPreferences] articleSortDescriptors] objectAtIndex:0] ascending] ? 0 : count - 1];
	}
}

/* selectFolderAndArticle
 * Select a folder and select a specified article within the folder.
 */
-(void)selectFolderAndArticle:(int)folderId guid:(NSString *)guid
{
	// If we're in the right folder, easy enough.
	if (folderId == [articleController currentFolderId])
		[self scrollToArticle:guid];
	else
	{
		// Otherwise we force the folder to be selected and seed guidOfArticleToSelect
		// so that after handleFolderSelection has been invoked, it will select the
		// requisite article on our behalf.
		currentSelectedRow = -1;
		[guidOfArticleToSelect release];
		guidOfArticleToSelect = [guid retain];
		[foldersTree selectFolder:folderId];
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

/* refreshCurrentFolder
 * Reload the current folder after a refresh.
 */
-(void)refreshCurrentFolder
{
	// Preserve the article that the user might currently be reading.
	Preferences * prefs = [Preferences standardPreferences];
	if (([prefs refreshFrequency] > 0) &&
		(currentSelectedRow >= 0 && currentSelectedRow < (int)[[articleController allArticles] count]))
	{
		Article * currentArticle = [[articleController allArticles] objectAtIndex:currentSelectedRow];
		if (![currentArticle isDeleted])
			[articleController setArticleToPreserve:currentArticle];
	}

	[self refreshFolder:MA_Refresh_ReloadFromDatabase];
}

/* refreshFolder
 * Refreshes the current folder by applying the current sort or thread
 * logic and redrawing the article list. The selected article is preserved
 * and restored on completion of the refresh.
 */
-(void)refreshFolder:(int)refreshFlag
{
	NSArray * allArticles = [articleController allArticles];
	NSString * guid = nil;

	[markReadTimer invalidate];
	[markReadTimer release];
	markReadTimer = nil;

	if (refreshFlag == MA_Refresh_SortAndRedraw)
		blockSelectionHandler = blockMarkRead = YES;
	if ([articleList visibleRange].location < [allArticles count])
		guid = [[[allArticles objectAtIndex:[articleList visibleRange].location] guid] retain];
	if (refreshFlag == MA_Refresh_ReloadFromDatabase)
		[articleController reloadArrayOfArticles];
	else if (refreshFlag == MA_Refresh_ReapplyFilter)
		[articleController refilterArrayOfArticles];
	if (refreshFlag != MA_Refresh_RedrawList)
		[articleController sortArticles];
	[articleList reloadData];
	if (guid != nil)
	{
		// To avoid upsetting the current displayed article after a refresh, we check to see if the first visible article is the same
		// elsewhere we scroll to the previous article
		allArticles = [articleController allArticles];
		BOOL isUnchanged = [articleList visibleRange].location < [allArticles count]
			&& [guid isEqualToString:[[allArticles objectAtIndex:[articleList visibleRange].location] guid]];
		if (!isUnchanged)
		{
			if (![self scrollToArticle:guid])
			{
				currentSelectedRow = -1;
				[articleList deselectRows];
			}
		}
	}
	else
		currentSelectedRow = -1;
	if ((refreshFlag == MA_Refresh_ReapplyFilter || refreshFlag == MA_Refresh_ReloadFromDatabase) && (currentSelectedRow == -1) && ([[NSApp mainWindow] firstResponder] == articleList))
		[[NSApp mainWindow] makeFirstResponder:[foldersTree mainView]];
	else if (refreshFlag == MA_Refresh_SortAndRedraw)
		blockSelectionHandler = blockMarkRead = NO;
	[guid release];
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

/* selectFolderWithFilter
 * Switches to the specified folder and displays articles filtered by whatever is in
 * the search field.
 */
-(void)selectFolderWithFilter:(int)newFolderId
{
	@autoreleasepool {
		currentSelectedRow = -1;
		[rowHeightArray removeAllObjects];
		[articleList reloadData];
		if (guidOfArticleToSelect == nil)
			[articleList scrollRowToVisible:0];
		else
			[self selectArticleAfterReload];
	}
}

/* handleRefreshArticle
 * Respond to the notification to refresh the current article pane.
 */
-(void)handleRefreshArticle:(NSNotification *)nc
{
}

/* clearCurrentURL
 * Clears the current URL.
 */
-(void)clearCurrentURL
{
	// If we already have an URL release it.
	if (currentURL)
	{
		[currentURL release];
		currentURL = nil;
	}
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
}

/* markCurrentRead
 * Mark the current article as read.
 */
-(void)markCurrentRead:(NSTimer *)aTimer
{
	NSArray * allArticles = [articleController allArticles];
	if (currentSelectedRow >=0 && currentSelectedRow < (int)[allArticles count] && ![[Database sharedDatabase] readOnly])
	{
		Article * theArticle = [allArticles objectAtIndex:currentSelectedRow];
		if (![theArticle isRead])
			[articleController markReadByArray:[NSArray arrayWithObject:theArticle] readFlag:YES];
	}
}

#pragma mark -
#pragma mark PXListViewDelegate

/* numberOfRowsInListView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of articles in the current folder.
 */
-(NSUInteger)numberOfRowsInListView:(PXListView*)aTableView
{
	return [[articleController allArticles] count];
}

- (CGFloat)listView:(PXListView*)aListView heightOfRow:(NSUInteger)row
{
	CGFloat height;
	if (row >= [rowHeightArray count])
	{
		NSInteger toAdd = row - [rowHeightArray count] + 1 ;
		for (NSInteger i = 0 ; i < toAdd ; i++) {
			[rowHeightArray addObject:[NSNumber numberWithFloat:DEFAULT_CELL_HEIGHT]];
		}
		return (CGFloat)DEFAULT_CELL_HEIGHT;
	}
	else
	{
		id object= [rowHeightArray objectAtIndex:row];
        height = [object floatValue];
		return  (height) ;
	}
}

/* cellForRow [datasource]
 * Called by the table view to obtain the object at the specified row.
 */
- (PXListViewCell*)listView:(PXListView*)aListView cellForRow:(NSUInteger)row
{
	if (![aListView isEqualTo:articleList])
		return nil;
	NSArray * allArticles = [articleController allArticles];

	Article * theArticle = [allArticles objectAtIndex:row];
	NSInteger articleFolderId = [theArticle folderId];
	Folder * folder = [[Database sharedDatabase] folderFromID:articleFolderId];
	NSString * feedURL = SafeString([folder feedURL]);

	ArticleCellView *cellView = (ArticleCellView*)[aListView dequeueCellWithReusableIdentifier:LISTVIEW_CELL_IDENTIFIER];

	if (cellView == nil)
	{
		cellView = [[[ArticleCellView alloc] initWithReusableIdentifier:LISTVIEW_CELL_IDENTIFIER
						inFrame:NSMakeRect(XPOS_IN_CELL, YPOS_IN_CELL, aListView.bounds.size.width - XPOS_IN_CELL, DEFAULT_CELL_HEIGHT)] autorelease];
	}

	ArticleView * view = [cellView articleView];
	[cellView setFolderId:articleFolderId];
	[cellView setArticleRow:row];
	NSString * htmlText = [view articleTextFromArray:[NSArray arrayWithObject:theArticle]];
	[cellView setInProgress:YES];
	[view setHTML:htmlText withBase:feedURL];
	[cellView addSubview:view];
    return cellView;
}

/* listViewSelectionDidChange [delegate]
 * Handle the selection changing in the table view unless blockSelectionHandler is set.
 */
- (void)listViewSelectionDidChange:(NSNotification*)aNotification
{
	if (!blockSelectionHandler)
	{
		currentSelectedRow = [articleList selectedRow];
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
	Database * db = [Database sharedDatabase];
	int count = [rowIndexes count];

	// Set up the pasteboard
	[pboard declareTypes:[NSArray arrayWithObjects:MA_PBoardType_RSSItem, @"WebURLsWithTitlesPboardType", NSStringPboardType, NSHTMLPboardType, nil] owner:self];
	if (count == 1)
		[pboard addTypes:[NSArray arrayWithObjects:MA_PBoardType_url, MA_PBoardType_urln, NSURLPboardType, nil] owner:self];

	// Open the HTML string
	[fullHTMLText appendString:@"<html><body>"];

	// Get all the articles that are being dragged
	NSUInteger msgIndex = [rowIndexes firstIndex];
	while (msgIndex != NSNotFound)
	{
		Article * thisArticle = [[articleController allArticles] objectAtIndex:msgIndex];
		Folder * folder = [db folderFromID:[thisArticle folderId]];
		NSString * msgText = [thisArticle body];
		NSString * msgTitle = [thisArticle title];
		NSString * msgLink = [thisArticle link];

		[arrayOfURLs addObject:msgLink];
		[arrayOfTitles addObject:msgTitle];

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

		if (count == 1)
		{
			[pboard setString:msgLink forType:MA_PBoardType_url];
			[pboard setString:msgTitle forType:MA_PBoardType_urln];

			// Write the link to the pastboard.
			[[NSURL URLWithString:msgLink] writeToPasteboard:pboard];
		}

		//increment
    	msgIndex = [rowIndexes indexGreaterThanIndex: msgIndex];
	}

	// Close the HTML string
	[fullHTMLText appendString:@"</body></html>"];

	// Put string on the pasteboard for external drops.
	[pboard setPropertyList:arrayOfArticles forType:MA_PBoardType_RSSItem];
	[pboard setPropertyList:[NSArray arrayWithObjects:arrayOfURLs, arrayOfTitles, nil] forType:@"WebURLsWithTitlesPboardType"];
	[pboard setString:fullPlainText forType:NSStringPboardType];
	[pboard setString:[fullHTMLText stringByEscapingExtendedCharacters] forType:NSHTMLPboardType];

	[arrayOfArticles release];
	[arrayOfURLs release];
	[arrayOfTitles release];
	[fullHTMLText release];
	[fullPlainText release];
	return YES;
}

/* writeRowsWithIndexes
 * Called to initiate a drag from PXListView. Use the common copy selection code to copy to
 * the pasteboard.
 */
-(BOOL)listView:(PXListView*)aListView writeRowsWithIndexes:(NSIndexSet*)rowIndexes toPasteboard:(NSPasteboard *)pboard;
{
	return [self copyIndexesSelection:rowIndexes toPasteboard:pboard];
}

/* copy
 * Handle the Copy action when the article list has focus.
 */
-(IBAction)copy:(id)sender
{
	[self copyIndexesSelection:[articleList selectedRows] toPasteboard:[NSPasteboard generalPasteboard]];
}

/* markedArticleRange
 * Retrieve an array of selected articles.
 */
-(NSArray *)markedArticleRange
{
	NSMutableArray * articleArray = nil;
	if ([[articleList selectedRows] count] > 0)
	{
		NSIndexSet * rowIndexes = [articleList selectedRows];
		NSUInteger  rowIndex = [rowIndexes firstIndex];

		articleArray = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
		while (rowIndex != NSNotFound)
		{
			[articleArray addObject:[[articleController allArticles] objectAtIndex:rowIndex]];
			rowIndex = [rowIndexes indexGreaterThanIndex:rowIndex];
		}
	}
	return articleArray;
}

#pragma mark -
#pragma mark Keyboard (NSResponder)

- (BOOL)acceptsFirstResponder
{
	return YES;
};

/* keyDown
 * Here is where we handle special keys when this view
 * has the focus so we can do custom things.
 */
-(void)keyDown:(NSEvent *)theEvent
{
	if ([[theEvent characters] length] == 1)
	{
		unichar keyChar = [[theEvent characters] characterAtIndex:0];
		if ([controller handleKeyDown:keyChar withFlags:[theEvent modifierFlags]])
			return;
	}
	[self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (void)moveDown:(id)sender
{
	[articleList moveDown:sender];
}

- (void)moveUp:(id)sender
{
	[articleList moveUp:sender];
}

- (void)scrollPageDown:(id)sender
{
	[articleList pageDown:sender];
	[[NSApp mainWindow] makeFirstResponder:self];
}

- (void)scrollPageUp:(id)sender
{
	[articleList pageUp:sender];
	[[NSApp mainWindow] makeFirstResponder:self];
}

- (void)pageDown:(id)sender
{
	[self scrollPageDown:sender];
}

- (void)pageUp:(id)sender
{
	[self scrollPageUp:sender];
}

- (void)scrollToEndOfDocument:(id)sender
{
	[articleList scrollRowToVisible:([[articleController allArticles] count]-1)];
	[[NSApp mainWindow] makeFirstResponder:self];
}

- (void)scrollToBeginningOfDocument:(id)sender
{
	[articleList scrollRowToVisible:0];
	[[NSApp mainWindow] makeFirstResponder:self];
}

@end
