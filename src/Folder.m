//
//  Folder.m
//  Vienna
//
//  Created by Steve on Thu Feb 19 2004.
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

#import "Folder.h"
#import "AppController.h"
#import "Constants.h"
#import "KeyChain.h"
#import "FolderImageCache.h"
#import "StringExtensions.h"
#import "Preferences.h"
#import "ArticleRef.h"

// Private internal functions
@interface Folder (Private)
	+(NSArray *)_iconArray;
@end


// Static pointers
static NSArray * iconArray = nil;


@implementation Folder

/* initWithId
 * Initialise a new folder object instance.
 */
-(instancetype)initWithId:(NSInteger)newId parentId:(NSInteger)newIdParent name:(NSString *)newName type:(NSInteger)newType
{
	if ((self = [super init]) != nil)
	{
		itemId = newId;
		parentId = newIdParent;
		firstChildId = 0;
		nextSiblingId = 0;
		unreadCount = 0;
		childUnreadCount = 0;
		type = newType;
		flags = 0;
		nonPersistedFlags = 0;
		isCached = NO;
		containsBodies = NO;
		hasPassword = NO;
		cachedArticles = [NSCache new];
		cachedArticles.delegate = self;
		cachedGuids = [NSMutableArray array];
		attributes = [NSMutableDictionary dictionary];
		self.name = newName;
		self.lastUpdateString = @"";
		self.username = @"";
		lastUpdate = [NSDate distantPast];
	}
	return self;
}

/* _iconArray
 * Return the internal array of pre-defined folder images
 */
+(NSArray *)_iconArray
{
	if (iconArray == nil)
		iconArray = @[
					  [NSImage imageNamed:@"smallFolder.tiff"],
					  [NSImage imageNamed:@"smartFolder.tiff"],
					  [NSImage imageNamed:@"rssFolder.tiff"],
					  [NSImage imageNamed:@"rssFeedNew.tiff"],
					  [NSImage imageNamed:@"trashFolder.tiff"],
					  [NSImage imageNamed:@"searchFolder.tiff"],
					  [NSImage imageNamed:@"googleFeed.tiff"],
					  ];
	return iconArray;
}

/* itemId
 * Returns the folder's ID.
 */
-(NSInteger)itemId
{
	return itemId;
}

/* parentId
 * Returns this folder's parent ID.
 */
-(NSInteger)parentId
{
	return parentId;
}

/* nextSiblingId
 * Returns the ID of the folder's next sibling.
 */
-(NSInteger)nextSiblingId
{
	return nextSiblingId;
}

/* nextSiblingId
 * Returns the ID of the folder's first child.
 */
-(NSInteger)firstChildId
{
	return firstChildId;
}

/* unreadCount
 */
-(NSInteger)unreadCount
{
	return unreadCount;
}

/* type
 */
-(NSInteger)type
{
	return type;
}

/* flags
 */
-(NSUInteger)flags
{
	return flags;
}

/* nonPersistedFlags
 */
-(NSUInteger)nonPersistedFlags
{
	return nonPersistedFlags;
}

/* childUnreadCount
 */
-(NSInteger)childUnreadCount
{
	return childUnreadCount;
}

/* feedDescription
 * Returns the feed's description.
 */
-(NSString *)feedDescription
{
	return [attributes valueForKey:@"FeedDescription"];
}

/* homePage
 * Returns the folder's home page URL.
 */
-(NSString *)homePage
{
	return [attributes valueForKey:@"HomePage"];
}

/* image
 * Returns an NSImage item that represents the specified folder.
 */
-(NSImage *)image
{
	if (IsGroupFolder(self))
		return [Folder _iconArray][MA_RSSFolderIcon];
	if (IsSmartFolder(self))
		return [Folder _iconArray][MA_SmartFolderIcon];
	if (IsTrashFolder(self))
		return [Folder _iconArray][MA_TrashFolderIcon];
	if (IsSearchFolder(self))
		return [Folder _iconArray][MA_SearchFolderIcon];
	//	if (IsGoogleReaderFolder(self))
	//	return [[Folder _iconArray] objectAtIndex:MA_GoogleReaderFolderIcon];
	if (IsRSSFolder(self) || IsGoogleReaderFolder(self))
	{
		// Try the folder icon cache.
		NSImage * imagePtr = nil;
		if (self.feedURL)
		{	
			NSString * homePageSiteRoot;
			homePageSiteRoot = self.homePage.host.convertStringToValidPath;
			imagePtr = [[FolderImageCache defaultCache] retrieveImage:homePageSiteRoot];
		}
		NSImage *altIcon;
		if (IsRSSFolder(self)) {
			altIcon = [Folder _iconArray][MA_RSSFeedIcon];
		} else {
			altIcon = [Folder _iconArray][MA_GoogleReaderFolderIcon];
		}
		return (imagePtr) ? imagePtr : altIcon;
	}
	
	// Use the generic folder icon for anything else
	return [Folder _iconArray][MA_FolderIcon];
}

