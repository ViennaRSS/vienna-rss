//
//  EmptyTrashWarning.h
//  Vienna
//
//  Created by Jeffrey Johnson on 12/26/06.
//  Copyright 2006 Jeffrey Johnson. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface EmptyTrashWarning : NSWindowController
{
	IBOutlet NSButton * doNotShowWarningAgain;
}

-(BOOL)shouldEmptyTrash;

-(IBAction)doNotEmptyTrash:(id)sender;
-(IBAction)emptyTrash:(id)sender;

@end
