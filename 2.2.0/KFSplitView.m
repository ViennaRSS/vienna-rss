// 
// KFSplitView.m
// KFSplitView v. 1.3, 11/27/2004
// 
// Copyright (c) 2003-2004 Ken Ferry. Some rights reserved.
// http://homepage.mac.com/kenferry/software.html
//
// Other contributors: Kirk Baker, John Pannell
// 
// This work is licensed under a Creative Commons license:
// http://creativecommons.org/licenses/by-nc/1.0/
//
// Send me an email if you have any problems (after you've read what there is to read).
//
// You can reach me at kenferry at the domain mac.com.
// 
// On this whole major axis, minor axis thing:
// 
//     The 'major' axis refers to the direction in which dividers can move.
//     It's the y-axis when [self isVertical] returns NO, and the x-axis otherwise.
//     Pretty much everything that uses coordinates or dimensions in this file works
//     more comfortably in that coordinate system.
// 
// Other
// 
//     This class is a basically a complete reimplementation of NSSplitView.  The
//     underlying NSSplitView is mostly used for drawing dividers.


#import "KFSplitView.h"

#pragma mark File-level and global vars:

NSString *KFSplitViewDidCollapseSubviewNotification = @"KFSplitViewDidCollapseSubviewNotification";
NSString *KFSplitViewDidExpandSubviewNotification = @"KFSplitViewDidExpandSubviewNotification";

const NSPoint KFOffScreenPoint = {1000000.0,1000000.0};

static NSMutableSet *kfInUsePositionNames;


#pragma mark Utility:

// these are macros (instead of inlines) so that we can use the instance variable kfIsVertical
// they're undef'd at the bottom of the file
#define KFMAJORCOORDOFPOINT(point) (kfIsVertical ? (point).x : (point).y)
#define KFMINORCOORDOFPOINT(point) (kfIsVertical ? (point).y : (point).x)
#define KFMAJORDIMOFSIZE(size) (kfIsVertical ? (size).width : (size).height)
#define KFMINORDIMOFSIZE(size) (kfIsVertical ? (size).height : (size).width)
#define KFPOINTWITHMAJMIN(major, minor) (kfIsVertical ? NSMakePoint((major), (minor)) : NSMakePoint((minor), (major)))
#define KFSIZEWITHMAJMIN(major, minor) (kfIsVertical ? NSMakeSize((major), (minor)) : NSMakeSize((minor), (major)))

#define KFMAX(a,b) ((a)>(b)?(a):(b))

// proportionally scale a list of integers so that the sum of the resulting list is targetTotal
// Will fail (return NO) if all integers are zero 
// Favors not completely zeroing out a nonzero int
static BOOL kfScaleUInts(unsigned *integers, int numInts, unsigned targetTotal) 
{
    unsigned total;
    float scalingFactor;
    int i, numNonZeroInts;
    
    // compute total
    total = 0;
    numNonZeroInts = 0;
    for (i = 0; i < numInts; i++)
    {
        if (integers[i] != 0)
        {
            total += integers[i];
            numNonZeroInts++;
        }
    }
    
    if (numNonZeroInts == 0) // fail
    {
        return NO;
    }
    
    // compute scalingFactor
    scalingFactor = (float)targetTotal / total;
    
    // scale all ints and recompute total (which may not equal targetTotal due to roundoff error)
    total = 0;
    for (i = 0; i < numInts; i++)
    {
        if (integers[i] != 0)
        {
            // this is preferable to rounding when used for subviews - helps
            // prevent a subview getting stuck at thickness 1 during a drag resize
            integers[i] = MAX(floor(scalingFactor*integers[i]), 1); 
            total += integers[i];
        }
    }
    
    // Each non-zero integer may be as much as 1 off of its "proper" floating point value due to roundoff,
    // so abs(targetTotal - total) might be as much as numNonZero.  We randomly choose integers to increment (or decrement)
    // to make up the gap, and we choose only from the non-zero values.
    int gap = abs(targetTotal - total);
    int closeGapIncrement =  (targetTotal > total) ? 1 : -1;
    int numRemainingNonZeroInts = numNonZeroInts;
    for (i = 0; i < numInts && gap > 0; i++)
    {
        if (integers[i] > 0)
        {
            BOOL shouldIncrementInt =  (gap == numRemainingNonZeroInts) || (rand() < (float) gap / numRemainingNonZeroInts * RAND_MAX);
            if (shouldIncrementInt)
            {
                integers[i] += closeGapIncrement;
                gap--;
            }
            numRemainingNonZeroInts--;
        }
    }
    
    return YES;
}

@interface KFSplitView (kfPrivate)

+ (NSString *)kfDefaultsKeyForName:(NSString *)name;
- (void)kfSetup;
- (void)kfSetupResizeCursors;
- (int)kfGetDividerAtMajCoord:(float)coord;
- (void)kfPutDivider:(int)offset atMajCoord:(float)coord;
- (void)kfRecalculateDividerRects;
- (void)kfMoveCollapsedSubviewsOffScreen;
- (void)kfSavePositionUsingAutosaveName:(id)sender;

- (void)kfLayoutSubviewsUsingThicknesses:(unsigned *)subviewThicknesses;

@end

@implementation KFSplitView

