//
//  MMTabPasteboardItem.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/11/12.
//
//

#import "MMTabPasteboardItem.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MMTabPasteboardItem

- (instancetype)init {
    self = [super init];
    if (self) {
        _sourceIndex = NSNotFound;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
