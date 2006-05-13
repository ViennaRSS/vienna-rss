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

// Private functions
@interface ArticleController (Private)
	-(NSArray *)applyFilter:(NSArray *)unfilteredArray;
	-(void)setSortColumnIdentifier:(NSString *)str;
	-(NSArray *)wrappedMarkAllReadInArray:(NSArray *)folderArray withUndo:(BOOL)undoFlag needRefresh:(BOOL *)needRefreshPtr;
	-(void)innerMarkReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag;
@end

@implementation ArticleController

/* init
 * Initialise.
 */
-(id)init
{
    if ((self = [super init]) != nil)
	{
		isBacktracking = NO;
		mainArticleView = nil;
		currentFolderId = -1;
		currentArrayOfArticles = nil;
		folderArrayOfArticles = nil;

		// Set default values to generate article sort descriptors
		articleSortSpecifiers = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"containingFolder.name", @"key",
				@"compare:", @"selector",
				nil], MA_Field_Folder,
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"isRead", @"key",
				@"compare:", @"selector",
				nil], MA_Field_Read,
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"isFlagged", @"key",
				@"compare:", @"selector",
				nil], MA_Field_Flagged,
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"hasComments", @"key",
				@"compare:", @"selector",
				nil], MA_Field_Comments,
			[NSDictionary dictionaryWithObjectsAndKeys:
				[@"articleData." stringByAppendingString:MA_Field_Date], @"key",
				@"compare:", @"selector",
				nil], MA_Field_Date,
			[NSDictionary dictionaryWithObjectsAndKeys:
				[@"articleData." stringByAppendingString:MA_Field_Author], @"key",
				@"caseInsensitiveCompare:", @"selector",
				nil], MA_Field_Author,
			[NSDictionary dictionaryWithObjectsAndKeys:
				[@"articleData." stringByAppendingString:MA_Field_Subject], @"key",
				@"numericCompare:", @"selector",
				nil], MA_Field_Headlines,
			[NSDictionary dictionaryWithObjectsAndKeys:
				[@"articleData." stringByAppendingString:MA_Field_Subject], @"key",
				@"numericCompare:", @"selector",
				nil], MA_Field_Subject,
			[NSDictionary dictionaryWithObjectsAndKeys:
				[@"articleData." stringByAppendingString:MA_Field_Link], @"key",
				@"caseInsensitiveCompare:", @"selector",
				nil], MA_Field_Link,
			[NSDictionary dictionaryWithObjectsAndKeys:
				[@"articleData." stringByAppendingString:MA_Field_Summary], @"key",
				@"caseInsensitiveCompare:", @"selector",
				nil], MA_Field_Summary,
			nil];

		// Pre-set sort to what was saved in the preferences
		Preferences * prefs = [Preferences standardPreferences];
		NSArray * sortDescriptors = [prefs articleSortDescriptors];
		if ([sortDescriptors count] == 0)
		{
			NSSortDescriptor * descriptor = [[[NSSortDescriptor alloc] initWithKey:[@"articleData." stringByAppendingString:MA_Field_Date] ascending:NO] autorelease];
			[prefs setArticleSortDescriptors:[NSArray arrayWithObject:descriptor]];
			[prefs setObject:MA_Field_Date forKey:MAPref_SortColumn];
		}
		[self setSortColumnIdentifier:[prefs stringForKey:MAPref_SortColumn]];
		
		// Create a backtrack array
		backtrackArray = [[BackTrackArray alloc] initWithMaximum:[prefs backTrackQueueSize]];
    }
    return self;
}

/* mainArticleView
 * Returns the current view being used to display the articles.
 */
-(NSView<ArticleBaseView, BaseView> *)mainArticleView
{
	return mainArticleView;
}

/* setMainArticleView
 * Sets the view to use for displaying the articles.
 */
-(void)setMainArticleView:(NSView<ArticleBaseView, BaseView> *)newView
{
	[newView retain];
	[mainArticleView release];
	mainArticleView = newView;
}

/* currentFolderId
 * Returns the ID of the current folder being displayed by the view.
 */
-(int)currentFolderId
{
	return currentFolderId;
}

/* selectedArticle
 * Returns the currently selected article from the article list.
 */
-(Article *)selectedArticle
{
	return [mainArticleView selectedArticle];
}

/* allArticles
 * Returns the current filtered and sorted article array.
 */
-(NSArray *)allArticles
{
	return currentArrayOfArticles;
}