/*****************
 * Initialization
 *****************/
#pragma mark Setup/teardown:

+ (void)initialize
{
    kfInUsePositionNames = [[NSMutableSet alloc] init];
}

- initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect]))
    {
        [self kfSetup];
    }

    return self;
}

- initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        [self kfSetup];
    }

    return self;
}

- (void)kfSetup
{
    // be sure to setup cursors before calling setVertical:
    [self kfSetupResizeCursors];

    kfCollapsedSubviews = [[NSMutableSet alloc] init];
    kfDividerRects = [[NSMutableArray alloc] init];
    
    kfDefaults = [NSUserDefaults standardUserDefaults];
    kfNotificationCenter = [NSNotificationCenter defaultCenter];

    [self setVertical:[self isVertical]];
}

// Attempts to find cursors to use as kfIsVerticalResizeCursor and kfNotIsVerticalResizeCursor.
// These cursors are eventually released, so make sure each receives a retain message now.
// If no good cursors can be found, an error is printed and the arrow cursor is used.
- (void)kfSetupResizeCursors
{
    NSImage *isVerticalImage, *isNotVerticalImage;

    if ((isVerticalImage = [NSImage imageNamed:@"NSTruthHorizontalResizeCursor"])); // standard Jaguar NSSplitView resize cursor
    else if  ((isVerticalImage = [NSImage imageNamed:@"NSTruthHResizeCursor"]));

    if (isVerticalImage)
    {
        kfIsVerticalResizeCursor = [[NSCursor alloc] initWithImage:isVerticalImage
                                                           hotSpot:NSMakePoint(8,8)];
    }

    if ((isNotVerticalImage = [NSImage imageNamed:@"NSTruthVerticalResizeCursor"])); // standard Jaguar NSSplitView resize cursor
    else if  ((isNotVerticalImage = [NSImage imageNamed:@"NSTruthVResizeCursor"]));

    if (isNotVerticalImage)
    {
        kfNotIsVerticalResizeCursor = [[NSCursor alloc] initWithImage:isNotVerticalImage
                                                           hotSpot:NSMakePoint(8,8)];
    }

    if (kfIsVerticalResizeCursor == nil)
    {
        kfIsVerticalResizeCursor = [[NSCursor arrowCursor] retain];
        NSLog(@"Warning - no horizontal resizing cursor located.  Please report this as a bug.");
    }
    if (kfNotIsVerticalResizeCursor == nil)
    {
        kfNotIsVerticalResizeCursor = [[NSCursor arrowCursor] retain];
        NSLog(@"Warning - no vertical resizing cursor located.  Please report this as a bug.");
    }
}

- (void)awakeFromNib
{
    [self kfRecalculateDividerRects];
}

- (void)dealloc
{
    [self setDelegate:nil];
    [self setPositionAutosaveName:@""];
    [kfCollapsedSubviews release];
    [kfDividerRects release];
    [kfIsVerticalResizeCursor release];
    [kfNotIsVerticalResizeCursor release];
    [super dealloc];
}

/******************
 * Main processing
 ******************/
#pragma mark Main processing:

