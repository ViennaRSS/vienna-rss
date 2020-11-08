//
//  MMSierraOverflowPopUpButton.m
//  MMTabBarView
//
//  Created by Isaiah Carew on 4/19/17.
//

#import "MMSierraRolloverButton.h"
#import "MMSierraRolloverButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMSierraRolloverButton

+ (nullable Class)cellClass {
    return [MMSierraRolloverButtonCell class];
}

- (instancetype)initWithFrame:(NSRect)frameRect {

    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = YES;
    }

    return self;
}

@end

NS_ASSUME_NONNULL_END
