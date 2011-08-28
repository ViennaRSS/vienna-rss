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
#import "ThinSplitView.h"
#import "TreeNode.h"

@class FolderView;
@class PopupButton;
@class AppController;
@class Database;

@interface FoldersTree : NSView
{
	IBOutlet AppController * controller;
	IBOutlet FolderView * outlineView;
	IBOutlet ThinSplitView * folderSplitView;

	TreeNode * rootNode;
	NSFont * cellFont;
	NSFont * boldCellFont;
	NSImage * folderErrorImage;
	NSImage * refreshProgressImage;
	BOOL blockSelectionHandler;
	BOOL canRenameFolders;
    
    NSOperationQueue *operationQueue;
}

// Public functions
-(void)initialiseFoldersTree;
-(void)saveFolderSettings;
-(void)updateAlternateMenuTitle;
-(void)updateFolder:(int)folderId recurseToParents:(BOOL)recurseToParents;
-(BOOL)canDeleteFolderAtRow:(int)row;
-(BOOL)selectFolder:(int)folderId;
-(void)renameFolder:(int)folderId;
-(int)actualSelection;
-(void)setOutlineViewBackgroundColor: (NSColor *)color;
-(int)groupParentSelection;
-(int)countOfSelectedFolders;
-(NSArray *)selectedFolders;
-(int)firstFolderWithUnread;
-(int)nextFolderWithUnread:(int)currentFolderId;
-(NSArray *)folders:(int)folderId;
-(NSView *)mainView;
-(void)outlineViewWillBecomeFirstResponder;
@end
