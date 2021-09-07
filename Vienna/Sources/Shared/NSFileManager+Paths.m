//
//  NSFileManager+Paths.m
//  Vienna
//
//  Copyright 2021 Eitot
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

#import "NSFileManager+Paths.h"

@import os.log;

#define VNA_LOG os_log_create("--", "Paths")

@implementation NSFileManager (Paths)

- (NSURL *)vna_applicationScriptsDirectory {
    static NSURL *url = nil;
    if (url) {
        return url;
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    url = [fileManager URLForDirectory:NSApplicationScriptsDirectory
                              inDomain:NSUserDomainMask
                     appropriateForURL:nil
                                create:NO
                                 error:&error];

    if (!url && error) {
        const char *function = __PRETTY_FUNCTION__;
        NSString *description = error.localizedDescription;
        os_log_fault(VNA_LOG, "%{public}s %{public}@", function, description);
    }

    return (id _Nonnull)url;
}

- (NSURL *)vna_applicationSupportDirectory {
    static NSURL *url = nil;
    if (url) {
        return url;
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    url = [fileManager URLForDirectory:NSApplicationSupportDirectory
                              inDomain:NSUserDomainMask
                     appropriateForURL:nil
                                create:NO
                                 error:&error];
    url = [url URLByAppendingPathComponent:@"Vienna"
                               isDirectory:YES];

    if (!url && error) {
        const char *function = __PRETTY_FUNCTION__;
        NSString *description = error.localizedDescription;
        os_log_fault(VNA_LOG, "%{public}s %{public}@", function, description);
    }

    return (id _Nonnull)url;
}

- (NSURL *)vna_cachesDirectory {
    static NSURL *url = nil;
    if (url) {
        return url;
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    url = [fileManager URLForDirectory:NSCachesDirectory
                              inDomain:NSUserDomainMask
                     appropriateForURL:nil
                                create:NO
                                 error:&error];
    url = [url URLByAppendingPathComponent:NSBundle.mainBundle.bundleIdentifier
                               isDirectory:YES];

    if (!url && error) {
        const char *function = __PRETTY_FUNCTION__;
        NSString *description = error.localizedDescription;
        os_log_fault(VNA_LOG, "%{public}s %{public}@", function, description);
    }

    return (id _Nonnull)url;
}

- (NSURL *)vna_downloadsDirectory {
    static NSURL *url = nil;
    if (url) {
        return url;
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    url = [fileManager URLForDirectory:NSDownloadsDirectory
                              inDomain:NSUserDomainMask
                     appropriateForURL:nil
                                create:NO
                                 error:&error];

    if (!url && error) {
        const char *function = __PRETTY_FUNCTION__;
        NSString *description = error.localizedDescription;
        os_log_fault(VNA_LOG, "%{public}s %{public}@", function, description);
    }

    return (id _Nonnull)url;
}

@end
