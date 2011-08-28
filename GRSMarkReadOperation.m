//
//  GRSMarkReadOperation.m
//  Vienna
//
//  Created by Adam Hartford on 7/29/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRSMarkReadOperation.h"
#import "GoogleReader.h"
#import "ArticleRef.h"
#import "Folder.h"

@implementation GRSMarkReadOperation

@synthesize articles;
@synthesize readFlag;

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
    [googleReader loadReadingList];
    
    for (Article * article in [self articles])
    {
        NSDictionary * data = [self readingListDataForArticle:article];
        if (data)
        {
            [googleReader markRead:[data objectForKey:@"id"] readFlag:readFlag];
        }
    }
}

-(void)dealloc
{
    [articles release];
}

@end
