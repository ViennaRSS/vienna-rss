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
#import "ArticleListView.h"
#import "UnifiedDisplayView.h"

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
		guidOfArticleToSelect = nil;
		firstUnreadArticleRequired = NO;

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
		[nc addObserver:self selector:@selector(handleArticleListContentChange:) name:@"MA_Notify_ArticleListContentChange" object:nil];
        [nc addObserver:self selector:@selector(handleArticleListStateChange:) name:@"MA_Notify_ArticleListStateChange" object:nil];

        queue = dispatch_queue_create("uk.co.opencommunity.vienna2.displayRefresh", DISPATCH_QUEUE_SERIAL);
        reloadArrayOfArticlesSemaphor = 0;
        requireSelectArticleAfterReload = NO;
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
	    [self selectFolderAndArticle:currentFolderId guid:currentSelectedArticle.guid];
	    [self ensureSelectedArticle];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleViewChange" object:nil];
	}

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
-(void)ensureSelectedArticle
{
	if (reloadArrayOfArticlesSemaphor <= 0) {
	    [mainArticleView ensureSelectedArticle];
	} else {
	    requireSelectArticleAfterReload = YES;
	}
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
	// mark current article read
	Article * currentArticle = self.selectedArticle;
	if (currentArticle != nil && !currentArticle.read)
	{
		[self markReadByArray:@[currentArticle] readFlag:YES];
	}

	// If there are any unread articles then select the first one in the
	// first folder.
	if ([Database sharedManager].countOfUnread > 0)
	{
		// Get the first folder with unread articles.
		NSInteger firstFolderWithUnread = foldersTree.firstFolderWithUnread;
		if (firstFolderWithUnread == currentFolderId)
		{
			[mainArticleView selectFirstUnreadInFolder];
		}
		else
		{
			// Seed in order to select the first unread article.
			firstUnreadArticleRequired = YES;
			// Select the folder in the tree view.
			[foldersTree selectFolder:firstFolderWithUnread];
		}
	}
}

/* displayNextUnread
 * Instructs the current article view to display the next unread article
 * in the database.
 */
-(void)displayNextUnread
{
	// mark current article read
	Article * currentArticle = self.selectedArticle;
	if (currentArticle != nil && !currentArticle.read)
	{
		[self markReadByArray:@[currentArticle] readFlag:YES];
	}
	
	// If there are any unread articles then select the nexst one
	if ([Database sharedManager].countOfUnread > 0)
	{
		// Search other articles in the same folder, starting from current position
		if (![mainArticleView viewNextUnreadInFolder])
		{
			// If nothing found and smart folder, search if we have other fresh articles from same folder
			Folder * currentFolder = [[Database sharedManager] folderFromID:currentFolderId];
			if (IsSmartFolder(currentFolder) || IsTrashFolder(currentFolder) || IsSearchFolder(currentFolder))
			{
				if (![mainArticleView selectFirstUnreadInFolder])
				{
					[self displayNextFolderWithUnread];
				}
			}
			else
			{
				[self displayNextFolderWithUnread];
			}
		}
	}
}

/* displayNextFolderWithUnread
 * Instructs the current article view to display the next folder with unread articles
 * in the database.
 */
-(void)displayNextFolderWithUnread
{
	NSInteger nextFolderWithUnread = [foldersTree nextFolderWithUnread:currentFolderId];
	if (nextFolderWithUnread != -1)
	{
		// Seed in order to select the first unread article.
		firstUnreadArticleRequired = YES;
		[foldersTree selectFolder:nextFolderWithUnread];
	}
}

/* displayFolder
 * This is called after notification of folder selection change
 * Call the current article view to display the specified folder if it
 * is different from the current one.
 */
-(void)displayFolder:(NSInteger)newFolderId
{
	if (currentFolderId != newFolderId && newFolderId != 0)
	{
		// Deselect all in current folder.
		// Otherwise, the new folder might attempt to preserve selection.
		// This can happen with smart folders, which have the same articles as other folders.
		[mainArticleView scrollToArticle:nil];
		
		currentFolderId = newFolderId;
		[self reloadArrayOfArticles];
	}

}

/* selectFolderAndArticle
 * Select a folder and select a specified article within the folder.
 */
-(void)selectFolderAndArticle:(NSInteger)folderId guid:(NSString *)guid
{
	// If we're in the right folder, select the article
	if (folderId == currentFolderId)
	{
		if (guid != nil) {
			[mainArticleView scrollToArticle:guid];
		}
	}
	else
	{
		// We seed guidOfArticleToSelect so that
		// after notification of folder selection change has been processed,
		// it will select the requisite article on our behalf.
		guidOfArticleToSelect = guid;
		[foldersTree selectFolder:folderId];
	}
}

/* reloadArrayOfArticles
 * Reload the folderArrayOfArticles from the current folder and applies the
 * current filter.
 */
