//
//  MMTabBarViewler.m
//  MMTabBarView
//
//  Created by Kent Sutherland on 11/24/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#import "MMTabBarController.h"
#import "MMTabBarView.h"
#import "MMAttachedTabBarButton.h"
#import "MMTabStyle.h"
#import "NSString+MMTabBarViewExtensions.h"
#import "MMTabBarView.Private.h"

NS_ASSUME_NONNULL_BEGIN

#define MAX_OVERFLOW_MENUITEM_TITLE_LENGTH      60

@interface MMTabBarController()
@end

@implementation MMTabBarController
{
	__weak MMTabBarView	*_tabBarView;
	NSMenu *_overflowMenu;
}

/*!
    @method     initWithTabBarView:
    @abstract   Creates a new MMTabBarController instance.
    @discussion Creates a new MMTabBarController for controlling a MMTabBarView. Should only be called by MMTabBarView.
    @param      A MMTabBarView.
    @returns    A newly created MMTabBarController instance.
 */
- (instancetype)initWithTabBarView:(MMTabBarView *)aTabBarView {
	if ((self = [super init])) {
		_tabBarView = aTabBarView;
	}
	return self;
}

/*!
    @method     overflowMenu
    @abstract   Returns current overflow menu or nil if there is none.
    @discussion Returns current overflow menu or nil if there is none.
    @returns    The current overflow menu.
 */
- (NSMenu *)overflowMenu {
	return _overflowMenu;
}

/*!
    @method     layoutButtons
    @abstract   Recalculates attached button positions and states.
    @discussion This method calculates the proper frame, tabState and overflow menu status for all attached buttons in the tab bar control.
 */
- (void)layoutButtons {

    NSArray *attachedButtons = [_tabBarView orderedAttachedButtons];
            
    NSInteger buttonCount = [attachedButtons count];
    
        // add dragged button if available
    if ([_tabBarView destinationIndexForDraggedItem] != NSNotFound) {
    
        MMAttachedTabBarButton *draggedButton = [_tabBarView attachedTabBarButtonForDraggedItems];
        if (draggedButton) {
            NSMutableArray *mutable = [attachedButtons mutableCopy];
            [mutable insertObject:draggedButton atIndex:[_tabBarView destinationIndexForDraggedItem]];
            attachedButtons = mutable;
            
            buttonCount++;
        }
    }
    
    NSArray *buttonWidths = [self _generateWidthsFromAttachedButtons:attachedButtons];
    [self _setupAttachedButtons:attachedButtons withWidths:buttonWidths];
}

/*!
 * @function   potentialMinimumForArray()
 * @abstract   Calculate the minimum total for a given array of widths
 * @discussion The array is summed using, for each item, the minimum between the current value and the passed minimum value.
 *             This is useful for getting a sum if the array has size-to-fit widths which will be allowed to be less than the
 *             specified minimum.
 * @param      An array of widths
 * @param      The minimum
 * @returns    The smallest possible sum for the array
 */
