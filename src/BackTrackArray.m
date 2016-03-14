//
//  BackTrackArray.m
//  Vienna
//
//  Created by Steve on Fri Mar 12 2004.
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

#import "BackTrackArray.h"
#import "ArticleRef.h"

@implementation BackTrackArray

/* initWithMaximum
 * Initialises a new BackTrackArray with the specified maximum number of
 * items.
 */
-(instancetype)initWithMaximum:(NSUInteger )theMax
{
	if ((self = [super init]) != nil)
	{
		maxItems = theMax;
		queueIndex = -1;
		array = [[NSMutableArray alloc] initWithCapacity:maxItems];
	}
	return self;
}

/* isAtStartOfQueue
 * Returns YES if we're at the start of the queue.
 */
-(BOOL)isAtStartOfQueue
{
	return queueIndex <= 0;
}

/* isAtEndOfQueue
 * Returns YES if we're at the end of the queue.
 */
-(BOOL)isAtEndOfQueue
{
	return queueIndex >= (NSInteger)array.count - 1;
}

/* previousItemAtQueue
 * Removes an item from the tail of the queue as long as the queue is not
 * empty and returns the backtrack data.
 */
-(BOOL)previousItemAtQueue:(NSInteger *)folderId guidPointer:(NSString **)guidPointer
{
	if (queueIndex > 0)
	{
		ArticleReference * item = array[--queueIndex];
		*folderId = [item folderId];
		*guidPointer = [item guid];
		return YES;
	}
	return NO;
}

/* nextItemAtQueue
 * Removes an item from the tail of the queue as long as the queue is not
 * empty and returns the backtrack data.
 */
-(BOOL)nextItemAtQueue:(NSInteger *)folderId guidPointer:(NSString **)guidPointer
{
	if (queueIndex < (NSInteger)array.count - 1)
	{
		ArticleReference * item = array[++queueIndex];
		*folderId = [item folderId];
		*guidPointer = [item guid];
		return YES;
	}
	return NO;
}

/* addToQueue
 * Adds an item to the queue. The new item is added at queueIndex
 * which is the most recent position to which the user has tracked
 * (usually the end of the array if no tracking has occurred). If
 * queueIndex is in the middle of the array, we remove all items
 * to the right (from queueIndex+1 onwards) in order to define a
 * new 'head' position. This produces the expected results when tracking
 * from the new item inserted back to the most recent item.
 */
-(void)addToQueue:(NSInteger)folderId guid:(NSString *)guid
{
	while (queueIndex + 1 < (NSInteger)array.count)
		[array removeObjectAtIndex:queueIndex + 1];
	if (array.count == maxItems)
	{
		[array removeObjectAtIndex:0];
		--queueIndex;
	}
	if (array.count > 0)
	{
		ArticleReference * item = array[array.count - 1];
		if ([[item guid] isEqualToString:guid] && [item folderId] == folderId)
			return;
	}
	[array addObject:[ArticleReference makeReferenceFromGUID:guid inFolder:folderId]];
	++queueIndex;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	array=nil;
}
@end
