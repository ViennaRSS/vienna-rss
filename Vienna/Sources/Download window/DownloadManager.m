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
#import "AppController+Notifications.h"
#import "Constants.h"
#import "DownloadItem.h"
#import "NSFileManager+Paths.h"
#import "Preferences.h"
#import "Vienna-Swift.h"

@interface DownloadManager ()

// Private properties
@property NSMutableArray<DownloadItem *> *downloads;
@property NSURLSession *session;

@end

@implementation DownloadManager

// MARK: Initialization

+ (DownloadManager *)sharedInstance {
    static DownloadManager *_sharedDownloadManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedDownloadManager = [[DownloadManager alloc] init];
        [_sharedDownloadManager unarchiveDownloadsList];
    });
    return _sharedDownloadManager;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _downloads = [[NSMutableArray alloc] init];
        NSURLSessionConfiguration *config;
        config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:self
                                            delegateQueue:nil];
    }

    return self;
}

- (void)dealloc {
    [self.session invalidateAndCancel];
}

// MARK: Accessors

- (NSArray *)downloadsList {
    return [self.downloads copy];
}

- (BOOL)hasActiveDownloads {
    __block BOOL hasActiveDownloads = NO;

    [self.downloads enumerateObjectsUsingBlock:^(DownloadItem *obj,
                                                 NSUInteger idx, BOOL *stop) {
        if (obj.state == DownloadStateStarted ||
            obj.state == DownloadStateInit) {
            hasActiveDownloads = YES;
            *stop = YES;
        }
    }];

    return hasActiveDownloads;
}

// MARK: Public methods

// Remove all completed items from the list.
- (void)clearList {
    NSInteger index = self.downloads.count - 1;
    while (index >= 0) {
        DownloadItem *item = self.downloads[index--];
        if (item.state != DownloadStateStarted) {
            [self.downloads removeObject:item];
        }
    }
    [self notifyDownloadItemChange:nil];
    [self archiveDownloadsList];
}

// Archive the downloads list to the preferences.
- (void)archiveDownloadsList {
    NSMutableArray *listArray = [[NSMutableArray alloc] initWithCapacity:self.downloads.count];

    for (DownloadItem *item in self.downloads) {
        [listArray addObject:[NSArchiver archivedDataWithRootObject:item]];
    }

    [Preferences.standardPreferences setArray:listArray
                                       forKey:MAPref_DownloadsList];
}

// Unarchive the downloads list from the preferences.
- (void)unarchiveDownloadsList {
    NSArray *listArray = [Preferences.standardPreferences arrayForKey:MAPref_DownloadsList];
    if (listArray != nil) {
        for (NSData *dataItem in listArray)
            [self.downloads addObject:[NSUnarchiver unarchiveObjectWithData:dataItem]];
    }
}

// Remove the specified item from the list.
- (void)removeItem:(DownloadItem *)item {
    [self.downloads removeObject:item];
    [self archiveDownloadsList];
}

// Abort the specified item and remove it from the list
- (void)cancelItem:(DownloadItem *)item {
    if (item.download) {
        [item.download cancel];
    } else if (item.downloadTask) {
        [item.downloadTask cancel];
    }
    item.state = DownloadStateCancelled;
    [self notifyDownloadItemChange:item];
    [self.downloads removeObject:item];
    [self archiveDownloadsList];
}

// Downloads a file from the specified URL.
- (void)downloadFileFromURL:(NSString *)url {
    NSString *filename = [NSURL URLWithString:url].lastPathComponent;
    NSString *destPath = [DownloadManager fullDownloadPath:filename];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]
                                             cachePolicy:NSURLRequestUseProtocolCachePolicy
                                         timeoutInterval:60.0];
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:request];

    DownloadItem *item = [[DownloadItem alloc] init];
    item.state = DownloadStateInit;
    item.downloadTask = task;
    item.filename = destPath;
    item.fileURL = [NSURL fileURLWithPath:destPath];
    [self.downloads addObject:item];

    [task resume];
}

- (DownloadItem *)itemForSessionTask:(NSURLSessionTask *)task {
    NSInteger index = self.downloads.count - 1;
    while (index >= 0) {
        DownloadItem *item = self.downloads[index--];
        if (item.downloadTask == task) {
            return item;
        }
    }
    return nil;
}