static NSInteger potentialMinimumForArray(NSArray *array, NSInteger minimum){
	NSInteger runningTotal = 0;
	NSInteger count = [array count];

	for(NSInteger i = 0; i < count; i++) {
		NSInteger currentValue = [[array objectAtIndex:i] integerValue];
		runningTotal += MIN(currentValue, minimum);
	}

	return runningTotal;
}

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)menuItem atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel {
	if (menu == _overflowMenu) {
		if ([[[menuItem representedObject] identifier] respondsToSelector:@selector(icon)]) {
			[menuItem setImage:[[[menuItem representedObject] identifier] valueForKey:@"icon"]];
		}
	}

	return TRUE;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu {
	if (menu == _overflowMenu) {
		return [_overflowMenu numberOfItems];
	} else {
		NSLog(@"Warning: Unexpected menu delegate call for menu %@", menu);
		return 0;
	}
}

#pragma mark -
#pragma Private Methods

/*!
    @method     _generateWidthsFromAttachedButtons:
    @abstract   Calculates the width of attached buttons that would be visible.
    @discussion Calculates the width of attached buttons in the tab bar and returns an array of widths for the buttons that would be visible. Uses large blocks of code that were previously in MMTabBarView's update method.
    @param      An array of MMAttachedTabBarButton.
    @returns    An array of numbers representing the widths of attached buttons that would be visible.
*/
- (NSArray *)_generateWidthsFromAttachedButtons:(NSArray *)buttons {
    NSInteger buttonCount = [buttons count], i, numberOfVisibleButtons = ([_tabBarView orientation] == MMTabBarHorizontalOrientation) ? 1 : 0;
	NSMutableArray *newWidths = [NSMutableArray arrayWithCapacity:buttonCount];

	CGFloat availableWidth = [_tabBarView availableWidthForButtons], currentOrigin = 0, totalOccupiedWidth = 0.0, width;

	NSRect buttonRect = [_tabBarView genericButtonRect];
	MMAttachedTabBarButton *currentButton;

	if ([_tabBarView orientation] == MMTabBarVerticalOrientation) {
		currentOrigin = [_tabBarView topMargin];
	}

	for(i = 0; i < buttonCount; i++) {
		currentButton = [buttons objectAtIndex:i];

        BOOL displayCloseButton = [_tabBarView allowsBackgroundTabClosing] || ([currentButton state] == NSOnState);

		BOOL suppressCloseButton = (   (buttonCount == 1
									    && [_tabBarView canCloseOnlyTab] == NO)
									|| [_tabBarView disableTabClose]
									|| !displayCloseButton
									|| ([[_tabBarView delegate]
										 respondsToSelector:@selector(tabView:disableTabCloseForTabViewItem:)]
										&& [[_tabBarView delegate] tabView:[_tabBarView tabView]
											 disableTabCloseForTabViewItem:[currentButton tabViewItem]]));

		// supress close button?
		[currentButton setSuppressCloseButton:suppressCloseButton];

		if ([_tabBarView orientation] == MMTabBarHorizontalOrientation) {
			// Determine button width
			if ([_tabBarView sizeButtonsToFit]) {
				width = [currentButton desiredWidth];
				if (width > [_tabBarView buttonMaxWidth]) {
					width = [_tabBarView buttonMaxWidth];
				}
            }
            else if (_tabBarView.resizeTabsToFitTotalWidth) {
                width = MAX (availableWidth / (CGFloat)buttonCount, [_tabBarView buttonMinWidth]);
			} else {
				width = [_tabBarView buttonOptimumWidth];
			}

            width = ceil(width);

			//check to see if there is not enough space to place all tabs as preferred
			if (totalOccupiedWidth + width > availableWidth) {
				//There's not enough space to add current button at its preferred width!

				//If we're not going to use the overflow menu, cram all the tab buttons into the bar regardless of minimum width
				if (![_tabBarView useOverflowMenu]) {
					NSInteger j, averageWidth = (availableWidth / buttonCount);

					numberOfVisibleButtons = buttonCount;
					[newWidths removeAllObjects];

					for(j = 0; j < buttonCount; j++) {
						CGFloat desiredWidth = [[buttons objectAtIndex:j] desiredWidth];
						[newWidths addObject:[NSNumber numberWithDouble:(desiredWidth < averageWidth && [_tabBarView sizeButtonsToFit]) ? desiredWidth : averageWidth]];
					}

					break;
				}

				//We'll be using the overflow menu if needed.
				numberOfVisibleButtons = i;
				if ([_tabBarView sizeButtonsToFit]) {
					BOOL remainingButtonsMustGoToOverflow = NO;

					totalOccupiedWidth = [[newWidths valueForKeyPath:@"@sum.intValue"] integerValue];
                    if ([newWidths count] > 0)
                        totalOccupiedWidth += ([newWidths count]-1);

					/* Can I squeeze it in without violating min button width? This is the width we would take up
					 * if every button so far were at the control minimum size (or their current size if that is less than the control minimum).
					 */
					if ((potentialMinimumForArray(newWidths, [_tabBarView buttonMinWidth]) + MIN(width, [_tabBarView buttonMinWidth])) <= availableWidth) {
						/* It's definitely possible for buttons so far to be visible.
						 * Shrink other buttons to allow this one to fit
						 */
						NSInteger buttonMinWidth = [_tabBarView buttonMinWidth];

						/* Start off adding it to the array; we know that it will eventually fit because
						 * (the potential minimum <= availableWidth)
						 *
						 * This allows average and minimum aggregates on the NSArray to work.
						 */
						[newWidths addObject:[NSNumber numberWithDouble:width]];
						numberOfVisibleButtons++;

						totalOccupiedWidth += width;

						//First, try to shrink tabs toward the average. Tabs smaller than average won't change
						totalOccupiedWidth -= [self _shrinkWidths:newWidths
											   towardMinimum:[[newWidths valueForKeyPath:@"@avg.intValue"] integerValue]
											   withAvailableWidth:availableWidth];



						if (totalOccupiedWidth > availableWidth) {
							//Next, shrink tabs toward the smallest of the existing tabs. The smallest tab won't change.
							NSInteger smallestTabWidth = [[newWidths valueForKeyPath:@"@min.intValue"] integerValue];
							if (smallestTabWidth > buttonMinWidth) {
								totalOccupiedWidth -= [self _shrinkWidths:newWidths
													   towardMinimum:smallestTabWidth
													   withAvailableWidth:availableWidth];
							}
						}

						if (totalOccupiedWidth > availableWidth) {
							//Finally, shrink tabs toward the imposed minimum size.  All tabs larger than the minimum wll change.
							totalOccupiedWidth -= [self _shrinkWidths:newWidths
												   towardMinimum:buttonMinWidth
												   withAvailableWidth:availableWidth];
						}

						if (totalOccupiedWidth > availableWidth) {
							//NSLog(@"**** -[MMTabBarController _generateWidthsFromAttachedButtons:] This is a failure (available %f, total %f, width is %f)", availableWidth, totalOccupiedWidth, width);
							remainingButtonsMustGoToOverflow = YES;
						}

						if (totalOccupiedWidth < availableWidth) {
							/* We're not using all available space not but exceeded available width before;
							 * stretch all buttons to fully fit the bar
							 */
							NSInteger leftoverWidth = availableWidth - totalOccupiedWidth;
							if (leftoverWidth > 0) {
								NSInteger q;
								for(q = numberOfVisibleButtons - 1; q >= 0; q--) {
									NSInteger desiredAddition = (NSInteger)leftoverWidth / (q + 1);
									NSInteger newButtonWidth = (NSInteger)[[newWidths objectAtIndex:q] doubleValue] + desiredAddition;
									[newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithDouble:newButtonWidth]];
									leftoverWidth -= desiredAddition;
									totalOccupiedWidth += desiredAddition;
								}
							}
						}
					} else {
                    
                        // adjust available width for overflow button

                        CGFloat overflowPadding = kMMTabBarCellPadding;
                        if ([_tabBarView.style respondsToSelector:@selector(overflowButtonPaddingForTabBarView:)]) {
                            overflowPadding = [_tabBarView.style overflowButtonPaddingForTabBarView:_tabBarView];
                        }
                        availableWidth -= ([_tabBarView overflowButtonSize].width + overflowPadding);
                        if (![_tabBarView showAddTabButton])
                            availableWidth -= overflowPadding;
                                                
						// stretch - distribute leftover room among buttons, since we can't add this button
						NSInteger leftoverWidth = availableWidth - totalOccupiedWidth;
						NSInteger q;
						for(q = i - 1; q >= 0; q--) {
							NSInteger desiredAddition = (NSInteger)leftoverWidth / (q + 1);
							NSInteger newButtonWidth = (NSInteger)[[newWidths objectAtIndex:q] doubleValue] + desiredAddition;
							[newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithDouble:newButtonWidth]];
							leftoverWidth -= desiredAddition;
						}

						remainingButtonsMustGoToOverflow = YES;
					}

					// done assigning widths; remaining buttons go in overflow menu
					if (remainingButtonsMustGoToOverflow) {
						break;
					}
				} else {
					//We're not using size-to-fit
					NSInteger revisedWidth = availableWidth / (i + 1);
					if (revisedWidth >= [_tabBarView buttonMinWidth]) {
						NSUInteger q;
						totalOccupiedWidth = 0;

						for(q = 0; q < [newWidths count]; q++) {
							[newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithDouble:revisedWidth]];
							totalOccupiedWidth += revisedWidth;
						}
						// just squeezed this one in...
						[newWidths addObject:[NSNumber numberWithDouble:revisedWidth]];
						totalOccupiedWidth += revisedWidth;
						numberOfVisibleButtons++;

                        if (totalOccupiedWidth < availableWidth) {
                            // when the available width is not divided evenly by totalOccupiedWidth
                            // there will be a small gap between the addTab-button and the left-most tab
                            // here we distribute the remainder among the tabs.
                            // we'll use the same mechanism as above for consistancy
                            // this will create the least jitter of the separators

                            q = 0;
                            while ((q < [newWidths count]) && (availableWidth > totalOccupiedWidth)) {
                                [newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithDouble:revisedWidth+1]];
                                totalOccupiedWidth ++;
                                q ++;
                            }

                            NSInteger tot = 0;
                            for (NSNumber *newWidth in newWidths) {
                                tot += newWidth.integerValue;
                            }

                        }

                    // couldn't fit that last one...
					} else {
                        // adjust available width for overflow button
                        CGFloat overflowPadding = kMMTabBarCellPadding;
                        if ([_tabBarView.style respondsToSelector:@selector(overflowButtonPaddingForTabBarView:)]) {
                            overflowPadding = [_tabBarView.style overflowButtonPaddingForTabBarView:_tabBarView];
                        }

                        availableWidth -= ([_tabBarView overflowButtonSize].width + overflowPadding);
                        if (![_tabBarView showAddTabButton])
                            availableWidth -= overflowPadding;

                        revisedWidth = availableWidth / i;
                        
                        if (revisedWidth >= [_tabBarView buttonMinWidth]) {
                            NSUInteger q;
                            totalOccupiedWidth = 0;

                            for(q = 0; q < [newWidths count]; q++) {
                                [newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithDouble:revisedWidth]];
                                totalOccupiedWidth += revisedWidth;
                            }
                        } else {
                            [self _shrinkWidths:newWidths towardMinimum:[_tabBarView buttonMinWidth] withAvailableWidth:availableWidth];
                            NSInteger usedWidth = [[newWidths valueForKeyPath:@"@sum.intValue"] integerValue];
                                // buttons still do not fit in available width? -> remove last button
                            if (availableWidth < usedWidth) {
                                totalOccupiedWidth -= [[newWidths lastObject] intValue];
                                numberOfVisibleButtons--;
                                [newWidths removeLastObject];

                                revisedWidth = availableWidth / numberOfVisibleButtons;
                        
                                if (revisedWidth >= [_tabBarView buttonMinWidth]) {
                                    NSUInteger q;
                                    totalOccupiedWidth = 0;

                                    for(q = 0; q < [newWidths count]; q++) {
                                        [newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithDouble:revisedWidth]];
                                        totalOccupiedWidth += revisedWidth;
                                    }
                                }
                            }
                        }

                        NSInteger q = 0;
                        totalOccupiedWidth = 0;
                        for (q = 0; q < [newWidths count]; q++) {
                            [newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithDouble:revisedWidth]];
                            totalOccupiedWidth += revisedWidth;
                        }

                        if (totalOccupiedWidth < availableWidth) {
                            // when the available width is not divided evenly by totalOccupiedWidth
                            // there will be a small gap between the addTab-button and the left-most tab
                            // here we distribute the remainder among the tabs.
                            // we'll use the same mechanism as above for consistancy
                            // this will create the least jitter of the separators
                            while (0 < [newWidths count] && availableWidth > totalOccupiedWidth) {
                                for (q=0; ((q < [newWidths count]) && (availableWidth > totalOccupiedWidth)); q++) {
                                    [newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithDouble:revisedWidth+1]];
                                    totalOccupiedWidth ++;
                                }
                            }

                            NSInteger tot = 0;
                            for (NSNumber *newWidth in newWidths) {
                                tot += newWidth.integerValue;
                            }
                            
                        }

                                            
						break;
					}
				}
			} else {
				//(totalOccupiedWidth < availableWidth)
				numberOfVisibleButtons = buttonCount;
				[newWidths addObject:[NSNumber numberWithDouble:width]];
				totalOccupiedWidth += width;
			}
		} else {
			//lay out vertical tabs
			if (currentOrigin + buttonRect.size.height <= [_tabBarView availableHeightForButtons]) {
				[newWidths addObject:[NSNumber numberWithDouble:currentOrigin]];
				numberOfVisibleButtons++;
				currentOrigin += buttonRect.size.height;
			} else {
                break;
			}
		}
	}

    // avoid clang analyzer warning 
    #pragma unused(totalOccupiedWidth)

	//make sure there are at least two items in the horizontal tab bar
	if ([_tabBarView orientation] == MMTabBarHorizontalOrientation) {
		if (numberOfVisibleButtons < 2 && [buttons count] > 1) {
			MMAttachedTabBarButton *button1 = [buttons objectAtIndex:0], *button2 = [buttons objectAtIndex:1];
			NSNumber *buttonWidth;

			[newWidths removeAllObjects];
			totalOccupiedWidth = 0;

			buttonWidth = [NSNumber numberWithDouble:[button1 desiredWidth] < availableWidth * 0.5f ?[button1 desiredWidth] : availableWidth * 0.5f];
			[newWidths addObject:buttonWidth];
			totalOccupiedWidth += [buttonWidth doubleValue];

			buttonWidth = [NSNumber numberWithDouble:[button2 desiredWidth] < (availableWidth - totalOccupiedWidth) ?[button2 desiredWidth] : (availableWidth - totalOccupiedWidth)];
			[newWidths addObject:buttonWidth];
			totalOccupiedWidth += [buttonWidth doubleValue];

			if (totalOccupiedWidth < availableWidth) {
				[newWidths replaceObjectAtIndex:0 withObject:[NSNumber numberWithDouble:availableWidth - [buttonWidth doubleValue]]];
			}
		}
	}
    /* MiMo says: this is obscure and breaks add button */
    /*
    // Add width to last tab if indivisible
    if ([_tabBarView resizeTabsToFitTotalWidth]) {
        if (totalOccupiedWidth != NSWidth(_tabBarView.frame)) {
            if (newWidths.count > 0) {
                [newWidths replaceObjectAtIndex:newWidths.count - 1 withObject:[NSNumber numberWithDouble:[[newWidths lastObject] doubleValue] + (NSWidth(_tabBarView.frame) - totalOccupiedWidth)]];
            }
        }
    }
    */

	return newWidths;
}

