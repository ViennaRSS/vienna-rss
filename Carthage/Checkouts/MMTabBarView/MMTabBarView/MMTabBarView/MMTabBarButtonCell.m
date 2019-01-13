//
//  MMTabBarButtonCell.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/5/12.
//
//

#import "MMTabBarButtonCell.h"

#import "MMTabBarButton.h"
#import "MMTabBarView.h"
#import "MMTabStyle.h"
#import "NSView+MMTabBarViewExtensions.h"
#import "NSCell+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMTabBarButtonCell ()
@end

@implementation MMTabBarButtonCell
{
    id <MMTabStyle> _style;
    BOOL            _isProcessing;
    BOOL            _isEdited;
    BOOL            _hasCloseButton;
    BOOL            _suppressCloseButton;
    BOOL            _closeButtonOver;
}

+ (NSColor *)defaultObjectCountColor {
    return [NSColor colorWithCalibratedWhite:0.3 alpha:0.45];
}

- (instancetype)init {
	if ((self = [super init])) {
    
        _style = nil;
        _isProcessing = NO;
		_objectCount = 0;
        _icon = nil;
        _largeImage = nil;
        _showObjectCount = NO;
		_objectCountColor = [NSColor colorWithCalibratedWhite:0.3 alpha:0.45];
		_isEdited = NO;
        _tabState = 0;
        
		_hasCloseButton = YES;
		_suppressCloseButton = NO;
		_closeButtonOver = NO;
	}
	return self;
}

- (MMTabBarButton *)controlView {
    return (MMTabBarButton *)[super controlView];
}

- (void)setControlView:(MMTabBarButton *)aView {
    [super setControlView:aView];
}

- (MMTabBarView *)tabBarView {
    return self.controlView.tabBarView;
}

- (void)calcDrawInfo:(NSRect)aRect {

    [super calcDrawInfo:aRect];
    
        // update control's sub buttons (position and images)
    [self _updateSubButtons];
}

- (void)updateImages {
    [self _updateCloseButtonImages];
}

#pragma mark -
#pragma mark Accessors

- (id <MMTabStyle>)style {

    @synchronized(self) {
        return _style;
    }
}

- (void)setStyle:(id<MMTabStyle>)style {

    @synchronized (self) {
    
        _style = nil;
        _style = style;
                
        [self _updateSubButtons];
    }
}

- (BOOL)hasCloseButton {

    @synchronized(self) {
        return _hasCloseButton;
    }
}

- (void)setHasCloseButton:(BOOL)newState {

    @synchronized (self) {
    
        if (newState != _hasCloseButton) {
            _hasCloseButton = newState;
        
        [self _updateCloseButton];
        }
    }
}

- (BOOL)suppressCloseButton {

    @synchronized(self) {
        return _suppressCloseButton;
    }
}

- (void)setSuppressCloseButton:(BOOL)newState {

    @synchronized (self) {
    
        if (newState != _suppressCloseButton) {
            _suppressCloseButton = newState;
        
            [self _updateCloseButton];           
        }
    }
}

- (BOOL)isProcessing {

    @synchronized(self) {
        return _isProcessing;
    }
}

- (void)setIsProcessing:(BOOL)newState {

    @synchronized (self) {
    
        if (newState != _isProcessing) {
            _isProcessing = newState;
        
        [self _updateIndicator];
        }
    }
}

- (BOOL)isEdited {

    @synchronized(self) {
        return _isEdited;
    }
}

- (void)setIsEdited:(BOOL)newState {

    @synchronized(self) {
    
        if (newState != _isEdited) {
            _isEdited = newState;
            [self _updateCloseButton];
        }
    }
}

- (void)setState:(NSInteger)value {

    [super setState:value];
    
    [self _updateSubButtons];
}

#pragma mark -
#pragma mark Progress Indicator Support

- (MMProgressIndicator *)indicator {
    return self.controlView.indicator;
}

#pragma mark -
#pragma mark Close Button Support

- (MMRolloverButton *)closeButton {
    return self.controlView.closeButton;
}

- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type {

    id <MMTabStyle> tabStyle = self.style;
    
    if ([tabStyle respondsToSelector:@selector(closeButtonImageOfType:forTabCell:)]) {
        return [tabStyle closeButtonImageOfType:type forTabCell:self];
    // use standard image
    } else {
        return [self _closeButtonImageOfType:type];
    }
    
}

- (BOOL)shouldDisplayCloseButton {
    return self.hasCloseButton && !self.suppressCloseButton;
}

#pragma mark -
#pragma mark Cell Values

- (NSAttributedString *)attributedStringValue {
    MMTabBarView *tabBarView = self.tabBarView;
    id <MMTabStyle> tabStyle = tabBarView.style;

    if ([tabStyle respondsToSelector:@selector(attributedStringValueForTabCell:)])
        return [tabStyle attributedStringValueForTabCell:self];
    else
        return self._attributedStringValue;
}

