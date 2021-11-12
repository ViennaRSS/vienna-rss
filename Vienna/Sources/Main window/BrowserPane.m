//
//  BrowserPane.m
//  Vienna
//
//  Created by Steve on 9/7/05.
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

#import "ViennaApp.h"
#import "BrowserPane.h"
#import "TabbedWebView.h"
#import "AppController.h"
#import "HelperFunctions.h"
#import "StringExtensions.h"
#import "AddressBarCell.h"
#import "RichXMLParser.h"
#import "SubscriptionModel.h"
#import "Folder.h"
#import "Constants.h"
#import "Preferences.h"
#import "Vienna-Swift.h"

@implementation BrowserPaneButtonCell

-(BOOL)isOpaque
{
	return NO;
}

-(NSColor *)highlightColorInView:(NSView *)controlView
{
	return nil;
} 
@end

@implementation BrowserPaneButton

-(BOOL)isOpaque
{
	return NO;
}

+(Class)cellClass
{
	return [BrowserPaneButtonCell class];
}

-(NSColor *)highlightColorInView:(NSView *)controlView
{
	return nil;
} 
@end

@interface BrowserPane ()

@property (nonatomic) OverlayStatusBar *statusBar;
@property (nonatomic) NSString *searchString;

-(void)endFrameLoad;
-(void)showRssPageButton:(BOOL)showButton;
-(void)setError:(NSError *)newError;

@end

@implementation BrowserPane

@synthesize tabUrl, loading;

+ (void)load
{
    if (self == [BrowserPane class]) {
        //These are synonyms
        [self exposeBinding:@"loading"];
        [self exposeBinding:@"isProcessing"];
    }
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
	{
	    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	    
	    if ([key isEqualToString:@"isProcessing"]) {
	        NSSet *affectingKeys = [NSSet setWithObjects:@"loading", nil];
	        keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
	    }
	    
	    return keyPaths;
	}

/* initWithFrame
 * Initialise our view.
 */
-(instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
		[self willChangeValueForKey:@"loading"];
		loading = NO;
		[self didChangeValueForKey:@"loading"];
		_title = @"";
		pageFilename = nil;
		lastError = nil;
		hasRSSlink = NO;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkAndLoad:) name:@"MA_Notify_TabChanged" object:self];
    }
    return self;
}

/* awakeFromNib
 * Do things that only make sense once the NIB is loaded.
 */
-(void)awakeFromNib
{
	// Create our webview
	[_webPane initTabbedWebView];
	_webPane.frameLoadDelegate = self;
	
	// Use an AddressBarCell for the address field which allows space for the
	// web page image and an optional lock icon for secure pages.
	AddressBarCell * cell = [[AddressBarCell alloc] init];
	[cell setEditable:YES];
	[cell setDrawsBackground:YES];
	[cell setBordered:YES];
	[cell setBezeled:YES];
	[cell setScrollable:YES];
	cell.target = self;
	cell.action = @selector(handleAddress:);
    cell.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall]];
	addressField.cell = cell;

	// The RSS page button is hidden by default
	[self showRssPageButton:NO];

	// Set tooltips
    addressField.toolTip = NSLocalizedString(@"Enter the URL here", nil);
    addressField.cell.accessibilityTitle = NSLocalizedString(@"Enter the URL here", nil);
	refreshButton.toolTip = NSLocalizedString(@"Refresh the current page", nil);
	refreshButton.cell.accessibilityTitle = NSLocalizedString(@"Refresh the current page", nil);
	backButton.toolTip = NSLocalizedString(@"Return to the previous page", nil);
	backButton.cell.accessibilityTitle = NSLocalizedString(@"Return to the previous page", nil);
	forwardButton.toolTip = NSLocalizedString(@"Go forward to the next page", nil);
    forwardButton.cell.accessibilityTitle = NSLocalizedString(@"Go forward to the next page", nil);
	rssPageButton.toolTip = NSLocalizedString(@"Subscribe to the feed for this page", nil);
	rssPageButton.cell.accessibilityTitle = NSLocalizedString(@"Subscribe to the feed for this page", nil);

    [NSUserDefaults.standardUserDefaults addObserver:self
                                          forKeyPath:MAPref_ShowStatusBar
                                             options:NSKeyValueObservingOptionInitial
                                             context:nil];
}

