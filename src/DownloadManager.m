//
//  DownloadManager.m
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

#import "DownloadManager.h"
#import "AppController.h"
#import "Constants.h"
#import "Preferences.h"

// Private functions
@interface DownloadManager (Private)
	-(void)archiveDownloadsList;
	-(void)unarchiveDownloadsList;
	-(void)notifyDownloadItemChange:(DownloadItem *)item;
@end

@implementation DownloadItem

/* init
 * Initialise a new DownloadItem object
 */
-(instancetype)init
{
	if ((self = [super init]) != nil)
	{
		state = DOWNLOAD_INIT;
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
		state = DOWNLOAD_COMPLETED;
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
-(void)setState:(NSInteger)newState
{
	state = newState;
}

/* state
 * Returns the download state.
 */
-(NSInteger)state
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

@implementation DownloadManager

/* sharedInstance
 * There's just one download manager, so return the single shared instance
 * that controls access to it.
 */
+(DownloadManager *)sharedInstance
{
	// Singleton
	static DownloadManager * _sharedDownloadManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_sharedDownloadManager = [[DownloadManager alloc] init];
		[_sharedDownloadManager unarchiveDownloadsList];
	});
	return _sharedDownloadManager;
}

/* init
 * Initialise the DownloadManager object.
 */
-(instancetype)init
{
	if ((self = [super init]) != nil)
	{
		downloadsList = [[NSMutableArray alloc] init];
		activeDownloads = 0;
	}
	return self;
}

/* downloadsList
 * Return the array of DownloadItems.
 */
-(NSArray *)downloadsList
{
	return [downloadsList copy];
}

/* activeDownloads
 * Return the number of downloads in progress.
 */
-(NSInteger)activeDownloads
{
	return activeDownloads;
}

/* clearList
 * Remove all completed items from the list.
 */
-(void)clearList
{
	NSInteger index = downloadsList.count - 1;
	while (index >= 0)
	{
		DownloadItem * item = downloadsList[index--];
		if (item.state != DOWNLOAD_STARTED)
			[downloadsList removeObject:item];
	}
	[self notifyDownloadItemChange:nil];
	[self archiveDownloadsList];
}

/* archiveDownloadsList
 * Archive the downloads list to the preferences.
 */
-(void)archiveDownloadsList
{
	NSMutableArray * listArray = [[NSMutableArray alloc] initWithCapacity:downloadsList.count];

	for (DownloadItem * item in downloadsList)
		[listArray addObject:[NSArchiver archivedDataWithRootObject:item]];

	[[Preferences standardPreferences] setArray:listArray forKey:MAPref_DownloadsList];
}

/* unarchiveDownloadsList
 * Unarchive the downloads list from the preferences.
 */
-(void)unarchiveDownloadsList
{
	NSArray * listArray = [[Preferences standardPreferences] arrayForKey:MAPref_DownloadsList];
	if (listArray != nil)
	{
		for (NSData * dataItem in listArray)
			[downloadsList addObject:[NSUnarchiver unarchiveObjectWithData:dataItem]];
	}
}

/* removeItem
 * Remove the specified item from the list.
 */
-(void)removeItem:(DownloadItem *)item
{	
	[downloadsList removeObject:item];
	[self archiveDownloadsList];
}

/* cancelItem
 * Abort the specified item and remove it from the list
 */
-(void)cancelItem:(DownloadItem *)item
{	
	[item.download cancel];
	[item setState:DOWNLOAD_CANCELLED];
	NSAssert(activeDownloads > 0, @"cancelItem called with zero activeDownloads count!");
	--activeDownloads;
	[self notifyDownloadItemChange:item];
	[downloadsList removeObject:item];
	[self archiveDownloadsList];
}

/* downloadFile
 * Downloads a file from the specified URL.
 */
-(void)downloadFileFromURL:(NSString *)url
{
	NSString * filename = [NSURL URLWithString:url].lastPathComponent;
	NSString * destPath = [DownloadManager fullDownloadPath:filename];
	NSURLRequest * theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
	NSURLDownload * theDownload = [[NSURLDownload alloc] initWithRequest:theRequest delegate:(id)self];
	if (theDownload)
	{
		DownloadItem * newItem = [DownloadItem new];
		[newItem setState:DOWNLOAD_INIT];
		newItem.download = theDownload;
		newItem.filename = filename;
		[downloadsList addObject:newItem];

		// The following line will stop us getting decideDestinationWithSuggestedFilename.
		[theDownload setDestination:destPath allowOverwrite:YES];
		
	}
}

