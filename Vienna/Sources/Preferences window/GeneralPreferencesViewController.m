//
//  GeneralPreferencesViewController.m
//  Vienna
//
//  Created by Joshua Pore on 22/11/2014.
//  Copyright (c) 2014 uk.co.opencommunity. All rights reserved.
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

#import "GeneralPreferencesViewController.h"

@import os.log;
@import UniformTypeIdentifiers;

#import "Constants.h"
#import "NSFileManager+Paths.h"
#import "Preferences.h"
#import "Vienna-Swift.h"

#define VNA_LOG os_log_create("--", "GeneralPreferencesViewController")

@interface GeneralPreferencesViewController ()

-(void)initializePreferences;
// -(void)selectUserDefaultFont:(NSString *)name size:(int)size control:(NSPopUpButton *)control sizeControl:(NSComboBox *)sizeControl;
// -(void)controlTextDidEndEditing:(NSNotification *)notification;
-(void)refreshLinkHandler;
-(void)updateDownloadsPopUp:(NSString *)downloadFolderPath;

@end

@implementation GeneralPreferencesViewController {
    IBOutlet NSPopUpButton *checkFrequency;
    IBOutlet NSPopUpButton *linksHandler;
    IBOutlet NSPopUpButton *expireDuration;
    IBOutlet NSButton *checkOnStartUp;
    IBOutlet NSButton *openLinksInBackground;
    IBOutlet NSButton *openLinksInExternalBrowser;
    IBOutlet NSButton *showAppInMenuBar;
    IBOutlet NSPopUpButton *downloadFolder;
    IBOutlet NSButtonCell *newArticlesNotificationBounceButton;
    IBOutlet NSButtonCell *markReadAfterNext;
    IBOutlet NSButtonCell *markReadAfterDelay;
    IBOutlet NSButton *markUpdatedAsNew;
    NSMutableDictionary *appToPathMap;
}

- (void)viewDidLoad {
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleReloadPreferences:) name:MA_Notify_CheckFrequencyChange object:nil];
    [nc addObserver:self selector:@selector(handleReloadPreferences:) name:MA_Notify_PreferenceChange object:nil];
    appToPathMap = [[NSMutableDictionary alloc] init];
}

- (void)viewWillAppear {
    [self initializePreferences];
}

#pragma mark - Vienna Preferences handling

/* handleReloadPreferences
 * This gets called when MA_Notify_PreferencesUpdated is broadcast. Just update the controls values.
 */
-(void)handleReloadPreferences:(NSNotification *)nc
{
    [self initializePreferences];
}

/* initializePreferences
 * Set the preference settings from the user defaults.
 */
-(void)initializePreferences
{
    Preferences * prefs = [Preferences standardPreferences];
    
    // Set the check frequency
    [checkFrequency selectItemAtIndex:[checkFrequency indexOfItemWithTag:prefs.refreshFrequency]];

    // Set check for new articles when starting
    checkOnStartUp.state = prefs.refreshOnStartup ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Set auto-expire duration
    // Meaning of tag :
    // 0 value disables auto-expire.
    // Increments of 1000 specify months, so 1000 = 1 month, 1001 = 1 month and 1 day…
    [expireDuration selectItemAtIndex:[expireDuration indexOfItemWithTag:prefs.autoExpireDuration]];
    
    // Set download folder
    [self updateDownloadsPopUp:NSFileManager.defaultManager.vna_downloadsDirectory.path];

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

            [self updateDownloadsPopUp:bookmark.resolvedURL.path];
        }
    }
    
    // Set whether the application is shown in the menu bar
    showAppInMenuBar.state = prefs.showAppInStatusBar ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Set whether links are opened in the background
    openLinksInBackground.state = prefs.openLinksInBackground ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Set whether links are opened in the external browser
    openLinksInExternalBrowser.state = prefs.openLinksInVienna ? NSControlStateValueOff : NSControlStateValueOn;
    
    // Set mark read behaviour
    markReadAfterNext.state = prefs.markReadInterval == 0 ? NSControlStateValueOn : NSControlStateValueOff;
    markReadAfterDelay.state = prefs.markReadInterval != 0 ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Show new articles notification options
    newArticlesNotificationBounceButton.state = ((prefs.newArticlesNotification & VNANewArticlesNotificationBounce) !=0) ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Set whether updated articles are considered as new
    markUpdatedAsNew.state = prefs.markUpdatedAsNew ? NSControlStateValueOn : NSControlStateValueOff;
    
    [self refreshLinkHandler];
}

