//
//  AppController.m
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
//  Copyright (c) 2004-2017 Steve Palmer and Vienna contributors. All rights reserved.
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

#import "AppController.h"

@import os.log;
@import UniformTypeIdentifiers;

#import "AppController+Notifications.h"
#import "ArticleController.h"
#import "Import.h"
#import "Export.h"
#import "RefreshManager.h"
#import "StringExtensions.h"
#import "SmartFolder.h"
#import "NewSubscription.h"
#import "NewGroupFolder.h"
#import "ViennaApp.h"
#import "ActivityPanelController.h"
#import "Constants.h"
#import "Preferences.h"
#import "InfoPanelController.h"
#import "InfoPanelManager.h"
#import "DownloadManager.h"
#import "HelperFunctions.h"
#import "SearchPanel.h"
#import "SearchMethod.h"
#import "OpenReader.h"
#import "Database.h"
#import "NSURL+CaminoExtensions.h"
#import "PluginManager.h"
#import "ArticleController.h"
#import "FoldersTree.h"
#import "Article.h"
#import "TreeNode.h"
#import "Field.h"
#import "Folder.h"
#import "FolderView.h"
#import "SubscriptionModel.h"
#import "Vienna-Swift.h"
#import "GeneratedAssetSymbols.h"

#define VNA_LOG os_log_create("--", "AppController")

static void *VNAAppControllerObserverContext = &VNAAppControllerObserverContext;

@interface AppController () <InfoPanelControllerDelegate, ActivityPanelControllerDelegate, NSMenuItemValidation, NSToolbarItemValidation>

-(void)installScriptsFolderWatcher;
-(void)handleTabChange:(NSNotification *)nc;
-(void)handleFolderSelection:(NSNotification *)nc;
-(void)handleCheckFrequencyChange:(NSNotification *)nc;
-(void)handleDidBecomeKeyWindow:(NSNotification *)nc;
-(void)handleReloadPreferences:(NSNotification *)nc;
-(void)handleShowAppInStatusBar:(NSNotification *)nc;
-(void)setAppStatusBarIcon;
-(void)updateNewArticlesNotification;
-(void)showAppInStatusBar;
-(void)initSortMenu;
-(void)initColumnsMenu;
-(void)initScriptsMenu;
-(void)doEditFolder:(Folder *)folder;
-(BOOL)installFilename:(NSString *)srcFile toPath:(NSString *)path;
-(void)runAppleScript:(NSString *)scriptName;
-(void)sendBlogEvent:(NSString *)externalEditorBundleIdentifier title:(NSString *)title url:(NSString *)url body:(NSString *)body author:(NSString *)author guid:(NSString *)guid;
-(void)updateAlternateMenuTitle;
-(void)updateSearchPlaceholderAndSearchMethod;
-(void)updateCloseCommands;
-(IBAction)cancelAllRefreshesToolbar:(id)sender;

@property (nonatomic) VNADispatchTimer *refreshTimer;

@property (nonatomic) MainWindowController *mainWindowController;
@property (nonatomic) ArticleController *articleController;
@property (nonatomic) ActivityPanelController *activityPanelController;
@property (nonatomic) VNADirectoryMonitor *directoryMonitor;
@property (weak, nonatomic) FolderView *outlineView;
@property (weak, nonatomic) NSSearchField *toolbarSearchField;

@end

@implementation AppController {
    IBOutlet NSMenuItem *closeTabItem;
    IBOutlet NSMenuItem *closeAllTabsItem;
    IBOutlet NSMenuItem *closeWindowItem;
    IBOutlet NSMenuItem *sortByMenu;
    IBOutlet NSMenuItem *columnsMenu;

    SmartFolder *smartFolder;
    NewGroupFolder *groupFolder;
    SearchPanel *searchPanel;

    NSMutableDictionary *scriptPathMappings;
    NSStatusItem *appStatusItem;
    NSInteger lastCountOfUnread;
    NSMenuItem *scriptsMenuItem;
    BOOL didCompleteInitialisation;
    NSString *searchString;

    NewSubscription *_rssFeed;
}

@synthesize rssFeed = _rssFeed;

/* init
 * Class instance initialisation.
 */
-(instancetype)init
{
	if ((self = [super init]) != nil) {
		scriptPathMappings = [[NSMutableDictionary alloc] init];
		lastCountOfUnread = 0;
		appStatusItem = nil;
		scriptsMenuItem = nil;
		didCompleteInitialisation = NO;
		searchString = nil;
	}
	return self;
}

// TODO: Figure out where to load this
- (PluginManager *)pluginManager {
    if (!_pluginManager) {
        _pluginManager = [PluginManager new];
        [_pluginManager resetPlugins];
    }

    return _pluginManager;
}

/* awakeFromNib
 * Do all the stuff that only makes sense after our NIB has been loaded and connected.
 */
-(void)awakeFromNib
{
    // We need to register the handlers early to catch events fired on launch.
    NSAppleEventManager *em = [NSAppleEventManager sharedAppleEventManager];
    [em setEventHandler:self
            andSelector:@selector(getUrl:withReplyEvent:)
          forEventClass:kInternetEventClass
             andEventID:kAEGetURL];
    [em setEventHandler:self
            andSelector:@selector(getUrl:withReplyEvent:)
          forEventClass:'WWW!'    // A particularly ancient AppleEvent that dates
             andEventID:'OURL'];  // back to the Spyglass days.
}

/* doSafeInitialisation
 * Do the stuff that requires that all NIBs and the database are awoken. I can't find a notification
 * from Cocoa for this so we hack it after applicationDidFinishLaunching
 */
-(void)doSafeInitialisation
{
	static BOOL doneSafeInit = NO;
	if (!doneSafeInit) {
		[self.foldersTree initialiseFoldersTree];

		Preferences * prefs = [Preferences standardPreferences];

		// Select the folder and article from the last session
		NSInteger previousFolderId = [prefs integerForKey:MAPref_CachedFolderID];
		NSString * previousArticleGuid = [prefs stringForKey:MAPref_CachedArticleGUID];
		if (previousArticleGuid.vna_isBlank) {
			previousArticleGuid = nil;
		}
		[self.articleController selectFolderAndArticle:previousFolderId guid:previousArticleGuid];

		[self.mainWindow makeFirstResponder:(previousArticleGuid != nil) ? ((NSView<BaseView> *)self.browser.primaryTab.view).mainView : self.foldersTree.mainView];

        // 300s (5m) is the minimum refresh frequency.
        if (prefs.refreshFrequency >= 300) {
            [self scheduleRefreshWithFrequency:prefs.refreshFrequency
                            refreshImmediately:prefs.refreshOnStartup];
        } else if (prefs.refreshOnStartup) {
            [self refreshAllSubscriptions];
        }

		doneSafeInit = YES;
		
	}
	didCompleteInitialisation = YES;
}

#pragma mark Accessor Methods

- (NewSubscription *)rssFeed {
    if (!_rssFeed) {
        _rssFeed = [[NewSubscription alloc] initWithDatabase:db];
        _rssFeed.pluginManager = self.pluginManager;
    }
    return _rssFeed;
}

/* installScriptsFolderWatcher
 * Install a handler to notify of changes in the scripts folder.
 * The handler is a code block which triggers a refresh of the scripts menu
 */
- (void)installScriptsFolderWatcher {
    NSURL *path = NSFileManager.defaultManager.vna_applicationScriptsDirectory;
    self.directoryMonitor = [[VNADirectoryMonitor alloc] initWithDirectories:@[path]];
    typeof(self) __weak weakSelf = self;
    void (^handler)(void) = ^{
        [weakSelf initScriptsMenu];
    };
    NSError *error;
    [self.directoryMonitor startWithEventHandler:handler
                                   dispatchQueue:dispatch_get_main_queue()
                                           error:&error];
    if (error) {
        os_log_error(VNA_LOG, "Failed to watch scripts directory. Reason: %{public}@", error.localizedDescription);
    }
}

#pragma mark Application Delegate

/* applicationDidFinishLaunching
 * Handle post-load activities.
 */
-(void)applicationDidFinishLaunching:(NSNotification *)aNot
{
	self.mainWindowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindowController"];
    self.mainWindowController.articleController = self.articleController;
	self.mainWindow = self.mainWindowController.window;

	self.browser = self.mainWindowController.browser;

	self.outlineView = self.mainWindowController.outlineView;
    self.foldersTree.controller = self;
    self.foldersTree.outlineView = self.outlineView;
    self.outlineView.delegate = self.foldersTree;
    self.outlineView.dataSource = self.foldersTree;

    self.articleController.foldersTree = self.foldersTree;

	self.toolbarSearchField = self.mainWindowController.toolbarSearchField;

    // Set the delegates
    [NSApplication sharedApplication].delegate = self;
	
	// Register a bunch of notifications
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleFolderSelection:) name:MA_Notify_FolderSelectionChange object:nil];
	[nc addObserver:self selector:@selector(handleCheckFrequencyChange:) name:MA_Notify_CheckFrequencyChange object:nil];
	[nc addObserver:self selector:@selector(handleEditFolder:) name:MA_Notify_EditFolder object:nil];
	[nc addObserver:self selector:@selector(handleRefreshStatusChange:) name:MA_Notify_RefreshStatus object:nil];
	[nc addObserver:self selector:@selector(handleTabChange:) name:MA_Notify_TabChanged object:nil];
	[nc addObserver:self selector:@selector(handleTabCountChange:) name:MA_Notify_TabCountChanged object:nil];
	[nc addObserver:self selector:@selector(handleDidBecomeKeyWindow:) name:NSWindowDidBecomeKeyNotification object:nil];
	[nc addObserver:self selector:@selector(handleReloadPreferences:) name:MA_Notify_PreferenceChange object:nil];
	[nc addObserver:self selector:@selector(handleShowAppInStatusBar:) name:MA_Notify_ShowAppInStatusBarChanged object:nil];
	[nc addObserver:self selector:@selector(handleUpdateUnreadCount:) name:MA_Notify_FoldersUpdated object:nil];
	//Open Reader Notifications
    [nc addObserver:self selector:@selector(handleGoogleAuthFailed:) name:MA_Notify_GoogleAuthFailed object:nil];

	// Initialize the database
	if ((db = [Database sharedManager]) == nil) {
		[NSApp terminate:nil];
		return;
	}

    // Restore the most recent layout
    [self.articleController setLayout:Preferences.standardPreferences.layout];

	// Initialize the Sort By and Columns menu
	[self initSortMenu];
	[self initColumnsMenu];

    // Load the plug-ins into the main menu.
    [self populatePluginsMenu];

    // Observe changes to the plug-in count.
    [self.pluginManager addObserver:self
                         forKeyPath:NSStringFromSelector(@selector(numberOfPlugins))
                            options:0
                            context:VNAAppControllerObserverContext];

	// Load the styles into the main menu.
    [self populateStyleMenu];

	// Show the current unread count on the app icon
	[self showUnreadCountOnApplicationIconAndWindowTitle];
	
	// Set alternate in main menu for opening pages, and check for correct title of menu item
	// This is a hack, because Interface Builder refuses to set alternates with only the shift key as modifier.
	NSMenuItem * alternateItem = menuItemWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	if (alternateItem != nil) {
        alternateItem.keyEquivalentModifierMask = NSEventModifierFlagOption;
		[alternateItem setAlternate:YES];
	}
	alternateItem = menuItemWithAction(@selector(viewArticlePagesInAlternateBrowser:));
	if (alternateItem != nil) {
        alternateItem.keyEquivalentModifierMask = NSEventModifierFlagOption;
		[alternateItem setAlternate:YES];
	}
	[self updateAlternateMenuTitle];
	
	// Create a menu for the search field
	// The menu title doesn't appear anywhere so we don't localise it. The titles of each
	// item is localised though.	
	((NSSearchFieldCell *)self.toolbarSearchField.cell).searchMenuTemplate = self.searchFieldMenu;
	
	// Set the placeholder string for the global search field
	SearchMethod * currentSearchMethod = [Preferences standardPreferences].searchMethod;
    self.toolbarSearchField.placeholderString = currentSearchMethod.displayName;
	
	// Add Scripts menu if we have any scripts
	if (!hasOSScriptsMenu()) {
		[self initScriptsMenu];
	}

	// Add the app to the status bar if needed.
	[self showAppInStatusBar];

    // User Notification Center delegate
    VNAUserNotificationCenter.current.delegate = self;

	// Register to be notified when the scripts folder changes.
	if (!hasOSScriptsMenu()) {
		[self installScriptsFolderWatcher];
	}
	
	// Fix up the Close commands
	[self updateCloseCommands];
	
	[self showMainWindow:self];
	
	// Hook up the key sequence properly now that all NIBs are loaded.
	self.foldersTree.mainView.nextKeyView = ((NSView<BaseView> *)self.browser.primaryTab.view).mainView;
    
	// Do safe initialisation.
	[self performSelector:@selector(doSafeInitialisation)
			   withObject:nil
			   afterDelay:0];

}

/// Handle the notification sent when the application is reopened, such as when
/// the Dock icon is clicked. If the main window was previously hidden, we show
/// it again here.
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)flag
{
    if (!didCompleteInitialisation) {
        return NO;
    }

    if (!flag) {
        [self showMainWindow:self];
    }

    return YES;
}

