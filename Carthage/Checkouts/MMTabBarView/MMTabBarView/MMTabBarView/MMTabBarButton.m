//
//  MMTabBarButton.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/5/12.
//
//

#import "MMTabBarButton.h"
#import "MMRolloverButton.h"
#import "MMTabBarButtonCell.h"
#import "MMTabBarView.h"
#import "MMTabDragAssistant.h"
#import "NSView+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

// Pointer value that we use as the binding context
NSString *kMMTabBarButtonOberserverContext = @"MMTabBarView.MMTabBarButton.ObserverContext";

@interface MMTabBarButton (/*Private*/)

- (void)_commonInit;
- (NSRect)_closeButtonRectForBounds:(NSRect)bounds;
- (NSRect)_indicatorRectForBounds:(NSRect)bounds;

@end

@implementation MMTabBarButton

+ (void)initialize
{
    if (self == [MMTabBarButton class]) {
        [self exposeBinding:@"isProcessing"];
        [self exposeBinding:@"isEdited"];    
        [self exposeBinding:@"objectCount"];
        [self exposeBinding:@"objectCountColor"];
        [self exposeBinding:@"icon"];
        [self exposeBinding:@"largeImage"];
        [self exposeBinding:@"hasCloseButton"];
    }
}

+ (nullable Class)cellClass {
    return [MMTabBarButtonCell class];
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _commonInit];
    }
    
    return self;
}

- (nullable MMTabBarButtonCell *)cell {
    return (MMTabBarButtonCell *)[super cell];
}

- (void)setCell:(nullable MMTabBarButtonCell *)aCell {
    [super setCell:aCell];
}

- (MMTabBarView *)tabBarView {
    return [self enclosingTabBarView];
}
    
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {

    [super resizeSubviewsWithOldSize:oldSize];
    
        // We do not call -calcSize before drawing (as documented).
        // We only need to calculate size when resizing.
    [self calcSize];
}

- (void)calcSize {

        // Let cell update (invokes -calcDrawInfo:)
        // Cell will update control's sub buttons too.
    [[self cell] calcDrawInfo:[self bounds]];
}

- (nullable NSMenu *)menuForEvent:(NSEvent *)event {

    MMTabBarView *tabBarView = [self tabBarView];
    
    return [tabBarView menuForTabBarButton:self withEvent:event];
}

- (void)updateCell {    
    [self updateCell:[self cell]];
}

#pragma mark -
#pragma mark Accessors

- (nullable SEL)closeButtonAction {

    @synchronized(self) {
        return [_closeButton action];
    }
}

- (void)setCloseButtonAction:(nullable SEL)closeButtonAction {

    @synchronized(self) {
        [_closeButton setAction:closeButtonAction];
    }
}

#pragma mark -
#pragma mark Dividers

- (BOOL)shouldDisplayLeftDivider {

    MMTabStateMask tabStateMask = [self tabState];
    
    BOOL retVal = NO;
    if (tabStateMask & MMTab_LeftIsSliding)
        retVal = YES;

    return retVal;
}

- (BOOL)shouldDisplayRightDivider {

    MMTabStateMask tabStateMask = [self tabState];
    
    BOOL retVal = NO;
    if (tabStateMask & MMTab_RightIsSliding)
        retVal = YES;

    return retVal;
}

#pragma mark -
#pragma mark Determine Sizes

- (CGFloat)minimumWidth {
    return [[self cell] minimumWidthOfCell];
}

- (CGFloat)desiredWidth {
    return [[self cell] desiredWidthOfCell];
}

#pragma mark -
#pragma mark Interfacing Cell

    // Overidden method of superclass.
    // Note: We use standard binding for title property.
    // Standard binding uses a binding adaptor we cannot access.
    // That means though title property is bound, our -observeValueForKeyPath:ofObject:change:context: will not called
    // if title property changes.
    // This is why we need to invoke update of layout manually.
-(void)setTitle:(NSString *)aString
{
    [super setTitle:aString];

    if ([[self tabBarView] sizeButtonsToFit])
        {
        [[NSOperationQueue mainQueue] addOperationWithBlock:
            ^{
            [[self tabBarView] update];
            }];
        }
    
}  // -setTitle:

- (id <MMTabStyle>)style {
    return [[self cell] style];
}

- (void)setStyle:(id <MMTabStyle>)newStyle {
    [[self cell] setStyle:newStyle];
    [self updateCell];

    if (_closeButton) {
        [_closeButton removeFromSuperview];
    }
    _closeButton = [self _closeButtonForBounds:[self bounds]];
    [self addSubview:_closeButton];

}

- (MMTabStateMask)tabState {
    return [[self cell] tabState];
}

- (void)setTabState:(MMTabStateMask)newState {

    [[self cell] setTabState:newState];
    [self updateCell];
}

- (BOOL)shouldDisplayCloseButton {
    return [[self cell] shouldDisplayCloseButton];
}

- (BOOL)hasCloseButton {
    return [[self cell] hasCloseButton];
}

- (void)setHasCloseButton:(BOOL)newState {
    [[self cell] setHasCloseButton:newState];
    [self updateCell];
}

- (BOOL)suppressCloseButton {
    return [[self cell] suppressCloseButton];
}

- (void)setSuppressCloseButton:(BOOL)newState {
    [[self cell] setSuppressCloseButton:newState];
    [self updateCell];
}

