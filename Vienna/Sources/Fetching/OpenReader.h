//
//  OpenReader.h
//  Vienna
//
//  Created by Adam Hartford on 7/7/11.
//  Copyright 2011-2018 Vienna contributors (see menu item 'About Vienna' for list of contributors). All rights reserved.
//

@import Foundation;

@class ActivityItem;
@class Article;
@class Folder;

@interface OpenReader : NSObject

+(OpenReader *)sharedManager;

@property (readonly, copy) NSString *statusMessage;

// Check if an accessToken is available
@property (nonatomic, getter=isReady, readonly) BOOL ready;
@property (nonatomic) NSOperation * unreadCountOperation;

-(void)loadSubscriptions;
-(void)clearAuthentication;
-(void)resetAuthentication;

-(void)subscribeToFeed:(NSString *)feedURL withLabel:(NSString *)label;
-(void)unsubscribeFromFeedIdentifier:(NSString *)feedIdentifier;
-(void)markRead:(Article *)article readFlag:(BOOL)flag;
-(void)markStarred:(Article *)article starredFlag:(BOOL)flag;
-(void)markAllReadInFolder:(Folder *)folder;
-(void)setFolderLabel:(NSString *)folderName forFeed:(NSString *)feedIdentifier set:(BOOL)flag;
-(void)setFolderTitle:(NSString *)folderName forFeed:(NSString *)feedIdentifier;
-(void)refreshFeed:(Folder*)thisFolder withLog:(ActivityItem *)aItem shouldIgnoreArticleLimit:(BOOL)ignoreLimit;
-(void)resetCountOfNewArticles;
@property (nonatomic, readonly) NSUInteger countOfNewArticles;

@end
