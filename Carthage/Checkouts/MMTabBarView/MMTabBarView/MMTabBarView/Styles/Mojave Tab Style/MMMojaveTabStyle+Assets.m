//
//  MMMojaveTabStyle+Assets.h
//  ------------------------
//
//  Provides assets for MMMojaveTabStyle
//  Created by Jim Derry on 2018/07/31.
//  Changes released in accordance with MMTabBarView license.
//

#import "MMMojaveTabStyle+Assets.h"
#import "MMTabBarView.h"
#if __has_feature(modules)
@import Darwin.Availability;
#else
#import "Availability.h"
#endif


@implementation MMMojaveTabStyle (Assets)

static NSDictionary<NSNumber*, NSDictionary<NSNumber*, id>*> *assets = nil;


- (NSColor *)colorForPart:(MMMojaveTabStyleAsset)part ofTabBarView:(MMTabBarView *)tabBarView
{
    return [self assetForPart:part ofTabBarView:tabBarView];
}


- (id)assetForPart:(MMMojaveTabStyleAsset)part ofTabBarView:(MMTabBarView *)tabBarView
{
    MMMojaveTabStyleAppearance mode = MMMappearanceAquaLight;

// If _compiled_ with less than 10.14, then the only selection available are the four AquaLight
// modes not ifdef'd out. However, if built with 10.14 or later, we may still deploy on 10.13,
// so ensure that we do the @available check, and force only the four AquaLight modes.
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101400
    if ( @available(macos 10.14, *) )
    {
        NSAppearanceName appearanceName = [tabBarView.superview.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameAccessibilityHighContrastAqua, NSAppearanceNameDarkAqua, NSAppearanceNameAccessibilityHighContrastDarkAqua]];

        if ([appearanceName isEqualToString:NSAppearanceNameAccessibilityHighContrastDarkAqua])
        {
            mode = ([tabBarView isWindowActive ]) ? MMMappearanceAquaDarkHighContrast : MMMappearanceAquaDarkHighContrastInactive;
        }
        else if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua])
        {
            mode = ([tabBarView isWindowActive ]) ? MMMappearanceAquaDark : MMMappearanceAquaDarkInactive;
        }
        else if ([appearanceName isEqualToString:NSAppearanceNameAccessibilityHighContrastAqua])
        {
            mode = ([tabBarView isWindowActive ]) ? MMMappearanceAquaLightHighContrast : MMMappearanceAquaLightHighContrastInactive;
        }
        else
        {
            mode = ([tabBarView isWindowActive ]) ? MMMappearanceAquaLight : MMMappearanceAquaLightInactive;
        }
    }
    else
    {
#endif
		if ( @available(macos 10.10, *) ) {
			if ( NSWorkspace.sharedWorkspace.accessibilityDisplayShouldIncreaseContrast )
				mode = tabBarView.isWindowActive ? MMMappearanceAquaLightHighContrast : MMMappearanceAquaLightHighContrastInactive;
			else
				mode = tabBarView.isWindowActive ? MMMappearanceAquaLight : MMMappearanceAquaLightInactive;
		} else {
			mode = (tabBarView.isWindowActive) ? MMMappearanceAquaLight : MMMappearanceAquaLightInactive;
		}
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101400
    }
#endif

    return self.assets[@(mode)][@(part)] ? : self.assets[@(MMMappearanceAquaLight)][@(part)];
}

inline static NSColor* labelColor(void)
{
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101400
	if ( @available(macos 10.10, *) )
	{
		return NSColor.labelColor;
	}
#endif
	return NSColor.textColor;
}