/* viewLink
 * Return the URL being displayed as a string.
 */
-(NSString *)viewLink
{
	if (self.webPane.mainFrame.dataSource.unreachableURL)
		return self.webPane.mainFrame.dataSource.unreachableURL.absoluteString;
	return self.tabUrl.absoluteString;
}

/* showRssPageButton
 * Conditionally show or hide the RSS page button.
 */
 // TODO : associate a menu when there are multiple feeds
-(void)showRssPageButton:(BOOL)showButton
{
	rssPageButton.enabled = showButton;
}

/* setError
 * Save the most recent error instance.
 */
-(void)setError:(NSError *)newError
{
	lastError = newError;
}

-(void)resetError {
    lastError = nil;
}

/* handleAddress
 * Called when the user hits Enter on the address bar.
 */
-(IBAction)handleAddress:(id)sender
{
	NSString * theURL = addressField.stringValue;
	if ([NSURL URLWithString:theURL].scheme == nil)
	{
	    // If no '.' appears in the string, wrap it with 'www' and 'com'
	    if (![theURL vna_hasCharacter:'.'])
	    {
		    theURL = [NSString stringWithFormat:@"www.%@.com", theURL];
        }
		theURL = [NSString stringWithFormat:@"http://%@", theURL];
	}

	// cleanUpUrl is a hack to handle Internationalized Domain Names. WebKit handles them automatically, so we tap into that.
	NSURL *urlToLoad = cleanedUpUrlFromString(theURL);
	if (urlToLoad != nil)
	{
		//set url and load immediately, because action was invoked by user
		self.tabUrl = urlToLoad;
		[self loadTab];
	}
	else
		[self activateAddressBar];
}

/* activateAddressBar
 * Put the focus on the address bar.
 */
-(void)activateAddressBar
{
	[NSApp.mainWindow makeFirstResponder:addressField];
}

/* To perform initial loading when tab first opened
 */
-(void)checkAndLoad:(NSNotification *)notification {
	if (self.webPane.mainFrame.dataSource.request == nil)
	{
		[self loadTab];
	}
}

/* loadURL
 * Load the specified URL into the web frame.
 */
-(void)loadTab
{
	if (!self.tabUrl) {
		return;
	}

	pageFilename = self.tabUrl.path.lastPathComponent.stringByDeletingPathExtension;
	
	if (self.webPane.loading)
	{
		[self willChangeValueForKey:@"isLoading"];
		[self.webPane stopLoading:self];
		[self didChangeValueForKey:@"loading"];
	}
	[self.webPane.mainFrame loadRequest:[NSURLRequest requestWithURL:self.tabUrl]];
}

-(void)setTabUrl:(NSURL *)url {
    tabUrl = url;
    addressField.stringValue = url ? url.absoluteString : @"";
    self.tab.label = url ? url.host : NSLocalizedString(@"New Tab", nil);
}

/* endFrameLoad
 * Handle the end of a load whether or not it completed and whether or not an error
 * occurred. The error variable is nil for no error or it contains the most recent
 * NSError incident.
 */
-(void)endFrameLoad
{
    if ([self.title isEqualToString:@""])
    {
        if (lastError == nil)
        {
            self.tab.label = pageFilename;
            self.title = pageFilename;
        }
    }

    [self willChangeValueForKey:@"loading"];
    loading = NO;
    [self didChangeValueForKey:@"loading"];
}

/* printDocument
 * Print the web page.
 */
-(void)printDocument:(id)sender
{
    [self.webPane printDocument:sender];
}

