//
//  EmptyTrashWarning.m
//  Vienna
//
//  Created by Jeffrey Johnson on 12/26/06.
//  Copyright (c) 2004-2006 Jeffrey Johnson. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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

-(instancetype)init
{
	return [super initWithWindowNibName:@"EmptyTrashWarning"];
}

-(void)windowWillLoad
{
	doNotShowWarningAgain.state = NSOffState;
}

-(BOOL)shouldEmptyTrash
{
	BOOL shouldEmptyTrash = ([NSApp runModalForWindow:self.window] == MA_EmptyTrashReturnCode_Yes);
	
	if (doNotShowWarningAgain.state == NSOnState)
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