/*!
    @method     _setupAttachedButtons:withWidths:
    @abstract   Creates tracking rect arrays and sets the frames of the visible attachment buttons.
    @discussion Creates tracking rect arrays and sets the frames given in the widths array.
*/
- (void)_setupAttachedButtons:(NSArray *)buttons withWidths:(NSArray *)widths {

    NSUInteger buttonCount = [buttons count];

	_overflowMenu = nil;
    
    __block NSRect buttonRect = [_tabBarView genericButtonRect];

    [_tabBarView enumerateAttachedButtons:buttons inRange:NSMakeRange(0, [widths count]) withOptions:MMAttachedButtonsEnumerationUpdateButtonState|MMAttachedButtonsEnumerationUpdateTabStateMask usingBlock:
        ^(MMAttachedTabBarButton *aButton, NSUInteger idx, MMAttachedTabBarButton *previousButton, MMAttachedTabBarButton *nextButton, BOOL *stop) {
                
            if ([[_tabBarView delegate] respondsToSelector:@selector(tabView:toolTipForTabViewItem:)]) {
                NSString *toolTip = [[_tabBarView delegate] tabView:[_tabBarView tabView] toolTipForTabViewItem:[aButton tabViewItem]];
                [aButton setToolTip:toolTip];
            }

            [aButton setTarget:_tabBarView];
            [aButton setAction:@selector(_didClickTabButton:)];
            
            if ([aButton shouldDisplayCloseButton]) {
                [[aButton closeButton] setTarget:_tabBarView];
                [aButton setCloseButtonAction:@selector(_didClickCloseButton:)];
            } else {
                [[aButton closeButton] setTarget:nil];
                [aButton setCloseButtonAction:NULL];
            }
        
			// set button frame
			if ([_tabBarView orientation] == MMTabBarHorizontalOrientation) {
				buttonRect.size.width = [[widths objectAtIndex:idx] doubleValue];
			} else {
				buttonRect.size.width = [_tabBarView frame].size.width;
				buttonRect.origin.y = [[widths objectAtIndex:idx] doubleValue];
				buttonRect.origin.x = 0;
			}

            [aButton setStackingFrame:buttonRect];

            if (idx+1 == [widths count] && [widths count] < buttonCount)
                {
                [aButton setIsOverflowButton:YES];
                [self _addItemToOverflowMenu:[aButton tabViewItem] withTitle:[[aButton attributedStringValue] string]];
                }
            else
                [aButton setIsOverflowButton:NO];

			// next...
            if ([_tabBarView orientation] == MMTabBarHorizontalOrientation)
                buttonRect.origin.x += [[widths objectAtIndex:idx] doubleValue];
            else
                buttonRect.origin.y += buttonRect.size.height;
                
            if ([[_tabBarView delegate] respondsToSelector:@selector(tabView:tabViewItem:isInOverflowMenu:)]) {
                [[_tabBarView delegate] tabView:[_tabBarView tabView] tabViewItem:[aButton tabViewItem] isInOverflowMenu:NO];
            }
        }];
    
        // handle overflow
    if (buttonCount > [widths count]) {
        [buttons enumerateObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange([widths count], buttonCount-[widths count])] options:0 usingBlock:
            ^(MMAttachedTabBarButton *aButton, NSUInteger idx, BOOL *stop) {

                [_tabBarView removeAttachedButton:aButton synchronizeTabViewItems:NO];

                [self _addItemToOverflowMenu:[aButton tabViewItem] withTitle:[[aButton attributedStringValue] string]];                
            }];
    }