- (void)mouseDown:(NSEvent *)theEvent
{
    // All coordinates are major axis coordinates unless otherwise specified.  See the top of the file
    // for an explanation of major and minor axes.
    float   minorDim;                                           // common dimension of all subviews
    int     divider;                                            // index of a divider being dragged
    float   mouseCoord, mouseToDividerOffset;                   // the mouse holds on to whatever part of the divider it grabs onto
    float   dividerThickness;                                   
    float   dividerCoord, prevDividerCoord;                     
    float   hardMinCoord, hardMaxCoord;                         // absolute boundaries for dividerCoord
    float   delMinCoord, delMaxCoord;                           // boundaries for dividerCoord according to the delegate (not absolute)
    NSView *firstSubview, *secondSubview;                       // subviews above and below the divider (if !isVertical)
    float   firstSubviewMinCoord, secondSubviewMaxCoord;        // top of the first, bottom of the second (if !isVertical)
    BOOL    firstSubviewCanCollapse, secondSubviewCanCollapse;  
    NSDate *distantFuture;
    float (*splitPosConstraintFunc)(id, SEL, ...);              // delegate supplied function to constrain dividerCoord

    // setup
    minorDim = KFMINORDIMOFSIZE([self frame].size);
    dividerThickness = [self dividerThickness];
    distantFuture = [NSDate distantFuture];

    // PRECOMPUTATION - we do as much as we can before starting the event loop.
    
    // figure out which divider is being dragged
    mouseCoord = KFMAJORCOORDOFPOINT([self convertPoint:[theEvent locationInWindow] fromView:nil]);
    divider = [self kfGetDividerAtMajCoord:mouseCoord];
    if (divider == NSNotFound)
    {
        return;
    }

    // if the event is a double click we let the delegate deal with it
    if ([theEvent clickCount] > 1)
    {
        if ([kfDelegate respondsToSelector:@selector(splitView:didDoubleClickInDivider:)])
        {
            [kfDelegate splitView:self didDoubleClickInDivider:divider];
            return;
        }
    }

    // firstSubview is the subview above (left) of the divider
    // secondSubview is the subview below (right) of the divider
    firstSubview = [[self subviews] objectAtIndex:divider];
    secondSubview = [[self subviews] objectAtIndex:divider+1];

    // set firstSubviewMinCoord and secondSubviewMaxCoord.  Here's a little diagram:
    //     ------------ <- firstSubviewMinCoord
    //
    //
    //
    //
    //     ------------ <- dividerCoord (not set yet)
    //     ------------
    //
    //
    //     ------------ <- secondSubviewMaxCoord
    if (![self isSubviewCollapsed:firstSubview])
    {
        firstSubviewMinCoord = KFMAJORCOORDOFPOINT([firstSubview frame].origin);
    }
    else
    {
        firstSubviewMinCoord = KFMAJORCOORDOFPOINT([[kfDividerRects objectAtIndex:divider] rectValue].origin);
    }
    if (![self isSubviewCollapsed:secondSubview])
    {
        secondSubviewMaxCoord = KFMAJORCOORDOFPOINT([secondSubview frame].origin) + KFMAJORDIMOFSIZE([secondSubview frame].size);
    }
    else
    {
        secondSubviewMaxCoord = KFMAJORCOORDOFPOINT([[kfDividerRects objectAtIndex:divider] rectValue].origin) + dividerThickness;
    }

    // hardMinCoord and hardMaxCoord are the absolute minimum and maximum values that may be
    // assigned to dividerCoord. delMinCoord and delMaxCoord are minimum and maximum values
    // for dividerCoord that are supplied by the delegate. These last are _not_ absolute: if the
    // delegate allows collapsing of subviews then dividerCoord can snap from delMinCoord to
    // hardMinCoord if the user drags the divider more than halfway across the region between them.
    // See Apple's NSSplitView documenation under - splitView:canCollapseSubview:.
    
    hardMinCoord = firstSubviewMinCoord;
    hardMaxCoord = secondSubviewMaxCoord - dividerThickness;

    delMinCoord = hardMinCoord;
    delMaxCoord = hardMaxCoord;
    
    if ([kfDelegate respondsToSelector:@selector(splitView:constrainMinCoordinate:ofSubviewAt:)])
    {
        delMinCoord = [kfDelegate splitView:self
                     constrainMinCoordinate:delMinCoord
                                ofSubviewAt:divider];
    }
    if ([kfDelegate respondsToSelector:@selector(splitView:constrainMaxCoordinate:ofSubviewAt:)])
    {
        delMaxCoord = [kfDelegate splitView:self
                     constrainMaxCoordinate:delMaxCoord
                                ofSubviewAt:divider];
    }

    delMinCoord = (delMinCoord < hardMinCoord) ? hardMinCoord : delMinCoord;
    delMaxCoord = (delMaxCoord > hardMaxCoord) ? hardMaxCoord : delMaxCoord;

    if (delMinCoord > delMaxCoord)
    {
        // this follows apple's implementation.  It says that if the delegate does
        // not supply any zone where the divider can sit without collapsing a subview then 
        // ignore the delegate.  The other option would be to always collapse to one subview
        // or the other, if one or both of the subviews are collasible.  That could be a bit of a UI
        // problem, because the user could try to drag a subview and have nothing happen.
        delMinCoord = hardMinCoord;
        delMaxCoord = hardMaxCoord;
    }

    firstSubviewCanCollapse = NO;
    secondSubviewCanCollapse = NO;
    if ([kfDelegate respondsToSelector:@selector(splitView:canCollapseSubview:)])
    {
        firstSubviewCanCollapse = [kfDelegate splitView:self canCollapseSubview:firstSubview];
        secondSubviewCanCollapse = [kfDelegate splitView:self canCollapseSubview:secondSubview];
    }

    // The delegate may constrain the possible values for dividerCoord.
    // Since this method will be called repeatedly we cache a pointer to it.
    splitPosConstraintFunc = NULL;
    if ([kfDelegate respondsToSelector:@selector(splitView:constrainSplitPosition:ofSubviewAt:)])
    {
        splitPosConstraintFunc = (float (*)(id, SEL, ...))[kfDelegate methodForSelector:@selector(splitView:constrainSplitPosition:ofSubviewAt:)];
    }

    // When the user grabs and drags the divider he holds onto that
    // particular spot while dragging.
    // mouseToDividerOffset is the difference between dividerCoord (the top of
    // the divider) and mouseCoord. 
    mouseToDividerOffset = KFMAJORCOORDOFPOINT([[kfDividerRects objectAtIndex:divider] rectValue].origin) - mouseCoord;

    // EVENT-LOOP
    prevDividerCoord = 1000000; // something non-sensical
    do
    {
        mouseCoord = KFMAJORCOORDOFPOINT([self convertPoint:[theEvent locationInWindow] fromView:nil]);
        dividerCoord = mouseCoord + mouseToDividerOffset;
        if (splitPosConstraintFunc != NULL)
        {
            dividerCoord = (*splitPosConstraintFunc)(kfDelegate,
                                                     @selector(splitView:constrainSplitPosition:ofSubviewAt:),
                                                     self,
                                                     dividerCoord,
                                                     divider);
        }

        // There are five regions where user may have dragged the divider:
        //     collapse first subview
        //     stick the divider to delMinCoord
        //     move freely
        //     stick the divider to delMaxCoord
        //     collapse the second subview
        if ( hardMinCoord == hardMaxCoord )
        {
            // special case: divider is pinned.  It is possible to collapse both subviews.
            [self setSubview:firstSubview isCollapsed:firstSubviewCanCollapse];
            [self setSubview:secondSubview isCollapsed:secondSubviewCanCollapse];
            dividerCoord = hardMinCoord;
        }
        else if ( firstSubviewCanCollapse &&
                  dividerCoord < hardMinCoord + (delMinCoord - hardMinCoord)/2)
        {
            // collapse first subview
            [self setSubview:secondSubview isCollapsed:NO];
            [self setSubview:firstSubview isCollapsed:YES];
            dividerCoord = hardMinCoord;
        }
        else if ( dividerCoord < delMinCoord )
        {
            // stick to delMinCoord
            [self setSubview:firstSubview isCollapsed:NO];
            [self setSubview:secondSubview isCollapsed:NO];
            dividerCoord = delMinCoord;
        }
        else if ( dividerCoord < delMaxCoord )
        {
            // move freely
            [self setSubview:firstSubview isCollapsed:NO];
            [self setSubview:secondSubview isCollapsed:NO];
        }
        else if ( !secondSubviewCanCollapse ||
                  dividerCoord < hardMaxCoord - (hardMaxCoord - delMaxCoord)/2 )
        {
            // stick to delMaxCoord
            [self setSubview:firstSubview isCollapsed:NO];
            [self setSubview:secondSubview isCollapsed:NO];
            dividerCoord = delMaxCoord;
        }
        else
        {
            // collapse second subview
            [self setSubview:firstSubview isCollapsed:NO];
            [self setSubview:secondSubview isCollapsed:YES];
            dividerCoord = hardMaxCoord;
        }

        if (prevDividerCoord != dividerCoord)
        {
            // Position and resize elements.  A collapsing subview's frame size doesn't change,
            // the subview just gets moved way offscreen (as in NSSplitView).
            // The diagram may help:
            //
            //     ------------ <- firstSubviewMinCoord
            //
            //
            //
            //     ------------ <- dividerCoord
            //     ------------ <- dividerCoord + dividerThickness
            //
            //
            //     ------------ <- secondSubviewMaxCoord
            
            [kfNotificationCenter postNotificationName:NSSplitViewWillResizeSubviewsNotification object:self];

            // divider
            [self kfPutDivider:divider atMajCoord:dividerCoord];

            // firstSubview
            if (![self isSubviewCollapsed:firstSubview])
            {
                NSRect newFrame;
                
                newFrame.origin = KFPOINTWITHMAJMIN(firstSubviewMinCoord,0);
                newFrame.size = KFSIZEWITHMAJMIN(dividerCoord - firstSubviewMinCoord, minorDim);
                
                if (!NSEqualRects([firstSubview frame],newFrame))
                {
                    [firstSubview setFrame:newFrame];
                    [firstSubview setNeedsDisplay:YES];
                }
            }
            else
            {
                [firstSubview setFrameOrigin:KFOffScreenPoint];
            }

            // secondSubview
            if (![self isSubviewCollapsed:secondSubview])
            {
                NSRect newFrame;
                
                newFrame.origin = KFPOINTWITHMAJMIN(dividerCoord + dividerThickness, 0);
                newFrame.size = KFSIZEWITHMAJMIN(secondSubviewMaxCoord - (dividerCoord + dividerThickness), minorDim);
                
                if (!NSEqualRects([secondSubview frame],newFrame))
                {
                    [secondSubview setFrame:newFrame];
                    [secondSubview setNeedsDisplay:YES];
                }                
            }
            else
            {
                [secondSubview setFrameOrigin:KFOffScreenPoint];
            }
            
            [kfNotificationCenter postNotificationName:NSSplitViewDidResizeSubviewsNotification object:self];

            prevDividerCoord = dividerCoord;
        }

        // get the next relevant event
        theEvent = [NSApp nextEventMatchingMask:NSLeftMouseDraggedMask|NSLeftMouseUpMask
                                      untilDate:distantFuture
                                         inMode:NSEventTrackingRunLoopMode
                                        dequeue:YES];
        
    } while ([theEvent type] == NSLeftMouseDragged);
    
    // inform delegate that user has finished dragging divider
    if ([kfDelegate respondsToSelector:@selector(splitView:didFinishDragInDivider:)])
    {
        [kfDelegate splitView:self didFinishDragInDivider:divider];
    }    
}

