//
//  FeedItem.m
//  Vienna
//
//  Created by Joshua Pore on 7/08/2015.
//  Copyright (c) 2015 uk.co.opencommunity. All rights reserved.
//

#import "FeedItem.h"

@implementation FeedItem

/* init
 * Creates a FeedItem instance
 */
-(instancetype)init
{
    self = [super init];
    if (self) {
        _title = @"";
        _feedItemDescription = @"";
        _author = @"";
        _guid = @"";
        _date = nil;
        _link = @"";
        _enclosure = @"";
    }
    return self;
}


@end