/* applicationShouldTerminate
 * This function is called when the user wants to close Vienna. First we check to see
 * if a connection or import is running and that all articles are saved.
 */
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if (DownloadManager.sharedInstance.hasActiveDownloads) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"One or more downloads are in progress", @"Message text of an alert");
        alert.informativeText = NSLocalizedString(@"If you quit Vienna now, all downloads will stop.", @"Message text of an alert");
        [alert addButtonWithTitle:NSLocalizedString(@"Quit", @"Title of a button on an alert")];
        [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"cancel.button",
                                                                    nil,
                                                                    NSBundle.mainBundle,
                                                                    @"Cancel",
                                                                    @"Title of a button on an alert")];
        NSModalResponse alertResponse = [alert runModal];

        if (alertResponse == NSAlertSecondButtonReturn) {
            [[NSNotificationCenter defaultCenter]  removeObserver:self];
            return NSTerminateCancel;
        }
    }

    if (!didCompleteInitialisation) {
        [[NSNotificationCenter defaultCenter]  removeObserver:self];
        return NSTerminateNow;
    }

    switch ([Preferences.standardPreferences integerForKey:MAPref_EmptyTrashNotification]) {
        case VNAEmptyTrashNone:
            break;

        case VNAEmptyTrashWithoutWarning:
            if (!db.trashEmpty) {
                [db purgeDeletedArticles];
            }
            break;

        case VNAEmptyTrashWithWarning: {
            if (db.trashEmpty) {
                break;
            }

            NSAlert *alert = [NSAlert new];
            alert.messageText = NSLocalizedString(@"There are deleted articles in the trash. Would you like to empty the trash before quitting?", @"Message text of an alert");
            alert.showsSuppressionButton = YES;
            alert.suppressionButton.title = NSLocalizedString(@"Do not show this warning again", @"Title of a checkbox on an alert");
            [alert addButtonWithTitle:NSLocalizedString(@"Empty Trash", @"Title of a button on an alert")];
            [alert addButtonWithTitle:NSLocalizedString(@"Don’t Empty Trash", @"Title of a button on an alert")];
            // The "Don’t Empty Trash" button should respond to the escape key.
            for (NSButton *button in alert.buttons) {
                if (button.tag != NSAlertSecondButtonReturn) {
                    continue;
                }
                unichar escapeKey[] = {0x001B};
                button.keyEquivalent = [NSString stringWithCharacters:escapeKey
                                                               length:1];
            }

            NSModalResponse alertResponse = [alert runModal];

            // The user pressed the "Empty Trash" button.
            if (alertResponse == NSAlertFirstButtonReturn) {
                [db purgeDeletedArticles];
            }

            if (alert.suppressionButton.state == NSControlStateValueOn) {
                Preferences *preferences = Preferences.standardPreferences;
                // The user pressed the "Empty Trash" button
                if (alertResponse == NSAlertFirstButtonReturn) {
                    [preferences setInteger:VNAEmptyTrashWithoutWarning
                                     forKey:MAPref_EmptyTrashNotification];
                // The user pressed the "Don’t Empty Trash" button
                } else if (alertResponse == NSAlertSecondButtonReturn) {
                    [preferences setInteger:VNAEmptyTrashNone
                                     forKey:MAPref_EmptyTrashNotification];
                }
            }
            break;
        }
        default:
            break;
    }

    return NSTerminateNow;
}

- (void)unregisterEventHandlers
{
    NSAppleEventManager* em = [NSAppleEventManager sharedAppleEventManager];
    [em removeEventHandlerForEventClass:kInternetEventClass
                             andEventID:kAEGetURL];
}

/* applicationWillTerminate
 * This is where we put the clean-up code.
 */
-(void)applicationWillTerminate:(NSNotification *)aNotification
{
    [self unregisterEventHandlers];
    
	if (didCompleteInitialisation) {
		// Close the activity window explicitly to force it to
		// save its split bar position to the preferences.
		NSWindow *activityPanel = self.activityPanelController.window;
		[activityPanel performClose:self];
		
		// Put back the original app icon
		[NSApp.dockTile setBadgeLabel:nil];
		
		// Save the open tabs
		[self.browser saveOpenTabs];
		
		// Remember the article list column position, sizes, etc.
		[self.articleController saveTableSettings];
		[self.foldersTree saveFolderSettings];
		
		// Remove "article" directory in cache
		NSFileManager * fileManager = [NSFileManager defaultManager];
		NSURL * dirUrl = [fileManager.vna_cachesDirectory URLByAppendingPathComponent:@"article"];
		[fileManager removeItemAtURL:dirUrl error:nil];
		
        [[NSNotificationCenter defaultCenter]  removeObserver:self];
	}
	[db optimizeDatabase];
	[db close];
}

/* applicationSupportsSecureRestorableState [delegate]
 */
-(BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    // We do not use override NSApplication delegate `initWithCoder` method, nor the methods
    // for restoring application state, so we are fine with SecureCoding.
    return YES;
}

/* openFile [delegate]
 * Called when the user opens a data file associated with Vienna by clicking in the finder or dragging it onto the dock.
 */
-(BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	Preferences * prefs = [Preferences standardPreferences];
	if ([filename.pathExtension isEqualToString:@"viennastyle"]) {
		NSString * styleName = filename.lastPathComponent.stringByDeletingPathExtension;
		if (![self installFilename:filename toPath:ArticleStyleLoader.stylesDirectoryURL.path]) {
			prefs.displayStyle = styleName;
		} else {
            [self populateStyleMenu];
			prefs.displayStyle = styleName;
            runOKAlertPanel(NSLocalizedString(@"Vienna has installed a new style", nil), NSLocalizedString(@"The style \"%@\" has been installed to your Styles folder and added to the Style menu.", nil), styleName);
		}
		return YES;
	}
	if ([filename.pathExtension isEqualToString:VNAPluginBundleExtension]) {
		NSString * path = PluginManager.pluginsDirectoryURL.path;
		if ([self installFilename:filename toPath:path]) {
			runOKAlertPanel(NSLocalizedString(@"Plugin installed", nil), NSLocalizedString(@"A new plugin has been installed. It is now available from the menu and you can add it to the toolbar.", nil));			
			NSString * fullPath = [path stringByAppendingPathComponent:filename.lastPathComponent];
            [self.pluginManager loadPlugin:fullPath];
		}
		return YES;
	}
	if ([filename.pathExtension isEqualToString:@"scpt"]) {
		NSFileManager *fileManager = NSFileManager.defaultManager;
		NSURL *scriptsURL = fileManager.vna_applicationScriptsDirectory;
		if ([self installFilename:filename toPath:scriptsURL.path]) {
			if (!hasOSScriptsMenu()) {
				[self initScriptsMenu];
			}
		}
		return YES;
	}
	if ([filename.pathExtension isEqualToString:@"opml"]) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"Import subscriptions from OPML file?", nil);
        alert.informativeText = NSLocalizedString(@"Do you really want to import the subscriptions from the specified OPML file?", nil);
        [alert addButtonWithTitle:NSLocalizedString(@"Import", @"Title of a button on an alert")];
        [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"cancel.button",
                                                                    nil,
                                                                    NSBundle.mainBundle,
                                                                    @"Cancel",
                                                                    @"Title of a button on an alert")];
        NSModalResponse alertResponse = [alert runModal];

        if (alertResponse == NSAlertFirstButtonReturn) {
            [Import importFromFile:filename];
            return YES;
        } else {
            return NO;
        }
	}
    if ([filename.pathExtension isEqualToString:@"webloc"]) {
        NSURL* url = [NSURL URLFromInetloc:filename];
        if (!self.mainWindow.visible) {
            [self.mainWindow makeKeyAndOrderFront:self];
        }
        if (url != nil && !db.readOnly) {
            [self.rssFeed newSubscription:self.mainWindow initialURL:url.absoluteString];
		    return YES;
        } else {
            return NO;
        }
    }
	return NO;
}

/* installFilename
 * Copies the folder at srcFile to the specified path. The path is created if it doesn't already exist and
 * an error is reported if we fail to create the path. The return value is the result of copying the source
 * folder to the new path.
 */
-(BOOL)installFilename:(NSString *)srcFile toPath:(NSString *)path
{
	NSString * fullPath = [path stringByAppendingPathComponent:srcFile.lastPathComponent];
	
	// Make sure we actually have a destination folder.
	NSFileManager * fileManager = [NSFileManager defaultManager];
	BOOL isDir = NO;
	
	if (![fileManager fileExistsAtPath:path isDirectory:&isDir]) {
		if (![fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:NULL error:NULL]) {
			runOKAlertPanel(NSLocalizedString(@"Cannot create folder", nil), NSLocalizedString(@"The \"%@\" folder cannot be created.", nil), path);
			return NO;
		}
	}

	[fileManager removeItemAtPath:fullPath error:nil];
	return [fileManager copyItemAtPath:srcFile toPath:fullPath error:nil];
}

/* searchFieldMenu
 * Allocates a popup menu for one of the search fields we use.
 */
-(NSMenu *)searchFieldMenu
{
	NSMenu * cellMenu = [NSMenu new];
	
	NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recent Searches", nil) action:NULL keyEquivalent:@""];
    item.tag = NSSearchFieldRecentsTitleMenuItemTag;
	[cellMenu insertItem:item atIndex:0];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recents", nil) action:NULL keyEquivalent:@""];
    item.tag = NSSearchFieldRecentsMenuItemTag;
	[cellMenu insertItem:item atIndex:1];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear Recent Searches", nil) action:NULL keyEquivalent:@""];
    item.tag = NSSearchFieldClearRecentsMenuItemTag;
	[cellMenu insertItem:item atIndex:2];
	
	SearchMethod * searchMethod;
	NSString * friendlyName;

	[cellMenu addItem: [NSMenuItem separatorItem]];

    NSArray *builtInSearchMethods = @[
        SearchMethod.allArticlesSearchMethod,
        SearchMethod.currentWebPageSearchMethod,
        SearchMethod.searchForFoldersMethod
    ];

	// Add all built-in search methods to the menu. 
	for (searchMethod in builtInSearchMethods) {
		friendlyName = searchMethod.displayName;
		item = [[NSMenuItem alloc] initWithTitle:friendlyName
                                          action:@selector(setSearchMethod:)
                                   keyEquivalent:@""];
		item.representedObject = searchMethod;
		
		// Is this the currently set search method? If yes, mark it as such.
		if ( [friendlyName isEqualToString:[Preferences standardPreferences].searchMethod.displayName] ) {
			item.state = NSControlStateValueOn;
		}
		
        if ([searchMethod isEqualTo:SearchMethod.searchForFoldersMethod]) {
            [cellMenu addItem:[NSMenuItem separatorItem]];
        }

        [cellMenu addItem:item];
	}
	
	// Add all available plugged-in search methods to the menu.
	NSMutableArray * searchMethods = [NSMutableArray arrayWithArray:self.pluginManager.searchMethods];
	if (searchMethods.count > 0) {
		[cellMenu addItem: [NSMenuItem separatorItem]];
		
		for (searchMethod in searchMethods) {
			if (!searchMethod.displayName) { 
				continue;
			}
			item = [[NSMenuItem alloc] initWithTitle:searchMethod.displayName action:@selector(setSearchMethod:) keyEquivalent:@""];
			item.representedObject = searchMethod;
			// Is this the currently set search method? If yes, mark it as such.
			if ( [searchMethod.displayName isEqualToString: [Preferences standardPreferences].searchMethod.displayName] ) {
				item.state = NSControlStateValueOn;
			}
			[cellMenu addItem:item];
		}
	} 
	return cellMenu;
}

/* setSearchMethod 
 */
-(void)setSearchMethod:(NSMenuItem *)sender
{
	[Preferences standardPreferences].searchMethod = sender.representedObject;
	((NSSearchFieldCell *)self.toolbarSearchField.cell).placeholderString = sender.title;
}

/* reindexDatabase
 * Reindex the database
 */
-(IBAction)reindexDatabase:(id)sender
{
	[db reindexDatabase];
}

/* getUrl
 * Handle http https URL Scheme passed to applicaton
 */
- (void)getUrl:(NSAppleEventDescriptor *)event
withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *urlStr = [event paramDescriptorForKeyword:keyDirectObject].stringValue;
    if (urlStr) {
        [self.rssFeed newSubscription:self.mainWindow initialURL:urlStr];
    }
}

/** openURLsInDefaultBrowser
 * Open an array of URLs in whatever the user has registered as their
 * default system browser.
 */
- (void)openURLsInDefaultBrowser:(NSArray<NSURL *> *)urlArray {
	Preferences * prefs = [Preferences standardPreferences];
    BOOL openLinksInBackground = prefs.openLinksInBackground;
    
    if ([urlArray.firstObject.scheme isEqualToString:@"mailto"]) {
        openLinksInBackground = NO;
    }

	// This line is a workaround for OS X bug rdar://4450641
    if (openLinksInBackground) {
		[self.mainWindow orderFront:self];
    }
	
    if (@available(macOS 10.15, *)) {
        NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
        configuration.activates = !openLinksInBackground;
        for (NSURL *url in urlArray) {
            if (!url) {
                continue;
            }
            [NSWorkspace.sharedWorkspace openURL:url
                                   configuration:configuration
                               completionHandler:^(__unused NSRunningApplication * _Nullable app,
                                                   NSError * _Nullable error) {
                if (error) {
                    os_log_error(VNA_LOG,
                                 "Could not open URL %@ in external browser. Reason: %{public}@",
                                 url.path, error.localizedDescription);
                }
            }];
        }
    } else {
        NSWorkspaceLaunchOptions lOptions = openLinksInBackground ? (NSWorkspaceLaunchWithoutActivation | NSWorkspaceLaunchDefault) : NSWorkspaceLaunchDefault;
        [NSWorkspace.sharedWorkspace openURLs:urlArray
                      withAppBundleIdentifier:nil
                                      options:lOptions
               additionalEventParamDescriptor:nil
                            launchIdentifiers:nil];
    }
}

/* openURLInDefaultBrowser
 * Open the specified URL in whatever the user has registered as their
 * default system browser.
 */
-(void)openURLInDefaultBrowser:(NSURL *)url
{
	[self openURLsInDefaultBrowser:@[url]];
    
}

- (IBAction)newTab:(id)sender
{
    (void)[self.browser createNewTab:nil inBackground:NO load:NO];
}

/* openWebLocation
 * Puts the focus in the address bar of the web browser tab. If one isn't open,
 * we create an empty one.
 */
-(IBAction)openWebLocation:(id)sender
{
	id<Tab> activeBrowserTab = self.browser.activeTab;

    [self showMainWindow:self];
	if (!activeBrowserTab) {
		(void)[self.browser createNewTab:nil inBackground:NO load:NO];
    } else {
        [self.browser.activeTab activateAddressBar];
	}
}

/* openURLFromString
 * Open a URL in either the internal Vienna browser or an external browser depending on
 * whatever the user has opted for.
 */
