//
//  MMYosemiteTabStyle.h
//  --------------------
//
//  Based on MMUnifiedTabStyle.h by Keith Blount
//  Created by Ajin Man Tuladhar on 04/11/2014.
//  Some clean up and adjustment by Michael Monscheuer on 03/16/2016
//  Copyright 2016 Ajin Man Tuladhar. All rights reserved.
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif
#import "MMTabStyle.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMYosemiteTabStyle : NSObject <MMTabStyle>

@property (assign) CGFloat leftMarginForTabBarView;

@property (assign) BOOL hasBaseline;

@property (retain) NSColor *selectedTabColor;
@property (retain) NSColor *unselectedTabColor;

@property (assign) BOOL needsResizeTabsToFitTotalWidth;

@end

NS_ASSUME_NONNULL_END
