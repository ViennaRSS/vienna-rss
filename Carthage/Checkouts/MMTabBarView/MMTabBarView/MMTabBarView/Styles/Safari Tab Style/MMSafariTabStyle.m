//
//  MMSafariTabStyle.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/20/12.
//  Copyright 2011 Marrintech. All rights reserved.
//

#import "MMSafariTabStyle.h"

#import "MMTabBarView.h"
#import "MMAttachedTabBarButton.h"
#import "MMAttachedTabBarButtonCell.h"
#import "NSView+MMTabBarViewExtensions.h"
#import "MMTabBarView.Private.h"
#import "MMTabBarButtonCell.Private.h"
#import "MMOverflowPopUpButton.h"
#import "MMOverflowPopUpButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMSafariTabStyle
{
	NSDictionary<NSAttributedStringKey, id> *_objectCountStringAttributes;
}

StaticImage(SafariAWATClose)
StaticImage(SafariAWATClosePressed)
StaticImage(SafariAWATCloseRollover)
StaticImage(SafariAWITClose)
StaticImage(SafariAWITClosePressed)
StaticImage(SafariAWITCloseRollover)
StaticImage(SafariIWATClose)
StaticImage(SafariIWATClosePressed)
StaticImage(SafariIWATCloseRollover)
StaticImage(SafariIWITClose)
StaticImage(SafariIWITClosePressed)
StaticImage(SafariIWITCloseRollover)
StaticImage(TabClose_Dirty)
StaticImage(TabClose_Dirty_Pressed)
StaticImage(TabClose_Dirty_Rollover)
StaticImage(SafariAWAddTabButton)
StaticImage(SafariAWAddTabButtonPushed)
StaticImage(SafariAWAddTabButtonRolloverPlus)
StaticImage(SafariAWATFill)
StaticImage(SafariAWATLeftCap)
StaticImage(SafariAWATRightCap)
StaticImage(SafariAWBG)
StaticImage(SafariAWITLeftCap)
StaticImage(SafariAWITRightCap)
StaticImage(SafariIWATFill)
StaticImage(SafariIWATLeftCap)
StaticImage(SafariIWATRightCap)
StaticImage(SafariIWBG)
StaticImage(SafariIWITLeftCap)
StaticImage(SafariIWITRightCap)

+ (NSString *)name {
    return @"Safari";
}

- (NSString *)name {
	return self.class.name;
}

#pragma mark -
#pragma mark Creation/Destruction

- (instancetype) init {
	if((self = [super init])) {
		NSFont* const font = [NSFont fontWithName:@"Helvetica" size:11.0];
		NSFont* const styledFont = [NSFontManager.sharedFontManager convertFont:font toHaveTrait:NSBoldFontMask];
		_objectCountStringAttributes = @{
			NSFontAttributeName: styledFont != nil ? styledFont : font,
			NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.85]
		};
	}
	return self;
}

