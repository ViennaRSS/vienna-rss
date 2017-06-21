//
//  GoogleReader.h
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011-2014 Vienna contributors (see Help/Acknowledgements for list of contributors). All rights reserved.
//

@import Foundation;

@class ActivityItem;
@class Article;
@class ASIHTTPRequest;
@class Folder;

@interface OpenReader : NSObject

+(OpenReader *)sharedManager;

// Check if an accessToken is available
@property (nonatomic, getter=isReady, readonly) BOOL ready;

-(void)loadSubscriptions;
-(void)clearAuthentication;
-(void)resetAuthentication;

-(void)subscribeToFeed:(NSString *)feedURL;
-(void)unsubscribeFromFeed:(NSString *)feedURL;
-(void)markRead:(Article *)article readFlag:(BOOL)flag;
-(void)markStarred:(Article *)article starredFlag:(BOOL)flag;
-(void)setFolderName:(NSString *)folderName forFeed:(NSString *)feedURL set:(BOOL)flag;
-(ASIHTTPRequest*)refreshFeed:(Folder*)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit;
@property (nonatomic, readonly) NSUInteger countOfNewArticles;

@end
