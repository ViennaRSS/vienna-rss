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

@interface GoogleReader : NSObject <ASIHTTPRequestDelegate> {
    NSString * token;
	GTMOAuth2Authentication *oAuthObject;
    NSDictionary * subscriptions;
    NSArray * readingList;
	NSMutableArray *localFeeds;
	BOOL isAuthenticated;
	NSString * readerUser;
}

@property (nonatomic, copy) NSDictionary * subscriptions;
@property (nonatomic, copy) NSArray * readingList;
@property (nonatomic, copy) NSMutableArray * localFeeds;
@property (nonatomic, retain) NSString *token;
@property (nonatomic, retain) NSString *readerUser;


+(GoogleReader *)sharedManager;

-(BOOL)isAuthenticated;

-(void)loadSubscriptions:(NSNotification*)nc;
-(void)loadReadingList;
-(void)authenticate;
-(void)updateViennaSubscriptionsWithGoogleSubscriptions:(NSArray*)folderList;

-(BOOL)subscribingTo:(NSString *)feedURL;
-(void)subscribeToFeed:(NSString *)feedURL;
-(void)unsubscribeFromFeed:(NSString *)feedURL;
-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag;
-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag;
-(void)setFolder:(NSString *)folderName forFeed:(NSString *)feedURL folderFlag:(BOOL)flag;
-(void)disableTag:(NSString *)tagName;
-(void)renameTagFrom:(NSString *)oldName to:(NSString *)newName;
-(void)renameFeed:(NSString *)feedURL to:(NSString *)newName;
-(ASIHTTPRequest*)refreshFeed:(Folder*)thisFolder shouldIgnoreArticleLimit:(BOOL)ignoreLimit;

@end
