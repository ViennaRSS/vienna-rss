//
//  ArticleCellView.m
//
//  Adapted from PXListView by Alex Rozanski
//  Modified by Barijaona Ramaholimihaso
//

#import "ArticleCellView.h"

#import "AppController.h"
#import "ArticleController.h"
#import "ArticleView.h"
#import "Preferences.h"
#import "Vienna-Swift.h"

#define PROGRESS_INDICATOR_LEFT_MARGIN	8
#define PROGRESS_INDICATOR_DIMENSION_REGULAR 24

#define WebKitErrorPlugInWillHandleLoad    204

@implementation ArticleCellView

@synthesize listView = _listView;
@synthesize articleView;
@synthesize progressIndicator;
@synthesize inProgress, folderId, articleRow;

#pragma mark -
#pragma mark Init/Dealloc

-(instancetype)initWithFrame:(NSRect)frameRect
{
	if((self = [super initWithFrame:frameRect]))
	{
		controller = APPCONTROLLER;
        [self initializeWebKitArticleView:frameRect];

        if ([(NSObject *)articleView isKindOfClass:ArticleView.class]) {
            [(ArticleView *)articleView setOpenLinksInNewBrowser:YES];
        }

		[self setInProgress:NO];
		progressIndicator = nil;
	}
	return self;
}

-(void)initializeWebKitArticleView:(NSRect)frameRect {
	WebKitArticleView * myArticleView = [[WebKitArticleView alloc] initWithFrame:frameRect];
    myArticleView.navigationDelegate = (id<WKNavigationDelegate>)self;
    articleView = myArticleView;
}

-(void)initializeWebViewArticleView:(NSRect)frameRect {
	ArticleView *webViewArticleView = [[ArticleView alloc] initWithFrame:frameRect];
	articleView = webViewArticleView;
	//TODO: do not get the primary tab from browser, but retrieve the articles tab directly
	// Make the list view the frame load and UI delegate for the web view
	webViewArticleView.UIDelegate = (NSView<WebUIDelegate> *)controller.browser.primaryTab.view;
	webViewArticleView.frameLoadDelegate = (NSView<WebFrameLoadDelegate> *) controller.browser.primaryTab.view;
	// Notify the list view when the article view has finished loading
	SEL loadFinishedSelector = NSSelectorFromString(@"webViewLoadFinished:");
	[[NSNotificationCenter defaultCenter] addObserver:controller.browser.primaryTab.view selector:loadFinishedSelector name:WebViewProgressFinishedNotification object:articleView];
	[webViewArticleView.mainFrame.frameView setAllowsScrolling:NO];

	[webViewArticleView setMaintainsBackForwardList:NO];
}

-(void)dealloc
{
    //TODO: do not get the primary tab from browser, but retrieve the articles tab directly
	[[NSNotificationCenter defaultCenter] removeObserver:controller.browser.primaryTab.view name:WebViewProgressFinishedNotification object:articleView];
}

#pragma mark -
#pragma mark Drawing

-(void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	if([self.listView.selectedRowIndexes containsIndex:articleRow]) {
		[[NSColor selectedControlColor] set];
	}
	else {
		[[NSColor controlColor] set];
    }

    //Draw the border and background
	NSBezierPath *roundedRect = [NSBezierPath bezierPathWithRect:self.bounds];
	[roundedRect fill];

	//Progress indicator
	if (self.inProgress)
	{
		if (!progressIndicator)
		{
			// Allocate and initialize the spinning progress indicator.
			NSRect progressRect = NSMakeRect(PROGRESS_INDICATOR_LEFT_MARGIN, NSHeight(self.bounds) - PROGRESS_INDICATOR_DIMENSION_REGULAR,
												PROGRESS_INDICATOR_DIMENSION_REGULAR, PROGRESS_INDICATOR_DIMENSION_REGULAR);
			progressIndicator = [[NSProgressIndicator alloc] initWithFrame:progressRect];
            progressIndicator.controlSize = NSControlSizeRegular;
			progressIndicator.style = NSProgressIndicatorStyleSpinning;
			[progressIndicator setDisplayedWhenStopped:NO];
		}

		// Add the progress indicator as a subview of the cell if
		// it is not already one.
		if (progressIndicator.superview != self)
			[self addSubview:progressIndicator];

		// Start the animation.
		[progressIndicator startAnimation:self];
	}
	else
	{
		// Stop the animation and remove from the superview.
		[progressIndicator stopAnimation:self];
		[progressIndicator.superview setNeedsDisplayInRect:progressIndicator.frame];
		[progressIndicator removeFromSuperviewWithoutNeedingDisplay];

		// Release the progress indicator.
		progressIndicator = nil;
	}

}

