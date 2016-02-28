//
//  PXListViewAppDelegate.h
//  PXListView
//
//  Created by Alex Rozanski on 29/05/2010.
//  Copyright 2010 Alex Rozanski. http://perspx.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PXListView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, PXListViewDelegate>
{
    IBOutlet NSWindow *window;
	IBOutlet PXListView	*listView;
	
	NSMutableArray *_listItems;
}

- (IBAction)reloadTable:(id)sender;

@end
