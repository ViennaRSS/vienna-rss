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
@end

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

/* stringByRemovingHTML
 * Returns an autoreleased instance of the specified string with all HTML tags removed.
 */
+(NSString *)stringByRemovingHTML:(NSString *)theString validTags:(NSArray *)tagArray
{
	NSMutableString * aString = [NSMutableString stringWithString:theString];
	int maxChrs = [theString length];
	int indexOfChr = 0;
	int tagLength = 0;
	int tagStartIndex = 0;
	int lengthToLastWord = 0;
	BOOL isInQuote = NO;
	BOOL isInTag = NO;
	
	// Rudimentary HTML tag parsing. This could be done by initWithHTML on an attributed string
	// and extracting the raw string but initWithHTML cannot be invoked within an NSURLConnection
	// callback which is where this is probably liable to be used.
	//
	// This code basically throws away all HTML tags up to <br> or <br /> or the first raw newline
	// or until 256 characters have been processed.
	//
	while (indexOfChr < maxChrs)
	{
		unichar ch = [aString characterAtIndex:indexOfChr];
		if (ch == '"')
			isInQuote = !isInQuote;
		if (isInTag)
			++tagLength;
		if (ch == ' ' && !isInTag)
			lengthToLastWord = indexOfChr;
		if (ch == '<' && !isInQuote)
		{
			isInTag = YES;
			tagStartIndex = indexOfChr;
			tagLength = 0;
		}
		if (ch == '>' && isInTag)
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
				if (tagArray == nil || [tagArray indexOfStringInArray:tagName] != NSNotFound)
				{
					[aString deleteCharactersInRange:tagRange];

					// Reset scan to the point where the tag started minus one because
					// we bump up indexOfChr at the end of the loop.
					indexOfChr = tagStartIndex - 1;
					maxChrs = [aString length];
				}
				isInTag = NO;

				if ([tagName isEqualToString:@"br"] && indexOfChr >= 0)
				{
					lengthToLastWord = tagStartIndex;
					break;
				}
			}
		}
		if (ch == '\n' || ch == '\r')
		{
			lengthToLastWord = indexOfChr;
			break;
		}
		if (indexOfChr >= 256 && !isInTag)
			break;
		++indexOfChr;
	}
	
	// If we got a long word with no spaces then just break the string
	// at the limit.
	if (lengthToLastWord == 0)
		lengthToLastWord = MIN(maxChrs, 256);
	if (indexOfChr != maxChrs)
	{
		[aString deleteCharactersInRange:NSMakeRange(lengthToLastWord, maxChrs - lengthToLastWord)];

		// If we truncated at the end of a word, append ellipsises to show that
		// there was more. Really just a little polish.
		if (lengthToLastWord < indexOfChr)
			[aString appendString:@"..."];
	}
	return aString;
}

/* firstNonBlankLine
 * Returns the first line of the string that isn't entirely spaces or tabs. Leading and
 * trailing spaces in the returned string are preserved. If all lines in the string are
 * empty, we return an empty string.
 */
-(NSString *)firstNonBlankLine
{
	unsigned int indexOfLastWord;
	unsigned int indexOfChr;
	BOOL hasNonEmptyChars;
	BOOL allowEmpty;
	NSRange r;
	
	r.location = 0;
	r.length = 0;
	indexOfChr = 0;
	indexOfLastWord = 0;
	hasNonEmptyChars = NO;
	allowEmpty = NO;
	while (indexOfChr < [self length])
	{
		unichar ch = [self characterAtIndex:indexOfChr];
		if (ch == '\r' || ch == '\n')
		{
			if (hasNonEmptyChars)
			{
				indexOfLastWord = r.length;
				break;
			}
			r.location += r.length + 1;
			r.length = -1;
			hasNonEmptyChars = NO;
		}
		else
		{
			if (ch == ' ' || ch == '\t')
				indexOfLastWord = r.length;
			else
				hasNonEmptyChars = YES;
		}
		++indexOfChr;
		++r.length;
	}
	if (r.length < [self length])
		r.length = indexOfLastWord;
	return [self substringWithRange:r];
}

/* stringByDeletingLastURLComponent
 * Returns a string with the last URL component removed. It is similar to stringByDeletingLastPathComponent
 * but it doesn't attempt to interpret the current string as a file path and 'fixup' slashes.
 */
-(NSString *)stringByDeletingLastURLComponent
{
	int index = [self length] - 1;
	if (index > 0 && [self characterAtIndex:index] == '/')
		--index;
	while (index >= 0 && [self characterAtIndex:index] != '/')
		--index;
	if (index <= 0)
		++index;
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
