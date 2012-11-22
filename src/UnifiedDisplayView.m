//
//  UnifiedDisplayView.m
//  Vienna
//
//  Created by Steve on 5/5/06.
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

#import "UnifiedDisplayView.h"
#import "ArticleController.h"
#import "AppController.h"
#import "Database.h"
#import "ArticleView.h"
#import "ArticleFilter.h"
#import "Preferences.h"
#import "Constants.h"
#import "StringExtensions.h"
#import <WebKit/WebKit.h>

@implementation UnifiedDisplayView

/* awakeFromNib
 * Called when the view is loaded from the NIB file.
 */
-(void)awakeFromNib
{
	// Make us the frame load and UI delegate for the web view
	[unifiedText setUIDelegate:self];
	[unifiedText setFrameLoadDelegate:self];
	[unifiedText setOpenLinksInNewBrowser:YES];
	[unifiedText setController:controller];

	// Disable caching
	[unifiedText setMaintainsBackForwardList:NO];
	[[unifiedText backForwardList] setPageCacheSize:0];
}

/* ensureSelectedArticle
 * Ensure that there is a selected article and that it is visible.
 */
-(void)ensureSelectedArticle:(BOOL)singleSelection
{
}

/* selectFolderAndArticle
 * Select a folder. In unified view, we currently disregard the article but
 * we could potentially try and highlight the article in the text in the future.
 */
-(void)selectFolderAndArticle:(int)folderId guid:(NSString *)guid
{
	if (folderId != [articleController currentFolderId])
		[foldersTree selectFolder:folderId];
}	

/* selectFolderWithFilter
 * Switches to the specified folder and displays articles filtered by whatever is in
 * the search field.
 */
-(void)selectFolderWithFilter:(int)newFolderId
{
	[articleController reloadArrayOfArticles];
	[articleController sortArticles];
	[articleController addBacktrack:nil];
	[self refreshArticlePane];
}

/* handleRefreshArticle
 * Respond to the notification to refresh the current article pane.
 */
-(void)handleRefreshArticle:(NSNotification *)nc
{
	[self refreshArticlePane];
}

/* sortByIdentifier
 * Sort by the column indicated by the specified column name.
 */
-(void)sortByIdentifier:(NSString *)columnName
{
	[self refreshArticlePane];
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

/* runJavaScriptAlertPanelWithMessage
 * Called when the browser wants to display a JavaScript alert panel containing the specified message.
 */
- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
	NSRunInformationalAlertPanel(NSLocalizedString(@"JavaScript", @""),	// title
		message,	// message
		NSLocalizedString(@"OK", @""),	// default button
		nil,	// alt button
		nil);	// other button
}

/* runJavaScriptConfirmPanelWithMessage
 * Called when the browser wants to display a JavaScript confirmation panel with the specified message.
 */
- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
	NSInteger result = NSRunInformationalAlertPanel(NSLocalizedString(@"JavaScript", @""),	// title
		message,	// message
		NSLocalizedString(@"OK", @""),	// default button
		NSLocalizedString(@"Cancel", @""),	// alt button
		nil);
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
-(void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(NSUInteger)modifierFlags
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

/* refreshCurrentFolder
 * Reload the current folder after a refresh.
 */
-(void)refreshCurrentFolder
{
	if ([[Preferences standardPreferences] refreshFrequency] == 0)
		[self refreshFolder:MA_Refresh_ReloadFromDatabase];
}

/* refreshFolder
 * Refreshes the current folder by applying the current sort or thread
 * logic and redrawing the article list. The selected article is preserved
 * and restored on completion of the refresh.
 */
-(void)refreshFolder:(int)refreshFlag
{
	if (refreshFlag == MA_Refresh_ReloadFromDatabase)
		[articleController reloadArrayOfArticles];
	else if (refreshFlag == MA_Refresh_ReapplyFilter)
		[articleController refilterArrayOfArticles];
	if (refreshFlag != MA_Refresh_RedrawList)
		[articleController sortArticles];
	[self refreshArticlePane];
}

/* displayFirstUnread
 * Find the first folder that has unread articles and switch to that.
 */
-(void)displayFirstUnread
{
	int firstFolderWithUnread = [foldersTree firstFolderWithUnread];
	if (firstFolderWithUnread != -1)
	{
		if (firstFolderWithUnread == [articleController currentFolderId])
			[self selectFolderWithFilter:[articleController currentFolderId]];
		else
			[foldersTree selectFolder:firstFolderWithUnread];
	}
	[[NSApp mainWindow] makeFirstResponder:unifiedText];
}

/* displayNextUnread
 * Find the next folder that has unread articles and switch to that.
 */
-(void)displayNextUnread
{
	int nextFolderWithUnread = [foldersTree nextFolderWithUnread:[articleController currentFolderId]];
	if (nextFolderWithUnread != -1)
	{
		if (nextFolderWithUnread == [articleController currentFolderId])
			[self selectFolderWithFilter:[articleController currentFolderId]];
		else
			[foldersTree selectFolder:nextFolderWithUnread];
	}
	[[NSApp mainWindow] makeFirstResponder:unifiedText];
}

/* refreshArticlePane
 * Updates the article pane for the current selected articles.
 */
-(void)refreshArticlePane
{
	NSArray * msgArray = [articleController allArticles];
	if ([msgArray count] == 0)
		[unifiedText clearHTML];
	else
	{
		NSString * htmlText = [unifiedText articleTextFromArray:msgArray];
		Article * firstArticle = [msgArray objectAtIndex:0];
		Folder * folder = [[Database sharedDatabase] folderFromID:[firstArticle folderId]];
		[unifiedText setHTML:htmlText withBase:SafeString([folder feedURL])];
	}
}

/* selectedArticle
 * Unified view doesn't yet support single article selections.
 */
-(Article *)selectedArticle
{
	return nil;
}

/* performFindPanelAction
 * Implement the search action.
 */
-(void)performFindPanelAction:(int)actionTag
{
	[self refreshFolder:MA_Refresh_ReloadFromDatabase];
}

/* printDocument
 * Print the active article.
 */
-(void)printDocument:(id)sender
{
	[unifiedText printDocument:sender];
}

/* handleGoForward
 * Move forward through the backtrack queue.
 */
-(IBAction)handleGoForward:(id)sender
{
	[articleController goForward];
}

/* handleGoBack
 * Move backward through the backtrack queue.
 */
-(IBAction)handleGoBack:(id)sender
{
	[articleController goBack];
}

/* viewLink
 * There's no view link address for unified display views.
 */
-(NSString *)viewLink
{
	return nil;
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
	return [articleController canGoBack];
}

/* mainView
 * Return the primary view of this view.
 */
-(NSView *)mainView
{
	return unifiedText;
}

/* webView
 * Return the web view of this view.
 */
-(WebView *)webView
{
	return unifiedText;
}

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger)flags
{
	return [controller handleKeyDown:keyChar withFlags:flags];
}
@end