-(void)openURLFromString:(NSString *)urlString inPreferredBrowser:(BOOL)openInPreferredBrowserFlag
{
	NSURL * theURL = [NSURL URLWithString:urlString];
	if (theURL == nil) {
		theURL = cleanedUpUrlFromString(urlString);
	}
	[self openURL:theURL inPreferredBrowser:openInPreferredBrowserFlag];
}

/** openURLs
 * Open an array of URLs in either the internal Vienna browser or an external browser depending on
 * whatever the user has opted for.
 */
-(void)openURLs:(NSArray *)urls inPreferredBrowser:(BOOL)openInPreferredBrowserFlag
{
	Preferences * prefs = [Preferences standardPreferences];
	BOOL openURLInVienna = prefs.openLinksInVienna;
	if (!openInPreferredBrowserFlag) {
		openURLInVienna = (!openURLInVienna);
	}
	if (openURLInVienna) {
		BOOL openInBackground = prefs.openLinksInBackground;
        if ([NSEvent modifierFlags] & NSEventModifierFlagShift) {
            openInBackground = !openInBackground;
        }

        for (NSURL * url in urls) {
			(void)[self.browser createNewTab:url inBackground:openInBackground load:true];
        }
        [self.mainWindow makeFirstResponder:((NSView<BaseView> *)self.browser.primaryTab.view).mainView];
	} else {
		[self openURLsInDefaultBrowser:urls];
	}
}

/* openURL
 * Open a URL in either the internal Vienna browser or an external browser depending on
 * whatever the user has opted for.
 */
-(void)openURL:(NSURL *)url inPreferredBrowser:(BOOL)openInPreferredBrowserFlag
{
	if (url == nil) {
		NSLog(@"Called openURL:inPreferredBrowser: with nil url.");
		return;
	}
	[self openURLs:@[url] inPreferredBrowser:openInPreferredBrowserFlag];
}

/* downloadEnclosure
 * Downloads the enclosures of the currently selected articles
 */
-(IBAction)downloadEnclosure:(id)sender
{
	for (Article * currentArticle in self.articleController.markedArticleRange) {
		if (currentArticle.hasEnclosure) {
			[[DownloadManager sharedInstance] downloadFileFromURL:currentArticle.enclosure];
		}
	}
}

/* openVienna
 * Calls into showMainWindow but activates the app first.
 */
- (IBAction)openVienna:(id)sender
{
    if (@available(macOS 14, *)) {
        [NSApp activate];
    } else {
        [NSApp activateIgnoringOtherApps:YES];
    }
    if (NSApp.isActive) {
        [self showMainWindow:sender];
    }
}

/* showMainWindow
 * Display the main window.
 */
-(IBAction)showMainWindow:(id)sender
{
	[self.mainWindow makeKeyAndOrderFront:self];
}

/* keepFoldersArranged
 * Toggle the arrangement of the folders list.
 */
-(IBAction)keepFoldersArranged:(id)sender
{
	[Preferences standardPreferences].foldersTreeSortMethod = [sender tag];
}


/* exportSubscriptions
 * Export the list of RSS subscriptions as an OPML file.
 */
-(IBAction)exportSubscriptions:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];

    // Create the accessory view
    ExportAccessoryViewController *accessoryController = [[ExportAccessoryViewController alloc] initWithNibName:@"ExportAccessoryViewController"
                                                                                                         bundle:nil];

    // If multiple selections in the folder list, default to selected folders
    // for simplicity.
    if (self.foldersTree.countOfSelectedFolders > 1) {
        accessoryController.mode = ExportModeSelectedFeeds;
    } else {
        accessoryController.mode = ExportModeAllFeeds;
    }
    
    panel.accessoryView = accessoryController.view;
    if (@available(macOS 11, *)) {
        panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"opml"]];
    } else {
        panel.allowedFileTypes = @[@"opml"];
    }
    [panel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger returnCode) {
        if (returnCode == NSModalResponseOK) {
            [panel orderOut:self];
            
            NSInteger countExported = [Export exportToFile:panel.URL.path
                                           fromFoldersTree:self.foldersTree
                                                 selection:accessoryController.mode == ExportModeSelectedFeeds
                                                withGroups:accessoryController.preserveFolders];
            
            if (countExported < 0) {
                NSAlert *alert = [NSAlert new];
                alert.messageText = NSLocalizedString(@"Cannot create export output file", nil);
                alert.informativeText = NSLocalizedString(@"The specified export output file could not be created. Check that it is not locked and no other application is using it.", nil);
                [alert beginSheetModalForWindow:self.mainWindow completionHandler:nil];
            } else {
                // Announce how many we successfully imported
                NSAlert *alert = [NSAlert new];
                alert.alertStyle = NSAlertStyleInformational;
                alert.messageText = NSLocalizedString(@"Export Completed", nil);
                alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"%d subscriptions successfully exported", nil), (int)countExported];
                [alert runModal];
            }
        }
    }];
}


/* importSubscriptions
 * Import an OPML file which lists RSS feeds.
 */
-(IBAction)importSubscriptions:(id)sender
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    [panel beginSheetModalForWindow:self.mainWindow
                  completionHandler: ^(NSInteger returnCode) {
                      
                      if (returnCode == NSModalResponseOK) {
                          [panel orderOut:self];
                          [Import importFromFile:panel.URL.path];
                      }
                  }];
    
    //panel = nil;
}


/* runAppleScript
 * Run an AppleScript script given a fully qualified path to the script.
 */
-(void)runAppleScript:(NSString *)scriptName
{
	NSDictionary * errorDictionary;
	
	NSURL * scriptURL = [NSURL fileURLWithPath:scriptName];
	NSAppleScript * appleScript = [[NSAppleScript alloc] initWithContentsOfURL:scriptURL error:&errorDictionary];
	if (appleScript == nil) {
		NSString * baseScriptName = scriptName.lastPathComponent.stringByDeletingPathExtension;
		runOKAlertPanel([NSString stringWithFormat:NSLocalizedString(@"Error loading script '%@'", nil), baseScriptName],
						[errorDictionary valueForKey:NSAppleScriptErrorMessage]);
	} else {
		NSAppleEventDescriptor * resultEvent = [appleScript executeAndReturnError:&errorDictionary];
		if (resultEvent == nil) {
			NSString * baseScriptName = scriptName.lastPathComponent.stringByDeletingPathExtension;
			runOKAlertPanel([NSString stringWithFormat:NSLocalizedString(@"AppleScript Error in '%@' script", nil), baseScriptName],
							[errorDictionary valueForKey:NSAppleScriptErrorMessage]);
		}
	}
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{
    if (self.mainWindow.keyWindow) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"Open Reader Authentication Failed",nil);
        if (![nc.object isEqualToString:@""]) {
            alert.informativeText = nc.object;
        } else {
            alert.informativeText = NSLocalizedString(@"Make sure the username and password needed to access the Open Reader server are correctly set in Vienna's preferences. Also check your network access.",nil);
        }
        [alert beginSheetModalForWindow:self.mainWindow completionHandler:^(NSModalResponse returnCode) {
            [[OpenReader sharedManager] clearAuthentication];
        }];
    }
}

/* initSortMenu
 * Create the sort popup menu.
 */
-(void)initSortMenu
{
	NSMenu * sortSubmenu = [NSMenu new];
	
	// Add the fields which are sortable to the menu.
	for (Field * field in [db arrayOfFields]) {
		// Filter out columns we don't sort on. Later we should have an attribute in the
		// field object itself based on which columns we can sort on.
		if (field.tag != VNAArticleFieldTagParent &&
			field.tag != VNAArticleFieldTagGUID &&
			field.tag != VNAArticleFieldTagDeleted &&
			field.tag != VNAArticleFieldTagHeadlines &&
			field.tag != VNAArticleFieldTagSummary &&
			field.tag != VNAArticleFieldTagLink &&
			field.tag != VNAArticleFieldTagText &&
			field.tag != VNAArticleFieldTagEnclosureDownloaded &&
			field.tag != VNAArticleFieldTagEnclosure)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:field.displayName action:@selector(doSortColumn:) keyEquivalent:@""];
			menuItem.representedObject = field;
			[sortSubmenu addItem:menuItem];
		}
	}
	
	// Add the separator.
	[sortSubmenu addItem:[NSMenuItem separatorItem]];

	// Now add the ascending and descending menu items.
	NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Ascending", nil) action:@selector(doSortDirection:) keyEquivalent:@""];
	menuItem.representedObject = @YES;
	[sortSubmenu addItem:menuItem];
	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Descending", nil) action:@selector(doSortDirection:) keyEquivalent:@""];
	menuItem.representedObject = @NO;
	[sortSubmenu addItem:menuItem];
	
	// Set the submenu
	sortByMenu.submenu = sortSubmenu;
}

/* initColumnsMenu
 * Create the columns popup menu.
 */
-(void)initColumnsMenu
{
	NSMenu * columnsSubMenu = [NSMenu new];
	
	for (Field * field in [db arrayOfFields]) {
		// Filter out columns we don't view in the article list. Later we should have an attribute in the
		// field object based on which columns are visible in the tableview.
		if (field.tag != VNAArticleFieldTagText && 
			field.tag != VNAArticleFieldTagGUID &&
			field.tag != VNAArticleFieldTagDeleted &&
			field.tag != VNAArticleFieldTagParent &&
			field.tag != VNAArticleFieldTagHeadlines &&
			field.tag != VNAArticleFieldTagEnclosureDownloaded)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:field.displayName action:@selector(doViewColumn:) keyEquivalent:@""];
			menuItem.representedObject = field;
			[columnsSubMenu addItem:menuItem];
		}
	}
	columnsMenu.submenu = columnsSubMenu;
}

- (void)populatePluginsMenu {
    NSMenu *menu = ((ViennaApp *)NSApp).articleMenu;

    if (self.pluginManager.numberOfPlugins > 0) {
        [menu addItem:[NSMenuItem separatorItem]];
    }
    
    for (NSMenuItem *menuItem in self.pluginManager.menuItems) {
        [menu addItem:menuItem];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (context != VNAAppControllerObserverContext) {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
        return;
    }

    if ([keyPath isEqualToString:NSStringFromSelector(@selector(numberOfPlugins))]) {
        NSMenu *menu = ((ViennaApp *)NSApp).articleMenu;

        // Remove any previously added plug-in menu items.
        for (NSMenuItem *menuItem in menu.itemArray) {
            if (menuItem.target == self.pluginManager) {
                [menu removeItem:menuItem];
            }
        }

        // If the last remaining item is a separator, remove it too.
        NSMenuItem *lastMenuItem = menu.itemArray.lastObject;
        if (lastMenuItem.isSeparatorItem) {
            [menu removeItem:lastMenuItem];
        }

        // Repopulate the menu.
        [self populatePluginsMenu];
    }
}

/* initScriptsMenu
 * Look in the Scripts folder and if there are any scripts, add a Scripts menu and populate
 * it with the names of the scripts we've found.
 *
 * Note that there are two places we look for scripts: inside the app resource for scripts that
 * are bundled with the application, and in the standard Mac OSX application script folder which
 * is where the sysem-wide script menu also looks.
 */
- (void)initScriptsMenu {
	// Valid script file extensions
	NSArray * exts = @[@"scpt"];
	
	// Dump the current mappings
	[scriptPathMappings removeAllObjects];
	
	// Add scripts within the app resource
	NSString * path = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"Scripts"];
	loadMapFromPath(path, scriptPathMappings, NO, exts);
	
	// Add scripts that the user created and stored in the scripts folder
	NSFileManager *fileManager = NSFileManager.defaultManager;
	NSURL *scriptsURL = fileManager.vna_applicationScriptsDirectory;
	loadMapFromPath(scriptsURL.path, scriptPathMappings, NO, exts);
	
	// Add the contents of the scriptsPathMappings dictionary keys to the menu sorted
	// by key name.
	NSArray * sortedMenuItems = [scriptPathMappings.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSInteger count = sortedMenuItems.count;

	// Insert the Scripts menu to the left of the Help menu only if
	// we actually have any scripts.
	if (count > 0) {
        NSMenu *scriptsMenu = [[NSMenu alloc] initWithTitle:@""];

		NSInteger index;
		for (index = 0; index < count; ++index) {
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:sortedMenuItems[index]
															   action:@selector(doSelectScript:)
														keyEquivalent:@""];
			[scriptsMenu addItem:menuItem];
		}
		
		[scriptsMenu addItem:[NSMenuItem separatorItem]];
		NSMenuItem * menuItem;
		
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Scripts Folder", nil) action:@selector(doOpenScriptsFolder:) keyEquivalent:@""];
		[scriptsMenu addItem:menuItem];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"More Scripts…", nil) action:@selector(openScriptsPage:) keyEquivalent:@""];
		[scriptsMenu addItem:menuItem];
		
		// If this is the first call to initScriptsMenu, create the scripts menu. Otherwise we just
		// update the one we have.
		if (scriptsMenuItem != nil) {
			[NSApp.mainMenu removeItem:scriptsMenuItem];
		}

        scriptsMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
        if (@available(macOS 11, *)) {
            scriptsMenuItem.image = [NSImage imageWithSystemSymbolName:@"applescript.fill"
                                              accessibilityDescription:nil];
        } else {
            // This image is available in AppKit, but not as a constant.
            scriptsMenuItem.image = [NSImage imageNamed:@"NSScriptTemplate"];
        }

		NSInteger helpMenuIndex = NSApp.mainMenu.numberOfItems - 1;
		[NSApp.mainMenu insertItem:scriptsMenuItem atIndex:helpMenuIndex];
		scriptsMenuItem.submenu = scriptsMenu;
    } else {
        // Remove the menu item if the are no scripts anymore.
        if (scriptsMenuItem) {
            [NSApp.mainMenu removeItem:scriptsMenuItem];
            scriptsMenuItem = nil;
        }
    }
}

