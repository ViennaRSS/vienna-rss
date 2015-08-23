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
-(id)init
{
    if ((self = [super init]) != nil)
    {
        [self setTitle:@""];
        [self setDescription:@""];
        [self setAuthor:@""];
        [self setGuid:@""];
        [self setDate:nil];
        [self setLink:@""];
        [self setEnclosure:@""];
    }
    return self;
}

/* setEnclosure
 * Set the item title.
 */
-(void)setEnclosure:(NSString *)newEnclosure
{
    enclosure = newEnclosure;
}

/* setTitle
 * Set the item title.
 */
-(void)setTitle:(NSString *)newTitle
{
    title = newTitle;
}

/* setDescription
 * Set the item description.
 */
-(void)setDescription:(NSString *)newDescription
{
    description = newDescription;
}

/* setAuthor
 * Set the item author.
 */
-(void)setAuthor:(NSString *)newAuthor
{
    author = newAuthor;
}

/* setDate
 * Set the item date
 */
-(void)setDate:(NSDate *)newDate
{
    date = newDate;
}

/* setGuid
 * Set the item GUID.
 */
-(void)setGuid:(NSString *)newGuid
{
    guid = newGuid;
}

/* setLink
 * Set the item link.
 */
-(void)setLink:(NSString *)newLink
{
    link = newLink;
}

/* title
 * Returns the item title.
 */
-(NSString *)title
{
    return title;
}

/* description
 * Returns the item description
 */
-(NSString *)description
{
    return description;
}

/* author
 * Returns the item author
 */
-(NSString *)author
{
    return author;
}

/* date
 * Returns the item date
 */
-(NSDate *)date
{
    return date;
}

/* guid
 * Returns the item GUID.
 */
-(NSString *)guid
{
    return guid;
}

/* link
 * Returns the item link.
 */
-(NSString *)link
{
    return link;
}

/* enclosure
 * Returns the associated enclosure.
 */
-(NSString *)enclosure
{
    return enclosure;
}

/* dealloc
 * Clean up when we're released.
 */
-(void)dealloc
{
    guid=nil;
    title=nil;
    description=nil;
    author=nil;
    date=nil;
    link=nil;
    enclosure=nil;
}
@end