//
//  MMTabBarButton.Common.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 23/05/15.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MMCloseButtonImageType)
{
    MMCloseButtonImageTypeStandard = 0,
    MMCloseButtonImageTypeRollover,
    MMCloseButtonImageTypePressed,
    MMCloseButtonImageTypeDirty,
    MMCloseButtonImageTypeDirtyRollover,
    MMCloseButtonImageTypeDirtyPressed
};

typedef NS_ENUM(NSUInteger,MMTabStateMask)
{
	MMTab_LeftIsSelectedMask		= 1 << 2,
	MMTab_RightIsSelectedMask		= 1 << 3,
    
    MMTab_LeftIsSliding             = 1 << 4,
    MMTab_RightIsSliding            = 1 << 5,
    
    MMTab_PlaceholderOnLeft         = 1 << 6,
    MMTab_PlaceholderOnRight        = 1 << 7,
    
	MMTab_PositionLeftMask			= 1 << 8,
	MMTab_PositionMiddleMask		= 1 << 9,
	MMTab_PositionRightMask         = 1 << 10,
	MMTab_PositionSingleMask		= 1 << 11
};

NS_ASSUME_NONNULL_END
