//
//  ArticleView.m
//  Vienna
//
//  Created by Steve on Tue Jul 05 2005.
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

#import "Constants.h"
#import "ArticleView.h"
#import "AppController.h"
#import "Preferences.h"
#import "HelperFunctions.h"
#import "StringExtensions.h"
#import "Article.h"
#import "BaseView.h"
#import "Vienna-Swift.h"

@interface ArticleView () <WebUIDelegate, WebFrameLoadDelegate, Tab>

@property (strong, nonatomic) OverlayStatusBar *statusBar;
@property (strong, nonatomic) WebViewArticleConverter *converter;

@end

@implementation ArticleView

@synthesize html, tabUrl, textSelection, title, listView, articles;

/* initWithFrame
 * The designated instance initialiser.
 */
-(instancetype)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		// Init our vars
		html = @"";

self.converter = [[WebViewArticleConverter alloc] init];

        self.UIDelegate = self;
        self.frameLoadDelegate = self;

         // Updates the article pane when the active display style has been changed.
        __weak ArticleView * weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:@"MA_Notify_StyleChange" object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            Preferences * prefs = [Preferences standardPreferences];
            weakSelf.textSizeMultiplier = prefs.textSizeMultiplier;
        }];

		// enlarge / reduce the text size according to user's setting
		self.textSizeMultiplier = [Preferences standardPreferences].textSizeMultiplier;
	}
	return self;
}

/* performDragOperation
 * Don't accept stuff dragged into the article view. 
 */
-(BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{ 
	return NO;
}

/* clearHTML
 * Make the web view behave like a blank page.
 */
-(void)clearHTML
{
    self.hidden = YES;
    self.tabUrl = [NSURL URLWithString:@"about:blank"];
    [self loadTab];
    html = @"";
}

-(void)setArticles:(NSArray<Article *> *)articles {
    if (articles.count > 0) {
        [self setHtml:[self.converter articleTextFromArray:articles]];
    } else {
        [self clearHTML];
    }
}

/* setHtml
 * Loads the web view with the specified HTML text.
 */
- (void)setHtml:(NSString *)htmlText {
	self.hidden = NO;
	// If the current HTML is the same as the new HTML then we don't need to
	// do anything here. This will stop the view from spurious redraws of the same
	// article after a refresh.
	if ([html isEqualToString:htmlText])
		return;
	
	// Remember the current html string.
	html = [htmlText copy];
	
	[self.mainFrame loadHTMLString:html
							  baseURL:[NSURL URLWithString:@"/"]];
}

/* keyDown
 * Here is where we handle special keys when the article view
 * has the focus so we can do custom things.
 */
-(void)keyDown:(NSEvent *)theEvent
{
	if (theEvent.characters.length == 1)
	{
		unichar keyChar = [theEvent.characters characterAtIndex:0];
		if ([APPCONTROLLER handleKeyDown:keyChar withFlags:theEvent.modifierFlags])
			return;
		
		//Don't go back or forward in article view.
        if ((theEvent.modifierFlags & NSEventModifierFlagCommand) &&
			((keyChar == NSLeftArrowFunctionKey) || (keyChar == NSRightArrowFunctionKey)))
			return;
	}
	[super keyDown:theEvent];
}

/* swipeWithEvent 
 * Enables "scroll to top"/"scroll to bottom" via vertical three-finger swipes as in Safari and other applications.
 * Also enables calling "viewNextUnread:" and "goBack:" via horizontal three-finger swipes.
 */
-(void)swipeWithEvent:(NSEvent *)event 
{	
	CGFloat deltaX = event.deltaX;
	CGFloat deltaY = event.deltaY;
		
	/* Check which is more likely to be what the user wanted: horizontal or vertical swipe?
	 * Thankfully, that's all the checking we need to do as built-in swipe detection is very solid. */
	if ( fabs(deltaY) > fabs(deltaX) )
	{
		if (deltaY != 0)
		{
			if (deltaY > 0)
				[self scrollToTop];
			else
				[self scrollToBottom];
		}
	}
	else 
	{
		if (deltaX != 0)
		{
			if (deltaX > 0)
				[APPCONTROLLER goBack:self];
			else 
				[APPCONTROLLER viewNextUnread:self];
		}
	}		
}

#pragma mark -
#pragma mark WebView methods overrides

/* makeTextSmaller
 */
-(IBAction)makeTextSmaller:(id)sender
{
	[super makeTextSmaller:sender];
	[Preferences standardPreferences].textSizeMultiplier = self.textSizeMultiplier;
}

/* makeTextLarger
 */
-(IBAction)makeTextLarger:(id)sender
{
	[super makeTextLarger:sender];
	[Preferences standardPreferences].textSizeMultiplier = self.textSizeMultiplier;
}

#pragma mark -
#pragma mark WebKit protocols

/* decidePolicyForNewWindowAction
 * Called by the web view to get our policy on handling actions that would open a new window.
 * When opening clicked links in the background or an external browser, we want the first responder to return to the article list.
 */
-(void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
	NSInteger navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] integerValue];
	if ((navType == WebNavigationTypeLinkClicked) && ([Preferences standardPreferences].openLinksInBackground || ![Preferences standardPreferences].openLinksInVienna))
		[NSApp.mainWindow makeFirstResponder:((NSView<BaseView> *)APPCONTROLLER.browser.primaryTab.view).mainView];
	
	[super webView:sender decidePolicyForNewWindowAction:actionInformation request:request newFrameName:frameName decisionListener:listener];
}
		
