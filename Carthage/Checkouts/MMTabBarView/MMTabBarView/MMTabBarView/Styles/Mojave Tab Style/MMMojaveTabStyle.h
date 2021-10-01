//
//  MMMojaveTabStyle.h
//  ------------------
//
//  Created by Jim Derry on 2018/07/30.
//  Changes released in accordance with MMTabBarView license.
//
//  For proper Mojave-like appearance, configure your MMTabBar like so:
//    - allow inactive tab closing
//    - only show close on hover
//    - use overflow menu NO
//    - automatically animates
//    - size to fit NO
//
// Features:
//    - Presents a nearly-faithful reproduction of Movaje tabs such as those
//      used on Safari and in Finder on all MMTabBarView supported systems.
//    - Dark mode is supported on macOS 10.14 systems and newer, when the
//      framework is built with the macOS 10.14 SDK or later.
//    - Dark mode is automatic. If the containing view is in dark mode, then
//      the style will be in dark mode.
//    - High contrast mode is supported on all modes.
//    - Proper, dimmed colors are used when the containing window is inactive.
//    - All images are drawn in code, reducing the framework size. Due to all
//      of the different highlight color combinations, this is a positive
//      feature, and of course supports future, higher-pixel-density displays.
//
// Limitations:
//    We are unable to replicate Mojave's tab bar style completely, due to lack
//    of supporting API in MMTabBarView. For example:
//    - Some of the close tab button hover colors are different in Mojave, but
//      MMTabBarView supports only a single image.
//    - MMTabBarView provides its own margins for the add tab button, so we
//      cannot occupy the entire space. Thus although we can implement Mojave's
//      hover behavor faithfully, we cannot emulate the mouse-down highlighting
//      properly.
//


#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif
#import "MMTabStyle.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMMojaveTabStyle : NSObject <MMTabStyle>

@property (assign) CGFloat leftMarginForTabBarView;

@property (assign) BOOL needsResizeTabsToFitTotalWidth;

@end

NS_ASSUME_NONNULL_END
