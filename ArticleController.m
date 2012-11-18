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

// Private functions
@interface ArticleController (Private)
	-(NSArray *)applyFilter:(NSArray *)unfilteredArray;
	-(void)setSortColumnIdentifier:(NSString *)str;
	-(NSArray *)wrappedMarkAllReadInArray:(NSArray *)folderArray withUndo:(BOOL)undoFlag;
	-(void)innerMarkReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag;
@end

@implementation ArticleController
@synthesize foldersTree, mainArticleView, currentArrayOfArticles, folderArrayOfArticles, backtrackArray;

/* init
 * Initialise.
 */
-(id)init
{
    if ((self = [super init]) != nil)
	{
		isBacktracking = NO;
		currentFolderId = -1;
		articleToPreserve = nil;

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
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"hasEnclosure", @"key",
				@"compare:", @"selector",
				nil], MA_Field_HasEnclosure,
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"enclosure", @"key",
				@"caseInsensitiveCompare:", @"selector",
				nil], MA_Field_Enclosure,
			nil];

		// Pre-set sort to what was saved in the preferences
		Preferences * prefs = [Preferences standardPreferences];
		NSArray * sortDescriptors = [prefs articleSortDescriptors];
		if ([sortDescriptors count] == 0)
		{
			NSSortDescriptor * descriptor = [[[NSSortDescriptor alloc] initWithKey:[@"articleData." stringByAppendingString:MA_Field_Date] ascending:YES] autorelease];
			[prefs setArticleSortDescriptors:[NSArray arrayWithObject:descriptor]];
			[prefs setObject:MA_Field_Date forKey:MAPref_SortColumn];
		}
		[self setSortColumnIdentifier:[prefs stringForKey:MAPref_SortColumn]];
		
		// Create a backtrack array
		[self setBacktrackArray:[[[BackTrackArray alloc] initWithMaximum:[prefs backTrackQueueSize]] autorelease]];
		
		// Register for notifications
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleFilterChange:) name:@"MA_Notify_FilteringChange" object:nil];
		[nc addObserver:self selector:@selector(handleFolderNameChange:) name:@"MA_Notify_FolderNameChanged" object:nil];
		[nc addObserver:self selector:@selector(handleFolderUpdate:) name:@"MA_Notify_FoldersUpdated" object:nil];
		[nc addObserver:self selector:@selector(handleRefreshArticle:) name:@"MA_Notify_ArticleViewChange" object:nil];
        [nc addObserver:self selector:@selector(handleArticleListStateChange:) name:@"MA_Notify_ArticleListStateChange" object:nil];
        
    }
    return self;
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
		NSUInteger index = [[descriptors valueForKey:@"key"] indexOfObject:[specifier valueForKey:@"key"]];

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

/* sortIsAscending
 * Returns YES if the sort direction is currently set to ascending.
 */
-(BOOL)sortIsAscending
{
	Preferences * prefs = [Preferences standardPreferences];
	NSMutableArray * descriptors = [NSMutableArray arrayWithArray:[prefs articleSortDescriptors]];
	NSSortDescriptor * sortDescriptor = [descriptors objectAtIndex:0];
	BOOL ascending = [sortDescriptor ascending];
	
	return ascending;
}

/* sortAscending
 * Sort by the direction indicated.
 */
-(void)sortAscending:(BOOL)newAscending
{
	Preferences * prefs = [Preferences standardPreferences];
	NSMutableArray * descriptors = [NSMutableArray arrayWithArray:[prefs articleSortDescriptors]];
	NSSortDescriptor * sortDescriptor = [descriptors objectAtIndex:0];
	
	BOOL existingAscending = [sortDescriptor ascending];
	if ( newAscending != existingAscending )
	{
		[descriptors replaceObjectAtIndex:0 withObject:[sortDescriptor reversedSortDescriptor]];
		[prefs setArticleSortDescriptors:descriptors];
		[mainArticleView refreshFolder:MA_Refresh_SortAndRedraw];
	}
}

/* sortArticles
 * Re-orders the articles in currentArrayOfArticles by the current sort order
 */