- (NSAttributedString *)attributedObjectCountStringValue {
    MMTabBarView *tabBarView = self.tabBarView;
    id <MMTabStyle> tabStyle = tabBarView.style;

    if ([tabStyle respondsToSelector:@selector(attributedObjectCountStringValueForTabCell:)])
        return [tabStyle attributedObjectCountStringValueForTabCell:self];
    else
        return self._attributedObjectCountStringValue;
}

#pragma mark -
#pragma mark Determining Cell Size

- (NSRect)drawingRectForBounds:(NSRect)theRect {
    id <MMTabStyle> tabStyle = self.style;
    if ([tabStyle respondsToSelector:@selector(drawingRectForBounds:ofTabCell:)])
        return [tabStyle drawingRectForBounds:theRect ofTabCell:self];
    else
        return [self _drawingRectForBounds:theRect];
}

- (NSRect)titleRectForBounds:(NSRect)theRect {

    id <MMTabStyle> tabStyle = self.style;
    if ([tabStyle respondsToSelector:@selector(titleRectForBounds:ofTabCell:)])
        return [tabStyle titleRectForBounds:theRect ofTabCell:self];
    else {
        return [self _titleRectForBounds:theRect];
    }
}

- (NSRect)iconRectForBounds:(NSRect)theRect {

    id <MMTabStyle> tabStyle = self.style;
    if ([tabStyle respondsToSelector:@selector(iconRectForBounds:ofTabCell:)]) {
        return [tabStyle iconRectForBounds:theRect ofTabCell:self];
    } else {
        return [self _iconRectForBounds:theRect];
    }
}

- (NSRect)largeImageRectForBounds:(NSRect)theRect {

    MMTabBarView *tabBarView = self.tabBarView;
    
    // support for large images for horizontal orientation only
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        return NSZeroRect;

    id <MMTabStyle> tabStyle = self.style;
    if ([tabStyle respondsToSelector:@selector(largeImageRectForBounds:ofTabCell:)]) {
        return [tabStyle largeImageRectForBounds:theRect ofTabCell:self];
    } else {
        return [self _largeImageRectForBounds:theRect];
    }
}

- (NSRect)indicatorRectForBounds:(NSRect)theRect {

    id <MMTabStyle> tabStyle = self.style;
    if ([tabStyle respondsToSelector:@selector(indicatorRectForBounds:ofTabCell:)])
        return [tabStyle indicatorRectForBounds:theRect ofTabCell:self];
    else {
        return [self _indicatorRectForBounds:theRect];
    }
}

- (NSSize)objectCounterSize
{
    MMTabBarView *tabBarView = self.tabBarView;
    id <MMTabStyle> tabStyle = tabBarView.style;

    if ([tabStyle respondsToSelector:@selector(objectCounterSizeOfTabCell:)]) {
        return [tabStyle objectCounterSizeOfTabCell:self];
    } else {
        return self._objectCounterSize;
    }
    
}

- (NSRect)objectCounterRectForBounds:(NSRect)theRect {

    id <MMTabStyle> tabStyle = self.style;
    if ([tabStyle respondsToSelector:@selector(objectCounterRectForBounds:ofTabCell:)]) {
        return [tabStyle objectCounterRectForBounds:theRect ofTabCell:self];
    } else {
    	return [self _objectCounterRectForBounds:theRect];
    }
}

- (NSSize)closeButtonSizeForBounds:(NSRect)theRect {

    id <MMTabStyle> tabStyle = self.style;
    
    // ask style for rect if available
    if ([tabStyle respondsToSelector:@selector(closeButtonSizeForBounds:ofTabCell:)]) {
        return [tabStyle closeButtonSizeForBounds:theRect ofTabCell:self];
    // default handling
    } else {
        return [self _closeButtonSizeForBounds:theRect];
    }
}

- (NSRect)closeButtonRectForBounds:(NSRect)theRect {
    
    id <MMTabStyle> tabStyle = self.style;
    
    // ask style for rect if available
    if ([tabStyle respondsToSelector:@selector(closeButtonRectForBounds:ofTabCell:)]) {
        return [tabStyle closeButtonRectForBounds:theRect ofTabCell:self];
    // default handling
    } else {
        return [self _closeButtonRectForBounds:theRect];
    }
}

- (MMRolloverButton *)closeButtonForBounds:(NSRect)theRect {

    id <MMTabStyle> tabStyle = [self style];

    // ask style for a button if available
    if ([tabStyle respondsToSelector:@selector(closeButtonForBounds:ofTabCell:)]) {
        return [tabStyle closeButtonForBounds:theRect ofTabCell:self];
        // default handling
    } else {
        return [self _closeButtonForBounds:theRect];
    }
}

- (CGFloat)minimumWidthOfCell {

    id <MMTabStyle> style = self.style;
    if ([style respondsToSelector:@selector(minimumWidthOfTabCell:)]) {
        return [style minimumWidthOfTabCell:self];
    } else {
        return self._minimumWidthOfCell;
    }
}

