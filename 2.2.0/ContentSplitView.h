//
//  ContentSplitView.m
//
//  Created by Dave Batton, August 2006.
//  http://www.Mere-Mortal-Software.com/
//	
//	Changes by Michael Stroeck on February 11, 2007.
//
//  Copyright 2006 by Dave Batton. Some rights reserved.
//  http://creativecommons.org/licenses/by/2.5/
//
//  This class draws a horizontal splitter like the one seen in Apple Mail (Tiger), below the message list and above the message detail view. It subclasses KFSplitView from Ken Ferry so that the splitter remembers where it was last left. It also allows the splitter to expand and collapse when double-clicked. The splitter thickness is reduced a bit and a background image and dimple are drawn in the splitter.
//
//  Assumes the ContentSplitViewBar and ContentSplitViewDimple images are available.


#import <Cocoa/Cocoa.h>
#import "KFSplitView.h"


@interface ContentSplitView : KFSplitView {
	NSImage *bar;
	NSImage *grip;
	id bottomSubview;
}


@end
