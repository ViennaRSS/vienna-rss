//
//  ArticleController.m
//  Vienna
//
//  Created by Steve on 5/6/06.
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

#import "ArticleController.h"
#import "AppController.h"
#import "Preferences.h"
#import "Constants.h"
#import "Database.h"
#import "ArticleFilter.h"
#import "ArticleRef.h"
#import "StringExtensions.h"
#import "GoogleReader.h"
#import "RefreshManager.h"
#import "ArticleListView.h"
#import "UnifiedDisplayView.h"

// Private functions
@interface ArticleController (Private)
	-(NSArray *)applyFilter:(NSArray *)unfilteredArray;
	-(void)setSortColumnIdentifier:(NSString *)str;
	-(NSArray *)wrappedMarkAllReadInArray:(NSArray *)folderArray withUndo:(BOOL)undoFlag;
	-(void)innerMarkReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag;
@end

@implementation ArticleController
@synthesize foldersTree, mainArticleView, currentArrayOfArticles, folderArrayOfArticles, articleSortSpecifiers, backtrackArray;

/* init
 * Initialise.
 */
-(instancetype)init
{
    if ((self = [super init]) != nil)
	{
		isBacktracking = NO;
		currentFolderId = -1;
		articleToPreserve = nil;

		// Set default values to generate article sort descriptors
		articleSortSpecifiers = @{
								  MA_Field_Folder: @{
										  @"key": @"containingFolder.name",
										  @"selector": @"compare:"
										  },
								  MA_Field_Read: @{
										  @"key": @"isRead",
										  @"selector": @"compare:"
										  },
								  MA_Field_Flagged: @{
										  @"key": @"isFlagged",
										  @"selector": @"compare:"
										  },
								  MA_Field_Comments: @{
										  @"key": @"hasComments",
										  @"selector": @"compare:"
										  },
								  MA_Field_Date: @{
										  @"key": [@"articleData." stringByAppendingString:MA_Field_Date],
										  @"selector": @"compare:"
										  },
								  MA_Field_Author: @{
										  @"key": [@"articleData." stringByAppendingString:MA_Field_Author],
										  @"selector": @"caseInsensitiveCompare:"
										  },
								  MA_Field_Headlines: @{
										  @"key": [@"articleData." stringByAppendingString:MA_Field_Subject],
										  @"selector": @"numericCompare:"
										  },
								  MA_Field_Subject: @{
										  @"key": [@"articleData." stringByAppendingString:MA_Field_Subject],
										  @"selector": @"numericCompare:"
										  },
								  MA_Field_Link: @{
										  @"key": [@"articleData." stringByAppendingString:MA_Field_Link],
										  @"selector": @"caseInsensitiveCompare:"
										  },
								  MA_Field_Summary: @{
										  @"key": [@"articleData." stringByAppendingString:MA_Field_Summary],
										  @"selector": @"caseInsensitiveCompare:"
										  },
								  MA_Field_HasEnclosure: @{
										  @"key": @"hasEnclosure",
										  @"selector": @"compare:"
										  },
								  MA_Field_Enclosure: @{
										  @"key": @"enclosure",
										  @"selector": @"caseInsensitiveCompare:"
										  },
								  };

		// Pre-set sort to what was saved in the preferences
		Preferences * prefs = [Preferences standardPreferences];
		NSArray * sortDescriptors = prefs.articleSortDescriptors;
		if (sortDescriptors.count == 0)
		{
			NSSortDescriptor * descriptor = [[NSSortDescriptor alloc] initWithKey:[@"articleData." stringByAppendingString:MA_Field_Date] ascending:YES];
			prefs.articleSortDescriptors = @[descriptor];
			[prefs setObject:MA_Field_Date forKey:MAPref_SortColumn];
		}
		[self setSortColumnIdentifier:[prefs stringForKey:MAPref_SortColumn]];
		
		// Create a backtrack array
		backtrackArray = [[BackTrackArray alloc] initWithMaximum:prefs.backTrackQueueSize];
		
		// Register for notifications
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleFilterChange:) name:@"MA_Notify_FilteringChange" object:nil];
		[nc addObserver:self selector:@selector(handleFolderNameChange:) name:@"MA_Notify_FolderNameChanged" object:nil];
		[nc addObserver:self selector:@selector(handleFolderUpdate:) name:@"MA_Notify_FoldersUpdated" object:nil];
		[nc addObserver:self selector:@selector(handleFolderAdded:) name:@"MA_Notify_FolderAdded" object:nil];
		[nc addObserver:self selector:@selector(handleRefreshArticle:) name:@"MA_Notify_ArticleViewChange" object:nil];
        
    }
    return self;
}

