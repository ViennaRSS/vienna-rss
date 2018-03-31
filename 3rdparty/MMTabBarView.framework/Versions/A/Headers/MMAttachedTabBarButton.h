//
//  MMAttachedTabBarButton.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/5/12.
//
//

#import "MMTabBarButton.h"

#import "MMAttachedTabBarButtonCell.h"
#import "MMProgressIndicator.h"
#import "MMTabBarView.h"

NS_ASSUME_NONNULL_BEGIN

@class MMAttachedTabBarButtonCell;

@protocol MMTabStyle;

@interface MMAttachedTabBarButton : MMTabBarButton

// designated initializer
- (instancetype)initWithFrame:(NSRect)frame tabViewItem:(NSTabViewItem *)anItem NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;

// overidden accessors (casting)
@property (nullable, strong) __kindof MMAttachedTabBarButtonCell *cell;

#pragma mark Properties

@property (strong) NSTabViewItem *tabViewItem;
@property (assign) NSRect slidingFrame;
@property (readonly) BOOL isInAnimatedSlide;
@property (assign) BOOL isInDraggedSlide;
@property (readonly) BOOL isSliding;
@property (assign) BOOL isOverflowButton;

#pragma mark Drag Support

@property (readonly) NSRect draggingRect;
@property (readonly) NSImage *dragImage;

#pragma mark -
#pragma mark Animation Support

- (void)slideAnimationWillStart;
- (void)slideAnimationDidEnd;

@end

NS_ASSUME_NONNULL_END
