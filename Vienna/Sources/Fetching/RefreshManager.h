//
//  RefreshManager.h
//  Vienna
//
//  Created by Steve on 7/19/05.
//  Copyright (c) 2004-2018 Steve Palmer and Vienna contributors (see menu item 'About Vienna' for list of contributors). All rights reserved.
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

@class Database;
@class FeedCredentials;
@class Folder;

@interface RefreshManager : NSObject <NSURLSessionTaskDelegate> {
	NSUInteger countOfNewArticles;
	NSMutableArray * authQueue;
	FeedCredentials * credentialsController;
	BOOL hasStarted;
	NSString * statusMessageDuringRefresh;
	NSOperationQueue *networkQueue;
	dispatch_queue_t _queue;
}

+(RefreshManager *)sharedManager;

@property (readonly, copy) NSString *statusMessage;
@property (nonatomic, getter=isConnecting, readonly) BOOL connecting;
@property (nonatomic, readonly) NSUInteger countOfNewArticles;

-(void)refreshFolderIconCacheForSubscriptions:(NSArray *)foldersArray;
-(void)refreshSubscriptions:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus;
-(void)forceRefreshSubscriptionForFolders:(NSArray*)foldersArray;
-(void)cancelAll;
-(void)refreshFavIconForFolder:(Folder *)folder;
-(NSOperation *)addConnection:(NSURLRequest *)conn completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
-(void)suspendConnectionsQueue;
-(void)resumeConnectionsQueue;
@end

// Refresh types
typedef NS_ENUM(int, RefreshTypes) {
	MA_Refresh_NilType = -1,
	MA_Refresh_Feed,
	MA_Refresh_FavIcon,
	MA_Refresh_GoogleFeed,
	MA_ForceRefresh_Google_Feed
};
