//
//  RefreshManager.h
//  Vienna
//
//  Created by Steve on 7/19/05.
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
#import "Database.h"
#import "FeedCredentials.h"
#import "Constants.h"
#import "ASINetworkQueue.h"

@interface RefreshManager : NSObject {
	NSUInteger maximumConnections;
	NSUInteger countOfNewArticles;
	NSMutableArray * refreshArray;
	NSMutableArray * authQueue;
	NSTimer * pumpTimer;
	FeedCredentials * credentialsController;
	//BOOL hasStarted;
	NSString * statusMessageDuringRefresh;
    SyncTypes syncType;
	ASINetworkQueue *networkQueue;
}

+(RefreshManager *)sharedManager;
+ (NSLock *)articlesUpdateSemaphore;
-(void)refreshFolderIconCacheForSubscriptions:(NSArray *)foldersArray;
//-(void)refreshSubscriptions:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus;
-(void)refreshSubscriptionsAfterRefresh:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus;
-(void)refreshSubscriptionsAfterRefreshAll:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus;
-(void)refreshSubscriptionsAfterSubscribe:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus;
-(void)refreshSubscriptionsAfterUnsubscribe:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus;
-(void)refreshSubscriptionsAfterDelete:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus;
-(void)refreshSubscriptionsAfterMerge:(NSArray *)foldersArray ignoringSubscriptionStatus:(BOOL)ignoreSubStatus;
-(void)forceRefreshSubscriptionForFolders:(NSArray*)foldersArray;
-(void)cancelAll;
-(BOOL)isConnecting;
-(NSUInteger)countOfNewArticles;
-(NSString *)statusMessageDuringRefresh;
@end

// Refresh types
typedef enum {
	MA_Refresh_NilType = -1,
	MA_Refresh_Feed,
	MA_Refresh_FavIcon,
	MA_Refresh_GoogleFeed,
	MA_ForceRefresh_Google_Feed
} RefreshTypes;