- (NSDictionary<NSNumber*, NSDictionary<NSNumber*, id>*> *)assets
{

    if ( !assets )
        assets = @{
             @(MMMappearanceAquaLight) : @{
                     @(MMMbezelMiddle)            : [NSColor colorWithSRGBRed:0.667 green:0.671 blue:0.671 alpha:1.0],
                     @(MMMbezelTop)               : [NSColor colorWithSRGBRed:0.682 green:0.678 blue:0.678 alpha:1.0],
                     @(MMMbezelBottom)            : [NSColor colorWithSRGBRed:0.655 green:0.651 blue:0.651 alpha:1.0],
    
                     @(MMMtabSelected)            : [NSColor colorWithSRGBRed:0.808 green:0.812 blue:0.816 alpha:1.0],
                     @(MMMtabUnselected)          : [NSColor colorWithSRGBRed:0.725 green:0.725 blue:0.725 alpha:1.0],
                     @(MMMtabUnselectedHover)     : [NSColor colorWithSRGBRed:0.655 green:0.655 blue:0.655 alpha:1.0],

                     @(MMMtabSelectedFont)        : NSColor.textColor,
                     @(MMMtabUnselectedFont)      : labelColor(),
                     @(MMMtabUnselectedHoverFont) : NSColor.textColor,
                     
                     @(MMMtabBarBackground)       : [NSColor colorWithSRGBRed:0.710 green:0.706 blue:0.710 alpha:1.0],

                     @(MMMaddButtonImage)                   : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.310 green:0.310 blue:0.310 alpha:1.0]],
                     @(MMMaddButtonImageAlternate)          : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.380 green:0.380 blue:0.380 alpha:1.0]],
                     @(MMMaddButtonImageRollover)           : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.310 green:0.310 blue:0.310 alpha:1.0]],

                     @(MMCloseButtonImageTypeStandard)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.330 green:0.330 blue:0.330 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeRollover)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.330 green:0.330 blue:0.330 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.590 green:0.590 blue:0.590 alpha:1.0]],
                     @(MMCloseButtonImageTypePressed)       : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.330 green:0.330 blue:0.330 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.490 green:0.490 blue:0.490 alpha:1.0]],

                     @(MMCloseButtonImageTypeDirty)         : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.600 green:0.600 blue:0.600 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyRollover) : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.490 green:0.490 blue:0.490 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyPressed)  : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.330 green:0.330 blue:0.330 alpha:1.0] backgroundColor:nil],
                     },

             @(MMMappearanceAquaLightInactive) : @{
                     @(MMMbezelMiddle)            : [NSColor colorWithSRGBRed:0.824 green:0.824 blue:0.824 alpha:1.0],
                     @(MMMbezelTop)               : [NSColor colorWithSRGBRed:0.820 green:0.820 blue:0.820 alpha:1.0],
                     @(MMMbezelBottom)            : [NSColor colorWithSRGBRed:0.820 green:0.820 blue:0.820 alpha:1.0],
    
                     @(MMMtabSelected)            : [NSColor colorWithSRGBRed:0.965 green:0.965 blue:0.965 alpha:1.0],
                     @(MMMtabUnselected)          : [NSColor colorWithSRGBRed:0.867 green:0.867 blue:0.867 alpha:1.0],
                     @(MMMtabUnselectedHover)     : [NSColor colorWithSRGBRed:0.776 green:0.776 blue:0.776 alpha:1.0],

                     @(MMMtabSelectedFont)        : NSColor.disabledControlTextColor,
                     @(MMMtabUnselectedFont)      : NSColor.disabledControlTextColor,
                     @(MMMtabUnselectedHoverFont) : NSColor.disabledControlTextColor,

                     @(MMMtabBarBackground)   : [NSColor colorWithSRGBRed:0.863 green:0.863 blue:0.863 alpha:1.0],

                     @(MMMaddButtonImage)                   : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.620 green:0.620 blue:0.620 alpha:1.0]],
                     @(MMMaddButtonImageAlternate)          : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.620 green:0.620 blue:0.620 alpha:1.0]],
                     @(MMMaddButtonImageRollover)           : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.620 green:0.620 blue:0.620 alpha:1.0]],

                     @(MMCloseButtonImageTypeStandard)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.580 green:0.580 blue:0.580 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeRollover)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.580 green:0.580 blue:0.580 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.740 green:0.740 blue:0.740 alpha:1.0]],
                     @(MMCloseButtonImageTypePressed)       : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.580 green:0.580 blue:0.580 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.490 green:0.490 blue:0.490 alpha:1.0]],

                     @(MMCloseButtonImageTypeDirty)         : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.810 green:0.810 blue:0.810 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyRollover) : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.740 green:0.740 blue:0.740 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyPressed)  : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.330 green:0.330 blue:0.330 alpha:1.0] backgroundColor:nil],
                     },

             @(MMMappearanceAquaLightHighContrast) : @{
                     @(MMMbezelMiddle)            : [NSColor colorWithSRGBRed:0.576 green:0.580 blue:0.576 alpha:1.0],
                     @(MMMbezelTop)               : [NSColor colorWithSRGBRed:0.584 green:0.584 blue:0.584 alpha:1.0],
                     @(MMMbezelBottom)            : [NSColor colorWithSRGBRed:0.565 green:0.565 blue:0.565 alpha:1.0],
    
                     @(MMMtabSelected)            : [NSColor colorWithSRGBRed:0.824 green:0.824 blue:0.827 alpha:1.0],
                     @(MMMtabUnselected)          : [NSColor colorWithSRGBRed:0.741 green:0.741 blue:0.741 alpha:1.0],
                     @(MMMtabUnselectedHover)     : [NSColor colorWithSRGBRed:0.667 green:0.667 blue:0.663 alpha:1.0],
                     
                     @(MMMtabSelectedFont)        : NSColor.textColor,
                     @(MMMtabUnselectedFont)      : labelColor(),
                     @(MMMtabUnselectedHoverFont) : NSColor.textColor,
                     
                     @(MMMtabBarBackground)   : [NSColor colorWithSRGBRed:0.741 green:0.741 blue:0.741 alpha:1.0],

                     @(MMMaddButtonImage)                   : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.420 green:0.420 blue:0.420 alpha:1.0]],
                     @(MMMaddButtonImageAlternate)          : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.420 green:0.420 blue:0.420 alpha:1.0]],
                     @(MMMaddButtonImageRollover)           : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.420 green:0.420 blue:0.420 alpha:1.0]],

                     @(MMCloseButtonImageTypeStandard)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.013 green:0.013 blue:0.013 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeRollover)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.180 green:0.180 blue:0.180 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.530 green:0.530 blue:0.530 alpha:1.0]],
                     @(MMCloseButtonImageTypePressed)       : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.004 green:0.004 blue:0.004 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.330 green:0.330 blue:0.330 alpha:1.0]],

                     @(MMCloseButtonImageTypeDirty)         : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.480 green:0.480 blue:0.480 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyRollover) : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.405 green:0.405 blue:0.405 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyPressed)  : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.330 green:0.330 blue:0.330 alpha:1.0] backgroundColor:nil],
                     },

             @(MMMappearanceAquaLightHighContrastInactive) : @{
                     @(MMMbezelMiddle)            : [NSColor colorWithSRGBRed:0.820 green:0.820 blue:0.820 alpha:1.0],
                     @(MMMbezelTop)               : [NSColor colorWithSRGBRed:0.675 green:0.675 blue:0.675 alpha:1.0],
                     @(MMMbezelBottom)            : [NSColor colorWithSRGBRed:0.675 green:0.675 blue:0.675 alpha:1.0],
    
                     @(MMMtabSelected)            : [NSColor colorWithSRGBRed:0.965 green:0.965 blue:0.965 alpha:1.0],
                     @(MMMtabUnselected)          : [NSColor colorWithSRGBRed:0.867 green:0.867 blue:0.867 alpha:1.0],
                     @(MMMtabUnselectedHover)     : [NSColor colorWithSRGBRed:0.776 green:0.776 blue:0.776 alpha:1.0],
                     
                     @(MMMtabSelectedFont)        : NSColor.disabledControlTextColor,
                     @(MMMtabUnselectedFont)      : NSColor.disabledControlTextColor,
                     @(MMMtabUnselectedHoverFont) : NSColor.disabledControlTextColor,

                     @(MMMtabBarBackground)   : [NSColor colorWithSRGBRed:0.867 green:0.867 blue:0.867 alpha:1.0],

                     @(MMMaddButtonImage)                   : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.640 green:0.640 blue:0.640 alpha:1.0]],
                     @(MMMaddButtonImageAlternate)          : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.640 green:0.640 blue:0.640 alpha:1.0]],
                     @(MMMaddButtonImageRollover)           : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.640 green:0.640 blue:0.640 alpha:1.0]],

                     @(MMCloseButtonImageTypeStandard)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.490 green:0.490 blue:0.490 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeRollover)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.490 green:0.490 blue:0.490 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.700 green:0.700 blue:0.700 alpha:1.0]],
                     @(MMCloseButtonImageTypePressed)       : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.490 green:0.490 blue:0.490 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.330 green:0.330 blue:0.330 alpha:1.0]],

                     @(MMCloseButtonImageTypeDirty)         : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.710 green:0.710 blue:0.710 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyRollover) : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.640 green:0.640 blue:0.640 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyPressed)  : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.330 green:0.330 blue:0.330 alpha:1.0] backgroundColor:nil],
                     },

             @(MMMappearanceAquaDark) : @{
                     @(MMMbezelMiddle)            : [NSColor colorWithSRGBRed:0.314 green:0.314 blue:0.314 alpha:1.0],
                     @(MMMbezelTop)               : [NSColor colorWithSRGBRed:0.322 green:0.322 blue:0.322 alpha:1.0],
                     @(MMMbezelBottom)            : [NSColor colorWithSRGBRed:0.000 green:0.000 blue:0.000 alpha:1.0],
    
                     @(MMMtabSelected)            : [NSColor colorWithSRGBRed:0.176 green:0.176 blue:0.176 alpha:1.0],
                     @(MMMtabUnselected)          : [NSColor colorWithSRGBRed:0.122 green:0.122 blue:0.122 alpha:1.0],
                     @(MMMtabUnselectedHover)     : [NSColor colorWithSRGBRed:0.110 green:0.110 blue:0.110 alpha:1.0],

                     @(MMMtabSelectedFont)        : NSColor.textColor,
                     @(MMMtabUnselectedFont)      : NSColor.disabledControlTextColor,
                     @(MMMtabUnselectedHoverFont) : NSColor.textColor,
                     
                     @(MMMtabBarBackground)   : [NSColor colorWithSRGBRed:0.112 green:0.112 blue:0.112 alpha:1.0],

                     @(MMMaddButtonImage)                   : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.510 green:0.510 blue:0.510 alpha:1.0]],
                     @(MMMaddButtonImageAlternate)          : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.280 green:0.280 blue:0.280 alpha:1.0]],
                     @(MMMaddButtonImageRollover)           : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.510 green:0.510 blue:0.510 alpha:1.0]],

                     @(MMCloseButtonImageTypeStandard)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.620 green:0.620 blue:0.620 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeRollover)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.620 green:0.620 blue:0.620 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.260 green:0.260 blue:0.260 alpha:1.0]],
                     @(MMCloseButtonImageTypePressed)       : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.850 green:0.850 blue:0.850 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.330 green:0.330 blue:0.330 alpha:1.0]],

                     @(MMCloseButtonImageTypeDirty)         : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.520 green:0.520 blue:0.520 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyRollover) : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.620 green:0.620 blue:0.620 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyPressed)  : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.750 green:0.750 blue:0.750 alpha:1.0] backgroundColor:nil],
                     },

             @(MMMappearanceAquaDarkInactive) : @{
                     @(MMMbezelMiddle)            : [NSColor colorWithSRGBRed:0.294 green:0.294 blue:0.294 alpha:1.0],
                     @(MMMbezelTop)               : [NSColor colorWithSRGBRed:0.294 green:0.294 blue:0.294 alpha:1.0],
                     @(MMMbezelBottom)            : [NSColor colorWithSRGBRed:0.000 green:0.000 blue:0.000 alpha:1.0],
     
                     @(MMMtabSelected)            : [NSColor colorWithSRGBRed:0.176 green:0.176 blue:0.176 alpha:1.0],
                     @(MMMtabUnselected)          : [NSColor colorWithSRGBRed:0.122 green:0.122 blue:0.122 alpha:1.0],
                     @(MMMtabUnselectedHover)     : [NSColor colorWithSRGBRed:0.110 green:0.110 blue:0.110 alpha:1.0],

                     @(MMMtabSelectedFont)        : NSColor.disabledControlTextColor,
                     @(MMMtabUnselectedFont)      : NSColor.disabledControlTextColor,
                     @(MMMtabUnselectedHoverFont) : NSColor.disabledControlTextColor,

                     @(MMMtabBarBackground)   : [NSColor colorWithSRGBRed:0.112 green:0.112 blue:0.112 alpha:1.0],

                     @(MMMaddButtonImage)                   : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.190 green:0.190 blue:0.190 alpha:1.0]],
                     @(MMMaddButtonImageAlternate)          : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.190 green:0.190 blue:0.190 alpha:1.0]],
                     @(MMMaddButtonImageRollover)           : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.190 green:0.190 blue:0.190 alpha:1.0]],

                     @(MMCloseButtonImageTypeStandard)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.260 green:0.260 blue:0.260 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeRollover)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.260 green:0.260 blue:0.260 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypePressed)       : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.260 green:0.260 blue:0.260 alpha:1.0] backgroundColor:nil],

                     @(MMCloseButtonImageTypeDirty)         : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.290 green:0.290 blue:0.290 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyRollover) : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.290 green:0.290 blue:0.290 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeDirtyPressed)  : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.290 green:0.290 blue:0.290 alpha:1.0] backgroundColor:nil],
                     },

             @(MMMappearanceAquaDarkHighContrast) : @{
                     @(MMMbezelMiddle)            : [NSColor colorWithSRGBRed:0.608 green:0.608 blue:0.608 alpha:1.0],
                     @(MMMbezelTop)               : [NSColor colorWithSRGBRed:0.361 green:0.357 blue:0.361 alpha:1.0],
                     @(MMMbezelBottom)            : [NSColor colorWithSRGBRed:0.349 green:0.349 blue:0.349 alpha:1.0],
    
                     @(MMMtabSelected)            : [NSColor colorWithSRGBRed:0.176 green:0.176 blue:0.176 alpha:1.0],
                     @(MMMtabUnselected)          : [NSColor colorWithSRGBRed:0.122 green:0.122 blue:0.122 alpha:1.0],
                     @(MMMtabUnselectedHover)     : [NSColor colorWithSRGBRed:0.110 green:0.110 blue:0.110 alpha:1.0],

                     @(MMMtabSelectedFont)        : NSColor.textColor,
                     @(MMMtabUnselectedFont)      : NSColor.disabledControlTextColor,
                     @(MMMtabUnselectedHoverFont) : NSColor.textColor,
                     
					 @(MMMtabBarBackground)   : [NSColor colorWithSRGBRed:0.112 green:0.112 blue:0.112 alpha:1.0],

                     @(MMMaddButtonImage)                   : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.520 green:0.520 blue:0.520 alpha:1.0]],
                     @(MMMaddButtonImageAlternate)          : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.180 green:0.180 blue:0.180 alpha:1.0]],
                     @(MMMaddButtonImageRollover)           : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.520 green:0.520 blue:0.520 alpha:1.0]],

                     @(MMCloseButtonImageTypeStandard)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.780 green:0.780 blue:0.780 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeRollover)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.780 green:0.780 blue:0.780 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.420 green:0.420 blue:0.420 alpha:1.0]],
                     @(MMCloseButtonImageTypePressed)       : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.780 green:0.780 blue:0.780 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.590 green:0.590 blue:0.590 alpha:1.0]],

					 @(MMCloseButtonImageTypeDirty)         : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.520 green:0.520 blue:0.520 alpha:1.0] backgroundColor:nil],
					 @(MMCloseButtonImageTypeDirtyRollover) : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.620 green:0.620 blue:0.620 alpha:1.0] backgroundColor:nil],
					 @(MMCloseButtonImageTypeDirtyPressed)  : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.750 green:0.750 blue:0.750 alpha:1.0] backgroundColor:nil],
                     },

             @(MMMappearanceAquaDarkHighContrastInactive) : @{
                     @(MMMbezelMiddle)            : [NSColor colorWithSRGBRed:0.310 green:0.310 blue:0.310 alpha:1.0],
                     @(MMMbezelTop)               : [NSColor colorWithSRGBRed:0.314 green:0.314 blue:0.314 alpha:1.0],
                     @(MMMbezelBottom)            : [NSColor colorWithSRGBRed:0.325 green:0.325 blue:0.325 alpha:1.0],
    
                     @(MMMtabSelected)            : [NSColor colorWithSRGBRed:0.176 green:0.176 blue:0.176 alpha:1.0],
                     @(MMMtabUnselected)          : [NSColor colorWithSRGBRed:0.122 green:0.122 blue:0.122 alpha:1.0],
                     @(MMMtabUnselectedHover)     : [NSColor colorWithSRGBRed:0.110 green:0.110 blue:0.110 alpha:1.0],

                     @(MMMtabSelectedFont)        : NSColor.disabledControlTextColor,
                     @(MMMtabUnselectedFont)      : NSColor.disabledControlTextColor,
                     @(MMMtabUnselectedHoverFont) : NSColor.disabledControlTextColor,

					 @(MMMtabBarBackground)   : [NSColor colorWithSRGBRed:0.112 green:0.112 blue:0.112 alpha:1.0],

                     @(MMMaddButtonImage)                   : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.190 green:0.190 blue:0.190 alpha:1.0]],
                     @(MMMaddButtonImageAlternate)          : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.190 green:0.190 blue:0.190 alpha:1.0]],
                     @(MMMaddButtonImageRollover)           : [self addTabImageWithIconColor:[NSColor colorWithSRGBRed:0.190 green:0.190 blue:0.190 alpha:1.0]],

                     @(MMCloseButtonImageTypeStandard)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.350 green:0.350 blue:0.350 alpha:1.0] backgroundColor:nil],
                     @(MMCloseButtonImageTypeRollover)      : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.350 green:0.350 blue:0.350 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.190 green:0.190 blue:0.190 alpha:1.0]],
                     @(MMCloseButtonImageTypePressed)       : [self closeTabImageWithIconColor:[NSColor colorWithSRGBRed:0.350 green:0.350 blue:0.350 alpha:1.0] backgroundColor:[NSColor colorWithSRGBRed:0.190 green:0.190 blue:0.190 alpha:1.0]],

					 @(MMCloseButtonImageTypeDirty)         : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.290 green:0.290 blue:0.290 alpha:1.0] backgroundColor:nil],
					 @(MMCloseButtonImageTypeDirtyRollover) : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.290 green:0.290 blue:0.290 alpha:1.0] backgroundColor:nil],
					 @(MMCloseButtonImageTypeDirtyPressed)  : [self closeDirtyTabImageWithIconColor:[NSColor colorWithSRGBRed:0.290 green:0.290 blue:0.290 alpha:1.0] backgroundColor:nil],
                     }
             };

    return assets;
}


