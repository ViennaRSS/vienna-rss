//
//  DownloadManager.h
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

#import <Cocoa/Cocoa.h>

// Download states
#define DOWNLOAD_INIT			0
#define DOWNLOAD_STARTED		1
#define DOWNLOAD_COMPLETED		2
#define DOWNLOAD_FAILED			3
#define DOWNLOAD_CANCELLED		4

@interface DownloadItem : NSObject<NSCoding> {
	long long expectedSize;
	long long fileSize;
	int state;
	NSImage * image;
	NSString * filename;
	NSURLDownload * download;
	NSDate * startTime;
}

// Public functions
-(void)setState:(int)newState;
-(void)setSize:(long long)newSize;
-(void)setExpectedSize:(long long)newExpectedSize;
-(void)setDownload:(NSURLDownload *)theDownload;
-(void)setFilename:(NSString *)theFilename;
-(void)setStartTime:(NSDate *)newStartTime;
-(int)state;
-(long long)expectedSize;
-(long long)size;
-(NSURLDownload *)download;
-(NSString *)filename;
-(NSImage *)image;
-(NSDate *)startTime;
@end

@interface DownloadManager : NSObject {
	NSMutableArray * downloadsList;
	int activeDownloads;
}

// Public functions
+(DownloadManager *)sharedInstance;
+(BOOL)isFileDownloaded:(NSString *)filename;
+(NSString *)fullDownloadPath:(NSString *)filename;
-(NSArray *)downloadsList;
-(int)activeDownloads;
-(void)clearList;
-(void)cancelItem:(DownloadItem *)item;
-(void)removeItem:(DownloadItem *)item;
-(void)downloadFileFromURL:(NSString *)url;
@end
