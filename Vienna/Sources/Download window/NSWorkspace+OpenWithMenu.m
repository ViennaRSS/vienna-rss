/*
 Copyright (c) 2003-2017, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this
 list of conditions and the following disclaimer in the documentation and/or other
 materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may
 be used to endorse or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
*/

#import "NSWorkspace+OpenWithMenu.h"

@implementation NSWorkspace (OpenWithMenu)

#pragma mark - Handler apps

- (NSArray *)handlerApplicationsForFile:(NSString *)filePath {
    NSURL *url = [NSURL fileURLWithPath:filePath];
    NSMutableArray *appPaths = [[NSMutableArray alloc] initWithCapacity:256];
    
    NSArray *applications = (NSArray *)CFBridgingRelease(LSCopyApplicationURLsForURL((__bridge CFURLRef)url, kLSRolesAll));
    if (applications == nil) {
        return @[];
    }
    
    for (NSURL *appURL in applications) {
        [appPaths addObject:[appURL path]];
    }
    return [NSArray arrayWithArray:appPaths];
}

- (NSString *)defaultHandlerApplicationForFile:(NSString *)filePath {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];    
    NSURL *appURL = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:fileURL];
    return [appURL path];
}

// Generate Open With menu for a given file. If no target and action are provided, we use our own.
// If no menu is supplied as parameter, a new menu is created and returned.
- (NSMenu *)openWithMenuForFile:(NSString *)path target:(id)t action:(SEL)s menu:(NSMenu *)menu {
    [menu removeAllItems];

    NSString *noneTitle = NSLocalizedString(@"<None>", @"Title in popup submenu");
    NSMenuItem *noneMenuItem = [[NSMenuItem alloc] initWithTitle:noneTitle action:nil keyEquivalent:@""];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO) {
        [menu addItem:noneMenuItem];
        return menu;
    }

    id target = t ? t : self;
    SEL selector = s ? s : @selector(openWith:);
    
    NSMenu *submenu = menu ? menu : [[NSMenu alloc] init];
    [submenu setTitle:path]; // Used by selector
    
    // Add menu item for default app
    NSString *defaultApp = [self defaultHandlerApplicationForFile:path];
    NSString *displayName = [[[NSFileManager defaultManager] displayNameAtPath:defaultApp] stringByDeletingPathExtension];
    NSString *defaultAppName = [NSString stringWithFormat:NSLocalizedString(@"%@ (default)", @"Appended to application name in Open With menu"), displayName];
    
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:defaultApp];
    [icon setSize:NSMakeSize(16,16)];
    
    NSMenuItem *defaultAppItem = [submenu addItemWithTitle:defaultAppName action:selector keyEquivalent:@""];
    [defaultAppItem setImage:icon];
    [defaultAppItem setTarget:target];
    [defaultAppItem setToolTip:defaultApp];
    
    [submenu addItem:[NSMenuItem separatorItem]];
    
    // Add items for all other apps that can open this file
    NSArray *apps = [self handlerApplicationsForFile:path];
    int numOtherApps = 0;
    if ([apps count]) {
    
        apps = [apps sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
        for (NSString *appPath in apps) {
            if ([appPath isEqualToString:defaultApp]) {
                continue; // Skip previously listed default app
            }
            
            numOtherApps++;
            NSString *title = [[[NSFileManager defaultManager] displayNameAtPath:appPath] stringByDeletingPathExtension];
            
            NSMenuItem *item = [submenu addItemWithTitle:title action:selector keyEquivalent:@""];
            [item setTarget:target];
            [item setToolTip:appPath];
            
            NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:appPath];
            if (icon) {
                [icon setSize:NSMakeSize(16,16)];
                [item setImage:icon];
            }
        }
        
    } else {
        [submenu addItem:noneMenuItem];
    }
    
    if (numOtherApps) {
        [submenu addItem:[NSMenuItem separatorItem]];
    }

    NSString *title = NSLocalizedString(@"Select…", @"Title of a popup menu item");
    NSMenuItem *selectItem = [submenu addItemWithTitle:title action:selector keyEquivalent:@""];
    [selectItem setTag:1];
    [selectItem setTarget:target];
    
    return submenu;
}

// Handler for when user selects item in Open With menu
- (void)openWith:(id)sender {
    NSString *appPath = [sender toolTip];
    NSString *filePath = [[sender menu] title];
    
    if ([sender tag] == 1) {
        // Create open panel
        NSOpenPanel *oPanel = [NSOpenPanel openPanel];
        [oPanel setAllowsMultipleSelection:NO];
        [oPanel setCanChooseDirectories:NO];
        [oPanel setAllowedFileTypes:@[(NSString *)kUTTypeApplicationBundle]];
        
        // Set Applications folder as default directory
        NSArray *applicationFolderPaths = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask];
        if ([applicationFolderPaths count]) {
            [oPanel setDirectoryURL:applicationFolderPaths[0]];
        }
        
        // Run
        if ([oPanel runModal] == NSModalResponseOK) {
            appPath = [[oPanel URLs][0] path];
        } else {
            return;
        }
    }
    
    [self openFile:filePath withApplication:appPath];
}

@end