/* setLayout
 * Changes the layout of the panes.
 */
-(void)setLayout:(NSInteger)newLayout
{
	Article * currentSelectedArticle = self.selectedArticle;

	switch (newLayout)
	{
		case MA_Layout_Report:
		case MA_Layout_Condensed:
			self.mainArticleView = articleListView;
			break;

		case MA_Layout_Unified:
			self.mainArticleView = unifiedListView;
			break;
	}

	[Preferences standardPreferences].layout = newLayout;
	if (currentSelectedArticle != nil)
	{
	    [mainArticleView selectFolderAndArticle:currentFolderId guid:currentSelectedArticle.guid];
	    [self ensureSelectedArticle:NO];
	}

}

/* refreshCurrentFolder
 */
-(void)refreshCurrentFolder
{
	[mainArticleView refreshCurrentFolder];
}

/* currentFolderId
 * Returns the ID of the current folder being displayed by the view.
 */
-(NSInteger)currentFolderId
{
	return currentFolderId;
}

/* markedArticleRange
 * Retrieve an array of selected articles.
 * from the article list.
 */
-(NSArray *)markedArticleRange
{
	return mainArticleView.markedArticleRange;
}

/* saveTableSettings
 * Save selected article and folder
 * and, for relevant layouts, table settings
 */
-(void)saveTableSettings
{
	[mainArticleView saveTableSettings];
}

/* updateAlternateMenuTitle
 * Sets the approprate title for the alternate item in the contextual menu
 */
 -(void)updateAlternateMenuTitle
{
	if (mainArticleView ==  articleListView)
	{
		[articleListView updateAlternateMenuTitle];
	}
	else
	{
		[unifiedListView updateAlternateMenuTitle];
	}
}

/* updateVisibleColumns
 * For relevant layouts, adapt table settings
 */
-(void)updateVisibleColumns
{
    if (mainArticleView ==  articleListView)
        [articleListView updateVisibleColumns];
}

/* selectedArticle
 * Returns the currently selected article from the article list.
 */
-(Article *)selectedArticle
{
	return mainArticleView.selectedArticle;
}

/* allArticles
 * Returns the current filtered and sorted article array.
 */
-(NSArray *)allArticles
{
	return currentArrayOfArticles;
}

/* ensureSelectedArticle
 * Ensures that an article is selected in the list and that any selected
 * article is scrolled into view.
 */
-(void)ensureSelectedArticle:(BOOL)singleSelection
{
	[mainArticleView ensureSelectedArticle:singleSelection];
}

/* searchPlaceholderString
 * Return the search field placeholder.
 */
-(NSString *)searchPlaceholderString
{
	if (currentFolderId == -1)
		return @"";

	Folder * folder = [[Database sharedManager] folderFromID:currentFolderId];
	return [NSString stringWithFormat:NSLocalizedString(@"Search in %@", nil), folder.name];
}

/* sortColumnIdentifier
 * Returns the name of the column on which we're currently sorting.
 */
-(NSString *)sortColumnIdentifier
{
	return sortColumnIdentifier;
}

/* setSortColumnIdentifier
 * Sets the name of the column on which we're currently sorting.
 */
-(void)setSortColumnIdentifier:(NSString *)str
{
	sortColumnIdentifier = str;
}

/* sortByIdentifier
 * Sort by the column indicated by the specified column name.
 */
