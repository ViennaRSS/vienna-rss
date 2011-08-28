//
//  GRSMarkStarredOperation.m
//  Vienna
//
//  Created by Adam Hartford on 7/29/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSMarkStarredOperation.h"
#import "GoogleReader.h"
#import "ArticleRef.h"
#import "Folder.h"

@implementation GRSMarkStarredOperation
@synthesize articles;
@synthesize starredFlag;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)doMain
{
    GoogleReader * googleReader = [GRSOperation sharedGoogleReader];
    [googleReader loadSubscriptions];
    
    for (Article * article in [self articles])
    {
        NSDictionary * data = [self readingListDataForArticle:article];
        if (data)
        {
            [googleReader markStarred:[data objectForKey:@"id"] starredFlag:starredFlag];
        }
    }
}

-(void)dealloc
{
    [articles release];
}

@end