/*
	NSInteger i, tabState, buttonCount = [buttons count];
	NSRect buttonRect = [_tabBarView genericButtonRect];
	NSTabViewItem *selectedTabViewItem = [[_tabBarView tabView] selectedTabViewItem];

	[_overflowMenu release], _overflowMenu = nil;

    MMAttachedTabBarButton *aButton = nil;    
	for(i = 0; i < buttonCount; i++) {
		aButton = [buttons objectAtIndex:i];

		if (i < [widths count]) {
        
			tabState = 0;
            
            if ([[_tabBarView delegate] respondsToSelector:@selector(tabView:toolTipForTabViewItem:)]) {
                NSString *toolTip = [[_tabBarView delegate] tabView:[_tabBarView tabView] toolTipForTabViewItem:[aButton tabViewItem]];
                [aButton setToolTip:toolTip];
            }

            [aButton setTarget:_tabBarView];
            [aButton setAction:@selector(_didClickTabButton:)];
            
            if ([aButton shouldDisplayCloseButton]) {
                [[aButton closeButton] setTarget:_tabBarView];
                [aButton setCloseButtonAction:@selector(_didClickCloseButton:)];
            } else {
                [[aButton closeButton] setTarget:nil];
                [aButton setCloseButtonAction:NULL];
            }
        
			// set button frame
			if ([_tabBarView orientation] == MMTabBarHorizontalOrientation) {
				buttonRect.size.width = [[widths objectAtIndex:i] doubleValue];
			} else {
				buttonRect.size.width = [_tabBarView frame].size.width;
				buttonRect.origin.y = [[widths objectAtIndex:i] doubleValue];
				buttonRect.origin.x = 0;
			}

            [aButton setStackingFrame:buttonRect];

			if ([[aButton tabViewItem] isEqualTo:selectedTabViewItem]) {
				[aButton setState:NSOnState];
				// previous button
				if (i > 0) {
					[[buttons objectAtIndex:i - 1] setTabState:([(MMAttachedTabBarButton *)[buttons objectAtIndex:i - 1] tabState] | MMTab_RightIsSelectedMask)];
				}
				// next button - see below
			} else {
				[aButton setState:NSOffState];
				// see if prev button was selected
				if ((i > 0) && ([[buttons objectAtIndex:i - 1] state] == NSOnState)) {
					tabState |= MMTab_LeftIsSelectedMask;
				}
			}

			// more tab states
			if ([widths count] == 1) {
				tabState |= MMTab_PositionLeftMask | MMTab_PositionRightMask | MMTab_PositionSingleMask;
			} else if (i == 0) {
				tabState |= MMTab_PositionLeftMask;
			} else if (i == [widths count] - 1) {
				tabState |= MMTab_PositionRightMask;
			}

			[aButton setTabState:tabState];

            if (i+1 == [widths count] && [widths count] < buttonCount)
                {
                [aButton setIsOverflowButton:YES];
                [self _addItemToOverflowMenu:[aButton tabViewItem] withTitle:[[aButton attributedStringValue] string]];
                }
            else
                [aButton setIsOverflowButton:NO];

			// next...
            if ([_tabBarView orientation] == MMTabBarHorizontalOrientation)
                buttonRect.origin.x += [[widths objectAtIndex:i] doubleValue];
            else
                buttonRect.origin.y += buttonRect.size.height;
                
            if ([[_tabBarView delegate] respondsToSelector:@selector(tabView:tabViewItem:isInOverflowMenu:)]) {
                [[_tabBarView delegate] tabView:[_tabBarView tabView] tabViewItem:[aButton tabViewItem] isInOverflowMenu:NO];
            }
		} else {
                
            [_tabBarView removeAttachedButton:aButton synchronizeTabViewItems:NO];

            [self _addItemToOverflowMenu:[aButton tabViewItem] withTitle:[[aButton attributedStringValue] string]];
		}
	}
*/    
}

