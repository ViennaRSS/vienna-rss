//
//  MMTabDragView.h
//  MMTabBarView
//
//  Created by Kent Sutherland on 6/17/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MMTabDragView : NSView

@property (assign) CGFloat alpha;
@property (strong) NSImage *image;
@property (strong) NSImage *alternateImage;

@end

NS_ASSUME_NONNULL_END
