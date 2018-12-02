//
//  MMTabDragAssistant.m
//  MMTabBarView
//
//  Created by John Pannell on 4/10/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

#import "MMTabDragAssistant.h"
#import "MMAttachedTabBarButton.h"
#import "MMTabStyle.h"
#import "MMTabDragWindowController.h"
#import "MMTabPasteboardItem.h"
#import "MMSlideButtonsAnimation.h"
#import "NSView+MMTabBarViewExtensions.h"

#import "MMTabBarView.Private.h"
#import "MMTabBarButton.Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMTabDragAssistant ()
@end

NSString *AttachedTabBarButtonUTI = @"de.monscheuer.mmtabbarview.attachedbutton";

@implementation MMTabDragAssistant
{
        // Support for dragging into new windows
	MMTabDragWindowController		*_draggedTab;
	MMTabDragWindowController		*_draggedView;
	NSSize							_dragWindowOffset;
	NSTimer							*_fadeTimer;
	BOOL							_centersDragWindows;
	MMTabBarTearOffStyle			_currentTearOffStyle;

        // Animation
    MMSlideButtonsAnimation         *_slideButtonsAnimation;
}

static MMTabDragAssistant *sharedDragAssistant = nil;

#pragma mark -
#pragma mark Creation/Destruction

+ (instancetype)sharedDragAssistant {
	if (!sharedDragAssistant) {
		sharedDragAssistant = [[MMTabDragAssistant alloc] init];
	}

	return sharedDragAssistant;
}

- (instancetype)init {
	if ((self = [super init])) {
		_destinationTabBar = nil;
		_isDragging = NO;
        _slideButtonsAnimation = nil;
        
        _isSliding = NO;
	}

	return self;
}

- (void)dealloc {

    if (_slideButtonsAnimation) {
        [_slideButtonsAnimation stopAnimation];
        _slideButtonsAnimation = nil;
    }
    
}

#pragma mark -
#pragma mark Dragging Source Handling

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context ofTabBarView:(MMTabBarView *)tabBarView {
    if (context == NSDraggingContextOutsideApplication)
        return NSDragOperationNone;
    else if (context == NSDraggingContextWithinApplication)
        return NSDragOperationMove;

    return NSDragOperationNone;
}

- (BOOL)shouldStartDraggingAttachedTabBarButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView withMouseDownEvent:(NSEvent *)event {
    return [aButton mm_dragShouldBeginFromMouseDown:event withExpiration:NSDate.distantFuture];
}

- (void)startDraggingAttachedTabBarButton:(MMAttachedTabBarButton *)aButton fromTabBarView:(MMTabBarView *)tabBarView withMouseDownEvent:(NSEvent *)event {

	NSRect buttonFrame = aButton.frame;
	if (tabBarView.isFlipped) {
		buttonFrame.origin.y += buttonFrame.size.height;
	}
        
    [self _dragAttachedTabBarButton:aButton ofTabBarView:tabBarView at:aButton.frame.origin event:event source:tabBarView];
}

- (void)draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint withTabBarView:(MMTabBarView *)tabBarView {

	if (_draggedTab) {
		[_draggedTab.window setFrameTopLeftPoint:screenPoint];
		[_draggedTab.window orderFront:nil];

		if (tabBarView.tabView.numberOfTabViewItems == 1) {
			MMTabPasteboardItem* const pasteboardItem = self.pasteboardItem;
			if (pasteboardItem != nil) {
				[self _draggingExitedTabBarView:tabBarView withPasteboardItem:pasteboardItem];
			}
		}
	}
}

