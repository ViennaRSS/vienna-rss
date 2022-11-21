//
//  FeedListCellView.m
//  Vienna
//
//  Copyright 2021 Joshua Pore, 2021-2022 Eitot
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FeedListCellView.h"

#import <os/log.h>

#define VNA_LOG os_log_create("--", "FeedListCellView")

// These contants are defined in Interface Builder.
NSUserInterfaceItemIdentifier const VNAFeedListCellViewIdentifier = @"FeedListCellView";
NSUserInterfaceItemIdentifier const VNAFeedListCellViewTextFieldIdentifier = @"TextField";
NSUserInterfaceItemIdentifier const VNAFeedListCellViewCountButtonIdentifier = @"CountButton";

// These constants were eyeballed from Apple's apps.
static CGFloat const VNALeadingSpaceConstantTiny = 22.0;
static CGFloat const VNALeadingSpaceConstantSmall = 25.0;
static CGFloat const VNALeadingSpaceConstantMedium = 29.0;
static CGFloat const VNAHorizontalDistanceConstantTiny = 13.0;
static CGFloat const VNAHorizontalDistanceConstantSmall = 15.0;
static CGFloat const VNAHorizontalDistanceConstantMedium = 17.0;

// These constants are only used on systems before macOS 11.
static CGFloat const VNAFontSizeTiny = 12.0;
static CGFloat const VNAFontSizeSmall = 13.0;
static CGFloat const VNAFontSizeMedium = 15.0;

@interface VNAFeedListCellView ()

@property (weak, nonatomic) IBOutlet NSStackView *stackView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textFieldLeadingSpace;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *iconHorizontalDistance;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *unreadCountBaseline;

// Ownership is required here, since these views might be removed from the view
// hierarchy by the stack view.
@property (nonatomic) IBOutlet NSButton *unreadCountButton;
@property (nonatomic) IBOutlet NSImageView *errorImageView;
@property (nonatomic) IBOutlet NSProgressIndicator *progressIndicator;

@end

@implementation VNAFeedListCellView

// MARK: Initialization

- (instancetype)init
{
    self = [super init];
    if (self) {
        _emphasized = NO;
        _inactive = NO;
        _showError = NO;
        _inProgress = NO;
        _unreadCount = 0;
        _canShowUnreadCount = YES;
    }
    return self;
}

// MARK: Overrides

// The cell view does not use the responder status itself, as selection and
// clicking is handled by the outline view. It will give up first responder
// status to the text field however. Since the whole frame of the cell view
// responds to events, the text field is activated needlessly when the user
// clicks anywhere within the frame. Disabling first responder avoids that.
- (BOOL)acceptsFirstResponder
{
    return NO;
}

// In macOS 12 this property returns a value based on the text field's first
// baseline. That value is used by the disclosure triangle. This behavior is
// not working correctly when the row height is changed. Returning 0 ensures
// that the disclosure triangle is vertically centered.
- (CGFloat)firstBaselineOffsetFromTop
{
    return 0.0;
}

// MARK: Accessors

- (void)setSizeMode:(VNAFeedListSizeMode)sizeMode
{
    _sizeMode = sizeMode;
    [self updateViewForSizeMode];
}

- (void)setEmphasized:(BOOL)emphasized
{
    _emphasized = emphasized;
    [self updateViewForFontTraits];
}

- (void)setInactive:(BOOL)inactive
{
    _inactive = inactive;
    if (_inactive) {
        self.textField.textColor = NSColor.tertiaryLabelColor;
    } else {
        self.textField.textColor = NSColor.labelColor;
    }
}

- (void)setInProgress:(BOOL)inProgress
{
    _inProgress = inProgress;
    if (_inProgress) {
        self.errorImageView.hidden = YES;
        self.progressIndicator.hidden = NO;
        [self.progressIndicator startAnimation:nil];
    } else {
        [self.progressIndicator stopAnimation:nil];
        self.progressIndicator.hidden = YES;
    }
}

- (void)setShowError:(BOOL)showError
{
    _showError = showError;
    if (_showError) {
        self.errorImageView.hidden = NO;
    } else {
        self.errorImageView.hidden = YES;
    }
}

- (void)setUnreadCount:(NSInteger)unreadCount
{
    _unreadCount = MAX(unreadCount, 0);
    [self updateUnreadCountWithAnimation:NO];
}

