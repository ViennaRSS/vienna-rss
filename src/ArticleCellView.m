//
//  ArticleCellView.m
//  PXListView
//
//  Adapted from PXListView by Alex Rozanski
//  Modified by Barijaona Ramaholimihaso
//

#import "ArticleCellView.h"
#import "AppController.h"
#import "BrowserView.h"
#import "PXListView.h"
#import "PXListView+Private.h"

#define PROGRESS_INDICATOR_LEFT_MARGIN	8
#define PROGRESS_INDICATOR_DIMENSION_REGULAR 24
#define DEFAULT_CELL_HEIGHT	150
#define XPOS_IN_CELL	6
#define YPOS_IN_CELL	2

@implementation ArticleCellView

@synthesize articleView;
@synthesize inProgress, folderId, articleRow;

#pragma mark -
#pragma mark Init/Dealloc

-(id)initWithReusableIdentifier: (NSString*)identifier inFrame:(NSRect)frameRect
{
	if((self = [super initWithReusableIdentifier:identifier]))
	{
		controller = APPCONTROLLER;
		articleView= [[ArticleView alloc] initWithFrame:frameRect];
		// Make the list view the frame load and UI delegate for the web view
		[articleView setUIDelegate:[[controller browserView] primaryTabItemView]];
		[articleView setFrameLoadDelegate:[[controller browserView] primaryTabItemView]];
		// Notify the list view when the article view has finished loading
		SEL loadFinishedSelector = NSSelectorFromString(@"webViewLoadFinished:");
		[[NSNotificationCenter defaultCenter] addObserver:[[controller browserView] primaryTabItemView] selector:loadFinishedSelector name:WebViewProgressFinishedNotification object:articleView];
		[articleView setOpenLinksInNewBrowser:YES];
		[articleView setController:controller];
		[[[articleView mainFrame] frameView] setAllowsScrolling:NO];

		// Make web preferences 16pt Arial to match Safari
		[[articleView preferences] setStandardFontFamily:@"Arial"];
		[[articleView preferences] setDefaultFontSize:16];

		// Enable caching
		[[articleView preferences] setUsesPageCache:YES];
		[articleView setMaintainsBackForwardList:NO];
		[self setInProgress:NO];
		progressIndicator = nil;
	}
	return self;
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:[[controller browserView] primaryTabItemView] name:WebViewProgressFinishedNotification object:articleView];
	[articleView stopLoading:self];
	[articleView setUIDelegate:nil];
	[articleView setFrameLoadDelegate:nil];
	[articleView release], articleView=nil;
	[progressIndicator release], progressIndicator=nil;

	[super dealloc];
}

#pragma mark -
#pragma mark Reusing Cells

- (void)prepareForReuse
{
	//calculate the frame
	NSRect newWebViewRect = NSMakeRect(XPOS_IN_CELL,
							   YPOS_IN_CELL,
							   NSWidth([self frame]) - XPOS_IN_CELL,
							   DEFAULT_CELL_HEIGHT);
	//set the new frame to the webview
	[articleView stopLoading:self];
	[articleView setFrame:newWebViewRect];
	[self setInProgress:YES];
	[articleView clearHTML];
	[super prepareForReuse];
}

#pragma mark -
#pragma mark Interaction

/* menuForEvent
 * Called when the popup menu is opened on the table.
 * We ensure that the item under the cursor is selected.
 * Handle menu by moving the selection.
 */
-(NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	NSUInteger row = [self row];
	PXListView *listView = [self listView];
	NSUInteger currentSelectedRow = [listView selectedRow];
	if (row != currentSelectedRow)
		[listView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	return ([[listView selectedRows] count] > 0 ? [self menu] : nil);
}

#pragma mark -
#pragma mark Drawing

-(void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	if([self isSelected]) {
		[[NSColor selectedControlColor] set];
	}
	else {
		[[NSColor controlColor] set];
    }

    //Draw the border and background
	NSBezierPath *roundedRect = [NSBezierPath bezierPathWithRect:[self bounds]];
	[roundedRect fill];

	//Progress indicator
	if ([self inProgress])
	{
		if (!progressIndicator)
		{
			// Allocate and initialize the spinning progress indicator.
			NSRect progressRect = NSMakeRect(PROGRESS_INDICATOR_LEFT_MARGIN, NSHeight([self bounds]) - PROGRESS_INDICATOR_DIMENSION_REGULAR,
												PROGRESS_INDICATOR_DIMENSION_REGULAR, PROGRESS_INDICATOR_DIMENSION_REGULAR);
			progressIndicator = [[NSProgressIndicator alloc] initWithFrame:progressRect];
			[progressIndicator setControlSize:NSRegularControlSize];
			[progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
			[progressIndicator setDisplayedWhenStopped:NO];
		}

		// Add the progress indicator as a subview of the cell if
		// it is not already one.
		if ([progressIndicator superview] != self)
			[self addSubview:progressIndicator];

		// Start the animation.
		[progressIndicator startAnimation:self];
	}
	else
	{
		// Stop the animation and remove from the superview.
		[progressIndicator stopAnimation:self];
		[[progressIndicator superview] setNeedsDisplayInRect:[progressIndicator frame]];
		[progressIndicator removeFromSuperviewWithoutNeedingDisplay];

		// Release the progress indicator.
		[progressIndicator release];
		progressIndicator = nil;
	}

}

-(void)layoutSubviews
{
	//calculate the new frame
	NSRect newWebViewRect = NSMakeRect(XPOS_IN_CELL,
							   YPOS_IN_CELL,
							   NSWidth([self frame]) - XPOS_IN_CELL,
							   NSHeight([self frame]) -YPOS_IN_CELL);
	//set the new frame to the webview
	[articleView setFrame:newWebViewRect];
	[super layoutSubviews];
}

- (BOOL)acceptsFirstResponder
{
	return NO;
};

/* keyDown
 * Here is where we handle special keys when this view
 * has the focus so we can do custom things.
 */
-(void)keyDown:(NSEvent *)theEvent
{
	[[[self listView] superview] keyDown:theEvent];
}

/* canMakeTextSmaller
 */
-(IBAction)canMakeTextSmaller
{
	[articleView canMakeTextSmaller];
}

/* canMakeTextLarger
 */
-(IBAction)canMakeTextLarger
{
	[articleView canMakeTextLarger];
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