/*!
 *  @method _shrinkWidths:towardMinimum:withAvailableWidth:
 *  @abstract Decreases widths in an array toward a minimum until they fit within availableWidth, if possible
 *  @param An array of NSNumbers
 *  @param The target minimum
 *  @param The maximum available width
 *  @returns The amount by which the total array width was shrunk
 */
- (NSInteger)_shrinkWidths:(NSMutableArray *)newWidths towardMinimum:(NSInteger)minimum withAvailableWidth:(CGFloat)availableWidth {
	BOOL changed = NO;
	NSInteger count = [newWidths count];
	NSInteger totalWidths = [[newWidths valueForKeyPath:@"@sum.intValue"] integerValue];
	NSInteger originalTotalWidths = totalWidths;

	do {
		changed = NO;

		for(NSInteger q = (count - 1); q >= 0; q--) {
			CGFloat buttonWidth = [[newWidths objectAtIndex:q] doubleValue];
			if (buttonWidth - 1 >= minimum) {
				buttonWidth--;
				totalWidths--;

				[newWidths replaceObjectAtIndex:q
				 withObject:[NSNumber numberWithDouble:buttonWidth]];

				changed = YES;
			}
		}
	} while(changed && (totalWidths > availableWidth));

	return(originalTotalWidths - totalWidths);
}