/* itemForDownload
 * Retrieves the DownloadItem for the given NSURLDownload object. We scan from the
 * last item since the odds are that the one we want will be at the end given that
 * new items are always appended to the list.
 */
-(DownloadItem *)itemForDownload:(NSURLDownload *)download
{
	NSInteger index = downloadsList.count - 1;
	while (index >= 0)
	{
		DownloadItem * item = downloadsList[index--];
		if (item.download == download)
			return item;
	}
	return nil;
}

/* fullDownloadPath
 * Given a filename, returns the fully qualified path to where the file will be downloaded by
 * using the user's preferred download folder. If that folder is absent then we default to
 * downloading to the desktop instead.
 */
+(NSString *)fullDownloadPath:(NSString *)filename
{
	NSString * downloadPath = [Preferences standardPreferences].downloadFolder;
    NSString * decodedFilename = [filename stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSFileManager * fileManager = [NSFileManager defaultManager];
	BOOL isDir = YES;

	if (![fileManager fileExistsAtPath:downloadPath isDirectory:&isDir] || !isDir)
		downloadPath = @"~/Desktop";
	
	return [downloadPath.stringByExpandingTildeInPath stringByAppendingPathComponent:decodedFilename];
}

/* isFileDownloaded
 * Looks up the specified file in the download list to determine if it is being downloaded. If
 * not, then it looks up the file in the workspace.
 */
+(BOOL)isFileDownloaded:(NSString *)filename
{
    NSString * decodedFilename = [filename stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	DownloadManager * downloadManager = [DownloadManager sharedInstance];
	NSInteger count = downloadManager.downloadsList.count;
	NSInteger index;

	NSString * firstFile = decodedFilename.stringByStandardizingPath;

	for (index = 0; index < count; ++index)
	{
		DownloadItem * item = downloadManager.downloadsList[index];
		NSString * secondFile = decodedFilename.stringByStandardizingPath;
		
		if ([firstFile compare:secondFile options:NSCaseInsensitiveSearch] == NSOrderedSame)
		{
			if (item.state != DOWNLOAD_COMPLETED)
				return NO;
			
			// File completed download but possibly moved or deleted after download
			// so check the file system.
			return [[NSFileManager defaultManager] fileExistsAtPath:secondFile];
		}
	}
	return NO;
}

/* notifyDownloadItemChange
 * Send a notification that the specified download item has changed.
 */
-(void)notifyDownloadItemChange:(DownloadItem *)item
{
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MA_Notify_DownloadsListChange" object:item];
}

/* downloadDidBegin
 * A download has started.
 */
-(void)downloadDidBegin:(NSURLDownload *)download
{
	DownloadItem * theItem = [self itemForDownload:download];
	if (theItem == nil)
	{
		theItem = [[DownloadItem alloc] init];
		theItem.download = download;
		[downloadsList addObject:theItem];
	}
	[theItem setState:DOWNLOAD_STARTED];
	if (theItem.filename == nil)
		theItem.filename = download.request.URL.path;

	// Keep count of active downloads
	++activeDownloads;
	
	// Record the time we started. We'll need this to work out the remaining
	// time and the number of KBytes/second we're getting
	theItem.startTime = [NSDate date];
	[self notifyDownloadItemChange:theItem];

	// If there's no download window visible, display one now.
	[APPCONTROLLER conditionalShowDownloadsWindow:self];
}

/* downloadDidFinish
 * A download has completed. Mark the associated DownloadItem as completed.
 */
-(void)downloadDidFinish:(NSURLDownload *)download
{
	DownloadItem * theItem = [self itemForDownload:download];
	[theItem setState:DOWNLOAD_COMPLETED];
	NSAssert(activeDownloads > 0, @"downloadDidFinish called with zero activeDownloads count!");
	--activeDownloads;
	[self notifyDownloadItemChange:theItem];
	[self archiveDownloadsList];

	NSString * filename = theItem.filename.lastPathComponent;
	if (filename == nil)
		filename = theItem.filename;

	NSMutableDictionary * contextDict = [[NSMutableDictionary alloc] init];
	[contextDict setValue:@MA_GrowlContext_DownloadCompleted forKey:@"ContextType"];
	[contextDict setValue:theItem.filename forKey:@"ContextData"];
	
	[APPCONTROLLER growlNotify:contextDict
							title:NSLocalizedString(@"Download completed", nil)
					  description:[NSString stringWithFormat:NSLocalizedString(@"File %@ downloaded", nil), filename]
				 notificationName:NSLocalizedString(@"Growl download completed", nil)];
	
	// Post a notification when the download completes.
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_DownloadCompleted" object:filename];

}

/* didFailWithError
 * A download failed with an error. Mark the associated DownloadItem as broken.
 */
-(void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	DownloadItem * theItem = [self itemForDownload:download];
	[theItem setState:DOWNLOAD_FAILED];
	NSAssert(activeDownloads > 0, @"didFailWithError called with zero activeDownloads count!");
	--activeDownloads;
	[self notifyDownloadItemChange:theItem];
	[self archiveDownloadsList];

	NSString * filename = theItem.filename.lastPathComponent;
	if (filename == nil)
		filename = theItem.filename;

	NSMutableDictionary * contextDict = [[NSMutableDictionary alloc] init];
	[contextDict setValue:@MA_GrowlContext_DownloadFailed forKey:@"ContextType"];
	[contextDict setValue:theItem.filename forKey:@"ContextData"];
	
	[APPCONTROLLER growlNotify:contextDict
							title:NSLocalizedString(@"Download failed", nil)
					  description:[NSString stringWithFormat:NSLocalizedString(@"File %@ failed to download", nil), filename]
				 notificationName:NSLocalizedString(@"Growl download failed", nil)];

}

/* didReceiveDataOfLength
 * The download received additional data of the specified size.
 */
-(void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	DownloadItem * theItem = [self itemForDownload:download];
	theItem.size = theItem.size + length;

	// TODO: How many bytes are we getting each second?
	
	// TODO: And the elapsed time until we're done?

	[self notifyDownloadItemChange:theItem];
}

/* didReceiveResponse
 * Called once after we have the initial response from the server. Get and save the
 * expected file size.
 */
-(void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response
{
	DownloadItem * theItem = [self itemForDownload:download];
	theItem.expectedSize = response.expectedContentLength;
	[self notifyDownloadItemChange:theItem];
}

/* willResumeWithResponse
 * The download is about to resume from the specified position.
 */
-(void)download:(NSURLDownload *)download willResumeWithResponse:(NSURLResponse *)response fromByte:(long long)startingByte
{
	DownloadItem * theItem = [self itemForDownload:download];
	theItem.size = startingByte;
	[self notifyDownloadItemChange:theItem];
}

/* shouldDecodeSourceDataOfMIMEType
 * Returns whether NSURLDownload should decode a download with a given MIME type. We ask for MacBinary, BinHex
 * and GZip files to be automatically decoded. Any other type is left alone.
 */
-(BOOL)download:(NSURLDownload *)download shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType
{
	if ([encodingType isEqualToString:@"application/macbinary"])
		return YES;
	if ([encodingType isEqualToString:@"application/mac-binhex40"])
		return YES;
	return NO;
}

/* decideDestinationWithSuggestedFilename
 * The delegate receives this message when download has determined a suggested filename for the downloaded file.
 * The suggested filename is specified in filename and is either derived from the last path component of the URL
 * and the MIME type or if the download was encoded, from the encoding. Once the delegate has decided a path,
 * it should send setDestination:allowOverwrite: to download.
 */
-(void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)filename
{
	NSString * destPath = [DownloadManager fullDownloadPath:filename];

	// Hack for certain compression types that are converted to .txt extension when
	// downloaded. SITX is the only one I know about.
	DownloadItem * theItem = [self itemForDownload:download];
	if ([theItem.filename.pathExtension isEqualToString:@"sitx"] && [filename.pathExtension isEqualToString:@"txt"])
		destPath = destPath.stringByDeletingPathExtension;

	// Save the filename
	[download setDestination:destPath allowOverwrite:NO];
	theItem.filename = destPath;
}

@end