/* hasCachedImage
 * Returns YES if the folder has an image stored in the cache.
 */
-(BOOL)hasCachedImage
{
	if (!IsRSSFolder(self) && !IsGoogleReaderFolder(self))
		return NO;
	NSImage * imagePtr = nil;
	if (self.feedURL)
	{
		NSString * homePageSiteRoot = self.homePage.host.convertStringToValidPath;
		imagePtr = [[FolderImageCache defaultCache] retrieveImage:homePageSiteRoot];
	}
	return (imagePtr != nil);
}

/* standardImage
 * Returns the standard (not feed customised) image for this folder.
 */
-(NSImage *)standardImage
{
	if (IsRSSFolder(self))
		return [Folder _iconArray][MA_RSSFeedIcon];
	if (IsGoogleReaderFolder(self))
		return [Folder _iconArray][MA_GoogleReaderFolderIcon];
	return self.image;
}

/* setImage
 * Used to set the image for a folder in the array. The image is cached for this session
 * and also written to the image folder if there is a valid one.
 */
-(void)setImage:(NSImage *)iconImage
{
	if (self.feedURL != nil && iconImage != nil)
	{
		NSString * homePageSiteRoot;
		homePageSiteRoot = self.homePage.host.convertStringToValidPath;
		[[FolderImageCache defaultCache] addImage:iconImage forURL:homePageSiteRoot];
	}
}

/* setFeedDescription
 * Sets the folder feed description.
 */
-(void)setFeedDescription:(NSString *)newFeedDescription
{
	[attributes setValue:SafeString(newFeedDescription) forKey:@"FeedDescription"];
}

/* setHomePage
 * Sets the folder's home page URL.
 */
-(void)setHomePage:(NSString *)newHomePage
{
	[attributes setValue:SafeString(newHomePage) forKey:@"HomePage"];
}

/* username
 * Returns the feed username.
 */
-(NSString *)username
{
	return [attributes valueForKey:@"Username"];
}

/* setUsername
 * Sets the username associated with this feed.
 */
-(void)setUsername:(NSString *)newUsername
{
	[attributes setValue:newUsername forKey:@"Username"];
}

/* password
 * Returns the feed password.
 */
-(NSString *)password
{
	if (!hasPassword)
	{
		if (self.username != nil && self.feedURL != nil)
			[attributes setValue:[KeyChain getPasswordFromKeychain:self.username url:self.feedURL] forKey:@"Password"];
		hasPassword = YES;
	}
	return [attributes valueForKey:@"Password"];
}

/* setPassword
 * Sets the password associated with this feed.
 */
-(void)setPassword:(NSString *)newPassword
{
	if (self.username != nil && self.feedURL != nil)
		[KeyChain setPasswordInKeychain:newPassword username:self.username url:self.feedURL];
	[attributes setValue:newPassword forKey:@"Password"];
	hasPassword = YES;
}

/* lastUpdate
 * Return the date of the last update from the feed.
 */
-(NSDate *)lastUpdate
{
	return lastUpdate;
}

/* setLastUpdate
 * Sets the last update date for this RSS feed.
 */
-(void)setLastUpdate:(NSDate *)newLastUpdate
{
	lastUpdate = newLastUpdate;
}

/* lastUpdateString
 * Return the last modified date of the feed as a string.
 */
-(NSString *)lastUpdateString
{
	return [attributes valueForKey:@"LastUpdateString"];
}

/* setLastUpdateString
 * Set the last update string. This is specifically a site-dependent Last-Modified
 * string that is basically passed with If-Modified-Since when requesting data from
 * the same site.
 */
-(void)setLastUpdateString:(NSString *)newLastUpdateString
{
	[attributes setValue:newLastUpdateString forKey:@"LastUpdateString"];
}

/* feedURL
 * Return the URL of the subscription.
 */
-(NSString *)feedURL
{
	return [attributes valueForKey:@"FeedURL"];
}

/* setFeedURL
 * Changes the URL of the subscription.
 */