- (CGFloat)desiredWidthOfCell {

    id <MMTabStyle> style = self.style;
    if ([style respondsToSelector:@selector(desiredWidthOfTabCell:)]) {
        return [style desiredWidthOfTabCell:self];
    } else {    
        return self._desiredWidthOfCell;
    }
}

#pragma mark -
#pragma mark Drawing

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {

    id <MMTabStyle> style = self.style;
    if ([style respondsToSelector:@selector(drawTabBarCell:withFrame:inView:)]) {
        [style drawTabBarCell:self withFrame:cellFrame inView:controlView];
    } else {
        [self _drawWithFrame:cellFrame inView:controlView];
    }
}

- (void)drawBezelWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {

    id <MMTabStyle> style = self.style;
        
    // draw bezel
    if ([style respondsToSelector:@selector(drawBezelOfTabCell:withFrame:inView:)]) {
        [style drawBezelOfTabCell:self withFrame:cellFrame inView:controlView];
    } else {
        [self _drawBezelWithFrame:cellFrame inView:controlView];
    }
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    id <MMTabStyle> style = self.style;
    
    if ([style respondsToSelector:@selector(drawInteriorOfTabCell:withFrame:inView:)]) {
        [style drawInteriorOfTabCell:self withFrame:cellFrame inView:controlView];
    } else {
        [self _drawInteriorWithFrame:cellFrame inView:controlView];
    }
    
}

- (void)drawLargeImageWithFrame:(NSRect)frame inView:(NSView *)controlView {
    
    id <MMTabStyle> style = self.style;
    if ([style respondsToSelector:@selector(drawLargeImageOfTabCell:withFrame:inView:)]) {
        [style drawLargeImageOfTabCell:self withFrame:frame inView:controlView];
    } else {
        [self _drawLargeImageWithFrame:frame inView:controlView];
    }
    
}

- (void)drawIconWithFrame:(NSRect)frame inView:(NSView *)controlView {

    id <MMTabStyle> style = self.style;
    if ([style respondsToSelector:@selector(drawIconOfTabCell:withFrame:inView:)]) {
        [style drawIconOfTabCell:self withFrame:frame inView:controlView];
    } else {
        [self _drawIconWithFrame:frame inView:controlView];
    }
    
}

- (void)drawTitleWithFrame:(NSRect)frame inView:(NSView *)controlView {

    id <MMTabStyle> style = self.style;
    if ([style respondsToSelector:@selector(drawTitleOfTabCell:withFrame:inView:)]) {
        [style drawTitleOfTabCell:self withFrame:frame inView:controlView];
    } else {
        [self _drawTitleWithFrame:frame inView:controlView];
    }
}

- (void)drawObjectCounterWithFrame:(NSRect)frame inView:(NSView *)controlView {

    id <MMTabStyle> style = self.style;
    if ([style respondsToSelector:@selector(drawObjectCounterOfTabCell:withFrame:inView:)]) {
        [style drawObjectCounterOfTabCell:self withFrame:frame inView:controlView];
    } else {
        [self _drawObjectCounterWithFrame:frame inView:controlView];
    }
}

- (void)drawIndicatorWithFrame:(NSRect)frame inView:(NSView *)controlView {

    id <MMTabStyle> style = self.style;
    if ([style respondsToSelector:@selector(drawIndicatorOfTabCell:withFrame:inView:)]) {
        [style drawIndicatorOfTabCell:self withFrame:frame inView:controlView];
    } else {
        [self _drawIndicatorWithFrame:frame inView:controlView];
    }
}

- (void)drawCloseButtonWithFrame:(NSRect)frame inView:(NSView *)controlView {

    id <MMTabStyle> style = self.style;
    if ([style respondsToSelector:@selector(drawCloseButtonOfTabCell:withFrame:inView:)]) {
        [style drawCloseButtonOfTabCell:self withFrame:frame inView:controlView];
    } else {
        [self _drawCloseButtonWithFrame:frame inView:controlView];
    }

}

#pragma mark -
#pragma mark NSCopying

