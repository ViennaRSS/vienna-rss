//
//  MMTabBarItem.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/29/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol MMTabBarItem <NSObject>

@optional

/**
 *  Title
 */
@property (copy)   NSString  *title;

/**
 *  Icon
 */
@property (strong) NSImage   *icon;

/**
 *  Large image
 */
@property (strong) NSImage   *largeImage;

/**
 *  Object count to display
 */
@property (assign) NSInteger objectCount;

/**
 *  YES: show object count, NO: do not show
 */
@property (assign) BOOL showObjectCount;

/**
 *  Color of object count badge
 */
@property (strong) NSColor   *objectCountColor;

/**
 *  Processing state
 */
@property (assign) BOOL isProcessing;

/**
 *  Edited state
 */
@property (assign) BOOL isEdited;

/**
 *  Returns YES if item has close button
 */
@property (assign) BOOL hasCloseButton;

@end

NS_ASSUME_NONNULL_END
