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
#import "NSKeyedArchiver+Compatibility.h"
#import "NSKeyedUnarchiver+Compatibility.h"
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
    NSData *data = [NSKeyedArchiver vna_archivedDataWithRootObject:[self.downloads copy]
                                             requiringSecureCoding:YES];

    if (data) {
        [Preferences.standardPreferences setObject:data
                                            forKey:MAPref_DownloadItemList];
    }
}

// Unarchive the downloads list from the preferences.
- (void)unarchiveDownloadsList {
    Preferences *preferences = Preferences.standardPreferences;
    NSData *archive = [preferences objectForKey:MAPref_DownloadItemList];

    if (!archive) {
        return;
    }

    NSArray<DownloadItem *> *items = nil;
    Class cls = [DownloadItem class];
    items = [NSKeyedUnarchiver vna_unarchivedArrayOfObjectsOfClass:cls
                                                          fromData:archive];

    if (items) {
        [self.downloads addObjectsFromArray:items];
    }
}

// Remove the specified item from the list.
- (void)removeItem:(DownloadItem *)item {
    [self.downloads removeObject:item];
    [self archiveDownloadsList];
}

// Abort the specified item and remove it from the list
- (void)cancelItem:(DownloadItem *)item {
    if (item.downloadTask) {
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
    [self downloadFileFromURL:url withFilename:filename];
}

// Downloads a file from the specified URL to specified filename
- (void)downloadFileFromURL:(NSString *)url withFilename:(NSString *)filename {
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
    NSURL *downloadFolderURL = fileManager.vna_downloadsDirectory;
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
        downloadPath = fileManager.vna_downloadsDirectory.path;
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

@end
