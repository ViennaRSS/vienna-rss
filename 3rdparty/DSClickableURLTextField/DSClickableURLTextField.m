/*
	DSClickableURLTextField
	
	Copyright (c) 2006 - 2007 Night Productions, by Darkshadow. All Rights Reserved.
	http://www.nightproductions.net/developer.htm
	darkshadow@nightproductions.net
	
	May be used freely, but keep my name/copyright in the header.
	
	There is NO warranty of any kind, express or implied; use at your own risk.
	Responsibility for damages (if any) to anyone resulting from the use of this
	code rests entirely with the user.
	
	------------------------------------
	
	* August 25, 2006 - initial release
	* August 30, 2006
		• Fixed a bug where cursor rects would be enabled even if the
		  textfield wasn't visible.  i.e. it's in a scrollview, but the
		  textfield isn't scrolled to where it's visible.
		• Fixed an issue where mouseUp wouldn't be called and so clicking
		  on the URL would have no effect when the textfield is a subview
		  of a splitview (and maybe some other certain views).  I did this
		  by NOT calling super in -mouseDown:.  Since the textfield is
		  non-editable and non-selectable, I don't believe this will cause
		  any problems.
		• Fixed the fact that it was using the textfield's bounds rather than
		  the cell's bounds to calculate rects.
	* May 25, 2007
		Contributed by Jens Miltner:
			• Fixed a problem with the text storage and the text field's
			  attributed string value having different lengths, causing
			  range exceptions.
			• Added a delegate method allowing custom handling of URLs.
			• Tracks initially clicked URL at -mouseDown: to avoid situations
			  where dragging would end up in a different URL at -mouseUp:, opening
			  that URL. This includes situations where the user clicks on an empty
			  area of the text field, drags the mouse, and ends up on top of a
			  link, which would then erroneously open that link.
			• Fixed to allow string links to work as well as URL links.
		Changes by Darkshadow:
			• Overrode -initWithCoder:, -initWithFrame:, and -awakeFromNib to
			  explicitly set the text field to be non-editable and
			  non-selectable.  Now you don't need to remember to set this up,
			  and the class will work correctly regardless.
			• Added in the ability for the user to copy URLs to the clipboard.
			  Note that this is off by default.
			• Some code clean up.
*/

#import "DSClickableURLTextField.h"


@implementation DSClickableURLTextField

/* Set the text field to be non-editable and
	non-selectable. */
- (id)initWithCoder:(NSCoder *)coder
{
	if ( (self = [super initWithCoder:coder]) ) {
		[self setEditable:NO];
		[self setSelectable:NO];
		canCopyURLs = NO;
	}
	
	return self;
}

/* Set the text field to be non-editable and
	non-selectable. */
- (id)initWithFrame:(NSRect)frameRect
{
	if ( (self = [super initWithFrame:frameRect]) ) {
		[self setEditable:NO];
		[self setSelectable:NO];
		canCopyURLs = NO;
	}
	
	return self;
}

- (void)dealloc
{
	[clickedURL release];
	[URLStorage release];
	
	[super dealloc];
}

/* Enforces that the text field be non-editable and
	non-selectable. Probably not needed, but I always
	like to be cautious.
*/
- (void)awakeFromNib
{
	[self setEditable:NO];
	[self setSelectable:NO];
}

- (void)setAttributedStringValue:(NSAttributedString *)aStr
{
	[URLStorage setAttributedString:aStr];
	[[self window] invalidateCursorRectsForView:self];
	[super setAttributedStringValue:aStr];
}

- (void)setStringValue:(NSString *)aStr
{
	NSAttributedString *attrString = [[[NSAttributedString alloc] initWithString:aStr attributes:nil] autorelease];
	[self setAttributedStringValue:attrString];
}

- (void)setCanCopyURLs:(BOOL)aFlag
{
	canCopyURLs = aFlag;
}

- (BOOL)canCopyURLs
{
	return canCopyURLs;
}

- (void)resetCursorRects
{
	if ( [[self attributedStringValue] length] == 0 ) {
		[super resetCursorRects];
		return;
	}
	
	NSRect cellBounds = [[self cell] drawingRectForBounds:[self bounds]];

	if ( URLStorage == nil ) {
		BOOL cellWraps = ![[self cell] isScrollable];
		NSSize containerSize = NSMakeSize( cellWraps ? cellBounds.size.width : MAXFLOAT, cellWraps ? MAXFLOAT : cellBounds.size.height );
		URLContainer = [[[NSTextContainer alloc] initWithContainerSize:containerSize] autorelease];
		URLManager = [[[NSLayoutManager alloc] init] autorelease];
		URLStorage = [[NSTextStorage alloc] init];
		
		[URLStorage addLayoutManager:URLManager];
		[URLManager addTextContainer:URLContainer];
		[URLContainer setLineFragmentPadding:2.f];
		
		[URLStorage setAttributedString:[self attributedStringValue]];
	}
	
	NSUInteger myLength = [URLStorage length];
	NSRange returnRange = { NSNotFound, 0 }, stringRange = { 0, myLength }, glyphRange = { NSNotFound, 0 };
	NSCursor *pointingCursor = nil;
	
	/* Here mainly for 10.2 compatibility (in case anyone even tries for that anymore) */
	if ( [NSCursor respondsToSelector:@selector(pointingHandCursor)] ) {
		pointingCursor = [NSCursor performSelector:@selector(pointingHandCursor)];
	} else {
		[super resetCursorRects];
		return;
	}
	
	/* Moved out of the while and for loops as there's no need to recalculate
	   it every time through */
	NSRect superVisRect = [self convertRect:[[self superview] visibleRect] fromView:[self superview]];

	while ( stringRange.location < myLength ) {
		id aVal = [URLStorage attribute:NSLinkAttributeName atIndex:stringRange.location longestEffectiveRange:&returnRange inRange:stringRange];
		
		if ( aVal != nil ) {
			NSRectArray aRectArray = NULL;
			NSUInteger numRects = 0, j = 0;
			glyphRange = [URLManager glyphRangeForCharacterRange:returnRange actualCharacterRange:nil];
			aRectArray = [URLManager rectArrayForGlyphRange:glyphRange withinSelectedGlyphRange:glyphRange inTextContainer:URLContainer rectCount:&numRects];
			for ( j = 0; j < numRects; j++ ) {
				/* Check to make sure the rect is visible before setting the cursor */
				NSRect glyphRect = aRectArray[j];
				glyphRect.origin.x += cellBounds.origin.x;
				glyphRect.origin.y += cellBounds.origin.y;
				NSRect textRect = NSIntersectionRect(glyphRect, cellBounds);
				NSRect cursorRect = NSIntersectionRect(textRect, superVisRect);
				if ( NSIntersectsRect( textRect, superVisRect ) )
					[self addCursorRect:cursorRect cursor:pointingCursor];
			}
		}
		stringRange.location = NSMaxRange(returnRange);
		stringRange.length = myLength - stringRange.location;
	}
}

