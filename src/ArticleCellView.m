//
//  ArticleCellView.m
//
//  Adapted from PXListView by Alex Rozanski
//  Modified by Barijaona Ramaholimihaso
//

#import "ArticleCellView.h"

#import "AppController.h"
#import "ArticleView.h"
#import "BrowserView.h"

#define PROGRESS_INDICATOR_LEFT_MARGIN	8
#define PROGRESS_INDICATOR_DIMENSION_REGULAR 24
#define DEFAULT_CELL_HEIGHT	300
#define XPOS_IN_CELL	6
#define YPOS_IN_CELL	2

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
		articleView= [[ArticleView alloc] initWithFrame:frameRect];
		// Make the list view the frame load and UI delegate for the web view
		articleView.UIDelegate = [controller.browserView primaryTabItemView];
		articleView.frameLoadDelegate = [controller.browserView primaryTabItemView];
		// Notify the list view when the article view has finished loading
		SEL loadFinishedSelector = NSSelectorFromString(@"webViewLoadFinished:");
		[[NSNotificationCenter defaultCenter] addObserver:[controller.browserView primaryTabItemView] selector:loadFinishedSelector name:WebViewProgressFinishedNotification object:articleView];
		[articleView setOpenLinksInNewBrowser:YES];
		[articleView.mainFrame.frameView setAllowsScrolling:NO];

		[articleView setMaintainsBackForwardList:NO];
		[self setInProgress:NO];
		progressIndicator = nil;
	}
	return self;
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:[controller.browserView primaryTabItemView] name:WebViewProgressFinishedNotification object:articleView];
	[articleView setUIDelegate:nil];
	[articleView setFrameLoadDelegate:nil];
	[articleView stopLoading:self];

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
    [self layoutSubviews];

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
			progressIndicator.controlSize = NSRegularControlSize;
			progressIndicator.style = NSProgressIndicatorSpinningStyle;
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

-(void)layoutSubviews
{
	//calculate the new frame
	NSRect newWebViewRect = NSMakeRect(XPOS_IN_CELL,
							   YPOS_IN_CELL,
							   NSWidth(self.frame) - XPOS_IN_CELL,
							   NSHeight(self.frame) -YPOS_IN_CELL);
	//set the new frame to the webview
	articleView.frame = newWebViewRect;
}

- (BOOL)acceptsFirstResponder
{
	return NO;
};

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
