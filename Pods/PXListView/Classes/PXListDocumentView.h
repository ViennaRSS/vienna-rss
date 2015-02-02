//
//  PXListDocumentView.h
//  PXListView
//
//  Created by Alex Rozanski on 29/05/2010.
//  Copyright 2010 Alex Rozanski. http://perspx.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PXListViewDropHighlight.h"


@class PXListView;

@interface PXListDocumentView : NSView
{
	PXListView				*_listView;
	PXListViewDropHighlight	_dropHighlight;
}

@property (assign) PXListView				*listView;

-(void)	setDropHighlight: (PXListViewDropHighlight)inState;
-(PXListViewDropHighlight) dropHighlight;

@end