- (void)draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint {
	if (_draggedTab) {
		if (_centersDragWindows) {
			if (_draggedTab.isAnimating) {
				return;
			}
			//Ignore aPoint, as it seems to give wacky values
			NSRect frame = _draggedTab.window.frame;
			frame.origin = screenPoint; //[NSEvent mouseLocation];
			frame.origin.x -= frame.size.width / 2;
			frame.origin.y -= frame.size.height / 2;
			[_draggedTab.window setFrame:frame display:NO];
		} else {
			[_draggedTab.window setFrameTopLeftPoint:screenPoint];
		}

		if (_draggedView) {
			//move the view representation with the tab
			//the relative position of the dragged view window will be different
			//depending on the position of the tab bar relative to the controlled tab view
			screenPoint.y -= _draggedTab.window.frame.size.height;
			screenPoint.x -= _dragWindowOffset.width;
			screenPoint.y += _dragWindowOffset.height;
			[_draggedView.window setFrameTopLeftPoint:screenPoint];
		}
	}
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {

    MMTabPasteboardItem *pasteboardItem = self.pasteboardItem;
    
	NSTabView *sourceTabView = _sourceTabBar.tabView;
	NSUInteger sourceIndex = pasteboardItem.sourceIndex;

    if (self.isDragging) {   // means there was not a successful drop (performDragOperation)
    
        id <MMTabBarViewDelegate> sourceDelegate = _sourceTabBar.delegate;

        //split off the dragged tab into a new window
		MMAttachedTabBarButton* const tabBarButton = _attachedTabBarButton;
		if (tabBarButton != nil) {
			if (self.destinationTabBar == nil &&
				sourceDelegate && [sourceDelegate respondsToSelector:@selector(tabView:newTabBarViewForDraggedTabViewItem:atPoint:)]) {

				NSTabViewItem* const tabViewItem = tabBarButton.tabViewItem;
				if (tabViewItem != nil) {
					MMTabBarView *tabBarView = [sourceDelegate tabView:sourceTabView newTabBarViewForDraggedTabViewItem:tabViewItem atPoint:screenPoint];

					if (tabBarView) {

						// remove tab view item from source tab view
						[_sourceTabBar removeTabViewItem:tabViewItem];
						[_sourceTabBar update:NO];

						// insert the dragged button and tab view to new window
						[tabBarView insertAttachedButton:tabBarButton atTabItemIndex:0];

						[tabBarView update:NO];   //make sure the new tab is set in the correct position

						if (_currentTearOffStyle == MMTabBarTearOffAlphaWindow) {
							[tabBarView.window makeKeyAndOrderFront:nil];
						} else {
							//center the window over where we ended dragging
							NSWindow* const window = tabBarView.window;
							if (window != nil) {
								[self _expandWindow:window atPoint:NSEvent.mouseLocation];
							}
						}

						if ([sourceDelegate respondsToSelector:@selector(tabView:didDropTabViewItem:inTabBarView:)]) {
							[sourceDelegate tabView:sourceTabView didDropTabViewItem:tabViewItem inTabBarView:tabBarView];
						}

						[tabBarView setNeedsUpdate:YES];
					} else {
						NSLog(@"Delegate returned no control to add to.");
						[_sourceTabBar insertAttachedButton:tabBarButton atTabItemIndex:sourceIndex];
					}
				}
			} else {
				// put button back
				[_sourceTabBar insertAttachedButton:tabBarButton atTabItemIndex:sourceIndex];
			}
		}

		[NSNotificationCenter.defaultCenter postNotificationName:MMTabDragDidEndNotification object:nil];

		[self finishDragOfPasteboardItem:pasteboardItem];
    } 
}

#pragma mark -
#pragma mark Dragging Destination Handling

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender inTabBarView:(MMTabBarView *)tabBarView {

    id <MMTabBarViewDelegate> delegate = tabBarView.delegate;

    MMTabPasteboardItem *pasteboardItem = [self _tabPasteboardItemOfDraggingInfo:sender];
    if (!pasteboardItem)
        return NSDragOperationNone;
    
	MMAttachedTabBarButton* const tabBarButton = _attachedTabBarButton;
    if (tabBarButton == nil)
        return NSDragOperationNone;

    NSPoint mouseLoc = [tabBarView convertPoint:sender.draggingLocation fromView:nil];
    NSUInteger destinationIndex = [self _destinationIndexForButton:tabBarButton atPoint:mouseLoc inTabBarView:tabBarView];
    if (destinationIndex == NSNotFound)
        return NSDragOperationNone;

    NSDragOperation dragOp = NSDragOperationMove;

    if (delegate && [delegate respondsToSelector:@selector(tabView:validateDrop:proposedItem:proposedIndex:inTabBarView:)]) {
        dragOp = [delegate tabView:tabBarView.tabView validateDrop:sender proposedItem:tabBarButton.tabViewItem proposedIndex:destinationIndex inTabBarView:tabBarView];
    }
    
    if (dragOp != NSDragOperationNone) {
    
        if (_draggedView || _draggedTab)
            [self _endDraggingWindowForPasteboardItem:pasteboardItem];
    
        [self setDestinationTabBar:tabBarView];
        [self setCurrentMouseLocation:mouseLoc];
        
        if (destinationIndex != tabBarView.destinationIndexForDraggedItem) {
            [tabBarView setDestinationIndexForDraggedItem:destinationIndex];
            [tabBarView update:YES];
        }
    }

    return dragOp;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender inTabBarView:(MMTabBarView *)tabBarView {

    id <MMTabBarViewDelegate> delegate = tabBarView.delegate;

    MMTabPasteboardItem *pasteboardItem = [self _tabPasteboardItemOfDraggingInfo:sender];
    if (!pasteboardItem)
        return NSDragOperationNone;
    
	NSTabView* sourceTabView = _sourceTabBar.tabView;
	MMAttachedTabBarButton* const tabBarButton = _attachedTabBarButton;
	if (tabBarButton == nil)
        return NSDragOperationNone;

    NSUInteger previousDestinationIndex = tabBarView.destinationIndexForDraggedItem;

    NSDragOperation dragOp = NSDragOperationMove;
    
        // get destination index
    NSPoint mouseLoc = [tabBarView convertPoint:sender.draggingLocation fromView:nil];
    NSUInteger destinationIndex = [self _destinationIndexForButton:tabBarButton atPoint:mouseLoc inTabBarView:tabBarView];
    
    if (destinationIndex == NSNotFound)
        dragOp = NSDragOperationNone;
    else {
        if (delegate && [delegate respondsToSelector:@selector(tabView:validateDrop:proposedItem:proposedIndex:inTabBarView:)]) {
            dragOp = [delegate tabView:sourceTabView validateDrop:sender proposedItem:tabBarButton.tabViewItem proposedIndex:destinationIndex inTabBarView:tabBarView];
            }
    }

    if (dragOp != NSDragOperationNone) {
    
        if (self.destinationTabBar != tabBarView) {
            [self setDestinationTabBar:tabBarView];
        }
        
        [self setCurrentMouseLocation:mouseLoc];
    } else {
        [self setDestinationTabBar:nil];
        destinationIndex = NSNotFound;
    }
    
    if (previousDestinationIndex == NSNotFound && destinationIndex != NSNotFound) {
            // simulate entered
        [self draggingEntered:sender inTabBarView:tabBarView];
    } else if (previousDestinationIndex != NSNotFound && destinationIndex == NSNotFound) {
            // simulate exited
        [self draggingExitedTabBarView:tabBarView draggingInfo:sender];
    }
    
    if (destinationIndex != tabBarView.destinationIndexForDraggedItem) {
        [tabBarView setDestinationIndexForDraggedItem:destinationIndex];
        [tabBarView update:YES];
        }
    
    return dragOp;
}

- (void)draggingExitedTabBarView:(MMTabBarView *)tabBarView draggingInfo:(id <NSDraggingInfo>)sender {

    MMTabPasteboardItem *pasteboardItem = [self _tabPasteboardItemOfDraggingInfo:sender];
    if (!pasteboardItem)
        return;

    [self _draggingExitedTabBarView:tabBarView withPasteboardItem:pasteboardItem];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender forTabBarView:(MMTabBarView *)tabBarView {

    BOOL success = NO;
    
    NSPasteboard *pb = sender.draggingPasteboard;
    
    if (![pb canReadItemWithDataConformingToTypes:@[AttachedTabBarButtonUTI]])
        return success;
 
        // get (single) pasteboard item
    MMTabPasteboardItem *pasteboardItem = [self _tabPasteboardItemOfDraggingInfo:sender];
    if (!pasteboardItem)
        return success;
        
        // get info about source on pasteboard
	NSTabView *sourceTabView = _sourceTabBar.tabView;
    NSUInteger sourceIndex = pasteboardItem.sourceIndex;
	MMAttachedTabBarButton* const tabBarButton = _attachedTabBarButton;
    if (tabBarButton == nil)
        return success;
    NSTabViewItem *tabViewItem = tabBarButton.tabViewItem;
        
        // get destination info
    MMTabBarView *destTabBarView = self.destinationTabBar;
    if (!destTabBarView)
        return success;
    
    id <MMTabBarViewDelegate> destDelegate = destTabBarView.delegate;

    NSPoint location = [destTabBarView convertPoint:sender.draggingLocation fromView:nil];
        
    NSUInteger destinationIndex = [self _destinationIndexForButton:tabBarButton atPoint:location inTabBarView:destTabBarView];
    
    NSDragOperation dragOp = NSDragOperationMove;
    if (destDelegate && [destDelegate respondsToSelector:@selector(tabView:validateDrop:proposedItem:proposedIndex:inTabBarView:)]) {
        dragOp = [destDelegate tabView:destTabBarView.tabView validateDrop:sender proposedItem:tabBarButton.tabViewItem proposedIndex:destinationIndex inTabBarView:destTabBarView];
    } 
    
    [tabBarView setDestinationIndexForDraggedItem:NSNotFound];

    if (dragOp != NSDragOperationNone) {
            // remove tab view item and suppress update
        [_sourceTabBar setIsReorderingTabViewItems:YES];
        [_sourceTabBar removeTabViewItem:tabViewItem];
        [_sourceTabBar setIsReorderingTabViewItems:NO];

            // insert tab view item and suppress update    
        [tabBarView setIsReorderingTabViewItems:YES];
        [tabBarView insertAttachedButton:tabBarButton atTabItemIndex:destinationIndex];
        [tabBarView setIsReorderingTabViewItems:NO];
                                                            
        [tabBarView update:NO];

        if ((_sourceTabBar != destTabBarView || sourceIndex != destinationIndex) && [_sourceTabBar.delegate respondsToSelector:@selector(tabView:didDropTabViewItem:inTabBarView:)]) {
            [_sourceTabBar.delegate tabView:sourceTabView didDropTabViewItem:tabViewItem inTabBarView:destTabBarView];
        }
        
        success = YES;
    }

	[NSNotificationCenter.defaultCenter postNotificationName:MMTabDragDidEndNotification object:nil];
        
    [self finishDragOfPasteboardItem:pasteboardItem];    
    
    return success;    
}

- (void)finishDragOfPasteboardItem:(MMTabPasteboardItem *)pasteboardItem {

	MMAttachedTabBarButton* const tabBarButton = _attachedTabBarButton;
	if (tabBarButton == nil) {
		return;
	}
    NSTabView *sourceTabView = _sourceTabBar.tabView;
	MMTabBarView *destinationTabBarView = self.destinationTabBar;

	if (sourceTabView.numberOfTabViewItems == 0 && [_sourceTabBar.delegate respondsToSelector:@selector(tabView:closeWindowForLastTabViewItem:)]) {
		[_sourceTabBar.delegate tabView:sourceTabView closeWindowForLastTabViewItem:tabBarButton.tabViewItem];
	}

	if (_draggedTab) {
		[_draggedTab.window orderOut:nil];
		_draggedTab = nil;
	}

	if (_draggedView) {
		[_draggedView.window orderOut:nil];
		_draggedView = nil;
	}

	_centersDragWindows = NO;

	[self setIsDragging:NO];
	[self setSourceTabBar:nil];
	[self setAttachedTabBarButton:nil];
	[self setPasteboardItem:nil];
	[self setDestinationTabBar:nil];
    [destinationTabBarView setDestinationIndexForDraggedItem:NSNotFound];
}

#pragma mark -
#pragma mark Dragging Helpers

- (NSUInteger)destinationIndexForButton:(MMAttachedTabBarButton *)aButton atPoint:(NSPoint)aPoint inTabBarView:(MMTabBarView *)tabBarView {
    return [self _destinationIndexForButton:aButton atPoint:aPoint inTabBarView:tabBarView];
}

#pragma mark -
#pragma mark NSAnimationDelegate

- (void)_finalizeAnimation:(NSAnimation *)animation {
    if (animation == _slideButtonsAnimation) {
        
        NSArray<NSDictionary<NSViewAnimationKey, id> *> *viewAnimations = _slideButtonsAnimation.viewAnimations;
        
        MMAttachedTabBarButton *aButton = nil;
        for (NSDictionary<NSViewAnimationKey, id> *anAnimDict in viewAnimations) {
            aButton = [anAnimDict objectForKey:NSViewAnimationTargetKey];
            if ([aButton isKindOfClass:MMAttachedTabBarButton.class]) {
                [aButton slideAnimationDidEnd];
            }
        }
        
        MMTabBarView *tabBarView = aButton.enclosingTabBarView;

        [tabBarView updateTabStateMaskOfAttachedButtons];
        
        NSArray<MMAttachedTabBarButton *> *attachedButtons = tabBarView.orderedAttachedButtons;
        NSUInteger numberOfAttachedButtons = attachedButtons.count;
        NSUInteger numberOfTabViewItems = tabBarView.numberOfTabViewItems;
        
            // update overflow state of attached buttons
        NSUInteger i = 0;
        for (MMAttachedTabBarButton *aButton in attachedButtons) {
        
            [aButton setIsOverflowButton:(numberOfTabViewItems > numberOfAttachedButtons) && (i+1 == numberOfAttachedButtons)];
            
        i++;
        }
    
        _slideButtonsAnimation = nil;
    }
}

- (void)animationDidStop:(NSAnimation *)animation {
    [self _finalizeAnimation:animation];
}

- (void)animationDidEnd:(NSAnimation *)animation {
    [self _finalizeAnimation:animation];
}

#pragma mark -
#pragma mark Private Methods

- (NSUInteger)_destinationIndexForButton:(MMAttachedTabBarButton *)aButton atPoint:(NSPoint)aPoint inTabBarView:(MMTabBarView *)tabBarView {

    NSUInteger resultingIndex = NSNotFound;
    
    MMTabBarOrientation orientation = tabBarView.orientation;
    
    if (orientation == MMTabBarHorizontalOrientation && aPoint.x < tabBarView.leftMargin) {
        resultingIndex = 0;
    } else if (orientation == MMTabBarVerticalOrientation && aPoint.y < tabBarView.topMargin) {
        resultingIndex = 0;
    } else {
    
        MMAttachedTabBarButton *overButton = nil;
        NSUInteger overButtonIndex = NSNotFound;
        
        NSArray<MMAttachedTabBarButton *> *sortedButtons = [tabBarView sortedAttachedButtonsUsingComparator:
            ^NSComparisonResult(MMAttachedTabBarButton *but1, MMAttachedTabBarButton *but2) {
            
                NSRect stackingFrame1 = but1.stackingFrame;
                NSRect stackingFrame2 = but2.stackingFrame;
                            
                if (tabBarView.orientation == MMTabBarHorizontalOrientation) {
                    
                    if (stackingFrame1.origin.x > stackingFrame2.origin.x)
                        return NSOrderedDescending;
                    else if (stackingFrame1.origin.x < stackingFrame2.origin.x)
                        return NSOrderedAscending;
                    else
                        return NSOrderedSame;
                } else {
                    if (stackingFrame1.origin.y > stackingFrame2.origin.y)
                        return NSOrderedDescending;
                    else if (stackingFrame1.origin.y < stackingFrame2.origin.y)
                        return NSOrderedAscending;
                    else
                        return NSOrderedSame;
                }
            }];
        
        
        for (MMAttachedTabBarButton *aSortedButton in sortedButtons) {
        
            NSPoint checkPoint = aPoint;
            if (tabBarView.orientation == MMTabBarHorizontalOrientation) {
                checkPoint.y = NSMidY(tabBarView.bounds);
            } else {
                checkPoint.x = NSMidX(tabBarView.bounds);
            }
        
            if (NSPointInRect(checkPoint, aSortedButton.stackingFrame)) {
                overButton = aSortedButton;
                overButtonIndex = [sortedButtons indexOfObjectIdenticalTo:aSortedButton];
                break;
            }
        }
        
        if (overButton) {            
            if (overButton == aButton)
                return overButtonIndex;

            NSRect overButtonFrame = overButton.frame;
            
            if (tabBarView.orientation == MMTabBarHorizontalOrientation) {
                // horizontal orientation
                if (aPoint.x < (overButtonFrame.origin.x + (overButtonFrame.size.width / 2.0))) {
                    // mouse on left side of button
                    resultingIndex = overButtonIndex;
                } else {
                    // mouse on right side of button
                    resultingIndex = overButtonIndex + 1;
                }
            } else {
                // vertical orientation
                if (aPoint.y < (overButtonFrame.origin.y + (overButtonFrame.size.height / 2.0))) {
                    // mouse on top of button
                    resultingIndex = overButtonIndex;
                } else {
                    // mouse on bottom of button
                    resultingIndex = overButtonIndex + 1;
                }
            }
        } else {

            if (self.isSliding)
                resultingIndex = tabBarView.numberOfVisibleTabViewItems-1;
            else if (self.isDragging) {
                if (tabBarView.destinationIndexForDraggedItem != NSNotFound)
                    resultingIndex = tabBarView.destinationIndexForDraggedItem;
                else {
                    NSRect lastFrame = tabBarView.lastAttachedButton.frame;
                    if (tabBarView.orientation == MMTabBarHorizontalOrientation) {
                        if (aPoint.x > NSMaxX(lastFrame)) {
                            resultingIndex = tabBarView.numberOfVisibleTabViewItems;
                        }
                    } else {
                        if (aPoint.y > NSMaxY(lastFrame))
                            resultingIndex = tabBarView.numberOfVisibleTabViewItems;
                    }
                }
            }
        }
    }
    
    return resultingIndex;
}

- (NSImage *)_imageForViewOfAttachedButton:(MMAttachedTabBarButton *)aButton forTabBarView:(MMTabBarView *)tabBarView styleMask:(NSUInteger *)outMask {
    
    NSTabView *tabView = tabBarView.tabView;
    
    NSImage *viewImage = nil;

	if (outMask) {
		*outMask = NSBorderlessWindowMask;
	}
    
    id <MMTabBarViewDelegate> tabBarDelegate = tabBarView.delegate;
    
    if (tabBarDelegate && [tabBarDelegate respondsToSelector:@selector(tabView:imageForTabViewItem:offset:styleMask:)]) {
		//get a custom image representation of the view to drag from the delegate
		NSImage *tabImage = _draggedTab.image;
		NSPoint drawPoint;
		_dragWindowOffset = NSZeroSize;
		viewImage = [tabBarDelegate tabView:tabView imageForTabViewItem:aButton.tabViewItem offset:&_dragWindowOffset styleMask:outMask];
		[viewImage lockFocus];

		//draw the tab into the returned window, that way we don't have two windows being dragged (this assumes the tab will be on the window)
		drawPoint = NSMakePoint(_dragWindowOffset.width, viewImage.size.height - _dragWindowOffset.height);

		if (tabBarView.orientation == MMTabBarHorizontalOrientation) {
			drawPoint.y += tabBarView.heightOfTabBarButtons - tabImage.size.height;
			_dragWindowOffset.height -= tabBarView.heightOfTabBarButtons - tabImage.size.height;
		} else {
			drawPoint.x += tabBarView.frame.size.width - tabImage.size.width;
		}

        [tabImage drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];

		[viewImage unlockFocus];
	} else {
		//the delegate doesn't give a custom image, so use an image of the view
		NSView *tabView = aButton.tabViewItem.view;
		viewImage = [[NSImage alloc] initWithSize:tabView.frame.size];
		[viewImage lockFocus];
		[tabView drawRect:tabView.bounds];
		[viewImage unlockFocus];
	}

	if (outMask && (*outMask | NSBorderlessWindowMask)) {
		_dragWindowOffset.height += 22;
	}

	return viewImage;
}

- (NSImage *)_miniwindowImageOfWindow:(NSWindow *)window {
	NSRect rect = window.frame;
	NSImage *image = [[NSImage alloc] initWithSize:rect.size];
	void* const graphicsPort = NSGraphicsContext.currentContext.graphicsPort;
	if (graphicsPort != nil) {
		[image lockFocus];
		rect.origin = NSZeroPoint;
		CGContextCopyWindowCaptureContentsToRect(graphicsPort, *(CGRect *)&rect, NSApp.contextID, window.windowNumber, 0);
		[image unlockFocus];
	}

	return image;
}

- (void)_expandWindow:(NSWindow *)window atPoint:(NSPoint)point {

	NSRect frame = window.frame;
	[window setFrameTopLeftPoint:NSMakePoint(point.x - frame.size.width / 2, point.y + frame.size.height / 2)];
	[window setAlphaValue:0.0];
    [window makeKeyAndOrderFront:nil];
    [window.animator setAlphaValue:1.0];
}

- (void)_dragAttachedTabBarButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView at:(NSPoint)buttonLocation event:(NSEvent *)theEvent source:(id)sourceObject {

    NSEvent *nextEvent = nil,
            *firstEvent = nil,
            *dragEvent = nil,
            *mouseUp = nil;
    NSDate *expiration = NSDate.distantFuture;
    BOOL   continueDetached = NO;

        // create pasteboard item
    MMTabPasteboardItem *pasteboardItem = [[MMTabPasteboardItem alloc] init];
    [pasteboardItem setSourceIndex:[tabBarView indexOfTabViewItem:aButton.tabViewItem]];
    [pasteboardItem setString:aButton.title forType:AttachedTabBarButtonUTI];

        // create dragging item
    NSDraggingItem *draggingItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pasteboardItem];
    
	[self setSourceTabBar:tabBarView];
	[self setAttachedTabBarButton:aButton];
    [self setPasteboardItem:pasteboardItem];

        // informal
	[NSNotificationCenter.defaultCenter postNotificationName:MMTabDragDidBeginNotification object:pasteboardItem];
    
    id <MMTabBarViewDelegate> delegate = tabBarView.delegate;
    NSTabView *tabView = tabBarView.tabView;
    NSTabViewItem *tabViewItem = aButton.tabViewItem;
    
    NSPoint mouseLocation = [tabBarView convertPoint:theEvent.locationInWindow fromView:nil];
    NSSize mouseOffset = NSMakeSize(mouseLocation.x-buttonLocation.x, mouseLocation.y-buttonLocation.y);
    
    NSUInteger sourceIndex = [tabBarView indexOfAttachedButton:aButton];
    NSUInteger destinationIndex = NSNotFound;
    NSUInteger lastDestinationIndex = sourceIndex;
    
    [self setIsSliding:YES];
    [aButton setIsInDraggedSlide:YES];

    [tabBarView updateTabStateMaskOfAttachedButton:aButton atIndex:sourceIndex];

    [aButton orderFront];
                
    while ((nextEvent = [tabBarView.window nextEventMatchingMask:NSLeftMouseUpMask | NSLeftMouseDraggedMask untilDate:expiration inMode:NSEventTrackingRunLoopMode dequeue:YES]) != nil) {
    
        if (firstEvent == nil) {
            firstEvent = nextEvent;
        }
        
        if (nextEvent.type == NSLeftMouseDragged) {
        
            dragEvent = nextEvent;
            
            mouseLocation = [tabBarView convertPoint:dragEvent.locationInWindow fromView:nil];
            NSRect slidingFrame = aButton.slidingFrame;
            slidingFrame.origin.x = mouseLocation.x - mouseOffset.width;
            slidingFrame.origin.y = mouseLocation.y - mouseOffset.height;

            [aButton setSlidingFrame:slidingFrame];
            
            destinationIndex = [self _destinationIndexForButton:aButton atPoint:mouseLocation inTabBarView:tabBarView];
        
            NSDragOperation dragOp = NSDragOperationMove;
            if (delegate && [delegate respondsToSelector:@selector(tabView:validateSlideOfProposedItem:proposedIndex:inTabBarView:)])
                dragOp = [delegate tabView:tabView validateSlideOfProposedItem:tabViewItem proposedIndex:destinationIndex inTabBarView:tabBarView];
        
            if (dragOp == NSDragOperationNone)
                destinationIndex = NSNotFound;
        
            if (destinationIndex != NSNotFound && destinationIndex != lastDestinationIndex)
                {
                destinationIndex = [self _moveAttachedTabBarButton:aButton inTabBarView:tabBarView fromIndex:sourceIndex toIndex:destinationIndex];
                sourceIndex = destinationIndex;
                lastDestinationIndex = destinationIndex;
                }

            if ([tabBarView allowsDetachedDraggingOfTabViewItem:aButton.tabViewItem]) {
            
                // check if we should detach
                NSRect tabBarViewBounds = tabBarView.bounds;
                
                NSRect hysteresisRect;
                if (tabBarView.orientation == MMTabBarHorizontalOrientation)
                    hysteresisRect = NSInsetRect(tabBarViewBounds,0.0,-15.0);
                else
                    hysteresisRect = NSInsetRect(tabBarViewBounds,-15.0,0.0);

                if (!NSPointInRect(mouseLocation, hysteresisRect)) {
                    continueDetached = YES;
                    break;
                }
            }
                                    
        } else if (nextEvent.type == NSLeftMouseUp) {
        
            mouseUp = nextEvent;

            [self setIsSliding:NO];
            [aButton setIsInDraggedSlide:NO];
                
                // move tab view item:
            if ([tabBarView indexOfTabViewItem:aButton.tabViewItem] != lastDestinationIndex) {

                [tabBarView moveTabViewItem:aButton.tabViewItem toIndex:lastDestinationIndex];
            
                [tabBarView update:NO];
                
                // slide Back:
            } else if (destinationIndex == NSNotFound || (destinationIndex != NSNotFound && sourceIndex == destinationIndex)) {
                if (tabBarView.automaticallyAnimates) {
                    [self _slideBackTabBarButton:aButton inTabBarView:tabBarView];
                } else {
                    [aButton setFrame:aButton.stackingFrame];
                }
            }
            
            lastDestinationIndex = NSNotFound;
            
            break;
        }
    }
        
        // continue with standard dragging procedure ("Detached")
    if (continueDetached) {

        [self setIsSliding:NO];
        [aButton setIsInDraggedSlide:NO];
        
        [self _dragDetachedButton:aButton ofTabBarView:tabBarView withEvent:firstEvent draggingItem:draggingItem source:sourceObject];
        
    } else {
        [self setPasteboardItem:nil];
    }
}

- (void)_detachButton:(MMAttachedTabBarButton *)aButton fromTabBarView:(MMTabBarView *)tabBarView {
   [tabBarView removeAttachedButton:aButton];
   [tabBarView update];
}

- (void)_dragDetachedButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView withEvent:(NSEvent *)theEvent draggingItem:(NSDraggingItem *)draggingItem source:(id)source {

    [self setIsDragging:YES];

        // get dragging image
	NSImage *dragImage = aButton.dragImage;
            
        // detach button
    [self _detachButton:aButton fromTabBarView:tabBarView];
            
        // begin dragging session
    _currentTearOffStyle = tabBarView.tearOffStyle;
    _draggedTab = [[MMTabDragWindowController alloc] initWithImage:dragImage styleMask:NSBorderlessWindowMask tearOffStyle:_currentTearOffStyle];

    NSPoint location = aButton.frame.origin;
    
    NSImage *dummyImage = [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
    [draggingItem setDraggingFrame:NSMakeRect(location.x, location.y, 1, 1) contents:dummyImage];
    
    [tabBarView beginDraggingSessionWithItems:@[draggingItem] event:theEvent source:source];
}

- (void)_slideBackTabBarButton:(MMAttachedTabBarButton *)aButton inTabBarView:(MMTabBarView *)tabBarView {

    if (_slideButtonsAnimation != nil) {
        [_slideButtonsAnimation stopAnimation];
        _slideButtonsAnimation = nil;
    }

    [aButton slideAnimationWillStart];

    _slideButtonsAnimation = [[MMSlideButtonsAnimation alloc] initWithTabBarButtons:[NSSet setWithObject:aButton]];
    [_slideButtonsAnimation setDuration:0.05];
    [_slideButtonsAnimation setDelegate:self];
    [_slideButtonsAnimation startAnimation];    
}

- (NSUInteger)_moveAttachedTabBarButton:(MMAttachedTabBarButton *)aButton inTabBarView:(MMTabBarView *)tabBarView fromIndex:(NSUInteger)sourceIndex toIndex:(NSUInteger)destinationIndex {

    if (destinationIndex == sourceIndex)
        return destinationIndex;

    if (_slideButtonsAnimation != nil) {
        [_slideButtonsAnimation stopAnimation];
        _slideButtonsAnimation = nil;
    }

    NSRange slidingRange;
    CGFloat slidingDirection = 0.0;

    NSArray<MMAttachedTabBarButton *> *sortedButtons = tabBarView.orderedAttachedButtons;
    NSUInteger numberOfButtons = sortedButtons.count;
    
    if (destinationIndex > sourceIndex) {
        
            // assure that destination index is in range of ordered buttons
        destinationIndex = MIN(destinationIndex,numberOfButtons-1);
        
        slidingRange = NSMakeRange(sourceIndex+1,destinationIndex-sourceIndex);
        slidingDirection = -1.0;
    } else {
        slidingRange = NSMakeRange(destinationIndex,sourceIndex-destinationIndex);
        slidingDirection = 1.0;
    }
    
    NSArray<MMAttachedTabBarButton *> *slidingButtons = [sortedButtons objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:slidingRange]];
    
    CGFloat slidingAmount = 0;
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        slidingAmount = aButton.frame.size.width;
    else
        slidingAmount = aButton.frame.size.height;
        
    NSRect stackingFrame;
    for (MMAttachedTabBarButton *aSlidingButton in slidingButtons) {
        stackingFrame = aSlidingButton.stackingFrame;
        
        if (tabBarView.orientation == MMTabBarHorizontalOrientation)
            stackingFrame.origin.x += slidingAmount*slidingDirection;
        else
            stackingFrame.origin.y += slidingAmount*slidingDirection;
            
        [aSlidingButton setStackingFrame:stackingFrame];
        [aSlidingButton slideAnimationWillStart];
    }

    // calculate stacking frame of moved button
    CGFloat positionOfMovedButton = 0.0;
    if (slidingDirection < 0) {
        MMAttachedTabBarButton *lastSlidedButton = slidingButtons.lastObject;
        NSRect stackingFrame = lastSlidedButton.stackingFrame;
        if (tabBarView.orientation == MMTabBarHorizontalOrientation)
            positionOfMovedButton = NSMaxX(stackingFrame);
        else
            positionOfMovedButton = NSMaxY(stackingFrame);
    } else {
        MMAttachedTabBarButton *firstSlidedButton = slidingButtons[0];
        NSRect stackingFrame = firstSlidedButton.stackingFrame;
        if (tabBarView.orientation == MMTabBarHorizontalOrientation)
            positionOfMovedButton = NSMinX(stackingFrame) - NSWidth(aButton.slidingFrame);
        else
            positionOfMovedButton = NSMinY(stackingFrame) - NSHeight(aButton.slidingFrame);
    }
    
    // update stacking frame of moved button
    stackingFrame = aButton.stackingFrame;
    if (tabBarView.orientation == MMTabBarHorizontalOrientation)
        stackingFrame.origin.x = positionOfMovedButton;
    else
        stackingFrame.origin.y = positionOfMovedButton;
        
    [aButton setStackingFrame:stackingFrame];
    
    [tabBarView updateTabStateMaskOfAttachedButtons];
    
    _slideButtonsAnimation = [[MMSlideButtonsAnimation alloc] initWithTabBarButtons:[NSSet setWithArray:slidingButtons]];
    [_slideButtonsAnimation setDelegate:self];
    [_slideButtonsAnimation startAnimation];
    
    return destinationIndex;
}

- (void)_draggingExitedTabBarView:(MMTabBarView *)tabBarView withPasteboardItem:(MMTabPasteboardItem *)pasteboardItem {

    NSParameterAssert(pasteboardItem != nil);
    
    id <MMTabBarViewDelegate> tabBarDelegate = tabBarView.delegate;
    
    NSTabView *sourceTabView = _sourceTabBar.tabView;

    BOOL isLeavingSourceTabBar = (_sourceTabBar && _sourceTabBar == tabBarView);

    if (isLeavingSourceTabBar) {
		NSTabViewItem* const tabViewItem = _attachedTabBarButton.tabViewItem;
		if (tabViewItem != nil) {
			if ([tabBarDelegate respondsToSelector:@selector(tabView:shouldAllowTabViewItem:toLeaveTabBarView:)]) {
				if (![tabBarDelegate tabView:sourceTabView shouldAllowTabViewItem:tabViewItem toLeaveTabBarView:tabBarView]) {
					return;
				}
			}
		}
    }

    BOOL shouldDragSourceWindow = (_sourceTabBar.tabView.numberOfTabViewItems == 1 && isLeavingSourceTabBar);
    
        // do nothing if the tab bar we exited did not participate
    if (!shouldDragSourceWindow && tabBarView.destinationIndexForDraggedItem == NSNotFound)
        return;

	[self setDestinationTabBar:nil];
    [tabBarView setDestinationIndexForDraggedItem:NSNotFound];
    [tabBarView update:YES];

        // switch to drag a window representation
    [self _beginDraggingWindowForPasteboardItem:pasteboardItem isSourceWindow:shouldDragSourceWindow];
}

- (MMTabPasteboardItem *)_tabPasteboardItemOfDraggingInfo:(id <NSDraggingInfo>)draggingInfo {
    NSPasteboard *pb = draggingInfo.draggingPasteboard;

        // get (single) pasteboard item
    NSArray<NSPasteboardItem *> *pasteboardItems = pb.pasteboardItems;
    for (NSPasteboardItem *anItem in pasteboardItems) {
        if ([anItem isKindOfClass:MMTabPasteboardItem.class])
            return (MMTabPasteboardItem *)anItem;
    }
    
    return nil;
}

- (void)_beginDraggingWindowForPasteboardItem:(MMTabPasteboardItem *)pasteboardItem isSourceWindow:(BOOL)isSourceWindow {

	MMAttachedTabBarButton* const tabBarButton = _attachedTabBarButton;
	if (tabBarButton == nil) {
		return;
	}

	MMTabBarView* const sourceTabBar = _sourceTabBar;
	if (sourceTabBar == nil) {
		return;
	}

    id <MMTabBarViewDelegate> sourceTabBarViewDelegate = sourceTabBar.delegate;
    
    if (_fadeTimer) {
		[_fadeTimer invalidate];
		_fadeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 target:self selector:@selector(_fadeInDragWindow:) userInfo:nil repeats:YES];
	} else if (_draggedTab) {
		if (_currentTearOffStyle == MMTabBarTearOffAlphaWindow) {
			//create a new floating drag window
			if (!_draggedView) {
				NSUInteger styleMask;
				NSImage *viewImage = [self _imageForViewOfAttachedButton:tabBarButton forTabBarView:sourceTabBar styleMask:&styleMask];

				_draggedView = [[MMTabDragWindowController alloc] initWithImage:viewImage styleMask:styleMask tearOffStyle:MMTabBarTearOffAlphaWindow];
			}

            NSPoint windowOrigin = _draggedTab.window.frame.origin;
            
			windowOrigin.x -= _dragWindowOffset.width;
			windowOrigin.y += _dragWindowOffset.height;
            
			[_draggedView.window setFrameTopLeftPoint:windowOrigin];
			[_draggedView.window orderWindow:NSWindowBelow relativeTo:_draggedTab.window.windowNumber];
		} else if (_currentTearOffStyle == MMTabBarTearOffMiniwindow && !_draggedTab.alternateImage) {
			NSImage *image;
			NSSize imageSize;
			NSUInteger mask;             //we don't need this but we can't pass nil in for the style mask, as some delegate implementations will crash

			NSWindow* const window = sourceTabBar.window;
			if (window != nil) {
				if (!(image = [self _miniwindowImageOfWindow:window])) {
					image = [self _imageForViewOfAttachedButton:tabBarButton forTabBarView:sourceTabBar styleMask:&mask];
				}
			}

			imageSize = image.size;

			if (imageSize.width > imageSize.height) {
				[image setSize:NSMakeSize(125, 125 * (imageSize.height / imageSize.width))];
			} else {
				[image setSize:NSMakeSize(125 * (imageSize.width / imageSize.height), 125)];
			}

			[_draggedTab setAlternateImage:image];
		}


		//set the window's alpha mask to zero if the last tab is being dragged
		//don't fade out the old window if the delegate doesn't respond to the new tab bar method, just to be safe
		if (isSourceWindow && sourceTabBarViewDelegate && [sourceTabBarViewDelegate respondsToSelector:@selector(tabView:newTabBarViewForDraggedTabViewItem:atPoint:)]) {
            [sourceTabBar.window orderOut:nil];

			if (sourceTabBar.tearOffStyle == MMTabBarTearOffAlphaWindow) {
				[_draggedView.window setAlphaValue:kMMTabDragWindowAlpha];
			} else {
                [_draggedTab switchImages];
				_centersDragWindows = YES;
				//#warning fix me - what should we do when the last tab is dragged as a miniwindow?
			}
		} else {
			if (sourceTabBar.tearOffStyle == MMTabBarTearOffAlphaWindow) {
				_fadeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 target:self selector:@selector(_fadeInDragWindow:) userInfo:nil repeats:YES];
			} else {
				[_draggedTab switchImages];
				_centersDragWindows = YES;
			}
		}
	}
}