-(void)sortByIdentifier:(NSString *)columnName
{
	Preferences * prefs = [Preferences standardPreferences];
	NSMutableArray * descriptors = [NSMutableArray arrayWithArray:prefs.articleSortDescriptors];
	
	if ([sortColumnIdentifier isEqualToString:columnName])
		descriptors[0] = [descriptors[0] reversedSortDescriptor];
	else
	{
		[self setSortColumnIdentifier:columnName];
		[prefs setObject:sortColumnIdentifier forKey:MAPref_SortColumn];
		NSSortDescriptor * sortDescriptor;
		NSDictionary * specifier = [articleSortSpecifiers valueForKey:sortColumnIdentifier];
		NSUInteger index = [[descriptors valueForKey:@"key"] indexOfObject:[specifier valueForKey:@"key"]];

		if (index == NSNotFound)
			sortDescriptor = [[NSSortDescriptor alloc] initWithKey:[specifier valueForKey:@"key"] ascending:YES selector:NSSelectorFromString([specifier valueForKey:@"selector"])];
		else
		{
			sortDescriptor = descriptors[index];
			[descriptors removeObjectAtIndex:index];
		}
		[descriptors insertObject:sortDescriptor atIndex:0];
	}
	prefs.articleSortDescriptors = descriptors;
	[mainArticleView refreshFolder:MA_Refresh_SortAndRedraw];
}

/* sortIsAscending
 * Returns YES if the sort direction is currently set to ascending.
 */
-(BOOL)sortIsAscending
{
	Preferences * prefs = [Preferences standardPreferences];
	NSMutableArray * descriptors = [NSMutableArray arrayWithArray:prefs.articleSortDescriptors];
	NSSortDescriptor * sortDescriptor = descriptors[0];
	BOOL ascending = sortDescriptor.ascending;
	
	return ascending;
}

/* sortAscending
 * Sort by the direction indicated.
 */
-(void)sortAscending:(BOOL)newAscending
{
	Preferences * prefs = [Preferences standardPreferences];
	NSMutableArray * descriptors = [NSMutableArray arrayWithArray:prefs.articleSortDescriptors];
	NSSortDescriptor * sortDescriptor = descriptors[0];
	
	BOOL existingAscending = sortDescriptor.ascending;
	if ( newAscending != existingAscending )
	{
		descriptors[0] = sortDescriptor.reversedSortDescriptor;
		prefs.articleSortDescriptors = descriptors;
		[mainArticleView refreshFolder:MA_Refresh_SortAndRedraw];
	}
}

/* sortArticles
 * Re-orders the articles in currentArrayOfArticles by the current sort order
 */
-(void)sortArticles
{
	NSArray * sortedArrayOfArticles;

	sortedArrayOfArticles = [currentArrayOfArticles sortedArrayUsingDescriptors:[Preferences standardPreferences].articleSortDescriptors];
	NSAssert([sortedArrayOfArticles count] == [currentArrayOfArticles count], @"Lost articles from currentArrayOfArticles during sort");
	self.currentArrayOfArticles = sortedArrayOfArticles;
}

/* displayFirstUnread
 * Instructs the current article view to display the first unread article
 * in the database.
 */
-(void)displayFirstUnread
{
	[mainArticleView displayFirstUnread];
}

/* displayNextUnread
 * Instructs the current article view to display the next unread article
 * in the database.
 */
-(void)displayNextUnread
{
	[mainArticleView displayNextUnread];
}

/* displayFolder
 * Call the current article view to display the specified folder if it
 * is different from the current one.
 */
-(void)displayFolder:(NSInteger)newFolderId
{
	if (currentFolderId != newFolderId && newFolderId != 0)
	{
		currentFolderId = newFolderId;
		[self reloadArrayOfArticles];
		[self sortArticles];
		[mainArticleView selectFolderWithFilter:newFolderId];		
	}
}

/* reloadArrayOfArticles
 * Reload the folderArrayOfArticles from the current folder and applies the
 * current filter.
 */
-(void)reloadArrayOfArticles
{
	
	Folder * folder = [[Database sharedManager] folderFromID:currentFolderId];
	self.folderArrayOfArticles = [folder articlesWithFilter:APPCONTROLLER.filterString];
	
	[self refilterArrayOfArticles];
}