// Given a filename, returns the fully qualified path to where the file will be
// downloaded by using the user's preferred download folder. If that folder is
// absent then we default to downloading to the desktop instead.
+ (NSString *)fullDownloadPath:(NSString *)filename {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *downloadFolderURL = fileManager.downloadsDirectory;
    NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
    NSData *data = [userDefaults dataForKey:MAPref_DownloadsFolderBookmark];

    if (data) {
        NSError *error = nil;
        VNASecurityScopedBookmark *bookmark = [[VNASecurityScopedBookmark alloc] initWithBookmarkData:data
                                                                                                error:&error];

        if (!error) {
            downloadFolderURL = bookmark.resolvedURL;
        }
    }

    NSString *downloadPath = downloadFolderURL.path;
    BOOL isDir = YES;

    if (![fileManager fileExistsAtPath:downloadPath isDirectory:&isDir] || !isDir) {
        downloadPath = fileManager.downloadsDirectory.path;
    }

    return [downloadPath stringByAppendingPathComponent:filename];
}

// Looks up the specified file in the download list to determine if it is being
// downloaded. If not, then it looks up the file in the workspace.
+ (BOOL)isFileDownloaded:(NSString *)filename {
    DownloadManager *downloadManager = DownloadManager.sharedInstance;
    NSInteger count = downloadManager.downloadsList.count;
    NSInteger index;

    NSString *firstFile = filename.stringByStandardizingPath;

    for (index = 0; index < count; ++index) {
        DownloadItem *item = downloadManager.downloadsList[index];
        NSString *secondFile = filename.stringByStandardizingPath;

        if ([firstFile compare:secondFile
                       options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            if (item.state != DownloadStateCompleted)
                return NO;

            // File completed download but possibly moved or deleted after
            // download so check the file system.
            return [[NSFileManager defaultManager] fileExistsAtPath:secondFile];
        }
    }
    return NO;
}

// MARK: Private methods

// Send a notification that the specified download item has changed.
- (void)notifyDownloadItemChange:(DownloadItem *)item {
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc postNotificationName:@"MA_Notify_DownloadsListChange" object:item];
}

// Delivers a user notification for the given download item.
- (void)deliverNotificationForDownloadItem:(DownloadItem *)item {
    if (item.state != DownloadStateCompleted &&
        item.state != DownloadStateFailed) {
        return;
    }

    [self notifyDownloadItemChange:item];
    [self archiveDownloadsList];

    NSString *fileName = item.filename.lastPathComponent;

    NSUserNotification *notification = [NSUserNotification new];
    notification.soundName = NSUserNotificationDefaultSoundName;

    if (item.state == DownloadStateCompleted) {
        notification.title = NSLocalizedString(@"Download completed", @"Notification title");
        notification.informativeText = [NSString stringWithFormat:NSLocalizedString(@"File %@ downloaded", @"Notification body"), fileName];
        notification.userInfo = @{UserNotificationContextKey: UserNotificationContextFileDownloadCompleted,
                                  UserNotificationFilePathKey: fileName};

        [NSNotificationCenter.defaultCenter postNotificationName:@"MA_Notify_DownloadCompleted" object:fileName];
    } else if (item.state == DownloadStateFailed) {
        notification.title = NSLocalizedString(@"Download failed", @"Notification title");
        notification.informativeText = [NSString stringWithFormat:NSLocalizedString(@"File %@ failed to download", @"Notification body"), fileName];
        notification.userInfo = @{UserNotificationContextKey: UserNotificationContextFileDownloadFailed,
                                  UserNotificationFilePathKey: fileName};
    }

    [NSUserNotificationCenter.defaultUserNotificationCenter deliverNotification:notification];
}

// MARK: - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    dispatch_sync(dispatch_get_main_queue(), ^{
        DownloadItem *item = [self itemForSessionTask:downloadTask];

        if (item.state == DownloadStateInit) {
            item.state = DownloadStateStarted;
        }

        item.size = totalBytesWritten;
        item.expectedSize = totalBytesExpectedToWrite;
        [self notifyDownloadItemChange:item];
    });
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
    dispatch_sync(dispatch_get_main_queue(), ^{
        DownloadItem *item = [self itemForSessionTask:downloadTask];
        [NSFileManager.defaultManager moveItemAtURL:location
                                              toURL:item.fileURL
                                              error:nil];
        item.state = DownloadStateCompleted;
        [self deliverNotificationForDownloadItem:item];
    });
}

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    // Only handle errors here, since a successful completion should call the
    // method -URLSession:session:downloadTask:didFinishDownloadingToURL: too.
    if (!error) {
        return;
    }

    dispatch_sync(dispatch_get_main_queue(), ^{
        DownloadItem *item = [self itemForSessionTask:task];
        item.state = DownloadStateFailed;
        [self deliverNotificationForDownloadItem:item];
    });
}

// MARK: - WebDownload (deprecated)

- (DownloadItem *)itemForDownload:(NSURLDownload *)download {
    NSInteger index = self.downloads.count - 1;
    while (index >= 0) {
        DownloadItem *item = self.downloads[index--];
        if (item.download == download) {
            return item;
        }
    }
    return nil;
}

