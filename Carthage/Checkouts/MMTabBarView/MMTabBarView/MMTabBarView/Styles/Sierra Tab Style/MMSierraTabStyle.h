//
//  MMSierraTabStyle.h
//  --------------------
//
//  Based on MMYosemiteTabStyle.h by Ajin Man Tuladhar
//  Created by Ajin Isaiah Carew on 04/16/2017
//  Copyright 2017 Isaiah Carew. All rights reserved.
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif
#import "MMTabStyle.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMSierraTabStyle : NSObject <MMTabStyle>

@property (assign) CGFloat leftMarginForTabBarView;

@property (assign) BOOL needsResizeTabsToFitTotalWidth;

@end

NS_ASSUME_NONNULL_END