- (id)copyWithZone:(nullable NSZone *)zone {
    
    MMTabBarButtonCell *cellCopy = [super copyWithZone:zone];
    if (cellCopy) {
    
        cellCopy->_style = _style;
        cellCopy->_icon = _icon;
        cellCopy->_largeImage = _largeImage;
        cellCopy->_objectCountColor = _objectCountColor;
        
        cellCopy->_tabState = _tabState;
        cellCopy->_showObjectCount = _showObjectCount;
        cellCopy->_objectCount = _objectCount;
        cellCopy->_isEdited = _isEdited;
        cellCopy->_isProcessing = _isProcessing;
        cellCopy->_hasCloseButton = _hasCloseButton;
        cellCopy->_suppressCloseButton = _suppressCloseButton;
        cellCopy->_closeButtonOver = _closeButtonOver;
    }
    
    return cellCopy;
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[super encodeWithCoder:aCoder];

	if (aCoder.allowsKeyedCoding) {
        [aCoder encodeObject:_style forKey:@"MMTabBarButtonCellStyle"];
        [aCoder encodeObject:_icon forKey:@"MMTabBarButtonCellIcon"];
        [aCoder encodeObject:_largeImage forKey:@"MMTabBarButtonCellLargeImage"];
        [aCoder encodeObject:_objectCountColor forKey:@"MMTabBarButtonCellLargeObjectCountColor"];
        
        [aCoder encodeInteger:_tabState forKey:@"MMTabBarButtonCellTabState"];
        [aCoder encodeBool:_showObjectCount forKey:@"MMTabBarButtonCellShowObjectCount"];
        [aCoder encodeInteger:_objectCount forKey:@"MMTabBarButtonCellTabObjectCount"];
        [aCoder encodeBool:_isEdited forKey:@"MMTabBarButtonCellShowObjectIsEdited"];
        [aCoder encodeBool:_isProcessing forKey:@"MMTabBarButtonCellShowObjectIsProcessing"];
        [aCoder encodeBool:_hasCloseButton forKey:@"MMTabBarButtonCellShowObjectHasCloseButton"];
        [aCoder encodeBool:_suppressCloseButton forKey:@"MMTabBarButtonCellShowObjectSuppressCloseButton"];
        [aCoder encodeBool:_closeButtonOver forKey:@"MMTabBarButtonCellShowObjectSuppressCloseButtonOver"];
	}
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super initWithCoder:aDecoder])) {
		if (aDecoder.allowsKeyedCoding) {
        
            _style = [aDecoder decodeObjectForKey:@"MMTabBarButtonCellStyle"];
            _icon = [aDecoder decodeObjectForKey:@"MMTabBarButtonCellIcon"];
            _largeImage = [aDecoder decodeObjectForKey:@"MMTabBarButtonCellLargeImage"];
            _objectCountColor = [aDecoder decodeObjectForKey:@"MMTabBarButtonCellLargeObjectCountColor"];
            
            _tabState = [aDecoder decodeIntegerForKey:@"MMTabBarButtonCellTabState"];
            _showObjectCount = [aDecoder decodeBoolForKey:@"MMTabBarButtonCellShowObjectCount"];
            _objectCount = [aDecoder decodeIntegerForKey:@"MMTabBarButtonCellTabObjectCount"];
            _isEdited = [aDecoder decodeBoolForKey:@"MMTabBarButtonCellShowObjectIsEdited"];
            _isProcessing = [aDecoder decodeBoolForKey:@"MMTabBarButtonCellShowObjectIsProcessing"];
            _hasCloseButton = [aDecoder decodeBoolForKey:@"MMTabBarButtonCellShowObjectHasCloseButton"];
            _suppressCloseButton = [aDecoder decodeBoolForKey:@"MMTabBarButtonCellShowObjectSuppressCloseButton"];
            _closeButtonOver = [aDecoder decodeBoolForKey:@"MMTabBarButtonCellShowObjectSuppressCloseButtonOver"];
		}
	}
	return self;
}

#pragma mark -
#pragma mark Private Methods

#pragma mark > String Values

- (NSAttributedString *)_attributedStringValue {

	NSMutableAttributedString *attrStr;
	NSString *contents = self.title;
	attrStr = [[NSMutableAttributedString alloc] initWithString:contents];
	NSRange range = NSMakeRange(0, contents.length);

	[attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:range];
	[attrStr addAttribute:NSForegroundColorAttributeName value:NSColor.controlTextColor range:range];
    
	// Paragraph Style for Truncating Long Text
	static NSMutableParagraphStyle *truncatingTailParagraphStyle = nil;
	if (!truncatingTailParagraphStyle) {
		truncatingTailParagraphStyle = [NSParagraphStyle.defaultParagraphStyle mutableCopy];
		[truncatingTailParagraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
		[truncatingTailParagraphStyle setAlignment:NSCenterTextAlignment];
	}
	[attrStr addAttribute:NSParagraphStyleAttributeName value:truncatingTailParagraphStyle range:range];

	return attrStr;
}

- (NSAttributedString *)_attributedObjectCountStringValue {

    static NSDictionary<NSAttributedStringKey, id> *objectCountStringAttributes = nil;
    
    if (objectCountStringAttributes == nil) {
		NSFont* const font = [NSFont fontWithName:@"Helvetica" size:11.0];
		NSFont* const styledFont = [NSFontManager.sharedFontManager convertFont:font toHaveTrait:NSBoldFontMask];
		objectCountStringAttributes = @{
			NSFontAttributeName: styledFont != nil ? styledFont : font,
			NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.85]
		};
    }

	NSString *contents = [NSString stringWithFormat:@"%lu", (unsigned long)self.objectCount];
	return [[NSMutableAttributedString alloc] initWithString:contents attributes:objectCountStringAttributes];
}

#pragma mark > Sub Buttons

- (void)_updateSubButtons {
    [self _updateCloseButton];
    [self _updateIndicator];
}