/* decidePolicyForNavigationAction
 * Called by the web view to get our policy on handling navigation actions.
 * Relative URLs should open in the same view.
 * When opening clicked links in the background or an external browser, we want the first responder to return to the article list.
 */
-(void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	if (request.URL.fragment != nil)
	{
		NSURL * feedURL = self.mainFrame.dataSource.initialRequest.URL;
		if ((feedURL != nil) && [feedURL.scheme isEqualToString:request.URL.scheme] && [feedURL.host isEqualToString:request.URL.host] && [feedURL.path isEqualToString:request.URL.path])
		{
			[listener use];
			return;
		}
	}
	
	NSInteger navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] integerValue];
	if ((navType == WebNavigationTypeLinkClicked) && ([Preferences standardPreferences].openLinksInBackground || ![Preferences standardPreferences].openLinksInVienna))
		[NSApp.mainWindow makeFirstResponder:((NSView<BaseView> *)APPCONTROLLER.browser.primaryTab.view).mainView];
	
	[super webView:sender decidePolicyForNavigationAction:actionInformation request:request frame:frame decisionListener:listener];
}
/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Tab interface (forwarding to article view)

- (BOOL)back {
	//TODO
	return false;
}

- (BOOL)forward {
	return false;
}

- (void)decreaseTextSize {
	[self makeTextSmaller:self];
}

- (void)increaseTextSize {
	[self makeTextLarger:self];
}

- (void)loadTab {
    [[self mainFrame] loadRequest:[NSURLRequest requestWithURL: self.tabUrl]];
}

- (BOOL)pageDown {
	//TODO
	return NO;
}

- (BOOL)pageUp {
	//TODO
	return NO;
}

- (void)printPage {
	//TODO
}

- (void)reloadTab {
	//TODO
}

- (void)searchFor:(NSString * _Nonnull)searchString action:(NSFindPanelAction)action {
	//TODO
}

- (void)stopLoadingTab {
	//TODO
}

- (void)activateAddressBar {
    //TODO
}

- (void)activateWebView {
    //TODO
}


- (nullable id)animationForKey:(nonnull NSAnimatablePropertyKey)key {
    //TODO
    return nil;
}

- (nonnull instancetype)animator {
    //TODO
    return nil;
}

+ (nullable id)defaultAnimationForKey:(nonnull NSAnimatablePropertyKey)key {
    //TODO
    return nil;
}

- (NSRect)accessibilityFrame {
    //TODO
    return CGRectZero;
}

- (nullable id)accessibilityParent {
    //TODO
    return nil;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    //TODO
}

#pragma mark Moved from ArticleListView

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
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

#pragma mark - WebView Delegate

/* didStartProvisionalLoadForFrame
 * Invoked when a new client request is made by sender to load a provisional data source for frame.
 */
-(void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
    if (frame == self.mainFrame)
    {
        [listView setError:nil];
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
    if (frame == self.mainFrame)
    {
        [self handleError:error withDataSource: frame.provisionalDataSource];
    }
}

/* didFailLoadWithError
 * Invoked when a location request for frame has failed to load.
 */
-(void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (frame == self.mainFrame)
    {
        // Not really errors. Load is cancelled or a plugin is grabbing the URL and will handle it by itself.
        if (!([error.domain isEqualToString:WebKitErrorDomain] && (error.code == NSURLErrorCancelled || error.code == /*WebKitErrorPlugInWillHandleLoad*/ 204)))
            [self handleError:error withDataSource:frame.dataSource];
        [listView endMainFrameLoad];
    }
}

-(void)handleError:(NSError *)error withDataSource:(WebDataSource *)dataSource
{
    // Remember the error.
    [listView setError:error];

    // Load the localized verion of the error page
    WebFrame * frame = self.mainFrame;
    NSString * pathToErrorPage = [[NSBundle bundleForClass:[self class]] pathForResource:@"errorpage" ofType:@"html"];
    if (pathToErrorPage != nil)
    {
        NSString *errorMessage = [NSString stringWithContentsOfFile:pathToErrorPage encoding:NSUTF8StringEncoding error:NULL];
        errorMessage = [errorMessage stringByReplacingOccurrencesOfString: @"$ErrorInformation" withString: error.localizedDescription];
        if (errorMessage != nil)
            [frame loadAlternateHTMLString:errorMessage baseURL:[NSURL fileURLWithPath:pathToErrorPage isDirectory:NO] forUnreachableURL:dataSource.request.URL];
    }
}

/* didFinishLoadForFrame
 * Invoked when a location request for frame has successfully; that is, when all the resources are done loading.
 */
-(void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (frame == self.mainFrame)
        [listView endMainFrameLoad];
}

// MARK: - WebUIDelegate methods


/* createWebViewWithRequest
 * Called when the browser wants to create a new window. The request is opened in a new tab.
 */
-(WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
    [listView.controller openURL:request.URL inPreferredBrowser:YES];
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
        return [listView.controller contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];

    // If we have a full HTML page then do the additional web-page specific items.
    if (listView.isCurrentPageFullHTML)
    {
        WebFrame * frameKey = [element valueForKey:WebElementFrameKey];
        if (frameKey != nil)
            return [listView.controller contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
    }

    // Remove the reload menu item if we don't have a full HTML page.
    if (!listView.isCurrentPageFullHTML)
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

@end
