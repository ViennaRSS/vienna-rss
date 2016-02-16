//
//  MyListViewCell.h
//  PXListView
//
//  Created by Alex Rozanski on 29/05/2010.
//  Copyright 2010 Alex Rozanski. http://perspx.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PXListViewCell.h"

@interface MyListViewCell : PXListViewCell
{
	NSTextField *titleLabel;
}

@property (nonatomic, retain) IBOutlet NSTextField *titleLabel;

@end