- (void)populateStyleMenu {
    NSMenu *menu = ((ViennaApp *)NSApp).styleMenu;

    // Remove any existing menu items.
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action == @selector(doSelectStyle:)) {
            [menu removeItem:item];
        }
    }

	// Reinitialise the styles map.
	NSArray *styles = [ArticleStyleLoader reloadStylesMap].allKeys;
    styles = [styles sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    // Create new menu items.
	for (NSInteger index = 0; index < styles.count; ++index) {
		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:styles[index]
                                                          action:@selector(doSelectStyle:)
                                                   keyEquivalent:@""];
		[menu insertItem:menuItem atIndex:index];
	}
}

/* updateNewArticlesNotification
 * Respond to a change in how we notify when new articles are retrieved.
 */
-(void)updateNewArticlesNotification
{
	lastCountOfUnread = -1;	// Force an update
	[self showUnreadCountOnApplicationIconAndWindowTitle];
}

- (void)handleUpdateUnreadCount:(NSNotification *)nc
{
	[self showUnreadCountOnApplicationIconAndWindowTitle];
}

/* showUnreadCountOnApplicationIconAndWindowTitle
 * Update the Vienna application icon to show the number of unread articles.
 */
- (void)showUnreadCountOnApplicationIconAndWindowTitle {
    @synchronized(NSApp.dockTile) {
        NSInteger currentCountOfUnread = db.countOfUnread;
        if (currentCountOfUnread == lastCountOfUnread) {
            return;
        }
        lastCountOfUnread = currentCountOfUnread;

        // Always update the app status icon first
        [self setAppStatusBarIcon];

        // Don't show a count if there are no unread articles
        if (currentCountOfUnread <= 0) {
            NSApp.dockTile.badgeLabel = nil;
            self.mainWindowController.unreadCount = 0;
        } else {
            NSString *countdown = [NSString stringWithFormat:@"%li", (long)currentCountOfUnread];
            NSApp.dockTile.badgeLabel = countdown;
            self.mainWindowController.unreadCount = currentCountOfUnread;
        }
    }
}

/* emptyTrash
 * Delete all articles from the Trash folder.
 */
-(IBAction)emptyTrash:(id)sender
{
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Are you sure you want to delete the messages in the Trash folder permanently?", nil);
    alert.informativeText = NSLocalizedString(@"You cannot undo this action", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"Empty", @"Title of a button on an alert")];
    [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"cancel.button",
                                                                nil,
                                                                NSBundle.mainBundle,
                                                                @"Cancel",
                                                                @"Title of a button on an alert")];
    [alert beginSheetModalForWindow:self.mainWindow completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self clearUndoStack];
            [self->db purgeDeletedArticles];
        }
    }];
}

/* keyboardShortcutsHelp
 * Display the Keyboard Shortcuts help page.
 */
-(IBAction)keyboardShortcutsHelp:(id)sender
{
    NSString *helpBook = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"];
    [[NSHelpManager sharedHelpManager] openHelpAnchor:@"KeyboardSection" inBook:helpBook];
}

/* printDocument
 * Print the selected articles in the article window.
 */
-(IBAction)printDocument:(id)sender
{
    id<Tab> activeBrowserTab = self.browser.activeTab;

    if (activeBrowserTab) {
        [activeBrowserTab printDocument:sender];
    }
}

/* folders
 * Return the array of folders.
 */
-(NSArray *)folders
{
	return [db arrayOfAllFolders];
}

/* selectedArticle
 * Returns the current selected article in the article pane.
 */
-(Article *)selectedArticle
{
	return self.articleController.selectedArticle;
}

/* currentFolderId
 * Return the ID of the currently selected folder whose articles are shown in
 * the article window.
 */
-(NSInteger)currentFolderId
{
	return self.articleController.currentFolderId;
}

-(NSString *)currentTextSelection
{
    id<Tab> activeBrowserTab = self.browser.activeTab;
    if (activeBrowserTab) {
        return activeBrowserTab.textSelection;
    } else {
        id target = [NSApp targetForAction:@selector(textSelection)];
        if (target) {
            return [target textSelection];
        }
    }
    return @"";
}

/* selectFolder
 * Select the specified folder.
 */
-(void)selectFolder:(NSInteger)folderId
{
	[self.foldersTree selectFolder:folderId];
}

/* updateCloseCommands
 * Update the keystrokes assigned to the Close Tab and Close Window
 * commands depending on whether any tabs are opened.
 */
-(void)updateCloseCommands
{
	if (self.browser.browserTabCount <= 1 || !self.mainWindow.keyWindow) {
		closeTabItem.keyEquivalent = @"";
		closeAllTabsItem.keyEquivalent = @"";
		closeWindowItem.keyEquivalent = @"w";
        closeWindowItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
	} else {
		closeTabItem.keyEquivalent = @"w";
        closeTabItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
		closeAllTabsItem.keyEquivalent = @"w";
        closeAllTabsItem.keyEquivalentModifierMask = NSEventModifierFlagCommand|NSEventModifierFlagOption;
		closeWindowItem.keyEquivalent = @"W";
        closeWindowItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
	}
}

/* showAppInStatusBar
 * Add or remove the app icon from the system status bar.
 */
-(void)showAppInStatusBar
{
	Preferences * prefs = [Preferences standardPreferences];
	if (prefs.showAppInStatusBar && appStatusItem == nil) {
		appStatusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
        [self setAppStatusBarIcon];
		
        NSMenu * statusBarMenu = [NSMenu new];
        [statusBarMenu addItemWithTitle:NSLocalizedString(@"Show Main Window…", @"Title of a menu item")
                                 action:@selector(openVienna:)
                          keyEquivalent:@""];
        [statusBarMenu addItem:[NSMenuItem separatorItem]];
		[statusBarMenu addItemWithTitle:NSLocalizedString(@"Refresh All Subscriptions", @"Title of a menu item")
								 action:@selector(refreshAllSubscriptions:)
						  keyEquivalent:@""];
		[statusBarMenu addItemWithTitle:NSLocalizedString(@"Mark All Subscriptions as Read", @"Title of a menu item")
								 action:@selector(markAllSubscriptionsRead:)
						  keyEquivalent:@""];
        [statusBarMenu addItem:[NSMenuItem separatorItem]];
        [statusBarMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"quitVienna.menuItem",
                                                                          nil,
                                                                          NSBundle.mainBundle,
                                                                          @"Quit Vienna",
                                                                          @"Title of a menu item")
                                 action:@selector(terminate:)
                          keyEquivalent:@""];
		appStatusItem.menu = statusBarMenu;
	} else if (!prefs.showAppInStatusBar && appStatusItem != nil) {
		[NSStatusBar.systemStatusBar removeStatusItem:appStatusItem];
		appStatusItem = nil;
	}
}

/* setAppStatusBarIcon
 * Set the appropriate application status bar icon depending on whether or not we have
 * any unread messages.
 */
-(void)setAppStatusBarIcon
{
	if (appStatusItem != nil) {
		if (lastCountOfUnread == 0) {
            NSImage *statusBarImage = [NSImage imageNamed:ACImageNameStatusBarIcon];
            statusBarImage.template = YES;
            appStatusItem.button.image = statusBarImage;
            appStatusItem.button.title = @"";
            appStatusItem.button.imagePosition = NSImageOnly;
		} else {
            NSImage *statusBarImage = [NSImage imageNamed:ACImageNameStatusBarIconUnread];
            statusBarImage.template = YES;
            appStatusItem.button.image = statusBarImage;
			appStatusItem.button.title = [NSString stringWithFormat:@"%ld", (long)lastCountOfUnread];
            appStatusItem.button.imagePosition = NSImageLeading;
		}
	}
}

/* handleRSSLink
 * Handle feed://<rss> links. If we're already subscribed to the link then make the folder
 * active. Otherwise offer to subscribe to the link.
 */
-(void)handleRSSLink:(NSString *)linkPath
{
    [self createSubscriptionInCurrentLocationForUrl:[NSURL URLWithString:linkPath]];
}

/* handleEditFolder
 * Respond to an edit folder notification.
 */
-(void)handleEditFolder:(NSNotification *)nc
{
	TreeNode * node = (TreeNode *)nc.object;
	Folder * folder = [db folderFromID:node.nodeId];
	[self doEditFolder:folder];
}

/* editFolder
 * Handles the Edit command
 */
-(IBAction)editFolder:(id)sender
{
	Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
	[self doEditFolder:folder];
}

/* doEditFolder
 * Handles an edit action on the specified folder.
 */
-(void)doEditFolder:(Folder *)folder
{
	if (folder.type == VNAFolderTypeRSS) {
		[self.rssFeed editSubscription:self.mainWindow folderId:folder.itemId];
	} else if (folder.type == VNAFolderTypeSmart) {
        if (!smartFolder) {
			smartFolder = [[SmartFolder alloc] initWithDatabase:db];
        }
		[smartFolder loadCriteria:self.mainWindow folderId:folder.itemId];
	}
}

/* handleFolderSelection
 * Called when the selection changes in the folder pane.
 */
-(void)handleFolderSelection:(NSNotification *)nc
{
    TreeNode *treeNode = nc.object;
	
	// Call through the controller to display the new folder.
	[self.articleController displayFolder:treeNode.nodeId];
	[self updateSearchPlaceholderAndSearchMethod];
	
	// Make sure article viewer is active
	// and an adequate responder exists
	[self.browser switchToPrimaryTab];
	if ([self.mainWindow.firstResponder isEqualTo:self.mainWindow]) {
		[self.mainWindow makeFirstResponder:self.foldersTree.mainView];
	}

    // If the user selects the unread-articles smart folder, then clear the
    // relevant user notifications.
    if (treeNode.folder.type == VNAFolderTypeSmart) {
        Criteria *unreadCriteria =
            [[Criteria alloc] initWithField:MA_Field_Read
                               operatorType:VNACriteriaOperatorEqualTo
                                      value:@"No"];
        NSString *predicateFormat = unreadCriteria.predicate.predicateFormat;
        Folder *smartFolder = [db folderForPredicateFormat:predicateFormat];
        if ([smartFolder isEqual:treeNode.folder]) {
            VNAUserNotificationCenter *center = VNAUserNotificationCenter.current;
            [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<VNAUserNotificationResponse *> *responses) {
                NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
                for (VNAUserNotificationResponse *response in responses) {
                    if ([response.userInfo[UserNotificationContextKey] isEqualToString:UserNotificationContextFetchCompleted]) {
                        [identifiers addObject:response.identifier];
                    }
                }
                [center removeDeliveredNotificationsWithIdentifiers:identifiers];
            }];
        }
    }
}

/* handleDidBecomeKeyWindow
 * Called when a window becomes the key window.
 */
-(void)handleDidBecomeKeyWindow:(NSNotification *)nc
{
	[self updateCloseCommands];
}

/* handleReloadPreferences
 * Called when MA_Notify_PreferencesUpdated is broadcast.
 * Update the menus.
 */
-(void)handleReloadPreferences:(NSNotification *)nc
{
	[self updateAlternateMenuTitle];
	[self.foldersTree updateAlternateMenuTitle];
	[self.articleController.mainArticleView updateAlternateMenuTitle];
	[self updateNewArticlesNotification];
}

/* handleShowAppInStatusBar
 * Called when MA_Notify_ShowAppInStatusBarChanged is broadcast. Call the common code to
 * add or remove the app icon from the status bar.
 */
-(void)handleShowAppInStatusBar:(NSNotification *)nc
{
	[self showAppInStatusBar];
}

- (void)handleCheckFrequencyChange:(NSNotification *)notification
{
    NSInteger frequency = Preferences.standardPreferences.refreshFrequency;
    if (frequency >= 300) {
        [self scheduleRefreshWithFrequency:frequency refreshImmediately:NO];
    } else {
        // The user disabled the automatic refresh.
        self.refreshTimer = nil;
    }
}

/* doViewColumn
 * Toggle whether or not a specified column is visible.
 */
-(IBAction)doViewColumn:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	Field * field = menuItem.representedObject;
	
	field.visible = !field.visible;
	[self.articleController updateVisibleColumns];
	[self.articleController saveTableSettings];
}

/* doSortColumn
 * Handle the user picking a sort column item from the Sort By submenu
 */
-(IBAction)doSortColumn:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	Field * field = menuItem.representedObject;
	
	NSAssert1(field, @"Somehow got a nil representedObject for Sort column sub-menu item '%@'", [menuItem title]);
	[self.articleController sortByIdentifier:field.name];
}

/* doSortDirection
 * Handle the user picking ascending or descending from the Sort By submenu
 */
-(IBAction)doSortDirection:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	NSNumber * ascendingNumber = menuItem.representedObject;
	
	NSAssert1(ascendingNumber != nil, @"Somehow got a nil representedObject for Sort direction sub-menu item '%@'", [menuItem title]);
	BOOL ascending = ascendingNumber.boolValue;
	[self.articleController sortAscending:ascending];
}

/* doOpenScriptsFolder
 * Open the standard Vienna scripts folder.
 */
-(IBAction)doOpenScriptsFolder:(id)sender
{
	NSFileManager *fileManager = NSFileManager.defaultManager;
	NSURL *scriptsURL = fileManager.vna_applicationScriptsDirectory;
	[NSWorkspace.sharedWorkspace openURL:scriptsURL];
}

/* doSelectScript
 * Run a script selected from the Script menu.
 */
-(IBAction)doSelectScript:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	NSString * scriptPath = [scriptPathMappings valueForKey:menuItem.title];
	if (scriptPath != nil) {
		[self runAppleScript:scriptPath];
	}
}

/* doSelectStyle
 * Handle a selection from the Style menu.
 */
-(IBAction)doSelectStyle:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	[Preferences standardPreferences].displayStyle = menuItem.title;
}

/* handleTabChange
 * Handle a change in the active tab field.
 */
-(void)handleTabChange:(NSNotification *)nc
{
	id<Tab> activeBrowserTab = self.browser.activeTab;
	if (activeBrowserTab == nil) {
		//we are in the article view
		if (self.selectedArticle == nil) {
			[self.mainWindow makeFirstResponder:self.foldersTree.mainView];
		} else {
			[self.mainWindow makeFirstResponder:((NSView<BaseView> *)self.browser.primaryTab.view).mainView];
		}
	} else {
		[activeBrowserTab activateWebView];
	}
	[self updateSearchPlaceholderAndSearchMethod];
}