#pragma mark -
#pragma mark Tab View Specific

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView {
	return 6.0;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView {
	return 6.0;
}

- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation forTabBarView:(MMTabBarView *)tabBarView {

    if (orientation != MMTabBarHorizontalOrientation)
        return NO;
    
    return YES;
}

- (NSSize)addTabButtonSizeForTabBarView:(MMTabBarView *)tabBarView {
    return NSMakeSize(22.0,tabBarView.frame.size.height);
}

- (NSRect)addTabButtonRectForTabBarView:(MMTabBarView *)tabBarView {

    NSRect rect = tabBarView._addTabButtonRect;
    
    rect.origin.y += 1.0;
    rect.size.height -= 1.0;
    
    return rect;
}

#pragma mark -
#pragma mark Add Tab Button

-(void)updateAddButton:(MMRolloverButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {

    [aButton setImage:_staticSafariAWAddTabButtonImage()];
    [aButton setAlternateImage:_staticSafariAWAddTabButtonPushedImage()];
    [aButton setRolloverImage:_staticSafariAWAddTabButtonRolloverPlusImage()];
}

#pragma mark -
#pragma mark Drag Support

- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {

	NSRect dragRect = aButton.stackingFrame;
	dragRect.size.width++;

	if(aButton.state == NSOnState) {
		if(tabBarView.orientation == MMTabBarHorizontalOrientation) {
			dragRect.size.height -= 2.0;
		} else {
			dragRect.size.height += 1.0;
			dragRect.origin.y -= 1.0;
			dragRect.origin.x += 2.0;
			dragRect.size.width -= 3.0;
		}
	} else if (tabBarView.orientation == MMTabBarVerticalOrientation) {
		dragRect.origin.x--;
	}

	return dragRect;
}

#pragma mark -
#pragma mark Providing Images

- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell
{
    BOOL activeWindow = cell.controlView.enclosingTabBarView.isWindowActive;
    BOOL activeTab = (cell.state == NSOnState);

    if (activeWindow) {
        switch (type) {
            case MMCloseButtonImageTypeStandard:
                return activeTab?_staticSafariAWATCloseImage():_staticSafariAWITCloseImage();
            case MMCloseButtonImageTypeRollover:
                return activeTab?_staticSafariAWATCloseRolloverImage():_staticSafariAWITCloseRolloverImage();
            case MMCloseButtonImageTypePressed:
                return activeTab?_staticSafariAWATClosePressedImage():_staticSafariAWITClosePressedImage();
                
            case MMCloseButtonImageTypeDirty:
                return _staticTabClose_DirtyImage();
            case MMCloseButtonImageTypeDirtyRollover:
                return _staticTabClose_Dirty_RolloverImage();
            case MMCloseButtonImageTypeDirtyPressed:
                return _staticTabClose_Dirty_PressedImage();
                
            default:
                break;
        }
    } else {
        switch (type) {
            case MMCloseButtonImageTypeStandard:
                return activeTab?_staticSafariIWATCloseImage():_staticSafariIWITCloseImage();
            case MMCloseButtonImageTypeRollover:
                return activeTab?_staticSafariIWATCloseRolloverImage():_staticSafariIWITCloseRolloverImage();
            case MMCloseButtonImageTypePressed:
                return activeTab?_staticSafariIWATClosePressedImage():_staticSafariIWITClosePressedImage();
                
            case MMCloseButtonImageTypeDirty:
                return _staticTabClose_DirtyImage();
            case MMCloseButtonImageTypeDirtyRollover:
                return _staticTabClose_Dirty_RolloverImage();
            case MMCloseButtonImageTypeDirtyPressed:
                return _staticTabClose_Dirty_PressedImage();
                
            default:
                break;
        }
    }
}

#pragma mark -
#pragma mark Determining Cell Size

- (NSRect)drawingRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell
{
    theRect.origin.x += cell._leftMargin;
    theRect.size.width -= cell._leftMargin + cell._rightMargin;
    
    theRect.origin.y += 1;
    theRect.size.height -= 1;
    
    return theRect;

/*
     NSRect rect = NSInsetRect(theRect, 6.0, 0.0);
    rect.origin.y += 1;
    rect.size.height -= 1;
    
    return rect;
*/    
}

- (NSRect)closeButtonRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell {
    
    NSRect rect = [cell _closeButtonRectForBounds:theRect];
    if (NSEqualRects(rect,NSZeroRect))
        return rect;
    
    rect.origin.y += 1;
    rect.size.height -= 1;
    return rect;
}

- (NSRect)overflowButtonRectForTabBarView:(MMTabBarView *)tabBarView {

    NSRect rect = tabBarView._overflowButtonRect;
    if (NSEqualRects(rect,NSZeroRect))
        return rect;
    
    rect.origin.y += 1.0;
    rect.size.height -= 1.0;
    
    return rect;
}

#pragma mark -
#pragma mark Drawing

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

	rect = tabBarView.bounds;
	    
	[NSGraphicsContext saveGraphicsState];

    // special case of hidden control; need line across top of cell
    if (rect.size.height < 2) {
        [NSColor.darkGrayColor set];
        NSRectFillUsingOperation(rect, NSCompositeSourceOver);
    } else {
        NSImage *bg = tabBarView.isWindowActive ? _staticSafariAWBGImage() : _staticSafariIWBGImage();
        NSDrawThreePartImage(rect, nil, bg, nil, NO, NSCompositeCopy, 1, tabBarView.isFlipped);
    }
    
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray<MMAttachedTabBarButton *> *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

    BOOL isWindowActive = tabBarView.isWindowActive;
    NSUInteger numberOfButtons = buttons.count;

    MMAttachedTabBarButton *prevButton = nil,
                           *nextButton = nil;
    
    if (index > 0)
        prevButton = buttons[index-1];
    if (index+1 < numberOfButtons)
        nextButton = buttons[index+1];

    NSImage *left = nil,
            *center = nil,
            *right = nil;
    NSRect buttonFrame = button.frame;

    buttonFrame = NSInsetRect(buttonFrame,-5.0,0);
        
        // standard drawing while animated slide is going on
    if (button.isInAnimatedSlide == YES) {
        
        left = _staticSafariAWITLeftCapImage();
        right = _staticSafariAWITRightCapImage();
        
        // draw selected button
    } else if (button.state == NSOnState) {
    
        if (tabBarView.isWindowActive) {
            left = _staticSafariAWATLeftCapImage();
            center = _staticSafariAWATFillImage();
            if (!button.isOverflowButton || button.isSliding)
                right = _staticSafariAWATRightCapImage();
        } else {
            left = _staticSafariIWATLeftCapImage();
            center = _staticSafariIWATFillImage();
            if (!button.isOverflowButton || button.isSliding)
                right = _staticSafariIWATRightCapImage();
        }        
    
        // draw first button
    } else if (prevButton == nil) {
    
        if (selIndex == NSNotFound || index < selIndex) {
            if (nextButton.isSliding || tabBarView.destinationIndexForDraggedItem == index+1)
                right = isWindowActive?_staticSafariAWITRightCapImage():_staticSafariIWITRightCapImage();
        }
        // draw last button
    } else if (nextButton == nil) {

        if (selIndex == NSNotFound || index > selIndex) {
            if (selIndex == NSNotFound || prevButton.isSliding || tabBarView.destinationIndexForDraggedItem+1 == index)
                left = isWindowActive?_staticSafariAWITLeftCapImage():_staticSafariIWITLeftCapImage();
        }
        
        if (tabBarView.showAddTabButton && !tabBarView.isOverflowButtonVisible)
            right = isWindowActive?_staticSafariAWITRightCapImage():_staticSafariIWITRightCapImage();
    
        // draw mid button
    } else {
    
        if (selIndex == NSNotFound || index < selIndex) {
            left = isWindowActive?_staticSafariAWITLeftCapImage():_staticSafariIWITLeftCapImage();
            if (nextButton.isSliding || tabBarView.destinationIndexForDraggedItem == index+1)
                right = isWindowActive?_staticSafariAWITRightCapImage():_staticSafariIWITRightCapImage();
        } else if (index > selIndex) {
            if (prevButton.isSliding)
                left = isWindowActive?_staticSafariAWITLeftCapImage():_staticSafariIWITLeftCapImage();
            right = isWindowActive?_staticSafariAWITRightCapImage():_staticSafariIWITRightCapImage();
        }
    }

    if (center != nil || left != nil || right != nil)
        NSDrawThreePartImage(buttonFrame, left, center, right, NO, NSCompositeSourceOver, 1.0, tabBarView.isFlipped);
}

-(void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {
    BOOL isWindowActive = tabBarView.isWindowActive;

    NSImage *left = nil,
            *right = nil,
            *center = nil;
        
    NSRect bezelRect = overflowButton.frame;
    bezelRect.origin.y -= 1.0;
    bezelRect.size.height += 1.0;
    bezelRect.size.width += 11.0;
    
    MMAttachedTabBarButton *lastAttachedButton = tabBarView.lastAttachedButton;
    
    BOOL displaySelected = lastAttachedButton.state == NSOnState;
    if (lastAttachedButton.isSliding)
        displaySelected = NO;
    
    if (displaySelected) {
        center = isWindowActive?_staticSafariAWATFillImage():_staticSafariIWATFillImage();
        right = isWindowActive?_staticSafariAWATRightCapImage():_staticSafariIWATRightCapImage();
        
    } else {
        right = isWindowActive?_staticSafariAWITRightCapImage():_staticSafariIWITRightCapImage();
    }
    NSDrawThreePartImage(bezelRect, left, center, right, NO, NSCompositeSourceOver, 1.0, tabBarView.isFlipped);
}

-(void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {

	if (@available(macos 10.14, *)) {
		return;
	}
    if (cell.controlView.frame.size.height < 2)
        return;

    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;
        
    NSRect cellFrame = frame;
    
    cellFrame = NSInsetRect(cellFrame, -5.0, 0);

    NSImage *left = nil;
    NSImage *center = nil;
    NSImage *right = nil;

    if (tabBarView.isWindowActive) {
        if (cell.state == NSOnState) {
            left = _staticSafariAWATLeftCapImage();
            center = _staticSafariAWATFillImage();
            if (![(MMAttachedTabBarButtonCell *)cell isOverflowButton] || button.isSliding)
                right = _staticSafariAWATRightCapImage();
        }
    } else {
    
        if (cell.state == NSOnState) {
            left = _staticSafariIWATLeftCapImage();
            center = _staticSafariIWATFillImage();
            if (![(MMAttachedTabBarButtonCell *)cell isOverflowButton] || button.isSliding)
                right = _staticSafariIWATRightCapImage();
        }
    }

    if (center != nil || left != nil || right != nil)
        NSDrawThreePartImage(cellFrame, left, center, right, NO, NSCompositeSourceOver, 1, controlView.isFlipped);
}

@end

NS_ASSUME_NONNULL_END
