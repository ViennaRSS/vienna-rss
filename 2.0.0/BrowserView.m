//
//  BrowserView.m
//  Vienna
//
//  Created by Steve on 8/26/05.
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

#import "BrowserView.h"

// Dimensions
static const int MA_Max_TabWidth = 180;
static const int MA_Min_TabWidth = 40;
static const int MA_Tab_Height = 20;
static const int MA_Left_Margin_Width = 10;

// Close button states
#define NORMAL_STATE		1
#define HIGHLIGHTED_STATE	2
#define PRESSED_STATE		3

/* BrowserTab
 * Defines a single tab with its associated view, title and
 * the position/size of the tab in the browser view.
 */
@interface BrowserTab : NSObject {
	NSView * associatedView;
	NSString * title;
	NSString * displayTitle;
	NSRect rect;
	NSRect textRect;
	NSRect closeButtonRect;
	int closeButtonState;
	NSTrackingRectTag trackingRectTag;
	NSTrackingRectTag closeButtonTrackingRectTag;
	NSToolTipTag toolTipTag;
}

// All accessors, set and get
-(NSView *)associatedView;
-(NSString *)title;
-(NSString *)displayTitle;
-(NSRect)rect;
-(NSRect)textRect;
-(NSRect)closeButtonRect;
-(BOOL)hasCloseButton;
-(int)closeButtonState;
-(NSTrackingRectTag)trackingRectTag;
-(NSTrackingRectTag)closeButtonTrackingRectTag;
-(NSToolTipTag)toolTipTag;
-(void)setAssociatedView:(NSView<BaseView> *)newView;
-(void)setTitle:(NSString *)newTitle;
-(void)setDisplayTitle:(NSString *)newDisplayTitle;
-(void)setRect:(NSRect)newRect;
-(void)setTextRect:(NSRect)newTextRect;
-(void)setCloseButtonState:(int)newState;
-(void)setCloseButtonRect:(NSRect)newCloseButtonRect;
-(void)setTrackingRectTag:(NSTrackingRectTag)newTag;
-(void)setCloseButtonTrackingRectTag:(NSTrackingRectTag)newTag;
-(void)setToolTipTag:(NSToolTipTag)newToolTipTag;
@end;

@implementation BrowserTab

/* init
 * This is the designated initialiser.
 */
-(id)initWithView:(NSView *)newView
{
	if ((self = [super init]) != nil)
	{
		[self setAssociatedView:newView];
		[self setTitle:@""];
		[self setRect:NSZeroRect];
		[self setTextRect:NSZeroRect];
		[self setCloseButtonRect:NSZeroRect];
		[self setTrackingRectTag:0];
		[self setCloseButtonTrackingRectTag:0];
		[self setCloseButtonState:NORMAL_STATE];
	}
	return self;
}

/* setAssociatedView
 * Sets the view associated with this tab.
 */
-(void)setAssociatedView:(NSView<BaseView> *)newView
{
	[newView retain];
	[associatedView release];
	associatedView = newView;
}

/* associatedView
 * Retrieves the associated view
 */
-(NSView *)associatedView
{
	return associatedView;
}

/* setTitle
 * Sets the title of the tab. This also sets the display title
 * to the same text.
 */
-(void)setTitle:(NSString *)newTitle
{
	[newTitle retain];
	[title release];
	title = newTitle;
	[self setDisplayTitle:newTitle];
}

/* title
 * Retrieves the tab's title.
 */
-(NSString *)title
{
	return title;
}

/* setDisplayTitle
 * Sets the display title of the tab. The display title is the
 * title truncated to fit in the textRect.
 */
-(void)setDisplayTitle:(NSString *)newDisplayTitle
{
	[newDisplayTitle retain];
	[displayTitle release];
	displayTitle = newDisplayTitle;
}

/* displayTitle
 * Retrieves the tab's display title.
 */
-(NSString *)displayTitle
{
	return displayTitle;
}

