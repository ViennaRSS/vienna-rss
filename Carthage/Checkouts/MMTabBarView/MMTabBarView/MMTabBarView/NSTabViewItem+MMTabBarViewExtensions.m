//
//  NSTabViewItem+MMTabBarViewExtensions.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/29/12.
//  Copyright (c) 2016 Michael Monscheuer. All rights reserved.
//

#if __has_feature(modules)
@import ObjectiveC.runtime;
#else
#import <objc/runtime.h>
#endif

#import "NSTabViewItem+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSTabViewItem (MMTabBarViewExtensions)

static char largeImage_key; //has a unique address (identifier)
static char icon_key;
static char isProcessing_key;
static char isEdited_key;
static char hasCloseButton_key;
static char objectCount_key;
static char objectCountColor_key;
static char showObjectCount_key;

- (nullable NSImage *)largeImage
{
    return objc_getAssociatedObject(self,&largeImage_key);
}  
 
- (void)setLargeImage:(nullable NSImage *)newImage
{
    objc_setAssociatedObject(self,&largeImage_key,newImage,
                             OBJC_ASSOCIATION_RETAIN);
}  

- (nullable NSImage *)icon
{
    return objc_getAssociatedObject(self,&icon_key);
} 
 
- (void)setIcon:(nullable NSImage *)newImage
{
    objc_setAssociatedObject(self,&icon_key,newImage,
                             OBJC_ASSOCIATION_RETAIN);
}  

- (BOOL)isProcessing
{
    return [(NSNumber*) objc_getAssociatedObject(self,&isProcessing_key) boolValue];
}  
 
- (void)setIsProcessing:(BOOL)flag
{
    NSNumber *boolValue = [NSNumber numberWithBool:flag];
    objc_setAssociatedObject(self,&isProcessing_key,boolValue,
                             OBJC_ASSOCIATION_RETAIN);
} 

- (NSInteger)objectCount
{
    return [(NSNumber*) objc_getAssociatedObject(self,&objectCount_key) integerValue];
}

- (void)setObjectCount:(NSInteger)value
{
    NSNumber *integerValue = [NSNumber numberWithInteger:value];
    objc_setAssociatedObject(self,&objectCount_key,integerValue,
                             OBJC_ASSOCIATION_RETAIN);    
}

- (nullable NSColor *)objectCountColor
{
    return objc_getAssociatedObject(self,&objectCountColor_key);
}

- (void)setObjectCountColor:(nullable NSColor *)aColor
{
    objc_setAssociatedObject(self,&objectCountColor_key,aColor,
                             OBJC_ASSOCIATION_RETAIN);    
}

- (BOOL)showObjectCount
{
    return [(NSNumber*) objc_getAssociatedObject(self,&showObjectCount_key) boolValue];
}

- (void)setShowObjectCount:(BOOL)flag
{
    NSNumber *boolValue = [NSNumber numberWithBool:flag];
    objc_setAssociatedObject(self,&showObjectCount_key,boolValue,
                             OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)isEdited
{
    return [(NSNumber*) objc_getAssociatedObject(self,&isEdited_key) boolValue];
}

- (void)setIsEdited:(BOOL)flag
{
    NSNumber *boolValue = [NSNumber numberWithBool:flag];
    objc_setAssociatedObject(self,&isEdited_key,boolValue,
                             OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)hasCloseButton
{
    return [(NSNumber*) objc_getAssociatedObject(self,&hasCloseButton_key) boolValue];
}
 
- (void)setHasCloseButton:(BOOL)flag
{
    NSNumber *boolValue = [NSNumber numberWithBool:flag];
    objc_setAssociatedObject(self,&hasCloseButton_key,boolValue,
                             OBJC_ASSOCIATION_RETAIN);
} 

@end

NS_ASSUME_NONNULL_END