// Call this method to retile the subviews, not adjustSubviews.
// It 1) dispatches will and did resize subviews notifications
//    2) calls the appropriate method to do the retiling.  That's a method of
//       the delegate if it has one and the default adjustSubviews otherwise.
//    3) cleans up some other layout, like divider positions
- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{    
    [kfNotificationCenter postNotificationName:NSSplitViewWillResizeSubviewsNotification object:self];
    
    if ([kfDelegate respondsToSelector:@selector(splitView:resizeSubviewsWithOldSize:)])
    {
        [kfDelegate splitView:self resizeSubviewsWithOldSize:oldBoundsSize];
    }
    else
    {
        [self adjustSubviews];
    }
    
    [self kfRecalculateDividerRects];
    [self kfMoveCollapsedSubviewsOffScreen];
    
    [kfNotificationCenter postNotificationName:NSSplitViewDidResizeSubviewsNotification object:self];
}


// See Apple's NSSplitView docs.  However, note that in general you want to call
// resizeSubviewsWithOldSize:, not this method.  The exception is that you might
// want to call adjustSubviews from splitView:resizeSubviewsWithOldSize: in the
// the delegate
- (void)adjustSubviews
{
    int i, numSubviews;
    NSArray *subviews;
    
    // The 'thickness' of a subview will mean the amount of space along
    // the major axis that the subview occupies in the splitview. 
    // We work in integral values, though actual thicknesses are floats.
    // In the current OS, the floats actually have integral values.
    //
    // Ex 1: The thickness of a collapsed subview is 0.
    // Ex 2: For an uncollapsed subview in a horizontal (standard direction) splitview,
    //       thickness means height.
    unsigned *subviewThicknesses;
    
    // setup 
    subviews = [self subviews];
    numSubviews = [subviews count];
    if (numSubviews == 0)
    {
        return;
    }
    
    subviewThicknesses = malloc(sizeof(unsigned)*numSubviews);
    
    // Fill out subviewThicknesses array.
    // Also keep track of the total thickness of all subviews, and 
    // of the first expanded subview
    unsigned totalSubviewThicknesses = 0;
    int firstExpandedSubviewIndex = NSNotFound;
    for (i = 0; i < numSubviews; i++)
    {
        NSView *subview = [subviews objectAtIndex:i];
        if (![self isSubviewCollapsed:subview])
        {
            subviewThicknesses[i] = floor(KFMAJORDIMOFSIZE([subview frame].size));
            totalSubviewThicknesses += subviewThicknesses[i];
            if (firstExpandedSubviewIndex == NSNotFound) { firstExpandedSubviewIndex = i; }
        }
        else
        {
            subviewThicknesses[i] = 0;
        }
    }
    
    // Compute new thicknesses for subviews.
    
    // In the end, the subview thicknesses should sum to the thickness of the splitview minus the space occupied by dividers.
    unsigned targetTotalSubviewsThickness = KFMAX(floor(KFMAJORDIMOFSIZE([self frame].size) - [self dividerThickness]*(numSubviews - 1)), 0);
    
    // If at least one of the subviews has positive thickness
    if (totalSubviewThicknesses != 0)
    {
        // then we can scale all the thicknesses 
        kfScaleUInts(subviewThicknesses, numSubviews, targetTotalSubviewsThickness);        
    }
    else // otherwise we'll have to expand one of the subviews to fill the entire space
    {
        if (firstExpandedSubviewIndex != NSNotFound)
        {
            subviewThicknesses[firstExpandedSubviewIndex] = targetTotalSubviewsThickness;
        }
        else
        {
            subviewThicknesses[0] = targetTotalSubviewsThickness;
        }
    }
    
    
    // layout subviews
    [self kfLayoutSubviewsUsingThicknesses:subviewThicknesses];
    
    // cleanup 
    free(subviewThicknesses);
}

