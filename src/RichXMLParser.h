//
//  RichXMLParser.h
//  Vienna
//
//  Created by Steve on 5/22/05.
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

#import <Cocoa/Cocoa.h>

@interface RichXMLParser : NSObject {
	NSString * title;
	NSString * link;
	NSString * description;
	NSDate * lastModified;
	NSMutableArray * items;
	NSMutableArray * orderArray;
	@private
	//prefixes for XML namespaces
	NSString * rssPrefix;
	NSString * rdfPrefix;
	NSString * atomPrefix;
	NSString * dcPrefix;
	NSString * contentPrefix;
	NSString * mediaPrefix;
	NSString * encPrefix;
}

// General functions
-(BOOL)parseRichXML:(NSData *)xmlData;
+(BOOL)extractFeeds:(NSData *)xmlData toArray:(NSMutableArray *)linkArray;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *description;
@property (nonatomic, readonly, copy) NSString *link;
@property (nonatomic, readonly, copy) NSDate *lastModified;
@property (nonatomic, readonly, copy) NSArray *items;
@end