/* setCloseButtonState
 * Sets the state of the close button. Valid states are:
 *  NORMAL_STATE - normal appearance.
 *  HIGHLIGHTED_STATE - highlighted
 *  PRESSED_STATE - depressed and highlighted
 */
-(void)setCloseButtonState:(int)newState
{
	closeButtonState = newState;
}

/* closeButtonState
 * Returns the close button state
 */
-(int)closeButtonState
{
	return closeButtonState;
}

/* setRect
 * Sets the rectangle that defines the tab's position and size within the
 * browser view.
 */
-(void)setRect:(NSRect)newRect
{
	rect = newRect;
}

/* rect
 * Returns the tab's rectangle.
 */
-(NSRect)rect
{
	return rect;
}

/* setTextRect
 * Sets the rectangle that defines the the tab's title
 */
-(void)setTextRect:(NSRect)newTextRect
{
	textRect = newTextRect;
}

/* textRect
 * Returns the tab's text rectangle.
 */
-(NSRect)textRect
{
	return textRect;
}

/* setCloseButtonRect
 * Sets the close button rectangle
 */
-(void)setCloseButtonRect:(NSRect)newCloseButtonRect
{
	closeButtonRect = newCloseButtonRect;
}

/* closeButtonRect
 * Returns the close button rectangle.
 */
-(NSRect)closeButtonRect
{
	return closeButtonRect;
}

/* hasCloseButton
 * Returns whether this tab has a close button. An empty closeButtonRect
 * means that setCloseButtonRect hasn't been called to set a close button
 * rectangle so we use that to indicate that the tab has no close button.
 */
-(BOOL)hasCloseButton
{
	return !NSIsEmptyRect(closeButtonRect);
}

/* setTrackingRectTag
 * Set the tracking rectange tag ID for this tab.
 */
-(void)setTrackingRectTag:(NSTrackingRectTag)newTag
{
	trackingRectTag = newTag;
}

/* trackingRectTag
 * Return the tracking rectange tag ID.
 */
-(NSTrackingRectTag)trackingRectTag
{
	return trackingRectTag;
}

/* setCloseButtonTrackingRectTag
 * Set the tracking rectange tag ID for this tab.
 */
-(void)setCloseButtonTrackingRectTag:(NSTrackingRectTag)newTag
{
	closeButtonTrackingRectTag = newTag;
}

/* closeButtonTrackingRectTag
 * Return the tracking rectange tag ID.
 */
-(NSTrackingRectTag)closeButtonTrackingRectTag
{
	return closeButtonTrackingRectTag;
}

/* setToolTipTag
 * Set's the tab's associated tooltip tag.
 */
-(void)setToolTipTag:(NSToolTipTag)newToolTipTag
{
	toolTipTag = newToolTipTag;
}

/* toolTipTag
 * Returns the tab's associated tooltip tag.
 */
-(NSToolTipTag)toolTipTag
{
	return toolTipTag;
}

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
	[displayTitle release];
	[title release];
	[associatedView release];
	[super dealloc];
}
@end

@implementation BrowserView

/* initWithFrame
 * Initialises the browser tab control.
 */
-(id)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame]) != nil)
	{
		activeTab = nil;
		allTabs = nil;
		trackingTab = nil;

		titleAttributes = [[NSMutableDictionary alloc] init];
		[titleAttributes setObject:[NSFont boldSystemFontOfSize:11.0] forKey:NSFontAttributeName];
		[titleAttributes setObject:[NSColor colorWithCalibratedWhite:0.27 alpha:1.0] forKey:NSForegroundColorAttributeName];

		borderColor = [[NSColor colorWithCalibratedWhite:0.27 alpha:1.0] retain];
		inactiveTabBackgroundColor = [[NSColor grayColor] retain];

		closeButton = [[NSImage imageNamed:@"smallCloseButton.tiff"] retain];
		highlightedCloseButton = [[NSImage imageNamed:@"highlightedCloseButton.tiff"] retain];
		pressedCloseButton = [[NSImage imageNamed:@"pressedCloseButton.tiff"] retain];
		closeButtonSize = [closeButton size];

		// Want to be notified when the view is resized.
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(viewWasResized:) name:NSViewBoundsDidChangeNotification object:[self superview]];
		[nc addObserver:self selector:@selector(viewWasResized:) name:NSViewFrameDidChangeNotification object:[self superview]];
    }
    return self;
}

