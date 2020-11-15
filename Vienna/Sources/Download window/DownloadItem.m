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

@implementation DownloadItem

/* init
 * Initialise a new DownloadItem object
 */
-(instancetype)init
{
	if ((self = [super init]) != nil)
	{
		state = DownloadStateInit;
		expectedSize = 0;
		fileSize = 0;
		filename = nil;
		download = nil;
		image = nil;
		startTime = nil;
	}
	return self;
}

/* initWithCoder
 * Initalises a decoded object. All decoded objects are assumed to be
 * completed downloads.
 */
-(instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]) != nil)
	{
		self.filename = [coder decodeObject];
		[coder decodeValueOfObjCType:@encode(long long) at:&fileSize];
		state = DownloadStateCompleted;
	}
	return self;
}

/* encodeWithCoder
 * Encodes a single DownloadItem object for archiving.
 */
-(void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:filename];
	[coder encodeValueOfObjCType:@encode(long long) at:&fileSize];
}

/* setState
 * Sets the download state.
 */
-(void)setState:(DownloadState)newState
{
	state = newState;
}

/* state
 * Returns the download state.
 */
-(DownloadState)state
{
	return state;
}

/* setExpectedSize
 * Sets the expected file size.
 */
-(void)setExpectedSize:(long long)newExpectedSize
{
	expectedSize = newExpectedSize;
	fileSize = 0;
}

/* expectedSize
 * Returns the expected total size of the item.
 */
-(long long)expectedSize
{
	return expectedSize;
}

/* setSize
 * Updates the file size.
 */
-(void)setSize:(long long)newSize
{
	fileSize = newSize;
}

/* size
 * Returns the file size.
 */
-(long long)size
{
	return fileSize;
}

/* setDownload
 * Sets the NSURLDownload object associated with this download.
 */
-(void)setDownload:(NSURLDownload *)theDownload
{
	download = theDownload;
}

/* download
 * Returns the NSURLDownload object associated with this download.
 */
-(NSURLDownload *)download
{
	return download;
}

/* setFilename
 * Sets the filename associated with this download item. The specified filename
 * may contain a path but only the last path component is stored.
 */
-(void)setFilename:(NSString *)theFilename
{
	filename = theFilename;

	// Force the image to be recached.
	image = nil;
}

/* filename
 * Returns the download item filename.
 */
-(NSString *)filename
{
	return filename;
}

/* image
 * Return the file image. This is always computed here.
 */
-(NSImage *)image
{
	if (image == nil)
	{
		image = [[NSWorkspace sharedWorkspace] iconForFileType:self.filename.pathExtension];
		if (!image.valid)
			image = nil;
		else
		{
			image.size = NSMakeSize(32, 32);
		}
	}
	return image;
}

/* setStartTime
 * Set the date/time when this file download started.
 */
-(void)setStartTime:(NSDate *)newStartTime
{
	startTime = newStartTime;
}

/* startTime
 * Returns the date/time when this file download started.
 */
-(NSDate *)startTime
{
	return startTime;
}

@end