/* refreshLinkHandler
 * Populate the drop down list of registered handlers for the feed:// URL
 * using launch services.
 */
-(void)refreshLinkHandler
{
    NSBundle * appBundle = [NSBundle mainBundle];
    NSString * ourAppName = [[NSFileManager defaultManager] displayNameAtPath:appBundle.bundlePath];
    BOOL onTheList = NO;
    NSURL *testURL = [NSURL URLWithString:@"feed://www.test.com"];
    NSURL *registeredAppURL = [NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:testURL];
    
    // Clear all existing items
    [linksHandler removeAllItems];
    
    // Add the current registered link handler to the start of the list. If
    // there is no current registered handler then default to Vienna.
    if (!registeredAppURL) {
        registeredAppURL = appBundle.executableURL;
        onTheList = YES;
    }
    
    NSString * regAppName = [[NSFileManager defaultManager] displayNameAtPath:registeredAppURL.path];
    // Maintain a table to map from the short name to the file URL for when
    // the user changes selection and we later need the file URL to register
    // the new selection.
    if (regAppName != nil) {
        NSImage *image = [NSWorkspace.sharedWorkspace iconForFile:registeredAppURL.path];
        [linksHandler addItemWithTitle:regAppName image:image];
        [linksHandler.menu addItem:[NSMenuItem separatorItem]];
        [appToPathMap setValue:registeredAppURL forKey:regAppName];
    }

    // Next, add the list of all registered link handlers under the /Applications folder
    // except for the registered application.
    CFArrayRef cfArrayOfApps = LSCopyApplicationURLsForURL((__bridge CFURLRef)testURL, kLSRolesAll);
    if (cfArrayOfApps != nil) {
        CFIndex count = CFArrayGetCount(cfArrayOfApps);
        NSInteger index;
        
        for (index = 0; index < count; ++index) {
            NSURL * appURL = (NSURL *)CFArrayGetValueAtIndex(cfArrayOfApps, index);
            if (appURL.fileURL && [appURL.path hasPrefix:@"/Applications/"]) {
                NSString * appName = [[NSFileManager defaultManager] displayNameAtPath:appURL.path];
                if ([appName isEqualToString:ourAppName]) {
                    onTheList = YES;
                }
                if (appName != nil && ![appName isEqualToString:regAppName]) {
                    [linksHandler addItemWithTitle:appName image:[[NSWorkspace sharedWorkspace] iconForFile:appURL.path]];
                }
                
                [appToPathMap setValue:appURL forKey:appName];
            }
        }
        CFRelease(cfArrayOfApps);
    }
    
    // Were we on the list? If not, add ourselves
    // complete with our icon.
    if (!onTheList) {
        [linksHandler addItemWithTitle:ourAppName image:[[NSWorkspace sharedWorkspace] iconForFile:appBundle.bundlePath]];
        
        NSURL * fileURL = [[NSURL alloc] initFileURLWithPath:appBundle.bundlePath];
        [appToPathMap setValue:fileURL forKey:ourAppName];
    }
    
    // Add a Select command so the user can manually pick a registered
    // application.
    [linksHandler.menu addItem:[NSMenuItem separatorItem]];
    NSString *selectTitle = NSLocalizedString(@"Select…",
                                              @"Title of a menu item");
    NSMenuItem *selectMenuItem = [[NSMenuItem alloc] initWithTitle:selectTitle
                                                            action:nil
                                                     keyEquivalent:@""];
    selectMenuItem.tag = -1;
    [linksHandler.menu addItem:selectMenuItem];
    
    // Select the registered item
    [linksHandler selectItemAtIndex:0];
}

/* changeExpireDuration
 * Handle the change to the auto-expire duration.
 */
-(IBAction)changeExpireDuration:(id)sender
{
    NSMenuItem * selectedItem = expireDuration.selectedItem;
    if (selectedItem != nil) {
        [Preferences standardPreferences].autoExpireDuration = selectedItem.tag;
    }
}

/* changeOpenLinksInBackground
 * Sets whether Vienna opens new links in the background in the active web
 * browser.
 */