/* handleTabCountChange
 * Handle a change in the number of tabs.
 */
- (void)handleTabCountChange:(NSNotification *)nc
{
	[self updateCloseCommands];	
}

/* handleRefreshStatusChange
 * Handle a change of the refresh status.
 */
-(void)handleRefreshStatusChange:(NSNotification *)nc
{
	if (self.connecting) {
		// Toggle the refresh button
		NSToolbarItem *item = [self toolbarItemWithIdentifier:@"Refresh"];
		item.action = @selector(cancelAllRefreshesToolbar:);
        item.image = [NSImage imageNamed:ACImageNameCancelTemplate];
	} else {
		// Run the auto-expire now
		Preferences * prefs = [Preferences standardPreferences];
		[db purgeArticlesOlderThanTag:prefs.autoExpireDuration];

		// Toggle the refresh button
		NSToolbarItem *item = [self toolbarItemWithIdentifier:@"Refresh"];
		item.action = @selector(refreshAllSubscriptions:);
        item.image = [NSImage imageNamed:ACImageNameSyncTemplate];

		[self showUnreadCountOnApplicationIconAndWindowTitle];
		
		// Bounce the dock icon for 1 second if the bounce method has been selected.
		NSInteger newUnread = [RefreshManager sharedManager].countOfNewArticles + [OpenReader sharedManager].countOfNewArticles;
		if (newUnread > 0 && ((prefs.newArticlesNotification & VNANewArticlesNotificationBounce) != 0)) {
			[NSApp requestUserAttention:NSInformationalRequest];
		}

        // User notification
        if (newUnread > 0) {
            VNAUserNotificationCenter *center = VNAUserNotificationCenter.current;
            [center getNotificationSettingsWithCompletionHandler:^(VNAUserNotificationSettings *settings) {
                VNAUserNotificationAuthorizationStatus status = settings.authorizationStatus;
                if (status == VNAUserNotificationAuthorizationStatusDenied) {
                    return;
                }

                void (^deliverNotification)(void) = ^{
                    NSString *identifier = UserNotificationContextFetchCompleted;
                    NSString *title = NSLocalizedString(@"New articles retrieved",
                                                        @"Notification title");
                    NSString *body = [NSString stringWithFormat:NSLocalizedString(@"%d new unread articles retrieved",
                                                                                  @"Notification body"),
                                      (int)newUnread];
                    VNAUserNotificationRequest *request =
                        [[VNAUserNotificationRequest alloc] initWithIdentifier:identifier
                                                                         title:title];
                    request.body = body;
                    request.playSound = settings.isSoundEnabled;
                    request.userInfo = @{
                        UserNotificationContextKey: UserNotificationContextFetchCompleted
                    };
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
	}
}

- (IBAction)openStylesPage:(id)sender
{
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *urlString = [bundle objectForInfoDictionaryKey:@"VNAStylesPage"];
    [self openURLInDefaultBrowser:[NSURL URLWithString:urlString]];
}

- (IBAction)openScriptsPage:(id)sender
{
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *urlString = [bundle objectForInfoDictionaryKey:@"VNAScriptsPage"];
    [self openURLInDefaultBrowser:[NSURL URLWithString:urlString]];
}

/* viewArticlePages inPreferredBrowser
 * Display the selected articles in a browser.
 */
-(void)viewArticlePages:(id)sender inPreferredBrowser:(BOOL)usePreferredBrowser
{
	NSArray * articleArray = self.articleController.markedArticleRange;
	Article * currentArticle;
	
	if (articleArray.count > 0) {
		
        NSMutableArray * articlesWithLinks = [NSMutableArray arrayWithCapacity:articleArray.count];
        NSMutableArray * urls = [NSMutableArray arrayWithCapacity:articleArray.count];
		
		for (currentArticle in articleArray) {
			if (currentArticle && !currentArticle.link.vna_isBlank) {
                [articlesWithLinks addObject:currentArticle];
                NSURL * theURL = [NSURL URLWithString:currentArticle.link];
                if (theURL == nil) {
					theURL = cleanedUpUrlFromString(currentArticle.link);
                }
                [urls addObject:theURL];
            }
		}
		[self openURLs:urls inPreferredBrowser:usePreferredBrowser];

        if (([Preferences standardPreferences].markReadInterval > 0.0f) && !db.readOnly) {
            [self.articleController markReadByArray:articlesWithLinks readFlag:YES];
        }
	}
}

/* viewArticlePages
 * Display the selected articles in the default browser.
 */
-(IBAction)viewArticlePages:(id)sender
{
	[self viewArticlePages:sender inPreferredBrowser:YES];
}

/* viewArticlePagesInAlternateBrowser
 * Display the selected articles in the alternate browser.
 */
-(IBAction)viewArticlePagesInAlternateBrowser:(id)sender
{
	[self viewArticlePages:sender inPreferredBrowser:NO];
}


/* goForward
 * In article view, forward track through the list of articles displayed.
 */
-(IBAction)goForward:(id)sender
{
    [self.browser switchToPrimaryTab];
    [self.articleController goForward];
}

/* goBack
 * In article view, back track through the list of articles displayed.
 */
-(IBAction)goBack:(id)sender
{
    [self.browser switchToPrimaryTab];
    [self.articleController goBack];
}

/* localPerformFindPanelAction
 * The default handler for the Find actions is the first responder. Unfortunately the
 * WebView, although it claims to implement this, doesn't. So we redirect the Find
 * commands here and trap the case where the webview has first responder status and
 * handle it especially. For other first responders, we pass this command through.
 */
-(IBAction)localPerformFindPanelAction:(id)sender
{
    NSInteger action = [sender tag];
	switch (action) {
		case NSFindPanelActionSetFindString:
			self.searchString = self.currentTextSelection;
			break;
			
		case NSFindPanelActionShowFindPanel:
			[self setFocusToSearchField:self];
			break;
			
		default:
            [self.browser.activeTab searchFor:self.toolbarSearchField.stringValue
                                       action:action];
			break;
	}
}

#pragma mark Key Listener

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(NSEvent *)event
{
    if (event.type != NSEventTypeKeyDown && event.characters.length != 1) {
        return NO;
    }
    unichar keyChar = [event.characters characterAtIndex:0];
    NSEventModifierFlags flags = event.modifierFlags;
	switch (keyChar) {
		case NSLeftArrowFunctionKey:
            if (flags & (NSEventModifierFlagCommand | NSEventModifierFlagOption)) {
				return NO;
			} else {
				if (self.mainWindow.firstResponder == ((NSView<BaseView> *)self.browser.primaryTab.view).mainView) {
					[self.mainWindow makeFirstResponder:self.foldersTree.mainView];
					return YES;
				}
			}
			return NO;
			
		case NSRightArrowFunctionKey:
            if (flags & (NSEventModifierFlagCommand | NSEventModifierFlagOption)) {
				return NO;
			} else {
				if (self.mainWindow.firstResponder == self.foldersTree.mainView) {
					[self.browser switchToPrimaryTab];
					if (self.selectedArticle == nil) {
						[self.articleController ensureSelectedArticle];
					}
					[self.mainWindow makeFirstResponder:(self.selectedArticle != nil) ? ((NSView<BaseView> *)self.browser.primaryTab.view).mainView : self.foldersTree.mainView];
					return YES;
				}
			}
			return NO;
			
		case NSDeleteFunctionKey:
		case NSDeleteCharacter:
			if (self.mainWindow.firstResponder == self.foldersTree.mainView) {
				[self deleteFolder:self];
				return YES;
			} else if (self.browser.activeTab == nil) { // make sure we are in the articles tab
				[self deleteMessage:self];
				return YES;
			}
			return NO;
			
		case 'h':
		case 'H':
			[self setFocusToSearchField:self];
			return YES;
			
		case '>':
		case '.':
			[self goForward:self];
			return YES;
			
		case '<':
		case ',':
			[self goBack:self];
			return YES;
			
		case 'k':
		case 'K':
			[self markAllRead:self];
			return YES;
			
		case 'm':
		case 'M':
			[self markFlagged:self];
			return YES;
			
		case 'b':
		case 'B':
			[self viewFirstUnread:self];
			return YES;

		case 'n':
		case 'N':
			[self viewNextUnread:self];
			return YES;

		case 'y':
		case 'Y':
			[self viewArticlesTab:self];
			return YES;
			
		case 'u':
		case 'U':
		case 'r':
		case 'R':
			[self markReadToggle:self];
			return YES;
			
		case 's':
		case 'S':
			[self skipFolder:self];
			return YES;
			
		case NSEnterCharacter:
		case NSCarriageReturnCharacter:
			if (self.mainWindow.firstResponder == self.foldersTree.mainView) {
                if (flags & NSEventModifierFlagOption) {
					[self viewSourceHomePageInAlternateBrowser:self];
				} else {
					[self viewSourceHomePage:self];
				}
				return YES;
			} else {
                if (flags & NSEventModifierFlagOption) {
					[self viewArticlePagesInAlternateBrowser:self];
				} else {
					[self viewArticlePages:self];
				}
				return YES;
			}
			return NO;
			
		case ' ': //SPACE
		{
            id<Tab> activeBrowserTab = self.browser.activeTab;
			
            if (activeBrowserTab == nil) {
                //we are in the article view
                [self.mainWindow makeFirstResponder:((NSView<BaseView> *)self.browser.primaryTab.view).mainView];
                if (flags & NSEventModifierFlagShift) {
                    [self.articleController.mainArticleView scrollUpDetailsOrGoBack];
				} else {
                    [self.articleController.mainArticleView scrollDownDetailsOrNextUnread];
				}
				return YES;
			}
		}
	}
	return NO;
}

/* toolbarItemWithIdentifier
 * Returns the toolbar button that corresponds to the specified identifier.
 */
-(NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)theIdentifier
{
	for (NSToolbarItem * theItem in self.mainWindow.toolbar.visibleItems) {
		if ([theItem.itemIdentifier isEqualToString:theIdentifier]) {
			return theItem;
		}
	}
	return nil;
}

/* isConnecting
 * Returns whether or not 
 */
-(BOOL)isConnecting
{
	return [RefreshManager sharedManager].connecting;
}

/* markSelectedFoldersRead
 * Mark read all articles in the specified array of folders.
 */
-(void)markSelectedFoldersRead:(NSArray *)arrayOfFolders
{
    if (!db.readOnly) {
        [self.articleController markAllFoldersReadByArray:arrayOfFolders];
    }
}

-(void)createSubscriptionInCurrentLocationForUrl:(NSURL *)url {
    NSInteger currentFolderId = self.foldersTree.actualSelection;
    NSInteger parentFolderId = self.foldersTree.groupParentSelection;
    Folder * currentFolder = [db folderFromID:currentFolderId];
    if (parentFolderId == VNAFolderTypeRoot && currentFolder.type != VNAFolderTypeRSS && currentFolder.type != VNAFolderTypeOpenReader) {
        currentFolderId = -1;
    }
    SubscriptionModel *subscription = [[SubscriptionModel alloc] init];
    NSString * verifiedURLString = [subscription verifiedFeedURLFromURL:url].absoluteString;
    [self createNewSubscription:verifiedURLString underFolder:parentFolderId afterChild:currentFolderId];
}

/* createNewSubscription
 * Create a new subscription for the specified URL under the given parent folder.
 */
-(void)createNewSubscription:(NSString *)urlString underFolder:(NSInteger)parentId afterChild:(NSInteger)predecessorId
{
	// Replace feed:// with http:// if necessary
	if ([urlString hasPrefix:@"feed://"]) {
		urlString = [NSString stringWithFormat:@"http://%@", [urlString substringFromIndex:7]];
	}

	urlString = cleanedUpUrlFromString(urlString).absoluteString;
	
	// If the folder already exists, just select it.
	Folder * folder = [db folderFromFeedURL:urlString];
	if (folder != nil) {
		[self.browser switchToPrimaryTab];
		[self.foldersTree selectFolder:folder.itemId];
		return;
	}
	
	// Create the new folder.
	if ([Preferences standardPreferences].syncGoogleReader && [Preferences standardPreferences].prefersGoogleNewSubscription) {	//creates in OpenReader
		NSString * folderName = [db folderFromID:parentId].name;
		[[OpenReader sharedManager] subscribeToFeed:urlString withLabel:folderName];
	} else { //creates locally
		NSInteger folderId = [db addRSSFolder:[Database untitledFeedFolderName]
                                  underParent:parentId
                                   afterChild:predecessorId
                              subscriptionURL:urlString];

		if (folderId != -1) {
            if (isAccessible(urlString) || [urlString hasPrefix:@"file"]) {
                Folder * folder = [db folderFromID:folderId];
                [[RefreshManager sharedManager] refreshSubscriptions:@[folder] ignoringSubscriptionStatus:NO];
            }
		}
	}
}

/* newSubscription
 * Display the pane for a new RSS subscription.
 */
-(IBAction)newSubscription:(id)sender
{
	[self.rssFeed newSubscription:self.mainWindow initialURL:nil];
}

/* newSmartFolder
 * Create a new smart folder.
 */
-(IBAction)newSmartFolder:(id)sender
{
	if (!smartFolder) {
		smartFolder = [[SmartFolder alloc] initWithDatabase:db];
	}
	[smartFolder newCriteria:self.mainWindow underParent:self.foldersTree.groupParentSelection];
}

/* newGroupFolder
 * Display the pane for a new group folder.
 */
-(IBAction)newGroupFolder:(id)sender
{
	if (!groupFolder) {
		groupFolder = [[NewGroupFolder alloc] init];
	}
	[groupFolder newGroupFolder:self.mainWindow underParent:self.foldersTree.groupParentSelection];
}

/* restoreMessage
 * Restore a message in the Trash folder back to where it came from.
 */
-(IBAction)restoreMessage:(id)sender
{
	Folder * folder = [db folderFromID:self.articleController.currentFolderId];
	if (folder.type == VNAFolderTypeTrash && self.selectedArticle != nil && !db.readOnly) {
		NSArray * articleArray = self.articleController.markedArticleRange;
		[self.articleController markDeletedByArray:articleArray deleteFlag:NO];
		[self clearUndoStack];
	}
}

/* deleteMessage
 * Delete the current article. If we're in the Trash folder, this represents a permanent
 * delete. Otherwise we just move the article to the trash folder.
 */
-(IBAction)deleteMessage:(id)sender
{
	if (self.selectedArticle != nil && !db.readOnly) {
		Folder * folder = [db folderFromID:self.articleController.currentFolderId];
		if (folder.type != VNAFolderTypeTrash) {
			NSArray * articleArray = self.articleController.markedArticleRange;
			[self.articleController markDeletedByArray:articleArray deleteFlag:YES];
		} else {
            NSAlert *alert = [NSAlert new];
            alert.messageText = NSLocalizedString(@"Are you sure you want to permanently delete the selected articles?", nil);
            alert.informativeText = NSLocalizedString(@"This operation cannot be undone.", nil);
            [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"delete.button",
                                                                        nil,
                                                                        NSBundle.mainBundle,
                                                                        @"Delete",
                                                                        @"Title of a button on an alert")];
            [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"cancel.button",
                                                                        nil,
                                                                        NSBundle.mainBundle,
                                                                        @"Cancel",
                                                                        @"Title of a button on an alert")];
            [alert beginSheetModalForWindow:self.mainWindow completionHandler:^(NSModalResponse returnCode) {
                if (returnCode == NSAlertFirstButtonReturn) {
                    NSArray *articleArray = self.articleController.markedArticleRange;
                    [self.articleController deleteArticlesByArray:articleArray];

                    // Blow away the undo stack here since undo actions may refer to
                    // articles that have been deleted. This is a bit of a cop-out but
                    // it's the easiest approach for now.
                    [self clearUndoStack];
                }
            }];
		}
	}
}

/* viewFirstUnread
 * Moves the selection to the first unread article.
 */
-(IBAction)viewFirstUnread:(id)sender
{
	[self.browser switchToPrimaryTab];
	if (db.countOfUnread > 0) {
		[self.mainWindow makeFirstResponder:((NSView<BaseView> *)self.browser.primaryTab.view).mainView];
		[self.articleController displayFirstUnread];
	} else {
		[self.mainWindow makeFirstResponder:(self.selectedArticle != nil) ? ((NSView<BaseView> *)self.browser.primaryTab.view).mainView : self.foldersTree.mainView];
	}
}

/* viewNextUnread
 * Moves the selection to the next unread article.
 */
-(IBAction)viewNextUnread:(id)sender
{
	[self.browser switchToPrimaryTab];
	if (db.countOfUnread > 0) {
		[self.mainWindow makeFirstResponder:((NSView<BaseView> *)self.browser.primaryTab.view).mainView];
		[self.articleController displayNextUnread];
	} else {
		[self.mainWindow makeFirstResponder:(self.selectedArticle != nil) ? ((NSView<BaseView> *)self.browser.primaryTab.view).mainView : self.foldersTree.mainView];
	}
}

/* clearUndoStack
 * Clear the undo stack for instances when the last action invalidates
 * all previous undoable actions.
 */
-(void)clearUndoStack
{
	[self.mainWindow.undoManager removeAllActions];
}

/* skipFolder
 * Mark all articles in the current folder read then skip to the next folder with
 * unread articles.
 */
-(IBAction)skipFolder:(id)sender
{
	if (!db.readOnly) {
		[self.articleController markAllFoldersReadByArray:self.foldersTree.selectedFolders];
		if (db.countOfUnread > 0) {
			[self.articleController displayNextFolderWithUnread];
		}
	}
}

#pragma mark Marking Articles 

/* markAllRead
 * Mark all articles read in the selected folders.
 */
-(IBAction)markAllRead:(id)sender
{
    if (!db.readOnly) {
        [self.articleController markAllFoldersReadByArray:self.foldersTree.selectedFolders];
    }
}

/* markAllSubscriptionsRead
 * Mark all subscriptions as read
 */
-(IBAction)markAllSubscriptionsRead:(id)sender
{
	if (!db.readOnly) {
		[self.articleController markAllFoldersReadByArray:[self.foldersTree folders:0]];
	}
}

/* markReadToggle
 * Toggle the read/unread state of the selected articles
 */
-(IBAction)markReadToggle:(id)sender
{
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !db.readOnly) {
		NSArray * articleArray = self.articleController.markedArticleRange;
		[self.articleController markReadByArray:articleArray readFlag:!theArticle.isRead];
	}
}

/* markRead
 * Mark read the selected articles
 */
-(IBAction)markRead:(id)sender
{
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !db.readOnly) {
		NSArray * articleArray = self.articleController.markedArticleRange;
		[self.articleController markReadByArray:articleArray readFlag:YES];
	}
}

