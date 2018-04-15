//
//  FakeModel.m
//  MMTabBarView Demo
//
//  Created by John Pannell on 12/19/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import "DemoFakeModel.h"

@implementation DemoFakeModel

- (instancetype)init {
	if (self = [super init]) {
		_isProcessing = NO;
		_icon = nil;
		_iconName = nil;
        _largeImage = nil;
		_objectCount = 2;
		_isEdited = NO;
        _hasCloseButton = YES;
        _title = @"Untitled";
        _objectCountColor = nil;
        _showObjectCount = YES;
	}
	return self;
}

@end
