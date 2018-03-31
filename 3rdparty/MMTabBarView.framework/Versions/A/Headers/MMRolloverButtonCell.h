//
//  MMRolloverButtonCell.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/8/12.
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MMRolloverButtonType)
{
    MMRolloverActionButton = 0,
    MMRolloverSwitchButton
};

@interface MMRolloverButtonCell : NSButtonCell 

@property (readonly) BOOL mouseHovered;
@property (strong) NSImage *rolloverImage;
@property (assign) MMRolloverButtonType rolloverButtonType;
@property (assign) BOOL simulateClickOnMouseHovered;

#pragma mark Tracking Area Support

- (void)addTrackingAreasForView:(NSView *)controlView inRect:(NSRect)cellFrame withUserInfo:(nullable NSDictionary *)userInfo mouseLocation:(NSPoint)mouseLocation;
- (void)mouseEntered:(NSEvent *)event;
- (void)mouseExited:(NSEvent *)event;

@end

NS_ASSUME_NONNULL_END