/* updateCloseButton
 * Redraws the close button for a tab depending on its current state.
 */
-(void)updateCloseButton:(BrowserTab *)theTab withLock:(BOOL)doLock
{
	if ([theTab hasCloseButton])
	{
		NSPoint pt = [theTab closeButtonRect].origin;
		NSImage * buttonImage;
		
		switch ([theTab closeButtonState])
		{
			case NORMAL_STATE:		buttonImage = closeButton; break;
			case HIGHLIGHTED_STATE: buttonImage = highlightedCloseButton; break;
			case PRESSED_STATE:		buttonImage = pressedCloseButton; break;
			default:				NSAssert(false, @"Unknown close button state!"); return;
		}
		if (doLock)
			[buttonImage lockFocus];
		[buttonImage compositeToPoint:NSMakePoint(pt.x, pt.y) operation:NSCompositeSourceOver];
		if (doLock)
			[buttonImage unlockFocus];
	}
}

/* drawRect
 * Draw each tab in turn. This code is called on every live resize so it needs to be fast
 * and optimised.
 */
-(void)drawRect:(NSRect)rect
{
	NSRect viewRect = [self bounds];
	int count = [allTabs count];
	if (count > 1)
	{
		int rightEdge = viewRect.origin.x;
		int y0 = (viewRect.origin.y + viewRect.size.height) - MA_Tab_Height;
		int y1 = (viewRect.origin.y + viewRect.size.height);

		NSBezierPath * bpath = [NSBezierPath bezierPath];
		[bpath setLineWidth:1.0];

		int activeTabIndex = [allTabs indexOfObject:activeTab];

		// Paint left margin.
		NSRect leftMargin = NSMakeRect(rightEdge, y0, MA_Left_Margin_Width, y1);
		if (NSIntersectsRect(leftMargin, rect))
		{
			[inactiveTabBackgroundColor set];
			NSRectFill(leftMargin);

			// Draw left and top edge of margin
			[borderColor set];
			[bpath moveToPoint:NSMakePoint(0, y0)];
			[bpath lineToPoint:NSMakePoint(0, y1)];
			[bpath lineToPoint:NSMakePoint(MA_Left_Margin_Width, y1)];
			[bpath stroke];
		}
		rightEdge += MA_Left_Margin_Width;

		// Draw each tab in turn.
		int index;
		for (index = 0; index < count; ++index)
		{
			BrowserTab * theTab = [allTabs objectAtIndex:index];
			int x0 = [theTab rect].origin.x;
			int x1 = x0 + [theTab rect].size.width;
			if (NSIntersectsRect([theTab rect], rect))
			{
				if (index != activeTabIndex)
				{
					[inactiveTabBackgroundColor set];
					NSRectFill([theTab rect]);

					// Draw top edge
					[borderColor set];
					[bpath moveToPoint:NSMakePoint(x0, y1)];
					[bpath lineToPoint:NSMakePoint(x1, y1)];
					[bpath stroke];

					// Draw separator only if the next tab isn't the
					// active tab.
					if (index + 1 != activeTabIndex)
					{
						[borderColor set];
						[bpath moveToPoint:NSMakePoint(x1, y0)];
						[bpath lineToPoint:NSMakePoint(x1, y1)];
						[bpath stroke];
					}
				}

				// Draw the close button for non-primary tabs
				[self updateCloseButton:theTab withLock:NO];

				// Draw the text
				[[theTab displayTitle] drawInRect:[theTab textRect] withAttributes:titleAttributes];
			}
			rightEdge = x1 + 1;
		}
		
		// Fill the remainder
		NSRect spareRect = NSMakeRect(rightEdge, y0, viewRect.size.width - rightEdge, y1);
		if (NSIntersectsRect(spareRect, rect))
		{
			if (rightEdge < viewRect.size.width)
			{
				[inactiveTabBackgroundColor set];
				NSRectFill(spareRect);
			}

			// Draw top edge of reminder and right hand side
			[borderColor set];
			[bpath moveToPoint:NSMakePoint(rightEdge, y1)];
			[bpath lineToPoint:NSMakePoint(viewRect.size.width, y1)];
			[bpath lineToPoint:NSMakePoint(viewRect.size.width, y0)];
			[bpath stroke];
		}
	}
}

