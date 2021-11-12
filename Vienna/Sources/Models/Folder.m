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
#import "Database.h"
#import "Article.h"

@interface Folder ()

@property (nonatomic) NSInteger itemId;
@property (nonatomic) BOOL isCached;
@property (nonatomic) BOOL containsBodies;
@property (nonatomic) BOOL hasPassword;
@property (nonatomic, strong) NSCache * cachedArticles;
@property (nonatomic, strong) NSMutableArray * cachedGuids;
@property (nonatomic, strong) NSMutableDictionary * attributes;

+(NSArray<NSImage *> *)_iconArray;

@end

// Static pointers
static NSArray * iconArray = nil;


@implementation Folder

/* initWithId
 * Initialise a new folder object instance.
 */
-(instancetype)initWithId:(NSInteger)newId parentId:(NSInteger)newIdParent name:(NSString *)newName type:(VNAFolderType)newType
{
	if ((self = [super init]) != nil)
	{
		_itemId = newId;
		_parentId = newIdParent;
		_firstChildId = 0;
		_nextSiblingId = 0;
		unreadCount = 0;
		childUnreadCount = 0;
		_type = newType;
        flags = 0;
        nonPersistedFlags = 0;
        _isCached = NO;
		_containsBodies = NO;
		_hasPassword = NO;
		_cachedArticles = [NSCache new];
		_cachedArticles.delegate = self;
		_cachedGuids = [NSMutableArray array];
		_attributes = [NSMutableDictionary dictionary];
		self.name = newName;
		self.lastUpdateString = @"";
		self.username = @"";
		_lastUpdate = [NSDate distantPast];
		self.remoteId = @"0";
	}
	return self;
}

/* _iconArray
 * Return the internal array of pre-defined folder images
 */
+(NSArray<NSImage *> *)_iconArray {
	if (iconArray == nil)
		iconArray = @[
					  [NSImage imageNamed:@"smallFolder"],
					  [NSImage imageNamed:@"smartFolder"],
					  [NSImage imageNamed:@"rssFolder"],
					  [NSImage imageNamed:@"rssFeedNew"],
					  [NSImage imageNamed:@"trashFolder"],
					  [NSImage imageNamed:@"searchFolder"],
					  [NSImage imageNamed:@"googleFeed"],
					  ];
	return iconArray;
}

/* unreadCount
 */
-(NSInteger)unreadCount
{
	return unreadCount;
}

/* flags
 */
-(VNAFolderFlag)flags
{
    return flags;
}

/* nonPersistedFlags
 */
-(VNAFolderFlag)nonPersistedFlags
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
	return SafeString(self.attributes[@"FeedDescription"]);
}

/* homePage
 * Returns the folder's home page URL.
 */
-(NSString *)homePage
{
	return SafeString(self.attributes[@"HomePage"]);
}

/*! Folder image
 * @return NSImage item that represents the specified folder or nil if
 * no appropriate image is found.
 */
-(NSImage * _Nullable)image {
    NSImage *folderImage = nil;
    switch (self.type) {
        case VNAFolderTypeSmart:
            folderImage = Folder._iconArray[MA_SmartFolderIcon];
            break;
        case VNAFolderTypeGroup:
            folderImage = Folder._iconArray[MA_RSSFolderIcon];
            break;
        case VNAFolderTypeTrash:
            folderImage = Folder._iconArray[MA_TrashFolderIcon];
            break;
        case VNAFolderTypeSearch:
            folderImage = Folder._iconArray[MA_SmartFolderIcon];
            break;
        case VNAFolderTypeRSS: {
            NSString *homePageSiteRoot = self.homePage.vna_host.vna_convertStringToValidPath;
            folderImage = [[FolderImageCache defaultCache] retrieveImage:homePageSiteRoot];
            if (folderImage == nil) {
                folderImage = Folder._iconArray[MA_RSSFeedIcon];
            }
            break;
        }
        case VNAFolderTypeOpenReader: {
            NSString *homePageSiteRoot = self.homePage.vna_host.vna_convertStringToValidPath;
            folderImage = [[FolderImageCache defaultCache] retrieveImage:homePageSiteRoot];
            if (folderImage == nil) {
                folderImage = Folder._iconArray[MA_GoogleReaderFolderIcon];
            }
            break;
        }
        default: // Use the generic folder icon for anything else
            folderImage = Folder._iconArray[MA_FolderIcon];
            break;
    }
    
    return folderImage;
}

