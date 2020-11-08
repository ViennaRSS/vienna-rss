//
//  MMTabPasteboardItem.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/11/12.
//
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class MMAttachedTabBarButton;
@class MMTabBarView;

@interface MMTabPasteboardItem : NSPasteboardItem 

@property (assign) NSUInteger sourceIndex;

@end

NS_ASSUME_NONNULL_END
