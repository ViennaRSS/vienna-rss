//
//  SearchFolder.h
//  Vienna
//
//  Created by Steve on Sun Apr 18 2004.
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

@interface SmartFolder : NSWindowController {
	IBOutlet NSWindow * searchWindow;
	IBOutlet NSTextField * smartFolderName;
	IBOutlet NSButton * saveButton;
	IBOutlet NSButton * cancelButton;
	IBOutlet NSView * searchCriteriaSuperview;
	IBOutlet NSView * searchCriteriaView;
	IBOutlet NSButton * addCriteriaButton;
	IBOutlet NSButton * removeCriteriaButton;
	IBOutlet NSPopUpButton * fieldNamePopup;
	IBOutlet NSPopUpButton * operatorPopup;
	IBOutlet NSPopUpButton * criteriaConditionPopup;
	IBOutlet NSTextField * valueField;
	IBOutlet NSPopUpButton * dateValueField;
	IBOutlet NSTextField * numberValueField;
	IBOutlet NSPopUpButton * flagValueField;
	IBOutlet NSPopUpButton * folderValueField;
	NSMutableDictionary * nameToFieldMap;
	NSMutableArray * arrayOfViews;
	Database * db;
	NSRect searchWindowFrame;
	int smartFolderId;
	int totalCriteria;
	int parentId;
	BOOL firstRun;
}

@property(strong) NSArray * topObjects;

// Action routines
-(IBAction)doSave:(id)sender;
-(IBAction)doCancel:(id)sender;
-(IBAction)addNewCriteria:(id)sender;
-(IBAction)removeCurrentCriteria:(id)sender;
-(IBAction)fieldChanged:(id)sender;

// Public functions
-(void)newCriteria:(NSWindow *)window underParent:(int)itemId;
-(void)loadCriteria:(NSWindow *)window folderId:(int)folderId;

// General functions
-(id)initWithDatabase:(Database *)newDb;
@end