- (NSImage *)closeTabImageWithIconColor:(NSColor * _Nonnull)iconColor backgroundColor:(NSColor * _Nullable)backgroundColor
{
    NSImage *result = [NSImage imageWithSize:NSMakeSize(16.0,16.0)
                                     flipped:YES
                              drawingHandler:^BOOL(NSRect dstRect)
                       {
                           if ( backgroundColor )
                           {
                               NSBezierPath *bezier = [NSBezierPath bezierPathWithRoundedRect:dstRect
                                                                                      xRadius:2.0
                                                                                      yRadius:2.0];
                               [backgroundColor set];
                               [bezier fill];
                           }

                           NSBezierPath *icon = NSBezierPath.bezierPath;

                           [iconColor set];
                           [icon moveToPoint:NSMakePoint(NSMinX(dstRect)+4.5, NSMinY(dstRect)+4.5)];
                           [icon lineToPoint:NSMakePoint(NSMaxX(dstRect)-4.5, NSMaxY(dstRect)-4.5)];
                           [icon moveToPoint:NSMakePoint(NSMaxX(dstRect)-4.5, NSMinY(dstRect)+4.5)];
                           [icon lineToPoint:NSMakePoint(NSMinX(dstRect)+4.5, NSMaxY(dstRect)-4.5)];
                           [icon stroke];

                           return YES;
                       }];
    
    return result;
}