- (nullable NSImage *)icon {
    return [[self cell] icon];
}

- (void)setIcon:(nullable NSImage *)anIcon {
    [[self cell] setIcon:anIcon];
    [self updateCell];
}

- (nullable NSImage *)largeImage {
    return [[self cell] largeImage];
}

- (void)setLargeImage:(nullable NSImage *)anImage {
    [[self cell] setLargeImage:anImage];
    [self updateCell];
}

- (BOOL)showObjectCount {
    return [[self cell] showObjectCount];
}

- (void)setShowObjectCount:(BOOL)newState {
    [[self cell] setShowObjectCount:newState];
    [self updateCell];
}

- (NSInteger)objectCount {
    return [[self cell] objectCount];
}

- (void)setObjectCount:(NSInteger)newCount {
    [[self cell] setObjectCount:newCount];
    [self updateCell];
}

- (NSColor *)objectCountColor {
    return [[self cell] objectCountColor];
}

- (void)setObjectCountColor:(NSColor *)newColor {
    [[self cell] setObjectCountColor:newColor];
    [self updateCell];
}

- (BOOL)isEdited {
    return [[self cell] isEdited];
}

- (void)setIsEdited:(BOOL)newState {
    [[self cell] setIsEdited:newState];
    [self updateCell];
}

- (BOOL)isProcessing {
    return [[self cell] isProcessing];
}

- (void)setIsProcessing:(BOOL)newState {
    [[self cell] setIsProcessing:newState];
    [self updateCell];
}

- (void)updateImages {
    [[self cell] updateImages];
}

#pragma mark -
#pragma mark NSKeyValueObserving

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary *)change context:(nullable void *)context 
{
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    
    if (context == (__bridge void *)(kMMTabBarButtonOberserverContext))
        {
        if ([[self tabBarView] sizeButtonsToFit])
            {
            [[NSOperationQueue mainQueue] addOperationWithBlock:
                ^{
                [[self tabBarView] update];
                }];
            }
        }
 
}  // -observeValueForKeyPath:ofObject:change:context:

#pragma mark -
#pragma mark Private Methods

- (void)_commonInit {
    _closeButton = [self _closeButtonForBounds:[self bounds]];
    [self addSubview:_closeButton];

    _indicator = [[MMProgressIndicator alloc] initWithFrame:NSMakeRect(0.0, 0.0, kMMTabBarIndicatorWidth, kMMTabBarIndicatorWidth)];
    [_indicator setStyle:NSProgressIndicatorSpinningStyle];
    [_indicator setAutoresizingMask:NSViewMinYMargin];
    [_indicator setControlSize: NSSmallControlSize];
    NSRect indicatorRect = [self _indicatorRectForBounds:[self bounds]];
    [_indicator setFrame:indicatorRect];
    [self addSubview:_indicator];
}

- (MMRolloverButton *)_closeButtonForBounds:(NSRect)bounds {
    return [[self cell] closeButtonForBounds:bounds];
}

- (NSRect)_closeButtonRectForBounds:(NSRect)bounds {
    return [[self cell] closeButtonRectForBounds:bounds];
}

- (NSRect)_indicatorRectForBounds:(NSRect)bounds {
    return [[self cell] indicatorRectForBounds:bounds];
}

-(void)_propagateValue:(id)value forBinding:(NSString*)binding {
	NSParameterAssert(binding != nil);

        //WARNING: bindingInfo contains NSNull, so it must be accounted for
	NSDictionary* bindingInfo = [self infoForBinding:binding];
	if(!bindingInfo)
		return; //there is no binding

        //apply the value transformer, if one has been set
	NSDictionary* bindingOptions = [bindingInfo objectForKey:NSOptionsKey];
	if(bindingOptions){
		NSValueTransformer* transformer = [bindingOptions valueForKey:NSValueTransformerBindingOption];
		if(!transformer || (id)transformer == [NSNull null]){
			NSString* transformerName = [bindingOptions valueForKey:NSValueTransformerNameBindingOption];
			if(transformerName && (id)transformerName != [NSNull null]){
				transformer = [NSValueTransformer valueTransformerForName:transformerName];
			}
		}

		if(transformer && (id)transformer != [NSNull null]){
			if([[transformer class] allowsReverseTransformation]){
				value = [transformer reverseTransformedValue:value];
			} else {
				NSLog(@"WARNING: binding \"%@\" has value transformer, but it doesn't allow reverse transformations in %s", binding, __PRETTY_FUNCTION__);
			}
		}
	}

	id boundObject = [bindingInfo objectForKey:NSObservedObjectKey];
	if(!boundObject || boundObject == [NSNull null]){
		NSLog(@"ERROR: NSObservedObjectKey was nil for binding \"%@\" in %s", binding, __PRETTY_FUNCTION__);
		return;
	}

	NSString* boundKeyPath = [bindingInfo objectForKey:NSObservedKeyPathKey];
	if(!boundKeyPath || (id)boundKeyPath == [NSNull null]){
		NSLog(@"ERROR: NSObservedKeyPathKey was nil for binding \"%@\" in %s", binding, __PRETTY_FUNCTION__);
		return;
	}

	[boundObject setValue:value forKeyPath:boundKeyPath];
}

@end

NS_ASSUME_NONNULL_END
