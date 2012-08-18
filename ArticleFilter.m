//
//  ArticleFilter.m
//  Vienna
//
//  Created by Steve on 3/24/06.
//  Copyright (c) 2004-2006 Steve Palmer. All rights reserved.
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

#import "ArticleFilter.h"
#import "CalendarExtensions.h"
#import "Preferences.h"
#import "Constants.h"
#import "Message.h"

@interface ArticleFilter (Private)
+(void)createFilter:(NSString *)name tag:(NSInteger)tag comparator:(SEL)comparator;
@end

// There's just one global filter list.
static NSMutableArray * _filterList = nil;

@implementation ArticleFilter

/* unreadArticleFilterComparator
 * Returns TRUE if the specified article is unread.
 */
+(BOOL)unreadArticleFilterComparator:(Article *)theArticle
{
	return ![theArticle isRead];
}

/* flaggedArticleFilterComparator
 * Returns TRUE if the specified article is flagged.
 */
+(BOOL)flaggedArticleFilterComparator:(Article *)theArticle
{
	return [theArticle isFlagged];
}

/* todayFilterComparator
 * Returns TRUE if the specified article was posted today.
 */
+(BOOL)todayFilterComparator:(Article *)theArticle
{
	return ([[theArticle date] compare:[NSCalendarDate today]] != NSOrderedAscending);
}

/* lastRefreshFilterComparator
 * Returns TRUE if the specified article is the same as or newer than the last refresh date.
 */
+(BOOL)lastRefreshFilterComparator:(Article *)theArticle
{
	return ([[theArticle createdDate] compare:[[Preferences standardPreferences] objectForKey:MAPref_LastRefreshDate]] != NSOrderedAscending);
}

/* initalize
 * Create all the default filters. To add a new filter:
 *
 * 1. Add an unique tag ID for the filter in constants.h (MA_Filter_xxx).
 * 2. Add a comparator in this file that returns TRUE if the article should be filtered IN.
 * 3. Add a new line below with the filter name, tag and comparator.
 * 4. Localise the filter name in the Localizable.strings for each language.
 *
 * That's it really. The filtering and menu is handled automatically.
 */
+(void)initialize
{
	[ArticleFilter createFilter:@"All Articles" tag:MA_Filter_All comparator:nil];
	[ArticleFilter createFilter:@"Unread Articles" tag:MA_Filter_Unread comparator:@selector(unreadArticleFilterComparator:)];
	[ArticleFilter createFilter:@"Last Refresh" tag:MA_Filter_LastRefresh comparator:@selector(lastRefreshFilterComparator:)];
	[ArticleFilter createFilter:@"Today" tag:MA_Filter_Today comparator:@selector(todayFilterComparator:)];
	[ArticleFilter createFilter:@"Flagged" tag:MA_Filter_Flagged comparator:@selector(flaggedArticleFilterComparator:)];
}

/* arrayOfFilters
 * Return the array of filters.
 */
+(NSArray *)arrayOfFilters
{
	return _filterList;
}

/* filterByTag
 * Returns the filter identified by the specified tag or nil if there's no filter
 * with the given tag.
 */
+(ArticleFilter *)filterByTag:(NSInteger)theTag
{
	NSInteger index;
	for (index = 0; index < [_filterList count]; ++index)
	{
		ArticleFilter * filter = [_filterList objectAtIndex:index];
		if ([filter tag] == theTag)
			return filter;
	}
	return nil;
}

/* initWithName
 * This is the designated initialiser for a new ArticleFilter object.
 */
-(id)initWithName:(NSString *)theName tag:(NSInteger)theTag comparator:(SEL)theComparator
{
	if ((self = [super init]) != nil)
	{
		name = [theName retain];
		tag = theTag;
		comparator = theComparator;
	}
	return self;
}

/* name
 * Return the filter name.
 */
-(NSString *)name
{
	return name;
}

/* comparator
 * Return the filter comparator function.
 */
-(SEL)comparator
{
	return comparator;
}

/* tag
 * Return the filter's unique ID (tag)
 */
-(NSInteger)tag
{
	return tag;
}

/* createFilter
 * Create a new article filter with the specified name and comparator.
 */
+(void)createFilter:(NSString *)name tag:(NSInteger)tag comparator:(SEL)comparator
{
	ArticleFilter * newFilter = [[ArticleFilter alloc] initWithName:name tag:tag comparator:comparator];
	if (_filterList == nil)
		_filterList = [[NSMutableArray alloc] init];
	[_filterList addObject:newFilter];
	[newFilter release];
}

/* dealloc
 * Clean up behind us.
 */
-(void)dealloc
{
	[name release];
	[super dealloc];
}
@end