/*!Check if an RSS or OpenReader folder
 * has an image stored in cache.
 * @return YES if the folder has an image stored in the cache.
 */
-(BOOL)hasCachedImage {
    if (self.type != VNAFolderTypeRSS && self.type != VNAFolderTypeOpenReader) {
		return NO;
    }
	NSImage * imagePtr = nil;
	if (self.feedURL) {
		NSString * homePageSiteRoot = self.homePage.vna_host.vna_convertStringToValidPath;
		imagePtr = [[FolderImageCache defaultCache] retrieveImage:homePageSiteRoot];
	}
	return (imagePtr != nil);
}

/*!Get the standard (not feed customised) image for this folder.
 * @return The standard image.
 */
-(NSImage *)standardImage {
    switch (self.type) {
        case VNAFolderTypeRSS: return Folder._iconArray[MA_RSSFeedIcon];
        case VNAFolderTypeOpenReader: return Folder._iconArray[MA_GoogleReaderFolderIcon];
        default: return self.image;
    }
}

/* setImage
 * Used to set the image for a folder in the array. The image is cached for this session
 * and also written to the image folder if there is a valid one.
 */
-(void)setImage:(NSImage *)image
{
    NSImage *iconImage = [image copy];
	if (self.feedURL != nil && iconImage != nil)
	{
		NSString * homePageSiteRoot;
		homePageSiteRoot = self.homePage.vna_host.vna_convertStringToValidPath;
		[[FolderImageCache defaultCache] addImage:iconImage forURL:homePageSiteRoot];
	}
}

/* setFeedDescription
 * Sets the folder feed description.
 */
-(void)setFeedDescription:(NSString *)newFeedDescription
{
	[self.attributes setValue:SafeString([newFeedDescription copy]) forKey:@"FeedDescription"];
}

/* setHomePage
 * Sets the folder's home page URL.
 */
-(void)setHomePage:(NSString *)newHomePage
{
	[self.attributes setValue:SafeString([newHomePage copy]) forKey:@"HomePage"];
}

/* username
 * Returns the feed username.
 */
-(NSString *)username
{
	return [self.attributes valueForKey:@"Username"];
}

/* setUsername
 * Sets the username associated with this feed.
 */
-(void)setUsername:(NSString *)newUsername
{
	[self.attributes setValue:[newUsername copy] forKey:@"Username"];
}

/* password
 * Returns the feed password.
 */
-(NSString *)password
{
	if (!self.hasPassword)
	{
		if (self.username != nil && self.feedURL != nil)
			[self.attributes setValue:[KeyChain getPasswordFromKeychain:self.username url:self.feedURL] forKey:@"Password"];
		self.hasPassword = YES;
	}
	return [self.attributes valueForKey:@"Password"];
}

/* setPassword
 * Sets the password associated with this feed.
 */
-(void)setPassword:(NSString *)password
{
	NSString *newPassword = [password copy];
	if (self.username != nil && self.feedURL != nil)
		[KeyChain setPasswordInKeychain:newPassword username:self.username url:self.feedURL];
	[self.attributes setValue:newPassword forKey:@"Password"];
	self.hasPassword = YES;
}

/* lastUpdateString
 * Return the last modified date of the feed as a string.
 */
-(NSString *)lastUpdateString
{
	return [self.attributes valueForKey:@"LastUpdateString"];
}

