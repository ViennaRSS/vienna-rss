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
#import "Preferences.h"
#import "StringExtensions.h"
#import "KeyChain.h"

// Indexes into folder image array
enum {
	MA_FolderIcon = 0,
	MA_SmartFolderIcon,
	MA_RSSFolderIcon,
	MA_RSSFeedIcon,
	MA_TrashFolderIcon,
	MA_SearchFolderIcon,
	MA_Max_Icons
};

// Folder image cache interface. This is exclusive to the
// folder code and only used privately.
@interface FolderImageCache : NSObject {
	NSString * imagesCacheFolder;
	NSMutableDictionary * folderImagesArray;
	BOOL initializedFolderImagesArray;
}

// Accessor functions
+(FolderImageCache *)defaultCache;
-(void)addImage:(NSImage *)image forURL:(NSString *)baseURL;
-(NSImage *)retrieveImage:(NSString *)baseURL;

// Support functions
-(void)initFolderImagesArray;
@end

// Static pointers
static FolderImageCache * _folderImageCache = nil;
static NSArray * iconArray = nil;

// Private internal functions
@interface Folder (Private)
	+(NSArray *)_iconArray;
@end

@implementation FolderImageCache

/* defaultCache
 * Returns a pointer to the default cache. There is just one default cache
 * and we instantiate it if it doesn't exist.
 */
+(FolderImageCache *)defaultCache
{
	if (_folderImageCache == nil)
		_folderImageCache = [[FolderImageCache alloc] init];
	return _folderImageCache;
}

/* init
 * Init an instance of the folder image cache.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		imagesCacheFolder = nil;
		initializedFolderImagesArray = NO;
		folderImagesArray = [[NSMutableDictionary alloc] init];
	}
	return self;
}

/* addImage
 * Add the specified image to the cache and save it to disk.
 */
-(void)addImage:(NSImage *)image forURL:(NSString *)baseURL
{
	// Add in memory
	[self initFolderImagesArray];
	[folderImagesArray setObject:image forKey:baseURL];

	// Save icon to disk here.
	if (imagesCacheFolder != nil)
	{
		NSString * fullFilePath = [[imagesCacheFolder stringByAppendingPathComponent:baseURL] stringByAppendingPathExtension:@"tiff"];
		NSData *imageData = nil;
		NS_DURING
			imageData = [image TIFFRepresentation];
		NS_HANDLER
			imageData = nil;
			NSLog(@"tiff exception with %@", fullFilePath);
		NS_ENDHANDLER
		if (imageData != nil)
			[[NSFileManager defaultManager] createFileAtPath:fullFilePath contents:imageData attributes:nil];
	}
}

/* retrieveImage
 * Retrieve the image for the specified URL from the cache.
 */
-(NSImage *)retrieveImage:(NSString *)baseURL
{
	[self initFolderImagesArray];
	return [folderImagesArray objectForKey:baseURL];
}

/* initFolderImagesArray
 * Load the existing list of folder images from the designated folder image cache. We
 * do this only once and we do it as quickly as possible. When we're done, the folderImagesArray
 * will be filled with image representations for each valid image file we find in the cache.
 */
-(void)initFolderImagesArray
{
	if (!initializedFolderImagesArray)
	{
		NSFileManager * fileManager = [NSFileManager defaultManager];
		NSArray * listOfFiles;
		BOOL isDir;
		
		// Get and cache the path to the folder. This is the best time to make sure it
		// exists. The penalty for it not existing AND us being unable to create it is that
		// we don't cache folder icons in this session.
		imagesCacheFolder = [[Preferences standardPreferences] imagesFolder];
		if (![fileManager fileExistsAtPath:imagesCacheFolder isDirectory:&isDir])
		{
			if (![fileManager createDirectoryAtPath:imagesCacheFolder attributes:NULL])
			{
				NSLog(@"Cannot create image cache at %@. Will not cache folder images in this session.", imagesCacheFolder);
				imagesCacheFolder = nil;
			}
			initializedFolderImagesArray = YES;
			return;
		}
		
		if (!isDir)
		{
			NSLog(@"The file at %@ is not a directory. Will not cache folder images in this session.", imagesCacheFolder);
			[imagesCacheFolder release];
			imagesCacheFolder = nil;
			initializedFolderImagesArray = YES;
			return;
		}
		
		// Remember - not every file we find may be a valid image file. We use the filename as
		// the key but check the extension too.
		listOfFiles = [fileManager directoryContentsAtPath:imagesCacheFolder];
		if (listOfFiles != nil)
		{
			NSEnumerator * enumerator = [listOfFiles objectEnumerator];
			NSString * fileName;
			
			while ((fileName = [enumerator nextObject]) != nil)
			{
				if ([[fileName pathExtension] isEqualToString:@"tiff"])
				{
					NSString * fullPath = [imagesCacheFolder stringByAppendingPathComponent:fileName];
					NSData * imageData = [fileManager contentsAtPath:fullPath];
					NSImage * iconImage = [[NSImage alloc] initWithData:imageData];
					if ([iconImage isValid])
					{
						[iconImage setScalesWhenResized:YES];
						[iconImage setSize:NSMakeSize(16, 16)];
						NSString * homePageSiteRoot = [[[fullPath lastPathComponent] stringByDeletingPathExtension] convertStringToValidPath];
						[folderImagesArray setObject:iconImage forKey:homePageSiteRoot];
					}
					[iconImage release];
				}
			}
		}
		initializedFolderImagesArray = YES;
	}
}