- (void)_updateCloseButtonImages {

    MMRolloverButton *closeButton = self.closeButton;
    
    [closeButton setImage:_isEdited?[self closeButtonImageOfType:MMCloseButtonImageTypeDirty]:[self closeButtonImageOfType:MMCloseButtonImageTypeStandard]];
    [closeButton setAlternateImage:_isEdited?[self closeButtonImageOfType:MMCloseButtonImageTypeDirtyPressed]:[self closeButtonImageOfType:MMCloseButtonImageTypePressed]];
    [closeButton setRolloverImage:_isEdited?[self closeButtonImageOfType:MMCloseButtonImageTypeDirtyRollover]:[self closeButtonImageOfType:MMCloseButtonImageTypeRollover]];
}

- (NSImage *)_closeButtonImageOfType:(MMCloseButtonImageType)type {
        
    // we currently have no default images
    return nil;
}

- (void)_updateCloseButton {

    MMTabBarView *tabBarView = self.tabBarView;
    MMTabBarButton *button = self.controlView;
    MMRolloverButton *closeButton = button.closeButton;

    [self _updateCloseButtonImages];

    BOOL shouldDisplayCloseButton = (self.shouldDisplayCloseButton && !tabBarView.isTabBarHidden);

    if (shouldDisplayCloseButton) {

            // allow style to update close button
        if (_style && [_style respondsToSelector:@selector(updateCloseButton:ofTabCell:)]) {
            shouldDisplayCloseButton = [_style updateCloseButton:closeButton ofTabCell:self];
        }
    }
    
        // adjust visibility and position of close button
    if (shouldDisplayCloseButton) {
        NSRect newFrame = [self closeButtonRectForBounds:button.bounds];

        BOOL shouldHide = NSEqualRects(newFrame,NSZeroRect);
        [closeButton setHidden:shouldHide];
        if (!shouldHide)
            [closeButton setFrame:newFrame];
    } else {
        [closeButton setHidden:YES];
    }
}

- (void)_updateIndicator {

    MMTabBarView *tabBarView = self.tabBarView;
    MMTabBarButton *button = self.controlView;
    MMProgressIndicator *indicator = button.indicator;

        // adjust visibility and position of process indicator
    if (self.isProcessing && !tabBarView.isTabBarHidden) {
        NSRect newFrame = [self indicatorRectForBounds:button.bounds];
        BOOL shouldHide = NSEqualRects(newFrame,NSZeroRect);
        [self.indicator setHidden:shouldHide];
        if (!shouldHide)
            [self.indicator setFrame:newFrame];
    
    } else {
        [indicator setHidden:YES];
    }
    
    if (_isProcessing && !indicator.isHidden)
        [indicator startAnimation:nil];
    else
        [indicator stopAnimation:nil];
}

#pragma mark > Margins

- (CGFloat)_leftMargin {

    return MARGIN_X;
}  // -_leftMargin

- (CGFloat)_rightMargin {

    // balancing right margin if cell displays close button on hover only
    // (simply improves look)
    if (self.shouldDisplayCloseButton && self.tabBarView.onlyShowCloseOnHover) {
        NSImage *image = [self closeButtonImageOfType:MMCloseButtonImageTypeStandard];
        return MARGIN_X + image.size.width + kMMTabBarCellPadding;
        }

    return MARGIN_X;
}  // -_rightMargin

#pragma mark > Determining Cell Size

- (NSRect)_drawingRectForBounds:(NSRect)theRect {

    theRect.origin.x += self._leftMargin;
    theRect.size.width -= self._leftMargin + self._rightMargin;
    
    theRect.origin.y += MARGIN_Y;
    theRect.size.height -= 2*MARGIN_Y;
    
    return theRect;
}

- (NSRect)_titleRectForBounds:(NSRect)theRect {
    NSRect drawingRect = [self drawingRectForBounds:theRect];

    NSRect constrainedDrawingRect = drawingRect;

    NSRect closeButtonRect = [self closeButtonRectForBounds:theRect];
    if (!NSEqualRects(closeButtonRect, NSZeroRect)) {
        constrainedDrawingRect.origin.x += NSWidth(closeButtonRect)  + kMMTabBarCellPadding;
        constrainedDrawingRect.size.width -= NSWidth(closeButtonRect) + kMMTabBarCellPadding;
    }

    NSRect largeImageRect = [self largeImageRectForBounds:theRect];
    if (!NSEqualRects(largeImageRect, NSZeroRect)) {
        constrainedDrawingRect.origin.x += NSWidth(largeImageRect) + kMMTabBarCellPadding;
        constrainedDrawingRect.size.width -= NSWidth(largeImageRect) + kMMTabBarCellPadding;
        }
                
    NSRect iconRect = [self iconRectForBounds:theRect];
    if (!NSEqualRects(iconRect, NSZeroRect)) {
        constrainedDrawingRect.origin.x += NSWidth(iconRect)  + kMMTabBarCellPadding;
        constrainedDrawingRect.size.width -= NSWidth(iconRect) + kMMTabBarCellPadding;
    }
        
    NSRect indicatorRect = [self indicatorRectForBounds:theRect];
    if (!NSEqualRects(indicatorRect, NSZeroRect)) {
        constrainedDrawingRect.size.width -= NSWidth(indicatorRect) + kMMTabBarCellPadding;
    }

    NSRect counterBadgeRect = [self objectCounterRectForBounds:theRect];
    if (!NSEqualRects(counterBadgeRect, NSZeroRect)) {
        constrainedDrawingRect.size.width -= NSWidth(counterBadgeRect) + kMMTabBarCellPadding;
    }
                            
    NSAttributedString *attrString = self.attributedStringValue;
    if (attrString.length == 0)
        return NSZeroRect;
        
    NSSize stringSize = attrString.size;
    
    NSRect result = NSMakeRect(constrainedDrawingRect.origin.x, drawingRect.origin.y+ceil((drawingRect.size.height-stringSize.height)/2), constrainedDrawingRect.size.width, stringSize.height);
                    
    return NSIntegralRect(result);

}

