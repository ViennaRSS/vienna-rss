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

#import "AppController+Notifications.h"
#import "Constants.h"
#import "DownloadItem.h"
#import "NSFileManager+Paths.h"
#import "NSKeyedUnarchiver+Compatibility.h"
#import "Preferences.h"
#import "Vienna-Swift.h"

#include <sys/xattr.h>

static NSString * const VNAUserNotificationFileDownloadThreadIdentifier = @"FileDownloadThreadIdentifier";
static const char *whereFromAttributeName = "com.apple.metadata:kMDItemWhereFroms";

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
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[self.downloads copy]
                                         requiringSecureCoding:YES
                                                         error:NULL];

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
    [self.downloads insertObject:item atIndex:0];

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
        BOOL bookmarkDataIsStale = NO;
        NSError *bookmarkInitError;
        VNASecurityScopedBookmark *bookmark =
            [[VNASecurityScopedBookmark alloc] initWithBookmarkData:data
                                                bookmarkDataIsStale:&bookmarkDataIsStale
                                                              error:&bookmarkInitError];
        if (!bookmarkInitError) {
            if (bookmarkDataIsStale) {
                NSError *bookmarkResolveError;
                NSData *bookmarkData =
                    [VNASecurityScopedBookmark bookmarkDataFromFileURL:bookmark.resolvedURL
                                                                 error:&bookmarkResolveError];
                if (!bookmarkResolveError) {
                    [userDefaults setObject:bookmarkData
                                     forKey:MAPref_DownloadsFolderBookmark];
                }
            }

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

// Looks up the specified URL in the workspace to determine if it has been downloaded
+ (nullable NSString *)fullpathForDownloadedURL:(NSString *)urlString {
    NSString *shortname = [NSURL URLWithString:urlString].lastPathComponent;
    NSString *expectedPath = [DownloadManager fullDownloadPath:shortname];
    if ([[DownloadManager originFromMetadata:expectedPath] isEqualToString:urlString]) {
        return expectedPath;
    }

    NSString *directoryPath = [expectedPath substringWithRange:NSMakeRange(0, expectedPath.length - shortname.length)];
    NSString *extension = [expectedPath pathExtension];
    if  (![extension isEqualToString:@""]) {
        shortname = [shortname substringWithRange:NSMakeRange(0, shortname.length - extension.length -1)];
        extension = [NSString stringWithFormat:@".%@", extension];
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:directoryPath error:nil];

    NSString * name = nil;
    for (NSString *file in files) {
        if ([file hasPrefix:shortname] && [file hasSuffix:extension]) {
            NSString *fullpath = [directoryPath stringByAppendingString:file];
            if ([[DownloadManager originFromMetadata:fullpath] isEqualToString:urlString]) {
                name = fullpath;
                continue;
            }
        }
    }
    return name;
}

// MARK: Private methods

+ (nullable NSString *)originFromMetadata:(NSString *)filePath
{
    // Retrieve the metadata length
    size_t size = getxattr(filePath.fileSystemRepresentation, whereFromAttributeName, NULL, 0, 0, 0);
    if (size > 0) {
        void *buffer = malloc(size);
        // retrieve the metadata
        ssize_t read = getxattr(filePath.fileSystemRepresentation, whereFromAttributeName, buffer, size, 0, 0);
        if (read < 0) {
            free(buffer);
            return nil;
        }
        NSData *data = [NSData dataWithBytesNoCopy:buffer length:size freeWhenDone:YES];
        id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil];
        if ([plist isKindOfClass:[NSArray class]] && [(NSArray *)plist count] > 0 && [((NSArray *)plist)[0] isKindOfClass:[NSString class]]) {
            return ((NSArray *)plist)[0];
        }
    }
    return nil;
}

// Send a notification that the specified download item has changed.
- (void)notifyDownloadItemChange:(DownloadItem *)item {
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc postNotificationName:MA_Notify_DownloadsListChange object:item];
}

