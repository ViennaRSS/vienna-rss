//
//  MMMojaveTabStyle+Assets.h
//  ------------------------
//
//  Provides assets for MMMojaveTabStyle
//  Created by Jim Derry on 2018/07/31.
//  Changes released in accordance with MMTabBarView license.
//
//  Because MMTabBarView supports back to 10.9 (this fork), we cannot use 
//  named colors in asset catalogues. The MMMojaveTabStyle should work 
//  transparently pre-10.14, and so we will build our own catalogue of assets.
//
//  Nearly all colors are hard-coded. Most of the Mojave-required named system
//  colors were introduced in macOS 10.14, and are not available in older
//  platforms supported by MMTabBarView.
//
//  In addition, NSImage assets are generated procedurally in order to support
//  current and future color tints and to maintain resolution independence.
//

#import "MMMojaveTabStyle.h"


@interface MMMojaveTabStyle (Assets)

// Appearances supported by this tab style, with room to grow in case Apple give us
// future surprises. Pre-Mojove will only use the MMMappearanceAquaLight; Mojave and
// later will choose the correct appearance based on the containing view's setting.
typedef NS_ENUM(NSInteger, MMMojaveTabStyleAppearance)
{
    MMMappearanceAquaLight,
    MMMappearanceAquaLightInactive,
    MMMappearanceAquaLightHighContrast,
    MMMappearanceAquaLightHighContrastInactive,
    MMMappearanceAquaDark,
    MMMappearanceAquaDarkInactive,
    MMMappearanceAquaDarkHighContrast,
    MMMappearanceAquaDarkHighContrastInactive,
};

// `assetForPart` will retrieve colors, images, and other assets via this enum as keys. Assets
// are also keyed to MMCloseButtonImageType, which can be cast to this type for fetching assets.
typedef NS_ENUM(NSInteger, MMMojaveTabStyleAsset)
{
    MMMbezelMiddle = 512,       // Interbutton color, right side.
    MMMbezelTop,                // Top bezel color.
    MMMbezelBottom,             // Bottom bezel color.

    MMMtabSelected,             // Tab selected color.
    MMMtabUnselected,           // Tab unselected color.
    MMMtabUnselectedHover,      // Tab hover color.
    
    MMMtabSelectedFont,         // Tab selected font color.
    MMMtabUnselectedFont,       // Tab unselected font color.
    MMMtabUnselectedHoverFont,  // Tab hover font color.
    
    MMMtabBarBackground,        // Tab bar background color (visible behind add button)

    MMMaddButtonImage,          // Add button, normal image.
    MMMaddButtonImageAlternate, // Add button, alternate/pressed image.
    MMMaddButtonImageRollover   // Add button, rollover image.
};


// Retrieve the required part as an NSColor for the given tabBarView.
- (NSColor *)colorForPart:(MMMojaveTabStyleAsset)part ofTabBarView:(MMTabBarView *)tabBarView;

// Retrieve the required part for the given tabBarView.
- (id)assetForPart:(MMMojaveTabStyleAsset)part ofTabBarView:(MMTabBarView *)tabBarView;

@end