- (NSRect)_iconRectForBounds:(NSRect)theRect {

    NSImage *icon = self.icon;
    if (!icon)
        return NSZeroRect;

    // calculate rect
    NSRect drawingRect = [self drawingRectForBounds:theRect];

    NSRect constrainedDrawingRect = drawingRect;

    NSRect closeButtonRect = [self closeButtonRectForBounds:theRect];
    if (!NSEqualRects(closeButtonRect, NSZeroRect)) {
        constrainedDrawingRect.origin.x += NSWidth(closeButtonRect)  + kMMTabBarCellPadding;
        constrainedDrawingRect.size.width -= NSWidth(closeButtonRect) + kMMTabBarCellPadding;
        }
                
    NSSize iconSize = icon.size;
    
    NSSize scaledIconSize = [self mm_scaleImageWithSize:iconSize toFitInSize:NSMakeSize(iconSize.width, constrainedDrawingRect.size.height) scalingType:NSImageScaleProportionallyDown];

    NSRect result;
        
    // icon only
    if (self.title.length == 0 && !self.showObjectCount && !self.isProcessing) {
        result = NSMakeRect(constrainedDrawingRect.origin.x+(constrainedDrawingRect.size.width - scaledIconSize.width)/2,
            constrainedDrawingRect.origin.y + ((constrainedDrawingRect.size.height - scaledIconSize.height) / 2),
            scaledIconSize.width, scaledIconSize.height);
    // icon 
    } else {
        result = NSMakeRect(constrainedDrawingRect.origin.x,
                                             constrainedDrawingRect.origin.y + ((constrainedDrawingRect.size.height - scaledIconSize.height) / 2),
                                             scaledIconSize.width, scaledIconSize.height);
                                             
        // center in available space (in case icon image is smaller than kMMTabBarIconWidth)
        if (scaledIconSize.width < kMMTabBarIconWidth) {
            result.origin.x += ceil((kMMTabBarIconWidth - scaledIconSize.width) / 2.0);
        }

        if (scaledIconSize.height < kMMTabBarIconWidth) {
            result.origin.y += ceil((kMMTabBarIconWidth - scaledIconSize.height) / 2.0 - 0.5);
        }
    }

    return NSIntegralRect(result);
}

- (NSRect)_largeImageRectForBounds:(NSRect)theRect {

    NSImage *image = self.largeImage;
    if (!image) {
        return NSZeroRect;
    }
    
    // calculate rect
    NSRect drawingRect = [self drawingRectForBounds:theRect];

    NSRect constrainedDrawingRect = drawingRect;

    NSRect closeButtonRect = [self closeButtonRectForBounds:theRect];
    if (!NSEqualRects(closeButtonRect, NSZeroRect)) {
        constrainedDrawingRect.origin.x += NSWidth(closeButtonRect) + kMMTabBarCellPadding;
        }
                
    NSSize scaledImageSize = [self mm_scaleImageWithSize:image.size toFitInSize:NSMakeSize(constrainedDrawingRect.size.width, constrainedDrawingRect.size.height) scalingType:NSImageScaleProportionallyUpOrDown];
    
    NSRect result = NSMakeRect(constrainedDrawingRect.origin.x,
                                         constrainedDrawingRect.origin.y - ((constrainedDrawingRect.size.height - scaledImageSize.height) / 2),
                                         scaledImageSize.width, scaledImageSize.height);

    if (scaledImageSize.width < kMMTabBarIconWidth) {
        result.origin.x += (kMMTabBarIconWidth - scaledImageSize.width) / 2.0;
    }
    if (scaledImageSize.height < constrainedDrawingRect.size.height) {
        result.origin.y += (constrainedDrawingRect.size.height - scaledImageSize.height) / 2.0;
    }
        
    return NSIntegralRect(result);
}

- (NSRect)_indicatorRectForBounds:(NSRect)theRect {

    if (!self.isProcessing) {
        return NSZeroRect;
    }

    // calculate rect
    NSRect drawingRect = [self drawingRectForBounds:theRect];

    NSSize indicatorSize = NSMakeSize(kMMTabBarIndicatorWidth, kMMTabBarIndicatorWidth);
    
    NSRect result = NSMakeRect(NSMaxX(drawingRect)-indicatorSize.width,NSMidY(drawingRect)-ceil(indicatorSize.height/2),indicatorSize.width,indicatorSize.height);
    
    return NSIntegralRect(result);
}

