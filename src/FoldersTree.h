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

@interface FoldersTree : NSView <NSOutlineViewDataSource>
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
    
}

// Public functions
-(void)initialiseFoldersTree;
-(void)saveFolderSettings;
-(void)updateAlternateMenuTitle;
-(void)updateFolder:(NSInteger)folderId recurseToParents:(BOOL)recurseToParents;
-(BOOL)canDeleteFolderAtRow:(NSInteger)row;
-(BOOL)selectFolder:(NSInteger)folderId;
-(void)renameFolder:(NSInteger)folderId;
@property (nonatomic, readonly) NSInteger actualSelection;
-(void)setOutlineViewBackgroundColor: (NSColor *)color;
@property (nonatomic, readonly) NSInteger groupParentSelection;
@property (nonatomic, readonly) NSInteger countOfSelectedFolders;
@property (nonatomic, readonly, copy) NSArray *selectedFolders;
@property (nonatomic, readonly) NSInteger firstFolderWithUnread;
-(NSInteger)nextFolderWithUnread:(NSInteger)currentFolderId;
-(NSArray *)folders:(NSInteger)folderId;
-(NSArray *)children:(NSInteger)folderId;
@property (nonatomic, readonly, strong) NSView *mainView;
-(void)outlineViewWillBecomeFirstResponder;
-(void)setSearch:(NSString *)string;
@end