/* refilterArrayOfArticles
 * Reapply the current filter to the article array.
 */
-(void)refilterArrayOfArticles
{
	self.currentArrayOfArticles = [self applyFilter:folderArrayOfArticles];
}

/* applyFilter
 * Apply the active filter to unfilteredArray and return the filtered array.
 * This is done here rather than in the folder management code for simplicity.
 */
-(NSArray *)applyFilter:(NSArray *)unfilteredArray
{
	NSMutableArray * filteredArray = [NSMutableArray arrayWithArray:unfilteredArray];
	
	NSString * guidOfArticleToPreserve = (articleToPreserve != nil) ? articleToPreserve.guid : @"";
	NSInteger folderIdOfArticleToPreserve = articleToPreserve.folderId;
	
	ArticleFilter * filter = [ArticleFilter filterByTag:[Preferences standardPreferences].filterMode];
	SEL comparator = filter.comparator;
	NSInteger count = filteredArray.count;
	NSInteger index;
	
	for (index = count - 1; index >= 0; --index)
	{
		Article * article = filteredArray[index];
		if ((article.folderId == folderIdOfArticleToPreserve) && [article.guid isEqualToString:guidOfArticleToPreserve])
			guidOfArticleToPreserve = @"";
		else if ((comparator != nil) && !((BOOL)(NSInteger)[ArticleFilter performSelector:comparator withObject:article]))
			[filteredArray removeObjectAtIndex:index];
	}
	
	if (![guidOfArticleToPreserve isEqualToString:@""])
	{
		Article * articleToAdd = nil;
		Folder * folder = [[Database sharedManager] folderFromID:folderIdOfArticleToPreserve];
		if (folder != nil)
		{
			articleToAdd = [folder articleFromGuid:guidOfArticleToPreserve];
		}
		if (articleToAdd == nil)
			articleToAdd = articleToPreserve;
		if (articleToAdd != nil)
            [filteredArray addObject:articleToAdd];
	}
	[self setArticleToPreserve:nil];
	
	return [filteredArray copy];
}

/* markDeletedUndo
 * Undo handler to restore a series of deleted articles.
 */
-(void)markDeletedUndo:(id)anObject
{
	[self markDeletedByArray:(NSArray *)anObject deleteFlag:NO];
}

/* markUndeletedUndo
 * Undo handler to delete a series of articles.
 */
-(void)markUndeletedUndo:(id)anObject
{
	[self markDeletedByArray:(NSArray *)anObject deleteFlag:YES];
}

/* markDeletedByArray
 * Helper function. Takes as an input an array of articles and deletes or restores
 * the articles.
 */