- (NSSize)_objectCounterSize {
    
    if (!self.showObjectCount) {
        return NSZeroSize;
    }
    
    // get badge width
    CGFloat countWidth = self.attributedObjectCountStringValue.size.width;
        countWidth += (2 * kMMObjectCounterRadius - 6.0);
        if (countWidth < kMMObjectCounterMinWidth) {
            countWidth = kMMObjectCounterMinWidth;
        }
    
    return NSMakeSize(countWidth, 2 * kMMObjectCounterRadius);
}

- (NSRect)_objectCounterRectForBounds:(NSRect)theRect {

    if (!self.showObjectCount) {
        return NSZeroRect;
    }

    NSRect drawingRect = [self drawingRectForBounds:theRect];

    NSRect constrainedDrawingRect = drawingRect;

    NSRect indicatorRect = [self indicatorRectForBounds:theRect];
    if (!NSEqualRects(indicatorRect, NSZeroRect)) {
        constrainedDrawingRect.size.width -= NSWidth(indicatorRect) + kMMTabBarCellPadding;
        }
    
    NSSize counterBadgeSize = self.objectCounterSize;
    
    // calculate rect
    NSRect result;
    result.size = counterBadgeSize; // temp
    result.origin.x = NSMaxX(constrainedDrawingRect)-counterBadgeSize.width;
    result.origin.y = ceil(constrainedDrawingRect.origin.y+(constrainedDrawingRect.size.height-result.size.height)/2);
                
    return NSIntegralRect(result);
}

- (NSSize)_closeButtonSizeForBounds:(NSRect)theRect {

    NSRect drawingRect = [self drawingRectForBounds:theRect];

    return NSMakeSize(12.0,drawingRect.size.height);
}

- (MMRolloverButton *)_closeButtonForBounds:(NSRect)theRect {

    NSRect frame = [self closeButtonRectForBounds:theRect];
    MMRolloverButton *closeButton = [[MMRolloverButton alloc] initWithFrame:frame];

    [closeButton setTitle:@""];
    [closeButton setImagePosition:NSImageOnly];
    [closeButton setRolloverButtonType:MMRolloverActionButton];
    [closeButton setBordered:NO];
    [closeButton setBezelStyle:NSShadowlessSquareBezelStyle];

    return closeButton;
}

- (NSRect)_closeButtonRectForBounds:(NSRect)theRect {

    if (self.shouldDisplayCloseButton == NO) {
        return NSZeroRect;
    }
    
    NSRect drawingRect = [self drawingRectForBounds:theRect];
    NSSize closeButtonSize = [self closeButtonSizeForBounds:theRect];
    
    NSRect result = NSMakeRect(drawingRect.origin.x, drawingRect.origin.y, closeButtonSize.width, closeButtonSize.height);
    
    return result;
}

- (CGFloat)_minimumWidthOfCell {
    CGFloat resultWidth = 0.0;

    // left margin
    resultWidth = self._leftMargin;

    // close button?
    if (self.shouldDisplayCloseButton) {
        NSImage *image = [self closeButtonImageOfType:MMCloseButtonImageTypeStandard];
        resultWidth += image.size.width + kMMTabBarCellPadding;
    }

    // icon?
    if (self.icon) {
        resultWidth += kMMTabBarIconWidth + kMMTabBarCellPadding;
    }

    // the label
    resultWidth += kMMMinimumTitleWidth;

    // object counter?
    if (self.showObjectCount) {
        resultWidth += self.objectCounterSize.width + kMMTabBarCellPadding;
    }

    // indicator?
    if (self.isProcessing) {
        resultWidth += kMMTabBarCellPadding + kMMTabBarIndicatorWidth;
    }

    // right margin
    resultWidth += self._rightMargin;

    return ceil(resultWidth);
}

- (CGFloat)_desiredWidthOfCell {

    CGFloat resultWidth = 0.0;

    // left margin
    resultWidth = self._leftMargin;

    // close button?
    if (self.shouldDisplayCloseButton) {
        NSImage *image = [self closeButtonImageOfType:MMCloseButtonImageTypeStandard];
        resultWidth += image.size.width + kMMTabBarCellPadding;
    }

    // icon?
    if (self.icon) {
        resultWidth += kMMTabBarIconWidth + kMMTabBarCellPadding;
    }

    // the label
    resultWidth += self.attributedStringValue.size.width;

    // object counter?
    if (self.showObjectCount) {
        resultWidth += self.objectCounterSize.width + kMMTabBarCellPadding;
    }

    // indicator?
    if (self.isProcessing) {
        resultWidth += kMMTabBarCellPadding + kMMTabBarIndicatorWidth;
    }

    // right margin
    resultWidth += self._rightMargin;
    
    return ceil(resultWidth);
}

#pragma mark > Drawing