/* mainView
 * Return the view that typically receives focus
 */
-(NSView *)mainView
{
    return self.webPane;
}

/* webView
 * Return the web view of this view.
 */
-(WebView *)webView
{
    return self.webPane;
}

- (NSString *)textSelection {
    if (self.webPane != nil)
    {
        NSView * docView = self.webPane.mainFrame.frameView.documentView;

        if ([docView conformsToProtocol:@protocol(WebDocumentText)]) {
            return [[(id<WebDocumentText>)docView selectedString] copy];
        } else {
            return @"";
        }
    } else {
        return @"";
    }

    return @"";
}

- (NSString *)html {
    if (self.webPane != nil)
    {
        WebDataSource * dataSource = self.webPane.mainFrame.dataSource;
        if (dataSource != nil)
        {
            id representation = dataSource.representation;
            if ((representation != nil) && ([representation conformsToProtocol:@protocol(WebDocumentRepresentation)]) && ([(id<WebDocumentRepresentation>)representation canProvideDocumentSource]))
                return [[(id<WebDocumentRepresentation>)representation documentSource] copy];
        }
    }
    return @"";
}

/* performFindPanelAction
 * Implement the search action. Search the web page for the specified
 * text.
 */
-(void)performFindPanelAction:(NSInteger)actionTag
{
    switch (actionTag)
    {
        case NSFindPanelActionSetFindString:
        {
			//TODO: unfortunately, webpane takes focus after every search action. Continuous searching would be nice if it worked though
			//[self.webPane searchFor:self.searchString direction:YES caseSensitive:NO wrap:YES];
            break;
        }

        case NSFindPanelActionNext:
            [self.webPane searchFor:self.searchString
                          direction:YES
                      caseSensitive:NO
                               wrap:YES];
            break;

        case NSFindPanelActionPrevious:
            [self.webPane searchFor:self.searchString
                          direction:NO
                      caseSensitive:NO
                               wrap:YES];
            break;
    }
}

/* canGoForward
 * Return TRUE if we can go forward to a web page.
 */
-(BOOL)canGoForward
{
    return self.webPane.canGoForward;
}

/* canGoBack
 * Return TRUE if we can go to a previous web page.
 */
-(BOOL)canGoBack
{
    return self.webPane.canGoBack;
}

/* handleGoForward
 * Go to the next web page.
 */
-(IBAction)handleGoForward:(id)sender
{
    [self.webPane goForward];
}

/* handleGoBack
 * Go to the previous web page.
 */
-(IBAction)handleGoBack:(id)sender
{
    [self.webPane goBack];
}

-(void)updateAlternateMenuTitle
{
    // TODO: use to add "Open page in (external browser)"
}

/* swipeWithEvent
 * Enables "back"/"forward" and "scroll to top"/"scroll to bottom" via three-finger swipes as in Safari and other applications.
 */
-(void)swipeWithEvent:(NSEvent *)event
{
    CGFloat deltaX = event.deltaX;
    CGFloat deltaY = event.deltaY;

    // If the horizontal component of the swipe is larger, the user wants to go back or forward...
    if (fabs(deltaX) > fabs(deltaY))
    {
        if (deltaX != 0)
        {
            if (deltaX > 0)
                [self handleGoBack:self];
            else
                [self handleGoForward:self];
        }
    }
    // Otherwise, she wants to go to the top/bottom of the page.
    else
    {
        if (deltaY != 0)
        {
            if (deltaY > 0)
                [self.webPane scrollToTop];
            else
                [self.webPane scrollToBottom];
        }
    }
}

/* handleReload
 * Reload the current web page.
 */
-(IBAction)handleReload:(id)sender
{
    if (self.webPane.mainFrame.dataSource != nil)
        [self.webPane reload:self];
    else
        [self handleAddress:self];
}

/* handleStopLoading webview
 * Stop loading the current web page.
 */
