//
//  EmptyTrashWarning.m
//  Vienna
//
//  Created by Jeffrey Johnson on 12/26/06.
//  Copyright 2006 Jeffrey Johnson. All rights reserved.
//

#import "EmptyTrashWarning.h"
#import "Constants.h"
#import "Preferences.h"

enum
{
	MA_EmptyTrashReturnCode_No = 0,
	MA_EmptyTrashReturnCode_Yes = 1,
};

@implementation EmptyTrashWarning

-(id)init
{
	return [super initWithWindowNibName:@"EmptyTrashWarning"];
}

-(void)windowWillLoad
{
	[doNotShowWarningAgain setState:NSOffState];
}

-(BOOL)shouldEmptyTrash
{
	BOOL shouldEmptyTrash = ([NSApp runModalForWindow:[self window]] == MA_EmptyTrashReturnCode_Yes);
	
	if ([doNotShowWarningAgain state] == NSOnState)
	{
		[[Preferences standardPreferences] setInteger:(shouldEmptyTrash ? MA_EmptyTrash_WithoutWarning : MA_EmptyTrash_None) forKey:MAPref_EmptyTrashNotification];
	}
	
	[self close];
	
	return shouldEmptyTrash;
}

-(IBAction)doNotEmptyTrash:(id)sender
{
	[NSApp stopModalWithCode:MA_EmptyTrashReturnCode_No];
}

-(IBAction)emptyTrash:(id)sender
{
	[NSApp stopModalWithCode:MA_EmptyTrashReturnCode_Yes];
}

@end
