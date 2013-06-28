//
//  GoogleReader.h
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequest.h"
#import "GTMOAuth2WindowController.h"
#import "Folder.h"
#import "ASINetworkQueue.h"
#import "ActivityLog.h"
#import "Debug.h"

@interface GoogleReader : NSObject <ASIHTTPRequestDelegate> {
@private
    NSString * token;
	NSMutableArray *localFeeds;
	NSString * readerUser;
	NSUInteger countOfNewArticles;
	NSString * clientAuthToken;
}

@property (nonatomic, copy) NSMutableArray * localFeeds;
@property (nonatomic, retain) NSString *token;
@property (nonatomic, retain) NSString *readerUser;
@property (nonatomic, retain) NSTimer * tokenTimer;


+(GoogleReader *)sharedManager;

// Check if an accessToken is available
-(BOOL)isReady;

-(void)loadSubscriptions:(NSNotification*)nc;
-(void)authenticate;
-(void)clearAuthentication;
-(void)resetAuthentication;

-(void)subscribeToFeed:(NSString *)feedURL;
-(void)unsubscribeFromFeed:(NSString *)feedURL;
-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag;
-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag;
-(void)setFolder:(NSString *)folderName forFeed:(NSString *)feedURL folderFlag:(BOOL)flag;
-(ASIHTTPRequest*)refreshFeed:(Folder*)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit;
-(NSUInteger)countOfNewArticles;

@end