-(void)setFeedURL:(NSString *)newURL
{
	[attributes setValue:newURL forKey:@"FeedURL"];
}

/* name
 * Returns the folder name
 */
-(NSString *)name
{
	return [attributes valueForKey:@"Name"];
}

/* setName
 * Updates the folder name.
 */
-(void)setName:(NSString *)newName
{
	[attributes setValue:newName forKey:@"Name"];
}

/* setType
 * Changes the folder type
 */
-(void)setType:(NSInteger)newType
{
	type = newType;
}

/* isGroupFolder
 * Used for scripting. Returns YES if this folder is a group folder.
 */
-(BOOL)isGroupFolder
{
	return IsGroupFolder(self);
}

/* isSmartFolder
 * Used for scripting. Returns YES if this folder is a smart folder.
 */
-(BOOL)isSmartFolder
{
	return IsSmartFolder(self);
}

/* isRSSFolder
 * Used for scripting. Returns YES if this folder is an RSS feed folder.
 */
-(BOOL)isRSSFolder
{
	return IsRSSFolder(self);
}

/* loadsFullHTML
 * Returns YES if this folder loads the full HTML articles instead of the feed text.
 */
-(BOOL)loadsFullHTML
{
	return LoadsFullHTML(self);
}

/* setFlag
 * Set the specified flag on the folder.
 */
-(void)setFlag:(NSUInteger)flagToSet
{
	flags |= flagToSet;
}

/* clearFlag
 * Clears the specified flag on the folder.
 */
-(void)clearFlag:(NSUInteger)flagToClear
{
	flags &= ~flagToClear;
}

/* setNonPersistedFlag
 * Set the specified flag on the folder.
 */
-(void)setNonPersistedFlag:(NSUInteger)flagToSet
{
	@synchronized(self) {
		nonPersistedFlags |= flagToSet;
	}
}

/* clearNonPersistedFlag
 * Clears the specified flag on the folder.
 */
-(void)clearNonPersistedFlag:(NSUInteger)flagToClear
{
	@synchronized(self) {
		nonPersistedFlags &= ~flagToClear;
	}
}

/* setParent
 * Re-parent the folder.
 */
-(void)setParent:(NSInteger)newParent
{
	parentId = newParent;
}

/* setNextSiblingId
 * Set the ID for the folder's next sibling.
 */
-(void)setNextSiblingId:(NSInteger)newNextSibling
{
	nextSiblingId = newNextSibling;
}

/* setFirstChildId
 * Set the ID for the folder's first child.
 */
-(void)setFirstChildId:(NSInteger)newFirstChild;
{
	firstChildId = newFirstChild;
}

/* indexOfArticle
 * Returns the index of the article that matches the specified article based on guid.
 */
-(NSUInteger)indexOfArticle:(Article *)article
{
    @synchronized(self)
    {
        [self ensureCache];
        return [cachedGuids indexOfObject:article.guid];
    }
}

/* articleFromGuid
 */
-(Article *)articleFromGuid:(NSString *)guid
{
    @synchronized(self)
    {
        [self ensureCache];
	    return [cachedArticles objectForKey:guid];
	}
}

/* createArticle
 * Adds or updates an article in the folder.
 * Returns YES if the article was added or updated
 * or NO if we couldn't add the article for some reason.
 * On success, status information is updated in the article to mark
 * if it is new or updated (from the point of view of the user).
 */
-(BOOL)createArticle:(Article *)article guidHistory:(NSArray *)guidHistory
{
@synchronized(self)
  {
    // Prime the article cache
    [self ensureCache];

    // Unread count adjustment factor
    NSInteger adjustment = 0;

    NSString * articleGuid = article.guid;
    // Does this article already exist?
    // We're going to ignore here the problem of feeds re-using guids, which is very naughty! Bad feed!
    Article * existingArticle = [cachedArticles objectForKey:articleGuid];

    if (existingArticle == nil)
    {
        if ([guidHistory containsObject:articleGuid])
            return NO; // Article has been deleted and removed from database, so ignore
        else
        {
            // add the article as new
            BOOL success = [[Database sharedManager] addArticle:article toFolder:itemId];
            if(success)
            {
                article.status = ArticleStatusNew;
                // add to the cache
	            [cachedGuids addObject:articleGuid];
	            [cachedArticles setObject:article forKey:[NSString stringWithString:articleGuid]];
                if(!article.read)
                    adjustment = 1;
            }
            else
                return NO;
        }
    }
    else if (existingArticle.deleted)
    {
        return NO;
    }
    else if (![[Preferences standardPreferences] boolForKey:MAPref_CheckForUpdatedArticles])
    {
        return NO;
    }
    else
    {
        BOOL success = [[Database sharedManager] updateArticle:existingArticle ofFolder:itemId withArticle:article];
        if (success)
        {
            // Update folder unread count if necessary
            if (existingArticle.read)
            {
                adjustment = 1;
                article.status = ArticleStatusNew;
                [existingArticle markRead:NO];
            }
            else
            {
                article.status = ArticleStatusUpdated;
            }
        }
        else
        {
            return NO;
        }
    }

    // Fix unread count on parent folders and Database manager
    if (adjustment != 0)
    {
		[[Database sharedManager] setFolderUnreadCount:self adjustment:adjustment];
    }
    return YES;
  } // synchronized
}

