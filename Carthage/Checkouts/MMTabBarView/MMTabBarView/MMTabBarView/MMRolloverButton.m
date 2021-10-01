//
//  MMOverflowPopUpButton.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/8/12.
//

#import "MMRolloverButton.h"

#import "MMRolloverButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMRolloverButton

+ (nullable Class)cellClass {
    return MMRolloverButtonCell.class;
}

- (instancetype)initWithFrame:(NSRect)frameRect {

    self = [super initWithFrame:frameRect];
    if (self) {
        self.focusRingType = NSFocusRingTypeNone;
    }
    
    return self;
}


- (void)awakeFromNib {
	if ([self.superclass instancesRespondToSelector:@selector(awakeFromNib)]) {
		[super awakeFromNib];
	}
}

- (nullable MMRolloverButtonCell *)cell {
    return (MMRolloverButtonCell *)super.cell;
}

- (void)setCell:(nullable MMRolloverButtonCell *)aCell {
    [super setCell:aCell];
}

#pragma mark -
#pragma mark Cell Interface

- (nullable NSImage *)rolloverImage {
	return [self.cell rolloverImage];
}

- (void)setRolloverImage:(nullable NSImage *)image {
    [self.cell setRolloverImage:image];
}

- (MMRolloverButtonType)rolloverButtonType {
    return [self.cell rolloverButtonType];
}

- (void)setRolloverButtonType:(MMRolloverButtonType)aType {
    [self.cell setRolloverButtonType:aType];
}

- (BOOL)mouseHovered {
    return [self.cell mouseHovered];
}

- (BOOL)simulateClickOnMouseHovered {
    return [self.cell simulateClickOnMouseHovered];
}

- (void)setSimulateClickOnMouseHovered:(BOOL)flag {
    [self.cell setSimulateClickOnMouseHovered:flag];
}

#pragma mark -
#pragma mark Tracking Area Support

-(void)updateTrackingAreas {

    [super updateTrackingAreas];

    // remove all tracking rects
    for (NSTrackingArea *area in self.trackingAreas) {
        // We have to uniquely identify our own tracking areas
        if (area.owner == self) {
            [self removeTrackingArea:area];
        }
    }
        // force reset of mouse hovered state
	if (self.mouseHovered) {
		NSEvent* const event = NSApp.currentEvent;
		if (event != nil) {
			[self.cell mouseExited:event];
		}
	}

    // recreate tracking areas and tool tip rects
    
    NSPoint mouseLocationInScreenCoos = NSEvent.mouseLocation;
    
    NSPoint mouseLocationInWindowCoos = [self.window convertRectFromScreen:NSMakeRect(mouseLocationInScreenCoos.x, mouseLocationInScreenCoos.y, 0.0, 0.0)].origin;
    
    NSPoint mouseLocation = [self convertPoint:mouseLocationInWindowCoos fromView:nil];
    
    [self.cell addTrackingAreasForView:self inRect:self.bounds withUserInfo:nil mouseLocation:mouseLocation];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [self.cell mouseEntered:theEvent];
}

- (void)mouseExited:(NSEvent *)theEvent {
    [self.cell mouseExited:theEvent];
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[super encodeWithCoder:aCoder];
	if (aCoder.allowsKeyedCoding) {
        // nothing yet
	}
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		if (aDecoder.allowsKeyedCoding) {
            // nothing yet
		}
	}
	return self;
}

@end

NS_ASSUME_NONNULL_END