/* searchPlaceholderString
 * Return the search field placeholder.
 */
-(NSString *)searchPlaceholderString
{
	if (currentFolderId == -1)
		return @"";

	Folder * folder = [[Database sharedDatabase] folderFromID:currentFolderId];
	return [NSString stringWithFormat:NSLocalizedString(@"Search in %@", nil), [folder name]];
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
	[str retain];
	[sortColumnIdentifier release];
	sortColumnIdentifier = str;
}

/* sortByIdentifier
 * Sort by the column indicated by the specified column name.
 */
-(void)sortByIdentifier:(NSString *)columnName
{
	Preferences * prefs = [Preferences standardPreferences];
	NSMutableArray * descriptors = [NSMutableArray arrayWithArray:[prefs articleSortDescriptors]];
	
	if ([sortColumnIdentifier isEqualToString:columnName])
		[descriptors replaceObjectAtIndex:0 withObject:[[descriptors objectAtIndex:0] reversedSortDescriptor]];
	else
	{
		[self setSortColumnIdentifier:columnName];
		[prefs setObject:sortColumnIdentifier forKey:MAPref_SortColumn];
		NSSortDescriptor * sortDescriptor;
		NSDictionary * specifier = [articleSortSpecifiers valueForKey:sortColumnIdentifier];
		unsigned int index = [[descriptors valueForKey:@"key"] indexOfObject:[specifier valueForKey:@"key"]];

		if (index == NSNotFound)
			sortDescriptor = [[NSSortDescriptor alloc] initWithKey:[specifier valueForKey:@"key"] ascending:YES selector:NSSelectorFromString([specifier valueForKey:@"selector"])];
		else
		{
			sortDescriptor = [[descriptors objectAtIndex:index] retain];
			[descriptors removeObjectAtIndex:index];
		}
		[descriptors insertObject:sortDescriptor atIndex:0];
		[sortDescriptor release];
	}
	[prefs setArticleSortDescriptors:descriptors];
	[mainArticleView refreshFolder:MA_Refresh_SortAndRedraw];
}

/* sortArticles
 * Re-orders the articles in currentArrayOfArticles by the current sort order
 */