-(void)markDeletedByArray:(NSArray *)articleArray deleteFlag:(BOOL)deleteFlag
{	
	// Set up to undo this action
	NSUndoManager * undoManager = NSApp.mainWindow.undoManager;
	SEL markDeletedUndoAction = deleteFlag ? @selector(markDeletedUndo:) : @selector(markUndeletedUndo:);
	[undoManager registerUndoWithTarget:self selector:markDeletedUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Delete", nil)];
	
	// We will make a new copy of currentArrayOfArticles and folderArrayOfArticles with the selected articles removed.
	NSMutableArray * currentArrayCopy = [NSMutableArray arrayWithArray:currentArrayOfArticles];
	NSMutableArray * folderArrayCopy = [NSMutableArray arrayWithArray:folderArrayOfArticles];
	__block BOOL needReload = NO;
	
	[self innerMarkReadByRefsArray:articleArray readFlag:YES];

	// Iterate over every selected article in the table and set the deleted
	// flag on the article while simultaneously removing it from our copies
	for (Article * theArticle in articleArray)
	{
		NSInteger folderId = theArticle.folderId;
		[[Database sharedManager] markArticleDeleted:folderId guid:theArticle.guid isDeleted:deleteFlag];
		if (![currentArrayOfArticles containsObject:theArticle])
			needReload = YES;
		else if (deleteFlag && (currentFolderId != [Database sharedManager].trashFolderId))
		{
			[currentArrayCopy removeObject:theArticle];
			[folderArrayCopy removeObject:theArticle];
		}
		else if (!deleteFlag && (currentFolderId == [Database sharedManager].trashFolderId))
		{
			[currentArrayCopy removeObject:theArticle];
			[folderArrayCopy removeObject:theArticle];
		}
		else
			needReload = YES;
	}

	self.currentArrayOfArticles = currentArrayCopy;
	self.folderArrayOfArticles = folderArrayCopy;
	if (needReload)
		[mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
	else
	{
		[mainArticleView refreshFolder:MA_Refresh_RedrawList];
		if (currentArrayOfArticles.count > 0u)
			[mainArticleView ensureSelectedArticle:YES];
		else
			[NSApp.mainWindow makeFirstResponder:foldersTree.mainView];
	}

	// If any of the articles we deleted were unread then the
	// folder's unread count just changed.
	[APPCONTROLLER showUnreadCountOnApplicationIconAndWindowTitle];
}

/* deleteArticlesByArray
 * Physically delete all selected articles in the article list.
 */
-(void)deleteArticlesByArray:(NSArray *)articleArray
{		
	// Make a new copy of currentArrayOfArticles and folderArrayOfArticles with the selected article removed.
	NSMutableArray * currentArrayCopy = [NSMutableArray arrayWithArray:currentArrayOfArticles];
	NSMutableArray * folderArrayCopy = [NSMutableArray arrayWithArray:folderArrayOfArticles];
	
	[self innerMarkReadByRefsArray:articleArray readFlag:YES];

	// Iterate over every selected article in the table and remove it from
	// the database.
	for (Article * theArticle in articleArray)	
	{
		NSInteger folderId = theArticle.folderId;
		if ([[Database sharedManager] deleteArticleFromFolder:folderId guid:theArticle.guid])
		{
			[currentArrayCopy removeObject:theArticle];
			[folderArrayCopy removeObject:theArticle];
		}
	}
	self.currentArrayOfArticles = currentArrayCopy;
	self.folderArrayOfArticles = folderArrayCopy;
	[mainArticleView refreshFolder:MA_Refresh_RedrawList];

	// Ensure there's a valid selection
    if (currentArrayOfArticles.count > 0u) {
		[mainArticleView ensureSelectedArticle:YES];
    } else {
		[NSApp.mainWindow makeFirstResponder:foldersTree.mainView];
    }
	// Read and/or unread count may have changed
	[APPCONTROLLER showUnreadCountOnApplicationIconAndWindowTitle];
}

/* markUnflagUndo
 * Undo handler to un-flag an array of articles.
 */
-(void)markUnflagUndo:(id)anObject
{
	[self markFlaggedByArray:(NSArray *)anObject flagged:NO];
}

/* markFlagUndo
 * Undo handler to flag an array of articles.
 */
-(void)markFlagUndo:(id)anObject
{
	[self markFlaggedByArray:(NSArray *)anObject flagged:YES];
}

/* markFlaggedByArray
 * Mark the specified articles in articleArray as flagged.
 */
-(void)markFlaggedByArray:(NSArray *)articleArray flagged:(BOOL)flagged
{	
	// Set up to undo this action
	NSUndoManager * undoManager = NSApp.mainWindow.undoManager;
	SEL markFlagUndoAction = flagged ? @selector(markUnflagUndo:) : @selector(markFlagUndo:);
	[undoManager registerUndoWithTarget:self selector:markFlagUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Flag", nil)];

	for (Article * theArticle in articleArray)
	{
		Folder *myFolder = [[Database sharedManager] folderFromID:theArticle.folderId];
		if (IsGoogleReaderFolder(myFolder)) {
			[[GoogleReader sharedManager] markStarred:theArticle starredFlag:flagged];
		}
		[[Database sharedManager] markArticleFlagged:theArticle.folderId
                                                guid:theArticle.guid
                                           isFlagged:flagged];
        [theArticle markFlagged:flagged];
	}

	[mainArticleView refreshFolder:MA_Refresh_RedrawList];
}

/* markUnreadUndo
 * Undo handler to mark an array of articles unread.
 */
-(void)markUnreadUndo:(id)anObject
{
	[self markAllReadByReferencesArray:(NSArray *)anObject readFlag:NO];
}

/* markReadUndo
 * Undo handler to mark an array of articles read.
 */
-(void)markReadUndo:(id)anObject
{
	[self markAllReadByReferencesArray:(NSArray *)anObject readFlag:YES];
}

/* markReadByArray
 * Helper function. Takes as an input an array of articles and marks those articles read or unread.
 */
-(void)markReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag
{
	// Set up to undo this action
	NSUndoManager * undoManager = NSApp.mainWindow.undoManager;	
	SEL markReadUndoAction = readFlag ? @selector(markUnreadUndo:) : @selector(markReadUndo:);
	[undoManager registerUndoWithTarget:self selector:markReadUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Mark Read", nil)];

    [self innerMarkReadByArray:articleArray readFlag:readFlag];

	[mainArticleView refreshFolder:MA_Refresh_RedrawList];
	
	// The info bar has a count of unread articles so we need to
	// update that.
	[APPCONTROLLER showUnreadCountOnApplicationIconAndWindowTitle];
}

/* innerMarkReadByArray
 * Marks all articles in the specified array read or unread.
 */
-(void)innerMarkReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag
{
	NSInteger lastFolderId = -1;
	
	for (Article * theArticle in articleArray)
	{
		NSInteger folderId = theArticle.folderId;
		if (theArticle.read != readFlag)
		{
			if (IsGoogleReaderFolder([[Database sharedManager] folderFromID:folderId])) {
				[[GoogleReader sharedManager] markRead:theArticle readFlag:readFlag];
			} else {
				[[Database sharedManager] markArticleRead:folderId guid:theArticle.guid isRead:readFlag];
				[theArticle markRead:readFlag];
				if (folderId != lastFolderId && lastFolderId != -1)
					[foldersTree updateFolder:lastFolderId recurseToParents:YES];
				lastFolderId = folderId;
			}
		}
	}
	if (lastFolderId != -1)
		[foldersTree updateFolder:lastFolderId recurseToParents:YES];
}

/* innerMarkReadByRefsArray
 * Marks all articles in the specified references array read or unread.
 */
-(void)innerMarkReadByRefsArray:(NSArray *)articleArray readFlag:(BOOL)readFlag
{
	Database * db = [Database sharedManager];
	NSInteger lastFolderId = -1;

	for (ArticleReference * articleRef in articleArray)
	{
		NSInteger folderId = articleRef.folderId;
		Folder * folder = [db folderFromID:folderId];
		if (IsGoogleReaderFolder(folder)){
			Article * article = [folder articleFromGuid:articleRef.guid];
			[[GoogleReader sharedManager] markRead:article readFlag:readFlag];
		} else {
			[db markArticleRead:folderId guid:articleRef.guid isRead:readFlag];
			if (folderId != lastFolderId && lastFolderId != -1)
				[foldersTree updateFolder:lastFolderId recurseToParents:YES];
			lastFolderId = folderId;
		}
	}
	if (lastFolderId != -1)
		[foldersTree updateFolder:lastFolderId recurseToParents:YES];
}

/* markAllReadUndo
 * Undo the most recent Mark All Read.
 */
-(void)markAllReadUndo:(id)anObject
{
	[self markAllReadByReferencesArray:(NSArray *)anObject readFlag:NO];
}

/* markAllReadRedo
 * Redo the most recent Mark All Read.
 */
-(void)markAllReadRedo:(id)anObject
{
	[self markAllReadByReferencesArray:(NSArray *)anObject readFlag:YES];
}

/* markAllReadByArray
 * Given an array of folders, mark all the articles in those folders as read and
 * return a reference array listing all the articles that were actually marked.
 */
-(void)markAllReadByArray:(NSArray *)folderArray withUndo:(BOOL)undoFlag withRefresh:(BOOL)refreshFlag
{
	NSArray * refArray = [self wrappedMarkAllReadInArray:folderArray withUndo:undoFlag];
	if (refArray != nil && refArray.count > 0)
	{
		NSUndoManager * undoManager = NSApp.mainWindow.undoManager;
		[undoManager registerUndoWithTarget:self selector:@selector(markAllReadUndo:) object:refArray];
		[undoManager setActionName:NSLocalizedString(@"Mark All Read", nil)];
	}

    for (Article * theArticle in folderArrayOfArticles) {
		[theArticle markRead:YES];
    }

    if (refreshFlag) {
		[mainArticleView refreshFolder:MA_Refresh_RedrawList];
    }
	[APPCONTROLLER showUnreadCountOnApplicationIconAndWindowTitle];
}

/* wrappedMarkAllReadInArray
 * Given an array of folders, mark all the articles in those folders as read and
 * return a reference array listing all the articles that were actually marked.
 */
-(NSArray *)wrappedMarkAllReadInArray:(NSArray *)folderArray withUndo:(BOOL)undoFlag
{
	NSMutableArray * refArray = [NSMutableArray array];
	
	for (Folder * folder in folderArray)
	{
		NSInteger folderId = folder.itemId;
		if (IsGroupFolder(folder) && undoFlag)
		{
			[refArray addObjectsFromArray:[self wrappedMarkAllReadInArray:[[Database sharedManager] arrayOfFolders:folderId] withUndo:undoFlag]];
		}
		else if (IsRSSFolder(folder))
		{
            if (undoFlag) {
				[refArray addObjectsFromArray:[folder arrayOfUnreadArticlesRefs]];
            }
			if ([[Database sharedManager] markFolderRead:folderId])
			{
				[foldersTree updateFolder:folderId recurseToParents:YES];
                
			}
		}
		else if (IsGoogleReaderFolder(folder))
		{
			NSArray * articleArray = [folder arrayOfUnreadArticlesRefs];
            if (undoFlag) {
				[refArray addObjectsFromArray:articleArray];
            }
			[self innerMarkReadByRefsArray:articleArray readFlag:YES];
		}
		else
		{
			// For smart folders, we only mark all read the current folder to
			// simplify things.
			if (undoFlag && folderId == currentFolderId)
			{
				[refArray addObjectsFromArray:currentArrayOfArticles];
				[self innerMarkReadByArray:currentArrayOfArticles readFlag:YES];
			}
		}
	}
	return [refArray copy];
}

/* markAllReadByReferencesArray
 * Given an array of references, mark all those articles read or unread.
 */
-(void)markAllReadByReferencesArray:(NSArray *)refArray readFlag:(BOOL)readFlag
{
	Database * dbManager = [Database sharedManager];
	__block NSInteger lastFolderId = -1;
	__block BOOL needRefilter = NO;
	
	// Set up to undo or redo this action
	NSUndoManager * undoManager = NSApp.mainWindow.undoManager;
	SEL markAllReadUndoAction = readFlag ? @selector(markAllReadUndo:) : @selector(markAllReadRedo:);
	[undoManager registerUndoWithTarget:self selector:markAllReadUndoAction object:refArray];
	[undoManager setActionName:NSLocalizedString(@"Mark All Read", nil)];
	
	for (ArticleReference *ref in refArray)
	{
		NSInteger folderId = ref.folderId;
		NSString * theGuid = ref.guid;
		Folder * folder = [dbManager folderFromID:folderId];
        if (IsGoogleReaderFolder(folder)) {
        	Article * article = [folder articleFromGuid:theGuid];
			[[GoogleReader sharedManager] markRead:article readFlag:readFlag];
        } else {
			[dbManager markArticleRead:folderId guid:theGuid isRead:readFlag];
			if (folderId != lastFolderId && lastFolderId != -1)
			{
				[foldersTree updateFolder:lastFolderId recurseToParents:YES];
			}
			lastFolderId = folderId;
		}

		if (folderId == currentFolderId) {
			needRefilter = YES;
		}
	}
	
	if (lastFolderId != -1)
	{
		[foldersTree updateFolder:lastFolderId recurseToParents:YES];
	}
	if (lastFolderId != -1 && !IsRSSFolder([dbManager folderFromID:currentFolderId])
		&& !IsGoogleReaderFolder([dbManager folderFromID:currentFolderId])) {
		[mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
	}
	else if (needRefilter) {
		[mainArticleView refreshFolder:MA_Refresh_ReapplyFilter];
	}
	
	// The info bar has a count of unread articles so we need to
	// update that.
	[APPCONTROLLER showUnreadCountOnApplicationIconAndWindowTitle];
}

/* addBacktrack
 * Add the specified article to the backtrack queue. The folder is taken from
 * the controller's current folder index.
 */
-(void)addBacktrack:(NSString *)guid
{
	if (!isBacktracking)
		[backtrackArray addToQueue:currentFolderId guid:guid];
}

/* goForward
 * Move forward through the backtrack queue.
 */
-(void)goForward
{
	NSInteger folderId;
	NSString * guid;
	
	if ([backtrackArray nextItemAtQueue:&folderId guidPointer:&guid])
	{
		isBacktracking = YES;
		[mainArticleView selectFolderAndArticle:folderId guid:guid];
		isBacktracking = NO;
	}
}

/* goBack
 * Move backward through the backtrack queue.
 */
-(void)goBack
{
	NSInteger folderId;
	NSString * guid;
	
	if ([backtrackArray previousItemAtQueue:&folderId guidPointer:&guid])
	{
		isBacktracking = YES;
		[mainArticleView selectFolderAndArticle:folderId guid:guid];
		isBacktracking = NO;
	}
}

/* canGoForward
 * Return TRUE if we can go forward in the backtrack queue.
 */
-(BOOL)canGoForward
{
	return !backtrackArray.atEndOfQueue;
}

/* canGoBack
 * Return TRUE if we can go backward in the backtrack queue.
 */
-(BOOL)canGoBack
{
	return !backtrackArray.atStartOfQueue;
}

/* handleFilterChange
* Update the list of articles when the user changes the filter.
*/
-(void)handleFilterChange:(NSNotification *)nc
{
    @synchronized(mainArticleView)
    {
	    [mainArticleView refreshFolder:MA_Refresh_ReapplyFilter];
	}
}

/* handleFolderNameChange
* Some folder metadata changed. Update the article list header and the
* current article with a possible name change.
*/
-(void)handleFolderNameChange:(NSNotification *)nc
{
    @synchronized(mainArticleView)
    {
        NSInteger folderId = ((NSNumber *)nc.object).integerValue;
        if (folderId == currentFolderId)
            [mainArticleView refreshArticlePane];
    }
}

/* handleRefreshArticle
* Respond to the notification to refresh the current article pane.
*/
-(void)handleRefreshArticle:(NSNotification *)nc
{
    @synchronized(mainArticleView)
    {
        [mainArticleView handleRefreshArticle:nc];
    }
}

/* handleFolderUpdate
* Called if a folder content has changed.
*/
-(void)handleFolderUpdate:(NSNotification *)nc
{
    @synchronized(mainArticleView)
    {
        NSInteger folderId = ((NSNumber *)nc.object).integerValue;
        if (folderId != currentFolderId)
            return;

        Folder * folder = [[Database sharedManager] folderFromID:folderId];
        if (IsSmartFolder(folder) || IsTrashFolder(folder))
            [mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
    }
}

/* handleFolderAdded
* Called if a folder was added.
*/
-(void)handleFolderAdded:(NSNotification *)nc
{
    @synchronized(mainArticleView)
    {
        Folder * folder = (Folder *)nc.object;
        currentFolderId = folder.itemId;
        [mainArticleView selectFolderAndArticle:currentFolderId guid:nil];
    }
}

/* setArticleToPreserve
 * Sets the article to preserve when reloading the array of articles.
 */
-(void)setArticleToPreserve:(Article *)article
{
	articleToPreserve = article;
}

/* dealloc
 * Clean up behind us.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
