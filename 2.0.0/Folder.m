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
#import "StringExtensions.h"

// Indexes into folder image array
enum {
	MA_FolderIcon = 0,
	MA_SmartFolderIcon,
	MA_RSSFolderIcon,
	MA_RSSFeedIcon,
	MA_TrashFolderIcon,
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
		NSData * imageData = [image TIFFRepresentationUsingCompression: NSTIFFCompressionLZW factor:1.0];
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
		imagesCacheFolder = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_FolderImagesFolder];
		imagesCacheFolder = [[imagesCacheFolder stringByExpandingTildeInPath] retain];
		if (![fileManager fileExistsAtPath:imagesCacheFolder isDirectory:&isDir])
		{
			if (![fileManager createDirectoryAtPath:imagesCacheFolder attributes:NULL])
			{
				[imagesCacheFolder release];
				imagesCacheFolder = nil;
			}
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
	[imagesCacheFolder release];
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
		unreadCount = 0;
		childUnreadCount = 0;
		type = newType;
		flags = 0;
		needFlush = NO;
		isMessages = NO;
		messages = [[NSMutableDictionary dictionary] retain];
		attributes = [[NSMutableDictionary dictionary] retain];
		[self setName:newName];
		[self setLastUpdate:[NSDate distantPast]];
		[self setLastUpdateString:@""];
		[self setUsername:@""];
		[self setPassword:@""];
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
						[NSImage imageNamed:@"searchFolder.tiff"],
						[NSImage imageNamed:@"rssFolder.tiff"],
						[NSImage imageNamed:@"rssFeed.tiff"],
						[NSImage imageNamed:@"trashFolder.tiff"],
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

/* description
 * Returns the folder description.
 */
-(NSString *)description
{
	return [attributes valueForKey:@"Description"];
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
	if (IsRSSFolder(self))
	{
		// Try the folder icon cache.
		NSImage * imagePtr = nil;
		if ([self feedURL])
		{
			NSString * homePageSiteRoot = [[[self feedURL] baseURL] convertStringToValidPath];
			imagePtr = [[FolderImageCache defaultCache] retrieveImage:homePageSiteRoot];
		}
		return (imagePtr) ? imagePtr : [[Folder _iconArray] objectAtIndex:MA_RSSFeedIcon];
	}
	
	// Use the generic folder icon for anything else
	return [[Folder _iconArray] objectAtIndex:MA_FolderIcon];
}

/* setImage
 * Used to set the image for a folder in the array. The image is cached for this session
 * and also written to the image folder if there is a valid one.
 */
-(void)setImage:(NSImage *)iconImage
{
	if ([self feedURL] != nil && iconImage != nil)
	{
		NSString * homePageSiteRoot = [[[self feedURL] baseURL] convertStringToValidPath];
		[[FolderImageCache defaultCache] addImage:iconImage forURL:homePageSiteRoot];
	}
}

/* setDescription
 * Sets the folder description.
 */
-(void)setDescription:(NSString *)newDescription
{
	[attributes setValue:newDescription forKey:@"Description"];
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
	return [attributes valueForKey:@"Password"];
}

/* setPassword
 * Sets the password associated with this feed.
 */
-(void)setPassword:(NSString *)newPassword
{
	[attributes setValue:newPassword forKey:@"Password"];
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
	needFlush = YES;
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
	needFlush = YES;
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

/* folderName
 * Returns the folder name. This is an alias for 'name' which
 * isn't acceptable to AppleScript.
 */
-(NSString *)folderName
{
	return [self name];
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

/* setFlag
 * Set the specified flag on the folder.
 */
-(void)setFlag:(unsigned int)flagToSet
{
	flags |= flagToSet;
	needFlush = YES;
}

/* clearFlag
 * Clears the specified flag on the folder.
 */
-(void)clearFlag:(unsigned int)flagToClear
{
	flags &= ~flagToClear;
	needFlush = YES;
}

/* setParent
 * Re-parent the folder.
 */
-(void)setParent:(int)newParent
{
	if (parentId != newParent)
	{
		parentId = newParent;
		needFlush = YES;
	}
}

/* messageFromGuid
 */
-(Message *)messageFromGuid:(NSString *)guid
{
	NSAssert(isMessages, @"Folder's cache of messages should be initialized before messageFromGuid can be used");
	return [messages objectForKey:guid];
}

/* articles
 */
-(NSArray *)articles
{
	return [messages allValues];
}

/* setUnreadCount
 */
-(void)setUnreadCount:(int)count
{
	NSAssert1(count >= 0, @"Attempting to set a negative unread count on folder %@", [self name]);
	if (unreadCount != count)
	{
		unreadCount = count;
		needFlush = YES;
	}
}

/* setChildUnreadCount
 * Update a separate count of the total number of unread messages
 * in all child folders.
 */
-(void)setChildUnreadCount:(int)count
{
	NSAssert1(count >= 0, @"Attempting to set a negative unread count on folder %@", [self name]);
	childUnreadCount = count;
}

/* needFlush
 * Return whether this folder needs to be committed.
 */
-(BOOL)needFlush
{
	return needFlush;
}

/* resetFlush
 * Mark changes in this folder as having been committed or thrown away.
 */
-(void)resetFlush
{
	needFlush = NO;
}

/* clearMessages
 * Empty the folder's array of messages.
 */
-(void)clearMessages
{
	[messages removeAllObjects];
	isMessages = NO;
}

/* addMessage
 */
-(void)addMessage:(Message *)newMessage
{
	[messages setObject:newMessage forKey:[newMessage guid]];
	isMessages = YES;
}

/* deleteMessage
 */
-(void)deleteMessage:(NSString *)guid
{
	NSAssert(isMessages, @"Folder's cache of messages should be initialized before deleteMessage can be used");
	[messages removeObjectForKey:guid];
}

/* markFolderEmpty
 * Mark this folder as empty on the service
 */
-(void)markFolderEmpty
{
	isMessages = YES;
}

/* messageCount
 */
-(int)messageCount
{
	return isMessages ? (int)[messages count] : -1;
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

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[lastUpdate release];
	[attributes release];
	[messages release];
	[super dealloc];
}
@end
