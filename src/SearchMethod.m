//
//  SearchMethod.m
//  Vienna
//
//  Created by Michael on 19/02/10.
//  Copyright 2010 Michael G. Stroeck. All rights reserved.
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


#import "SearchMethod.h"
#import "HelperFunctions.h"
#import "AppController.h"

@implementation SearchMethod

/* init
 * Create an "empty" search method that will not do anything on its own.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		friendlyName = nil;
		searchQueryString = nil;
		handler = nil;
	}
	return self;
}

/* initWithDictionary:
 * Used to init fron a plugin's info.dict. This class is designed to be capable 
 * of doing different things with searches according to the plugin definition. 
 * At the moment, however, we only ever do a normal web-search.*/

-(id)initWithDictionary:(NSDictionary *)dict 
{
	if ((self = [super init]) != nil)
	{
		friendlyName = [dict valueForKey:@"FriendlyName"];
		searchQueryString = [dict valueForKey:@"SearchQueryString"];
		handler = @selector(performWebSearch:);
	}
	return self;
}

# pragma mark NSCoder Conformity

- (void)encodeWithCoder:(NSCoder *)coder; 
{
    [coder encodeObject:friendlyName forKey:@"friendlyName"];
	[coder encodeObject:searchQueryString forKey:@"searchQueryString"];
	[coder encodeValueOfObjCType:@encode(SEL) at:&handler];
}

- (id)initWithCoder:(NSCoder *)coder;
{
	if ((self = [super init]) != nil)
    {
		[self setFriendlyName:[coder decodeObjectForKey:@"friendlyName"]];
		[self setSearchQueryString:[coder decodeObjectForKey:@"searchQueryString"]];
		[coder decodeValueOfObjCType:@encode(SEL) at:&handler];
    }   
    return self;
}

# pragma mark Class Methods

/* builtInSearchMethods
 * Class method that returns all built-in SearchMethods. They are defined 
 * immediately below.If you add a new one, add it to the array. 
 * Remember: arrayWithObjects needs a "nil" termination.
 */
+(NSArray *)builtInSearchMethods
{
	return [NSArray arrayWithObjects: [SearchMethod searchAllArticlesMethod], [SearchMethod searchCurrentWebPageMethod], nil];
}

/* searchAllArticlesMethod
 * Class method that returns the standard SearchMethod "Search all Articles".
 */
+(SearchMethod *)searchAllArticlesMethod
{
	SearchMethod * method = [[SearchMethod alloc] init];
	[method setFriendlyName:@"Search all articles"];
	[method setHandler:@selector(performAllArticlesSearch)];
	
	return [method autorelease]; 
}

/* searchCurrentWebPageMethod
 * Class method that Returns a SearchMethod that only works when 
 * the active view is a web pane.
 */
+(SearchMethod *)searchCurrentWebPageMethod
{
	SearchMethod * method = [[SearchMethod alloc] init];
	[method setFriendlyName:@"Search current web page"];
	[method setHandler:@selector(performWebPageSearch)];
	
	return [method autorelease]; 
}	

# pragma mark Instance Methods

/* searchCurrentWebPageMethod
 * Returns the URL that needs to be accessed to send the query.
 */
- (NSURL *)queryURLforSearchString:(NSString *)searchString;
{
	NSURL * queryURL;
	NSString * temp = [[self searchQueryString] stringByReplacingOccurrencesOfString:@"$SearchTerm$" withString:searchString];
	queryURL = cleanedUpAndEscapedUrlFromString(temp);
    return queryURL;
}

#pragma mark Getters and setters

/* setFriendlyName
 * Sets the name of the search method to be displayed in Vienna.
 */
-(void)setFriendlyName:(NSString *) newName 
{ 
	[friendlyName release]; 
	friendlyName = [newName retain]; 
}

/* friendlyName
 * Returns the name of the search method to be displayed in Vienna.
 */
-(NSString *)friendlyName 
{ 
	return friendlyName; 
}

/* setSearchQueryString
 * Sets the format string from the plugin info that we plug the search terms into.
 */
-(void)setSearchQueryString:(NSString *) newQueryString 
{ 
	[searchQueryString release]; 
	searchQueryString = [newQueryString retain]; 
}

/* searchQueryString
 * Returns the format string from the plugin info that we plug the search terms into.
 */
-(NSString *)searchQueryString 
{ 
	return searchQueryString; 
}

/* setHandler
 * Sets the handler for the SearchMetod. Handling happens in AppController, 
 * because that's where these always get called.
 */
-(void)setHandler:(SEL) theHandler 
{ 
	handler = theHandler; 
}

/* setHandler
 * Returns the handler for the SearchMetod. Handling happens in AppController, 
 * because that's where these always get called.
 */
-(SEL)handler 
{ 
	return handler; 
}

-(void)dealloc 
{ 
	[friendlyName release]; 
	friendlyName=nil;
	[searchQueryString release]; 
	searchQueryString=nil;
	[super dealloc]; 
}

@end