/* setLastUpdateString
 * Set the last update string. This is specifically a site-dependent Last-Modified
 * string that is basically passed with If-Modified-Since when requesting data from
 * the same site.
 */
-(void)setLastUpdateString:(NSString *)newLastUpdateString
{
	[self.attributes setValue:[newLastUpdateString copy] forKey:@"LastUpdateString"];
}

/* feedURL
 * Return the URL of the subscription.
 */
-(NSString *)feedURL
{
	return [self.attributes valueForKey:@"FeedURL"];
}

/* setFeedURL
 * Changes the URL of the subscription.
 */
-(void)setFeedURL:(NSString *)newURL
{
	[self.attributes setValue:[newURL copy] forKey:@"FeedURL"];
}

/* remoteId
 * Returns the identifier used by the remote OpenReader server
 */
-(NSString *)remoteId
{
	return [self.attributes valueForKey:@"remoteId"];
}

/* setRemoteId
 * Stores the identifier used by the remote OpenReader server for this feed.
 */
-(void)setRemoteId:(NSString *)newId
{
	[self.attributes setValue:[newId copy] forKey:@"remoteId"];
}

/* name
 * Returns the folder name
 */
-(NSString *)name
{
	return [self.attributes valueForKey:@"Name"];
}

/* setName
 * Updates the folder name.
 */
-(void)setName:(NSString *)newName
{
	[self.attributes setValue:[newName copy] forKey:@"Name"];
}

/* isGroupFolder
 * Used for scripting. Returns YES if this folder is a group folder.
 */
-(BOOL)isGroupFolder {
	return self.type == VNAFolderTypeGroup;
}

/* isSmartFolder
 * Used for scripting. Returns YES if this folder is a smart folder.
 */
-(BOOL)isSmartFolder {
    return self.type == VNAFolderTypeSmart;
}

/* isRSSFolder
 * Used for scripting. Returns YES if this folder is an RSS feed folder.
 */
-(BOOL)isRSSFolder {
    return self.type == VNAFolderTypeRSS;
}

/* isOpenReaderFolder
 * Returns YES if this folder is an OpenReader feed folder.
 */
-(BOOL)isOpenReaderFolder {
    return self.type == VNAFolderTypeOpenReader;
}

// MARK: - VNAFolderFlag methods

/* loadsFullHTML
 * Returns YES if this folder loads the full HTML articles instead of the feed text.
 */
-(BOOL)loadsFullHTML{
	return (self.flags & VNAFolderFlagLoadFullHTML);
}

-(BOOL)isUnsubscribed {
    return (self.flags & VNAFolderFlagUnsubscribed);
}

-(BOOL)isUpdating {
    return (self.nonPersistedFlags & VNAFolderFlagUpdating);
}

-(BOOL)isError {
    return (self.nonPersistedFlags & VNAFolderFlagError);
}

-(BOOL)isSyncedOK {
    return (self.nonPersistedFlags & VNAFolderFlagSyncedOK);
}

/* setFlag
 * Set the specified flag on the folder.
 */
-(void)setFlag:(VNAFolderFlag)flagToSet
{
	flags |= flagToSet;
}

/* clearFlag
 * Clears the specified flag on the folder.
 */
-(void)clearFlag:(VNAFolderFlag)flagToClear
{
	flags &= ~flagToClear;
}

/* setNonPersistedFlag
 * Set the specified flag on the folder.
 */
-(void)setNonPersistedFlag:(VNAFolderFlag)flagToSet
{
	@synchronized(self) {
		nonPersistedFlags |= flagToSet;
	}
}

/* clearNonPersistedFlag
 * Clears the specified flag on the folder.
 */
-(void)clearNonPersistedFlag:(VNAFolderFlag)flagToClear
{
	@synchronized(self) {
		nonPersistedFlags &= ~flagToClear;
	}
}

