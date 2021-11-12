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

static NSString *const VNACodingKeyFilename = @"filename";
static NSString *const VNACodingKeySize = @"size";

@interface DownloadItem ()

@property (readwrite, nonatomic) NSImage *image;

@end

@implementation DownloadItem

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

// MARK: - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];

    if (self) {
        if (coder.allowsKeyedCoding) {
            _filename = [coder decodeObjectOfClass:[NSString class]
                                            forKey:VNACodingKeyFilename];
            _size = [coder decodeInt64ForKey:VNACodingKeySize];
        } else {
            // NSUnarchiver is deprecated since macOS 10.13 and replaced with
            // NSKeyedUnarchiver. For backwards-compatibility with NSArchiver,
            // decoding using NSUnarchiver is still supported.
            //
            // Important: The order in which the values are decoded must match
            // the order in which they were encoded. Changing the code below can
            // lead to decoding failure.
            _filename = [coder decodeObject];
            [coder decodeValueOfObjCType:@encode(long long) at:&_size];
        }
        _state = DownloadStateCompleted;
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (coder.allowsKeyedCoding) {
        [coder encodeObject:self.filename forKey:VNACodingKeyFilename];
        [coder encodeInt64:self.size forKey:VNACodingKeySize];
    } else {
        // NSArchiver is deprecated since macOS 10.13 and replaced with
        // NSKeyedArchiver. For testing purposes only, encoding with NSArchiver
        // is still supported.
        //
        // Important: The order in which the values are encoded must match the
        // the order in which they will be decoded. Changing the code below can
        // lead to decoding failure.
        [coder encodeObject:self.filename];
        [coder encodeValueOfObjCType:@encode(long long) at:&_size];
    }
}

@end
