//
//  StringExtensions.m
//  Vienna
//
//  Created by Steve on Wed Mar 17 2004.
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

#import "StringExtensions.h"
#import "ArrayExtensions.h"

@implementation NSMutableString (MutableStringExtensions)

/* replaceString
 * Replaces one string with another. This is just a simpler version of the standard
 * NSMutableString replaceOccurrencesOfString function with NSLiteralString implied
 * and the range set to the entire string.
 */
-(void)replaceString:(NSString *)source withString:(NSString *)dest
{
	[self replaceOccurrencesOfString:source withString:dest options:NSLiteralSearch range:NSMakeRange(0, [self length])];
}

/* fixupRelativeImgTags
 * Scans the text for <img...> tags that have relative links in the src attribute and fixes
 * up the relative links to be absolute to the base URL.
 */
-(void)fixupRelativeImgTags:(NSString *)baseURL
{
	baseURL = [baseURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	if (baseURL == nil)
		return;
	NSURL * imgBaseURL = [NSURL URLWithString:baseURL];
	
	unsigned int textLength = [self length];
	NSRange srchRange;
	
	srchRange.location = 0;
	srchRange.length = textLength;
	while ((srchRange = [self rangeOfString:@"<img" options:NSLiteralSearch range:srchRange]), srchRange.location != NSNotFound)
	{
		srchRange.length = textLength - srchRange.location;
		NSRange srcRange = [self rangeOfString:@"src=\"" options:NSLiteralSearch range:srchRange];
		if (srcRange.location != NSNotFound)
		{
			// Find the src parameter range.
			unsigned int index = srcRange.location + srcRange.length;
			srcRange.location += srcRange.length;
			srcRange.length = 0;
			while (index < textLength && [self characterAtIndex:index] != '"')
			{
				++index;
				++srcRange.length;
			}
			
			// Now extract the source parameter
			NSString * srcPath = [self substringWithRange:srcRange];
			if (![srcPath hasPrefix:@"http://"])
			{
				NSString * escapedSrcPath = [srcPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				if (escapedSrcPath != nil)
				{
					NSURL * imgURL = [NSURL URLWithString:escapedSrcPath relativeToURL:imgBaseURL];
					if (imgURL != nil)
					{
						srcPath = [imgURL absoluteString];
						[self replaceCharactersInRange:srcRange withString:srcPath];
						textLength = [self length];
					}
				}
			}
			
			// Start searching again from beyond the URL
			srchRange.location = srcRange.location + [srcPath length];
		}
		else
			++srchRange.location;
		srchRange.length = textLength - srchRange.location;
	}
}
@end

// Used for mapping entities to their representations
static NSMutableDictionary * entityMap = nil;

@implementation NSString (StringExtensions)

/* hexValue
 * A counterpart to intValue, but parses a hexadecimal number.
 */
-(int)hexValue
{
	int count = [self length];
	int intValue = 0;
	int index = 0;

	while (index < count)
	{
		unichar ch = [self characterAtIndex:index];
		if (ch >= '0' && ch <= '9')
			intValue = (intValue * 16) + (ch - '0');
		else if (ch >= 'A' && ch <= 'F')
			intValue = (intValue * 16) + (ch - 'A' + 10);
		else if (ch >= 'a' && ch <= 'f')
			intValue = (intValue * 16) + (ch - 'a' + 10);
		else
			break;
		++index;
	}
	return intValue;
}

/* summaryTextFromHTML
 * Create a summary text string from raw HTML. We strip out the HTML and convert the entity
 * characters to their unicode equivalents. Newlines are replaced with spaces then the string
 * is truncated to the given number of characters.
 */
-(NSString *)summaryTextFromHTML
{
	return [[NSString stringByRemovingHTML:self] normalised];
}

/* titleTextFromHTML
 * Create a title from a description which may be HTML. The HTML is stripped out and entity
 * characters are converted to their unicode equivalents. Then the first newline is returned up to
 * the given number of characters.
 */
-(NSString *)titleTextFromHTML
{
	return [[NSString stringByRemovingHTML:self] firstNonBlankLine];
}

/* firstWord
 * Returns the first word in self.
 */
-(NSString *)firstWord
{
	NSString * trimmedSelf = [self trim];
	int wordLength = [trimmedSelf indexOfCharacterInString:' ' afterIndex:0];
	return (wordLength == NSNotFound) ? trimmedSelf : [trimmedSelf substringToIndex:wordLength];
}

/* stringByRemovingHTML
 * Returns an autoreleased instance of the specified string with all HTML tags removed.
 */
+(NSString *)stringByRemovingHTML:(NSString *)theString
{
	NSMutableString * aString = [NSMutableString stringWithString:theString];
	int maxChrs = [theString length];
	int cutOff = 150;
	int indexOfChr = 0;
	int tagLength = 0;
	int tagStartIndex = 0;
	BOOL isInQuote = NO;
	BOOL isInTag = NO;

	// Rudimentary HTML tag parsing. This could be done by initWithHTML on an attributed string
	// and extracting the raw string but initWithHTML cannot be invoked within an NSURLConnection
	// callback which is where this is probably liable to be used.
	while (indexOfChr < maxChrs)
	{
		unichar ch = [aString characterAtIndex:indexOfChr];
		if (isInTag)
			++tagLength;
		else if (indexOfChr >= cutOff)
			break;
		
		if (ch == '"')
			isInQuote = !isInQuote;
		else if (ch == '<' && !isInQuote)
		{
			isInTag = YES;
			tagStartIndex = indexOfChr;
			tagLength = 0;
		}
		else if (ch == '>' && isInTag)
		{
			if (++tagLength > 2)
			{
				NSRange tagRange = NSMakeRange(tagStartIndex, tagLength);
				NSString * tag = [[aString substringWithRange:tagRange] lowercaseString];
				int indexOfTagName = 1;

				// Extract the tag name
				if ([tag characterAtIndex:indexOfTagName] == '/')
					++indexOfTagName;
				
				int chIndex = indexOfTagName;
				unichar ch = [tag characterAtIndex:chIndex];
				while (chIndex < tagLength && [[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:ch])
					ch = [tag characterAtIndex:++chIndex];
	
				NSString * tagName = [tag substringWithRange:NSMakeRange(indexOfTagName, chIndex - indexOfTagName)];
				[aString deleteCharactersInRange:tagRange];

				// Replace <br> and </p> with newlines
				if ([tagName isEqualToString:@"br"] || [tag isEqualToString:@"<p>"] || [tag isEqualToString:@"<div>"])
					[aString insertString:@"\n" atIndex:tagRange.location];

				// Reset scan to the point where the tag started minus one because
				// we bump up indexOfChr at the end of the loop.
				indexOfChr = tagStartIndex - 1;
				maxChrs = [aString length];
				isInTag = NO;
				isInQuote = NO;	// Fix problem with Tribe.net feeds that have bogus quotes in HTML tags
			}
		}
		++indexOfChr;
	}
	
	if (maxChrs > cutOff)
		[aString deleteCharactersInRange:NSMakeRange(cutOff, maxChrs - cutOff)];
	
	return [aString stringByUnescapingExtendedCharacters];
}

/* normalised
 * Returns the current string normalised. Newlines are removed and replaced with spaces and multiple
 * spaces are collapsed to one.
 */
-(NSString *)normalised
{
	NSMutableString * string = [NSMutableString stringWithString:self];
	BOOL isInWhitespace = YES;
	int length = [string length];
	int index = 0;
	
	while (index < length)
	{
		unichar ch = [string characterAtIndex:index];
		if (ch == '\r' || ch == '\n' || ch == '\t')
		{
			if (!isInWhitespace)
				[string replaceCharactersInRange:NSMakeRange(index, 1) withString:@" "];
			ch = ' ';
		}
		if (ch == ' ' && isInWhitespace)
		{
			[string deleteCharactersInRange:NSMakeRange(index, 1)];
			--index;
			--length;
		}
		isInWhitespace = (ch == ' ');
		++index;
	}
	return string;
}

/* firstNonBlankLine
 * Returns the first line of the string that isn't entirely spaces or tabs. If all lines in the string are
 * empty, we return an empty string.
 */
-(NSString *)firstNonBlankLine
{
	BOOL hasNonEmptyChars = NO;
	unsigned int indexOfFirstChr = 0u;
	unsigned int indexOfLastChr = 0u;
	
	unsigned int indexOfChr = 0u;
	unsigned int length = [self length];
	while (indexOfChr < length)
	{
		unichar ch = [self characterAtIndex:indexOfChr];
		if (ch == '\r' || ch == '\n')
		{
			if (hasNonEmptyChars)
			{
				break;
			}
		}
		else
		{
			if (ch != ' ' && ch != '\t')
			{
				if (!hasNonEmptyChars)
				{
					hasNonEmptyChars = YES;
					indexOfFirstChr = indexOfChr;
				}
				indexOfLastChr = indexOfChr;
			}
		}
		++indexOfChr;
	}
	return hasNonEmptyChars ? [self substringWithRange:NSMakeRange(indexOfFirstChr, 1u + (indexOfLastChr - indexOfFirstChr))] : @"";
}

/* stringByDeletingLastURLComponent
 * Returns a string with the last URL component removed. It is similar to stringByDeletingLastPathComponent
 * but it doesn't attempt to interpret the current string as a file path and 'fixup' slashes.
 */
-(NSString *)stringByDeletingLastURLComponent
{
	int index = [self length] - 1;
	int beginning = 0;

	if ([self hasPrefix:@"http://"])
		beginning = 6;
	if (index > beginning && [self characterAtIndex:index] == '/')
		--index;
	while (index >= beginning && [self characterAtIndex:index] != '/')
		--index;
	if (index <= beginning)
		return self;
	return [self substringWithRange:NSMakeRange(0, index)];
}

/* stringByAppendingURLComponent
 * Appends the specified component to the end of our URL. It is similar to stringByAppendingPathComponent
 * but it doesn't attempt to interpret the current string as a file path and 'fixup' slashes.
 */
-(NSString *)stringByAppendingURLComponent:(NSString *)newComponent
{
	NSMutableString * newString = [NSMutableString stringWithString:self];
	int index = [newString length] - 1;
	int newIndex = 0;

	if (index >= 0 && [newString characterAtIndex:index] != '/')
		[newString appendString:@"/"];
	if ([newComponent length] > 0 && [newComponent characterAtIndex:0] == '/')
		++newIndex;
	[newString appendString:[newComponent substringFromIndex:newIndex]];
	return newString;
}

/* stringByEscapingExtendedCharacters
 * Returns a string that consisted of the receiver but with all extended characters
 * escaped in the format &#code; where code is the character code.
 */
-(NSString *)stringByEscapingExtendedCharacters
{
	NSMutableString * escapedString = [NSMutableString stringWithString:self];
	int length = [escapedString length];
	int index = 0;

	while (index < length)
	{
		unichar ch = [escapedString characterAtIndex:index];
		if (ch <= 127)
			++index;
		else
		{
			NSString * escapedCharacter = [NSString stringWithFormat:@"&#%d;", ch];
			[escapedString replaceCharactersInRange:NSMakeRange(index, 1) withString:escapedCharacter];
			index += [escapedCharacter length];
			length = [escapedString length];
		}
	}
	return escapedString;
}

/* stringByUnescapingExtendedCharacters
 * Scan the specified string and convert attribute characters to their literals. Also trim leading and trailing
 * whitespace.
 */
-(NSString *)stringByUnescapingExtendedCharacters
{
	NSMutableString * processedString = [[NSMutableString alloc] initWithString:self];
	int entityStart;
	int entityEnd;
	
	entityStart = [processedString indexOfCharacterInString:'&' afterIndex:0];
	while (entityStart != NSNotFound)
	{
		entityEnd = [processedString indexOfCharacterInString:';' afterIndex:entityStart + 1];
		if (entityEnd != NSNotFound)
		{
			NSRange entityRange = NSMakeRange(entityStart, (entityEnd - entityStart) + 1);
			NSRange innerEntityRange = NSMakeRange(entityRange.location + 1, entityRange.length - 2);
			NSString * entityString = [processedString substringWithRange:innerEntityRange];
			[processedString replaceCharactersInRange:entityRange withString:[NSString mapEntityToString:entityString]];
		}
		entityStart = [processedString indexOfCharacterInString:'&' afterIndex:entityStart + 1];
	}
	
	NSString * returnString = [processedString trim];
	[processedString release];
	return returnString;
}

/* mapEntityToString
 * Maps an entity sequence to its character equivalent.
 */
+(NSString *)mapEntityToString:(NSString *)entityString
{
	if (entityMap == nil)
	{
		entityMap = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
			@"<",	@"lt",
			@">",	@"gt",
			@"\"",	@"quot",
			@"&",	@"amp",
			@"'",	@"rsquo",
			@"'",	@"lsquo",
			@"'",	@"apos",
			@"...", @"hellip",
			@" ",	@"nbsp",
			nil,	nil] retain];
		
		// Add entities that map to non-ASCII characters
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xA1] forKey:@"iexcl"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xA2] forKey:@"cent"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xA3] forKey:@"pound"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xA4] forKey:@"curren"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xA5] forKey:@"yen"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xA6] forKey:@"brvbar"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xA7] forKey:@"sect"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xA8] forKey:@"uml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xA9] forKey:@"copy"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xAA] forKey:@"ordf"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xAB] forKey:@"laquo"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xAC] forKey:@"not"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xAE] forKey:@"reg"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xAF] forKey:@"macr"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xB0] forKey:@"deg"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xB1] forKey:@"plusmn"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xB2] forKey:@"sup2"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xB3] forKey:@"sup3"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xB4] forKey:@"acute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xB5] forKey:@"micro"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xB6] forKey:@"para"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xB7] forKey:@"middot"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xB8] forKey:@"cedil"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xB9] forKey:@"sup1"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xBA] forKey:@"ordm"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xBB] forKey:@"raquo"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xBC] forKey:@"frac14"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xBD] forKey:@"frac12"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xBE] forKey:@"frac34"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xBF] forKey:@"iquest"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xC0] forKey:@"Agrave"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xC1] forKey:@"Aacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xC3] forKey:@"Atilde"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xC4] forKey:@"Auml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xC5] forKey:@"Aring"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xC6] forKey:@"AElig"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xC7] forKey:@"Ccedil"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xC8] forKey:@"Egrave"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xC9] forKey:@"Eacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xCA] forKey:@"Ecirc"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xCB] forKey:@"Euml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xCC] forKey:@"Igrave"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xCD] forKey:@"Iacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xCE] forKey:@"Icirc"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xCF] forKey:@"Iuml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xD0] forKey:@"ETH"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xD1] forKey:@"Ntilde"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xD2] forKey:@"Ograve"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xD3] forKey:@"Oacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xD4] forKey:@"Ocirc"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xD5] forKey:@"Otilde"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xD6] forKey:@"Ouml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xD7] forKey:@"times"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xD8] forKey:@"Oslash"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xD9] forKey:@"Ugrave"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xDA] forKey:@"Uacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xDB] forKey:@"Ucirc"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xDC] forKey:@"Uuml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xDD] forKey:@"Yacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xDE] forKey:@"THORN"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xDF] forKey:@"szlig"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xE0] forKey:@"agrave"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xE1] forKey:@"aacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xE2] forKey:@"acirc"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xE3] forKey:@"atilde"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xE4] forKey:@"auml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xE5] forKey:@"aring"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xE6] forKey:@"aelig"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xE7] forKey:@"ccedil"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xE8] forKey:@"egrave"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xE9] forKey:@"eacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xEA] forKey:@"ecirc"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xEB] forKey:@"euml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xEC] forKey:@"igrave"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xED] forKey:@"iacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xEE] forKey:@"icirc"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xEF] forKey:@"iuml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xF0] forKey:@"eth"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xF1] forKey:@"ntilde"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xF2] forKey:@"ograve"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xF3] forKey:@"oacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xF4] forKey:@"ocirc"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xF5] forKey:@"otilde"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xF6] forKey:@"ouml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xF7] forKey:@"divide"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xF8] forKey:@"oslash"];
        [entityMap setValue:[NSString stringWithFormat:@"%C", 0xF9] forKey:@"ugrave"];
        [entityMap setValue:[NSString stringWithFormat:@"%C", 0xFA] forKey:@"uacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xFB] forKey:@"ucirc"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xFC] forKey:@"uuml"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xFD] forKey:@"yacute"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xFE] forKey:@"thorn"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xC3C] forKey:@"sigma"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0xCA3] forKey:@"Sigma"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0x2022] forKey:@"bull"];
		[entityMap setValue:[NSString stringWithFormat:@"%C", 0x20AC] forKey:@"euro"];
	}
	
	// Parse off numeric codes of the format #xxx
	if ([entityString length] > 1 && [entityString characterAtIndex:0] == '#')
	{
		int intValue;
		if ([entityString characterAtIndex:1] == 'x')
			intValue = [[entityString substringFromIndex:2] hexValue];
		else
			intValue = [[entityString substringFromIndex:1] intValue];
		return [NSString stringWithFormat:@"%C", MAX(intValue, ' ')];
	}
	
	NSString * mappedString = [entityMap objectForKey:entityString];
	return mappedString ? mappedString : [NSString stringWithFormat:@"&%@;", entityString];
}

