//
//  MMTabDragAssistant.h
//  MMTabBarView
//
//  Created by John Pannell on 4/10/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

/*
   This class is a sigleton that manages the details of a tab drag and drop.  The details were beginning to overwhelm me when keeping all of this in the control and buttons :-)
 */

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif
#import "MMTabBarView.h"

NS_ASSUME_NONNULL_BEGIN

@class MMTabDragWindowController, MMTabPasteboardItem;

extern NSString *AttachedTabBarButtonUTI;

@interface MMTabDragAssistant : NSObject <NSAnimationDelegate>

// Creation/destruction
+ (instancetype)sharedDragAssistant;

#pragma mark Properties

@property (nullable, strong) MMTabBarView *sourceTabBar;
@property (nullable, strong) MMAttachedTabBarButton *attachedTabBarButton;
@property (nullable, strong) MMTabPasteboardItem *pasteboardItem;
@property (nullable, strong) MMTabBarView *destinationTabBar;
@property (assign) BOOL isDragging;
@property (assign) NSPoint currentMouseLocation;

@property (assign) BOOL isSliding;

#pragma mark Dragging Source Handling

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context ofTabBarView:(MMTabBarView *)tabBarView;

- (BOOL)shouldStartDraggingAttachedTabBarButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView withMouseDownEvent:(NSEvent *)event;

- (void)startDraggingAttachedTabBarButton:(MMAttachedTabBarButton *)aButton fromTabBarView:(MMTabBarView *)tabBarView withMouseDownEvent:(NSEvent *)event;

- (void)draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint withTabBarView:(MMTabBarView *)tabBarView;
- (void)draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint;
- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation;

#pragma mark Dragging Destination Handling

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender inTabBarView:(MMTabBarView *)tabBarView;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender inTabBarView:(MMTabBarView *)tabBarView;

- (void)draggingExitedTabBarView:(MMTabBarView *)tabBarView draggingInfo:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender forTabBarView:(MMTabBarView *)tabBarView;

- (void)finishDragOfPasteboardItem:(MMTabPasteboardItem *)pasteboardItem;

#pragma mark Dragging Helpers

- (NSUInteger)destinationIndexForButton:(MMAttachedTabBarButton *)aButton atPoint:(NSPoint)aPoint inTabBarView:(MMTabBarView *)tabBarView;

@end

void CGContextCopyWindowCaptureContentsToRect(void *grafport, CGRect rect, NSInteger cid, NSInteger wid, NSInteger zero);
OSStatus CGSSetWindowTransform(NSInteger cid, NSInteger wid, CGAffineTransform transform);

@interface NSApplication (CoreGraphicsUndocumented)
- (NSInteger)contextID;
@end

NS_ASSUME_NONNULL_END
