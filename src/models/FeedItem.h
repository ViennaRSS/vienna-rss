//
//  FeedItem.h
//  Vienna
//
//  Created by Joshua Pore on 7/08/2015.
//  Copyright (c) 2015 uk.co.opencommunity. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FeedItem : NSObject {
    NSString * title;
    NSString * author;
    NSString * link;
    NSString * guid;
    NSDate * date;
    NSString * description;
    NSString * enclosure;
}

// Getters
-(NSString *)title;
-(NSString *)description;
-(NSString *)author;
-(NSString *)guid;
-(NSDate *)date;
-(NSString *)link;
-(NSString *)enclosure;

// Setters
-(void)setTitle:(NSString *)newTitle;
-(void)setDescription:(NSString *)newDescription;
-(void)setAuthor:(NSString *)newAuthor;
-(void)setDate:(NSDate *)newDate;
-(void)setGuid:(NSString *)newGuid;
-(void)setLink:(NSString *)newLink;
-(void)setEnclosure:(NSString *)newEnclosure;

@end