-(void)reloadArrayOfArticles
{
	reloadArrayOfArticlesSemaphor++;
	[mainArticleView startLoadIndicator];

	[self getArticlesWithCompletionBlock:^(NSArray *resultArray) {
	    // when multiple refreshes where queued, we update folderArrayOfArticles only once
	    reloadArrayOfArticlesSemaphor--;
	    if (reloadArrayOfArticlesSemaphor <=0)
	    {
            [mainArticleView stopLoadIndicator];
            self.folderArrayOfArticles = resultArray;
			Article * article = self.selectedArticle;
			
			if (shouldPreserveSelectedArticle)
			{
				if (article != nil && article.read && !article.deleted)
				{
					articleToPreserve = article;
				}
				shouldPreserveSelectedArticle = NO;
			}
			
            [mainArticleView refreshFolder:MA_Refresh_ReapplyFilter];
			
			if (guidOfArticleToSelect != nil )
			{
				[mainArticleView scrollToArticle:guidOfArticleToSelect];
				guidOfArticleToSelect = nil;
			}
            else if (firstUnreadArticleRequired)
            {
                [mainArticleView selectFirstUnreadInFolder];
				firstUnreadArticleRequired = NO;
            }
			
            if (requireSelectArticleAfterReload)
            {
                [self ensureSelectedArticle];
				requireSelectArticleAfterReload = NO;
            }

            // To avoid upsetting the current displayed article after a refresh,
            // we check to see if the selected article is the same
            // and if it has been updated
            Article * currentArticle = self.selectedArticle;
			if ( currentArticle == article &&
				[[Preferences standardPreferences] boolForKey:MAPref_CheckForUpdatedArticles]
				&& currentArticle.revised && !currentArticle.read )
			{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleViewChange" object:nil];
            }
		}
	}];
}

/* getArticlesWithCompletionBlock
 * Launch articlesWithFilter on background queue and perform completion block
 */
- (void)getArticlesWithCompletionBlock:(void(^)(NSArray * resultArray))completionBlock {
	Folder * folder = [[Database sharedManager] folderFromID:currentFolderId];
    dispatch_async(queue, ^{
        NSArray * articleArray = [folder articlesWithFilter:APPCONTROLLER.filterString];    

        // call the completion block with the result when finished
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(articleArray);
            });
        }        
    });
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
	
	NSString * guidOfArticleToPreserve = articleToPreserve.guid;
	
	ArticleFilter * filter = [ArticleFilter filterByTag:[Preferences standardPreferences].filterMode];
	SEL comparator = filter.comparator;
	for (NSInteger index = filteredArray.count - 1; index >= 0; --index)
	{
		Article * article = filteredArray[index];
		if (guidOfArticleToPreserve != nil 
			&& article.folderId == articleToPreserve.folderId 
			&& [article.guid isEqualToString:guidOfArticleToPreserve])
		{
			guidOfArticleToPreserve = nil;
		}
		else if ((comparator != nil) && !((BOOL)(NSInteger)[ArticleFilter performSelector:comparator withObject:article]))
			[filteredArray removeObjectAtIndex:index];
	}
	
	if (guidOfArticleToPreserve != nil)
	{
		[filteredArray addObject:articleToPreserve];
	}
	articleToPreserve = nil;
	
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
	
    // if we mark deleted, mark also read and unflagged
	if (deleteFlag) {
	    [self innerMarkReadByRefsArray:articleArray readFlag:YES];
        [self innerMarkFlaggedByArray:articleArray flagged:NO];
		[mainArticleView selectPreviousArticle];
	}

	// Iterate over every selected article in the table and set the deleted
	// flag on the article while simultaneously removing it from our copies
	for (Article * theArticle in articleArray)
	{
		[[Database sharedManager] markArticleDeleted:theArticle isDeleted:deleteFlag];
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
		[self reloadArrayOfArticles];
	else
	{
		[mainArticleView refreshFolder:MA_Refresh_RedrawList];
		if (currentArrayOfArticles.count > 0u)
			[mainArticleView ensureSelectedArticle];
		else
			[NSApp.mainWindow makeFirstResponder:foldersTree.mainView];
	}
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
	[mainArticleView selectPreviousArticle];

	// Iterate over every selected article in the table and remove it from
	// the database.
	for (Article * theArticle in articleArray)	
	{
		if ([[Database sharedManager] deleteArticle:theArticle])
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
		[mainArticleView ensureSelectedArticle];
    } else {
		[NSApp.mainWindow makeFirstResponder:foldersTree.mainView];
    }
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

    [self innerMarkFlaggedByArray:articleArray flagged:flagged];
	[mainArticleView refreshFolder:MA_Refresh_RedrawList];
}

/* innerMarkFlaggedByArray
 * Marks all articles in the specified array flagged or unflagged.
 */
-(void)innerMarkFlaggedByArray:(NSArray *)articleArray flagged:(BOOL)flagged
{
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
				if (folderId != lastFolderId && lastFolderId != -1) {
					[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
																		object:@(lastFolderId)];
				}
				lastFolderId = folderId;
			}
		}
	}
	if (lastFolderId != -1) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
															object:@(lastFolderId)];
	}
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
			if (article != nil) {
                [[GoogleReader sharedManager] markRead:article readFlag:readFlag];
			}
		} else {
			[db markArticleRead:folderId guid:articleRef.guid isRead:readFlag];
			if (folderId != lastFolderId && lastFolderId != -1) {
				[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
																	object:@(lastFolderId)];
			}
			lastFolderId = folderId;
		}
	}
	if (lastFolderId != -1) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
															object:@(lastFolderId)];
	}
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

