//
//  MMAppDelegate.h
//  MMTabBarView Demo
//
//  Created by Michael Monscheuer on 9/19/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

@interface MMAppDelegate : NSObject <NSApplicationDelegate>

- (IBAction)newWindow:(id)pSender;

@end