/* updateTabTextRect
 * Recomputes a tab's display title and textRect. Typically call this
 * when the tabs change or when the tab's title changes.
 */
-(void)updateTabTextRect:(BrowserTab *)theTab
{
	NSRect textRect = NSInsetRect([theTab rect], 10.0, 0.0);

	// Primary tab doesn't have a close button so we've the full
	// tab width to play with.
	if (theTab != [allTabs objectAtIndex:0])
	{
		textRect.size.width -= (closeButtonSize.width + 10);
		textRect.origin.x += closeButtonSize.width;
	}
	NSString * titleString = [theTab title];
	int length = [titleString length];
	
	NSSize textSize = [titleString sizeWithAttributes:titleAttributes];
	while (textSize.width > textRect.size.width && length > 0)
	{
		titleString = [[titleString substringToIndex:--length] stringByAppendingString:@"..."];
		textSize = [titleString sizeWithAttributes:titleAttributes];
	}
	
	textRect.origin.y += ( textRect.size.height - textSize.height) / 2;
	textRect.origin.x += (textRect.size.width - textSize.width) / 2;
	textRect.size.width = textSize.width;
	textRect.size.height = textSize.height;
	
	[theTab setDisplayTitle:titleString];
	[theTab setTextRect:textRect];
}

/* updateTrackingRectangles
 * Compute the position/size for all the tabs and update the view's tracking rectangle
 * for each one.
 */
-(void)updateTrackingRectangles
{
	NSRect viewRect = [self bounds];
	int count = [allTabs count];
	if (count == 1)
	{
		BrowserTab * primaryTab = [allTabs objectAtIndex:0];
		[self removeTrackingRect:[primaryTab trackingRectTag]];
		[self removeTrackingRect:[primaryTab closeButtonTrackingRectTag]];
		[primaryTab setRect:NSZeroRect];
		[self removeAllToolTips];
	}
	else
	{
		int x0 = viewRect.origin.x + MA_Left_Margin_Width;
		int y0 = (viewRect.origin.y + viewRect.size.height) - MA_Tab_Height;
		int tabWidth = MIN(viewRect.size.width / count, MA_Max_TabWidth);
		int index = 0;
		
		NSPoint mousePt = [self convertPoint:[[self window] convertScreenToBase:[NSEvent mouseLocation]] fromView:nil];

		tabWidth = MAX(MA_Min_TabWidth, tabWidth);
		while (index < count)
		{
			BrowserTab * theTab = [allTabs objectAtIndex:index];
			NSRect computedRect = NSMakeRect(x0, y0, tabWidth, MA_Tab_Height);
			BOOL mouseInTab = NSPointInRect(mousePt, computedRect);
			if (!NSEqualRects(computedRect, [theTab rect]))
			{
				[theTab setRect:computedRect];
				[self removeTrackingRect:[theTab trackingRectTag]];
				[theTab setTrackingRectTag:[self addTrackingRect:computedRect owner:self userData:theTab assumeInside:mouseInTab]];

				// Tabs can have tooltips. We'll provide the actual tooltip text in stringForToolTip
				[self removeToolTip:[theTab toolTipTag]];
				[theTab setToolTipTag:[self addToolTipRect:computedRect owner:self userData:theTab]];

				// Compute the display title and textRect for the display title.
				[self updateTabTextRect:theTab];

				// Compute close button rectangle for non-primary tabs
				if (index > 0)
				{
					int x0 = computedRect.origin.x + 5;
					int y0 = (computedRect.origin.y + (MA_Tab_Height - closeButtonSize.height) / 2);
					NSRect closeRect = NSMakeRect(x0, y0, closeButtonSize.width, closeButtonSize.height);
					[theTab setCloseButtonRect:closeRect];

					[self removeTrackingRect:[theTab closeButtonTrackingRectTag]];
					[theTab setCloseButtonTrackingRectTag:[self addTrackingRect:closeRect owner:self userData:theTab assumeInside:NSPointInRect(mousePt, closeRect)]];
				}
			}
			
			if (mouseInTab)
				trackingTab = theTab;
			
			x0 += tabWidth + 1;
			++index;
		}
	}
}