// Required: Sum of all subviewThicknesses <= splitViewThickness - dividersThickness.   
// If the splitview has positive available space for subviews, then one of the supplied subview thicknesses
// must also be positive.  Extra space will be dumped into the last subview with positive thickness.  
// See adjustSubviews for the definition of 'thickness'.
// 
// Does not currently put collapsed subviews off screen or do divider placement.
// Could be done efficiently here, but would duplicate functionality of other methods.
- (void)kfLayoutSubviewsUsingThicknesses:(unsigned *)subviewThicknesses
{
    int i, lastPositiveThicknessSubviewIndex, numSubviews;
    float minorDimOfSplitViewSize;
    float curMajAxisPos, dividerThickness;
    NSArray *subviews;
    
    // setup
    subviews = [self subviews];
    numSubviews = [subviews count];
    minorDimOfSplitViewSize = KFMINORDIMOFSIZE([self frame].size);
    dividerThickness = [self dividerThickness];
    
    // Compute lastPositiveThicknessSubviewIndex.
    lastPositiveThicknessSubviewIndex = NSNotFound;
    for (i = numSubviews - 1; i >= 0; i--)
    {
        if (subviewThicknesses[i] != 0)
        {
            lastPositiveThicknessSubviewIndex = i;
            break;
        }
    }
    
    // We walk down the major axis, setting subview frames as we go.
    curMajAxisPos = 0;
    for (i = 0; i < numSubviews; i++)
    {
        NSView *subview = [subviews objectAtIndex:i];
        
        float newSubviewThickness = -1; // sentinel value, meaning "do not change"

        if (subviewThicknesses[i] == 0) // If subview should have no thickness
        {
            // then shrink its frame if it is uncollapsed.
            if (![self isSubviewCollapsed:subview]) 
            {
                newSubviewThickness = 0;
            }
        }
        else // If supplied thickness is positive
        {            
            // make sure the subview isn't collapsed.
            if ([self isSubviewCollapsed:subview])
            {
                [self setSubview:subview isCollapsed:NO];
            }
            
            
            // If this is the last subview that we're going to give a positive thickness
            if (i == lastPositiveThicknessSubviewIndex)
            {
                // we overrule the given the given value and just fill all available area.
                float remainingDividersThickness = (numSubviews - 1 - i)*dividerThickness;
                float splitViewThickness = KFMAJORDIMOFSIZE([self frame].size);
                
                newSubviewThickness = KFMAX(splitViewThickness - curMajAxisPos - remainingDividersThickness, 0); 
            }
            else // If this isn't the last subview that we're going to set to a positive thickness
            {
                // use the supplied thickness.
                newSubviewThickness = subviewThicknesses[i];
            }
        }
        
        // If we found a new subview thickness
        if (newSubviewThickness != -1)
        {
            // set the subview's frame accordingly
            NSPoint newSubviewOrigin = KFPOINTWITHMAJMIN(curMajAxisPos, 0);
            NSSize  newSubviewSize   = KFSIZEWITHMAJMIN(newSubviewThickness, minorDimOfSplitViewSize);
            NSRect  newFrame         = NSMakeRect(newSubviewOrigin.x, newSubviewOrigin.y,
                                                  newSubviewSize.width, newSubviewSize.height);
            
            if (!NSEqualRects([subview frame],newFrame))
            {
                [subview setFrame:newFrame];
                [subview setNeedsDisplay:YES];
            }
            
            // and advance down the major axis.
            curMajAxisPos += newSubviewThickness;
        }

        // Account for divider thickness.
        if (i < numSubviews - 1)
        {
            curMajAxisPos += dividerThickness;
        }
    }    
}

