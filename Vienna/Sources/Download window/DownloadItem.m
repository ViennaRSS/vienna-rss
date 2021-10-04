//
//  DownloadItem.m
//  Vienna
//
//  Created by Steve on 10/7/05.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DownloadItem.h"

@interface DownloadItem ()

@property (readwrite, copy, nonatomic) NSImage *image;

@end

@implementation DownloadItem

- (void)setExpectedSize:(long long)expectedSize
{
    _expectedSize = expectedSize;
    self.size = 0;
}

- (void)setFilename:(NSString *)filename
{
    _filename = filename;

    // Force the image to be recached.
    self.image = nil;
}

- (NSImage *)image
{
    if (!_image) {
        NSString *extension = self.filename.pathExtension;
        _image = [NSWorkspace.sharedWorkspace iconForFileType:extension];
        if (!_image.valid) {
            _image = nil;
        } else {
            _image.size = NSMakeSize(32, 32);
        }
    }
    return [_image copy];
}

#pragma mark NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];

    if (self) {
        _filename = [coder decodeObject];
        [coder decodeValueOfObjCType:@encode(long long) at:&_size];
        _state = DownloadStateCompleted;
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.filename];
    [coder encodeValueOfObjCType:@encode(long long) at:&_size];
}

@end