/* stringForToolTip
 * Returns the tooltip for the tab specified by the userData object. This is the tab's full title which
 * may have been truncated for display.
 */
-(NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
	BrowserTab * theTab = (BrowserTab *)userData;
	return [theTab title];
}

/* mouseEntered
 * Handle the event arising from the cursor entering a tab area.
 */
-(void)mouseEntered:(NSEvent *)theEvent
{
	if (trackingTab != [theEvent userData])
		trackingTab = [theEvent userData];
	if ([trackingTab hasCloseButton])
	{
		NSPoint mousePosition = [self convertPoint:[theEvent locationInWindow] fromView:[[NSApp mainWindow] contentView]];
		if (NSPointInRect(mousePosition, [trackingTab closeButtonRect]))
		{
			[trackingTab setCloseButtonState:HIGHLIGHTED_STATE];
			[self setNeedsDisplayInRect:[trackingTab closeButtonRect]];
			[self displayIfNeeded];
		}
	}
}

/* mouseExited
 * Handle the event arising from the cursor leaving a tab area.
 */
-(void)mouseExited:(NSEvent *)theEvent
{
	if ([trackingTab hasCloseButton])
	{
		NSPoint mousePosition = [self convertPoint:[theEvent locationInWindow] fromView:[[NSApp mainWindow] contentView]];
		if (!NSPointInRect(mousePosition, [trackingTab closeButtonRect]))
		{
			[trackingTab setCloseButtonState:NORMAL_STATE];
			[self setNeedsDisplayInRect:[trackingTab closeButtonRect]];
			[self displayIfNeeded];
			return;
		}
		if (NSPointInRect(mousePosition, [trackingTab rect]))
			return;
	}
	if (trackingTab == [theEvent userData])
		trackingTab = nil;
}

/* mouseDown
 * Handle the event arising from the mouse down in a tab area and make the tab
 * the active tab. However if the mouse down is in the close button then ignore
 * this event (otherwise clicking the close button of an inactive tab first makes
 * it active before closing it - ugly.)
 */
-(void)mouseDown:(NSEvent *)theEvent
{
	if (trackingTab != nil)
	{
		if ([trackingTab hasCloseButton])
		{
			NSPoint mousePosition = [self convertPoint:[theEvent locationInWindow] fromView:[[NSApp mainWindow] contentView]];
			if (NSPointInRect(mousePosition, [trackingTab closeButtonRect]))
			{
				[trackingTab setCloseButtonState:PRESSED_STATE];
				[self setNeedsDisplayInRect:[trackingTab closeButtonRect]];
				[self displayIfNeeded];
				return;
			}
		}
		[self showTab:trackingTab];
	}
}

/* mouseDragged
 * Handle a drag event which can occur when the user clicks in the close button then moves
 * the cursor out of the close button, keeping the mouse button depressed.
 */
-(void)mouseDragged:(NSEvent *)theEvent
{
	if (trackingTab != nil)
	{
		if ([trackingTab hasCloseButton])
		{
			NSPoint mousePosition = [self convertPoint:[theEvent locationInWindow] fromView:[[NSApp mainWindow] contentView]];
			if (!NSPointInRect(mousePosition, [trackingTab closeButtonRect]))
				[trackingTab setCloseButtonState:NORMAL_STATE];
			else
				[trackingTab setCloseButtonState:PRESSED_STATE];
			[self setNeedsDisplayInRect:[trackingTab closeButtonRect]];
			[self displayIfNeeded];
		}
	}
}