/* markAllFoldersReadByArray
 * Given an array of folders, mark all the articles in those folders as read.
 */
-(void)markAllFoldersReadByArray:(NSArray *)folderArray
{
	NSArray * refArray = [self wrappedMarkAllFoldersReadInArray:folderArray];
	if (refArray != nil && refArray.count > 0)
	{
		NSUndoManager * undoManager = NSApp.mainWindow.undoManager;
		[undoManager registerUndoWithTarget:self selector:@selector(markAllReadUndo:) object:refArray];
		[undoManager setActionName:NSLocalizedString(@"Mark All Read", nil)];
	}
	
	// Smart and Search folders are not included in folderArray when you mark all subscriptions read,
	// so we need to mark articles read if they're the current folder.
	Folder * currentFolder = [[Database sharedManager] folderFromID:currentFolderId];
	if (currentFolder != nil && ![folderArray containsObject:currentFolder])
	{
		for (Article * theArticle in folderArrayOfArticles)
			[theArticle markRead:YES];
	}
	
	[mainArticleView refreshFolder:MA_Refresh_RedrawList];
}

/* wrappedMarkAllFoldersReadInArray
 * Given an array of folders, mark all the articles in those folders as read and
 * return a reference array listing all the articles that were actually marked.
 */
-(NSArray *)wrappedMarkAllFoldersReadInArray:(NSArray *)folderArray
{
	NSMutableArray * refArray = [NSMutableArray array];
	
	for (Folder * folder in folderArray)
	{
		NSInteger folderId = folder.itemId;
		if (IsGroupFolder(folder))
		{
			[refArray addObjectsFromArray:[self wrappedMarkAllFoldersReadInArray:[[Database sharedManager] arrayOfFolders:folderId]]];
		}
		else if (IsRSSFolder(folder))
		{
			[refArray addObjectsFromArray:[folder arrayOfUnreadArticlesRefs]];
			if ([[Database sharedManager] markFolderRead:folderId]) {
				[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
																	object:@(folderId)];
			}
		}
		else if (IsGoogleReaderFolder(folder))
		{
			NSArray * articleArray = [folder arrayOfUnreadArticlesRefs];
			[refArray addObjectsFromArray:articleArray];
			[self innerMarkReadByRefsArray:articleArray readFlag:YES];
		}
		else
		{
			// For smart folders, we only mark all read the current folder to
			// simplify things.
			if (folderId == currentFolderId)
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
        	if (article != nil) {
			    [[GoogleReader sharedManager] markRead:article readFlag:readFlag];
			}
        } else {
			[dbManager markArticleRead:folderId guid:theGuid isRead:readFlag];
			if (folderId != lastFolderId && lastFolderId != -1) {
				[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
																	object:@(lastFolderId)];
			}
			lastFolderId = folderId;
		}

		if (folderId == currentFolderId) {
			needRefilter = YES;
		}
	}
	
	if (lastFolderId != -1) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
															object:@(lastFolderId)];
	}
	if (lastFolderId != -1 && !IsRSSFolder([dbManager folderFromID:currentFolderId])
		&& !IsGoogleReaderFolder([dbManager folderFromID:currentFolderId])) {
		[self reloadArrayOfArticles];
	}
	else if (needRefilter) {
		[mainArticleView refreshFolder:MA_Refresh_ReapplyFilter];
	}
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
		[self selectFolderAndArticle:folderId guid:guid];
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
		[self selectFolderAndArticle:folderId guid:guid];
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

/* handleArticleListStateChange
* Called if a folder content has changed
* but we don't need to add new articles
*/
-(void)handleArticleListStateChange:(NSNotification *)nc
{
    NSInteger folderId = ((NSNumber *)nc.object).integerValue;
    Folder * currentFolder = [[Database sharedManager] folderFromID:currentFolderId];
    if ( (folderId == currentFolderId) || (!IsRSSFolder(currentFolder) && !IsGoogleReaderFolder(currentFolder)) ) {
        [mainArticleView refreshFolder:MA_Refresh_RedrawList];
    }
}

/* handleArticleListContentChange
 * called after a refresh
 * or any other event which may have added a removed an article
 * to the current folder
 */
-(void)handleArticleListContentChange:(NSNotification *)note
{
	// With automatic refresh and automatic mark read,
	// the article you're current reading can disappear.
	// For example, if you're reading in the Unread Articles smart folder.
	// So make sure the keep this article around.
	if ([[Preferences standardPreferences] refreshFrequency] > 0
		&& [[Preferences standardPreferences] markReadInterval] > 0.0)
	{
		shouldPreserveSelectedArticle = YES;
	}
	
    [self reloadArrayOfArticles];
}

/* dealloc
 * Clean up behind us.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