- (void)kfMoveCollapsedSubviewsOffScreen
{
    NSEnumerator *collapsedSubviewEnumerator = [kfCollapsedSubviews objectEnumerator];
    NSView *subview;
    while ((subview = [collapsedSubviewEnumerator nextObject]))
    {
        [subview setFrameOrigin:KFOffScreenPoint];
    }
}


- (void)drawRect:(NSRect)rect
{
    int i, numDividers;

    numDividers = [kfDividerRects count];
    for (i = 0; i < numDividers; i++)
    {
        [self drawDividerInRect:[[kfDividerRects objectAtIndex:i] rectValue]];
    }
}

// returns the index ('offset' in Apple's docs) of the divider under the
// given coordinate, or NSNotFound if there isn't a divider there.
- (int)kfGetDividerAtMajCoord:(float)coord
{
    int i, numDividers, result;
    float curDividerMinimumMajorCoord, dividerThickness;
        
    numDividers = [kfDividerRects count];
    result = NSNotFound;
    dividerThickness = [self dividerThickness];
    
    for (i = 0; i < numDividers; i++)
    {
        curDividerMinimumMajorCoord = KFMAJORCOORDOFPOINT([[kfDividerRects objectAtIndex:i] rectValue].origin);
        if (curDividerMinimumMajorCoord <= coord && coord < curDividerMinimumMajorCoord + dividerThickness)
        {
            result = i;
            break;
        }
    }

    return result;
}

- (void)kfPutDivider:(int)offset atMajCoord:(float)coord
{
    NSPoint newOrigin;
    NSSize  newSize;
    NSRect  newFrame;

    while ([kfDividerRects count] <= offset)
    {
        [kfDividerRects addObject:[NSValue valueWithRect:NSZeroRect]];
    }
    
    newOrigin = KFPOINTWITHMAJMIN(coord,0);
    newSize = KFSIZEWITHMAJMIN([self dividerThickness], KFMINORDIMOFSIZE([self frame].size));
    newFrame = NSMakeRect(newOrigin.x, newOrigin.y, newSize.width, newSize.height);
    
    if (!NSEqualRects([[kfDividerRects objectAtIndex:offset] rectValue], newFrame))
    {
        [kfDividerRects replaceObjectAtIndex:offset withObject:[NSValue valueWithRect:newFrame]];
        [self setNeedsDisplayInRect:newFrame];
        [[[self subviews] objectAtIndex:offset]   setNeedsDisplay:YES];
        [[[self subviews] objectAtIndex:offset+1] setNeedsDisplay:YES];

    }
}

// positions all dividers based on the current location of the subviews
- (void)kfRecalculateDividerRects
{
    float curMajAxisPos, dividerThickness;
    id subview, subviews;
    int numSubviews, i;
    
    dividerThickness = [self dividerThickness];
    subviews = [self subviews];
    numSubviews = [subviews count];
    
    curMajAxisPos = 0;
    for (i = 0; i < numSubviews - 1; i++)
    {
        subview = [subviews objectAtIndex:i];
        if (![self isSubviewCollapsed:subview])
        {
            curMajAxisPos += KFMAJORDIMOFSIZE([subview frame].size);
        }

        [self kfPutDivider:i atMajCoord:curMajAxisPos];
        curMajAxisPos += dividerThickness;
    }
    
    int numDividerRects = [kfDividerRects count];
    if (numDividerRects > numSubviews - 1)
    {
        [kfDividerRects removeObjectsInRange:NSMakeRange(numSubviews-1,numDividerRects - numSubviews + 1)];
    }
    
    [[self window] invalidateCursorRectsForView:self];
}

- (void)resetCursorRects
{
    int i, numDividers;

    numDividers = [kfDividerRects count];
    for (i = 0; i < numDividers; i++)
    {
        [self addCursorRect:[[kfDividerRects objectAtIndex:i] rectValue]
                     cursor:kfCurrentResizeCursor];
    }
}

