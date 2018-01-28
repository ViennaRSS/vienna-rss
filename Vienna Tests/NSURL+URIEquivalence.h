//
//  NSURL+URIEquivalence.h
//  Vienna
//
//  Copyright © 2016 uk.co.opencommunity. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (URIEquivalence)

/**
 NSURL equivalency test
 http://stackoverflow.com/questions/12310258/reliable-way-to-compare-two-nsurl-or-one-nsurl-and-an-nsstring
 */
- (BOOL)isEquivalent:(NSURL *)aURL;

@end
