//
//  ArticleRef.m
//  Vienna
//
//  Created by Steve on 9/3/05.
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

#import "ArticleRef.h"

@implementation ArticleReference

/* initWithReference
 */
-(instancetype)initWithReference:(NSString *)aGuid inFolder:(NSInteger)aFolderId
{
	if ((self = [super init]) != nil)
	{
		guid = aGuid;
		folderId = aFolderId;
	}
	return self;
}

/* makeReference
 * Create a new ArticleReference using the information in the specified article.
 */
+(ArticleReference *)makeReference:(Article *)anArticle
{
	return [[ArticleReference alloc] initWithReference:[anArticle guid] inFolder:[anArticle folderId]];
}

/* makeReferenceFromGUID
 * Create a new ArticleReference using the information in the specified article.
 */
+(ArticleReference *)makeReferenceFromGUID:(NSString *)aGuid inFolder:(NSInteger)folderId
{
	return [[ArticleReference alloc] initWithReference:aGuid inFolder:folderId];
}

/* guid
 * Return the reference GUID.
 */
-(NSString *)guid
{
	return guid;
}

/* folderId
 * Return the reference folder ID.
 */
-(NSInteger)folderId
{
	return folderId;
}

/* description
 * A human readable description of this reference.
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"%@ in folder %ld", guid, (long)folderId];
}

/* dealloc
 * Clean up behind ourselves.
 */
-(void)dealloc
{
	guid=nil;
}
@end
