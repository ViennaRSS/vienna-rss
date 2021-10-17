//
//  RichXMLParser.h
//  Vienna
//
//  Copyright 2004-2005 Steve Palmer
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

@import Foundation;

@interface RichXMLParser : NSObject

@property (readonly, nonatomic) NSString *title;
@property (readonly, nonatomic) NSString *feedDescription;
@property (readonly, nonatomic) NSString *link;
@property (readonly, nonatomic) NSDate *lastModified;
@property (readonly, nonatomic) NSArray *items;

- (BOOL)parseRichXML:(NSData *)xmlData;

@end
