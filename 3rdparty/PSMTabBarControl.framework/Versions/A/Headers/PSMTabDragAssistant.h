//
//  PSMTabDragAssistant.h
//  PSMTabBarControl
//
//  Created by John Pannell on 4/10/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

/*
   This class is a sigleton that manages the details of a tab drag and drop.  The details were beginning to overwhelm me when keeping all of this in the control and cells :-)
 */

#import <Cocoa/Cocoa.h>
#import "PSMTabBarControl.h"

#define kPSMTabDragAnimationSteps 8

@class PSMTabBarCell, PSMTabDragWindowController;

@interface PSMTabDragAssistant : NSObject {
	PSMTabBarControl					*_sourceTabBar;
	PSMTabBarControl					*_destinationTabBar;
	NSMutableSet						*_participatingTabBars;
	PSMTabBarCell						*_draggedCell;
	NSInteger							_draggedCellIndex;					// for snap back
	BOOL								_isDragging;

	// Support for dragging into new windows
	PSMTabDragWindowController		*_draggedTab;
	PSMTabDragWindowController		*_draggedView;
	NSSize								_dragWindowOffset;
	NSTimer							*_fadeTimer;
	BOOL								_centersDragWindows;
	PSMTabBarTearOffStyle			_currentTearOffStyle;

	// Animation
	NSTimer							*_animationTimer;
	NSMutableArray					*_sineCurveWidths;
	NSPoint							_currentMouseLoc;
	PSMTabBarCell						*_targetCell;
}

// Creation/destruction
+ (PSMTabDragAssistant *)sharedDragAssistant;

// Accessors
- (PSMTabBarControl *)sourceTabBar;
- (void)setSourceTabBar:(PSMTabBarControl *)tabBar;
- (PSMTabBarControl *)destinationTabBar;
- (void)setDestinationTabBar:(PSMTabBarControl *)tabBar;
- (PSMTabBarCell *)draggedCell;
- (void)setDraggedCell:(PSMTabBarCell *)cell;
- (NSInteger)draggedCellIndex;
- (void)setDraggedCellIndex:(NSInteger)value;
- (BOOL)isDragging;
- (void)setIsDragging:(BOOL)value;
- (NSPoint)currentMouseLoc;
- (void)setCurrentMouseLoc:(NSPoint)point;
- (PSMTabBarCell *)targetCell;
- (void)setTargetCell:(PSMTabBarCell *)cell;

// Functionality
- (void)startDraggingCell:(PSMTabBarCell *)cell fromTabBarControl:(PSMTabBarControl *)tabBarControl withMouseDownEvent:(NSEvent *)event;
- (void)draggingEnteredTabBarControl:(PSMTabBarControl *)tabBarControl atPoint:(NSPoint)mouseLoc;
- (void)draggingUpdatedInTabBarControl:(PSMTabBarControl *)tabBarControl atPoint:(NSPoint)mouseLoc;
- (void)draggingExitedTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)performDragOperation;
- (void)draggedImageEndedAt:(NSPoint)aPoint operation:(NSDragOperation)operation;
- (void)finishDrag;

- (void)draggingBeganAt:(NSPoint)aPoint;
- (void)draggingMovedTo:(NSPoint)aPoint;

// Animation
- (void)animateDrag:(NSTimer *)timer;
- (void)calculateDragAnimationForTabBarControl:(PSMTabBarControl *)tabBarControl;

// Placeholder
- (void)distributePlaceholdersInTabBarControl:(PSMTabBarControl *)tabBarControl withDraggedCell:(PSMTabBarCell *)cell;
- (void)distributePlaceholdersInTabBarControl:(PSMTabBarControl *)tabBarControl;
- (void)removeAllPlaceholdersFromTabBarControl:(PSMTabBarControl *)tabBarControl;

@end

void CGContextCopyWindowCaptureContentsToRect(void *grafport, CGRect rect, NSInteger cid, NSInteger wid, NSInteger zero);
OSStatus CGSSetWindowTransform(NSInteger cid, NSInteger wid, CGAffineTransform transform);

@interface NSApplication (CoreGraphicsUndocumented)
- (NSInteger)contextID;
@end
