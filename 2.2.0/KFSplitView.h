//
// KFSplitView.h
// KFSplitView v. 1.3, 11/27/2004
//
// Copyright (c) 2003-2004 Ken Ferry. Some rights reserved.
// http://homepage.mac.com/kenferry/software.html
//
// This work is licensed under a Creative Commons license:
// http://creativecommons.org/licenses/by-nc/1.0/
//
// Send me an email if you have any problems (after you've read what there is to read).
//
// You can reach me at kenferry at the domain mac.com.

#import <AppKit/AppKit.h>

@interface KFSplitView:NSSplitView
{
    // retained
    NSMutableSet *kfCollapsedSubviews;
    NSMutableArray *kfDividerRects;
    NSString *kfPositionAutosaveName;
    NSCursor *kfIsVerticalResizeCursor;
    NSCursor *kfNotIsVerticalResizeCursor;

    // not retained
    NSCursor *kfCurrentResizeCursor;
    NSUserDefaults *kfDefaults;
    NSNotificationCenter *kfNotificationCenter;
    BOOL kfIsVertical;
    id kfDelegate;
}

// sets the collapse-state of a subview, which is completely independent
// of that subview's frame (as in NSSplitView).  (Sometime) after calling this
// you'll need to tell the splitview to resize its subviews.
// Normally, that would be this call:
//    [kfSplitView resizeSubviewsWithOldSize:[kfSplitView bounds].size];
- (void)setSubview:(NSView *)subview isCollapsed:(BOOL)flag;

// To find documentation for these methods refer to Apple's NSWindow
// documentation for the corresponding methods (e.g. -setFrameAutosaveName:).
// To use an autosave name, call -setPositionAutosaveName: from the -awakeFromNib
// method of a controller.
+ (void)removePositionUsingName:(NSString *)name;
- (void)savePositionUsingName:(NSString *)name;
- (BOOL)setPositionUsingName:(NSString *)name;
- (BOOL)setPositionAutosaveName:(NSString *)name;
- (NSString *)positionAutosaveName;
- (void)setPositionFromPlistObject:(id)string;
- (id)plistObjectWithSavedPosition;

-(NSArray *)layout;
-(void)setLayout:(NSArray *)newLayout;

@end

@interface NSObject(KFSplitViewDelegate)

// in notification argument 'object' will be sender, 'userInfo' will have key @"subview"
- (void)splitViewDidCollapseSubview:(NSNotification *)notification;
- (void)splitViewDidExpandSubview:(NSNotification *)notification;

- (void)splitView:(id)sender didDoubleClickInDivider:(int)index;
- (void)splitView:(id)sender didFinishDragInDivider:(int)index;

@end

// notifications: 'object' will be sender, 'userInfo' will have key @"subview".
// The delegate is automatically registered to receive these notifications.
extern NSString *KFSplitViewDidCollapseSubviewNotification;
extern NSString *KFSplitViewDidExpandSubviewNotification;