-(void)handleStopLoading:(id)sender
{
    [self willChangeValueForKey:@"loading"];
    // stop Javascript and plugings
    [self.webPane abortJavascript];
    [self.webPane setUIDelegate:nil];
    [self.webPane stopLoading:self];
    [self didChangeValueForKey:@"loading"];
    [self.webPane.mainFrame loadHTMLString:@"" baseURL:nil];
}

/* handleRSSPage
 * Open the RSS feed for the current page.
 */
-(IBAction)handleRSSPage:(id)sender
{
    if (hasRSSlink)
    {
        NSURL *rssUrl = self.tabUrl;
        [APPCONTROLLER createSubscriptionInCurrentLocationForUrl:rssUrl];
    }
}

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger)flags
{
    return NO;
}

/* dealloc
 * Clean up when the view is being deleted.
 */
-(void)dealloc
{
    [NSUserDefaults.standardUserDefaults removeObserver:self
                                             forKeyPath:MAPref_ShowStatusBar];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self handleStopLoading:nil];
    [_webPane close];
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
            [self addSubview:self.statusBar];
        } else if (!isStatusBarShown && self.statusBar) {
            [self.statusBar removeFromSuperview];
            self.statusBar = nil;
        }
    }
}

/* loading
 * Returns whether the current web page is in the process of being loaded.
 */
-(BOOL)isLoading
{
    return loading;
}

/* isProcessing
 * Synonymous function that enables the progress indicator on the active tab.
 */
-(BOOL)isProcessing
{
    return self.loading;
}

-(void)setIsProcessing:(BOOL)isProcessing
{
    //TODO: intentionally does nothing. Find more elegant way
}

-(void)setHasCloseButton:(BOOL)hasCloseButton
{
    //TODO: INTENTIONALLY EMPTY, find more elegant way
}

-(BOOL)hasCloseButton
{
    //TODO: find out why MMTabBar needs this and fix
    return YES;
}

#pragma mark - WebFrameLoadDelegate

/* didStartProvisionalLoadForFrame
 * Invoked when a new client request is made by sender to load a provisional data source for frame.
 */
-(void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
    if (frame == self.webPane.mainFrame)
    {
        [self showRssPageButton:NO];
        [self resetError];
    }

}

/* didCommitLoadForFrame
 * Invoked when data source of frame has started to receive data.
 */
-(void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
    if (frame == self.webPane.mainFrame)
    {
        NSURL * url = frame.dataSource.request.URL;
        NSURL * unreachableURL = frame.dataSource.unreachableURL;
        [self setLoadingURL:url unreachable:unreachableURL];
    }
}

/* didFailProvisionalLoadWithError
 * Invoked when a location request for frame has failed to load.
 */
-(void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (frame == self.webPane.mainFrame)
    {
        // Was this a feed redirect? If so, this isn't an error:
        if (!(self.webPane.feedRedirect || self.webPane.download))
        {
            [self showError:error forWebFrame:frame];
        }
        [self endFrameLoad];
    }
}

/* didFailLoadWithError
 * Invoked when a location request for frame has failed to load.
 */