/* indexOfCharacterInString
 * Returns the index of the first occurrence of the specified character at or after
 * the starting index. If no occurrence is found, returns NSNotFound.
 */
-(int)indexOfCharacterInString:(char)ch afterIndex:(int)startIndex
{
	int length = [self length];
	int index;

	if (startIndex < length - 1)
		for (index = startIndex; index < length; ++index)
		{
			if ([self characterAtIndex:index] == ch)
				return index;
		}
	return NSNotFound;
}

/* hasCharacter
 * Returns YES if the specified character appears in the string. NO otherwise.
 */
-(BOOL)hasCharacter:(char)ch
{
	return [self indexOfCharacterInString:ch afterIndex:0] != NSNotFound;
}

/* trim
 * Removes leading and trailing whitespace from the string.
 */
-(NSString *)trim
{
	return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

/* isBlank
 * Returns YES if the string is blank. No otherwise. A blank string is defined
 * as one comprising entirely one or more combination of spaces, tabs or newlines.
 */
-(BOOL)isBlank
{
	return [[self trim] length] == 0;
}

/* convertStringToValidPath
 * This function normalises a string to make it suitable for use as a path. It converts any part
 * of the string that is a 'path' separator to an underscore.
 */
-(NSString *)convertStringToValidPath
{
	NSMutableString * baseURLString = [NSMutableString stringWithString:self];
	[baseURLString replaceOccurrencesOfString:@"." withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [baseURLString length])];
	[baseURLString replaceOccurrencesOfString:@"/" withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [baseURLString length])];
	[baseURLString replaceOccurrencesOfString:@"?" withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [baseURLString length])];
	[baseURLString replaceOccurrencesOfString:@"*" withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [baseURLString length])];
	return baseURLString;
}

/* baseURL
 * Given a URL, this function returns the root of the URL minus the scheme and
 * any path. Thus if the string is:
 *
 *  http://www.livejournal.com/users/stevewpalmer
 *
 * Then it returns www.livejournal.com. If the URL itself is the root or
 * we can't parse anything, we just return ourselves. Thus we're guaranteed to
 * return a non-nil value.
 */
-(NSString *)baseURL
{
	NSURL * url = [NSURL URLWithString:self];
	return (url && [url host]) ? [url host] : self;
}

/* numericCompare
 * Compares two strings using both case insensitivity and numeric comparisons.
 */
-(NSComparisonResult)numericCompare:(NSString *)aString;
{
	return [self compare:aString options:NSCaseInsensitiveSearch|NSNumericSearch];
}
@end