/* markUnread
 * Mark unread the selected articles
 */
-(IBAction)markUnread:(id)sender
{
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !db.readOnly) {
		NSArray * articleArray = self.articleController.markedArticleRange;
		[self.articleController markReadByArray:articleArray readFlag:NO];
	}
}

/* markFlagged
 * Toggle the flagged/unflagged state of the selected article
 */
-(IBAction)markFlagged:(id)sender
{
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !db.readOnly) {
		NSArray * articleArray = self.articleController.markedArticleRange;
		[self.articleController markFlaggedByArray:articleArray flagged:!theArticle.isFlagged];
	}
}

/* renameFolder
 * Renames the current folder
 */
-(IBAction)renameFolder:(id)sender
{
	[self.foldersTree renameFolder:self.foldersTree.actualSelection];
}

/* deleteFolder
 * Delete the current folder.
 */
-(IBAction)deleteFolder:(id)sender
{
	NSMutableArray * selectedFolders = [NSMutableArray arrayWithArray:self.foldersTree.selectedFolders];
	NSUInteger count = selectedFolders.count;
	NSUInteger index;
	
	// Show a different prompt depending on whether we're deleting one folder or a
	// collection of them.
	NSString * alertBody = nil;
	NSString * alertTitle = nil;
	BOOL needPrompt = YES;
	
	if (count == 1) {
		Folder * folder = selectedFolders[0];
		if (folder.type == VNAFolderTypeSmart) {
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete smart folder \"%@\"? This will not delete the actual articles matched by the search.", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete smart folder", nil);
		} else if (folder.type == VNAFolderTypeSearch) {
			needPrompt = NO;
		} else if (folder.type == VNAFolderTypeRSS) {
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to unsubscribe from \"%@\"? This operation will delete all cached articles.", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete subscription", nil);
		} else if (folder.type == VNAFolderTypeOpenReader) {
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Unsubscribing from an Open Reader RSS feed will also remove your locally cached articles.", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete Open Reader RSS feed", nil);
		} else if (folder.type == VNAFolderTypeGroup) {
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete group folder \"%@\" and all sub folders? This operation cannot be undone.", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete group folder", nil);
		} else if (folder.type == VNAFolderTypeTrash) {
			return;
		} else {
			NSAssert1(false, @"Unhandled folder type in deleteFolder: %@", [folder name]);
		}
	} else {
		alertBody = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete all %d selected folders? This operation cannot be undone.", nil), (unsigned int)count];
		alertTitle = NSLocalizedString(@"Delete multiple folders", nil);
	}
	
	// Get confirmation first
	if (needPrompt) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = alertTitle;
        alert.informativeText = alertBody;
        [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"delete.button",
                                                                    nil,
                                                                    NSBundle.mainBundle,
                                                                    @"Delete",
                                                                    @"Title of a button on an alert")];
        [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"cancel.button",
                                                                    nil,
                                                                    NSBundle.mainBundle,
                                                                    @"Cancel",
                                                                    @"Title of a button on an alert")];
        NSModalResponse alertResponse = [alert runModal];

		if (alertResponse == NSAlertSecondButtonReturn) {
			return;
		}
	}
	

	if (smartFolder != nil) {
		[smartFolder doCancel:nil];
	}
	if ([(NSControl *)self.foldersTree.mainView abortEditing]) {
		[self.mainWindow makeFirstResponder:self.foldersTree.mainView];
	}
	
	
	// Clear undo stack for this action
	[self clearUndoStack];
	
	// Prompt for each folder for now
	for (index = 0; index < count; ++index) {
		Folder * folder = selectedFolders[index];
		
		// This little hack is so if we're deleting the folder currently being displayed
		// and there's more than one folder being deleted, we delete the folder currently
		// being displayed last so that the MA_Notify_FolderDeleted handlers that only
		// refresh the display if the current folder is being deleted only trips once.
		if (folder.itemId == self.articleController.currentFolderId && index < count - 1) {
			[selectedFolders insertObject:folder atIndex:count];
			++count;
			continue;
		}
		if (folder.type != VNAFolderTypeTrash) {
			// Create a status string
            NSString * deleteStatusMsg = [NSString stringWithFormat:NSLocalizedString(@"Deleting folder \"%@\"…", nil), folder.name];
            // TODO: Use KVO
            self.mainWindowController.statusText = deleteStatusMsg;

			// Now call the database to delete the folder.
			[db deleteFolder:folder.itemId];
            
			if (folder.type == VNAFolderTypeOpenReader) {
				NSLog(@"Unsubscribe Open Reader folder");
				[[OpenReader sharedManager] unsubscribeFromFeedIdentifier:folder.remoteId];
			}
		}
	}
	
	// Unread count may have changed
    self.mainWindowController.statusText = nil;
	[self showUnreadCountOnApplicationIconAndWindowTitle];
}

/* getInfo
 * Display the Info panel for the selected feeds.
 */
-(IBAction)getInfo:(id)sender
{
	NSInteger folderId = self.foldersTree.actualSelection;
    if (folderId > 0) {
        [[InfoPanelManager infoWindowManager] showInfoWindowForFolder:folderId
                                                                block:^(InfoPanelController *infoPanelController) {
                                                                    infoPanelController.delegate = self;
                                                                }];
    }
}

/* unsubscribeFeed
 * Subscribe or re-subscribe to a feed.
 */
-(IBAction)unsubscribeFeed:(id)sender
{
	NSArray * selectedFolders = [NSArray arrayWithArray:self.foldersTree.selectedFolders];
	NSInteger count = selectedFolders.count;
	NSInteger index;
	
	for (index = 0; index < count; ++index) {
		Folder * folder = selectedFolders[index];
        
        if (folder.isUnsubscribed) {
            // Currently unsubscribed, so re-subscribe locally
            [db clearFlag:VNAFolderFlagUnsubscribed forFolder:folder.itemId];
        } else {
            // Currently subscribed, so unsubscribe locally
            [db setFlag:VNAFolderFlagUnsubscribed forFolder:folder.itemId];
        }
        [NSNotificationCenter.defaultCenter postNotificationName:MA_Notify_FoldersUpdated object:@(folder.itemId)];
	}
}

/* setLoadFullHTMLFlag
 * Sets the value of the load full HTML pages flag for the current folder selection
 * and informs interested parties.
 */
-(IBAction)setLoadFullHTMLFlag:(BOOL)loadFullHTMLPages
{
	NSMutableArray * selectedFolders = [NSMutableArray arrayWithArray:self.foldersTree.selectedFolders];
	NSInteger count = selectedFolders.count;
	NSInteger index;
	
	for (index = 0; index < count; ++index) {
		Folder * folder = selectedFolders[index];
		NSInteger folderID = folder.itemId;
		
		if (loadFullHTMLPages) {
			[folder setFlag:VNAFolderFlagLoadFullHTML];
            [db setFlag:VNAFolderFlagLoadFullHTML forFolder:folderID];
		} else {
			[folder clearFlag:VNAFolderFlagLoadFullHTML];
            [db clearFlag:VNAFolderFlagLoadFullHTML forFolder:folderID];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:MA_Notify_LoadFullHTMLChange object:@(folderID)];
	}
}

/* useCurrentStyleForArticles
 * Use the current style to display articles (default).
 */
-(IBAction)useCurrentStyleForArticles:(id)sender
{
	[self setLoadFullHTMLFlag:NO];
}

/* useWebPageForArticles
 * Use the web page at the article's link location to display articles.
 */
-(IBAction)useWebPageForArticles:(id)sender
{
	[self setLoadFullHTMLFlag:YES];
}

/* viewSourceHomePage
 * Display the web site associated with this feed, if there is one.
 */
-(IBAction)viewSourceHomePage:(id)sender
{
	Article * thisArticle = self.selectedArticle;
	Folder * folder = (thisArticle) ? [db folderFromID:thisArticle.folderId] : [db folderFromID:self.foldersTree.actualSelection];
	if (thisArticle || folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) {
		[self openURLFromString:folder.homePage inPreferredBrowser:YES];
	}
}

/* viewSourceHomePageInAlternateBrowser
 * Display the web site associated with this feed, if there is one, in non-preferred browser.
 */
-(IBAction)viewSourceHomePageInAlternateBrowser:(id)sender
{
	Article * thisArticle = self.selectedArticle;
	Folder * folder = (thisArticle) ? [db folderFromID:thisArticle.folderId] : [db folderFromID:self.foldersTree.actualSelection];
	if (thisArticle || folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) {
		[self openURLFromString:folder.homePage inPreferredBrowser:NO];
	}
}

- (IBAction)openHomePage:(id)sender
{
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *urlString = [bundle objectForInfoDictionaryKey:@"VNAHomePage"];
    [self openURLInDefaultBrowser:[NSURL URLWithString:urlString]];
}

#pragma mark Tabs

/* articlesTab
 * Go straight back to the articles tab
 */
-(void)viewArticlesTab:(id)sender
{
	[self.browser switchToPrimaryTab];
}

/* previousTab
 * Display the previous tab, if there is one.
 */
-(IBAction)previousTab:(id)sender
{
	[self.browser showPreviousTab];
}

/* nextTab
 * Display the next tab, if there is one.
 */
-(IBAction)nextTab:(id)sender
{
	[self.browser showNextTab];
}

/* closeAllTabs
 * Closes all tab windows.
 */
-(IBAction)closeAllTabs:(id)sender
{
    [self.browser closeAllTabs];
}

/* closeTab
 * Close the active tab unless it's the primary view.
 */
-(IBAction)closeActiveTab:(id)sender
{
	[self.browser closeActiveTab];
}