-(void)_endDraggingWindowForPasteboardItem:(MMTabPasteboardItem *)pasteboardItem {

    if (_currentTearOffStyle == MMTabBarTearOffMiniwindow && _draggedTab) {
        [_draggedTab switchImages];
    }
    
        //tell the drag window to display only the header if there is one
    if (_currentTearOffStyle == MMTabBarTearOffAlphaWindow && _draggedView) {
        if (_fadeTimer) {
            [_fadeTimer invalidate];
        }

        [_draggedTab.window orderFront:nil];
        _fadeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 target:self selector:@selector(_fadeOutDragWindow:) userInfo:nil repeats:YES];
    }
}

- (void)_fadeInDragWindow:(NSTimer *)timer {

	CGFloat value = _draggedView.window.alphaValue;
	if (value >= kMMTabDragWindowAlpha || _draggedTab == nil) {
		[timer invalidate];
		_fadeTimer = nil;
	} else {
		[_draggedTab.window setAlphaValue:_draggedTab.window.alphaValue - kMMTabDragAlphaInterval];
		[_draggedView.window setAlphaValue:value + kMMTabDragAlphaInterval];
	}    
}

- (void)_fadeOutDragWindow:(NSTimer *)timer {
	CGFloat value = _draggedView.window.alphaValue;
	NSWindow *tabWindow = _draggedTab.window, *viewWindow = _draggedView.window;

	if (value <= 0.0) {
		[viewWindow setAlphaValue:0.0];
		[tabWindow setAlphaValue:kMMTabDragWindowAlpha];

		[timer invalidate];
		_fadeTimer = nil;
	} else {
		if (tabWindow.alphaValue < kMMTabDragWindowAlpha) {
			[tabWindow setAlphaValue:tabWindow.alphaValue + kMMTabDragAlphaInterval];
		}
		[viewWindow setAlphaValue:value - kMMTabDragAlphaInterval];
	}    
}

@end

NS_ASSUME_NONNULL_END
