//
//  GoogleReader.h
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011-2014 Vienna contributors (see Help/Acknowledgements for list of contributors). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequest.h"
#import "Folder.h"
#import "ASINetworkQueue.h"
#import "ActivityLog.h"
#import "Debug.h"

@interface GoogleReader : NSObject <ASIHTTPRequestDelegate> {
@private
    NSString * token;
	NSMutableArray *localFeeds;
	NSUInteger countOfNewArticles;
	NSString * clientAuthToken;
	NSTimer * tokenTimer;
	NSTimer * authTimer;
	dispatch_queue_t _queue;
}

@property (nonatomic, copy) NSMutableArray * localFeeds;
@property (nonatomic, retain) NSString *token;
@property (nonatomic, retain) NSString *clientAuthToken;
@property (nonatomic, retain) NSTimer * tokenTimer;
@property (nonatomic, retain) NSTimer * authTimer;

+(GoogleReader *)sharedManager;

// Check if an accessToken is available
-(BOOL)isReady;

-(void)loadSubscriptions:(NSNotification*)nc;
-(void)authenticate;
-(void)getToken;
-(void)clearAuthentication;
-(void)resetAuthentication;

-(void)subscribeToFeed:(NSString *)feedURL;
-(void)unsubscribeFromFeed:(NSString *)feedURL;
-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag;
-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag;
-(void)setFolderName:(NSString *)folderName forFeed:(NSString *)feedURL set:(BOOL)flag;
-(ASIHTTPRequest*)refreshFeed:(Folder*)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit;
-(NSUInteger)countOfNewArticles;

@end