- (void)_addItemToOverflowMenu:(NSTabViewItem *)anItem withTitle:(NSString *)title {

    NSMenuItem *menuItem = nil;

    if (_overflowMenu == nil) {
        _overflowMenu = [[NSMenu alloc] init];
        [_overflowMenu insertItemWithTitle:@"" action:nil keyEquivalent:@"" atIndex:0]; // Because the overflowPupUpButton is a pull down menu
        [_overflowMenu setDelegate:self];
    }

    // Each item's title is limited to 60 characters. If more than 60 characters, use an ellipsis to indicate that more exists.
    NSString *truncatedString = [title stringByTruncatingToLength:MAX_OVERFLOW_MENUITEM_TITLE_LENGTH];
    
    menuItem = [_overflowMenu addItemWithTitle:truncatedString
                action:@selector(_overflowMenuAction:)
                keyEquivalent:@""];
    [menuItem setTarget:_tabBarView];
    [menuItem setRepresentedObject:anItem];
/*
    if ([aButton objectCount] > 0) {
        [menuItem setTitle:[[menuItem title] stringByAppendingFormat:@" (%lu)", (unsigned long)[aButton objectCount]]];
    }
*/            
        
    if ([[_tabBarView delegate] respondsToSelector:@selector(tabView:tabViewItem:isInOverflowMenu:)]) {
        [[_tabBarView delegate] tabView:[_tabBarView tabView] tabViewItem:anItem isInOverflowMenu:YES];
    }
}
@end

NS_ASSUME_NONNULL_END
