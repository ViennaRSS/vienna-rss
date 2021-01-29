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

@implementation NSFileManager (Paths)

// The NSApplicationScriptsDirectory search path returns a subdirectory in the
// Library/Application Scripts directory. Vienna currently uses a subdirectory
// in Library/Scripts/Applications instead. The sandboxing migration performs
// an automatic migration to Library/Application Scripts/<bundle identifier>
// and places a symlink at the old location. This code needs to be updated
// accordingly.
- (NSURL *)applicationScriptsDirectory {
    static NSURL *url = nil;
    if (url) {
        return [url copy];
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    url = [fileManager URLForDirectory:NSLibraryDirectory
                              inDomain:NSUserDomainMask
                     appropriateForURL:nil
                                create:YES
                                 error:&error];
    url = [url URLByAppendingPathComponent:@"Scripts/Applications/Vienna"
                               isDirectory:YES];
// This is the replacement code for sandboxing:
//
//    NSURL *url = [fileManager URLForDirectory:NSApplicationScriptsDirectory
//                                     inDomain:NSUserDomainMask
//                            appropriateForURL:nil
//                                       create:YES
//                                        error:&error];
    if (!url && error) {
        [NSApp presentError:error];
    }

    return [url copy];
}

// According to Apple's file-system programming guide, the bundle identifier
// should be used as the subdirectory name. However, Vienna presently uses the
// app name instead. This should be changed when Vienna migrates to sandboxing.
- (NSURL *)applicationSupportDirectory {
    static NSURL *url = nil;
    if (url) {
        return [url copy];
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    url = [fileManager URLForDirectory:NSApplicationSupportDirectory
                              inDomain:NSUserDomainMask
                     appropriateForURL:nil
                                create:YES
                                 error:&error];
    if (!url && error) {
        [NSApp presentError:error];
    }

    url = [url URLByAppendingPathComponent:@"Vienna"
                               isDirectory:YES];
// This is the replacement code for sandboxing:
//
//    url = [url URLByAppendingPathComponent:NSBundle.mainBundle.bundleIdentifier
//                               isDirectory:YES];

    return [url copy];
}

- (NSURL *)cachesDirectory {
    static NSURL *url = nil;
    if (url) {
        return [url copy];
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    url = [fileManager URLForDirectory:NSCachesDirectory
                              inDomain:NSUserDomainMask
                     appropriateForURL:nil
                                create:YES
                                 error:&error];
    if (!url && error) {
        [NSApp presentError:error];
    }

    url = [url URLByAppendingPathComponent:NSBundle.mainBundle.bundleIdentifier
                               isDirectory:YES];

    return [url copy];
}

@end