/* reloadPage
 * Reload the web page.
 */
-(IBAction)reloadPage:(id)sender
{
    [self.browser.activeTab reloadTab];
}

/* stopReloadingPage
 * Cancel current reloading of a web page.
 */
-(IBAction)stopReloadingPage:(id)sender
{
    [self.browser.activeTab stopLoadingTab];
}

/* updateAlternateMenuTitle
 * Set the appropriate title for the menu items that override browser preferences
 * For future implementation, perhaps we can save a lot of code by
 * creating an ivar for the title string and binding the menu's title to it.
 */
-(void)updateAlternateMenuTitle
{
	Preferences * prefs = [Preferences standardPreferences];
	NSString * alternateLocation;
	if (prefs.openLinksInVienna) {
		alternateLocation = getDefaultBrowser();
		if (alternateLocation == nil) {
			alternateLocation = NSLocalizedString(@"External Browser", nil);
		}
	} else {
		alternateLocation = NSRunningApplication.currentApplication.localizedName;
	}
	NSMenuItem * item = menuItemWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	if (item != nil) {
		item.title = [NSString stringWithFormat:NSLocalizedString(@"Open Subscription Home Page in %@", nil), alternateLocation];
	}
	item = menuItemWithAction(@selector(viewArticlePagesInAlternateBrowser:));
	if (item != nil) {
		item.title = [NSString stringWithFormat:NSLocalizedString(@"Open Article Page in %@", nil), alternateLocation];
	}
}

/* updateSearchPlaceholder
 * Update the search placeholder string in the search field depending on the view in
 * the active tab.
 */
-(void)updateSearchPlaceholderAndSearchMethod
{
	id<Tab> activeBrowserTab = self.browser.activeTab;
	Preferences * prefs = [Preferences standardPreferences];
	
	// START of rather verbose implementation of switching between "Search all articles" and "Search current web page".
	if (activeBrowserTab) {
		// If the current view is a browser view and "Search all articles" is the current SearchMethod, switch to "Search current webpage"
		if ([prefs.searchMethod.displayName isEqualToString:[SearchMethod allArticlesSearchMethod].displayName]) {
			for (NSMenuItem * menuItem in ((NSSearchFieldCell *)self.toolbarSearchField.cell).searchMenuTemplate.itemArray) {
				if ([[menuItem.representedObject displayName] isEqualToString:[SearchMethod currentWebPageSearchMethod].displayName]) {
                    self.toolbarSearchField.placeholderString = [SearchMethod currentWebPageSearchMethod].displayName;
					[Preferences standardPreferences].searchMethod = menuItem.representedObject;
				}
			}
		}
	} else {
		// If the current view is anything else "Search current webpage" is active, switch to "Search all articles".
		if ([prefs.searchMethod.displayName isEqualToString:[SearchMethod currentWebPageSearchMethod].displayName]) {
			for (NSMenuItem * menuItem in ((NSSearchFieldCell *)self.toolbarSearchField.cell).searchMenuTemplate.itemArray) {
				if ([[menuItem.representedObject displayName] isEqualToString:[SearchMethod allArticlesSearchMethod].displayName]) {
                    self.toolbarSearchField.placeholderString = [SearchMethod allArticlesSearchMethod].displayName;
					[Preferences standardPreferences].searchMethod = menuItem.representedObject;
				}
			}
		} else {
            self.toolbarSearchField.placeholderString = prefs.searchMethod.displayName;
		}
	// END of switching between "Search all articles" and "Search current web page".
	}
}

#pragma mark Searching

/* setFocusToSearchField
 * Put the input focus on the search field.
 */
-(IBAction)setFocusToSearchField:(id)sender
{
	if (self.mainWindow.toolbar.visible && [self toolbarItemWithIdentifier:@"SearchItem"] && self.mainWindow.toolbar.displayMode != NSToolbarDisplayModeLabelOnly) {
		[self.mainWindow makeFirstResponder:self.toolbarSearchField];
	} else {
		if (!searchPanel) {
			searchPanel = [[SearchPanel alloc] init];
		}
		[searchPanel runSearchPanel:self.mainWindow];
	}
}

/* searchString
 * Returns the global search string currently in use for the web and article views.
 * Set by the user via the toolbar or the search panel.
 */
-(void)setSearchString:(NSString *)newSearchString
{
	searchString = [newSearchString copy];
	self.toolbarSearchField.stringValue = searchString;
}

/* searchString
 * Returns the global search string currently in use for the web and article views.
 */
-(NSString *)searchString
{
	return searchString;
}

- (IBAction)searchUsingTreeFilter:(id)sender
{
    if ([sender isKindOfClass:[NSSearchField class]]) {
        NSString *searchString = ((NSSearchField *)sender).stringValue;
        [self.foldersTree setSearch:searchString];
    } else if ([sender isKindOfClass:[SearchMethod class]]) {
        [self.foldersTree setSearch:self.searchString];
    } else if ([sender isKindOfClass:[NSButton class]]) {
        // Send an empty string to cancel the search.
        [self.foldersTree setSearch:[NSString string]];
        self.mainWindowController.toolbarSearchField.stringValue = @"";
    }
    [self.mainWindow makeFirstResponder:self.foldersTree.mainView];
}

/* searchUsingToolbarTextField
 * Executes a search using the search field on the toolbar.
 */
-(IBAction)searchUsingToolbarTextField:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        if (!searchPanel) {
            searchPanel = [[SearchPanel alloc] init];
        }
        [searchPanel runSearchPanel:self.mainWindow];
    } else {
        self.searchString = self.toolbarSearchField.stringValue;
        SearchMethod * currentSearchMethod = [Preferences standardPreferences].searchMethod;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:currentSearchMethod.handler withObject: currentSearchMethod];
#pragma clang diagnostic pop
    }
}

/* performAllArticlesSearch
 * Searches for the current searchString in all articles.
 */
-(void)performAllArticlesSearch
{
	[self searchArticlesWithString:self.searchString];
}

/* performAllArticlesSearch
 * Performs a web-search with the defined query URL. This is usually called by plugged-in SearchMethods.
 */
-(void)performWebSearch:(SearchMethod *)searchMethod
{
	(void)[self.browser createNewTab:[searchMethod queryURLforSearchString:searchString] inBackground:NO load:true];
}

/* performWebPageSearch
 * Performs a search for searchString within the currently displayed web page in our bult-in browser.
 */
-(void)performWebPageSearch
{
	id<Tab> activeBrowserTab = self.browser.activeTab;
	if (activeBrowserTab) {
        [activeBrowserTab searchFor:self.searchString
                             action:NSFindPanelActionSetFindString];
	}
}	
	
/* searchArticlesWithString
 * Do the actual article search. The database is called to set the search string
 * and then we make sure the search folder is selected so that the subsequent
 * reload will be scoped by the search string.
 */
-(void)searchArticlesWithString:(NSString *)theSearchString
{
	if (!theSearchString.vna_isBlank) {
        db.searchString = theSearchString;
        if (self.foldersTree.actualSelection != db.searchFolderId) {
			[self.foldersTree selectFolder:db.searchFolderId];
        } else {
			[self.articleController reloadArrayOfArticles];
        }
        [self.browser switchToPrimaryTab];
	}
}

#pragma mark Refresh Subscriptions

// This method is run as a result of -applicationDidFinishLaunching: or by way
// of -handleCheckFrequencyChange: after the user changed the refresh frequency.
- (void)scheduleRefreshWithFrequency:(NSInteger)frequency
                  refreshImmediately:(BOOL)refreshImmediately
{
    NSTimeInterval interval = (NSTimeInterval)frequency;
    if (self.refreshTimer) {
        [self.refreshTimer rescheduleWithInterval:interval
                                  fireImmediately:refreshImmediately];
    } else {
        self.refreshTimer =
            [[VNADispatchTimer alloc] initWithInterval:interval
                                       fireImmediately:refreshImmediately
                                         dispatchQueue:dispatch_get_main_queue()
                                          eventHandler:^{
                [self refreshAllSubscriptions];
            }];
    }
}

- (void)refreshAllSubscriptions
{
    if (self.connecting) {
        return;
    }

    if (Preferences.standardPreferences.syncGoogleReader) {
        [OpenReader.sharedManager loadSubscriptions];
    }
    [RefreshManager.sharedManager refreshSubscriptions:[self.foldersTree folders:0]
                            ignoringSubscriptionStatus:NO];
}

/* refreshAllFolderIcons
 * Get new favicons from all subscriptions.
 */
-(IBAction)refreshAllFolderIcons:(id)sender
{
    os_log_info(VNA_LOG, "Refreshing icons for %lu folders", [self.foldersTree folders:0].count);
    if (!self.connecting) {
		[[RefreshManager sharedManager] refreshFolderIconCacheForSubscriptions:[self.foldersTree folders:0]];
    }
}

/* refreshAllSubscriptions
 * Get new articles from all subscriptions.
 */
-(IBAction)refreshAllSubscriptions:(id)sender
{
    if (self.refreshTimer) {
        [self.refreshTimer fire];
    } else {
        [self refreshAllSubscriptions];
    }
}

-(IBAction)forceRefreshSelectedSubscriptions:(id)sender {
	NSLog(@"Force Refresh");
	[[RefreshManager sharedManager] forceRefreshSubscriptionForFolders:self.foldersTree.selectedFolders];
}

-(IBAction)updateRemoteSubscriptions:(id)sender {
	[[OpenReader sharedManager] loadSubscriptions];
}


/* refreshSelectedSubscriptions
 * Refresh one or more subscriptions selected from the folders list. The selection we obtain
 * may include non-RSS folders so these have to be trimmed out first.
 */
-(IBAction)refreshSelectedSubscriptions:(id)sender
{
	[[RefreshManager sharedManager] refreshSubscriptions:self.foldersTree.selectedFolders ignoringSubscriptionStatus:YES];
}

/* cancelAllRefreshesToolbar
 * Separate cancel refresh action just for the toolbar.
 */
-(IBAction)cancelAllRefreshesToolbar:(id)sender
{
	[self cancelAllRefreshes:sender];
}

/* cancelAllRefreshes
 * Used to kill all active refresh connections and empty the queue of folders due to
 * be refreshed.
 */
-(IBAction)cancelAllRefreshes:(id)sender
{
	[[RefreshManager sharedManager] cancelAll];
}

#pragma mark Blogging

/* blogWithExternalEditor
 * Builds and sends an Apple Event with info from the currently selected articles to the application specified by the bundle identifier that is passed.
 * Iterates over all currently selected articles and consecutively sends Apple Events to the specified app.
 */
-(void)blogWithExternalEditor:(NSString *)externalEditorBundleIdentifier
{
	// Is our target application running? If not, we'll launch it.
    if ([NSRunningApplication runningApplicationsWithBundleIdentifier:externalEditorBundleIdentifier].count == 0) {
        NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
        if (@available(macOS 10.15, *)) {
            NSURL *appURL = [workspace URLForApplicationWithBundleIdentifier:externalEditorBundleIdentifier];
            NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
            configuration.activates = NO;
            [NSWorkspace.sharedWorkspace openApplicationAtURL:appURL
                                                configuration:configuration
                                            completionHandler:^(__unused NSRunningApplication * _Nullable app,
                                                                NSError * _Nullable error) {
                if (error) {
                    os_log_error(VNA_LOG,
                                 "Could not open app with identifier %{public}@. Reason: %{public}@",
                                 appURL.path, error.localizedDescription);
                }
            }];
        } else {
            [workspace launchAppWithBundleIdentifier:externalEditorBundleIdentifier
                                             options:NSWorkspaceLaunchWithoutActivation
                      additionalEventParamDescriptor:NULL
                                    launchIdentifier:nil];
        }
    }
	
	// If the active tab is a web view, blog the URL
    id<Tab> activeBrowserTab = self.browser.activeTab;
    if (activeBrowserTab) {
        //is browser tab
        [self sendBlogEvent:externalEditorBundleIdentifier title:activeBrowserTab.title url:activeBrowserTab.tabUrl.absoluteString body:self.currentTextSelection author:@"" guid:@""];
    } else {
		// Get the currently selected articles from the ArticleView and iterate over them.
        for (Article * currentArticle in self.articleController.markedArticleRange) {
			[self sendBlogEvent:externalEditorBundleIdentifier title:currentArticle.title url:currentArticle.link body:self.currentTextSelection author:currentArticle.author guid:currentArticle.guid];
        }
	}
}

/* sendBlogEvent
 * Send an event to the specified blog editor using the given parameters. Unused parameters should be set to an empty string.
 */
-(void)sendBlogEvent:(NSString *)externalEditorBundleIdentifier title:(NSString *)title url:(NSString *)url body:(NSString *)body author:(NSString *)author guid:(NSString *)guid
{
	NSAppleEventDescriptor * eventRecord;
	NSAppleEventDescriptor * target;
	NSAppleEventDescriptor * event;
	
	// The record descriptor which will hold the information about the post.
	eventRecord = [NSAppleEventDescriptor recordDescriptor];
	
	// Setting the target application.
	target = [NSAppleEventDescriptor descriptorWithDescriptorType:typeApplicationBundleID 
															 data:[externalEditorBundleIdentifier 
																   dataUsingEncoding:NSUTF8StringEncoding]];
	
	// The actual Apple Event that will get sent to the target.
	event = [NSAppleEventDescriptor appleEventWithEventClass:EditDataItemAppleEventClass 
													 eventID:EditDataItemAppleEventID
											targetDescriptor:target 
													returnID:kAutoGenerateReturnID
											   transactionID:kAnyTransactionID];
	
	// Inserting the data about the post we want the target to create.
	[eventRecord setDescriptor:[NSAppleEventDescriptor descriptorWithString:title] forKeyword:DataItemTitle];
	[eventRecord setDescriptor:[NSAppleEventDescriptor descriptorWithString:url] forKeyword:DataItemLink];
	[eventRecord setDescriptor:[NSAppleEventDescriptor descriptorWithString:body] forKeyword:DataItemDescription];
	[eventRecord setDescriptor:[NSAppleEventDescriptor descriptorWithString:author] forKeyword:DataItemCreator];
	[eventRecord setDescriptor:[NSAppleEventDescriptor descriptorWithString:guid] forKeyword:DataItemGUID];
	
	// Add the recordDescriptor whe just created to the actual event.
	[event setDescriptor: eventRecord forKeyword:'----'];
	
	// Send our Apple Event.
	OSStatus err = AESendMessage(event.aeDesc, NULL, kAENoReply | kAEDontReconnect | kAENeverInteract | kAEDontRecord, kAEDefaultTimeout);
	if (err != noErr) { 
		NSLog(@"Error sending Apple Event: %li", (long)err );
	}
}

