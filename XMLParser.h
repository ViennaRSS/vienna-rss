//
//  XMLParser.h
//  Vienna
//
//  Created by Steve on 5/27/05.
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
// 

#import <Cocoa/Cocoa.h>

@interface XMLParser : NSObject {
	CFXMLTreeRef tree;
	CFXMLNodeRef node;
}

// Functions
-(BOOL)setData:(NSData *)data;
-(id)initWithEmptyTree;
-(BOOL)hasValidTree;
-(CFIndex)countOfChildren;
-(NSString *)nodeName;
-(XMLParser *)addTree:(NSString *)name;
-(XMLParser *)addTree:(NSString *)name withElement:(NSString *)value;
-(XMLParser *)addTree:(NSString *)name withAttributes:(NSDictionary *)attributesDict;
-(XMLParser *)addClosedTree:(NSString *)name withAttributes:(NSDictionary *)attributesDict;
-(void)addElement:(NSString *)value;
-(NSDictionary *)attributesForTree;
-(NSString *)xmlForTree;
-(NSString *)valueOfElement;
-(NSString *)valueOfAttribute:(NSString *)attributeName;
-(XMLParser *)treeByName:(NSString *)name;
-(XMLParser *)treeByPath:(NSString *)path;
-(XMLParser *)treeByIndex:(CFIndex)index;
+(NSString *)quoteAttributes:(NSString *)stringToProcess;
+(NSCalendarDate *)parseXMLDate:(NSString *)dateString;
@end
