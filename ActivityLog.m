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

static ActivityLog * defaultActivityLog = nil;		// Singleton object

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
	[aName retain];
	[name release];
	name = aName;
}

/* setStatus
 * Sets the item status.
 */
-(void)setStatus:(NSString *)aStatus
{
	[aStatus retain];
	[status release];
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
		NSEnumerator * enumerator = [details objectEnumerator];
		NSString * aString;

		while ((aString = [enumerator nextObject]) != nil)
		{
			[detailString appendString:aString];
			[detailString appendString:@"\n"];
		}
	}
	return detailString;
}

/* dealloc
 * Clean up before we expire.
 */
-(void)dealloc
{
	[details release];
	[status release];
	[name release];
	[super dealloc];
}
@end

@implementation ActivityLog

/* defaultLog
 * Return the default log singleton.
 */
+(ActivityLog *)defaultLog
{
	if (defaultActivityLog == nil)
		defaultActivityLog = [[ActivityLog alloc] init];
	return defaultActivityLog;
}

/* init
 * Initialise a new log instance.
 */
-(id)init
{
	if ((self = [super init]) != nil)
		log = [[NSMutableArray alloc] init];
	return self;
}

/* getStatus
 * Retrieves the status item in the array corresponding to the source name. On
 * return, indexPointer is the index of the item or the index of the item just
 * where the status item should be if it was found.
 */
-(ActivityItem *)getStatus:(NSString *)name index:(int *)indexPointer
{
	NSEnumerator * enumerator = [log objectEnumerator];
	ActivityItem * item;
	int indexOfItem = 0;
	
	while ((item = [enumerator nextObject]) != nil)
	{
		int ordering = [[item name] caseInsensitiveCompare:name];
		if (ordering == NSOrderedSame)
		{
			*indexPointer = indexOfItem;
			return item;
		}
		else if (ordering == NSOrderedDescending)
			break;
		++indexOfItem;
	}
	*indexPointer = indexOfItem;
	return nil;
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
		[item release];
		
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

/* setStatus
 * Set a new status entry for the specified source item.
 */
-(void)setStatus:(NSString *)aStatusString forItem:(ActivityItem *)item
{
	[item setStatus:aStatusString];
}

/* clearDetails
 * Empties the details log for the specified source.
 */
-(void)clearDetails:(NSString *)theSource
{
	ActivityItem * item;
	int insertionIndex;
	
	if ((item = [self getStatus:theSource index:&insertionIndex]) != nil)
		[item clearDetails];
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
	[log release];
	[super dealloc];
}
@end