#pragma mark Toolbar And Menu Bar Validation

/* validateCommonToolbarAndMenuItems
 * Validation code for items that appear on both the toolbar and the menu. Since these are
 * handled identically, we validate here to avoid duplication of code in two delegates.
 * The return value is YES if we handled the validation here and no further validation is
 * needed, NO otherwise.
 */
-(BOOL)validateCommonToolbarAndMenuItems:(SEL)theAction validateFlag:(BOOL *)validateFlag
{
	BOOL isMainWindowVisible = self.mainWindow.visible;
	BOOL isAnyArticleView = self.browser.activeTab == nil;
	
	*validateFlag = NO;
    
	if (theAction == @selector(refreshAllSubscriptions:) || theAction == @selector(cancelAllRefreshesToolbar:)) {
		*validateFlag = !db.readOnly;
		return YES;
	}

	if (theAction == @selector(newSubscription:)) {
		*validateFlag = !db.readOnly && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(newSmartFolder:)) {
		*validateFlag = !db.readOnly && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(skipFolder:)) {
		*validateFlag = !db.readOnly && isAnyArticleView && isMainWindowVisible && db.countOfUnread > 0;
		return YES;
	}
	if (theAction == @selector(getInfo:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		*validateFlag = (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(forceRefreshSelectedSubscriptions:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		*validateFlag = folder.type == VNAFolderTypeOpenReader;
		return YES;
	}
	if (theAction == @selector(viewArticlesTab:)) {
		*validateFlag = !isAnyArticleView;
		return YES;
	}
	if (theAction == @selector(viewNextUnread:)) {
		*validateFlag = db.countOfUnread > 0;
		return YES;
	}
    if (theAction == @selector(markAllRead:)) {
        Folder *folder = [db folderFromID:self.foldersTree.actualSelection];
        if (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) {
            *validateFlag = folder && folder.unreadCount > 0 && !db.readOnly && isMainWindowVisible;
        } else if (folder.type != VNAFolderTypeTrash) {
            *validateFlag = folder && !db.readOnly && db.countOfUnread > 0 && isMainWindowVisible;
        }
        return YES;
    }
	if (theAction == @selector(goBack:)) {
        *validateFlag = isMainWindowVisible && isAnyArticleView && self.articleController.canGoBack;
        return YES;
	}
	if (theAction == @selector(deleteMessage:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		*validateFlag = self.selectedArticle != nil && !db.readOnly
	    		&& isMainWindowVisible && folder.type != VNAFolderTypeOpenReader;
		return YES;
	}
	if (theAction == @selector(emptyTrash:)) {
		*validateFlag = !db.readOnly;
		return YES;
	}
	if (theAction == @selector(searchUsingToolbarTextField:)) {
		*validateFlag = isMainWindowVisible;
	}
	return NO;
}

/* validateToolbarItem
 * Check [theItem identifier] and return YES if the item is enabled, NO otherwise.
 */
-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	BOOL flag;
	[self validateCommonToolbarAndMenuItems:toolbarItem.action validateFlag:&flag];
	return (flag && (NSApp.active));
}

/* validateMenuItem
 * This is our override where we handle item validation for the
 * commands that we own.
 */
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL	theAction = menuItem.action;
	BOOL isMainWindowVisible = self.mainWindow.visible;
	BOOL isAnyArticleView = self.browser.activeTab == nil;
	BOOL isArticleView = self.browser.activeTab == nil;
	BOOL flag;
	
	if ([self validateCommonToolbarAndMenuItems:theAction validateFlag:&flag]) {
		return flag;
	}
	if (theAction == @selector(printDocument:)) {
		if (!isMainWindowVisible) {
			return NO;
		}
		if (isAnyArticleView) {
			return self.selectedArticle != nil;
		} else {
			return !self.browser.activeTab.isLoading;
		}
	} else if (theAction == @selector(goForward:)) {
        return isMainWindowVisible && isAnyArticleView && self.articleController.canGoForward;
	} else if (theAction == @selector(newGroupFolder:)) {
		return !db.readOnly && isMainWindowVisible;
	} else if (theAction == @selector(makeTextStandardSize:)) {
        return self.browser.activeTab != nil;
	} else if (theAction == @selector(makeTextLarger:)) {
        return self.browser.activeTab != nil;
	} else if (theAction == @selector(makeTextSmaller:)) {
        return self.browser.activeTab != nil;
	} else if (theAction == @selector(doViewColumn:)) {
		Field * field = menuItem.representedObject;
		menuItem.state = field.visible ? NSControlStateValueOn : NSControlStateValueOff;
		return isMainWindowVisible && isArticleView;
	} else if (theAction == @selector(doSelectStyle:)) {
		NSString * styleName = menuItem.title;
		menuItem.state = [styleName isEqualToString:[Preferences standardPreferences].displayStyle] ? NSControlStateValueOn : NSControlStateValueOff;
		return isMainWindowVisible && isAnyArticleView;
	} else if (theAction == @selector(doSortColumn:)) {
		Field * field = menuItem.representedObject;
        if ([field.name isEqualToString:self.articleController.sortColumnIdentifier]) {
			menuItem.state = NSControlStateValueOn;
        } else {
			menuItem.state = NSControlStateValueOff;
        }
		return isMainWindowVisible && isAnyArticleView;
	} else if (theAction == @selector(doSortDirection:)) {
		NSNumber * ascendingNumber = menuItem.representedObject;
		BOOL ascending = ascendingNumber.integerValue;
        if (ascending == self.articleController.sortIsAscending) {
			menuItem.state = NSControlStateValueOn;
        } else {
			menuItem.state = NSControlStateValueOff;
        }
		return isMainWindowVisible && isAnyArticleView;
	} else if (theAction == @selector(unsubscribeFeed:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		if (folder) {
			if (folder.isUnsubscribed) {
				[menuItem setTitle:NSLocalizedString(@"Resubscribe to Feed", nil)];
			} else {
				[menuItem setTitle:NSLocalizedString(@"Unsubscribe from Feed", nil)];
			}
		}
		return folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && !db.readOnly && isMainWindowVisible;
	} else if (theAction == @selector(useCurrentStyleForArticles:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		if (folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && !folder.loadsFullHTML) {
			menuItem.state = NSControlStateValueOn;
		} else {
			menuItem.state = NSControlStateValueOff;
		}
		return folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && !db.readOnly && isMainWindowVisible;
	} else if (theAction == @selector(useWebPageForArticles:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		if (folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && folder.loadsFullHTML) {
			menuItem.state = NSControlStateValueOn;
		} else {
			menuItem.state = NSControlStateValueOff;
		}
		return folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && !db.readOnly && isMainWindowVisible;
	} else if (theAction == @selector(deleteFolder:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		if (folder.type == VNAFolderTypeSearch) {
			menuItem.title = NSLocalizedStringWithDefaultValue(@"delete.menuItem",
															   nil,
															   NSBundle.mainBundle,
															   @"Delete",
															   @"Title of a menu item");
		} else {
			[menuItem setTitle:NSLocalizedString(@"Delete…", @"Title of a menu item")];
		}
		return folder && folder.type != VNAFolderTypeTrash && !db.readOnly && isMainWindowVisible;
	} else if (theAction == @selector(refreshSelectedSubscriptions:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		return folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeGroup || folder.type == VNAFolderTypeOpenReader) && !db.readOnly;
	} else if (theAction == @selector(refreshAllFolderIcons:)) {
		return !self.connecting && !db.readOnly;
	} else if (theAction == @selector(renameFolder:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		return folder && !db.readOnly && isMainWindowVisible;
	} else if (theAction == @selector(markAllSubscriptionsRead:)) {
		return !db.readOnly && isMainWindowVisible && db.countOfUnread > 0;
	} else if (theAction == @selector(importSubscriptions:)) {
		return !db.readOnly && isMainWindowVisible;
	} else if (theAction == @selector(cancelAllRefreshes:)) {
		return !db.readOnly && self.connecting;
	} else if ((theAction == @selector(viewSourceHomePage:)) || (theAction == @selector(viewSourceHomePageInAlternateBrowser:))) {
		Article * thisArticle = self.selectedArticle;
		Folder * folder = (thisArticle) ? [db folderFromID:thisArticle.folderId] : [db folderFromID:self.foldersTree.actualSelection];
		return folder && (thisArticle || folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && (folder.homePage && !folder.homePage.vna_isBlank && isMainWindowVisible);
	} else if ((theAction == @selector(viewArticlePages:)) || (theAction == @selector(viewArticlePagesInAlternateBrowser:))) {
		Article * thisArticle = self.selectedArticle;
		if (thisArticle != nil) {
			return (thisArticle.link && !thisArticle.link.vna_isBlank && isMainWindowVisible);
		}
		return NO;
	} else if (theAction == @selector(exportSubscriptions:)) {
		return isMainWindowVisible;
	} else if (theAction == @selector(reindexDatabase:)) {
		return !self.connecting && !db.readOnly && isMainWindowVisible;
	} else if (theAction == @selector(editFolder:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		return folder && (folder.type == VNAFolderTypeSmart || folder.type == VNAFolderTypeRSS) && !db.readOnly && isMainWindowVisible;
	} else if (theAction == @selector(restoreMessage:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		return folder.type == VNAFolderTypeTrash && self.selectedArticle != nil && !db.readOnly && isMainWindowVisible;
	} else if (theAction == @selector(previousTab:)) {
		return isMainWindowVisible && self.browser.browserTabCount > 1;
	} else if (theAction == @selector(nextTab:)) {
		return isMainWindowVisible && self.browser.browserTabCount > 1;
	} else if (theAction == @selector(closeActiveTab:)) {
		return isMainWindowVisible && !isArticleView;
	} else if (theAction == @selector(closeAllTabs:)) {
		return isMainWindowVisible && self.browser.browserTabCount > 1;
	} else if (theAction == @selector(reloadPage:)) {
		return !isAnyArticleView;
	} else if (theAction == @selector(stopReloadingPage:)) {
		return self.browser.activeTab.isLoading;
	} else if (theAction == @selector(keepFoldersArranged:)) {
		Preferences * prefs = [Preferences standardPreferences];
		menuItem.state = (prefs.self.foldersTreeSortMethod == menuItem.tag) ? NSControlStateValueOn : NSControlStateValueOff;
		return isMainWindowVisible;
	} else if (theAction == @selector(setFocusToSearchField:)) {
		return isMainWindowVisible;
	} else if (theAction == @selector(markFlagged:)) {
		Article * thisArticle = self.selectedArticle;
		if (thisArticle != nil) {
			if (thisArticle.isFlagged) {
				[menuItem setTitle:NSLocalizedString(@"Mark Unflagged", nil)];
			} else {
				[menuItem setTitle:NSLocalizedString(@"Mark Flagged", nil)];
			}
		}
		return (thisArticle != nil && !db.readOnly && isMainWindowVisible);
	} else if (theAction == @selector(markRead:)) {
		Article * thisArticle = self.selectedArticle;
		return (thisArticle != nil && !db.readOnly && isMainWindowVisible);
	} else if (theAction == @selector(markUnread:)) {
		Article * thisArticle = self.selectedArticle;
		return (thisArticle != nil && !db.readOnly && isMainWindowVisible);
	} else if (theAction == @selector(downloadEnclosure:)) {
        if (self.articleController.markedArticleRange.count > 1) {
			[menuItem setTitle:NSLocalizedString(@"Download Enclosures", @"Title of a menu item")];
        } else {
			[menuItem setTitle:NSLocalizedString(@"Download Enclosure", @"Title of a menu item")];
        }
		return (self.selectedArticle.hasEnclosure && isMainWindowVisible);
	} else if (theAction == @selector(setSearchMethod:)) {
		Preferences * prefs = [Preferences standardPreferences];
		if ([prefs.searchMethod.displayName isEqualToString:[menuItem.representedObject displayName]]) {
			menuItem.state = NSControlStateValueOn;
		} else { 
			menuItem.state = NSControlStateValueOff;
		}
		return YES;
	} else if (theAction == @selector(openVienna:)) {
        return self.mainWindow.isKeyWindow == false;
    }

	return YES;
}

// MARK: Info panel delegate

// This delegate method is called when the user clicks on the validate button
// on the info panel.
- (void)infoPanelControllerWillOpenURL:(nonnull NSURL *)url {
    [self openURL:url inPreferredBrowser:YES];
}

#pragma mark Activity panel

- (ActivityPanelController *)activityPanelController {
    if (!_activityPanelController) {
        _activityPanelController = [ActivityPanelController new];
        _activityPanelController.delegate = self;
    }

    return _activityPanelController;
}

/**
 * Show the activity window
 */
- (IBAction)showActivityWindow:(id)sender {
    [self.activityPanelController showWindow:self];
}

/**
 This delegate method is called when the user clicks on a row in the activity
 panel's table view. This will be used to select a correspondng folder.
 */
- (void)activityPanelControllerDidSelectFolder:(Folder *)folder {
    [self selectFolder:folder.itemId];
}

// MARK: article controller
- (ArticleController *)articleController {
    if (!_articleController) {
        _articleController = [[ArticleController alloc] init];
    }
    return _articleController;
}

// MARK: Folders Tree
- (FoldersTree *)foldersTree {
    if (!_foldersTree) {
        _foldersTree = [FoldersTree new];
    }
    return _foldersTree;
}

#pragma mark Dealloc

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
    [self.pluginManager removeObserver:self
                            forKeyPath:NSStringFromSelector(@selector(numberOfPlugins))
                               context:VNAAppControllerObserverContext];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
