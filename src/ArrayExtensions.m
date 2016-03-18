//
//  ArrayExtensions.m
//  Vienna
//
//  Created by Steve on 9/25/05.
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

#import "ArrayExtensions.h"

@implementation NSArray (ArrayExtensions)

/* indexOfStringInArray
 * Returns the index of the specified string in the receiver. Or returns
 * NSNotFound if the string is not found. The string must match exactly with regard
 * to case, character set and spaces.
 */
-(NSUInteger)indexOfStringInArray:(NSString *)theString
{
	NSUInteger index = 0;
	while (index < self.count)
	{
		NSString * aString = self[index];
		NSAssert([aString isKindOfClass:[NSString class]], @"Not an NSString object in the array!");
		if ([aString isEqualToString:theString])
			return index;
		++index;
	}
	return NSNotFound;
}

@end
