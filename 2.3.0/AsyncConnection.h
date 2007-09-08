//
//  AsyncConnection.h
//  Vienna
//
//  Created by Steve on 6/16/05.
//  Copyright (c) 2005 Steve Palmer. All rights reserved.
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
#import "ActivityLog.h"

// Possible return values
typedef enum {
	MA_Connect_Succeeded = 0,
	MA_Connect_Failed,
	MA_Connect_NeedCredentials,
	MA_Connect_Stopped,
	MA_Connect_PermanentRedirect,
	MA_Connect_URLIsGone
} ConnectStatus;

@interface AsyncConnection : NSObject {
	NSURLConnection * connector;
	NSDictionary * httpHeaders;
	NSDictionary * responseHeaders;
	NSMutableData * receivedData;
	NSString * username;
	NSString * password;
	ActivityItem * aItem;
	NSString * URLString;
	id contextData;
	ConnectStatus status;
	id delegate;
	SEL handler;
}

// Public functions
-(BOOL)beginLoadDataFromURL:(NSURL *)url
				   username:(NSString *)theUsername
				   password:(NSString *)thePassword
				   delegate:(id)theDelegate
				contextData:(id)theData
						log:(ActivityItem *)theItem
			 didEndSelector:(SEL)endSelector;
-(void)cancel;
-(void)close;

-(ConnectStatus)status;
-(id)contextData;
-(ActivityItem *)aItem;
-(NSString *)URLString;

-(void)setHttpHeaders:(NSDictionary *)headerFields;
-(NSDictionary *)responseHeaders;
-(NSData *)receivedData;
@end
