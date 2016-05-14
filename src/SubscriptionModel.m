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
*  @param feedURLString A pointer to the URL to verify
*
*  @return A pointer to a verified URL
*/
-(NSURL *)verifiedFeedURLFromURL:(NSURL *)rssFeedURL
{
    // If the URL starts with feed or ends with a feed extension then we're going
    // assume it's a feed.
    if ([rssFeedURL.scheme isEqualToString:@"feed"]) {
        return rssFeedURL;
    }
    
    if ([rssFeedURL.pathExtension isEqualToString:@"rss"] || [rssFeedURL.pathExtension isEqualToString:@"rdf"] || [rssFeedURL.pathExtension isEqualToString:@"xml"]) {
        return rssFeedURL;
    }
    
    // OK. Now we're at the point where can't be reasonably sure that
    // the URL points to a feed. Time to look at the content.
    if (rssFeedURL.scheme == nil)
    {
        rssFeedURL = [NSURL URLWithString:[@"http://" stringByAppendingString:rssFeedURL.absoluteString]];
    }
    
    // Use this rather than [NSData dataWithContentsOfURL:],
    // because that method will not necessarily unzip gzipped content from server.
    // Thanks to http://www.omnigroup.com/mailman/archive/macosx-dev/2004-March/051547.html
    NSData * urlContent = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:rssFeedURL] returningResponse:NULL error:NULL];
    if (urlContent == nil)
        return rssFeedURL;
    
    NSMutableArray * linkArray = [NSMutableArray arrayWithCapacity:10];
    // Get all the feeds on the page. If there's more than one, use the first one.
	// TODO : if there are multiple feeds, we should put up an UI inviting the user to pick one
	// That would require modifying extractFeeds to provide URL strings and titles
	// as feeds' links are often advertised in the HTML head
	// as <link rel="alternate" type="application/rss+xml" title="..." href="...">
	NSURL * myURL;
    if ([RichXMLParser extractFeeds:urlContent toArray:linkArray])
    {
        NSString * feedPart = linkArray.firstObject;
		myURL = [NSURL URLWithString:feedPart relativeToURL:rssFeedURL];
		if (myURL ==nil)
		{
			// try cleaning up the string : unescape then re-add escapes
			NSString * urlString = [[feedPart stringByUnescapingExtendedCharacters] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			myURL = [NSURL URLWithString:urlString relativeToURL:rssFeedURL];
		}
    }
    return myURL;
}


@end