/* dealloc
 * Clean up.
 */
-(void)dealloc
{
	[folderImagesArray release];
	[super dealloc];
}
@end

@implementation Folder

/* initWithId
 * Initialise a new folder object instance.
 */
-(id)initWithId:(int)newId parentId:(int)newIdParent name:(NSString *)newName type:(int)newType
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
		hasPassword = NO;
		cachedArticles = [[NSMutableDictionary dictionary] retain];
		attributes = [[NSMutableDictionary dictionary] retain];
		[self setName:newName];
		[self setLastUpdate:[NSDate distantPast]];
		[self setLastUpdateString:@""];
		[self setUsername:@""];
		[self setBloglinesId:MA_NonBloglines_Folder];
	}
	return self;
}

/* _iconArray
 * Return the internal array of pre-defined folder images
 */
+(NSArray *)_iconArray
{
	if (iconArray == nil)
		iconArray = [[NSArray arrayWithObjects:
						[NSImage imageNamed:@"smallFolder.tiff"],
						[NSImage imageNamed:@"smartFolder.tiff"],
						[NSImage imageNamed:@"rssFolder.tiff"],
						[NSImage imageNamed:@"rssFeedNew.tiff"],
						[NSImage imageNamed:@"trashFolder.tiff"],
						[NSImage imageNamed:@"searchFolder.tiff"],
						nil] retain];
	return iconArray;
}

/* itemId
 * Returns the folder's ID.
 */
-(int)itemId
{
	return itemId;
}

/* parentId
 * Returns this folder's parent ID.
 */
-(int)parentId
{
	return parentId;
}

/* nextSiblingId
 * Returns the ID of the folder's next sibling.
 */
-(int)nextSiblingId
{
	return nextSiblingId;
}

/* nextSiblingId
 * Returns the ID of the folder's first child.
 */
-(int)firstChildId
{
	return firstChildId;
}

/* unreadCount
 */
-(int)unreadCount
{
	return unreadCount;
}

/* type
 */
-(int)type
{
	return type;
}

/* flags
 */
-(unsigned int)flags
{
	return flags;
}

/* nonPersistedFlags
 */
-(unsigned int)nonPersistedFlags
{
	return nonPersistedFlags;
}

/* childUnreadCount
 */
-(int)childUnreadCount
{
	return childUnreadCount;
}

/* attributes
 * Return the folder attributes.
 */
-(NSDictionary *)attributes
{
	return attributes;
}

/* feedDescription
 * Returns the feed's description.
 */
-(NSString *)feedDescription
{
	return SafeString([attributes valueForKey:@"FeedDescription"]);
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
		return [[Folder _iconArray] objectAtIndex:MA_RSSFolderIcon];
	if (IsSmartFolder(self))
		return [[Folder _iconArray] objectAtIndex:MA_SmartFolderIcon];
	if (IsTrashFolder(self))
		return [[Folder _iconArray] objectAtIndex:MA_TrashFolderIcon];
	if (IsSearchFolder(self))
		return [[Folder _iconArray] objectAtIndex:MA_SearchFolderIcon];
	if (IsRSSFolder(self))
	{
		// Try the folder icon cache.
		NSImage * imagePtr = nil;
		if ([self feedURL])
		{
			NSString * homePageSiteRoot = [[[self homePage] baseURL] convertStringToValidPath];
			imagePtr = [[FolderImageCache defaultCache] retrieveImage:homePageSiteRoot];
		}
		return (imagePtr) ? imagePtr : [[Folder _iconArray] objectAtIndex:MA_RSSFeedIcon];
	}
	
	// Use the generic folder icon for anything else
	return [[Folder _iconArray] objectAtIndex:MA_FolderIcon];
}