/******************
 * Accessors
 ******************/

- (void)setVertical:(BOOL)flag
{
    [super setVertical:flag]; 
    kfIsVertical = flag;
    if (kfIsVertical)
    {
        kfCurrentResizeCursor = kfIsVerticalResizeCursor;
    }
    else
    {
        kfCurrentResizeCursor = kfNotIsVerticalResizeCursor;
    }
}

- (id)delegate
{
    return kfDelegate;
}

// automatically registers the delegate for relevant notifications, and unregisters
// the old delegate for those same notifications.
- (void)setDelegate:(id)delegate
{
    id delegateAutoRegNotifications, delegateMethodNames;
    int i, numAutoRegNotifications;
    SEL methodSelector;

    delegateAutoRegNotifications = [NSArray arrayWithObjects:
        NSSplitViewWillResizeSubviewsNotification,
        NSSplitViewDidResizeSubviewsNotification,
        KFSplitViewDidCollapseSubviewNotification,
        KFSplitViewDidExpandSubviewNotification, nil];
    delegateMethodNames = [NSArray arrayWithObjects:
                           @"splitViewWillResizeSubviews:",
                           @"splitViewDidResizeSubviews:",
                           @"splitViewDidCollapseSubview:",
                           @"splitViewDidExpandSubview:", nil];
    numAutoRegNotifications = [delegateAutoRegNotifications count];

    if (kfDelegate)
    {
        for (i = 0; i < numAutoRegNotifications; i++)
        {
            [kfNotificationCenter removeObserver:kfDelegate
                                            name:[delegateAutoRegNotifications objectAtIndex:i]
                                          object:self];
        }
    }

    kfDelegate = delegate;

    if (kfDelegate)
    {
        for (i = 0; i < numAutoRegNotifications; i++)
        {
            methodSelector = sel_registerName([[delegateMethodNames objectAtIndex:i] cString]);
            if ([kfDelegate respondsToSelector:methodSelector])
            {
                [kfNotificationCenter addObserver:kfDelegate
                                         selector:methodSelector
                                             name:[delegateAutoRegNotifications objectAtIndex:i]
                                           object:self];
            }
        }
    }
}

- (BOOL)isSubviewCollapsed:(NSView *)subview
{
    return [kfCollapsedSubviews containsObject:subview];
}

- (void)setSubview:(NSView *)subview isCollapsed:(BOOL)flag
{
    NSDictionary *subviewDictionary;
    
    if (flag != [self isSubviewCollapsed:subview])
    {
        subviewDictionary = [NSDictionary dictionaryWithObject:subview forKey:@"subview"];
        if (flag)
        {
            [kfCollapsedSubviews addObject:subview];
            [kfNotificationCenter postNotificationName:KFSplitViewDidCollapseSubviewNotification
                                                object:self
                                              userInfo:subviewDictionary];
        }
        else
        {
            [kfCollapsedSubviews removeObject:subview];
            [kfNotificationCenter postNotificationName:KFSplitViewDidExpandSubviewNotification
                                                object:self
                                              userInfo:subviewDictionary];
        }
    }
}


/**********************
 * Position saving
 **********************/
#pragma mark Position saving:

// FOR DOCUMENTATION OF POSITION SAVING METHODS SEE APPLE'S NSWINDOW DOCS

+ (void)removePositionUsingName:(NSString *)name
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[[self class] kfDefaultsKeyForName:name]];
}

- (void)savePositionUsingName:(NSString *)name
{
    NSString *key = [[self class] kfDefaultsKeyForName:name];
    NSString *prop = [self plistObjectWithSavedPosition];
    [kfDefaults setObject:prop forKey:key];
}

- (BOOL)setPositionUsingName:(NSString *)name
{
    BOOL result;
    id object;

    object = [kfDefaults objectForKey:[[self class] kfDefaultsKeyForName:name]];
    if (object)
    {
        [self setPositionFromPlistObject:object];
        result = YES;
    }
    else
    {
        result = NO;
    }

    return result;
}

- (BOOL)setPositionAutosaveName:(NSString *)name
{
    if ([name isEqualToString:@""])
    {
        name = nil;
    }

    if ([kfInUsePositionNames containsObject:name])
    {
        return NO;
    }

    if (kfPositionAutosaveName)
    {
        [kfInUsePositionNames removeObject:kfPositionAutosaveName];
        [kfPositionAutosaveName autorelease];
    }

    kfPositionAutosaveName = [name copy];
    if (kfPositionAutosaveName)
    {
        [self setPositionUsingName:kfPositionAutosaveName];
        [kfInUsePositionNames addObject:kfPositionAutosaveName];
        [kfNotificationCenter addObserver:self
                                 selector:@selector(kfSavePositionUsingAutosaveName:)
                                     name:NSSplitViewDidResizeSubviewsNotification
                                   object:self];
    }
    else
    {
        [kfNotificationCenter removeObserver:self
                                        name:NSSplitViewDidResizeSubviewsNotification
                                      object:self];
    }

    return YES;
}

- (NSString *)positionAutosaveName
{
    return kfPositionAutosaveName;
}


