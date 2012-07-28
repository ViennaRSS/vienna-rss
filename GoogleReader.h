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
    NSString * token;
	NSString * actionToken;
	GTMOAuth2Authentication *oAuthObject;
    NSArray * readingList;
	NSMutableArray *localFeeds;
	BOOL isAuthenticated;
	NSString * readerUser;
	NSTimer * tokenTimer;
	NSTimer * actionTokenTimer;
	NSUInteger countOfNewArticles;
}

@property (nonatomic, copy) NSArray * readingList;
@property (nonatomic, copy) NSMutableArray * localFeeds;
@property (nonatomic, retain) NSString *token;
@property (nonatomic, retain) NSString *actionToken;
@property (nonatomic, retain) NSString *readerUser;
@property (nonatomic, retain) NSTimer * tokenTimer;
@property (nonatomic, retain) NSTimer * actionTokenTimer;


+(GoogleReader *)sharedManager;

// Check if an accessToken is available
-(BOOL)isReady;

-(void)loadSubscriptions:(NSNotification*)nc;
-(void)loadReadingList;
-(void)authenticate;
-(void)clearAuthentication;
-(void)resetAuthentication;

-(void)subscribeToFeed:(NSString *)feedURL;
-(void)unsubscribeFromFeed:(NSString *)feedURL;
-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag;
-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag;
-(void)setFolder:(NSString *)folderName forFeed:(NSString *)feedURL folderFlag:(BOOL)flag;
-(void)disableTag:(NSString *)tagName;
-(void)renameTagFrom:(NSString *)oldName to:(NSString *)newName;
-(void)renameFeed:(NSString *)feedURL to:(NSString *)newName;
-(ASIHTTPRequest*)refreshFeed:(Folder*)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit;
-(NSString *)getGoogleOAuthToken;
-(NSString *)getGoogleActionToken;
-(NSUInteger)countOfNewArticles;

@end
