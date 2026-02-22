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

@import Cocoa;

#import "FolderViewDelegate.h"

@class AppController;
@class FolderView;

@interface FoldersTree : NSObject <FolderViewDelegate, NSOutlineViewDataSource, NSTextFieldDelegate>

@property (weak, nonatomic) AppController *controller;
@property (weak, nonatomic) FolderView *outlineView;

-(void)initialiseFoldersTree;
-(void)saveFolderSettings;
-(void)updateFolder:(NSInteger)folderId recurseToParents:(BOOL)recurseToParents;
-(BOOL)selectFolder:(NSInteger)folderId;
-(void)renameFolder:(NSInteger)folderId;
@property (nonatomic, readonly) NSInteger actualSelection;
@property (nonatomic, readonly) NSInteger groupParentSelection;
@property (nonatomic, readonly) NSInteger countOfSelectedFolders;
@property (readonly, nonatomic) NSArray *selectedFolders;
@property (nonatomic, readonly) NSInteger firstFolderWithUnread;
-(NSInteger)nextFolderWithUnread:(NSInteger)currentFolderId;
-(NSArray *)folders:(NSInteger)folderId;
-(NSArray *)children:(NSInteger)folderId;
@property (nonatomic, readonly) NSView *mainView;
-(void)setSearch:(NSString *)string;

@end