- (NSURL*)urlAtMouse:(NSEvent *)mouseEvent
{
	NSURL*	urlAtMouse = nil;
	NSPoint mousePoint = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
	NSRect cellBounds = [[self cell] drawingRectForBounds:[self bounds]];
	
	if ( ([URLStorage length] > 0 ) && [self mouse:mousePoint inRect:cellBounds] ) {
		id aVal = nil;
		NSRange returnRange = { NSNotFound, 0 }, glyphRange = { NSNotFound, 0 };
		NSRectArray linkRect = NULL;
		NSUInteger glyphIndex = [URLManager glyphIndexForPoint:mousePoint inTextContainer:URLContainer];
		NSUInteger charIndex = [URLManager characterIndexForGlyphAtIndex:glyphIndex];
		NSUInteger numRects = 0, j = 0;
		
		aVal = [URLStorage attribute:NSLinkAttributeName atIndex:charIndex longestEffectiveRange:&returnRange inRange:NSMakeRange(charIndex, [URLStorage length] - charIndex)];
		if ( (aVal != nil) ) {
			glyphRange = [URLManager glyphRangeForCharacterRange:returnRange actualCharacterRange:nil];
			linkRect = [URLManager rectArrayForGlyphRange:glyphRange withinSelectedGlyphRange:glyphRange inTextContainer:URLContainer rectCount:&numRects];
			for ( j = 0; j < numRects; j++ ) {
				NSRect testHit = linkRect[j];
				testHit.origin.x += cellBounds.origin.x;
				testHit.origin.x += cellBounds.origin.y;
				if ( [self mouse:mousePoint inRect:NSIntersectionRect(testHit, cellBounds)] ) {
					// be smart about links stored as strings
					if ( [aVal isKindOfClass:[NSString class]] )
						aVal = [NSURL URLWithString:aVal];
					urlAtMouse = aVal;
					break;
				}
			}
		}
	}
	return urlAtMouse;
}

- (NSMenu *)menuForEvent:(NSEvent *)aEvent
{
	if ( !canCopyURLs )
		return nil;
	
	NSURL *anURL = [self urlAtMouse:aEvent];
	
	if ( anURL != nil ) {
		NSMenu *aMenu = [[[NSMenu alloc] initWithTitle:@"Copy URL"] autorelease];
		NSMenuItem *anItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy URL", @"Copy URL") action:@selector(copyURL:) keyEquivalent:@""] autorelease];
		[anItem setTarget:self];
		[anItem setRepresentedObject:anURL];
		[aMenu addItem:anItem];
		
		return aMenu;
	}
	
	return nil;
}

- (void)copyURL:(id)sender
{
	NSPasteboard *copyBoard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	NSURL *copyURL = [sender representedObject];
	
	[copyBoard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, nil] owner:nil];
	[copyURL writeToPasteboard:copyBoard];
	[copyBoard setString:[copyURL absoluteString] forType:NSStringPboardType];
}

- (void)mouseDown:(NSEvent *)mouseEvent
{
	/* Not calling [super mouseDown:] because there are some situations where
		the mouse tracking is ignored otherwise. */
	
	/* Remember which URL was clicked originally, so we don't end up opening
		the wrong URL accidentally.
	*/
	[clickedURL release];
	clickedURL = [[self urlAtMouse:mouseEvent] retain];
}

- (void)mouseUp:(NSEvent *)mouseEvent
{
	NSURL* urlAtMouse = [self urlAtMouse:mouseEvent];
	if ( (urlAtMouse != nil)  &&  [urlAtMouse isEqualTo:clickedURL] ) {
		// check if delegate wants to open the URL itself, if not, let the workspace open the URL
		if ( ([self delegate] == nil)  || ![[self delegate] respondsToSelector:@selector(textField:openURL:)] || ![(id)[self delegate] textField:self openURL:urlAtMouse] )
			[[NSWorkspace sharedWorkspace] openURL:urlAtMouse];
	}
	[clickedURL release];
	clickedURL = nil;
	[super mouseUp:mouseEvent];
}

@end
