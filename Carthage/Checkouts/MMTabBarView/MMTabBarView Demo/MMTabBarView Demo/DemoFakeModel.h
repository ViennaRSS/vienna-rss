//
//  FakeModel.h
//  MMTabBarView Demo
//
//  Created by John Pannell on 12/19/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <MMTabBarView/MMTabBarItem.h>

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