/* otherMouseDown
 * Third mouse button click in a tab closes that tab.
 */
-(void)otherMouseDown:(NSEvent *)theEvent
{
	if (trackingTab != nil && [theEvent buttonNumber] == 2)
	{
		[self closeTab:trackingTab];
		return;
	}
}

/* mouseUp
 * Handle the event arising from the mouse up in a tab area. Look to
 * see if the cursor is in the close button and, if so, close the tab.
 * Hold down both Cmd and Alt to close all tabs.
 */
-(void)mouseUp:(NSEvent *)theEvent
{
	if (trackingTab != nil && [trackingTab hasCloseButton])
	{
		NSPoint mousePosition = [self convertPoint:[theEvent locationInWindow] fromView:[[NSApp mainWindow] contentView]];
		if (NSPointInRect(mousePosition, [trackingTab closeButtonRect]))
		{
			if (([theEvent modifierFlags] & (NSAlternateKeyMask|NSCommandKeyMask)) == (NSAlternateKeyMask|NSCommandKeyMask))
				[self closeAllTabs];
			else
				[self closeTab:trackingTab];
		}
	}
}

/* viewWasResized
 * Called when the frame or bounds size changed. We use this to recompute the
 * position of the tabs at the top of the view and update them.
 */
-(void)viewWasResized:(NSNotification *)notification
{
	[self updateTrackingRectangles];
	[self setNeedsDisplay:YES];
}

/* viewSize
 * Returns the dimensions of the browser view client area.
 */
-(NSSize)viewSize
{
	NSSize viewRect = [self frame].size;
	if ([allTabs count] > 1)
		viewRect.height -= MA_Tab_Height;
	return viewRect;
}

/* setPrimaryTabView
 * Sets the primary tab view. This is the view that is always displayed and
 * occupies the first tab position.
 */
-(BrowserTab *)setPrimaryTabView:(NSView *)newPrimaryTab
{
	BrowserTab * newTab = [[BrowserTab alloc] initWithView:newPrimaryTab];
	if (allTabs == nil)
	{
		allTabs = [[NSMutableArray alloc] init];
		[allTabs addObject:newTab];
	}
	else
		[allTabs replaceObjectAtIndex:0 withObject:newTab];
	[self updateTrackingRectangles];
	[self showTab:newTab];
	return newTab;
}

/* activeTab
 * Returns the active tab which is the view currently being displayed.
 */
-(BrowserTab *)activeTab
{
	return activeTab;
}

/* activeTabView
 * Returns the view associated with the active tab.
 */
-(NSView<BaseView> *)activeTabView
{
	return [activeTab associatedView];
}

/* setActiveTabToPrimaryTab
 * Make the primary tab the active tab.
 */
-(void)setActiveTabToPrimaryTab
{
	[self showTab:[allTabs objectAtIndex:0]];
}

/* setActiveTab
 * Switches the active tab. The new active tab must be one already in
 * the browser view's array of tabs.
 */
-(void)setActiveTab:(BrowserTab *)newActiveTab
{
	NSAssert([allTabs indexOfObject:newActiveTab] != NSNotFound, @"Cannot make an active tab without first adding it to the browserview");
	[self showTab:newActiveTab];
}

/* createNewTabWithView
 * Create a new tab with the specified view. If makeKey is YES then the new tab is
 * made active, otherwise the current tab stays active.
 */
-(BrowserTab *)createNewTabWithView:(NSView<BaseView> *)newTabView makeKey:(BOOL)keyIt
{
	if (allTabs == nil)
		allTabs = [[NSMutableArray alloc] init];
	BrowserTab * newTab = [[BrowserTab alloc] initWithView:newTabView];
	[allTabs addObject:newTab];
	[self updateTrackingRectangles];
	if (keyIt)
		[self showTab:newTab];
	else
	{
		// If this new tab is the first new one after the primary view then we
		// need to resize the primary view because the tab bar is now visible.
		NSView<BaseView> * activeView = [activeTab associatedView];
		[activeView setFrameSize:[self viewSize]];
		[self display];
	}
	[newTab release];
	return newTab;
}

