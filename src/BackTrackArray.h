//
//  BackTrackArray.h
//  Vienna
//
//  Created by Steve on Fri Mar 12 2004.
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

#import <Cocoa/Cocoa.h>

@interface BackTrackArray : NSObject {
	NSMutableArray * array;
	NSUInteger  maxItems;
	NSInteger queueIndex;
}

// Accessor functions
-(instancetype)initWithMaximum:(NSUInteger)theMax /*NS_DESIGNATED_INITIALIZER*/;
@property (nonatomic, getter=isAtStartOfQueue, readonly) BOOL atStartOfQueue;
@property (nonatomic, getter=isAtEndOfQueue, readonly) BOOL atEndOfQueue;
-(void)addToQueue:(NSInteger)folderId guid:(NSString *)guid;
-(BOOL)nextItemAtQueue:(NSInteger *)folderId guidPointer:(NSString **)guidPtr;
-(BOOL)previousItemAtQueue:(NSInteger *)folderId guidPointer:(NSString **)guidPtr;
@end
