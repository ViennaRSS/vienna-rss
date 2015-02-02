//
//  PXListViewCell.m
//  PXListView
//
//  Created by Alex Rozanski on 29/05/2010.
//  Copyright 2010 Alex Rozanski. http://perspx.com. All rights reserved.
//

#import "PXListViewCell.h"
#import "PXListViewCell+Private.h"

#import <iso646.h>

#import "PXListView.h"
#import "PXListView+Private.h"
#import "PXListView+UserInteraction.h"

#pragma mark -

@implementation PXListViewCell

@synthesize reusableIdentifier = _reusableIdentifier;
@synthesize listView = _listView;
@synthesize row = _row;

+ (id)cellLoadedFromNibNamed:(NSString*)nibName reusableIdentifier:(NSString*)identifier
{
    return [self cellLoadedFromNibNamed:nibName bundle:nil reusableIdentifier:identifier];
}

+ (id)cellLoadedFromNibNamed:(NSString*)nibName bundle:(NSBundle*)bundle reusableIdentifier:(NSString*)identifier
{
    NSNib *cellNib = [[NSNib alloc] initWithNibNamed:nibName bundle:bundle];
    NSArray *objects = nil;
    
    id cell = nil;
    
    [cellNib instantiateNibWithOwner:nil topLevelObjects:&objects];
    for(id object in objects) {
        if([object isKindOfClass:[self class]]) {
            cell = object;
            [cell setReusableIdentifier:identifier];
            break;
        }
    }
    
    [cellNib release];
    
    return cell;
}

#pragma mark -
#pragma mark Init/Dealloc

- (id)initWithReusableIdentifier:(NSString*)identifier
{
	if((self = [super initWithFrame: NSZeroRect]))
	{
		_reusableIdentifier = [identifier copy];
	}
	
	return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
	if((self = [super initWithCoder: aDecoder]))
	{
		_reusableIdentifier = NSStringFromClass([self class]);
	}
	
	return self;
}


- (void)dealloc
{
	[_reusableIdentifier release];
	[super dealloc];
}

#pragma mark -
#pragma mark Handling Selection

- (void)mouseDown:(NSEvent*)theEvent
{
	[[self listView] handleMouseDown:theEvent inCell:self];
}

- (BOOL)isSelected
{
	return [[[self listView] selectedRows] containsIndex:[self row]];
}

#pragma mark -
#pragma mark Drag & Drop

- (void)setDropHighlight:(PXListViewDropHighlight)inState
{
	[[self listView] setShowsDropHighlight: inState != PXListViewDropNowhere];
	
	_dropHighlight = inState;
	[self setNeedsDisplay:YES];
}

-(PXListViewDropHighlight)dropHighlight
{
	return _dropHighlight;
}

- (void)drawRect:(NSRect)dirtyRect
{
	if(_dropHighlight == PXListViewDropAbove)
	{
		[[NSColor alternateSelectedControlColor] set];
		NSRect		theBox = [self bounds];
		theBox.origin.y += theBox.size.height -1.0f;
		theBox.size.height = 2.0f;
		[NSBezierPath setDefaultLineWidth: 2.0f];
		[NSBezierPath strokeRect: theBox];
	}
	else if(_dropHighlight == PXListViewDropBelow)
	{
		[[NSColor alternateSelectedControlColor] set];
		NSRect		theBox = [self bounds];
		theBox.origin.y += 1.0f;
		theBox.size.height = 2.0f;
		[NSBezierPath setDefaultLineWidth: 2.0f];
		[NSBezierPath strokeRect: theBox];
	}
	else if(_dropHighlight == PXListViewDropOn)
	{
		[[NSColor alternateSelectedControlColor] set];
		NSRect		theBox = [self bounds];
		[NSBezierPath setDefaultLineWidth: 2.0f];
		[NSBezierPath strokeRect: NSInsetRect(theBox,1.0f,1.0f)];
	}
}


#pragma mark -
#pragma mark Reusing Cells

- (void)prepareForReuse
{
	_dropHighlight = PXListViewDropNowhere;
}


#pragma mark layout

-(void)layoutSubviews;
{
    
}

#pragma mark -
#pragma mark Accessibility

-(NSArray*)	accessibilityAttributeNames
{
	NSMutableArray*	attribs = [[[super accessibilityAttributeNames] mutableCopy] autorelease];
	
	[attribs addObject: NSAccessibilityRoleAttribute];
	[attribs addObject: NSAccessibilityEnabledAttribute];
	
	return attribs;
}

-(BOOL)	accessibilityIsAttributeSettable: (NSString *)attribute
{
	if( [attribute isEqualToString: NSAccessibilityRoleAttribute]
		or [attribute isEqualToString: NSAccessibilityEnabledAttribute] )
	{
		return NO;
	}
	else
		return [super accessibilityIsAttributeSettable: attribute];
}

-(id)	accessibilityAttributeValue: (NSString *)attribute
{
	if( [attribute isEqualToString: NSAccessibilityRoleAttribute] )
	{
		return NSAccessibilityRowRole;
	}
	else if( [attribute isEqualToString: NSAccessibilityEnabledAttribute] )
	{
		return [NSNumber numberWithBool: YES];
	}
	else
		return [super accessibilityAttributeValue: attribute];
}


-(NSArray *)	accessibilityActionNames
{
	return [NSArray arrayWithObjects: NSAccessibilityPressAction, nil];
}


-(NSString *)	accessibilityActionDescription: (NSString *)action
{
	return NSAccessibilityActionDescription(action);
}


-(void)	accessibilityPerformAction: (NSString *)action
{
	if( [action isEqualToString: NSAccessibilityPressAction] )
	{
		[[self listView] handleMouseDown: nil inCell: self];
	}
}


-(BOOL)	accessibilityIsIgnored
{
	return NO;
}

@end
