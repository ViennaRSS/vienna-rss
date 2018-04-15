//
//  MMRolloverButtonCell.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/8/12.
//

#import "MMRolloverButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMRolloverButtonCell
{
    MMRolloverButtonType _rolloverButtonType;
}

@dynamic rolloverButtonType;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _rolloverImage = nil;
        _mouseHovered = NO;
        _simulateClickOnMouseHovered = NO;
    }
    return self;
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView {

    if (_mouseHovered && ![self isHighlighted]) {
        if (_rolloverImage) {
            [super drawImage:_rolloverImage withFrame:frame inView:controlView];
            return;
        }
    }

    [super drawImage:image withFrame:frame inView:controlView];
}

#pragma mark -
#pragma mark Accessors

- (MMRolloverButtonType)rolloverButtonType {
    return _rolloverButtonType;
}

- (void)setRolloverButtonType:(MMRolloverButtonType)aType {

    _rolloverButtonType = aType;
    
    switch (_rolloverButtonType) {
        case MMRolloverActionButton:
            [self setButtonType:NSMomentaryChangeButton];
            [self setShowsStateBy:NSNoCellMask];
            [self setHighlightsBy:NSContentsCellMask];
            [self setImageDimsWhenDisabled:YES];
            break;
        case MMRolloverSwitchButton:
            break;
    }
    
    [(NSControl *)[self controlView] updateCell:self];
}

#pragma mark -
#pragma mark Tracking Area Support

- (void)addTrackingAreasForView:(NSView *)controlView inRect:(NSRect)cellFrame withUserInfo:(nullable NSDictionary *)userInfo mouseLocation:(NSPoint)mouseLocation {

    NSTrackingAreaOptions options = 0;
    BOOL mouseIsInside = NO;
    NSTrackingArea *area = nil;

    // ---- add tracking area for hover effect ----
    
    options = NSTrackingEnabledDuringMouseDrag | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways;

    mouseIsInside = [controlView mouse:mouseLocation inRect:cellFrame];
    if (mouseIsInside) {
        options |= NSTrackingAssumeInside;
        _mouseHovered = YES;
    }
    
    // We make the view the owner, and it delegates the calls back to the cell after it is properly setup for the corresponding row/column in the outlineview
    area = [[NSTrackingArea alloc] initWithRect:cellFrame options:options owner:controlView userInfo:userInfo];
    [controlView addTrackingArea:area];
    area = nil;
}

- (void)mouseEntered:(NSEvent *)event {

    if (_simulateClickOnMouseHovered && [event modifierFlags] & NSAlternateKeyMask) {
        [self performClick:self];
        return;
    }

    _mouseHovered = YES;
    [(NSControl *)[self controlView] updateCell:self];
}

- (void)mouseExited:(NSEvent *)event {
    _mouseHovered = NO;
    [(NSControl *)[self controlView] updateCell:self];
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[super encodeWithCoder:aCoder];
	if ([aCoder allowsKeyedCoding]) {
        [aCoder encodeObject:_rolloverImage forKey:@"rolloverImage"];
        [aCoder encodeInteger:_simulateClickOnMouseHovered forKey:@"simulateClickOnMouseHovered"];
        [aCoder encodeInteger:_rolloverButtonType forKey:@"rolloverButtonType"];
        
	}
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		if ([aDecoder allowsKeyedCoding]) {
            _rolloverImage = [aDecoder decodeObjectForKey:@"rolloverImage"];
            _simulateClickOnMouseHovered = [aDecoder decodeIntegerForKey:@"simulateClickOnMouseHovered"];
            _rolloverButtonType = [aDecoder decodeIntegerForKey:@"rolloverButtonType"];
		}
	}
	return self;
}

#pragma mark -
#pragma mark Copying

- (id)copyWithZone:(nullable NSZone *)zone {

    MMRolloverButtonCell *cellCopy = [super copyWithZone:zone];
    if (cellCopy) {
        cellCopy->_rolloverButtonType = _rolloverButtonType;
        cellCopy->_simulateClickOnMouseHovered = _simulateClickOnMouseHovered;
        cellCopy->_rolloverImage = _rolloverImage;
    }
    
    return cellCopy;    
}

@end

NS_ASSUME_NONNULL_END
