//
//  ActivityLog.m
//  Vienna
//
//  Created by Steve on 6/21/05.
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

#import "ActivityLog.h"
#import "Database.h"

@implementation ActivityItem

/* init
 * Initialise a new ActivityItem object
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		[self setName:@""];
		[self setStatus:@""];
		details = nil;
	}
	return self;
}

/* name
 * Returns the object source name.
 */
-(NSString *)name
{
	return name;
}

/* status
 * Returns the object source status
 */
-(NSString *)status
{
	return status;
}

/* setName
 * Sets the source name
 */
-(void)setName:(NSString *)aName
{
	name = aName;
}

/* setStatus
 * Sets the item status.
 */
-(void)setStatus:(NSString *)aStatus
{
	status = aStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ActivityLogChange" object:self];
}

/* clearDetails
 * Empties the details log for this item.
 */
-(void)clearDetails
{
	[details removeAllObjects];
}

/* appendDetail
 * Appends the specified text string to the details for this item.
 */
-(void)appendDetail:(NSString *)aString
{
	if (details == nil)
		details = [[NSMutableArray alloc] init];
	[details addObject:aString];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ActivityDetailChange" object:self];
}

/* details
 * Returns all details for this item. Caution: the return value
 * may be nil if the item has no initialised details.
 */
-(NSString *)details
{
	NSMutableString * detailString = [NSMutableString stringWithString:@""];
	if (details != nil)
	{
		for (NSString * aString in details)
		{
			[detailString appendString:aString];
			[detailString appendString:@"\n"];
		}
	}
	return detailString;
}

/* description
 * Return item description for debugging.
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"{'%@', '%@'}", name, status];
}

/* dealloc
 * Clean up before we expire.
 */
-(void)dealloc
{
	details=nil;
	status=nil;
	name=nil;
}
@end

@implementation ActivityLog

/* defaultLog
 * Return the default log singleton.
 */
+(ActivityLog *)defaultLog
{
	// Singleton
	static ActivityLog * defaultActivityLog = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		defaultActivityLog = [[ActivityLog alloc] init];
	});
	return defaultActivityLog;
}

/* init
 * Initialise a new log instance.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		log = [[NSMutableArray alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillDeleteFolder:) name:@"MA_Notify_WillDeleteFolder" object:nil];
	}
	return self;
}

/* handleWillDeleteFolder
 * Trap the notification that the specified folder is about to be deleted.
 */
-(void)handleWillDeleteFolder:(NSNotification *)nc
{
	Folder * folder = [[Database sharedManager] folderFromID:[[nc object] intValue]];
	ActivityItem * item = [self itemByName:[folder name]];
	[log removeObject:item];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ActivityLogChange" object:nil];
}

/* getStatus
 * Retrieves the status item in the array corresponding to the source name. On
 * return, indexPointer is the index of the item or the index of the item just
 * where the status item should be if it was found.
 */
-(ActivityItem *)getStatus:(NSString *)name index:(int *)indexPointer
{
	int indexOfItem = 0;
	ActivityItem * item;

	for (item in log)
	{
		if ([[item name] caseInsensitiveCompare:name] == NSOrderedSame)
			break;
		++indexOfItem;
	}
	*indexPointer = indexOfItem;
	return item;
}

/* itemByName
 * Returns the ActivityItem that corresponds to the specified name. If one doesn't
 * exist then it is created.
 */
-(ActivityItem *)itemByName:(NSString *)theName
{
	ActivityItem * item;
	int insertionIndex;

	if ((item = [self getStatus:theName index:&insertionIndex]) == nil)
	{
		item = [[ActivityItem alloc] init];
		[item setName:theName];
		[log insertObject:item atIndex:insertionIndex];
		
		item = [log objectAtIndex:insertionIndex];
	}
	return item;
}

/* sortUsingDescriptors
 * Sort the log using the specified descriptors.
 */
-(void)sortUsingDescriptors:(NSArray *)sortDescriptors
{
	[log sortUsingDescriptors:sortDescriptors];
}

/* allItems
 * Return a copy of all items in the log.
 */
-(NSArray *)allItems
{
	return log;
}

/* dealloc
 * Clean up after ourself.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	log=nil;
}
@end