- (DownloadItem *)newDownloadItemForDownload:(NSURLDownload *)download {
    DownloadItem *item = [[DownloadItem alloc] init];
    item.download = download;
    item.filename = download.request.URL.path;
    return item;
}

// MARK: - WebDownloadDelegate (deprecated)

- (void)downloadDidBegin:(NSURLDownload *)download {
    DownloadItem *theItem = [self itemForDownload:download];
    if (!theItem) {
        theItem = [self newDownloadItemForDownload:download];
        [self.downloads addObject:theItem];
    }
    theItem.state = DownloadStateStarted;

    [self notifyDownloadItemChange:theItem];

    // If there's no download window visible, display one now.
    [APPCONTROLLER conditionalShowDownloadsWindow:self];
}

// A download has completed. Mark the associated DownloadItem as completed.
- (void)downloadDidFinish:(NSURLDownload *)download {
    DownloadItem *item = [self itemForDownload:download];
    item.state = DownloadStateCompleted;
    [self deliverNotificationForDownloadItem:item];
}

// A download failed with an error. Mark the associated DownloadItem as broken.
- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
    DownloadItem *item = [self itemForDownload:download];
    item.state = DownloadStateFailed;
    [self deliverNotificationForDownloadItem:item];
}

// The download received additional data of the specified size.
- (void)download:(NSURLDownload *)download
    didReceiveDataOfLength:(NSUInteger)length {
    DownloadItem *theItem = [self itemForDownload:download];
    theItem.size = theItem.size + length;

    // TODO: How many bytes are we getting each second?

    // TODO: And the elapsed time until we're done?

    [self notifyDownloadItemChange:theItem];
}

// Called once after we have the initial response from the server. Get and save
// the expected file size.
- (void)download:(NSURLDownload *)download
    didReceiveResponse:(NSURLResponse *)response {
    DownloadItem *theItem = [self itemForDownload:download];
    theItem.expectedSize = response.expectedContentLength;
    [self notifyDownloadItemChange:theItem];
}

// The download is about to resume from the specified position.
- (void)download:(NSURLDownload *)download
    willResumeWithResponse:(NSURLResponse *)response
                  fromByte:(long long)startingByte {
    DownloadItem *theItem = [self itemForDownload:download];
    theItem.size = startingByte;
    [self notifyDownloadItemChange:theItem];
}

// Returns whether NSURLDownload should decode a download with a given MIME
// type. We ask for MacBinary, BinHex and GZip files to be automatically
// decoded. Any other type is left alone.
- (BOOL)download:(NSURLDownload *)download
    shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType {
    if ([encodingType isEqualToString:@"application/macbinary"] ||
        [encodingType isEqualToString:@"application/mac-binhex40"]) {
        return YES;
    } else {
        return NO;
    }
}

// The delegate receives this message when download has determined a suggested
// filename for the downloaded file. The suggested filename is specified in
// filename and is either derived from the last path component of the URL and
// the MIME type or if the download was encoded, from the encoding. Once the
// delegate has decided a path, it should send setDestination:allowOverwrite:
// to download.
- (void)download:(NSURLDownload *)download
    decideDestinationWithSuggestedFilename:(NSString *)filename {
    NSString *destPath = [DownloadManager fullDownloadPath:filename];
    DownloadItem *theItem = [self itemForDownload:download];

    // If the URL download was started by WebView, then it may have bypassed the
    // -downloadDidBegin: callback.
    if (!theItem) {
        theItem = [self newDownloadItemForDownload:download];
        theItem.state = DownloadStateStarted;
        [self.downloads addObject:theItem];
        [self notifyDownloadItemChange:theItem];
    }

    // Hack for certain compression types that are converted to .txt extension
    // when downloaded. SITX is the only one I know about.
    if ([theItem.filename.pathExtension isEqualToString:@"sitx"] &&
        [filename.pathExtension isEqualToString:@"txt"]) {
        destPath = destPath.stringByDeletingPathExtension;
    }

    // Save the filename
    [download setDestination:destPath allowOverwrite:NO];
    theItem.filename = destPath;
}

// Sent when the destination file is created (possibly in a temporary folder)
- (void)download:(NSURLDownload *)download
    didCreateDestination:(NSString *)path {
    DownloadItem *theItem = [self itemForDownload:download];

    // If the URL download was started by WebView, then it may have bypassed the
    // -downloadDidBegin: callback.
    if (!theItem) {
        theItem = [self newDownloadItemForDownload:download];
        theItem.state = DownloadStateStarted;
        [self.downloads addObject:theItem];
        [self notifyDownloadItemChange:theItem];
    }

    [[NSFileManager defaultManager] moveItemAtPath:path
                                            toPath:theItem.filename
                                             error:nil];
    [self deliverNotificationForDownloadItem:theItem];
    theItem.state = DownloadStateCompleted;
}

@end