-(void)sortArticles
{
	NSArray * sortedArrayOfArticles;

	sortedArrayOfArticles = [currentArrayOfArticles sortedArrayUsingDescriptors:[[Preferences standardPreferences] articleSortDescriptors]];
	NSAssert([sortedArrayOfArticles count] == [currentArrayOfArticles count], @"Lost articles from currentArrayOfArticles during sort");
	[currentArrayOfArticles release];
	currentArrayOfArticles = [sortedArrayOfArticles retain];
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
-(void)displayFolder:(int)newFolderId
{
	if (currentFolderId != newFolderId && newFolderId != 0)
	{
		[[Database sharedDatabase] flushFolder:currentFolderId];
		currentFolderId = newFolderId;
		[mainArticleView selectFolderWithFilter:newFolderId];		
	}
}

/* reloadArrayOfArticles
 * Reload the folderArrayOfArticles from the current folder and applies the
 * current filter.
 */
-(void)reloadArrayOfArticles
{
	[folderArrayOfArticles release];
	
	Folder * folder = [[Database sharedDatabase] folderFromID:currentFolderId];
	folderArrayOfArticles = [[folder articlesWithFilter:[[NSApp delegate] searchString]] retain];
	
	[self refilterArrayOfArticles];
}

/* refilterArrayOfArticles
 * Reapply the current filter to the article array.
 */
-(void)refilterArrayOfArticles
{
	[currentArrayOfArticles release];
	currentArrayOfArticles = [self applyFilter:folderArrayOfArticles];
}

/* applyFilter
 * Apply the active filter to unfilteredArray and return the filtered array.
 * This is done here rather than in the folder management code for simplicity.
 */
-(NSArray *)applyFilter:(NSArray *)unfilteredArray
{
	ArticleFilter * filter = [ArticleFilter filterByTag:[[Preferences standardPreferences] filterMode]];
	if ([filter comparator] == nil)
		return [unfilteredArray retain];
	
	NSMutableArray * filteredArray = [[NSMutableArray alloc] initWithArray:unfilteredArray];
	int count = [filteredArray count];
	int index;
	
	for (index = count - 1; index >= 0; --index)
	{
		Article * article = [filteredArray objectAtIndex:index];
		if (![ArticleFilter performSelector:[filter comparator] withObject:article])
			[filteredArray removeObjectAtIndex:index];
	}
	return filteredArray;
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
	NSEnumerator * enumerator = [articleArray objectEnumerator];
	Article * theArticle;
	
	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markDeletedUndoAction = deleteFlag ? @selector(markDeletedUndo:) : @selector(markUndeletedUndo:);
	[undoManager registerUndoWithTarget:self selector:markDeletedUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Delete", nil)];
	
	// We will make a new copy of the currentArrayOfArticles with the selected articles removed.
	NSMutableArray * arrayCopy = [[NSMutableArray alloc] initWithArray:currentArrayOfArticles];
	BOOL needFolderRedraw = NO;
	
	// Iterate over every selected article in the table and set the deleted
	// flag on the article while simultaneously removing it from our copy of
	// currentArrayOfArticles.
	Database * db = [Database sharedDatabase];
	[db beginTransaction];
	while ((theArticle = [enumerator nextObject]) != nil)
	{
		if (![theArticle isRead])
			needFolderRedraw = YES;
		[db markArticleDeleted:[theArticle folderId] guid:[theArticle guid] isDeleted:deleteFlag];
		if (deleteFlag)
		{
			if ([self currentCacheContainsFolder:[theArticle folderId]])
				[arrayCopy removeObject:theArticle];
		}
		else
		{
			if (currentFolderId == [db trashFolderId])
				[arrayCopy removeObject:theArticle];
			else if ([theArticle folderId] == currentFolderId)
				[arrayCopy addObject:theArticle];
		}
	}
	[db commitTransaction];
	[currentArrayOfArticles release];
	currentArrayOfArticles = arrayCopy;
	[mainArticleView refreshFolder:MA_Refresh_RedrawList];

	// If we've added articles back to the array, we need to resort to put
	// them back in the right place.
	if (!deleteFlag)
		[self sortArticles];

	// If any of the articles we deleted were unread then the
	// folder's unread count just changed.
	if (needFolderRedraw)
		[foldersTree updateFolder:currentFolderId recurseToParents:YES];
	
	/* Move this logic to refreshFolder.
	// Compute the new place to put the selection
	int nextRow = [[articleList selectedRowIndexes] firstIndex];
	currentSelectedRow = -1;
	if (nextRow < 0 || nextRow >= (int)[currentArrayOfArticles count])
		nextRow = [currentArrayOfArticles count] - 1;
	[mainArticleView makeRowSelectedAndVisible:nextRow];
	*/
	// Read and/or unread count may have changed
	if (needFolderRedraw)
		[[NSApp delegate] showUnreadCountOnApplicationIconAndWindowTitle];
}

/* deleteArticlesByArray
 * Physically delete all selected articles in the article list.
 */
-(void)deleteArticlesByArray:(NSArray *)articleArray
{		
	// Make a new copy of the currentArrayOfArticles with the selected article removed.
	NSMutableArray * arrayCopy = [[NSMutableArray alloc] initWithArray:currentArrayOfArticles];
	BOOL needFolderRedraw = NO;
	
	// Iterate over every selected article in the table and remove it from
	// the database.
	Database * db = [Database sharedDatabase];
	NSEnumerator * enumerator = [articleArray objectEnumerator];
	Article * theArticle;

	[db beginTransaction];
	while ((theArticle = [enumerator nextObject]) != nil)
	{
		if (![theArticle isRead])
			needFolderRedraw = YES;
		if ([db deleteArticle:[theArticle folderId] guid:[theArticle guid]])
			[arrayCopy removeObject:theArticle];
	}
	[db commitTransaction];
	[currentArrayOfArticles release];
	currentArrayOfArticles = arrayCopy;
	[mainArticleView refreshFolder:MA_Refresh_RedrawList];

	// Blow away the undo stack here since undo actions may refer to
	// articles that have been deleted. This is a bit of a cop-out but
	// it's the easiest approach for now.
//	[controller clearUndoStack];
	
	// If any of the articles we deleted were unread then the
	// folder's unread count just changed.
	if (needFolderRedraw)
		[foldersTree updateFolder:currentFolderId recurseToParents:YES];
	
	/* Move this logic to refreshFolder.
	// Compute the new place to put the selection
	int nextRow = [[articleList selectedRowIndexes] firstIndex];
	currentSelectedRow = -1;
	if (nextRow < 0 || nextRow >= (int)[currentArrayOfArticles count])
		nextRow = [currentArrayOfArticles count] - 1;
	[self makeRowSelectedAndVisible:nextRow];
	*/
	
	// Read and/or unread count may have changed
	if (needFolderRedraw)
		[[NSApp delegate] showUnreadCountOnApplicationIconAndWindowTitle];
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
	NSEnumerator * enumerator = [articleArray objectEnumerator];
	Database * db = [Database sharedDatabase];
	Article * theArticle;
	
	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markFlagUndoAction = flagged ? @selector(markUnflagUndo:) : @selector(markFlagUndo:);
	[undoManager registerUndoWithTarget:self selector:markFlagUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Flag", nil)];
	
	[db beginTransaction];
	while ((theArticle = [enumerator nextObject]) != nil)
	{
		[theArticle markFlagged:flagged];
		[db markArticleFlagged:[theArticle folderId] guid:[theArticle guid] isFlagged:flagged];
	}
	[db commitTransaction];
	[mainArticleView refreshFolder:MA_Refresh_RedrawList];
}

/* markUnreadUndo
 * Undo handler to mark an array of articles unread.
 */
-(void)markUnreadUndo:(id)anObject
{
	[self markReadByArray:(NSArray *)anObject readFlag:NO];
}

/* markReadUndo
 * Undo handler to mark an array of articles read.
 */
-(void)markReadUndo:(id)anObject
{
	[self markReadByArray:(NSArray *)anObject readFlag:YES];
}

/* markReadByArray
 * Helper function. Takes as an input an array of articles and marks those articles read or unread.
 */
-(void)markReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag
{
	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];	
	SEL markReadUndoAction = readFlag ? @selector(markUnreadUndo:) : @selector(markReadUndo:);
	[undoManager registerUndoWithTarget:self selector:markReadUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Mark Read", nil)];

	Database * db = [Database sharedDatabase];
	BOOL singleArticle = [articleArray count] < 2;
	
	if (!singleArticle)
		[db beginTransaction];
	[self innerMarkReadByArray:articleArray readFlag:readFlag];
	if (!singleArticle)
		[db commitTransaction];
	[mainArticleView refreshFolder:MA_Refresh_RedrawList];
	[foldersTree updateFolder:currentFolderId recurseToParents:YES];
	
	// The info bar has a count of unread articles so we need to
	// update that.
	[[NSApp delegate] showUnreadCountOnApplicationIconAndWindowTitle];
}

/* innerMarkReadByArray
 * Marks all articles in the specified array read or unread.
 */
-(void)innerMarkReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag
{
	NSEnumerator * enumerator = [articleArray objectEnumerator];
	Database * db = [Database sharedDatabase];
	int lastFolderId = -1;
	Article * theArticle;
	
	while ((theArticle = [enumerator nextObject]) != nil)
	{
		int folderId = [theArticle folderId];
		[db markArticleRead:folderId guid:[theArticle guid] isRead:readFlag];
		[theArticle markRead:readFlag];
		if (folderId != lastFolderId && lastFolderId != -1)
			[foldersTree updateFolder:lastFolderId recurseToParents:YES];
		lastFolderId = folderId;
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
	Database * db = [Database sharedDatabase];
	BOOL singleFolder = [folderArray count] < 2;	
	NSArray * refArray = nil;
	BOOL flag = NO;

	if (!singleFolder)
		[db beginTransaction];
	refArray = [self wrappedMarkAllReadInArray:folderArray withUndo:undoFlag needRefresh:&flag];
	if (!singleFolder)
		[db commitTransaction];
	if (refArray != nil && [refArray count] > 0)
	{
		NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
		[undoManager registerUndoWithTarget:self selector:@selector(markAllReadUndo:) object:refArray];
		[undoManager setActionName:NSLocalizedString(@"Mark All Read", nil)];
	}
	if (flag && refreshFlag)
		[mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
	[[NSApp delegate] showUnreadCountOnApplicationIconAndWindowTitle];
}

/* wrappedMarkAllReadInArray
 * Given an array of folders, mark all the articles in those folders as read and
 * return a reference array listing all the articles that were actually marked.
 */
-(NSArray *)wrappedMarkAllReadInArray:(NSArray *)folderArray withUndo:(BOOL)undoFlag needRefresh:(BOOL *)needRefreshPtr
{
	NSMutableArray * refArray = [NSMutableArray array];
	NSEnumerator * enumerator = [folderArray objectEnumerator];
	Database * db = [Database sharedDatabase];
	Folder * folder;
	
	NSAssert(needRefreshPtr != nil, @"needRefresh pointer cannot be nil");
	while ((folder = [enumerator nextObject]) != nil)
	{
		int folderId = [folder itemId];
		if (IsGroupFolder(folder))
		{
			if (undoFlag)
				[refArray addObjectsFromArray:[self wrappedMarkAllReadInArray:[db arrayOfFolders:folderId] withUndo:undoFlag needRefresh:needRefreshPtr]];
			if ([self currentCacheContainsFolder:folderId])
				*needRefreshPtr = YES;
		}
		else if (!IsSmartFolder(folder))
		{
			if (undoFlag)
				[refArray addObjectsFromArray:[db arrayOfUnreadArticles:folderId]];
			if ([db markFolderRead:folderId])
			{
				[foldersTree updateFolder:folderId recurseToParents:YES];
				if ([self currentCacheContainsFolder:folderId])
					*needRefreshPtr = YES;
			}
		}
		else
		{
			// For smart folders, we only mark all read the current folder to
			// simplify things.
			if (folderId == currentFolderId)
			{
				if (undoFlag)
					[refArray addObjectsFromArray:currentArrayOfArticles];
				[self innerMarkReadByArray:currentArrayOfArticles readFlag:YES];
				[mainArticleView refreshFolder:MA_Refresh_RedrawList];
			}
		}
	}
	return refArray;
}

/* currentCacheContainsFolder
 * Scans the current article cache to determine if any article is a member of the specified
 * folder and returns YES if so.
 */
-(BOOL)currentCacheContainsFolder:(int)folderId
{
	int count = [currentArrayOfArticles count];
	int index = 0;
	
	while (index < count)
	{
		Article * anArticle = [currentArrayOfArticles objectAtIndex:index];
		if ([anArticle folderId] == folderId)
			return YES;
		++index;
	}
	return NO;
}

/* markAllReadByReferencesArray
 * Given an array of references, mark all those articles read or unread.
 */
-(void)markAllReadByReferencesArray:(NSArray *)refArray readFlag:(BOOL)readFlag
{
	NSEnumerator * enumerator = [refArray objectEnumerator];
	Database * db = [Database sharedDatabase];
	ArticleReference * ref;
	int lastFolderId = -1;
	
	// Set up to undo or redo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markAllReadUndoAction = readFlag ? @selector(markAllReadUndo:) : @selector(markAllReadRedo:);
	[undoManager registerUndoWithTarget:self selector:markAllReadUndoAction object:refArray];
	[undoManager setActionName:NSLocalizedString(@"Mark All Read", nil)];
	
	[db beginTransaction];
	while ((ref = [enumerator nextObject]) != nil)
	{
		int folderId = [ref folderId];
		[db markArticleRead:folderId guid:[ref guid] isRead:readFlag];
		if (folderId != lastFolderId && lastFolderId != -1)
		{
			[foldersTree updateFolder:lastFolderId recurseToParents:YES];
			if (lastFolderId == currentFolderId)
				[mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
		}
		lastFolderId = folderId;
	}
	[db commitTransaction];
	
	if (lastFolderId != -1)
	{
		[foldersTree updateFolder:lastFolderId recurseToParents:YES];
		if (lastFolderId == currentFolderId)
			[mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
		else
		{
			Folder * currentFolder = [db folderFromID:currentFolderId];
			if (IsSmartFolder(currentFolder))
				[mainArticleView refreshFolder:MA_Refresh_RedrawList];
		}
	}
	
	// The info bar has a count of unread articles so we need to
	// update that.
	[[NSApp delegate] showUnreadCountOnApplicationIconAndWindowTitle];
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
	int folderId;
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
-(void)goBack;
{
	int folderId;
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
	return ![backtrackArray isAtEndOfQueue];
}

/* canGoBack
 * Return TRUE if we can go backward in the backtrack queue.
 */
-(BOOL)canGoBack
{
	return ![backtrackArray isAtStartOfQueue];
}

/* dealloc
 * Clean up behind us.
 */
-(void)dealloc
{
	[mainArticleView release];
	[backtrackArray release];
	[sortColumnIdentifier release];
	[folderArrayOfArticles release];
	[currentArrayOfArticles release];
	[articleSortSpecifiers release];
	[super dealloc];
}
@end
