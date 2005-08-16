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
#import "XMLParser.h"

@interface FeedItem : NSObject {
	NSString * title;
	NSString * author;
	NSString * link;
	NSString * guid;
	NSDate * date;
	NSString * description;
}

// Accessor functions
-(NSString *)title;
-(NSString *)description;
-(NSString *)author;
-(NSString *)guid;
-(NSDate *)date;
-(NSString *)link;
@end

@interface RichXMLParser : XMLParser {
	NSString * title;
	NSString * link;
	NSString * description;
	NSDate * lastModified;
	NSMutableArray * items;
}

// General functions
-(BOOL)parseRichXML:(NSData *)xmlData;
-(NSString *)title;
-(NSString *)description;
-(NSString *)link;
-(NSDate *)lastModified;
-(NSArray *)items;
@end
