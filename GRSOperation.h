//
//  GRSOperation.h
//  Vienna
//
//  Created by Adam Hartford on 7/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GoogleReader;
@class Article;



@interface GRSOperation : NSOperation

+(GoogleReader *)sharedGoogleReader;
+(void)setFetchFlag:(BOOL)flag;
-(NSDictionary *)readingListDataForArticle:(Article *)article;

// Abstract
-(void)doMain;
-(void)handleError;

@end
