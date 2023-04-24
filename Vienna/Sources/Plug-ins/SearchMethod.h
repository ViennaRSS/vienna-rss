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

@import Foundation;

@interface SearchMethod : NSObject <NSSecureCoding>

/// Used to init fron a plugin's info.dict. This class is designed to be capable
/// of doing different things with searches according to the plugin definition.
/// At the moment, however, we only ever do a normal web search.
- (instancetype)initWithDictionary:(NSDictionary *)dict;

/// The standard SearchMethod "Search all Articles".
@property (class, readonly, nonatomic) SearchMethod *allArticlesSearchMethod;

/// SearchMethod that only works when the active view is a web pane.
@property (class, readonly, nonatomic) SearchMethod *currentWebPageSearchMethod;

/// The standard SearchMethod "Search For Folders".
@property (class, readonly, nonatomic) SearchMethod *searchForFoldersMethod;

@property (copy, nonatomic) NSString *displayName;
@property (copy, nonatomic) NSString *queryString;
@property (nonatomic) SEL handler;

/// Returns the URL that needs to be accessed to send the query.
- (NSURL *)queryURLforSearchString:(NSString *)searchString;

@end