/* setUnreadCount
 */
-(void)setUnreadCount:(NSInteger)count
{
	@synchronized(self) {
		NSAssert1(count >= 0, @"Attempting to set a negative unread count on folder %@", [self name]);
		unreadCount = count;
	}
}

/* setChildUnreadCount
 * Update a separate count of the total number of unread articles
 * in all child folders.
 */
-(void)setChildUnreadCount:(NSInteger)count
{
	@synchronized(self) {
		NSAssert1(count >= 0, @"Attempting to set a negative unread count on folder %@", [self name]);
		childUnreadCount = count;
	}
}

/* clearCache
 * Empty the folder's cache of article.
 */
-(void)clearCache
{
    @synchronized(self)
    {
		[cachedArticles removeAllObjects];
		[cachedGuids removeAllObjects];
		isCached = NO;
		containsBodies = NO;
	}
}

/* removeArticleFromCache
 * Remove the article identified by the specified GUID from the cache.
 */
-(void)removeArticleFromCache:(NSString *)guid
{
    @synchronized(self)
    {
        NSAssert(isCached, @"Folder's cache of articles should be initialized before removeArticleFromCache can be used");
        [cachedArticles removeObjectForKey:guid];
        [cachedGuids removeObject:guid];
    }
}

/* countOfCachedArticles
 * Return the number of articles in our cache, or -1 if the cache is empty.
 * (Note: empty is not the same as a folder with zero articles. The semantics are
 * important here since we could potentially keep trying to recache an folder that
 * truly has zero articles otherwise).
 */
-(NSInteger)countOfCachedArticles
{
	return isCached ? (NSInteger)cachedGuids.count : -1;
}

/* ensureCache
 * Prepare the cache if it is not yet ready
 */
 -(void)ensureCache
 {
    [cachedArticles setEvictsObjectsWithDiscardedContent:NO];
    if (!isCached)
    {
        [cachedGuids removeAllObjects];
        [cachedArticles removeAllObjects];
        [[Database sharedManager] prepareCache:cachedArticles forFolder:itemId saveGuidsIn:cachedGuids];
    }
    isCached = YES;
    // Note that articles' statuses are left at the default value (0) which is ArticleStatusEmpty
    [cachedArticles setEvictsObjectsWithDiscardedContent:YES];
}

/* articles
 * Return an array of all articles in the specified folder.
 */
-(NSArray *)articles
{
    return [self articlesWithFilter:@""];
}

/* markArticlesInCacheRead
 * iterate through the cache and mark the articles as read
 */
-(void)markArticlesInCacheRead
{
@synchronized(self)
  {
    NSInteger count = unreadCount;
    // Note the use of reverseObjectEnumerator
    // since the unread articles are likely to be clustered
    // with the most recent articles at the end of the array
    // so it makes the code slightly faster.
    for (id obj in cachedGuids.reverseObjectEnumerator.allObjects)
    {
        Article * article = [cachedArticles objectForKey:(NSString *)obj];
        if (!article.read)
        {
            [article markRead:YES];
            count--;
            if (count == 0)
                break;
        }
    }
  } // synchronized
}

/* arrayOfUnreadArticlesRefs
 * Return an array of ArticleReference of all unread articles
 */
-(NSArray *)arrayOfUnreadArticlesRefs
{
@synchronized(self)
  {
    if (isCached)
    {
        NSInteger count = unreadCount;
        NSMutableArray * result = [NSMutableArray arrayWithCapacity:unreadCount];
        for (id obj in cachedGuids.reverseObjectEnumerator.allObjects)
        {
            Article * article = [cachedArticles objectForKey:(NSString *)obj];
            if (!article.read)
            {
                [result addObject:[ArticleReference makeReference:article]];
                count--;
                if (count == 0)
                    break;
            }
        }
        return [result copy];
    }
    else
        return [[Database sharedManager] arrayOfUnreadArticlesRefs:itemId];
  } // synchronized
}

