//
//  SubscriptionModel.m
//  Vienna
//
//  Created by Joshua Pore on 4/10/2014.
//  Copyright (c) 2014 uk.co.opencommunity. All rights reserved.
//

#import "SubscriptionModel.h"
#import "RichXMLParser.h"
#import "StringExtensions.h"

@implementation SubscriptionModel


/*!
* Verifies the specified URL. This is the auto-discovery phase that is described at
* http://diveintomark.org/archives/2002/08/15/ultraliberal_rss_locator
*
* Basically we examine the data at the specified URL and if it is an RSS feed
* then OK. Otherwise if it looks like an HTML page, we scan for links in the
* page text.
*
*  @param feedURLString A pointer to the NSString containing the URL to verify
*
*  @return A pointer to an NSString containing a verified URL
*/
+(NSString *)verifiedFeedURLFromString:(NSString *)feedURLString
{
    NSString * urlString = [[feedURLString trim] lowercaseString];
    
    // If the URL starts with feed or ends with a feed extension then we're going
    // assume it's a feed.
    if ([urlString hasPrefix:@"feed:"])
        return feedURLString;
    
    if ([urlString hasSuffix:@".rss"] || [urlString hasSuffix:@".rdf"] || [urlString hasSuffix:@".xml"])
        return feedURLString;
    
    // OK. Now we're at the point where can't be reasonably sure that
    // the URL points to a feed. Time to look at the content.
    NSURL * url = [NSURL URLWithString:urlString];
    if ([url scheme] == nil)
    {
        urlString = [@"http://" stringByAppendingString:urlString];
        url = [NSURL URLWithString:urlString];
    }
    
    // Use this rather than [NSData dataWithContentsOfURL:],
    // because that method will not necessarily unzip gzipped content from server.
    // Thanks to http://www.omnigroup.com/mailman/archive/macosx-dev/2004-March/051547.html
    NSData * urlContent = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url] returningResponse:NULL error:NULL];
    if (urlContent == nil)
        return feedURLString;
    
    // Get all the feeds on the page. If there's more than one, use the first one. Later we
    // could put up UI inviting the user to pick one but I don't know if it makes sense to
    // do this. How would they know which one would be best? We'd have to query each feed, get
    // the title and then ask them.
    NSMutableArray * linkArray = [NSMutableArray arrayWithCapacity:10];
    if ([RichXMLParser extractFeeds:urlContent toArray:linkArray])
    {
        NSString * feedPart = [linkArray objectAtIndex:0];
        if (![feedPart hasPrefix:@"http:"] && ![feedPart hasPrefix:@"https:"])
        {
            if (![urlString hasSuffix:@"/"])
                urlString = [urlString stringByAppendingString:@"/"];
            feedURLString = [urlString stringByAppendingString:feedPart];
        }
        else
            feedURLString = feedPart;
    }
    return feedURLString;
}


@end
