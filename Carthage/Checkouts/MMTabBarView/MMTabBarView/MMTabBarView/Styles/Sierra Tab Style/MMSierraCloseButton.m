//
//  MMSierraCloseButton.m
//  MMTabBarView
//
//  Created by Isaiah Carew on 4/23/17.
//  Copyright © 2017 Michael Monscheuer. All rights reserved.
//

#import "MMSierraCloseButton.h"
#import "MMSierraCloseButtonCell.h"

@implementation MMSierraCloseButton

+ (nullable Class)cellClass {
    return [MMSierraCloseButtonCell class];
}

- (instancetype)initWithFrame:(NSRect)frameRect {

    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = YES;
    }

    return self;
}

@end