- (void)_drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [self drawBezelWithFrame:cellFrame inView:controlView];
    [self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void)_drawBezelWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    // default implementation draws nothing yet.
}

- (void)_drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSRect componentRect;
    
    componentRect = [self largeImageRectForBounds:cellFrame];
    if (!NSEqualRects(componentRect, NSZeroRect))
        [self drawLargeImageWithFrame:cellFrame inView:controlView];
        
    componentRect = [self iconRectForBounds:cellFrame];
    if (!NSEqualRects(componentRect, NSZeroRect))
        [self drawIconWithFrame:cellFrame inView:controlView];
        
    componentRect = [self titleRectForBounds:cellFrame];
    if (!NSEqualRects(componentRect, NSZeroRect))
        [self drawTitleWithFrame:cellFrame inView:controlView];
        
    componentRect = [self objectCounterRectForBounds:cellFrame];
    if (!NSEqualRects(componentRect, NSZeroRect))
        [self drawObjectCounterWithFrame:cellFrame inView:controlView];
        
    componentRect = [self indicatorRectForBounds:cellFrame];
    if (!NSEqualRects(componentRect, NSZeroRect))
        [self drawIndicatorWithFrame:cellFrame inView:controlView];
        
    componentRect = [self closeButtonRectForBounds:cellFrame];
    if (!NSEqualRects(componentRect, NSZeroRect))
        [self drawCloseButtonWithFrame:cellFrame inView:controlView];
}

- (void)_drawLargeImageWithFrame:(NSRect)frame inView:(NSView *)controlView {

    MMTabBarView *tabBarView = controlView.enclosingTabBarView;

    MMTabBarOrientation orientation = tabBarView.orientation;

    NSImage *image = self.largeImage;

    if ((orientation != MMTabBarVerticalOrientation) || !image)
        return;
    
    NSRect imageDrawingRect = [self largeImageRectForBounds:frame];
    
    [NSGraphicsContext saveGraphicsState];
            
    //Create Rounding.
    CGFloat userIconRoundingRadius = (imageDrawingRect.size.width / 4.0);
    if (userIconRoundingRadius > 3.0) {
        userIconRoundingRadius = 3.0;
    }
    
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithRoundedRect:imageDrawingRect xRadius:userIconRoundingRadius yRadius:userIconRoundingRadius];
    [clipPath addClip];        

    [image drawInRect:imageDrawingRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];

    [NSGraphicsContext restoreGraphicsState];
}

- (void)_drawIconWithFrame:(NSRect)frame inView:(NSView *)controlView {
    NSRect iconRect = [self iconRectForBounds:frame];
    
    NSImage *icon = self.icon;

    [icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
}

inline static bool useShadow(NSView* const inView) {
	if (@available(macOS 10.14, *)) {
		return ![[inView.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
	}
	return true;
}

- (void)_drawTitleWithFrame:(NSRect)frame inView:(NSView *)controlView {

    NSRect rect = [self titleRectForBounds:frame];

    [NSGraphicsContext saveGraphicsState];

	if (useShadow(controlView)) {
		NSShadow *shadow = [[NSShadow alloc] init];
		[shadow setShadowColor:[NSColor.whiteColor colorWithAlphaComponent:0.4]];
		[shadow setShadowBlurRadius:1.0];
		[shadow setShadowOffset:NSMakeSize(0.0, -1.0)];
		[shadow set];
	}

    // draw title
    [self.attributedStringValue drawInRect:rect];

    [NSGraphicsContext restoreGraphicsState];
        
}

- (void)_drawObjectCounterWithFrame:(NSRect)frame inView:(NSView *)controlView {

    // set color
    [self.objectCountColor ?: self.class.defaultObjectCountColor set];
    
    // get rect
    NSRect myRect = [self objectCounterRectForBounds:frame];
    
    // create badge path
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:myRect xRadius:kMMObjectCounterRadius yRadius:kMMObjectCounterRadius];
    
    // fill badge
    [path fill];

    // draw attributed string centered in area
    NSRect counterStringRect;
    NSAttributedString *counterString = self.attributedObjectCountStringValue;
    counterStringRect.size = counterString.size;
    counterStringRect.origin.x = myRect.origin.x + ((myRect.size.width - counterStringRect.size.width) / 2.0) + 0.25;
    counterStringRect.origin.y = NSMidY(myRect)-counterStringRect.size.height/2;
    [counterString drawInRect:counterStringRect];
}

- (void)_drawIndicatorWithFrame:(NSRect)frame inView:(NSView *)controlView {
    // we draw nothing by default
}

- (void)_drawCloseButtonWithFrame:(NSRect)frame inView:(NSView *)controlView {

    // we draw nothing by default
    
        // update hidden state of close button
    if (self.tabBarView.onlyShowCloseOnHover) {
        [self.closeButton setHidden:!self.mouseHovered];
    } else {
        if (self.closeButton.isHidden == YES)
            [self.closeButton setHidden:NO];
    }
}

@end

NS_ASSUME_NONNULL_END