- (NSImage *)closeDirtyTabImageWithIconColor:(NSColor * _Nonnull)iconColor backgroundColor:(NSColor * _Nullable)backgroundColor
{
    NSImage *result = [NSImage imageWithSize:NSMakeSize(16.0,16.0)
                                     flipped:YES
                              drawingHandler:^BOOL(NSRect dstRect)
                       {
                           if ( backgroundColor )
                           {
                               NSBezierPath *bezier = [NSBezierPath bezierPathWithRoundedRect:dstRect
                                                                                      xRadius:2.0
                                                                                      yRadius:2.0];
                               [backgroundColor set];
                               [bezier fill];
                           }

                           CGFloat dia = 12.0;
                           CGFloat delta = (dstRect.size.width - dia) / 2;

                           NSBezierPath *outerCircle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(delta, delta, dia, dia)];
                           [iconColor set];
                           [outerCircle fill];

                           dia = 4.0;
                           delta = (dstRect.size.width - dia) / 2;
                           NSBezierPath *innerCircle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(delta, delta, dia, dia)];
                           [[NSColor colorWithSRGBRed:0.960 green:0.960 blue:0.960 alpha:1.0] set];
                           [innerCircle fill];

                           return YES;
                       }];

    return result;
}


- (NSImage *)addTabImageWithIconColor:(NSColor * _Nonnull)iconColor
{
    NSImage *result = [NSImage imageWithSize:NSMakeSize(18.0,18.0)
                                     flipped:YES
                              drawingHandler:^BOOL(NSRect dstRect)
                       {
                           NSBezierPath *icon = NSBezierPath.bezierPath;

                           [iconColor set];
                           CGFloat minX = NSMinX(dstRect);
                           CGFloat maxX = NSMaxX(dstRect);
                           CGFloat minY = NSMinY(dstRect);
                           CGFloat maxY = NSMaxY(dstRect);
                           CGFloat x1 = (maxX - minX) / 2 - 0.5;
                           CGFloat y1 = minY + 3.5;
                           CGFloat dy1 = maxY - 3.5;
                           CGFloat x2 = minX + 3.5;
                           CGFloat dx2 = maxX - 3.5;
                           CGFloat y2 = (maxY - minY) / 2 - 0.5;

                           [icon moveToPoint:NSMakePoint( x1, y1 )];
                           [icon lineToPoint:NSMakePoint( x1, dy1 )];
                           [icon moveToPoint:NSMakePoint( x2, y2 )];
                           [icon lineToPoint:NSMakePoint( dx2, y2 )];
                           [icon stroke];

                           return YES;
                       }];

    return result;
}

-(void)resetColors
{
    assets = nil;
}

@end