-(void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (frame == self.webPane.mainFrame)
    {
        // Not really errors. Load is cancelled or a plugin is grabbing the URL and will handle it by itself.
        if (!([error.domain isEqualToString:WebKitErrorDomain]
              && (error.code == NSURLErrorCancelled || error.code == WebKitErrorPlugInWillHandleLoad))) {
            [self showError:error forWebFrame:frame];
        }
        [self endFrameLoad];
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (frame != self.webPane.mainFrame) {
        return;
    }

    NSData *data = frame.dataSource.data;
    NSURL *url = frame.dataSource.response.URL;
    VNAFeedDiscoverer *parser = [[VNAFeedDiscoverer alloc] initWithData:data
                                                                baseURL:url];
    hasRSSlink = [parser documentHasFeeds];
    [self showRssPageButton:hasRSSlink];

    [self endFrameLoad];
}

/* didReceiveTitle
 * Invoked when the page title arrives. We use this to set the tab title.
 */
-(void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    if (frame == self.webPane.mainFrame)
    {
        //TODO: do not use reference from browswerpane to tab
        self.tab.label = title;
        self.title = title;
    }
}

/* didReceiveIcon
 * Invoked when we get the page icon.
 */
-(void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame
{
    if (frame == self.webPane.mainFrame)
    {
        image.size = NSMakeSize(14, 14);
        iconImage.image = image;
        //TODO: show icon in tab (maybe based on user setting)
    }
}

#pragma mark - WebFrameLoad helper methods

-(void)setLoadingURL:(NSURL *)url unreachable:(NSURL *)unreachableURL {
    if (!loading)
    {
        [self willChangeValueForKey:@"loading"];
        loading = YES;
        [self didChangeValueForKey:@"loading"];
    }

    // Show or hide the lock icon depending on whether this is a secure
    // web page.
    if ([url.scheme isEqualToString:@"https"])
    {
        [addressField.cell setHasSecureImage:YES];
        [lockIconImage setHidden:NO];
    }
    else
    {
        [addressField.cell setHasSecureImage:NO];
        [lockIconImage setHidden:YES];
    }

    if (!unreachableURL) {
        self.tabUrl = url;
    } else {
        self.tabUrl = unreachableURL;
    }
}

- (void)showError:(NSError *)error forWebFrame:(WebFrame *)frame {
    [self setError:error];

    // Use a warning sign as favicon
    iconImage.image = [NSImage imageNamed:@"folderError"];

    // Load the localized verion of the error page
    NSString * pathToErrorPage = [[NSBundle bundleForClass:[self class]] pathForResource:@"errorpage" ofType:@"html"];
    if (pathToErrorPage != nil)
    {
        NSString *errorMessage = [NSString stringWithContentsOfFile:pathToErrorPage encoding:NSUTF8StringEncoding error:NULL];
        errorMessage = [errorMessage stringByReplacingOccurrencesOfString: @"$ErrorInformation" withString: error.localizedDescription];
        if (errorMessage != nil)
        {
            [frame loadAlternateHTMLString:errorMessage baseURL:[NSURL fileURLWithPath:pathToErrorPage isDirectory:NO] forUnreachableURL:frame.provisionalDataSource.request.URL];
        }
        NSString *unreachableURL = frame.provisionalDataSource.unreachableURL.absoluteString;
        if (unreachableURL != nil)
            self.tabUrl = frame.provisionalDataSource.unreachableURL;
    }
}

#pragma mark - WebUIDelegate helper methods

- (void)hoveredOverURL:(NSURL *)url {
    if (self.statusBar) {
        self.statusBar.label = url.absoluteString;
    }
}

#pragma mark - BrowserTab Protocol Requirements

- (BOOL)back {
	BOOL canGoBack = [self.webPane canGoBack];
    [self handleGoBack:nil];
	return canGoBack;
}

- (BOOL)forward {
	BOOL canGoForward = [self.webPane canGoForward];
	[self handleGoForward:nil];
	return canGoForward;
}

- (void)decreaseTextSize {
	[self.webPane makeTextSmaller:nil];
}


- (void)increaseTextSize {
	[self.webPane makeTextLarger:nil];
}

- (void)printPage {
	[self.webPane printDocument:self];
}


- (void)reloadTab {
    [self handleReload:nil];
}

- (void)searchFor:(NSString * _Nonnull)searchString
           action:(NSFindPanelAction)action {
    self.searchString = searchString;
    [self performFindPanelAction:action];
}

- (void)stopLoadingTab {
    [self handleStopLoading:nil];
}

- (void)closeTab {
    [self stopLoadingTab]; //remainder will be handeled by dealloc
}

- (void)activateWebView {
    [self.window makeFirstResponder:self.webPane];
}

@end