/* hasCachedImage
 * Returns YES if the folder has an image stored in the cache.
 */
-(BOOL)hasCachedImage
{
	if (!IsRSSFolder(self))
		return NO;
	NSImage * imagePtr = nil;
	if ([self feedURL])
	{
		NSString * homePageSiteRoot = [[[self homePage] baseURL] convertStringToValidPath];
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
		return [[Folder _iconArray] objectAtIndex:MA_RSSFeedIcon];
	return [self image];
}

/* setImage
 * Used to set the image for a folder in the array. The image is cached for this session
 * and also written to the image folder if there is a valid one.
 */
-(void)setImage:(NSImage *)iconImage
{
	if ([self feedURL] != nil && iconImage != nil)
	{
		NSString * homePageSiteRoot = [[[self homePage] baseURL] convertStringToValidPath];
		[[FolderImageCache defaultCache] addImage:iconImage forURL:homePageSiteRoot];
	}
}

/* setFeedDescription
 * Sets the folder feed description.
 */
-(void)setFeedDescription:(NSString *)newFeedDescription
{
	[attributes setValue:newFeedDescription forKey:@"FeedDescription"];
}

/* setHomePage
 * Sets the folder's home page URL.
 */
-(void)setHomePage:(NSString *)newHomePage
{
	[attributes setValue:newHomePage forKey:@"HomePage"];
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
		if ([self username] != nil && [self feedURL] != nil)
			[attributes setValue:[KeyChain getPasswordFromKeychain:[self username] url:[self feedURL]] forKey:@"Password"];
		hasPassword = YES;
	}
	return [attributes valueForKey:@"Password"];
}

/* setPassword
 * Sets the password associated with this feed.
 */
