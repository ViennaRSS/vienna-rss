//
//  GoogleReader.h
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequest.h"

@interface GoogleReader : NSObject <ASIHTTPRequestDelegate> {
    NSString * username;
    NSString * password;
    NSString * token;
    NSDictionary * subscriptions;
    NSArray * readingList;
    BOOL authenticated;
}

@property (nonatomic, copy) NSDictionary * subscriptions;
@property (nonatomic, copy) NSArray * readingList;

+(id)readerWithUsername:(NSString *)username password:(NSString *)password;

-(void)loadSubscriptions;
-(void)loadReadingList;

-(BOOL)subscribingTo:(NSString *)feedURL;
-(void)subscribeToFeed:(NSString *)feedURL;
-(void)unsubscribeFromFeed:(NSString *)feedURL;
-(void)markRead:(NSString *)itemGuid readFlag:(BOOL)flag;
-(void)markStarred:(NSString *)itemGuid starredFlag:(BOOL)flag;
-(void)setFolder:(NSString *)folderName forFeed:(NSString *)feedURL folderFlag:(BOOL)flag;
-(void)disableTag:(NSString *)tagName;
-(void)renameTagFrom:(NSString *)oldName to:(NSString *)newName;
-(void)renameFeed:(NSString *)feedURL to:(NSString *)newName;

-(BOOL)isAuthenticated;

@end
