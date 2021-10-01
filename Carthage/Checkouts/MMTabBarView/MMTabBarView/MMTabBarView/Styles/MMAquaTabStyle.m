//
//  MMAquaTabStyle.m
//  MMTabBarView
//
//  Created by John Pannell on 2/17/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

#import "MMAquaTabStyle.h"
#import "MMAttachedTabBarButton.h"
#import "MMAttachedTabBarButtonCell.h"
#import "MMTabBarView.h"
#import "MMTabBarButtonCell.h"
#import "MMOverflowPopUpButton.h"
#import "NSView+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMAquaTabStyle
{
	NSImage									*aquaTabBg;
	NSImage									*aquaTabBgDown;
	NSImage									*aquaTabBgDownGraphite;
	NSImage									*aquaTabBgDownNonKey;
	NSImage									*aquaDividerDown;
	NSImage									*aquaDivider;
	NSImage									*aquaCloseButton;
	NSImage									*aquaCloseButtonDown;
	NSImage									*aquaCloseButtonOver;
	NSImage									*aquaCloseDirtyButton;
	NSImage									*aquaCloseDirtyButtonDown;
	NSImage									*aquaCloseDirtyButtonOver;
}

+ (NSString *)name {
    return @"Aqua";
}

- (NSString *)name {
	return self.class.name;
}

#pragma mark -
#pragma mark Creation/Destruction

- (instancetype) init {
	if ((self = [super init])) {
		[self _loadImages];
	}
	return self;
}

#pragma mark -
#pragma mark Tab View Specifics

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView {
	return 0.0;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView {
	return 0.0;
}

- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView {
	return 0.0;
}

#pragma mark -
#pragma mark Providing Images

- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell
{
    switch (type) {
        case MMCloseButtonImageTypeStandard:
            return aquaCloseButton;
        case MMCloseButtonImageTypeRollover:
            return aquaCloseButtonOver;
        case MMCloseButtonImageTypePressed:
            return aquaCloseButtonDown;
            
        case MMCloseButtonImageTypeDirty:
            return aquaCloseDirtyButton;
        case MMCloseButtonImageTypeDirtyRollover:
            return aquaCloseDirtyButtonOver;
        case MMCloseButtonImageTypeDirtyPressed:
            return aquaCloseDirtyButtonDown;
            
        default:
            break;
    }
}

#pragma mark -
#pragma mark Drawing

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {
	if (rect.size.height <= 22.0) {
		//Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
		rect = tabBarView.bounds;

		[aquaTabBg drawInRect:rect fromRect:NSMakeRect(0.0, 0.0, 1.0, 22.0) operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
	}
}

- (void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {

    MMTabBarView *tabBarView = controlView.enclosingTabBarView;
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;
    
	NSRect cellFrame = frame;
    
    NSImage *left = nil;
    NSImage *right = nil;
    NSImage *center = nil;
    
	// Selected Tab
	if (cell.state == NSOnState) {
		NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
        
		// proper tint
		NSControlTint currentTint;
		if (cell.controlTint == NSDefaultControlTint) {
			currentTint = NSColor.currentControlTint;
		} else{
			currentTint = cell.controlTint;
		}

		if (!tabBarView.isWindowActive) {
			currentTint = NSClearControlTint;
		}

		switch(currentTint) {
            case NSGraphiteControlTint:
                center = aquaTabBgDownGraphite;
                break;
            case NSClearControlTint:
                center = aquaTabBgDownNonKey;
                break;
			case NSDefaultControlTint:
            case NSBlueControlTint:
            default:
                center = aquaTabBgDown;
                break;
        }

        if (button.shouldDisplayRightDivider) {
            right = aquaDivider;
        }
        
        if (button.shouldDisplayLeftDivider) {
            left = aquaDivider;
        }

        NSDrawThreePartImage(aRect, left, center, right, NO, NSCompositeSourceOver, 1.0,controlView.isFlipped);

	} else { // Unselected Tab
		NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
        
		// Rollover
		if (cell.mouseHovered) {
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
			NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
		}
        
        if (button.shouldDisplayRightDivider)
            right = aquaDivider;
        if (button.shouldDisplayLeftDivider)
            left = aquaDivider;
        
        if (!button.isOverflowButton) {
            NSDrawThreePartImage(aRect, left, center, right, NO, NSCompositeSourceOver, 1.0,controlView.isFlipped);
        }
	}
}

- (void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

    MMAttachedTabBarButton *lastAttachedButton = tabBarView.lastAttachedButton;
    MMAttachedTabBarButtonCell *lastAttachedButtonCell = lastAttachedButton.cell;

    if (lastAttachedButton.isSliding)
        return;
    
	NSRect cellFrame = overflowButton.frame;
        
    NSImage *left = nil;
    NSImage *right = nil;
    NSImage *center = nil;
    
        // Draw selected
	if (lastAttachedButtonCell.state == NSOnState) {
		NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
        aRect.size.width += 5.0;
        
            // proper tint
		NSControlTint currentTint;
		if (lastAttachedButtonCell.controlTint == NSDefaultControlTint) {
			currentTint = NSColor.currentControlTint;
		} else{
			currentTint = lastAttachedButtonCell.controlTint;
		}

		if (!tabBarView.isWindowActive) {
			currentTint = NSClearControlTint;
		}

		switch(currentTint) {
            case NSGraphiteControlTint:
                center = aquaTabBgDownGraphite;
                break;
            case NSClearControlTint:
                center = aquaTabBgDownNonKey;
                break;
			case NSDefaultControlTint:
            case NSBlueControlTint:
            default:
                center = aquaTabBgDown;
                break;
        }

        if (tabBarView.showAddTabButton) {
            right = aquaDivider;
        }
        
        NSDrawThreePartImage(aRect, left, center, right, NO, NSCompositeSourceOver, 1.0,tabBarView.isFlipped);

        // Draw unselected
	} else {
		NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
        aRect.size.width += 5.0;
        
            // Rollover
		if (lastAttachedButton.mouseHovered) {
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
			NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
		}
        
        if (tabBarView.showAddTabButton)
            right = aquaDivider;
        
        NSDrawThreePartImage(aRect, left, center, right, NO, NSCompositeSourceOver, 1.0,tabBarView.isFlipped);
	}
}

#pragma mark -
#pragma mark Private Methods

- (void)_loadImages {
	// Aqua Tabs Images
	aquaTabBg = [MMTabBarView.bundle imageForResource:@"AquaTabsBackground"];

	aquaTabBgDown = [MMTabBarView.bundle imageForResource:@"AquaTabsDown"];

	aquaTabBgDownGraphite = [MMTabBarView.bundle imageForResource:@"AquaTabsDownGraphite"];

	aquaTabBgDownNonKey = [MMTabBarView.bundle imageForResource:@"AquaTabsDownNonKey"];

	aquaDividerDown = [MMTabBarView.bundle imageForResource:@"AquaTabsSeparatorDown"];

	aquaDivider = [MMTabBarView.bundle imageForResource:@"AquaTabsSeparator"];

	aquaCloseButton = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front"];
	aquaCloseButtonDown = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front_Pressed"];
	aquaCloseButtonOver = [MMTabBarView.bundle imageForResource:@"AquaTabClose_Front_Rollover"];

	aquaCloseDirtyButton = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front"];
	aquaCloseDirtyButtonDown = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front_Pressed"];
	aquaCloseDirtyButtonOver = [MMTabBarView.bundle imageForResource:@"AquaTabCloseDirty_Front_Rollover"];
}

@end

NS_ASSUME_NONNULL_END