- (void)setCanShowUnreadCount:(BOOL)canShowUnreadCount
{
    _canShowUnreadCount = canShowUnreadCount;
    BOOL animate = NSAnimationContext.currentContext.allowsImplicitAnimation;
    [self updateUnreadCountWithAnimation:animate];
}

// MARK: Utility

- (NSFont *)fontForTextStyle:(NSFontTextStyle)textStyle NS_AVAILABLE_MAC(11)
{
    NSFontDescriptor *descriptor;
    descriptor = [NSFontDescriptor preferredFontDescriptorForTextStyle:textStyle
                                                               options:@{}];
    NSFont *font = [NSFont fontWithDescriptor:descriptor
                                         size:descriptor.pointSize];
    return font;
}

- (NSImageSymbolConfiguration *)symbolForTextStyle:(NSFontTextStyle)textStyle
    NS_AVAILABLE_MAC(11)
{
    NSImageSymbolConfiguration *config;
    config = [NSImageSymbolConfiguration configurationWithTextStyle:textStyle];
    return config;
}

- (void)updateViewForSizeMode
{
    switch (self.sizeMode) {
    case VNAFeedListSizeModeTiny:
        self.textFieldLeadingSpace.constant = VNALeadingSpaceConstantTiny;
        self.iconHorizontalDistance.constant = VNAHorizontalDistanceConstantTiny;
        if (@available(macOS 11, *)) {
            self.unreadCountBaseline.active = YES;
            NSFontTextStyle style = NSFontTextStyleCallout;
            self.textField.font = [self fontForTextStyle:style];
            self.imageView.symbolConfiguration = [self symbolForTextStyle:style];
        } else {
            self.unreadCountBaseline.active = NO;
            self.textField.font = [NSFont systemFontOfSize:VNAFontSizeTiny];
        }
        break;
    case VNAFeedListSizeModeSmall:
        self.textFieldLeadingSpace.constant = VNALeadingSpaceConstantSmall;
        self.iconHorizontalDistance.constant = VNAHorizontalDistanceConstantSmall;
        self.unreadCountBaseline.active = NO;
        if (@available(macOS 11, *)) {
            NSFontTextStyle style = NSFontTextStyleBody;
            self.textField.font = [self fontForTextStyle:style];
            self.imageView.symbolConfiguration = [self symbolForTextStyle:style];
        } else {
            self.textField.font = [NSFont systemFontOfSize:VNAFontSizeSmall];
        }
        break;
    case VNAFeedListSizeModeMedium:
        self.textFieldLeadingSpace.constant = VNALeadingSpaceConstantMedium;
        self.iconHorizontalDistance.constant = VNAHorizontalDistanceConstantMedium;
        self.unreadCountBaseline.active = NO;
        if (@available(macOS 11, *)) {
            NSFontTextStyle style = NSFontTextStyleTitle3;
            self.textField.font = [self fontForTextStyle:style];
            self.imageView.symbolConfiguration = [self symbolForTextStyle:style];
        } else {
            self.textField.font = [NSFont systemFontOfSize:VNAFontSizeMedium];
        }
        break;
    default:
        os_log_fault(VNA_LOG, "Invalid size mode for cell view");
    }
}

- (void)updateViewForFontTraits
{
    NSFontDescriptor *descriptor = [self.textField.font.fontDescriptor copy];
    NSFontDescriptorSymbolicTraits traits = descriptor.symbolicTraits;
    if (self.isEmphasized) {
        traits |= NSFontDescriptorTraitBold;
    } else {
        traits &= ~NSFontDescriptorTraitBold;
    }
    descriptor = [descriptor fontDescriptorWithSymbolicTraits:traits];
    NSFont *font = [NSFont fontWithDescriptor:descriptor
                                         size:descriptor.pointSize];
    self.textField.font = font;
}

- (void)updateUnreadCountWithAnimation:(BOOL)animated
{
    NSInteger unreadCount = self.unreadCount;
    NSString *countString = [NSString stringWithFormat:@"%ld", unreadCount];
    BOOL showUnreadCount = self.canShowUnreadCount && unreadCount > 0;
    if (animated) {
        self.unreadCountButton.animator.hidden = !showUnreadCount;
        self.unreadCountButton.animator.title = countString;
    } else {
        self.unreadCountButton.hidden = !showUnreadCount;
        self.unreadCountButton.title = countString;
    }
}

@end