-(void)sortArticles
{
	NSArray * sortedArrayOfArticles;

	sortedArrayOfArticles = [currentArrayOfArticles sortedArrayUsingDescriptors:[[Preferences standardPreferences] articleSortDescriptors]];
	NSAssert([sortedArrayOfArticles count] == [currentArrayOfArticles count], @"Lost articles from currentArrayOfArticles during sort");
	[self setCurrentArrayOfArticles:sortedArrayOfArticles];
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
-(void)displayFolder:(int)newFolderId
{
	if (currentFolderId != newFolderId && newFolderId != 0)
	{
		[[[Database sharedDatabase] folderFromID:currentFolderId] clearCache];
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
	
	[[RefreshManager articlesUpdateSemaphore] lock];
	Folder * folder = [[Database sharedDatabase] folderFromID:currentFolderId];
	[self setFolderArrayOfArticles:[folder articlesWithFilter:[[NSApp delegate] filterString]]];
	[[RefreshManager articlesUpdateSemaphore] unlock];
	
	[self refilterArrayOfArticles];
}

/* refilterArrayOfArticles
 * Reapply the current filter to the article array.
 */
-(void)refilterArrayOfArticles
{
	[self setCurrentArrayOfArticles:[self applyFilter:folderArrayOfArticles]];
}

/* applyFilter
 * Apply the active filter to unfilteredArray and return the filtered array.
 * This is done here rather than in the folder management code for simplicity.
 */
-(NSArray *)applyFilter:(NSArray *)unfilteredArray
{
	NSMutableArray * filteredArray = [NSMutableArray arrayWithArray:unfilteredArray];
	
	NSString * guidOfArticleToPreserve = (articleToPreserve != nil) ? [articleToPreserve guid] : @"";
	int folderIdOfArticleToPreserve = [articleToPreserve folderId];
	
	ArticleFilter * filter = [ArticleFilter filterByTag:[[Preferences standardPreferences] filterMode]];
	SEL comparator = [filter comparator];
	int count = [filteredArray count];
	int index;
	
	for (index = count - 1; index >= 0; --index)
	{
		Article * article = [filteredArray objectAtIndex:index];
		if (([article folderId] == folderIdOfArticleToPreserve) && [[article guid] isEqualToString:guidOfArticleToPreserve])
			guidOfArticleToPreserve = @"";
		else if ((comparator != nil) && !((BOOL)(NSInteger)[ArticleFilter performSelector:comparator withObject:article]))
			[filteredArray removeObjectAtIndex:index];
	}
	
	if (![guidOfArticleToPreserve isEqualToString:@""])
	{
		Article * articleToAdd = nil;
		Folder * folder = [[Database sharedDatabase] folderFromID:folderIdOfArticleToPreserve];
		if (folder != nil)
		{
			[folder clearCache];
			[folder articles];
			articleToAdd = [folder articleFromGuid:guidOfArticleToPreserve];
		}
		if (articleToAdd == nil)
			articleToAdd = articleToPreserve;
		[filteredArray addObject:articleToAdd];
	}
	[self setArticleToPreserve:nil];
	
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
	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markDeletedUndoAction = deleteFlag ? @selector(markDeletedUndo:) : @selector(markUndeletedUndo:);
	[undoManager registerUndoWithTarget:self selector:markDeletedUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Delete", nil)];
	
	// We will make a new copy of currentArrayOfArticles and folderArrayOfArticles with the selected articles removed.
	NSMutableArray * currentArrayCopy = [[NSMutableArray alloc] initWithArray:currentArrayOfArticles];
	NSMutableArray * folderArrayCopy = [[NSMutableArray alloc] initWithArray:folderArrayOfArticles];
	BOOL needFolderRedraw = NO;
	BOOL needReload = NO;
	
	// Iterate over every selected article in the table and set the deleted
	// flag on the article while simultaneously removing it from our copies
	Database * db = [Database sharedDatabase];
	[db beginTransaction];
	for (Article * theArticle in articleArray)
	{
		if (![theArticle isRead])
			needFolderRedraw = YES;
		[db markArticleDeleted:[theArticle folderId] guid:[theArticle guid] isDeleted:deleteFlag];
		if (![currentArrayOfArticles containsObject:theArticle])
			needReload = YES;
		else if (deleteFlag && (currentFolderId != [db trashFolderId]))
		{
			[currentArrayCopy removeObject:theArticle];
			[folderArrayCopy removeObject:theArticle];
		}
		else if (!deleteFlag && (currentFolderId == [db trashFolderId]))
		{
			[currentArrayCopy removeObject:theArticle];
			[folderArrayCopy removeObject:theArticle];
		}
		else
			needReload = YES;
	}
	[db commitTransaction];
	[self setCurrentArrayOfArticles:currentArrayCopy];
	[currentArrayCopy release];
	[self setFolderArrayOfArticles:folderArrayCopy];
	[folderArrayCopy release];
	if (needReload)
		[mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
	else
	{
		[mainArticleView refreshFolder:MA_Refresh_RedrawList];
		if ([currentArrayOfArticles count] > 0u)
			[mainArticleView ensureSelectedArticle:YES];
		else
			[[NSApp mainWindow] makeFirstResponder:[foldersTree mainView]];
	}

	// If any of the articles we deleted were unread then the
	// folder's unread count just changed.
	if (needFolderRedraw)
	{
		[foldersTree updateFolder:currentFolderId recurseToParents:YES];
		[[NSApp delegate] showUnreadCountOnApplicationIconAndWindowTitle];
	}
}

/* deleteArticlesByArray
 * Physically delete all selected articles in the article list.
 */
-(void)deleteArticlesByArray:(NSArray *)articleArray
{		
	// Make a new copy of currentArrayOfArticles and folderArrayOfArticles with the selected article removed.
	NSMutableArray * currentArrayCopy = [[NSMutableArray alloc] initWithArray:currentArrayOfArticles];
	NSMutableArray * folderArrayCopy = [[NSMutableArray alloc] initWithArray:folderArrayOfArticles];
	BOOL needFolderRedraw = NO;
	
	// Iterate over every selected article in the table and remove it from
	// the database.
	Database * db = [Database sharedDatabase];

	[db beginTransaction];
	for (Article * theArticle in articleArray)	
	{
		if (![theArticle isRead])
			needFolderRedraw = YES;
		if ([db deleteArticle:[theArticle folderId] guid:[theArticle guid]])
		{
			[currentArrayCopy removeObject:theArticle];
			[folderArrayCopy removeObject:theArticle];
		}
	}
	[db commitTransaction];
	[self setCurrentArrayOfArticles:currentArrayCopy];
	[currentArrayCopy release];
	[self setFolderArrayOfArticles:folderArrayCopy];
	[folderArrayCopy release];
	[mainArticleView refreshFolder:MA_Refresh_RedrawList];

	// If any of the articles we deleted were unread then the
	// folder's unread count just changed.
	if (needFolderRedraw)
		[foldersTree updateFolder:currentFolderId recurseToParents:YES];

	// Ensure there's a valid selection
	if ([currentArrayOfArticles count] > 0u)
		[mainArticleView ensureSelectedArticle:YES];
	else
		[[NSApp mainWindow] makeFirstResponder:[foldersTree mainView]];
	
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
	Database * db = [Database sharedDatabase];
	
	// Set up to undo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markFlagUndoAction = flagged ? @selector(markUnflagUndo:) : @selector(markFlagUndo:);
	[undoManager registerUndoWithTarget:self selector:markFlagUndoAction object:articleArray];
	[undoManager setActionName:NSLocalizedString(@"Flag", nil)];

	[db beginTransaction];
	for (Article * theArticle in articleArray)
	{
		Folder *myFolder = [db folderFromID:[theArticle folderId]];
		if (IsGoogleReaderFolder(myFolder)) {
			[[GoogleReader sharedManager] markStarred:[theArticle guid] starredFlag:flagged];
		}
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
	
	// The info bar has a count of unread articles so we need to
	// update that.
	[[NSApp delegate] showUnreadCountOnApplicationIconAndWindowTitle];
}

/* innerMarkReadByArray
 * Marks all articles in the specified array read or unread.
 */
-(void)innerMarkReadByArray:(NSArray *)articleArray readFlag:(BOOL)readFlag
{
	Database * db = [Database sharedDatabase];
	NSInteger lastFolderId = -1;
	
	for (Article * theArticle in articleArray)
	{
		NSInteger folderId = [theArticle folderId];
		if (IsGoogleReaderFolder([db folderFromID:folderId]) && ([theArticle isRead] != readFlag)) {
			[[GoogleReader sharedManager] markRead:[theArticle guid] readFlag:readFlag];
		}
		//FIX: article status should be "settato" from httprequest success block
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
	NSArray * refArray = nil;

	[db beginTransaction];
	refArray = [self wrappedMarkAllReadInArray:folderArray withUndo:undoFlag];
	[db commitTransaction];
	if (refArray != nil && [refArray count] > 0)
	{
		NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
		[undoManager registerUndoWithTarget:self selector:@selector(markAllReadUndo:) object:refArray];
		[undoManager setActionName:NSLocalizedString(@"Mark All Read", nil)];
	}

	for (Article * theArticle in folderArrayOfArticles)
	{
		if (IsGoogleReaderFolder([db folderFromID:[theArticle folderId]]) && ![theArticle isRead]) {
			[[GoogleReader sharedManager] markRead:[theArticle guid] readFlag:YES];
		}
		[theArticle markRead:YES];

	}
    
	if (refreshFlag)
		[mainArticleView refreshFolder:MA_Refresh_RedrawList];
	[[NSApp delegate] showUnreadCountOnApplicationIconAndWindowTitle];
}

/* wrappedMarkAllReadInArray
 * Given an array of folders, mark all the articles in those folders as read and
 * return a reference array listing all the articles that were actually marked.
 */
-(NSArray *)wrappedMarkAllReadInArray:(NSArray *)folderArray withUndo:(BOOL)undoFlag
{
	NSMutableArray * refArray = [NSMutableArray array];
	Database * db = [Database sharedDatabase];
	
	for (Folder * folder in folderArray)
	{
		int folderId = [folder itemId];
		if (IsGroupFolder(folder) && undoFlag)
		{
			[refArray addObjectsFromArray:[self wrappedMarkAllReadInArray:[db arrayOfFolders:folderId] withUndo:undoFlag]];
		}
		else if (IsRSSFolder(folder))
		{
			if (undoFlag)
				[refArray addObjectsFromArray:[db arrayOfUnreadArticles:folderId]];
			if ([db markFolderRead:folderId])
			{
				[foldersTree updateFolder:folderId recurseToParents:YES];
                
			}
		}
		else
		{
			// Google Reader feeds and smart folders
			// For smart folders, we only mark all read the current folder to
			// simplify things.
			if (undoFlag && (IsGoogleReaderFolder(folder) || folderId == currentFolderId))
			{
				[refArray addObjectsFromArray:currentArrayOfArticles];
				[self innerMarkReadByArray:currentArrayOfArticles readFlag:YES];
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
	Database * db = [Database sharedDatabase];
	int lastFolderId = -1;
	BOOL needRefilter = NO;
	
	// Set up to undo or redo this action
	NSUndoManager * undoManager = [[NSApp mainWindow] undoManager];
	SEL markAllReadUndoAction = readFlag ? @selector(markAllReadUndo:) : @selector(markAllReadRedo:);
	[undoManager registerUndoWithTarget:self selector:markAllReadUndoAction object:refArray];
	[undoManager setActionName:NSLocalizedString(@"Mark All Read", nil)];
	
	[db beginTransaction];
	for (ArticleReference *ref in refArray)
	{
		int folderId = [ref folderId];
		[db markArticleRead:folderId guid:[ref guid] isRead:readFlag];
		if (folderId != lastFolderId && lastFolderId != -1)
		{
			[foldersTree updateFolder:lastFolderId recurseToParents:YES];
			if (lastFolderId == currentFolderId)
				needRefilter = YES;
		}
		lastFolderId = folderId;
	}
	[db commitTransaction];
	
	if (lastFolderId != -1)
	{
		[foldersTree updateFolder:lastFolderId recurseToParents:YES];
		if (lastFolderId == currentFolderId)
			needRefilter = YES;
        if (!IsRSSFolder([db folderFromID:currentFolderId])&&!IsGoogleReaderFolder([db folderFromID:currentFolderId]))
            [mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
        else if (needRefilter)
            [mainArticleView refreshFolder:MA_Refresh_ReapplyFilter];
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
-(void)goBack
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

/* handleFilterChange
* Update the list of articles when the user changes the filter.
*/
-(void)handleFilterChange:(NSNotification *)nc
{
	[mainArticleView refreshFolder:MA_Refresh_ReapplyFilter];
}

/* handleFolderNameChange
* Some folder metadata changed. Update the article list header and the
* current article with a possible name change.
*/
-(void)handleFolderNameChange:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	if (folderId == currentFolderId)
		[mainArticleView refreshArticlePane];
}

/* handleRefreshArticle
* Respond to the notification to refresh the current article pane.
*/
-(void)handleRefreshArticle:(NSNotification *)nc
{
	[mainArticleView handleRefreshArticle:nc];
}

// TODO this is being called too often by sync operations. We should try to avoid
// querying the database so often. Need to look into having the sync operations know
// when everything has been completed and only query the database once.
-(void)handleArticleListStateChange:(NSNotification *)nc
{
    [mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
    //[mainArticleView refreshFolder:MA_Refresh_RedrawList];
}

/* handleFolderUpdate
* Called if a folder content has changed.
*/
-(void)handleFolderUpdate:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	if (folderId != currentFolderId)
		return;
	
	Folder * folder = [[Database sharedDatabase] folderFromID:folderId];
	if (IsSmartFolder(folder) || IsTrashFolder(folder))
		[mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
}

/* setArticleToPreserve
 * Sets the article to preserve when reloading the array of articles.
 */
-(void)setArticleToPreserve:(Article *)article
{
	[article retain];
	[articleToPreserve release];
	articleToPreserve = article;
}

/* dealloc
 * Clean up behind us.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[mainArticleView release];
	self.mainArticleView=nil;
	[backtrackArray release];
	self.backtrackArray=nil;
	[sortColumnIdentifier release];
	[folderArrayOfArticles release];
	self.folderArrayOfArticles=nil;
	[currentArrayOfArticles release];
	self.currentArrayOfArticles=nil;
	[articleSortSpecifiers release];
	[articleToPreserve release];
	[super dealloc];
}
@end
