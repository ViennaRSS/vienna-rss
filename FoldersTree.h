//
//  FoldersTree.h
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
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
#import "TreeNode.h"

@class TexturedHeader;
@class FolderView;
@class PopupButton;
@class AppController;
@class Database;

@interface FoldersTree : NSView
{
	IBOutlet FolderView * outlineView;
	IBOutlet PopupButton * popupMenu;
	IBOutlet NSButton * newSubButton;
	IBOutlet NSButton * refreshButton;
	IBOutlet NSButton * markAllReadButton;
	IBOutlet TexturedHeader * folderHeader;

	AppController * controller;
	Database * db;
	TreeNode * rootNode;
	NSTimer * selectionTimer;
	NSFont * cellFont;
	NSFont * boldCellFont;
	NSImage * folderErrorImage;
	BOOL blockSelectionHandler;
}

// Public functions
-(void)setController:(AppController *)theController;
-(void)initialiseFoldersTree;
-(void)saveFolderSettings;
-(void)updateAlternateMenuTitle;
-(void)updateFolder:(int)folderId recurseToParents:(BOOL)recurseToParents;
-(BOOL)selectFolder:(int)folderId;
-(void)renameFolder:(int)folderId;
-(int)actualSelection;
-(int)groupParentSelection;
-(int)countOfSelectedFolders;
-(NSArray *)selectedFolders;
-(int)nextFolderWithUnread:(int)currentFolderId;
-(NSArray *)folders:(int)folderId;
-(NSView *)mainView;
@end