-(IBAction)changeOpenLinksInBackground:(id)sender
{
    [Preferences standardPreferences].openLinksInBackground = [sender state] == NSControlStateValueOn;
}

/* changeShowAppInMenuBar
 * Sets whether or not the application icon is shown in the menu bar.
 */
-(IBAction)changeShowAppInMenuBar:(id)sender
{
    [Preferences standardPreferences].showAppInStatusBar = [sender state] == NSControlStateValueOn;
}

/* changeMarkUpdatedAsNew
 * Sets whether Vienna considers updated articles
 * as new ones.
 */
-(IBAction)changeMarkUpdatedAsNew:(id)sender
{
    [Preferences standardPreferences].markUpdatedAsNew = [sender state] == NSControlStateValueOn;
}

/* changeOpenLinksInExternalBrowser
 * Sets whether Vienna opens new links in the browser view or in
 * the user's current default browser application.
 */
-(IBAction)changeOpenLinksInExternalBrowser:(id)sender
{
    [Preferences standardPreferences].openLinksInVienna = [sender state] == NSControlStateValueOff;
}

/* changeDownloadFolder
 * Bring up the folder browser to pick a new download folder.
 */
-(IBAction)changeDownloadFolder:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.delegate = self;
    openPanel.canChooseFiles = NO;
    openPanel.canChooseDirectories = YES;
    openPanel.canCreateDirectories = YES;
    openPanel.allowsMultipleSelection = NO;
    openPanel.prompt = NSLocalizedString(@"Select",
                                         @"Label of a button on an open panel");

    openPanel.directoryURL = NSFileManager.defaultManager.vna_downloadsDirectory;
    [openPanel beginSheetModalForWindow:self.view.window
                      completionHandler:^(NSInteger returnCode) {
        if (returnCode == NSModalResponseOK) {
            NSError *error = nil;
            NSData *data = [VNASecurityScopedBookmark bookmarkDataFromFileURL:openPanel.URL
                                                                        error:&error];
            if (!error) {
                NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
                [userDefaults setObject:data forKey:MAPref_DownloadsFolderBookmark];
                [self updateDownloadsPopUp:openPanel.URL.path];
            }
        } else if (returnCode == NSModalResponseCancel) {
            [self->downloadFolder selectItemAtIndex:0];
        }
    }];
}

/* updateDownloadsPopUp
 * Update the Downloads folder popup with the specified download folder path and image.
 */
-(void)updateDownloadsPopUp:(NSString *)downloadFolderPath
{
    NSMenuItem * downloadPathItem = [downloadFolder itemAtIndex:0];
    NSImage * pathImage = [[NSWorkspace sharedWorkspace] iconForFile:downloadFolderPath];
    
    pathImage.size = NSMakeSize(16, 16);
    
    downloadPathItem.title = [[NSFileManager defaultManager] displayNameAtPath:downloadFolderPath];
    downloadPathItem.image = pathImage;

    [downloadFolder selectItemAtIndex:0];
}

/* changeCheckOnStartUp
 * Set whether Vienna checks for new articles when it starts.
 */
-(IBAction)changeCheckOnStartUp:(id)sender
{
    [Preferences standardPreferences].refreshOnStartup = [sender state] == NSControlStateValueOn;
}

/* selectDefaultLinksHandler
 * The user picked something from the list of handlers.
 */
-(IBAction)selectDefaultLinksHandler:(id)sender
{
    NSMenuItem * selectedItem = linksHandler.selectedItem;
    if (selectedItem != nil) {
        if (selectedItem.tag == -1) {
            [self handleLinkSelector];
            return;
        }
        typeof(self) __weak weakSelf = self;
        [self setDefaultApplicationForFeedScheme:[appToPathMap valueForKey:selectedItem.title]
                               completionHandler:^{
            [weakSelf refreshLinkHandler];
        }];
    } else {
        [self refreshLinkHandler];
    }
}

/* handleLinkSelector
 * Handle the 'Select...' command on the popup list of registered applications. Display the
 * file browser in the Applications folder and use that to add a new application to the
 * list.
 */