// Delivers a user notification for the given download item.
- (void)deliverUserNotificationForDownloadItem:(DownloadItem *)item
{
    VNAUserNotificationCenter *center = VNAUserNotificationCenter.current;
    [center getNotificationSettingsWithCompletionHandler:^(VNAUserNotificationSettings *settings) {
        VNAUserNotificationAuthorizationStatus status = settings.authorizationStatus;
        if (status == VNAUserNotificationAuthorizationStatusDenied) {
            return;
        }

        void (^deliverNotification)(void) = ^{
            NSString *title;
            NSString *body;
            NSString *filename = item.filename.lastPathComponent;
            NSDictionary<NSString *, id> *userInfo;
            switch (item.state) {
            case DownloadStateCompleted:
                title = NSLocalizedString(@"Download completed", @"Notification title");
                body = [NSString stringWithFormat:NSLocalizedString(@"File %@ downloaded",
                                                                    @"Notification body"),
                                                  filename];
                userInfo = @{
                    UserNotificationContextKey: UserNotificationContextFileDownloadCompleted,
                    UserNotificationFilePathKey: item.filename
                };
                break;
            case DownloadStateFailed:
                title = NSLocalizedString(@"Download failed", @"Notification title");
                body = [NSString stringWithFormat:NSLocalizedString(@"File %@ failed to download",
                                                                    @"Notification body"),
                                                  filename];
                userInfo = @{
                    UserNotificationContextKey: UserNotificationContextFileDownloadFailed,
                    UserNotificationFilePathKey: item.filename
                };
                break;
            default:
                return;
            }
            VNAUserNotificationRequest *request =
                [[VNAUserNotificationRequest alloc] initWithIdentifier:item.fileURL.absoluteString
                                                                 title:title];
            // Use a thread identifier to group all file download notifications
            // (this can be disabled by the user in System Settings).
            request.threadIdentifier = VNAUserNotificationFileDownloadThreadIdentifier;
            request.body = body;
            request.playSound = settings.isSoundEnabled;
            request.userInfo = userInfo;
            [center addNotificationRequest:request
                     withCompletionHandler:nil];
        };

        if (status == VNAUserNotificationAuthorizationStatusProvisional ||
            status == VNAUserNotificationAuthorizationStatusAuthorized) {
            deliverNotification();
        } else if (status == VNAUserNotificationAuthorizationStatusNotDetermined) {
            [center requestAuthorizationWithCompletionHandler:^(BOOL granted) {
                if (granted) {
                    deliverNotification();
                }
            }];
        }
    }];
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

        // Detect any collision with an existing file
        NSString *destinationName = item.filename;
        if ([[NSFileManager defaultManager] fileExistsAtPath:destinationName]) {
            NSString *baseName = destinationName;
            NSString *extension = [baseName pathExtension];
            if  (![extension isEqualToString:@""]) {
                baseName = [baseName substringWithRange:NSMakeRange(0, baseName.length - extension.length -1)];
                extension = [NSString stringWithFormat:@".%@", extension];
            }

            NSUInteger counter = 2;
            while ([[NSFileManager defaultManager] fileExistsAtPath:destinationName]) {
                destinationName = [NSString stringWithFormat:@"%@-%lu%@", baseName, (unsigned long)counter, extension];
                counter++;
            }

            item.filename = destinationName;
        }

        [NSFileManager.defaultManager moveItemAtURL:location
                                              toURL:item.fileURL
                                              error:nil];

        // write metadata describing where the file was obtained from
        NSString *origin = downloadTask.originalRequest.URL.absoluteString;
        NSArray *origins = @[origin];
        NSData *value = [NSPropertyListSerialization dataWithPropertyList:origins
                                                                   format:NSPropertyListBinaryFormat_v1_0
                                                                  options:0
                                                                    error:nil];
        size_t size = value.length;
        int options = XATTR_NOFOLLOW | 0; // create or replace the attribute, do not follow symbolic links
        setxattr(destinationName.fileSystemRepresentation, whereFromAttributeName, value.bytes, size, 0, options);

        // notify
        item.state = DownloadStateCompleted;
        [self notifyDownloadItemChange:item];
        [self archiveDownloadsList];
        [NSNotificationCenter.defaultCenter postNotificationName:MA_Notify_DownloadCompleted
                                                          object:item.filename.lastPathComponent];
        [self deliverUserNotificationForDownloadItem:item];
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
        [self notifyDownloadItemChange:item];
        [self archiveDownloadsList];
        [self deliverUserNotificationForDownloadItem:item];
    });
}

@end
