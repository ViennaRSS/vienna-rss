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

@implementation ArticleCellView

@synthesize articleView;
@synthesize inProgress, folderId;

#pragma mark -
#pragma mark Init/Dealloc

-(id)initWithReusableIdentifier: (NSString*)identifier inFrame:(NSRect)frameRect
{
	if((self = [super initWithReusableIdentifier:identifier]))
	{
		controller = (AppController *)[NSApp delegate];
		articleView= [[ArticleView alloc] initWithFrame:frameRect];
		// Make the list view the frame load and UI delegate for the web view
		[articleView setUIDelegate:[[controller browserView] primaryTabItemView]];
		[articleView setFrameLoadDelegate:[[controller browserView] primaryTabItemView]];
		[articleView setOpenLinksInNewBrowser:YES];
		[articleView setController:controller];
		[[[articleView mainFrame] frameView] setAllowsScrolling:NO];

		// Make web preferences 16pt Arial to match Safari
		[[articleView preferences] setStandardFontFamily:@"Arial"];
		[[articleView preferences] setDefaultFontSize:16];

		// Disable caching
		[[articleView preferences] setUsesPageCache:NO];
		[articleView setMaintainsBackForwardList:NO];
		[self setInProgress:NO];
		progressIndicator = nil;
	}
	return self;
}

-(void)dealloc
{
	[articleView release], articleView=nil;
	[progressIndicator release], progressIndicator=nil;

	[super dealloc];
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
			NSRect progressRect = NSMakeRect(PROGRESS_INDICATOR_LEFT_MARGIN, NSHeight([self frame]) - PROGRESS_INDICATOR_DIMENSION_REGULAR,
												PROGRESS_INDICATOR_DIMENSION_REGULAR, PROGRESS_INDICATOR_DIMENSION_REGULAR);
			progressIndicator = [[NSProgressIndicator alloc] initWithFrame:progressRect];
			[progressIndicator setControlSize:NSRegularControlSize];
			[progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
			[progressIndicator setUsesThreadedAnimation:NO]; //priority to display

			// Start the animation.
			[progressIndicator startAnimation:self];
		}

		// Add the progress indicator as a subview of the cell if
		// it is not already one.
		if ([progressIndicator superview] != self)
			[self addSubview:progressIndicator];

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
	[[[self listView] superview] keyDown:theEvent];
}

@end
