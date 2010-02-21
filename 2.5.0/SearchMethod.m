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

-(id)initWithDictionary:(NSDictionary *)dict 
{
	if ((self = [super init]) != nil)
	{
		friendlyName = [dict valueForKey:@"FriendlyName"];
		searchQueryString = [dict valueForKey:@"SearchQueryString"];
		/* This class is designed to be capable of doing different things with searches 
		 * according to the plugin definition. At the moment, however, we only ever 
		 * do a normal web-search when we initialize from a plugn dict.*/
		handler = @selector(performWebSearch:);
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder; // We need to conform to NSCoder so we can store SearchMethods in the Defaults database.
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

- (NSURL *)queryURLforSearchString:(NSString *)searchString;
{
	NSURL * queryURL;
	NSString * temp = [[self searchQueryString] stringByReplacingOccurrencesOfString:@"$SearchTerm$" withString:searchString];
	queryURL = cleanedUpAndEscapedUrlFromString(temp);
    return queryURL;
}

+(SearchMethod *)searchAllArticlesMethod
{
	SearchMethod * method = [[SearchMethod alloc] init];
	[method setFriendlyName:@"Search all articles"];
	[method setHandler:@selector(performAllArticlesSearch)];
	
	return [method autorelease]; 
}	

// Getters and setters.

-(void)setFriendlyName:(NSString *) newName 
{ 
	[friendlyName release]; 
	friendlyName = [newName retain]; 
}

-(NSString *)friendlyName 
{ 
	return friendlyName; 
}

-(NSString *)searchQueryString 
{ 
	return searchQueryString; 
}

-(void)setSearchQueryString:(NSString *) newQueryString 
{ 
	[searchQueryString release]; 
	searchQueryString = [newQueryString retain]; 
}

-(void)setHandler:(SEL) theHandler 
{ 
	handler = theHandler; 
}

-(SEL)handler 
{ 
	return handler; 
}

-(void)dealloc 
{ 
	[friendlyName release]; 
	[searchQueryString release]; 
	[super dealloc]; 
}

@end