/* articlesWithFilter
 * Return an array of filtered articles in the specified folder.
 */
-(NSArray *)articlesWithFilter:(NSString *)fstring
{
@synchronized(self)
  {
	if ([fstring isEqualToString:@""])
	{
        if (isCached && containsBodies)
		{
			NSMutableArray * articles = [NSMutableArray arrayWithCapacity:cachedGuids.count];
			for (id object in cachedGuids)
			{
				Article * theArticle = [cachedArticles objectForKey:object];
				if (theArticle != nil)
				    [articles addObject:theArticle];
				else
				{   // some problem
				    NSLog(@"Bug retrieving from cache in folder %li : after %lu insertions of %lu, guid %@",(long)itemId, (unsigned long)articles.count,(unsigned long)cachedGuids.count,object);
				    isCached = NO;
				    containsBodies = NO;
				    break;
				}
			}
			return [articles copy];
		}
        else
        {
            NSArray * articles = [[Database sharedManager] arrayOfArticles:itemId filterString:fstring];
            // Only feeds folders can be cached, as they are the only ones to guarantee
            // bijection : one article <-> one guid
            if (IsRSSFolder(self) || IsGoogleReaderFolder(self))
            {
                isCached = NO;
                [cachedArticles removeAllObjects];
                [cachedGuids removeAllObjects];
                for (id object in articles)
                {
                    NSString * guid = ((Article *)object).guid;
                    [cachedGuids addObject:guid];
                    [cachedArticles setObject:object forKey:[NSString stringWithString:guid]];
                }
                isCached = YES;
                containsBodies = YES;
            }
            return articles;
        }
	}
	else
	    return [[Database sharedManager] arrayOfArticles:itemId filterString:fstring];
  } //synchronized
}

/* folderNameCompare
 * Returns the result of comparing two folders by folder name.
 */
-(NSComparisonResult)folderNameCompare:(Folder *)otherObject
{
	return [self.name caseInsensitiveCompare:otherObject.name];
}

/* folderIDCompare
 * Returns the result of comparing two folders by folder ID.
 */
-(NSComparisonResult)folderIDCompare:(Folder *)otherObject
{
	if (self.itemId > otherObject.itemId) return NSOrderedAscending;
	if (self.itemId < otherObject.itemId) return NSOrderedDescending;
	return NSOrderedSame;
}

/* feedSourceFilePath
 * Returns the path of the raw feed source file for the folder
 */
-(NSString *)feedSourceFilePath
{
	NSString * feedSourceFilePath = nil;
	if (self.RSSFolder)
	{
		NSString * feedSourceFileName = [NSString stringWithFormat:@"folder%li.xml", (long)self.itemId];
		feedSourceFilePath = [[Preferences standardPreferences].feedSourcesFolder stringByAppendingPathComponent:feedSourceFileName];
	}
	return feedSourceFilePath;
}

/* hasFeedSource
 * Returns whether there is a downloaded feed source for the folder.
 */
-(BOOL)hasFeedSource
{
	NSString * feedSourceFilePath = self.feedSourceFilePath;
	BOOL isDirectory = YES;
	return feedSourceFilePath != nil && [[NSFileManager defaultManager] fileExistsAtPath:feedSourceFilePath isDirectory:&isDirectory] && !isDirectory;
}

/* objectSpecifier
 * Return an NSScriptObjectSpecifier object representing this folder.
 */
-(NSScriptObjectSpecifier *)objectSpecifier
{
	NSArray * folders = APPCONTROLLER.folders;
	NSUInteger index = [folders indexOfObjectIdenticalTo:self];
	if (index != NSNotFound)
	{
		NSScriptObjectSpecifier *containerRef = APPCONTROLLER.objectSpecifier;
		return [[NSIndexSpecifier allocWithZone:nil] initWithContainerClassDescription:(NSScriptClassDescription *)NSApp.classDescription containerSpecifier:containerRef key:@"folders" index:index];
	}
	return nil;
}

/* description
 * Return a description of the folder.
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"Folder id %li (%@)", (long)itemId, self.name];
}

#pragma mark NSCacheDelegate
-(void)cache:(NSCache *)cache willEvictObject:(id)obj
{
    @synchronized(self)
    {
        isCached = NO;
        containsBodies = NO;
        [cachedGuids removeAllObjects];
    }
}
@end