- (void)handleLinkSelector
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    NSWindow * prefPaneWindow = linksHandler.window;
    
    panel.directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationDirectory inDomain:NSLocalDomainMask appropriateForURL:nil create:NO error:nil];
    if (@available(macOS 11, *)) {
        panel.allowedContentTypes = @[UTTypeApplicationBundle];
    } else {
        panel.allowedFileTypes = @[NSFileTypeForHFSTypeCode('APPL')];
    }
    panel.prompt = NSLocalizedString(@"Select", @"Label of a button on an open panel");
    [panel beginSheetModalForWindow:prefPaneWindow completionHandler:^(NSInteger returnCode) {
        [panel orderOut:self];
        [prefPaneWindow makeKeyAndOrderFront:self];
        
        if (returnCode == NSModalResponseOK) {
            typeof(self) __weak weakSelf = self;
            [self setDefaultApplicationForFeedScheme:panel.URL
                                   completionHandler:^{
                [weakSelf refreshLinkHandler];
            }];
        } else {
            [self refreshLinkHandler];
        }
    }];
}

- (void)setDefaultApplicationForFeedScheme:(NSURL *)applicationURL
                         completionHandler:(void (^)(void))completionHandler
{
    NSString *feedURLScheme = @"feed";
    if (@available(macOS 12, *)) {
        NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
        // "Some" schemes require user consent to change the handlers. The docs
        // do not state which ones, but as of macOS 12, "feed" does not require
        // a confirmation. The completion handler is called in either case and
        // presumably returns an error if the user does not consent. If that
        // happens, the change is not applied and Vienna fails gracefully.
        [workspace setDefaultApplicationAtURL:applicationURL
                         toOpenURLsWithScheme:feedURLScheme
                            completionHandler:^(NSError * _Nullable error) {
            // This error code indicates that the user rejected the change.
            if (error && error.code == NSFileReadUnknownError) {
                os_log_error(VNA_LOG, "Handler for the feed URL scheme not changed, because consent was refused");
            } else if (error) {
                os_log_error(VNA_LOG, "Handler for the feed URL scheme not changed. Error: %{public}@ (%ld)", error.domain, error.code);
            } else {
                os_log_debug(VNA_LOG, "Handler for the feed URL scheme changed to %@", applicationURL.lastPathComponent);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler();
            });
        }];
    } else {
        CFStringRef scheme = (__bridge CFStringRef)feedURLScheme;
        NSBundle *bundle = [NSBundle bundleWithURL:applicationURL];
        CFStringRef bundleID = (__bridge CFStringRef)bundle.bundleIdentifier;
        LSSetDefaultHandlerForURLScheme(scheme, bundleID);
        completionHandler();
    }
}

/* changeCheckFrequency
 * The user changed the connect frequency drop down so save the new value and then
 * tell the main app that it changed.
 */
-(IBAction)changeCheckFrequency:(id)sender
{
    NSInteger newFrequency = checkFrequency.selectedItem.tag;
    [Preferences standardPreferences].refreshFrequency = newFrequency;
}

/* changeNewArticlesNotificationBounce
 * Change if we require user attention (by bouncing the Dock icon) when new articles are announced.
 */
-(IBAction)changeNewArticlesNotificationBounce:(id)sender
{
    Preferences * prefs = [Preferences standardPreferences];
    NSInteger currentNotificationValue = prefs.newArticlesNotification;
    if ([sender state] == NSControlStateValueOn) {
        prefs.newArticlesNotification = currentNotificationValue | VNANewArticlesNotificationBounce;
    } else {
        prefs.newArticlesNotification = currentNotificationValue & ~VNANewArticlesNotificationBounce;
    }
}

/* changeMarkReadBehaviour
 * Set the mark read behaviour based on the users selection.
 */
-(IBAction)changeMarkReadBehaviour:(id)sender
{
    float newReadInterval = ([sender selectedCell] == markReadAfterNext) ? 0 : MA_Default_Read_Interval;
    [Preferences standardPreferences].markReadInterval = newReadInterval;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// MARK: - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    return [fileManager isWritableFileAtPath:url.path];
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    BOOL isWritable = [fileManager isWritableFileAtPath:url.path];
    if (!isWritable) {
        NSString *str = NSLocalizedString(@"This folder cannot be chosen "
                                          "because you don’t have permission.",
                                          @"Message text of a modal alert");
        NSDictionary *userInfoDict = @{NSLocalizedDescriptionKey: str};
        if (outError) {
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSFileWriteNoPermissionError
                                        userInfo:userInfoDict];
        }
    }
    return isWritable;
}

@end
