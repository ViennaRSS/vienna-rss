//
//  NewGroupFolder.h
//  Vienna
//
//  Created by Steve on 6/4/05.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
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

#import <Cocoa/Cocoa.h>
#import "Database.h"

@interface NewGroupFolder : NSWindowController {
	IBOutlet NSWindow * newGroupFolderWindow;
	IBOutlet NSTextField * folderName;
	IBOutlet NSButton * saveButton;
	IBOutlet NSButton * cancelButton;
	NSInteger parentId;
}

@property(strong) NSArray * topObjects;

// Action handlers
-(IBAction)doSave:(id)sender;
-(IBAction)doCancel:(id)sender;

// General functions
-(void)newGroupFolder:(NSWindow *)window underParent:(NSInteger)itemId;
@end
