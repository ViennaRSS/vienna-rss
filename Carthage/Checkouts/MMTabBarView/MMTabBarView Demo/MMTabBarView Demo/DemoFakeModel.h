//
//  FakeModel.h
//  MMTabBarView Demo
//
//  Created by John Pannell on 12/19/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

#if __has_feature(modules)
@import MMTabBarView;
#else
#import <MMTabBarView/MMTabBarView.h>
#endif

@interface DemoFakeModel : NSObject <MMTabBarItem>

@property (copy)   NSString *title;
@property (strong) NSImage  *largeImage;
@property (strong) NSImage  *icon;
@property (strong) NSString *iconName;

@property (assign) BOOL      isProcessing;
@property (assign) NSInteger objectCount;
@property (strong) NSColor   *objectCountColor;
@property (assign) BOOL      showObjectCount;
@property (assign) BOOL      isEdited;
@property (assign) BOOL      hasCloseButton;

// designated initializer
- (instancetype)init NS_DESIGNATED_INITIALIZER;

@end