/* indexOfArticle
 * Returns the index of the article that matches the specified article based on guid.
 */
-(NSUInteger)indexOfArticle:(Article *)article
{
    @synchronized(self)
    {
        [self ensureCache];
        return [self.cachedGuids indexOfObject:article.guid];
    }
}

/* articleFromGuid
 */
-(Article *)articleFromGuid:(NSString *)guid
{
    @synchronized(self)
    {
        [self ensureCache];
	    return [self.cachedArticles objectForKey:guid];
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
    Article * existingArticle = [self.cachedArticles objectForKey:articleGuid];

    if (existingArticle == nil)
    {
        if ([guidHistory containsObject:articleGuid])
            return NO; // Article has been deleted and removed from database, so ignore
        else
        {
            // add the article as new
            BOOL success = [[Database sharedManager] addArticle:article toFolder:self.itemId];
            if(success)
            {
                article.status = ArticleStatusNew;
                // add to the cache
                NSString * guid = article.guid;
	            [self.cachedArticles setObject:article forKey:[NSString stringWithString:guid]];
	            [self.cachedGuids addObject:guid];
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
        BOOL success = [[Database sharedManager] updateArticle:existingArticle ofFolder:self.itemId withArticle:article];
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
    NSAssert1(count >= 0, @"Attempting to set a negative unread count on folder %@", [self name]);
    unreadCount = count;
}

/* setChildUnreadCount
 * Update a separate count of the total number of unread articles
 * in all child folders.
 */
-(void)setChildUnreadCount:(NSInteger)count
{
    NSAssert1(count >= 0, @"Attempting to set a negative unread count on folder %@", [self name]);
    childUnreadCount = count;
}

/* clearCache
 * Empty the folder's cache of article.
 */
-(void)clearCache
{
    @synchronized(self)
    {
		[self.cachedArticles removeAllObjects];
		[self.cachedGuids removeAllObjects];
		self.isCached = NO;
		self.containsBodies = NO;
	}
}

/* removeArticleFromCache
 * Remove the article identified by the specified GUID from the cache.
 */
-(void)removeArticleFromCache:(NSString *)guid
{
    @synchronized(self)
    {
        NSAssert(self.isCached, @"Folder's cache of articles should be initialized before removeArticleFromCache can be used");
        [self.cachedArticles removeObjectForKey:guid];
        [self.cachedGuids removeObject:guid];
    }
}

/* restoreArticleToCache
 * Re-add an article to the cache (useful for unmarking article as deleted).
 */
-(void)restoreArticleToCache:(Article *)article
{
    @synchronized(self)
    {
        NSString * guid = article.guid;
        [self.cachedArticles setObject:article forKey:[NSString stringWithString:guid]];
        [self.cachedGuids addObject:guid];
        // note if article has incomplete data
        if (article.createdDate == nil)
        {
            self.containsBodies = NO;
        }
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
	return self.isCached ? (NSInteger)self.cachedGuids.count : -1;
}

/* ensureCache
 * Prepare the cache if it is not yet ready
 */
 -(void)ensureCache
 {
    if (!self.isCached)
    {
        NSArray * myArray = [[Database sharedManager] minimalCacheForFolder:self.itemId];
        for (Article * myArticle in myArray)
        {
            NSString * guid = myArticle.guid;
            [self.cachedArticles setObject:myArticle forKey:[NSString stringWithString:guid]];
            [self.cachedGuids addObject:guid];
        }
        self.isCached = YES;
        // Note that this only builds a minimal cache, so we cannot set the containsBodies flag
        // Note also that articles' statuses are left at the default value (0) which is ArticleStatusEmpty
    }
}

/* articles
 * Return an array of all articles in the specified folder.
 */
-(NSArray<Article *> *)articles
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
    for (id obj in self.cachedGuids.reverseObjectEnumerator.allObjects)
    {
        Article * article = [self.cachedArticles objectForKey:(NSString *)obj];
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
    if (self.isCached)
    {
        NSInteger count = unreadCount;
        NSMutableArray * result = [NSMutableArray arrayWithCapacity:unreadCount];
        for (id obj in self.cachedGuids.reverseObjectEnumerator.allObjects)
        {
            Article * article = [self.cachedArticles objectForKey:(NSString *)obj];
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
        return [[Database sharedManager] arrayOfUnreadArticlesRefs:self.itemId];
  } // synchronized
}

/*! Get an array of filtered articles in the current
 * @return Array of filtered articles in the current
 */
-(NSArray<Article *> *)articlesWithFilter:(NSString *)filterString
{
	if ([filterString isEqualToString:@""])
	{
		if (self.type == VNAFolderTypeGroup) {
			NSMutableArray * articles = [NSMutableArray array];
			NSArray * subFolders = [[Database sharedManager] arrayOfFolders:self.itemId];
			for (Folder * folder in subFolders) {
                [articles addObjectsFromArray:[folder articlesWithFilter:filterString]];
			}
			return [articles copy];
		}
		@synchronized(self) {
            if (self.isCached && self.containsBodies)
            {
                self.cachedArticles.evictsObjectsWithDiscardedContent = NO;
                NSMutableArray * articles = [NSMutableArray arrayWithCapacity:self.cachedGuids.count];
                for (id object in self.cachedGuids)
                {
                    Article * theArticle = [self.cachedArticles objectForKey:object];
                    if (theArticle != nil) {
                        [articles addObject:theArticle];
                    }
                    else
                    {   // some problem
                        NSLog(@"Bug retrieving from cache in folder %li : after %lu insertions of %lu, guid %@",(long)self.itemId, (unsigned long)articles.count,(unsigned long)self.cachedGuids.count,object);
                        self.isCached = NO;
                        self.containsBodies = NO;
                        break;
                    }
                }
                self.cachedArticles.evictsObjectsWithDiscardedContent = YES;
                return [articles copy];
            }
            else
            {
                NSArray * articles = [[Database sharedManager] arrayOfArticles:self.itemId filterString:filterString];
                // Only feeds folders can be cached, as they are the only ones to guarantee
                // bijection : one article <-> one guid
                if (self.type == VNAFolderTypeRSS || self.type == VNAFolderTypeOpenReader) {
                    self.isCached = NO;
                    self.containsBodies = NO;
                    [self.cachedArticles removeAllObjects];
                    [self.cachedGuids removeAllObjects];
                    for (id object in articles)
                    {
                        NSString * guid = ((Article *)object).guid;
                        [self.cachedArticles setObject:object forKey:[NSString stringWithString:guid]];
                        [self.cachedGuids addObject:guid];
                    }
                    self.isCached = YES;
                    self.containsBodies = YES;
                }
                return articles;
            }
        } // synchronized
	}
    else {
	    return [[Database sharedManager] arrayOfArticles:self.itemId filterString:filterString];
    }
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
	if (self.type == VNAFolderTypeRSS) {
		NSString * feedSourceFileName = [NSString stringWithFormat:@"folder%li.xml", (long)self.itemId];
		feedSourceFilePath = [[Preferences standardPreferences].feedSourcesFolder stringByAppendingPathComponent:feedSourceFileName];
	}
	return feedSourceFilePath;
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
	return [NSString stringWithFormat:@"Folder id %li (%@)", (long)self.itemId, self.name];
}

#pragma mark NSCacheDelegate
-(void)cache:(NSCache *)cache willEvictObject:(id)obj
{
    @synchronized(self)
    {
        Article * theArticle = ((Article *)obj);
        NSString * guid = theArticle.guid;
        if (self.isCached && !theArticle.isDeleted)
        {
            self.isCached = NO;
            self.containsBodies = NO;
        }
        [self.cachedGuids removeObject:guid];
    }
}
@end
