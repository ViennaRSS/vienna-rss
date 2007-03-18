//
//  XMLTag.m
//  Vienna
//
//  Created by Steve Palmer on 04/03/2007.
//  Copyright (c) 2004-2007 Steve Palmer. All rights reserved.
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

#import "XMLTag.h"

@interface XMLTag (Private)
	-(void)setName:(NSString *)newName;
	-(void)setAttributes:(NSDictionary *)newAttributes;
@end

@implementation XMLTag

/* name
 * Returns the element tag name.
 */
-(NSString *)name
{
	return name;
}

/* setName
 * Sets the tag name
 */
-(void)setName:(NSString *)newName
{
	[newName retain];
	[name release];
	name = newName;
}

/* attributes
 * Returns the dictionary of tag attributes which is the collection of attributes
 * keyed by attribute name.
 */
-(NSDictionary *)attributes
{
	return attributes;
}

/* setAttributes
 * Sets the tag attributes.
 */
-(void)setAttributes:(NSDictionary *)newAttributes
{
	[newAttributes retain];
	[attributes release];
	attributes = newAttributes;
}

/* description
 * Return the tag formatted for output.
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@", name, attributes];
}

/* parserFromData
 * Given a block of text, this function returns an array of all the XML tags in the block
 * including HTML tags as permitted. Thus <a href>text</a> would be two array entries while
 * <br /> would be another. For each tag, a dictionary of attributes is also collected. The
 * raw CDATA text between tags is ignored. All tag and attribute names are returned as
 * lower case for simplicity, and attribute values have their quotes stripped.
 *
 * This is basically just a simple means of extracting HTML/XML tags from from the source
 * page. It doesn't really do much else and we can either replace this by some true HTML
 * parser (XMLParser won't work as the CFXMLTreeCreateFromDataWithError can't cope with
 * the looser HTML syntax) or expand this to be a real HTML/XML parser.
 */
+(NSArray *)parserFromData:(NSData *)data
{
	NSMutableArray * tagArray = [NSMutableArray arrayWithCapacity:10];
	const char * textPtr = [data bytes];
	const char * endPtr = textPtr + [data length];
	const char * tagStartPtr = nil;
	int cntrlCharCount = 0;
	BOOL inTag = NO;
	BOOL inQuote = NO;

	while (textPtr < endPtr)
	{
		if (iscntrl(*textPtr) && *textPtr != '\r' && *textPtr != '\n' && *textPtr != '\t')
		{
			// A series of control characters suggest a corrupted feed so bail
			// out now if this happens.
			if (++cntrlCharCount == 10)
				break;
		}
		else if (*textPtr == '<' && !inTag && !inQuote)
		{
			tagStartPtr = textPtr+1;
			inTag = YES;
		}
		else if (*textPtr == '"')
		{
			inQuote = !inQuote;
		}
		else if (*textPtr == '>' && inTag)
		{
			NSAssert(tagStartPtr != nil, @"Somehow got into a tag without tagStartPtr!");

			// Anything that starts with a '!' is a comment. Otherwise it is the
			// tag name so collect and save it.
			if (*tagStartPtr != '!')
			{
				XMLTag * tag = [[XMLTag alloc] init];
				NSMutableDictionary * tagDict = [NSMutableDictionary dictionary];
				const char * tagEndPtr = tagStartPtr;

				if (*tagEndPtr == '/')
					++tagEndPtr;
				while (isalpha(*tagEndPtr))
					++tagEndPtr;
				[tag setName:[[NSString stringWithCString:tagStartPtr length:(tagEndPtr - tagStartPtr)] lowercaseString]];
				
				while (isspace(*tagEndPtr))
					++tagEndPtr;
				
				// Now gather all attributes
				while (*tagEndPtr != '>')
				{
					// Tag close?
					if (*tagEndPtr == '/')
					{
						++tagEndPtr;
						continue;
					}
					
					// Get the attribute name
					tagStartPtr = tagEndPtr;
					while (isalpha(*tagEndPtr))
						++tagEndPtr;
					NSString * attrName = [[NSString stringWithCString:tagStartPtr length:(tagEndPtr - tagStartPtr)] lowercaseString];

					// Skip the '=' and any whitespaces between the name and the value
					while (isspace(*tagEndPtr))
						++tagEndPtr;
					if (*tagEndPtr == '=')
						++tagEndPtr;
					while (isspace(*tagEndPtr))
						++tagEndPtr;

					// Get the attribute value. This is everything up to the end of the tag or the
					// first space outside of quotes.
					tagStartPtr = tagEndPtr;
					BOOL inQuote = NO;
					while (*tagEndPtr)
					{
						if ((*tagEndPtr == ' ' || *tagEndPtr == '>' || *tagEndPtr == '/') && !inQuote)
							break;
						if (*tagEndPtr == '"')
							inQuote = !inQuote;
						++tagEndPtr;
					}
					NSString * attrValue = [NSString stringWithCString:tagStartPtr length:(tagEndPtr - tagStartPtr)];
					attrValue = [attrValue stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
					[tagDict setValue:attrValue forKey:attrName];

					while (isspace(*tagEndPtr))
						++tagEndPtr;
				}

				[tag setAttributes:tagDict];
				[tagArray addObject:tag];
				[tag release];
			}
			inTag = NO;
			inQuote = NO;
			tagStartPtr = nil;
		}
		++textPtr;
	}
	return tagArray;
}


/* dealloc
 * Clean up afterwards.
 */
-(void)dealloc
{
	[name release];
	[attributes release];
	[super dealloc];
}
@end