static NSString *savedPositionVersionKey 		= @"version";
static NSString *savedPositionSubviewsKey 		= @"subviews";
static NSString *savedPositionSubviewFrameKey		= @"frame";
static NSString *savedPositionSubviewIsCollapsedKey	= @"collapsed";
static NSString *savedPositionIsVerticalKey		= @"isVertical";

- (void)setPositionFromPlistObject:(id)plistObject
{
    if ([plistObject isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *positionDict = (NSDictionary *)plistObject;
        
        // check position data format version
        if ([[positionDict objectForKey:savedPositionVersionKey] intValue] == 2)
        {
            NSArray *subviews, *subviewPositionsArray;
            int numSubviews, numSavedSubviews, numSettableSubviews, i;
            
            // set subview positions
            subviews = [self subviews];
            numSubviews = [subviews count];
            subviewPositionsArray = [positionDict objectForKey:savedPositionSubviewsKey];
            
            // what if the number of saved subview records and the actual number of subviews don't match?
            // we'll set positions until we run out of either subviews or data records
            numSavedSubviews = [subviewPositionsArray count];
            numSettableSubviews = (numSubviews < numSavedSubviews) ? numSubviews : numSavedSubviews;
            
            for (i = 0; i < numSettableSubviews; i++)
            {
                NSView *subview;
                NSDictionary *subviewPositionData;
            
                subview = [subviews objectAtIndex:i];
                subviewPositionData = [subviewPositionsArray objectAtIndex:i];
                
                // subview data consists of frame and collapse state
                [subview setFrame:NSRectFromString([subviewPositionData objectForKey:savedPositionSubviewFrameKey])];
                [self setSubview:subview isCollapsed:[[subviewPositionData objectForKey:savedPositionSubviewIsCollapsedKey] boolValue]];
            }
                        
            // set isVertical
            [self setVertical:[[positionDict objectForKey:savedPositionIsVerticalKey] boolValue]];            
        }
    }
    
    [self resizeSubviewsWithOldSize:[self bounds].size];    
}

- (id)plistObjectWithSavedPosition
{ 
    NSMutableDictionary *positionDict = [NSMutableDictionary dictionary];
    
    // save position data format version
    [positionDict setObject:[NSNumber numberWithInt:2] forKey:savedPositionVersionKey];
    
    // save subview positions
    NSArray *subviews;
    NSMutableArray *subviewPositionsArray;
    int numSubviews, i;
    
    subviews = [self subviews];
    numSubviews = [subviews count];
    subviewPositionsArray = [NSMutableArray array];
    
    for (i = 0; i < numSubviews; i++)
    {
        NSView *subview;
        NSDictionary *subviewPositionData;
        
        subview = [subviews objectAtIndex:i];
        
        // subview data consists of frame and collapse state
        subviewPositionData = [NSDictionary dictionaryWithObjectsAndKeys:
            NSStringFromRect([subview frame]), 					savedPositionSubviewFrameKey,
            [NSNumber numberWithBool:[self isSubviewCollapsed:subview]], 	savedPositionSubviewIsCollapsedKey,
            nil];
        [subviewPositionsArray addObject:subviewPositionData];
    }
        
    [positionDict setObject:subviewPositionsArray forKey:savedPositionSubviewsKey];
    
    // save isVertical
    BOOL isVertical = [self isVertical];
    [positionDict setObject:[NSNumber numberWithBool:isVertical]
                     forKey:savedPositionIsVerticalKey];
    
    return positionDict;
}


+ (NSString *)kfDefaultsKeyForName:(NSString *)name
{
    return [@"KFSplitView Position " stringByAppendingString:name];
}

- (void)kfSavePositionUsingAutosaveName:(id)sender
{
    [self savePositionUsingName:kfPositionAutosaveName];
}

/* layout
 * Returns an NSArray of the splitview layouts.
 */
-(NSArray *)layout
{
	NSMutableArray * viewRects = [NSMutableArray array];
	NSEnumerator * viewEnum = [[self subviews] objectEnumerator];
	NSView * view;
	NSRect frame;

	while ((view = [viewEnum nextObject]) != nil)
	{
		if ([self isSubviewCollapsed:view])
			frame = NSZeroRect;
		else
			frame = [view frame];
		[viewRects addObject:NSStringFromRect(frame)];
	}
	return viewRects;
}

/* setLayout
 * Sets the splitview layout from the specified array
 */
-(void)setLayout:(NSArray *)viewRects
{
	NSArray * views = [self subviews];
	int i, count;
	NSRect frame;

	count = MIN([viewRects count], [views count]);
	for (i = 0; i < count; i++)
	{
		frame = NSRectFromString([viewRects objectAtIndex: i]);
		if (NSIsEmptyRect(frame))
		{
			frame = [[views objectAtIndex:i] frame];
			if( [self isVertical] )
				frame.size.width = 0;
			else
				frame.size.height = 0;
		}
		[[views objectAtIndex:i] setFrame:frame];
	}
}

@end
#undef KFMAJORCOORDOFPOINT
#undef KFMINORCOORDOFPOINT
#undef KFMAJORDIMOFSIZE
#undef KFMINORDIMOFSIZE
#undef KFPOINTWITHMAJORMINOR
#undef KFSIZEWITHMAJORMINOR

#undef KFMAX

