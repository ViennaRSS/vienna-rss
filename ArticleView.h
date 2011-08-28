//
//  ArticleView.h
//  Vienna
//
//  Created by Steve on Tue Jul 05 2005.
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

#import <Cocoa/Cocoa.h>
#import "TabbedWebView.h"

@interface ArticleView : TabbedWebView {
	NSString * htmlTemplate;
	NSString * cssStylesheet;
	NSString * jsScript;
	NSString * currentHTML;
}

// Public functions
+(NSDictionary *)stylesMap;
+(NSDictionary *)loadStylesMap;
-(void)clearHTML;
-(void)setHTML:(NSString *)htmlText withBase:(NSString *)urlString;
-(NSString *)articleTextFromArray:(NSArray *)msgArray;
-(void)keyDown:(NSEvent *)theEvent;
@end
