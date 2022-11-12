//
//  DateFormatterExtension.m
//  Vienna
//
//  Copyright 2017
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DateFormatterExtension.h"

@implementation NSDateFormatter (RelativeDateFormatter)

+ (NSDateFormatter *)relativeDateFormatter {
    static NSDateFormatter *_relativeDateFormatter;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        _relativeDateFormatter = [self new];
        _relativeDateFormatter.doesRelativeDateFormatting = YES;
        _relativeDateFormatter.dateStyle = NSDateFormatterShortStyle;
        _relativeDateFormatter.timeStyle = NSDateFormatterShortStyle;
        _relativeDateFormatter.formattingContext = NSFormattingContextDynamic;
    });

    return _relativeDateFormatter;
}

+ (NSString *)relativeDateStringFromDate:(NSDate *)date {
    return [NSDateFormatter.relativeDateFormatter stringFromDate:date];
}

@end
