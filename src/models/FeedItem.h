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

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *description;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *guid;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, copy) NSString *enclosure;

@end