- (BOOL)acceptsFirstResponder
{
	return NO;
}

/* makeTextStandardSize
 * Make webview text size smaller
 */
-(IBAction)makeTextStandardSize:(id)sender
{
	[articleView resetTextSize];
}

/* makeTextSmaller
 * Make webview text size smaller
 */
-(IBAction)makeTextSmaller:(id)sender
{
	[articleView decreaseTextSize];
}

/* makeTextLarger
 * Make webview text size larger
 */
-(IBAction)makeTextLarger:(id)sender
{
	[articleView increaseTextSize];
}

#pragma mark -
#pragma mark WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    // sometimes, for some unknown reason, the html file is missing in action.
    // If it occurs, we just provoke a new request
    if ([webView isEqualTo:((WebKitArticleView *)self.articleView)]) {
        [self setInProgress:NO];
        NSUInteger row = self.articleRow;
        NSArray *allArticles = self->controller.articleController.allArticles;
        if (row < (NSInteger)allArticles.count) {
            [self.listView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        }
        // Note: it's on purpose that we do not call deleteHtmlFile here,
        // because it's almost certain that the reason we got into this delegate call
        // is that the file is already missing.
        // Not removing the file does not seem to cause orphan files,
        // while trying to remove it causes much more error messages in log.
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    // Not really errors. Load is cancelled or a plugin is grabbing the URL and will handle it by itself.
    if (!([error.domain isEqualToString:WebKitErrorDomain] &&
          (error.code == NSURLErrorCancelled || error.code == WebKitErrorPlugInWillHandleLoad)))
    {
        if ([webView isEqualTo:((WebKitArticleView *)self.articleView)]) {
            [self setInProgress:NO];
            NSUInteger row = self.articleRow;
            NSArray *allArticles = self->controller.articleController.allArticles;
            if (row < (NSInteger)allArticles.count) {
                [self.listView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            }
            WebKitArticleView *articleView = (WebKitArticleView *)(self.articleView);
            [articleView deleteHtmlFile];
        } else {
            // TODO : what should we do ?
            NSLog(@"Webview error %@ associated to webViews %@ and %@", error, ((WebKitArticleView *)self.articleView), webView);
        }
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if ([webView isEqualTo:((WebKitArticleView *)self.articleView)]) {
        NSUInteger row = [self.listView rowForView:self];
        if (row == self.articleRow && row < self->controller.articleController.allArticles.count
            && self.folderId == [self->controller.articleController.allArticles[row] folderId])
        {    //relevant cell
            [webView evaluateJavaScript:@"document.documentElement.offsetHeight"
                      completionHandler:^(id _Nullable result, NSError *_Nullable error) {
                          CGFloat fittingHeight = ((NSNumber *)result).doubleValue;
                          //calculate the new frame
                          NSRect newWebViewRect = NSMakeRect(0,
                                                   0,
                                                   NSWidth(webView.superview.frame),
                                                   fittingHeight);
                          //set the new frame to the webview
                          webView.frame = newWebViewRect;
                          self.fittingHeight = fittingHeight;
                          [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_CellResize" object:self];
                          WebKitArticleView *articleView = (WebKitArticleView *)(self.articleView);
                          [articleView deleteHtmlFile];
                      }];
        } else { //non relevant cell
            [self setInProgress:NO];
            if (row < self->controller.articleController.allArticles.count) {
                [self.listView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            }
            WebKitArticleView *articleView = (WebKitArticleView *)(self.articleView);
            [articleView deleteHtmlFile];
        }
    }
} // webView:didFinishNavigation:

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if ((navigationAction.navigationType) == WKNavigationTypeLinkActivated) {
        // prevent navigation to links opened through click
        decisionHandler(WKNavigationActionPolicyCancel);
        // open in new preferred browser instead, or the alternate one if the option key is pressed
        NSUInteger modifierFlags = navigationAction.modifierFlags;
        BOOL openInPreferredBrower = (modifierFlags & NSEventModifierFlagOption) ? NO : YES; // This is to avoid problems in casting the value into BOOL
        // TODO: maybe we need to add an api that opens a clicked link in foreground to the AppController
        [APPCONTROLLER openURL:navigationAction.request.URL inPreferredBrowser:openInPreferredBrower];
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

@end