/* setTabTitle
 * Sets the title of the specified tab then redraws the tab bar.
 */
-(void)setTabTitle:(BrowserTab *)tab title:(NSString *)newTitle
{
	[tab setTitle:newTitle];
	[self updateTabTextRect:tab];
	[self displayRect:[tab rect]];
}

/* closeAllTabs
 * Close all tabs.
 */
-(void)closeAllTabs
{
	int count = [allTabs count];
	[activeTab retain];
	while ( count > 1)
	{
		BrowserTab * theTab = [allTabs objectAtIndex:--count];
		[self removeTrackingRect:[theTab trackingRectTag]];
		[self removeTrackingRect:[theTab closeButtonTrackingRectTag]];
		[allTabs removeObject:theTab];
	}
	[self updateTrackingRectangles];
	[self makeTabActive:[allTabs objectAtIndex:0]];
	[activeTab release];
}

/* closeTab
 * Close the specified tab unless it is the primary tab, in which case
 * we do nothing.
 */
-(void)closeTab:(BrowserTab *)theTab
{
	int index = [allTabs indexOfObject:theTab];
	if (index != NSNotFound && index > 0)
	{
		[theTab retain];
		[self removeTrackingRect:[theTab trackingRectTag]];
		[self removeTrackingRect:[theTab closeButtonTrackingRectTag]];
		[self removeToolTip:[theTab toolTipTag]];
		[allTabs removeObject:theTab];
		if (trackingTab == theTab)
			trackingTab = nil;
		[self updateTrackingRectangles];
		if (index == [allTabs count])
			--index;
		[self makeTabActive:[allTabs objectAtIndex:index]];
		[theTab release];
	}
}

/* countOfTabs
 * Returns the total number of tabs.
 */
-(int)countOfTabs
{
	return [allTabs count];
}

/* showTab
 * Makes the specified tab active if not already and post a notification.
 */
-(void)showTab:(BrowserTab *)theTab
{
	if (theTab != activeTab)
		[self makeTabActive:theTab];
}

/* makeTabActive
 * Makes the specified tab the active tab
 */
-(void)makeTabActive:(BrowserTab *)theTab
{
	NSView<BaseView> * tabView = [theTab associatedView];
	[tabView setFrameSize:[self viewSize]];
	if (activeTab == nil)
		[self addSubview:tabView];
	else if (theTab != activeTab)
		[self replaceSubview:[activeTab associatedView] with:tabView];
	activeTab = theTab;
	[tabView display];
	[self display];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TabChanged" object:tabView];
}

/* showPreviousTab
 * Switch to the previous tab in the view order. Wrap round to the end
 * if we're at the beginning.
 */
-(void)showPreviousTab
{
	NSAssert([allTabs count] > 0, @"Cannot call showPreviousTab without a primary tab");
	int index = [allTabs indexOfObject:activeTab];
	NSAssert(index != NSNotFound, @"Active tab missing from allTabs array");
	int count = [allTabs count];

	if (index == 0)
		index = count;
	[self showTab:[allTabs objectAtIndex:index - 1]];
}

/* showNextTab
 * Switch to the next tab in the tab order. Wrap round to the beginning
 * if we're at the end.
 */
-(void)showNextTab
{
	NSAssert([allTabs count] > 0, @"Cannot call showNextTab without a primary tab");
	int index = [allTabs indexOfObject:activeTab];
	NSAssert(index != NSNotFound, @"Active tab missing from allTabs array");
	int count = [allTabs count];

	if (++index == count)
		index = 0;
	[self showTab:[allTabs objectAtIndex:index]];
}

/* dealloc
 * Clean up behind ourselves.
 */
-(void)dealloc
{
	[borderColor release];
	[inactiveTabBackgroundColor release];
	[pressedCloseButton release];
	[highlightedCloseButton release];
	[closeButton release];
	[titleAttributes release];
	[allTabs release];
	[super dealloc];
}
@end