-(void)setPassword:(NSString *)newPassword
{
	if ([self username] != nil && [self feedURL] != nil)
		[KeyChain setPasswordInKeychain:newPassword username:[self username] url:[self feedURL]];
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
	[newLastUpdate retain];
	[lastUpdate release];
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

/* bloglinesId
 * Returns the Bloglines ID associated with this folder.
 */
-(long)bloglinesId
{
	return [[attributes valueForKey:@"BloglinesID"] longValue];
}

/* setBloglinesId
 * Sets the Bloglines ID associated with this folder. The special constant MA_NonBloglines_Folder
 * can be used to de-associate it with Bloglines.
 */
-(void)setBloglinesId:(long)newBloglinesId
{
	[attributes setValue:[NSNumber numberWithLong:newBloglinesId] forKey:@"BloglinesID"];
}

/* setType
 * Changes the folder type
 */
-(void)setType:(int)newType
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

/* setFlag
 * Set the specified flag on the folder.
 */
-(void)setFlag:(unsigned int)flagToSet
{
	flags |= flagToSet;
}

/* clearFlag
 * Clears the specified flag on the folder.
 */
-(void)clearFlag:(unsigned int)flagToClear
{
	flags &= ~flagToClear;
}

/* setNonPersistedFlag
 * Set the specified flag on the folder.
 */
-(void)setNonPersistedFlag:(unsigned int)flagToSet
{
	nonPersistedFlags |= flagToSet;
}

/* clearNonPersistedFlag
 * Clears the specified flag on the folder.
 */
-(void)clearNonPersistedFlag:(unsigned int)flagToClear
{
	nonPersistedFlags &= ~flagToClear;
}

/* setParent
 * Re-parent the folder.
 */
-(void)setParent:(int)newParent
{
	parentId = newParent;
}

/* setNextSiblingId
 * Set the ID for the folder's next sibling.
 */
-(void)setNextSiblingId:(int)newNextSibling
{
	nextSiblingId = newNextSibling;
}

/* setFirstChildId
 * Set the ID for the folder's first child.
 */
-(void)setFirstChildId:(int)newFirstChild;
{
	firstChildId = newFirstChild;
}

/* indexOfArticle
 * Returns the index of the article that matches the specified article based on guid.
 */
-(unsigned)indexOfArticle:(Article *)article
{
	NSArray * cacheArray = [self articles];
	Article * realArticle = [cachedArticles objectForKey:[article guid]];
	return [cacheArray indexOfObjectIdenticalTo:realArticle];
}

/* articleFromGuid
 */
-(Article *)articleFromGuid:(NSString *)guid
{
	NSAssert(isCached, @"Folder's cache of articles should be initialized before articleFromGuid can be used");
	return [cachedArticles objectForKey:guid];
}

/* setUnreadCount
 */
-(void)setUnreadCount:(int)count
{
	NSAssert1(count >= 0, @"Attempting to set a negative unread count on folder %@", [self name]);
	unreadCount = count;
}

/* setChildUnreadCount
 * Update a separate count of the total number of unread articles
 * in all child folders.
 */
-(void)setChildUnreadCount:(int)count
{
	NSAssert1(count >= 0, @"Attempting to set a negative unread count on folder %@", [self name]);
	childUnreadCount = count;
}

/* clearCache
 * Empty the folder's cache of article.
 */
-(void)clearCache
{
	[cachedArticles removeAllObjects];
	isCached = NO;
}

/* addArticleToCache
 * Add the specified article to our cache, replacing any existing instance.
 */
-(void)addArticleToCache:(Article *)newArticle
{
	[cachedArticles setObject:newArticle forKey:[newArticle guid]];
	isCached = YES;
}

/* removeArticleFromCache
 * Remove the article identified by the specified GUID from the cache.
 */
-(void)removeArticleFromCache:(NSString *)guid
{
	NSAssert(isCached, @"Folder's cache of articles should be initialized before removeArticleFromCache can be used");
	[cachedArticles removeObjectForKey:guid];
}

/* markFolderEmpty
 * Mark this folder as empty on the service
 */
-(void)markFolderEmpty
{
	isCached = YES;
}

/* countOfCachedArticles
 * Return the number of articles in our cache, or -1 if the cache is empty.
 * (Note: empty is not the same as a folder with zero articles. The semantics are
 * important here since we could potentially keep trying to recache an folder that
 * truly has zero articles otherwise).
 */
-(int)countOfCachedArticles
{
	return isCached ? (int)[cachedArticles count] : -1;
}

/* articles
 * Return an array of all articles in the specified folder.
 */
-(NSArray *)articles
{
	if (!isCached)
		[[Database sharedDatabase] arrayOfArticles:itemId filterString:nil];
	return [cachedArticles allValues];
}

/* articlesWithFilter
 * Return an array of filtered articles in the specified folder.
 */
-(NSArray *)articlesWithFilter:(NSString *)fstring
{
	return [[Database sharedDatabase] arrayOfArticles:itemId filterString:fstring];
}

/* folderNameCompare
 * Returns the result of comparing two folders by folder name.
 */
-(NSComparisonResult)folderNameCompare:(Folder *)otherObject
{
	return [[self name] caseInsensitiveCompare:[otherObject name]];
}

/* folderIDCompare
 * Returns the result of comparing two folders by folder ID.
 */
-(NSComparisonResult)folderIDCompare:(Folder *)otherObject
{
	if ([self itemId] > [otherObject itemId]) return NSOrderedAscending;
	if ([self itemId] < [otherObject itemId]) return NSOrderedDescending;
	return NSOrderedSame;
}

/* objectSpecifier
 * Return an NSScriptObjectSpecifier object representing this folder.
 */
-(NSScriptObjectSpecifier *)objectSpecifier
{
	NSArray * folders = [[NSApp delegate] folders];
	unsigned index = [folders indexOfObjectIdenticalTo:self];
	if (index != NSNotFound)
	{
		NSScriptObjectSpecifier *containerRef = [[NSApp delegate] objectSpecifier];
		return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:(NSScriptClassDescription *)[NSApp classDescription] containerSpecifier:containerRef key:@"folders" index:index] autorelease];
	}
	return nil;
}

/* description
 * Return a description of the folder.
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"Folder id %d (%@)", itemId, [self name]];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[lastUpdate release];
	[attributes release];
	[cachedArticles release];
	[super dealloc];
}
@end
