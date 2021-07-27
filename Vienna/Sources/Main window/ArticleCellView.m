//
//  ArticleCellView.m
//
//  Adapted from PXListView by Alex Rozanski
//  Modified by Barijaona Ramaholimihaso
//

#import "ArticleCellView.h"

#import "AppController.h"
#import "ArticleView.h"
#import "Vienna-Swift.h"

#define PROGRESS_INDICATOR_LEFT_MARGIN	8
#define PROGRESS_INDICATOR_DIMENSION_REGULAR 24

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
        if (Preferences.standardPreferences.useNewBrowser) {
            [self initializeWebKitArticleTab];
        } else {
            [self initializeWebViewArticleView:frameRect];
        }

        if ([(NSObject *)articleView isKindOfClass:ArticleView.class]) {
            [(ArticleView *)articleView setOpenLinksInNewBrowser:YES];
        }

		[self setInProgress:NO];
		progressIndicator = nil;
	}
	return self;
}

-(void)initializeWebKitArticleTab {
	articleView = [[WebKitArticleTab alloc] init];
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

/* makeTextSmaller
 * Make webview text size smaller
 */
-(IBAction)makeTextSmaller:(id)sender
{
	[articleView makeTextSmaller:sender];
}

/* makeTextLarger
 * Make webview text size larger
 */
-(IBAction)makeTextLarger:(id)sender
{
	[articleView makeTextLarger:sender];
}

@end
