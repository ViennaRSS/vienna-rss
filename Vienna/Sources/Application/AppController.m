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
#import "AppController+Notifications.h"
#import "Import.h"
#import "Export.h"
#import "RefreshManager.h"
#import "StringExtensions.h"
#import "SearchFolder.h"
#import "NewSubscription.h"
#import "NewGroupFolder.h"
#import "ViennaApp.h"
#import "ActivityPanelController.h"
#import "BrowserPaneTemplate.h"
#import "Constants.h"
#import "EmptyTrashWarning.h"
#import "Preferences.h"
#import "InfoPanelController.h"
#import "InfoPanelManager.h"
#import "DownloadManager.h"
#import "HelperFunctions.h"
#import "DisclosureView.h"
#import "SearchPanel.h"
#import "SearchMethod.h"
#import "OpenReader.h"
#import "VTPG_Common.h"
#import "Debug.h"
#import "Database.h"
#import "NSURL+Utils.h"
#import "PreferencesWindowController.h"
#import "PluginManager.h"
#import "ArticleController.h"
#import "FoldersTree.h"
#import "Article.h"
#import "DownloadWindow.h"
#import "TreeNode.h"
#import "Field.h"
#import "Folder.h"
#import "BrowserView.h"
#import "ArticleListView.h"
#import "UnifiedDisplayView.h"
#import "ArticleView.h"
#import "FolderView.h"
#import "Vienna-Swift.h"

@interface AppController () <InfoPanelControllerDelegate, ActivityPanelControllerDelegate>

-(void)installSleepHandler;
-(void)installScriptsFolderWatcher;
-(void)handleTabChange:(NSNotification *)nc;
-(void)handleFolderSelection:(NSNotification *)nc;
-(void)handleCheckFrequencyChange:(NSNotification *)nc;
-(void)handleFolderNameChange:(NSNotification *)nc;
-(void)handleDidBecomeKeyWindow:(NSNotification *)nc;
-(void)handleReloadPreferences:(NSNotification *)nc;
-(void)handleShowAppInStatusBar:(NSNotification *)nc;
-(void)handleShowFilterBar:(NSNotification *)nc;
-(void)setAppStatusBarIcon;
-(void)updateNewArticlesNotification;
-(void)showAppInStatusBar;
-(void)initSortMenu;
-(void)initColumnsMenu;
-(void)initScriptsMenu;
-(void)doEditFolder:(Folder *)folder;
-(void)refreshOnTimer:(NSTimer *)aTimer;
-(BOOL)installFilename:(NSString *)srcFile toPath:(NSString *)path;
-(void)setFilterBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate;
-(void)setPersistedFilterBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate;
-(void)runAppleScript:(NSString *)scriptName;
@property (nonatomic, readonly, copy) NSString *appName;
-(void)sendBlogEvent:(NSString *)externalEditorBundleIdentifier title:(NSString *)title url:(NSString *)url body:(NSString *)body author:(NSString *)author guid:(NSString *)guid;
-(void)setLayout:(NSInteger)newLayout withRefresh:(BOOL)refreshFlag;
-(void)updateAlternateMenuTitle;
-(void)updateSearchPlaceholderAndSearchMethod;
-(void)updateCloseCommands;
@property (nonatomic, getter=isFilterBarVisible, readonly) BOOL filterBarVisible;
@property (nonatomic, readonly, strong) NSTimer *checkTimer;
-(IBAction)cancelAllRefreshesToolbar:(id)sender;

@property (nonatomic) MainWindowController *mainWindowController;
@property (weak, nonatomic) NSWindow *mainWindow;
@property (nonatomic) ActivityPanelController *activityPanelController;
@property (nonatomic) DirectoryMonitor *directoryMonitor;
@property (nonatomic) PreferencesWindowController *preferencesWindowController;
@property (weak, nonatomic) FolderView *outlineView;
@property (weak, nonatomic) DisclosureView *filterDisclosureView;
@property (weak, nonatomic) NSSearchField *filterSearchField;
@property (weak, nonatomic) NSSearchField *toolbarSearchField;

@end

// Static constant strings that are typically never tweaked

// Awake from sleep
static io_connect_t root_port;
static void MySleepCallBack(void * x, io_service_t y, natural_t messageType, void * messageArgument);

@implementation AppController

@synthesize rssFeed = _rssFeed;

/* init
 * Class instance initialisation.
 */
-(instancetype)init
{
	if ((self = [super init]) != nil)
	{
		scriptPathMappings = [[NSMutableDictionary alloc] init];
		lastCountOfUnread = 0;
		appStatusItem = nil;
		scriptsMenuItem = nil;
		checkTimer = nil;
		didCompleteInitialisation = NO;
		emptyTrashWarning = nil;
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
	if (!doneSafeInit)
	{
        [ASIHTTPRequest setDefaultUserAgentString:[NSString stringWithFormat:MA_DefaultUserAgentString, ((ViennaApp *)NSApp).applicationVersion.firstWord]];
        
		[self.foldersTree initialiseFoldersTree];

		Preferences * prefs = [Preferences standardPreferences];

		// Set the initial filter bar state
		[self setFilterBarState:prefs.showFilterBar withAnimation:NO];
		// Select the folder and article from the last session
		NSInteger previousFolderId = [prefs integerForKey:MAPref_CachedFolderID];
		NSString * previousArticleGuid = [prefs stringForKey:MAPref_CachedArticleGUID];
		if (previousArticleGuid.blank)
			previousArticleGuid = nil;
		[self.articleController selectFolderAndArticle:previousFolderId guid:previousArticleGuid];

		[self.mainWindow makeFirstResponder:(previousArticleGuid != nil) ? [self.browserView primaryTabItemView].mainView : self.foldersTree.mainView];

		if (prefs.refreshOnStartup)
			[self refreshAllSubscriptions:self];

		// Start opening the old tabs once everything else has finished initializing and setting up
		NSArray<NSString *> * tabLinks = [prefs arrayForKey:MAPref_TabList];
		NSDictionary<NSString *, NSString *> * tabTitles = [prefs objectForKey:MAPref_TabTitleDictionary];

		for (int i = 0; i < tabLinks.count; i++)
		{
			NSString *tabLink = tabLinks[i].length ? tabLinks[i] : nil;
			[self.browserView createNewTab:([NSURL URLWithString:tabLink])
					 withTitle:tabTitles[tabLink] inBackground:YES];
		}

		doneSafeInit = YES;
		
	}
	didCompleteInitialisation = YES;
}

#pragma mark Accessor Methods

- (NewSubscription *)rssFeed {
    if (!_rssFeed)
        _rssFeed = [[NewSubscription alloc] initWithDatabase:db];
    return _rssFeed;
}

#pragma mark IORegisterForSystemPower

/* MySleepCallBack
 * Called in response to an I/O event that we established via IORegisterForSystemPower. The
 * messageType parameter allows us to distinguish between which event occurred.
 */
static void MySleepCallBack(void * refCon, io_service_t service, natural_t messageType, void * messageArgument)
{
	if (messageType == kIOMessageSystemHasPoweredOn)
	{
		AppController * app = APPCONTROLLER;
		if (app != nil)
		{
            Preferences * prefs = [Preferences standardPreferences];
            NSInteger frequency = prefs.refreshFrequency;
            if (frequency > 0)
            {
                NSDate * lastRefresh = [prefs objectForKey:MAPref_LastRefreshDate];
                if ((lastRefresh == nil) || (app.checkTimer == nil))
                    [app handleCheckFrequencyChange:nil];
                else
                {
                    // Wait at least 15 seconds after waking to avoid refresh errors.
                    NSTimeInterval interval = -lastRefresh.timeIntervalSinceNow;
                    if (interval > frequency)
                    {
                        [NSTimer scheduledTimerWithTimeInterval:15.0
                                                         target:app
                                                       selector:@selector(refreshOnTimer:)
                                                       userInfo:nil
                                                        repeats:NO];
                        [app handleCheckFrequencyChange:nil];
                    }
                    else
                    {
                        app.checkTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:15.0 + frequency - interval];
                    }
                }
            }
		}
	}
	else if (messageType == kIOMessageCanSystemSleep)
	{
		// Idle sleep is about to kick in. Allow it otherwise the system
		// will wait 30 seconds then go to sleep.
		IOAllowPowerChange(root_port, (long)messageArgument);
	}
	else if (messageType == kIOMessageSystemWillSleep)
	{
		// The system WILL go to sleep. Allow it otherwise the system will
		// wait 30 seconds then go to sleep.
		IOAllowPowerChange(root_port, (long)messageArgument);
	}
}

/* installSleepHandler
 * Registers our handler to be notified when the system awakes from sleep. We use this to kick
 * off a refresh if necessary.
 */
-(void)installSleepHandler
{
	IONotificationPortRef notify;
	io_object_t anIterator;
	
	root_port = IORegisterForSystemPower((__bridge void *)(self), &notify, MySleepCallBack, &anIterator);
	if (root_port != 0)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notify), kCFRunLoopCommonModes);
}

/* installScriptsFolderWatcher
 * Install a handler to notify of changes in the scripts folder.
 * The handler is a code block which triggers a refresh of the scripts menu
 */
- (void)installScriptsFolderWatcher {
    NSURL *path = [NSURL fileURLWithPath:Preferences.standardPreferences.scriptsFolder];
    self.directoryMonitor = [[DirectoryMonitor alloc] initWithDirectories:@[path]];

    NSError *error = nil;
    typeof(self) __weak weakSelf = self;
    [self.directoryMonitor startAndReturnError:&error eventHandler:^{
        [weakSelf initScriptsMenu];
    }];
    if (error) {
        LLog(@"%@", error.localizedDescription);
    }
}

/* layoutManager
 * Return a cached instance of NSLayoutManager for calculating the font height.
 */
-(NSLayoutManager *)layoutManager
{
	static NSLayoutManager * theManager = nil;
	
	if (theManager == nil)
		theManager = [[NSLayoutManager alloc] init];
	return theManager;
}

#pragma mark Application Delegate

/* applicationDidFinishLaunching
 * Handle post-load activities.
 */
-(void)applicationDidFinishLaunching:(NSNotification *)aNot
{
	self.mainWindowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindowController"];
	self.mainWindow = self.mainWindowController.window;

	self.browserView = self.mainWindowController.browserView;
	self.articleListView = self.mainWindowController.articleListView;
	self.articleListView.controller = self;
	self.unifiedListView = self.mainWindowController.unifiedDisplayView;
	self.unifiedListView.controller = self;

	self.outlineView = self.mainWindowController.outlineView;
    self.foldersTree.controller = self;
    self.foldersTree.outlineView = self.outlineView;
    self.outlineView.delegate = self.foldersTree;
    self.outlineView.dataSource = self.foldersTree;

    self.articleController.foldersTree = self.foldersTree;
    self.articleController.unifiedListView = self.unifiedListView;
    self.articleController.articleListView = self.articleListView;

	self.filterDisclosureView = self.mainWindowController.filterDisclosureView;
	self.filterSearchField = self.mainWindowController.filterSearchField;
	self.toolbarSearchField = self.mainWindowController.toolbarSearchField;

	Preferences * prefs = [Preferences standardPreferences];

    // Restore the most recent layout
    [self setLayout:prefs.layout withRefresh:NO];

    // Set the delegates
    [NSApplication sharedApplication].delegate = self;
	
	// Register a bunch of notifications
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleFolderSelection:) name:@"MA_Notify_FolderSelectionChange" object:nil];
	[nc addObserver:self selector:@selector(handleCheckFrequencyChange:) name:@"MA_Notify_CheckFrequencyChange" object:nil];
	[nc addObserver:self selector:@selector(handleEditFolder:) name:@"MA_Notify_EditFolder" object:nil];
	[nc addObserver:self selector:@selector(handleRefreshStatusChange:) name:@"MA_Notify_RefreshStatus" object:nil];
	[nc addObserver:self selector:@selector(handleTabChange:) name:@"MA_Notify_TabChanged" object:nil];
	[nc addObserver:self selector:@selector(handleTabCountChange:) name:@"MA_Notify_TabCountChanged" object:nil];
	[nc addObserver:self selector:@selector(handleFolderNameChange:) name:@"MA_Notify_FolderNameChanged" object:nil];
	[nc addObserver:self selector:@selector(handleDidBecomeKeyWindow:) name:NSWindowDidBecomeKeyNotification object:nil];
	[nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_PreferenceChange" object:nil];
	[nc addObserver:self selector:@selector(handleShowAppInStatusBar:) name:@"MA_Notify_ShowAppInStatusBarChanged" object:nil];
	[nc addObserver:self selector:@selector(handleShowFilterBar:) name:@"MA_Notify_FilterBarChanged" object:nil];
	[nc addObserver:self selector:@selector(showUnreadCountOnApplicationIconAndWindowTitle) name:@"MA_Notify_FoldersUpdated" object:nil];
	//Open Reader Notifications
    [nc addObserver:self selector:@selector(handleGoogleAuthFailed:) name:@"MA_Notify_GoogleAuthFailed" object:nil];

	// Initialize the database
	if ((db = [Database sharedManager]) == nil)
	{
		[NSApp terminate:nil];
		return;
	}

	// Preload dictionary of standard URLs
	NSString * pathToPList = [[NSBundle mainBundle] pathForResource:@"StandardURLs.plist" ofType:@""];
	if (pathToPList != nil)
		standardURLs = [NSDictionary dictionaryWithContentsOfFile:pathToPList];
	
	// Initialize the Sort By and Columns menu
	[self initSortMenu];
	[self initColumnsMenu];

    // Load the plug-ins into the main menu.
    [self populatePluginsMenu];

    // Observe changes to the plug-in count.
    [self.pluginManager addObserver:self
                         forKeyPath:NSStringFromSelector(@selector(numberOfPlugins))
                            options:0
                            context:nil];

	// Load the styles into the main menu.
    [self populateStyleMenu];

	// Show the current unread count on the app icon
	[self showUnreadCountOnApplicationIconAndWindowTitle];
	
	// Set alternate in main menu for opening pages, and check for correct title of menu item
	// This is a hack, because Interface Builder refuses to set alternates with only the shift key as modifier.
	NSMenuItem * alternateItem = menuItemWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	if (alternateItem != nil)
	{
		alternateItem.keyEquivalentModifierMask = NSAlternateKeyMask;
		[alternateItem setAlternate:YES];
	}
	alternateItem = menuItemWithAction(@selector(viewArticlePagesInAlternateBrowser:));
	if (alternateItem != nil)
	{
		alternateItem.keyEquivalentModifierMask = NSAlternateKeyMask;
		[alternateItem setAlternate:YES];
	}
	[self updateAlternateMenuTitle];
	
	// Create a menu for the search field
	// The menu title doesn't appear anywhere so we don't localise it. The titles of each
	// item is localised though.	
	((NSSearchFieldCell *)self.toolbarSearchField.cell).searchMenuTemplate = self.searchFieldMenu;
	((NSSearchFieldCell *)self.filterSearchField.cell).searchMenuTemplate = self.searchFieldMenu;
	
	// Set the placeholder string for the global search field
	SearchMethod * currentSearchMethod = [Preferences standardPreferences].searchMethod;
    if (@available(macOS 10.10, *)) {
        self.toolbarSearchField.placeholderString = currentSearchMethod.friendlyName;
    } else {
        ((NSSearchFieldCell *)self.toolbarSearchField.cell).placeholderString = currentSearchMethod.friendlyName;
    }
	
	// Add Scripts menu if we have any scripts
	if (!hasOSScriptsMenu())
		[self initScriptsMenu];

	// Add the app to the status bar if needed.
	[self showAppInStatusBar];

    // Notification Center delegate
    NSUserNotificationCenter.defaultUserNotificationCenter.delegate = self;

	// Start the check timer
	[self handleCheckFrequencyChange:nil];

	// Register to be informed when the system awakes from sleep
	[self installSleepHandler];
	
	// Register to be notified when the scripts folder changes.
	if (!hasOSScriptsMenu())
		[self installScriptsFolderWatcher];
	
	// Fix up the Close commands
	[self updateCloseCommands];
	
	[self showMainWindow:self];
	
	// Hook up the key sequence properly now that all NIBs are loaded.
	self.foldersTree.mainView.nextKeyView = [self.browserView primaryTabItemView].mainView;
    
	// Do safe initialisation.
	[self performSelector:@selector(doSafeInitialisation)
			   withObject:nil
			   afterDelay:0];

}

/* applicationShouldHandleReopen
 * Handle the notification sent when the application is reopened such as when the dock icon
 * is clicked. If the main window was previously hidden, we show it again here.
 */
-(BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	if (!didCompleteInitialisation)
		return NO;
	
	[self showMainWindow:self];
	if (emptyTrashWarning != nil)
		[emptyTrashWarning showWindow:self];
	return YES;
}

/* applicationShouldTerminate
 * This function is called when the user wants to close Vienna. First we check to see
 * if a connection or import is running and that all articles are saved.
 */
-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if ([DownloadManager sharedInstance].activeDownloads > 0)
	{
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"One or more downloads are in progress", nil);
        alert.informativeText = NSLocalizedString(@"If you quit Vienna now, all downloads will stop.", nil);
        [alert addButtonWithTitle:NSLocalizedString(@"Quit", @"Title of a button on an alert")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Title of a button on an alert")];
        NSModalResponse alertResponse = [alert runModal];

		if (alertResponse == NSAlertSecondButtonReturn)
		{
            [[NSNotificationCenter defaultCenter]  removeObserver:self];
			return NSTerminateCancel;
		}
	}
	
	if (!didCompleteInitialisation)
	{
        [[NSNotificationCenter defaultCenter]  removeObserver:self];
		return NSTerminateNow;
	}
	
	switch ([[Preferences standardPreferences] integerForKey:MAPref_EmptyTrashNotification])
	{
		case MA_EmptyTrash_None: break;
			
		case MA_EmptyTrash_WithoutWarning:
			if (!db.trashEmpty)
			{
				[db purgeDeletedArticles];
			}
			break;
			
		case MA_EmptyTrash_WithWarning:
			if (!db.trashEmpty)
			{
				if (emptyTrashWarning == nil)
					emptyTrashWarning = [[EmptyTrashWarning alloc] init];
				if (emptyTrashWarning.shouldEmptyTrash)
				{
					[db purgeDeletedArticles];
				}
				emptyTrashWarning = nil;
			}
			break;
			
		default: break;
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
    
	if (didCompleteInitialisation)
	{
		Preferences * prefs = [Preferences standardPreferences];
		
		// Close the activity window explicitly to force it to
		// save its split bar position to the preferences.
		NSWindow *activityPanel = self.activityPanelController.window;
		[activityPanel performClose:self];
		
		// Put back the original app icon
		[NSApp.dockTile setBadgeLabel:nil];
		
		// Save the open tabs
		[self.browserView saveOpenTabs];
		
		// Remember the article list column position, sizes, etc.
		[self.articleController saveTableSettings];
		[self.foldersTree saveFolderSettings];
		
		// Finally save preferences
		[prefs savePreferences];
		
        [[NSNotificationCenter defaultCenter]  removeObserver:self];
	}
	[db close];
}


/* openFile [delegate]
 * Called when the user opens a data file associated with Vienna by clicking in the finder or dragging it onto the dock.
 */
-(BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	Preferences * prefs = [Preferences standardPreferences];
	if ([filename.pathExtension isEqualToString:@"viennastyle"])
	{
		NSString * styleName = filename.lastPathComponent.stringByDeletingPathExtension;
		if (![self installFilename:filename toPath:prefs.stylesFolder])
			[Preferences standardPreferences].displayStyle = styleName;
		else
		{
			Preferences * prefs = [Preferences standardPreferences];
            [self populateStyleMenu];
			prefs.displayStyle = styleName;
            runOKAlertPanel(NSLocalizedString(@"Vienna has installed a new style", nil), NSLocalizedString(@"The style \"%@\" has been installed to your Styles folder and added to the Style menu.", nil), styleName);
		}
		return YES;
	}
	if ([filename.pathExtension isEqualToString:@"viennaplugin"])
	{
		NSString * path = prefs.pluginsFolder;
		if ([self installFilename:filename toPath:path])
		{
			runOKAlertPanel(NSLocalizedString(@"Plugin installed", nil), NSLocalizedString(@"A new plugin has been installed. It is now available from the menu and you can add it to the toolbar.", nil));			
			NSString * fullPath = [path stringByAppendingPathComponent:filename.lastPathComponent];
            [self.pluginManager loadPlugin:fullPath];
		}
		return YES;
	}
	if ([filename.pathExtension isEqualToString:@"scpt"])
	{
		if ([self installFilename:filename toPath:prefs.scriptsFolder])
		{
			if (!hasOSScriptsMenu())
				[self initScriptsMenu];
		}
		return YES;
	}
	if ([filename.pathExtension isEqualToString:@"opml"])
	{
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"Import subscriptions from OPML file?", nil);
        alert.informativeText = NSLocalizedString(@"Do you really want to import the subscriptions from the specified OPML file?", nil);
        [alert addButtonWithTitle:NSLocalizedString(@"Import", @"Title of a button on an alert")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Title of a button on an alert")];
        NSModalResponse alertResponse = [alert runModal];

        if (alertResponse == NSAlertFirstButtonReturn) {
            [Import importFromFile:filename];
            return YES;
        } else {
            return NO;
        }
	}
    if ([filename.pathExtension isEqualToString:@"webloc"])
    {
        NSURL* url = [NSURL URLFromInetloc:filename];
        if (!self.mainWindow.visible)
        	[self.mainWindow makeKeyAndOrderFront:self];
        if (url != nil && !db.readOnly)
        {
            [self.rssFeed newSubscription:self.mainWindow underParent:self.foldersTree.groupParentSelection initialURL:url.absoluteString];
		    return YES;
        }
        else
        	return NO;
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
	
	if (![fileManager fileExistsAtPath:path isDirectory:&isDir])
	{
		if (![fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:NULL error:NULL])
		{
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

	// Add all built-in search methods to the menu. 
	for (searchMethod in [SearchMethod builtInSearchMethods])
	{
		friendlyName = searchMethod.friendlyName;
		item = [[NSMenuItem alloc] initWithTitle:friendlyName
                                          action:@selector(setSearchMethod:)
                                   keyEquivalent:@""];
		item.representedObject = searchMethod;
		
		// Is this the currently set search method? If yes, mark it as such.
		if ( [friendlyName isEqualToString:[Preferences standardPreferences].searchMethod.friendlyName] )
			item.state = NSOnState;
		
		[cellMenu addItem:item];
	}
	
	// Add all available plugged-in search methods to the menu.
	NSMutableArray * searchMethods = [NSMutableArray arrayWithArray:self.pluginManager.searchMethods];
	if (searchMethods.count > 0)
	{	
		[cellMenu addItem: [NSMenuItem separatorItem]];
		
		for (searchMethod in searchMethods)
		{
			if (!searchMethod.friendlyName) 
				continue;
			item = [[NSMenuItem alloc] initWithTitle:searchMethod.friendlyName action:@selector(setSearchMethod:) keyEquivalent:@""];
			item.representedObject = searchMethod;
			// Is this the currently set search method? If yes, mark it as such.
			if ( [searchMethod.friendlyName isEqualToString: [Preferences standardPreferences].searchMethod.friendlyName] )
				item.state = NSOnState;
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

/* standardURLs
 */
-(NSDictionary *)standardURLs
{
	return standardURLs;
}

/* reindexDatabase
 * Reindex the database
 */
-(IBAction)reindexDatabase:(id)sender
{
	[db reindexDatabase];
}

/* reportLayout
 * Switch to report layout
 */
-(IBAction)reportLayout:(id)sender
{
	[self setLayout:MA_Layout_Report withRefresh:YES];
}

/* condensedLayout
 * Switch to condensed layout
 */
-(IBAction)condensedLayout:(id)sender
{
	[self setLayout:MA_Layout_Condensed withRefresh:YES];
}

/* unifiedLayout
 * Switch to unified layout.
 */
-(IBAction)unifiedLayout:(id)sender
{
	[self setLayout:MA_Layout_Unified withRefresh:YES];
}

/* setLayout
 * Changes the layout of the panes.
 */
-(void)setLayout:(NSInteger)newLayout withRefresh:(BOOL)refreshFlag
{
	[self.articleController setLayout:newLayout];
    if (refreshFlag) {
        [self.articleController.mainArticleView refreshFolder:MA_Refresh_RedrawList];
    }
	[self.browserView setPrimaryTabItemView:self.articleController.mainArticleView];
	self.foldersTree.mainView.nextKeyView = [self.browserView primaryTabItemView].mainView;
    if (self.selectedArticle == nil)
        [self.mainWindow makeFirstResponder:self.foldersTree.mainView];
    else
        [self.mainWindow makeFirstResponder:[self.browserView primaryTabItemView].mainView];
	[self updateSearchPlaceholderAndSearchMethod];
}


/* getUrl
 * Handle http https URL Scheme passed to applicaton
 */
- (void)getUrl:(NSAppleEventDescriptor *)event
withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *urlStr = [event paramDescriptorForKeyword:keyDirectObject].stringValue;
    if(urlStr)
        [self.rssFeed newSubscription:self.mainWindow underParent:self.foldersTree.groupParentSelection initialURL:urlStr];
}

/* contextMenuItemsForElement
 * Creates a new context menu for our web pane.
 */
-(NSArray *)contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray * newDefaultMenu = [[NSMutableArray alloc] initWithArray:defaultMenuItems];
	NSURL * urlLink = [element valueForKey:WebElementLinkURLKey];
	NSURL * imageURL;
	NSString * defaultBrowser = getDefaultBrowser();
	if (defaultBrowser == nil)
		defaultBrowser = NSLocalizedString(@"External Browser", nil);
	NSMenuItem * newMenuItem;
	NSInteger count = newDefaultMenu.count;
	NSInteger index;
	
	// Note: this is only safe to do if we're going from [count..0] when iterating
	// over newDefaultMenu. If we switch to the other direction, this will break.
	for (index = count - 1; index >= 0; --index)
	{
		NSMenuItem * menuItem = newDefaultMenu[index];
		switch (menuItem.tag)
		{
			case WebMenuItemTagOpenImageInNewWindow:
				imageURL = [element valueForKey:WebElementImageURLKey];
				if (imageURL != nil)
				{
					[menuItem setTitle:NSLocalizedString(@"Open Image in New Tab", nil)];
					menuItem.target = self;
					menuItem.action = @selector(openWebElementInNewTab:);
					menuItem.representedObject = imageURL;
					menuItem.tag = WebMenuItemTagOther;
					newMenuItem = [NSMenuItem new];
					if (newMenuItem != nil)
					{
						newMenuItem.title = [NSString stringWithFormat:NSLocalizedString(@"Open Image in %@", nil), defaultBrowser];
						newMenuItem.target = self;
						newMenuItem.action = @selector(openWebElementInDefaultBrowser:);
						newMenuItem.representedObject = imageURL;
						newMenuItem.tag = WebMenuItemTagOther;
						[newDefaultMenu insertObject:newMenuItem atIndex:index + 1];
					}
				}
				break;
				
			case WebMenuItemTagOpenFrameInNewWindow:
				[menuItem setTitle:NSLocalizedString(@"Open Frame", nil)];
				break;
				
			case WebMenuItemTagOpenLinkInNewWindow:
				[menuItem setTitle:NSLocalizedString(@"Open Link in New Tab", nil)];
				menuItem.target = self;
				menuItem.action = @selector(openWebElementInNewTab:);
				menuItem.representedObject = urlLink;
				menuItem.tag = WebMenuItemTagOther;
				newMenuItem = [[NSMenuItem alloc] init];
				if (newMenuItem != nil)
				{
					newMenuItem.title = [NSString stringWithFormat:NSLocalizedString(@"Open Link in %@", nil), defaultBrowser];
					newMenuItem.target = self;
					newMenuItem.action = @selector(openWebElementInDefaultBrowser:);
					newMenuItem.representedObject = urlLink;
					newMenuItem.tag = WebMenuItemTagOther;
					[newDefaultMenu insertObject:newMenuItem atIndex:index + 1];
				}
				break;
				
			case WebMenuItemTagCopyLinkToClipboard:
				[menuItem setTitle:NSLocalizedString(@"Copy Link to Clipboard", nil)];
				break;
		}
	}
	
	if (urlLink == nil)
	{
		// Separate our new commands from the existing ones.
		[newDefaultMenu addObject:[NSMenuItem separatorItem]];
		
		// Add command to open the current page in the external browser
		newMenuItem = [NSMenuItem new];
		if (newMenuItem != nil)
		{
			newMenuItem.title = [NSString stringWithFormat:NSLocalizedString(@"Open Page in %@", nil), defaultBrowser];
			newMenuItem.target = self;
			newMenuItem.action = @selector(openPageInBrowser:);
			newMenuItem.tag = WebMenuItemTagOther;
			[newDefaultMenu addObject:newMenuItem];
		}
		
		// Add command to copy the URL of the current page to the clipboard
		newMenuItem = [NSMenuItem new];
		if (newMenuItem != nil)
		{
			[newMenuItem setTitle:NSLocalizedString(@"Copy Page Link to Clipboard", nil)];
			newMenuItem.target = self;
			newMenuItem.action = @selector(copyPageURLToClipboard:);
			newMenuItem.tag = WebMenuItemTagOther;
			[newDefaultMenu addObject:newMenuItem];
		}
	}
	
	return [newDefaultMenu copy];
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
	
	// Launch in the foreground or background as needed
	NSWorkspaceLaunchOptions lOptions = openLinksInBackground ? (NSWorkspaceLaunchWithoutActivation | NSWorkspaceLaunchDefault) : (NSWorkspaceLaunchDefault | NSWorkspaceLaunchDefault);
	[[NSWorkspace sharedWorkspace] openURLs:urlArray
					withAppBundleIdentifier:NULL
									options:lOptions
			 additionalEventParamDescriptor:NULL
						  launchIdentifiers:NULL];
}

/* openURLInDefaultBrowser
 * Open the specified URL in whatever the user has registered as their
 * default system browser.
 */
-(void)openURLInDefaultBrowser:(NSURL *)url
{
	[self openURLsInDefaultBrowser:@[url]];
    
}

/* openPageInBrowser
 * Open the current web page in the browser.
 */
-(IBAction)openPageInBrowser:(id)sender
{
	NSView<BaseView> * theView = self.browserView.activeTabItemView;
	NSURL * url = nil;
	
	// Get the URL from the appropriate view.
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		BrowserPane * webPane = (BrowserPane *)theView;
		url = webPane.url;
	}
	else if ([theView isKindOfClass:[ArticleListView class]])
	{
		ArticleListView * articleListView = (ArticleListView *)theView;
		url = articleListView.url;
	}

	// If we have an URL then open it in the default browser.
	if (url != nil)
		[self openURLInDefaultBrowser:url];
}

/* copyPageURLToClipboard
 * Copy the URL of the current web page to the clipboard.
 */
-(IBAction)copyPageURLToClipboard:(id)sender
{
	NSView<BaseView> * theView = self.browserView.activeTabItemView;
	NSURL * url = nil;

	// Get the URL from the appropriate view.
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		BrowserPane * webPane = (BrowserPane *)theView;
		url = webPane.url;
	}
	else if ([theView isKindOfClass:[ArticleListView class]])
	{
		ArticleListView * articleListView = (ArticleListView *)theView;
		url = articleListView.url;
	}

	// If we have an URL then copy it to the clipboard.
	if (url != nil)
	{
		NSPasteboard * pboard = [NSPasteboard generalPasteboard];
		[pboard declareTypes:@[NSStringPboardType, NSURLPboardType] owner:self];
		[url writeToPasteboard:pboard];
		[pboard setString:url.description forType:NSStringPboardType];
	}
}

/* openWebElementInNewTab
 * Open the specified element in a new tab
 */
-(IBAction)openWebElementInNewTab:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]])
	{
		NSMenuItem * item = (NSMenuItem *)sender;
		Preferences * prefs = [Preferences standardPreferences];
		
		BOOL openInBackground = prefs.openLinksInBackground;
        if ([NSEvent modifierFlags] & NSEventModifierFlagShift) {
			openInBackground = !openInBackground;
        }
		
		[self.browserView createAndLoadNewTab:item.representedObject inBackground:openInBackground];
	}
}

-(void)newTab:(id)sender
{
	[self.browserView newTab];
}

/* openWebElementInDefaultBrowser
 * Open the specified element in an external browser
 */
-(IBAction)openWebElementInDefaultBrowser:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]])
	{
		NSMenuItem * item = (NSMenuItem *)sender;
		[self openURLInDefaultBrowser:item.representedObject];
	}
}

/* openWebLocation
 * Puts the focus in the address bar of the web browser tab. If one isn't open,
 * we create an empty one.
 */
-(IBAction)openWebLocation:(id)sender
{
	NSView<BaseView> * theView = self.browserView.activeTabItemView;
	[self showMainWindow:self];
	if (![theView isKindOfClass:[BrowserPane class]])
	{
		[self.browserView createNewTab:nil inBackground:NO];
		theView = self.browserView.activeTabItemView;
	}
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		BrowserPane * browserPane = (BrowserPane *)theView;
		[browserPane activateAddressBar];
	}
}

/* openURLFromString
 * Open a URL in either the internal Vienna browser or an external browser depending on
 * whatever the user has opted for.
 */
-(void)openURLFromString:(NSString *)urlString inPreferredBrowser:(BOOL)openInPreferredBrowserFlag
{
	NSURL * theURL = [NSURL URLWithString:urlString];
	if (theURL == nil)
	{
		theURL = cleanedUpAndEscapedUrlFromString(urlString);
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
	if (!openInPreferredBrowserFlag)
		openURLInVienna = (!openURLInVienna);
	if (openURLInVienna)
	{
		BOOL openInBackground = prefs.openLinksInBackground;
        if ([NSEvent modifierFlags] & NSEventModifierFlagShift) {
            openInBackground = !openInBackground;
        }

		for (NSURL * url in urls)
			[self.browserView createAndLoadNewTab:url inBackground:openInBackground];
	}
	else
		[self openURLsInDefaultBrowser:urls];
}

/* openURL
 * Open a URL in either the internal Vienna browser or an external browser depending on
 * whatever the user has opted for.
 */
-(void)openURL:(NSURL *)url inPreferredBrowser:(BOOL)openInPreferredBrowserFlag
{
	if (url == nil)
	{
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
	for (Article * currentArticle in self.articleController.markedArticleRange)
	{
		if (currentArticle.hasEnclosure)
		{
			[[DownloadManager sharedInstance] downloadFileFromURL:currentArticle.enclosure];
		}
	}
}

/* openVienna
 * Calls into showMainWindow but activates the app first.
 */
-(IBAction)openVienna:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[self showMainWindow:sender];
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
    panel.allowedFileTypes = @[@"opml"];
    [panel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger returnCode) {
        if (returnCode == NSFileHandlingPanelOKButton)
        {
            [panel orderOut:self];
            
            NSInteger countExported = [Export exportToFile:panel.URL.path
                                           fromFoldersTree:self.foldersTree
                                                 selection:accessoryController.mode == ExportModeSelectedFeeds
                                                withGroups:accessoryController.preserveFolders];
            
            if (countExported < 0)
            {
                NSAlert *alert = [NSAlert new];
                alert.messageText = NSLocalizedString(@"Cannot create export output file", nil);
                alert.informativeText = NSLocalizedString(@"The specified export output file could not be created. Check that it is not locked and no other application is using it.", nil);
                [alert beginSheetModalForWindow:self.mainWindow completionHandler:nil];
            }
            else
            {
                // Announce how many we successfully imported
                NSAlert *alert = [NSAlert new];
                alert.alertStyle = NSAlertStyleInformational;
                alert.messageText = NSLocalizedString(@"Export Completed", nil);
                alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"%d subscriptions successfully exported", nil), countExported];
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
                      
                      if (returnCode == NSFileHandlingPanelOKButton)
                      {
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
	if (appleScript == nil)
	{
		NSString * baseScriptName = scriptName.lastPathComponent.stringByDeletingPathExtension;
		runOKAlertPanel([NSString stringWithFormat:NSLocalizedString(@"Error loading script '%@'", nil), baseScriptName],
						[errorDictionary valueForKey:NSAppleScriptErrorMessage]);
	}
	else
	{
		NSAppleEventDescriptor * resultEvent = [appleScript executeAndReturnError:&errorDictionary];
		if (resultEvent == nil)
		{
			NSString * baseScriptName = scriptName.lastPathComponent.stringByDeletingPathExtension;
			runOKAlertPanel([NSString stringWithFormat:NSLocalizedString(@"AppleScript Error in '%@' script", nil), baseScriptName],
							[errorDictionary valueForKey:NSAppleScriptErrorMessage]);
		}
	}
}

#pragma mark Filter Bar

/* isFilterBarVisible
 * Simple function that returns whether or not the filter bar is visible.
 */
-(BOOL)isFilterBarVisible
{
    return self.filterDisclosureView.isDisclosed;
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{
    if (self.mainWindow.keyWindow) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"Open Reader Authentication Failed",nil);
        alert.informativeText = NSLocalizedString(@"Make sure the username and password needed to access the Open Reader server are correctly set in Vienna's preferences.\nAlso check your network access.",nil);
        [alert beginSheetModalForWindow:self.mainWindow completionHandler:nil];
    }
}

/* handleShowFilterBar
 * Respond to the filter bar being shown or hidden programmatically.
 */
-(void)handleShowFilterBar:(NSNotification *)nc
{
	if (self.browserView.activeTabItemView == [self.browserView primaryTabItemView])
		[self setFilterBarState:[Preferences standardPreferences].showFilterBar withAnimation:YES];
}

/* showHideFilterBar
 * Toggle the filter bar on/off.
 */
-(IBAction)showHideFilterBar:(id)sender
{
	[self setPersistedFilterBarState:!self.filterBarVisible withAnimation:YES];
}

/* hideFilterBar
 * Removes the filter bar from the current article view.
 */
-(IBAction)hideFilterBar:(id)sender
{
	[self setPersistedFilterBarState:NO withAnimation:YES];
}

/* setPersistedFilterBarState
 * Calls setFilterBarState but also persists the new state to the preferences.
 */
-(void)setPersistedFilterBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate
{
	[self setFilterBarState:isVisible withAnimation:doAnimate];
	[Preferences standardPreferences].showFilterBar = isVisible;
}

/* setFilterBarState
 * Show or hide the filter bar. The withAnimation flag specifies whether or not we do the
 * animated show/hide. It should be set to NO for actions that are not user initiated as
 * otherwise the background rendering of the control can cause complications.
 */
-(void)setFilterBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate
{
	if (isVisible && !self.filterBarVisible)
	{
        [self.filterDisclosureView disclose:doAnimate];

		// Hook up the Tab ordering so Tab from the search field goes to the
		// article view.
		self.foldersTree.mainView.nextKeyView = self.filterSearchField;
		self.filterSearchField.nextKeyView = [self.browserView primaryTabItemView].mainView;
		
		// Set focus only if this was user initiated
        if (doAnimate) {
			[self.mainWindow makeFirstResponder:self.filterSearchField];
        }
	}
	if (!isVisible && self.filterBarVisible)
	{
        [self.filterDisclosureView collapse:doAnimate];

		// Fix up the tab ordering
		self.foldersTree.mainView.nextKeyView = [self.browserView primaryTabItemView].mainView;
		
		// Clear the filter, otherwise we end up with no way remove it!
		self.filterString = @"";
		if (doAnimate)
		{
			[self searchUsingFilterField:self];
			
			// If the focus was originally on the filter bar then we should
			// move it to the message list
			if (self.mainWindow.firstResponder == self.mainWindow)
				[self.mainWindow makeFirstResponder:[self.browserView primaryTabItemView].mainView];
		}
	}
}

/* initSortMenu
 * Create the sort popup menu.
 */
-(void)initSortMenu
{
	NSMenu * sortSubmenu = [NSMenu new];
	
	// Add the fields which are sortable to the menu.
	for (Field * field in [db arrayOfFields])
	{
		// Filter out columns we don't sort on. Later we should have an attribute in the
		// field object itself based on which columns we can sort on.
		if (field.tag != ArticleFieldIDParent &&
			field.tag != ArticleFieldIDGUID &&
			field.tag != ArticleFieldIDComments &&
			field.tag != ArticleFieldIDDeleted &&
			field.tag != ArticleFieldIDHeadlines &&
			field.tag != ArticleFieldIDSummary &&
			field.tag != ArticleFieldIDLink &&
			field.tag != ArticleFieldIDText &&
			field.tag != ArticleFieldIDEnclosureDownloaded &&
			field.tag != ArticleFieldIDEnclosure)
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
	
	for (Field * field in [db arrayOfFields])
	{
		// Filter out columns we don't view in the article list. Later we should have an attribute in the
		// field object based on which columns are visible in the tableview.
		if (field.tag != ArticleFieldIDText && 
			field.tag != ArticleFieldIDGUID &&
			field.tag != ArticleFieldIDComments &&
			field.tag != ArticleFieldIDDeleted &&
			field.tag != ArticleFieldIDParent &&
			field.tag != ArticleFieldIDHeadlines &&
			field.tag != ArticleFieldIDEnclosureDownloaded)
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
                       context:(void *)context {
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
	path = [Preferences standardPreferences].scriptsFolder;
	loadMapFromPath(path, scriptPathMappings, NO, exts);
	
	// Add the contents of the scriptsPathMappings dictionary keys to the menu sorted
	// by key name.
	NSArray * sortedMenuItems = [scriptPathMappings.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSInteger count = sortedMenuItems.count;

	// Insert the Scripts menu to the left of the Help menu only if
	// we actually have any scripts.
	if (count > 0) {
		NSMenu * scriptsMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@""];
		
		NSInteger index;
		for (index = 0; index < count; ++index)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:sortedMenuItems[index]
															   action:@selector(doSelectScript:)
														keyEquivalent:@""];
			[scriptsMenu addItem:menuItem];
		}
		
		[scriptsMenu addItem:[NSMenuItem separatorItem]];
		NSMenuItem * menuItem;
		
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Scripts Folder", nil) action:@selector(doOpenScriptsFolder:) keyEquivalent:@""];
		[scriptsMenu addItem:menuItem];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"More Scripts…", nil) action:@selector(moreScripts:) keyEquivalent:@""];
		[scriptsMenu addItem:menuItem];
		
		// If this is the first call to initScriptsMenu, create the scripts menu. Otherwise we just
		// update the one we have.
		if (scriptsMenuItem != nil)
		{
			[NSApp.mainMenu removeItem:scriptsMenuItem];
		}
		
		scriptsMenuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"" action:NULL keyEquivalent:@""];
		scriptsMenuItem.image = [NSImage imageNamed:@"ScriptsTemplate"];
		
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
	NSArray *styles = [ArticleView loadStylesMap].allKeys;
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
	if (([Preferences standardPreferences].newArticlesNotification
		& MA_NewArticlesNotification_Badge) == 0)
	{
		// Remove the badge if there was one.
		[NSApp.dockTile setBadgeLabel:nil];
	}
	else
	{
		lastCountOfUnread = -1;	// Force an update
		[self showUnreadCountOnApplicationIconAndWindowTitle];
	}
}

/* showUnreadCountOnApplicationIconAndWindowTitle
 * Update the Vienna application icon to show the number of unread articles.
 */
-(void)showUnreadCountOnApplicationIconAndWindowTitle
{
	@synchronized(NSApp.dockTile) {
	NSInteger currentCountOfUnread = db.countOfUnread;
	if (currentCountOfUnread == lastCountOfUnread)
		return;
	lastCountOfUnread = currentCountOfUnread;
	
	// Always update the app status icon first
	[self setAppStatusBarIcon];
	
	// Don't show a count if there are no unread articles
	if (currentCountOfUnread <= 0)
	{
		[NSApp.dockTile setBadgeLabel:nil];
		self.mainWindow.title = self.appName;
		return;	
	}	
	
	self.mainWindow.title = [NSString stringWithFormat:@"%@ (%li %@)", self.appName, (long)currentCountOfUnread, NSLocalizedString(@"Unread", nil)];
	
	// Exit now if we're not showing the unread count on the application icon
	if (([Preferences standardPreferences].newArticlesNotification
		& MA_NewArticlesNotification_Badge) ==0)
			return;
	
	NSString * countdown = [NSString stringWithFormat:@"%li", (long)currentCountOfUnread];
	NSApp.dockTile.badgeLabel = countdown;

	} // @synchronized
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
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Title of a button on an alert")];
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
	[self.browserView.activeTabItemView printDocument:sender];
}

/* folders
 * Return the array of folders.
 */
-(NSArray *)folders
{
	return [db arrayOfAllFolders];
}

/* appName
 * Returns's the application friendly (localized) name.
 */
-(NSString *)appName
{
	return [NSBundle mainBundle].infoDictionary[@"CFBundleName"];
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
	if (self.browserView.countOfTabs < 2 || !self.mainWindow.keyWindow)
	{
		closeTabItem.keyEquivalent = @"";
		closeAllTabsItem.keyEquivalent = @"";
		closeWindowItem.keyEquivalent = @"w";
		closeWindowItem.keyEquivalentModifierMask = NSCommandKeyMask;
	}
	else
	{
		closeTabItem.keyEquivalent = @"w";
		closeTabItem.keyEquivalentModifierMask = NSCommandKeyMask;
		closeAllTabsItem.keyEquivalent = @"w";
		closeAllTabsItem.keyEquivalentModifierMask = NSCommandKeyMask|NSAlternateKeyMask;
		closeWindowItem.keyEquivalent = @"W";
		closeWindowItem.keyEquivalentModifierMask = NSCommandKeyMask;
	}
}

/* showAppInStatusBar
 * Add or remove the app icon from the system status bar.
 */
-(void)showAppInStatusBar
{
	Preferences * prefs = [Preferences standardPreferences];
	if (prefs.showAppInStatusBar && appStatusItem == nil)
	{
		appStatusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		[self setAppStatusBarIcon];
		[appStatusItem setHighlightMode:YES];
		
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
        [statusBarMenu addItemWithTitle:NSLocalizedString(@"Quit Vienna", @"Title of a menu item")
                                 action:@selector(terminate:)
                          keyEquivalent:@""];
		appStatusItem.menu = statusBarMenu;
	}
	else if (!prefs.showAppInStatusBar && appStatusItem != nil)
	{
		[[NSStatusBar systemStatusBar] removeStatusItem:appStatusItem];
		appStatusItem = nil;
	}
}

/* setAppStatusBarIcon
 * Set the appropriate application status bar icon depending on whether or not we have
 * any unread messages.
 */
-(void)setAppStatusBarIcon
{
	if (appStatusItem != nil)
	{
		if (lastCountOfUnread == 0)
		{
            NSImage *statusBarImage = [NSImage imageNamed:@"statusBarIcon"];
            [statusBarImage setTemplate:YES];
            appStatusItem.image = statusBarImage;
			[appStatusItem setTitle:nil];
		}
		else
		{
            NSImage *statusBarImage = [NSImage imageNamed:@"statusBarIconUnread"];
            [statusBarImage setTemplate:YES];
            appStatusItem.image = statusBarImage;
			appStatusItem.title = [NSString stringWithFormat:@"%ld", (long)lastCountOfUnread];
			// Yosemite hack : need to insist for displaying correctly icon and text
            appStatusItem.image = statusBarImage;
		}
	}
}

/* handleRSSLink
 * Handle feed://<rss> links. If we're already subscribed to the link then make the folder
 * active. Otherwise offer to subscribe to the link.
 */
-(void)handleRSSLink:(NSString *)linkPath
{
	[self createNewSubscription:linkPath underFolder:self.foldersTree.groupParentSelection afterChild:-1];
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
	if (folder.type == VNAFolderTypeRSS)
	{
		[self.rssFeed editSubscription:self.mainWindow folderId:folder.itemId];
	}
	else if (folder.type == VNAFolderTypeSmart)
	{
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
	NSInteger newFolderId = ((TreeNode *)nc.object).nodeId;
	
	// We don't filter when we switch folders.
	self.filterString = @"";
	
	// Call through the controller to display the new folder.
	[self.articleController displayFolder:newFolderId];
	[self updateSearchPlaceholderAndSearchMethod];
	
	// Make sure article viewer is active
	[self.browserView setActiveTabToPrimaryTab];

    // If the user selects the unread-articles smart folder, then clear the
    // relevant user notifications.
    if (newFolderId == [db folderFromName:NSLocalizedString(@"Unread Articles", nil)].itemId) {
        NSUserNotificationCenter *center = NSUserNotificationCenter.defaultUserNotificationCenter;
        [center.deliveredNotifications enumerateObjectsUsingBlock:^(NSUserNotification * notification, NSUInteger idx, BOOL *stop) {
            if ([notification.userInfo[UserNotificationContextKey] isEqualToString:UserNotificationContextFetchCompleted]) {
                [center removeDeliveredNotification:notification];
            }
        }];
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
	[self.articleController updateAlternateMenuTitle];
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

/* handleCheckFrequencyChange
 * Called when the refresh frequency is changed.
 */
-(void)handleCheckFrequencyChange:(NSNotification *)nc
{
	NSInteger newFrequency = [Preferences standardPreferences].refreshFrequency;
	
	[checkTimer invalidate];
	checkTimer = nil;
	if (newFrequency > 0)
	{
		checkTimer = [NSTimer scheduledTimerWithTimeInterval:newFrequency
													   target:self
													 selector:@selector(refreshOnTimer:)
													 userInfo:nil
													  repeats:NO];
	}
}

/* checkTimer
 * Return the refresh timer object.
 */
-(NSTimer *)checkTimer
{
	return checkTimer;
}

/* doViewColumn
 * Toggle whether or not a specified column is visible.
 */
-(IBAction)doViewColumn:(id)sender;
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
	
	NSAssert1(ascendingNumber, @"Somehow got a nil representedObject for Sort direction sub-menu item '%@'", [menuItem title]);
	BOOL ascending = ascendingNumber.boolValue;
	[self.articleController sortAscending:ascending];
}

/* doOpenScriptsFolder
 * Open the standard Vienna scripts folder.
 */
-(IBAction)doOpenScriptsFolder:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:[Preferences standardPreferences].scriptsFolder];
}

/* doSelectScript
 * Run a script selected from the Script menu.
 */
-(IBAction)doSelectScript:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	NSString * scriptPath = [scriptPathMappings valueForKey:menuItem.title];
	if (scriptPath != nil)
		[self runAppleScript:scriptPath];
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
	NSView<BaseView> * newView = nc.object;
	if (newView == [self.browserView primaryTabItemView])
	{
		if (self.selectedArticle == nil)
			[self.mainWindow makeFirstResponder:self.foldersTree.mainView];
		else
			[self.mainWindow makeFirstResponder:[self.browserView primaryTabItemView].mainView];
	}
	else
	{
		BrowserPane * webPane = (BrowserPane *)newView;
		[self.mainWindow makeFirstResponder:webPane.mainView];
	}
	[self updateStatusBarFilterButtonVisibility];
	[self updateSearchPlaceholderAndSearchMethod];
}

/* handleTabChange
 * Handle a change in the number of tabs.
 */
- (void)handleTabCountChange:(NSNotification *)nc
{
	[self updateCloseCommands];	
}

/* handleFolderNameChange
 * Handle folder name change.
 */
-(void)handleFolderNameChange:(NSNotification *)nc
{
	NSInteger folderId = ((NSNumber *)nc.object).integerValue;
	if (folderId == self.articleController.currentFolderId)
		[self updateSearchPlaceholderAndSearchMethod];
}

/* handleRefreshStatusChange
 * Handle a change of the refresh status.
 */
-(void)handleRefreshStatusChange:(NSNotification *)nc
{
	if (self.connecting)
	{
		// Save the date/time of this refresh so we do the right thing when
		// we apply the filter.
		[[Preferences standardPreferences] setObject:[NSDate date] forKey:MAPref_LastRefreshDate];
		
		// Toggle the refresh button
		NSToolbarItem *item = [self toolbarItemWithIdentifier:@"Refresh"];
		item.action = @selector(cancelAllRefreshesToolbar:);
        item.image = [NSImage imageNamed:@"CancelTemplate"];
	}
	else
	{
		// Run the auto-expire now
		Preferences * prefs = [Preferences standardPreferences];
		[db purgeArticlesOlderThanDays:prefs.autoExpireDuration];

		// Toggle the refresh button
		NSToolbarItem *item = [self toolbarItemWithIdentifier:@"Refresh"];
		item.action = @selector(refreshAllSubscriptions:);
        item.image = [NSImage imageNamed:@"SyncTemplate"];

		[self showUnreadCountOnApplicationIconAndWindowTitle];
		
		// Bounce the dock icon for 1 second if the bounce method has been selected.
		NSInteger newUnread = [RefreshManager sharedManager].countOfNewArticles + [OpenReader sharedManager].countOfNewArticles;
		if (newUnread > 0 && ((prefs.newArticlesNotification & MA_NewArticlesNotification_Bounce) != 0))
			[NSApp requestUserAttention:NSInformationalRequest];

        // User notification
        if (newUnread > 0) {
            NSUserNotification *notification = [NSUserNotification new];
            notification.title = NSLocalizedString(@"New articles retrieved", @"Notification title");
            notification.informativeText = [NSString stringWithFormat:NSLocalizedString(@"%d new unread articles retrieved", @"Notification body"), newUnread];
            notification.userInfo = @{UserNotificationContextKey: UserNotificationContextFetchCompleted};
            notification.soundName = NSUserNotificationDefaultSoundName;

            // Set a unique identifier to assure that this notifications cannot
            // appear more than once.
            notification.identifier = UserNotificationContextFetchCompleted;

            // Remove the previous notification, if present, before sending a
            // new one. This will assure that the user can receive an alert and
            // and can see the updated notification in Notification Center.
            NSUserNotificationCenter *center = NSUserNotificationCenter.defaultUserNotificationCenter;
            [center removeDeliveredNotification:notification];
            [center deliverNotification:notification];
        }
	}
}

/* moreStyles
 * Display the web page where the user can download additional styles.
 */
-(IBAction)moreStyles:(id)sender
{
	NSString * stylesPage = [standardURLs valueForKey:@"ViennaMoreStylesPage"];
	if (stylesPage != nil)
		[self openURLInDefaultBrowser:[NSURL URLWithString:stylesPage]];
}

/* moreScripts
 * Display the web page where the user can download additional scripts.
 */
-(IBAction)moreScripts:(id)sender
{
	NSString * scriptsPage = [standardURLs valueForKey:@"ViennaMoreScriptsPage"];
	if (scriptsPage != nil)
		[self openURLInDefaultBrowser:[NSURL URLWithString:scriptsPage]];
}

/* viewArticlePages inPreferredBrowser
 * Display the selected articles in a browser.
 */
-(void)viewArticlePages:(id)sender inPreferredBrowser:(BOOL)usePreferredBrowser
{
	NSArray * articleArray = self.articleController.markedArticleRange;
	Article * currentArticle;
	
	if (articleArray.count > 0) 
	{
		
        NSMutableArray * articlesWithLinks = [NSMutableArray arrayWithCapacity:articleArray.count];
        NSMutableArray * urls = [NSMutableArray arrayWithCapacity:articleArray.count];
		
		for (currentArticle in articleArray)
		{
			if (currentArticle && !currentArticle.link.blank)
            {
                [articlesWithLinks addObject:currentArticle];
                NSURL * theURL = [NSURL URLWithString:currentArticle.link];
                if (theURL == nil)
                {
					theURL = cleanedUpAndEscapedUrlFromString(currentArticle.link);
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
 * In article view, forward track through the list of articles displayed. In 
 * web view, go to the next web page.
 */
-(IBAction)goForward:(id)sender
{
	[self.browserView.activeTabItemView handleGoForward:sender];
}

/* goBack
 * In article view, back track through the list of articles displayed. In 
 * web view, go to the previous web page.
 */
-(IBAction)goBack:(id)sender
{
	[self.browserView.activeTabItemView handleGoBack:sender];
}

/* localPerformFindPanelAction
 * The default handler for the Find actions is the first responder. Unfortunately the
 * WebView, although it claims to implement this, doesn't. So we redirect the Find
 * commands here and trap the case where the webview has first responder status and
 * handle it especially. For other first responders, we pass this command through.
 */
-(IBAction)localPerformFindPanelAction:(id)sender
{
	switch ([sender tag]) 
	{
		case NSFindPanelActionSetFindString:
			[self setFocusToSearchField:self];
			self.toolbarSearchField.stringValue = APP.currentTextSelection;
			[searchPanel setSearchString:APP.currentTextSelection];
			break;
			
		case NSFindPanelActionShowFindPanel:
			[self setFocusToSearchField:self];
			break;
			
		default:
			[self.browserView.activeTabItemView performFindPanelAction:[sender tag]];
			break;
	}
}

#pragma mark Key Listener

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger)flags
{
	if (keyChar >= '0' && keyChar <= '9' && (flags & NSControlKeyMask))
	{
		NSInteger layoutStyle = MA_Layout_Report + (keyChar - '0');
		[self setLayout:layoutStyle withRefresh:YES];
		return YES;
	}
	switch (keyChar)
	{
		case NSLeftArrowFunctionKey:
			if (flags & (NSCommandKeyMask | NSAlternateKeyMask))
				return NO;
			else
			{
				if (self.mainWindow.firstResponder == [self.browserView primaryTabItemView].mainView)
				{
					[self.mainWindow makeFirstResponder:self.foldersTree.mainView];
					return YES;
				}
			}
			return NO;
			
		case NSRightArrowFunctionKey:
			if (flags & (NSCommandKeyMask | NSAlternateKeyMask))
				return NO;
			else
			{
				if (self.mainWindow.firstResponder == self.foldersTree.mainView)
				{
					[self.browserView setActiveTabToPrimaryTab];
					if (self.selectedArticle == nil)
					{
						[self.articleController ensureSelectedArticle];
					}
					[self.mainWindow makeFirstResponder:(self.selectedArticle != nil) ? [self.browserView primaryTabItemView].mainView : self.foldersTree.mainView];
					return YES;
				}
			}
			return NO;
			
		case NSDeleteFunctionKey:
		case NSDeleteCharacter:
			if (self.mainWindow.firstResponder == self.foldersTree.mainView)
			{
				[self deleteFolder:self];
				return YES;
			}
			else if (self.mainWindow.firstResponder == (self.articleController.mainArticleView).mainView)
			{
				[self deleteMessage:self];
				return YES;
			}
			return NO;
			
		case 'h':
		case 'H':
			[self setFocusToSearchField:self];
			return YES;
			
		case 'f':
		case 'F':
			if (!self.filterBarVisible)
				[self setPersistedFilterBarState:YES withAnimation:YES];
			else
				[self.mainWindow makeFirstResponder:self.filterSearchField];
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
			if (self.mainWindow.firstResponder == self.foldersTree.mainView)
			{
				if (flags & NSAlternateKeyMask)
					[self viewSourceHomePageInAlternateBrowser:self];
				else
					[self viewSourceHomePage:self];
				return YES;
			}
			else
			{
				if (flags & NSAlternateKeyMask)
					[self viewArticlePagesInAlternateBrowser:self];
				else
					[self viewArticlePages:self];
				return YES;
			}
			return NO;
			
		case ' ': //SPACE
		{
			WebView * view = self.browserView.activeTabItemView.webView;
			NSView * theView = view.mainFrame.frameView.documentView;
			
			if (theView == nil)
				[self viewNextUnread:self];
			else
			{
				NSRect visibleRect = theView.visibleRect;
				if (flags & NSShiftKeyMask)
				{
					if (visibleRect.origin.y < 2)
						[self goBack:self];
					else
						[view scrollPageUp:self];
				}
				else
				{
					if (visibleRect.origin.y + visibleRect.size.height >= theView.frame.size.height - 2)
						[self viewNextUnread:self];
					else
						[view scrollPageDown:self];
				}
			}
			return YES;
		}
	}
	return NO;
}

/* toolbarItemWithIdentifier
 * Returns the toolbar button that corresponds to the specified identifier.
 */
-(NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)theIdentifier
{
	for (NSToolbarItem * theItem in self.mainWindow.toolbar.visibleItems)
	{
		if ([theItem.itemIdentifier isEqualToString:theIdentifier])
			return theItem;
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

/* refreshOnTimer
 * Each time the check timer fires, we see if a connect is not nswindow
 * running and then kick one off.
 */
-(void)refreshOnTimer:(NSTimer *)aTimer
{
	[self refreshAllSubscriptions:self];
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

/* createNewGoogleReaderSubscription
 * Create a new Open Reader subscription for the specified URL under the given parent folder.
 */

-(void)createNewGoogleReaderSubscription:(NSString *)url underFolder:(NSInteger)parentId withTitle:(NSString*)title afterChild:(NSInteger)predecessorId
{
	NSLog(@"Adding Open Reader Feed: %@ with Title: %@",url,title);
	// Replace feed:// with http:// if necessary
	if ([url hasPrefix:@"feed://"])
		url = [NSString stringWithFormat:@"http://%@", [url substringFromIndex:7]];
	
	// If the folder already exists, just select it.
	Folder * folder = [db folderFromFeedURL:url];
	if (folder != nil)
	{
		//[self.browserView setActiveTabToPrimaryTab];
		//[self.foldersTree selectFolder:[folder itemId]];
		return;
	}
	
	// Create then select the new folder.
	NSInteger folderId = [db addGoogleReaderFolder:title
                                       underParent:parentId
                                        afterChild:predecessorId
                                   subscriptionURL:url];
		
	if (folderId != -1)
	{
		//		[self.foldersTree selectFolder:folderId];
		//		if (isAccessible(url))
		//{
			Folder * folder = [db folderFromID:folderId];
			[[RefreshManager sharedManager] refreshSubscriptionsAfterSubscribe:@[folder] ignoringSubscriptionStatus:NO];
		//}
	}
}

/* createNewSubscription
 * Create a new subscription for the specified URL under the given parent folder.
 */
-(void)createNewSubscription:(NSString *)urlString underFolder:(NSInteger)parentId afterChild:(NSInteger)predecessorId
{
	// Replace feed:// with http:// if necessary
	if ([urlString hasPrefix:@"feed://"])
		urlString = [NSString stringWithFormat:@"http://%@", [urlString substringFromIndex:7]];

	urlString = cleanedUpAndEscapedUrlFromString(urlString).absoluteString;
	
	// If the folder already exists, just select it.
	Folder * folder = [db folderFromFeedURL:urlString];
	if (folder != nil)
	{
		[self.browserView setActiveTabToPrimaryTab];
		[self.foldersTree selectFolder:folder.itemId];
		return;
	}
	
	// Create the new folder.
	if ([Preferences standardPreferences].syncGoogleReader && [Preferences standardPreferences].prefersGoogleNewSubscription)
	{	//creates in Google
		OpenReader * myGoogle = [OpenReader sharedManager];
		[myGoogle subscribeToFeed:urlString];
		NSString * folderName = [db folderFromID:parentId].name;
		if (folderName != nil)
			[myGoogle setFolderName:folderName forFeed:urlString set:TRUE];
		[myGoogle loadSubscriptions];

	}
	else
	{ //creates locally
		NSInteger folderId = [db addRSSFolder:[Database untitledFeedFolderName]
                                  underParent:parentId
                                   afterChild:predecessorId
                              subscriptionURL:urlString];

		if (folderId != -1)
		{
            if (isAccessible(urlString) || [urlString hasPrefix:@"file"])
            {
                Folder * folder = [db folderFromID:folderId];
                [[RefreshManager sharedManager] refreshSubscriptionsAfterSubscribe:@[folder] ignoringSubscriptionStatus:NO];
            }
		}
	}
}

/* newSubscription
 * Display the pane for a new RSS subscription.
 */
-(IBAction)newSubscription:(id)sender
{
	[self.rssFeed newSubscription:self.mainWindow underParent:self.foldersTree.groupParentSelection initialURL:nil];
}

/* newSmartFolder
 * Create a new smart folder.
 */
-(IBAction)newSmartFolder:(id)sender
{
	if (!smartFolder)
		smartFolder = [[SmartFolder alloc] initWithDatabase:db];
	[smartFolder newCriteria:self.mainWindow underParent:self.foldersTree.groupParentSelection];
}

/* newGroupFolder
 * Display the pane for a new group folder.
 */
-(IBAction)newGroupFolder:(id)sender
{
	if (!groupFolder)
		groupFolder = [[NewGroupFolder alloc] init];
	[groupFolder newGroupFolder:self.mainWindow underParent:self.foldersTree.groupParentSelection];
}

/* restoreMessage
 * Restore a message in the Trash folder back to where it came from.
 */
-(IBAction)restoreMessage:(id)sender
{
	Folder * folder = [db folderFromID:self.articleController.currentFolderId];
	if (folder.type == VNAFolderTypeTrash && self.selectedArticle != nil && !db.readOnly)
	{
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
	if (self.selectedArticle != nil && !db.readOnly)
	{
		Folder * folder = [db folderFromID:self.articleController.currentFolderId];
		if (folder.type != VNAFolderTypeTrash) {
			NSArray * articleArray = self.articleController.markedArticleRange;
			[self.articleController markDeletedByArray:articleArray deleteFlag:YES];
		} else {
            NSAlert *alert = [NSAlert new];
            alert.messageText = NSLocalizedString(@"Are you sure you want to permanently delete the selected articles?", nil);
            alert.informativeText = NSLocalizedString(@"This operation cannot be undone.", nil);
            [alert addButtonWithTitle:NSLocalizedString(@"Delete", @"Title of a button on an alert")];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Title of a button on an alert")];
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

/* showDownloadsWindow
 * Show the Downloads window, bringing it to the front if necessary.
 */
-(IBAction)showDownloadsWindow:(id)sender
{
	if (downloadWindow == nil)
		downloadWindow = [[DownloadWindow alloc] init];
	[downloadWindow.window makeKeyAndOrderFront:sender];
}

/* conditionalShowDownloadsWindow
 * Make the Downloads window visible only if it hasn't been shown.
 */
-(IBAction)conditionalShowDownloadsWindow:(id)sender
{
	if (downloadWindow == nil)
		downloadWindow = [[DownloadWindow alloc] init];
	if (!downloadWindow.window.visible)
		[downloadWindow.window makeKeyAndOrderFront:sender];
}

/* viewFirstUnread
 * Moves the selection to the first unread article.
 */
-(IBAction)viewFirstUnread:(id)sender
{
	[self.browserView setActiveTabToPrimaryTab];
	if (db.countOfUnread > 0)
	{
		[self.mainWindow makeFirstResponder:[self.browserView primaryTabItemView].mainView];
		[self.articleController displayFirstUnread];
	}
	else
	{
		[self.mainWindow makeFirstResponder:(self.selectedArticle != nil) ? [self.browserView primaryTabItemView].mainView : self.foldersTree.mainView];
	}
}

/* viewNextUnread
 * Moves the selection to the next unread article.
 */
-(IBAction)viewNextUnread:(id)sender
{
	[self.browserView setActiveTabToPrimaryTab];
	if (db.countOfUnread > 0)
	{
		[self.mainWindow makeFirstResponder:[self.browserView primaryTabItemView].mainView];
		[self.articleController displayNextUnread];
	}
	else
	{
		[self.mainWindow makeFirstResponder:(self.selectedArticle != nil) ? [self.browserView primaryTabItemView].mainView : self.foldersTree.mainView];
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
	if (!db.readOnly)
	{
		[self.articleController markAllFoldersReadByArray:self.foldersTree.selectedFolders];
		if (db.countOfUnread > 0)
		{
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
	if (!db.readOnly)
	{
		[self.articleController markAllFoldersReadByArray:[self.foldersTree folders:0]];
	}
}

/* markReadToggle
 * Toggle the read/unread state of the selected articles
 */
-(IBAction)markReadToggle:(id)sender
{
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !db.readOnly)
	{
		NSArray * articleArray = self.articleController.markedArticleRange;
		[self.articleController markReadByArray:articleArray readFlag:!theArticle.read];
	}
}

/* markRead
 * Mark read the selected articles
 */
-(IBAction)markRead:(id)sender
{
	Article * theArticle = self.selectedArticle;
	if (theArticle != nil && !db.readOnly)
	{
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
	if (theArticle != nil && !db.readOnly)
	{
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
	if (theArticle != nil && !db.readOnly)
	{
		NSArray * articleArray = self.articleController.markedArticleRange;
		[self.articleController markFlaggedByArray:articleArray flagged:!theArticle.flagged];
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
	
	if (count == 1)
	{
		Folder * folder = selectedFolders[0];
		if (folder.type == VNAFolderTypeSmart)
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete smart folder \"%@\"? This will not delete the actual articles matched by the search.", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete smart folder", nil);
		}
		else if (folder.type == VNAFolderTypeSearch)
			needPrompt = NO;
		else if (folder.type == VNAFolderTypeRSS)
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to unsubscribe from \"%@\"? This operation will delete all cached articles.", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete subscription", nil);
		}
		else if (folder.type == VNAFolderTypeOpenReader)
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Unsubscribing from an Open Reader RSS feed will also remove your locally cached articles.", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete Open Reader RSS feed", nil);
		}
		else if (folder.type == VNAFolderTypeGroup)
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete group folder \"%@\" and all sub folders? This operation cannot be undone.", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete group folder", nil);
		}
		else if (folder.type == VNAFolderTypeTrash)
			return;
		else
			NSAssert1(false, @"Unhandled folder type in deleteFolder: %@", [folder name]);
	}
	else
	{
		alertBody = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete all %d selected folders? This operation cannot be undone.", nil), count];
		alertTitle = NSLocalizedString(@"Delete multiple folders", nil);
	}
	
	// Get confirmation first
	if (needPrompt)
	{
        NSAlert *alert = [NSAlert new];
        alert.messageText = alertTitle;
        alert.informativeText = alertBody;
        [alert addButtonWithTitle:NSLocalizedString(@"Delete", @"Title of a button on an alert")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Title of a button on an alert")];
        NSModalResponse alertResponse = [alert runModal];

		if (alertResponse == NSAlertSecondButtonReturn)
			return;
	}
	

	if (smartFolder != nil)
		[smartFolder doCancel:nil];
	if ([(NSControl *)self.foldersTree.mainView abortEditing])
		[self.mainWindow makeFirstResponder:self.foldersTree.mainView];
	
	
	// Clear undo stack for this action
	[self clearUndoStack];
	
	// Prompt for each folder for now
	for (index = 0; index < count; ++index)
	{
		Folder * folder = selectedFolders[index];
		
		// This little hack is so if we're deleting the folder currently being displayed
		// and there's more than one folder being deleted, we delete the folder currently
		// being displayed last so that the MA_Notify_FolderDeleted handlers that only
		// refresh the display if the current folder is being deleted only trips once.
		if (folder.itemId == self.articleController.currentFolderId && index < count - 1)
		{
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
				[[OpenReader sharedManager] unsubscribeFromFeed:folder.feedURL];
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
	
	for (index = 0; index < count; ++index)
	{
		Folder * folder = selectedFolders[index];
        
        if (folder.isUnsubscribed) {
            // Currently unsubscribed, so re-subscribe locally
            [[Database sharedManager] clearFlag:VNAFolderFlagUnsubscribed forFolder:folder.itemId];
        } else {
            // Currently subscribed, so unsubscribe locally
            [[Database sharedManager] setFlag:VNAFolderFlagUnsubscribed forFolder:folder.itemId];
        }

		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
                                                            object:@(folder.itemId)];
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
	
	for (index = 0; index < count; ++index)
	{
		Folder * folder = selectedFolders[index];
		NSInteger folderID = folder.itemId;
		
		if (loadFullHTMLPages)
		{
			[folder setFlag:VNAFolderFlagLoadFullHTML];
            [[Database sharedManager] setFlag:VNAFolderFlagLoadFullHTML forFolder:folderID];
		}
		else
		{
			[folder clearFlag:VNAFolderFlagLoadFullHTML];
            [[Database sharedManager] clearFlag:VNAFolderFlagLoadFullHTML forFolder:folderID];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_LoadFullHTMLChange" object:@(folderID)];
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
	if (thisArticle || folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader)
		[self openURLFromString:folder.homePage inPreferredBrowser:YES];
}

/* viewSourceHomePageInAlternateBrowser
 * Display the web site associated with this feed, if there is one, in non-preferred browser.
 */
-(IBAction)viewSourceHomePageInAlternateBrowser:(id)sender
{
	Article * thisArticle = self.selectedArticle;
	Folder * folder = (thisArticle) ? [db folderFromID:thisArticle.folderId] : [db folderFromID:self.foldersTree.actualSelection];
	if (thisArticle || folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader)
		[self openURLFromString:folder.homePage inPreferredBrowser:NO];
}

/* showViennaHomePage
 * Open the Vienna home page in the default browser.
 */
-(IBAction)showViennaHomePage:(id)sender
{
	NSString * homePage = [standardURLs valueForKey:@"ViennaHomePage"];
	if (homePage != nil)
		[self openURLInDefaultBrowser:[NSURL URLWithString:homePage]];
}

#pragma mark Tabs

/* articlesTab
 * Go straight back to the articles tab
 */
-(void)viewArticlesTab:(id)sender
{
	[self.browserView showArticlesTab];
}

/* previousTab
 * Display the previous tab, if there is one.
 */
-(IBAction)previousTab:(id)sender
{
	[self.browserView showPreviousTab];
}

/* nextTab
 * Display the next tab, if there is one.
 */
-(IBAction)nextTab:(id)sender
{
	[self.browserView showNextTab];
}

/* closeAllTabs
 * Closes all tab windows.
 */
-(IBAction)closeAllTabs:(id)sender
{
	[self.browserView closeAllTabs];
}

/* closeTab
 * Close the active tab unless it's the primary view.
 */
-(IBAction)closeTab:(id)sender
{
	[self.browserView closeTabItemView:self.browserView.activeTabItemView];
}

/* reloadPage
 * Reload the web page.
 */
-(IBAction)reloadPage:(id)sender
{
	NSView<BaseView> * theView = self.browserView.activeTabItemView;
	if ([theView isKindOfClass:[BrowserPane class]])
		[theView performSelector:@selector(handleReload:)];
}

/* stopReloadingPage
 * Cancel current reloading of a web page.
 */
-(IBAction)stopReloadingPage:(id)sender
{
	NSView<BaseView> * theView = self.browserView.activeTabItemView;
	if ([theView isKindOfClass:[BrowserPane class]])
		[theView performSelector:@selector(handleStopLoading:)];
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
	if (prefs.openLinksInVienna)
	{
		alternateLocation = getDefaultBrowser();
		if (alternateLocation == nil)
			alternateLocation = NSLocalizedString(@"External Browser", nil);
	}
	else
		alternateLocation = self.appName;
	NSMenuItem * item = menuItemWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	if (item != nil)
	{
		item.title = [NSString stringWithFormat:NSLocalizedString(@"Open Subscription Home Page in %@", nil), alternateLocation];
	}
	item = menuItemWithAction(@selector(viewArticlePagesInAlternateBrowser:));
	if (item != nil)
		item.title = [NSString stringWithFormat:NSLocalizedString(@"Open Article Page in %@", nil), alternateLocation];
}

/* updateStatusBarFilterButtonVisibility
 * Sets whether the filterin indication on the status bar is visible or not.
 */

-(void)updateStatusBarFilterButtonVisibility
{
	NSView<BaseView> * theView = self.browserView.activeTabItemView;
	if ([theView isKindOfClass:[BrowserPane class]])
	{
        self.mainWindowController.filterAreaIsHidden = YES;
		[self setFilterBarState:NO withAnimation:NO];
	}
	else {
        self.mainWindowController.filterAreaIsHidden = NO;
		[self setFilterBarState:[Preferences standardPreferences].showFilterBar withAnimation:NO];
	}
}

/* updateSearchPlaceholder
 * Update the search placeholder string in the search field depending on the view in
 * the active tab.
 */
-(void)updateSearchPlaceholderAndSearchMethod
{
	NSView<BaseView> * theView = self.browserView.activeTabItemView;
	Preferences * prefs = [Preferences standardPreferences];
	
	// START of rather verbose implementation of switching between "Search all articles" and "Search current web page".
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		// If the current view is a browser view and "Search all articles" is the current SearchMethod, switch to "Search current webpage"
		if ([prefs.searchMethod.friendlyName isEqualToString:[SearchMethod searchAllArticlesMethod].friendlyName])
		{
			for (NSMenuItem * menuItem in ((NSSearchFieldCell *)self.toolbarSearchField.cell).searchMenuTemplate.itemArray)
			{
				if ([[menuItem.representedObject friendlyName] isEqualToString:[SearchMethod searchCurrentWebPageMethod].friendlyName]) {
                    if (@available(macOS 10.10, *)) {
                        self.toolbarSearchField.placeholderString = [SearchMethod searchCurrentWebPageMethod].friendlyName;
                    } else {
                        ((NSSearchFieldCell *)self.toolbarSearchField.cell).placeholderString = [SearchMethod searchCurrentWebPageMethod].friendlyName;
                    }
					[Preferences standardPreferences].searchMethod = menuItem.representedObject;
				}
			}
		}
	}
	else 
	{
		// If the current view is anything else "Search current webpage" is active, switch to "Search all articles".
		if ([prefs.searchMethod.friendlyName isEqualToString:[SearchMethod searchCurrentWebPageMethod].friendlyName])
		{
			for (NSMenuItem * menuItem in ((NSSearchFieldCell *)self.toolbarSearchField.cell).searchMenuTemplate.itemArray)
			{
				if ([[menuItem.representedObject friendlyName] isEqualToString:[SearchMethod searchAllArticlesMethod].friendlyName]) {
                    if (@available(macOS 10.10, *)) {
                        self.toolbarSearchField.placeholderString = [SearchMethod searchAllArticlesMethod].friendlyName;
                    } else {
                        ((NSSearchFieldCell *)self.toolbarSearchField.cell).placeholderString = [SearchMethod searchAllArticlesMethod].friendlyName;
                    }
					[Preferences standardPreferences].searchMethod = menuItem.representedObject;
				}
			}
		} else {
            if (@available(macOS 10.10, *)) {
                self.toolbarSearchField.placeholderString = prefs.searchMethod.friendlyName;
            } else {
                ((NSSearchFieldCell *)self.toolbarSearchField.cell).placeholderString = prefs.searchMethod.friendlyName;
		}
		}
	// END of switching between "Search all articles" and "Search current web page".
	}
	
	if ([Preferences standardPreferences].layout == MA_Layout_Unified)
	{
		[self.filterSearchField.cell setSendsWholeSearchString:YES];
		((NSSearchFieldCell *)self.filterSearchField.cell).placeholderString = self.articleController.searchPlaceholderString;
	}
	else
	{
		[self.filterSearchField.cell setSendsWholeSearchString:NO];
		((NSSearchFieldCell *)self.filterSearchField.cell).placeholderString = self.articleController.searchPlaceholderString;
	}
}

#pragma mark Searching

/* setFocusToSearchField
 * Put the input focus on the search field.
 */
-(IBAction)setFocusToSearchField:(id)sender
{
	if (self.mainWindow.toolbar.visible && [self toolbarItemWithIdentifier:@"SearchItem"] && self.mainWindow.toolbar.displayMode != NSToolbarDisplayModeLabelOnly)
		[self.mainWindow makeFirstResponder:self.toolbarSearchField];
	else
	{
		if (!searchPanel)
			searchPanel = [[SearchPanel alloc] init];
		[searchPanel runSearchPanel:self.mainWindow];
	}
}

/* searchString
 * Returns the global search string currently in use for the web and article views.
 * Set by the user via the toolbar or the search panel.
 */
-(void)setSearchString:(NSString *)newSearchString
{
	searchString = newSearchString;
}

/* searchString
 * Returns the global search string currently in use for the web and article views.
 */
-(NSString *)searchString
{
	return searchString;
}


/* setFilterString
 * Sets the filter bar's search string when the users enters it in the filter bar's search field.
 */
-(void)setFilterString:(NSString *)newFilterString
{
	self.filterSearchField.stringValue = newFilterString;
}

/* filterString
 * Return the contents of the filter bar's search field.
 */
-(NSString *)filterString
{
	return self.filterSearchField.stringValue;
}

/* searchUsingFilterField
 * Executes a search using the filter control.
 */
-(IBAction)searchUsingFilterField:(id)sender
{
	[self.browserView.activeTabItemView performFindPanelAction:NSFindPanelActionNext];
}

- (IBAction)searchUsingTreeFilter:(NSSearchField* )field
{
    NSString* f = field.stringValue;
    [self.foldersTree setSearch:f];
}

/* searchUsingToolbarTextField
 * Executes a search using the search field on the toolbar.
 */
-(IBAction)searchUsingToolbarTextField:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        if (!searchPanel)
            searchPanel = [[SearchPanel alloc] init];
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
	[self searchArticlesWithString:self.toolbarSearchField.stringValue];
}

/* performAllArticlesSearch
 * Performs a web-search with the defined query URL. This is usually called by plugged-in SearchMethods.
 */
-(void)performWebSearch:(SearchMethod *)searchMethod
{
	[self.browserView createAndLoadNewTab:[searchMethod queryURLforSearchString:searchString] inBackground:NO];
}

/* performWebPageSearch
 * Performs a search for searchString within the currently displayed web page in our bult-in browser.
 */
-(void)performWebPageSearch
{
	NSView<BaseView> * theView = self.browserView.activeTabItemView;
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		[self setFocusToSearchField:self];
		[theView performFindPanelAction:NSFindPanelActionSetFindString];
	}
}	
	
/* searchArticlesWithString
 * Do the actual article search. The database is called to set the search string
 * and then we make sure the search folder is selected so that the subsequent
 * reload will be scoped by the search string.
 */
-(void)searchArticlesWithString:(NSString *)theSearchString
{
	if (!theSearchString.blank)
	{
        db.searchString = theSearchString;
        if (self.foldersTree.actualSelection != db.searchFolderId) {
			[self.foldersTree selectFolder:db.searchFolderId];
        } else {
			[self.articleController reloadArrayOfArticles];
        }
	}
}

#pragma mark Refresh Subscriptions

/* refreshAllFolderIcons
 * Get new favicons from all subscriptions.
 */
-(IBAction)refreshAllFolderIcons:(id)sender
{
	LOG_EXPR([self.foldersTree folders:0]);
    if (!self.connecting) {
		[[RefreshManager sharedManager] refreshFolderIconCacheForSubscriptions:[self.foldersTree folders:0]];
    }
}

/* refreshAllSubscriptions
 * Get new articles from all subscriptions.
 */
-(IBAction)refreshAllSubscriptions:(id)sender
{
	// Reset the refresh timer
	[self handleCheckFrequencyChange:nil];
	
	// Kick off an initial refresh	
	if (!self.connecting) 
		[[RefreshManager sharedManager] refreshSubscriptionsAfterRefreshAll:[self.foldersTree folders:0] ignoringSubscriptionStatus:NO];
	
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
	[[RefreshManager sharedManager] refreshSubscriptionsAfterRefresh:self.foldersTree.selectedFolders ignoringSubscriptionStatus:YES];
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


/* mailLinkToArticlePage
 * Prompts the default email application to send a link to the currently selected article(s). 
 * Builds a string that contains a well-formed link according to the "mailto:"-scheme (RFC2368).
 */
-(IBAction)mailLinkToArticlePage:(id)sender
{
	NSMutableString *mailtoLink = nil;
	NSString * mailtoLineBreak = @"%0D%0A"; // necessary linebreak characters according to RFC
	NSString * title;
	NSString * link;
	Article * currentArticle;
	
	// If the active tab is a web view, mail the URL ...
	NSView<BaseView> * theView = self.browserView.activeTabItemView;
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		NSString * viewLink = theView.viewLink;
		if (viewLink != nil)
		{
			title = percentEscape([self.browserView tabItemViewTitle:theView]);
			link = percentEscape(viewLink);
			mailtoLink = [NSMutableString stringWithFormat:@"mailto:?subject=%@&body=%@", title, link];
		}
	}
	else
	{
		// ... otherwise, iterate over the currently selected articles.
		NSArray * articleArray = self.articleController.markedArticleRange;
		if (articleArray.count > 0) 
		{
			if (articleArray.count == 1)
			{
				currentArticle = articleArray[0];
				title = percentEscape(currentArticle.title);
				link = percentEscape(currentArticle.link);
				mailtoLink = [NSMutableString stringWithFormat: @"mailto:?subject=%@&body=%@", title, link];
			}
			else
			{
				mailtoLink = [NSMutableString stringWithFormat:@"mailto:?subject=&body="];
				for (currentArticle in articleArray)
				{
					title = percentEscape(currentArticle.title);
					link = percentEscape(currentArticle.link);
					[mailtoLink appendFormat: @"%@%@%@%@%@", title, mailtoLineBreak, link, mailtoLineBreak, mailtoLineBreak];
				}
			}
		}
	}
	
	if (mailtoLink != nil)
		[self openURLInDefaultBrowser:[NSURL URLWithString: mailtoLink]];
}

/* makeTextSmaller
 * Make text size smaller in the article pane.
 * In the future, we may want this to make text size smaller in the article list instead.
 */
-(IBAction)makeTextSmaller:(id)sender
{
	NSView<BaseView> * activeView = self.browserView.activeTabItemView;
	[activeView.webView makeTextSmaller:sender];
}

/* makeTextLarger
 * Make text size larger in the article pane.
 * In the future, we may want this to make text size larger in the article list instead.
 */
-(IBAction)makeTextLarger:(id)sender
{
	NSView<BaseView> * activeView = self.browserView.activeTabItemView;
	[activeView.webView makeTextLarger:sender];
}

#pragma mark Blogging

/* blogWithExternalEditor
 * Builds and sends an Apple Event with info from the currently selected articles to the application specified by the bundle identifier that is passed.
 * Iterates over all currently selected articles and consecutively sends Apple Events to the specified app.
 */
-(void)blogWithExternalEditor:(NSString *)externalEditorBundleIdentifier;
{
	// Is our target application running? If not, we'll launch it.
	if ([NSRunningApplication runningApplicationsWithBundleIdentifier:externalEditorBundleIdentifier].count == 0)
	{
		[[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:externalEditorBundleIdentifier
															 options:NSWorkspaceLaunchWithoutActivation
									  additionalEventParamDescriptor:NULL
													launchIdentifier:nil];
	}
	
	// If the active tab is a web view, blog the URL
	NSView<BaseView> * theView = self.browserView.activeTabItemView;
    if ([theView isKindOfClass:[BrowserPane class]]) {
		[self sendBlogEvent:externalEditorBundleIdentifier title:[self.browserView tabItemViewTitle:self.browserView.activeTabItemView] url:theView.viewLink body:APP.currentTextSelection author:@"" guid:@""];
    } else {
		// Get the currently selected articles from the ArticleView and iterate over them.
        for (Article * currentArticle in self.articleController.markedArticleRange) {
			[self sendBlogEvent:externalEditorBundleIdentifier title:currentArticle.title url:currentArticle.link body:APP.currentTextSelection author:currentArticle.author guid:currentArticle.guid];
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
	if (err != noErr) 
		NSLog(@"Error sending Apple Event: %li", (long)err );
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
	BOOL isAnyArticleView = self.browserView.activeTabItemView == [self.browserView primaryTabItemView];
	
	*validateFlag = NO;
    
	if (theAction == @selector(refreshAllSubscriptions:) || theAction == @selector(cancelAllRefreshesToolbar:))
	{
		*validateFlag = !db.readOnly;
		return YES;
	}

	if (theAction == @selector(newSubscription:))
	{
		*validateFlag = !db.readOnly && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(newSmartFolder:))
	{
		*validateFlag = !db.readOnly && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(skipFolder:))
	{
		*validateFlag = !db.readOnly && isAnyArticleView && isMainWindowVisible && db.countOfUnread > 0;
		return YES;
	}
	if (theAction == @selector(getInfo:))
	{
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		*validateFlag = (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(forceRefreshSelectedSubscriptions:)) {
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		*validateFlag = folder.type == VNAFolderTypeOpenReader;
		return YES;
	}
	if (theAction == @selector(viewArticlesTab:))
	{
		*validateFlag = !isAnyArticleView;
		return YES;
	}
	if (theAction == @selector(viewNextUnread:))
	{
		*validateFlag = db.countOfUnread > 0;
		return YES;
	}
    if (theAction == @selector(markAllRead:))
    {
        Folder *folder = [db folderFromID:self.foldersTree.actualSelection];
        if (folder.type == VNAFolderTypeRSS) {
            *validateFlag = folder && folder.unreadCount > 0 && !db.readOnly && isMainWindowVisible;
        } else if (folder.type != VNAFolderTypeTrash) {
            *validateFlag = folder && !db.readOnly && db.countOfUnread > 0 && isMainWindowVisible;
        }
        return YES;
    }
	if (theAction == @selector(goBack:))
	{
        // TODO: Make this work without the protocol check.
        if ([self.browserView.activeTabItemView conformsToProtocol:@protocol(BaseView)]) {
            *validateFlag = self.browserView.activeTabItemView.canGoBack && isMainWindowVisible;
        } else {
            *validateFlag = NO;
        }
		return YES;
	}
	if (theAction == @selector(mailLinkToArticlePage:))
	{
		NSView<BaseView> * theView = self.browserView.activeTabItemView;
		Article * thisArticle = self.selectedArticle;
		
		if ([theView isKindOfClass:[BrowserPane class]])
			*validateFlag = (theView.viewLink != nil);
		else
			*validateFlag = (thisArticle != nil && isMainWindowVisible);
		return NO; // Give the menu handler a chance too.
	}
	if (theAction == @selector(emptyTrash:))
	{
		*validateFlag = !db.readOnly;
		return YES;
	}
	if (theAction == @selector(searchUsingToolbarTextField:))
	{
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
	BOOL isAnyArticleView = self.browserView.activeTabItemView == [self.browserView primaryTabItemView];
	BOOL isArticleView = self.browserView.activeTabItemView == self.articleController.mainArticleView;
	BOOL flag;
	
	if ([self validateCommonToolbarAndMenuItems:theAction validateFlag:&flag])
	{
		return flag;
	}
	if (theAction == @selector(printDocument:))
	{
		if (!isMainWindowVisible)
			return NO;
		if (isAnyArticleView)
		{
			return self.selectedArticle != nil;
		}
		else
		{
			NSView<BaseView> * theView = self.browserView.activeTabItemView;
			return theView != nil && [theView isKindOfClass:[BrowserPane class]] && !((BrowserPane *)theView).loading;
		}
	}
	else if (theAction == @selector(goForward:))
	{
		return self.browserView.activeTabItemView.canGoForward && isMainWindowVisible;
	}
	else if (theAction == @selector(newGroupFolder:))
	{
		return !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(showHideFilterBar:))
	{
		if ([Preferences standardPreferences].showFilterBar)
			[menuItem setTitle:NSLocalizedString(@"Hide Filter Bar", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Show Filter Bar", nil)];
		return isMainWindowVisible && isAnyArticleView;
	}
	else if (theAction == @selector(makeTextLarger:))
	{
		return self.browserView.activeTabItemView.webView.canMakeTextLarger && isMainWindowVisible;
	}
	else if (theAction == @selector(makeTextSmaller:))
	{
		return self.browserView.activeTabItemView.webView.canMakeTextSmaller && isMainWindowVisible;
	}
	else if (theAction == @selector(doViewColumn:))
	{
		Field * field = menuItem.representedObject;
		menuItem.state = field.visible ? NSOnState : NSOffState;
		return isMainWindowVisible && isArticleView;
	}
	else if (theAction == @selector(doSelectStyle:))
	{
		NSString * styleName = menuItem.title;
		menuItem.state = [styleName isEqualToString:[Preferences standardPreferences].displayStyle] ? NSOnState : NSOffState;
		return isMainWindowVisible && isAnyArticleView;
	}
	else if (theAction == @selector(doSortColumn:))
	{
		Field * field = menuItem.representedObject;
        if ([field.name isEqualToString:self.articleController.sortColumnIdentifier]) {
			menuItem.state = NSOnState;
        } else {
			menuItem.state = NSOffState;
        }
		return isMainWindowVisible && isAnyArticleView;
	}
	else if (theAction == @selector(doSortDirection:))
	{
		NSNumber * ascendingNumber = menuItem.representedObject;
		BOOL ascending = ascendingNumber.integerValue;
        if (ascending == self.articleController.sortIsAscending) {
			menuItem.state = NSOnState;
        } else {
			menuItem.state = NSOffState;
        }
		return isMainWindowVisible && isAnyArticleView;
	}
	else if (theAction == @selector(unsubscribeFeed:))
	{
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		if (folder)
		{
			if (folder.isUnsubscribed)
				[menuItem setTitle:NSLocalizedString(@"Resubscribe to Feed", nil)];
			else
				[menuItem setTitle:NSLocalizedString(@"Unsubscribe from Feed", nil)];
		}
		return folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(useCurrentStyleForArticles:))
	{
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		if (folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && !folder.loadsFullHTML)
			menuItem.state = NSOnState;
		else
			menuItem.state = NSOffState;
		return folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(useWebPageForArticles:))
	{
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		if (folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && folder.loadsFullHTML)
			menuItem.state = NSOnState;
		else
			menuItem.state = NSOffState;
		return folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(deleteFolder:))
	{
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		if (folder.type == VNAFolderTypeSearch)
			[menuItem setTitle:NSLocalizedString(@"Delete", @"Title of a menu item")];
		else
			[menuItem setTitle:NSLocalizedString(@"Delete…", @"Title of a menu item")];
		return folder && folder.type != VNAFolderTypeTrash && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(refreshSelectedSubscriptions:))
	{
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		return folder && (folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeGroup || folder.type == VNAFolderTypeOpenReader) && !db.readOnly;
	}
	else if (theAction == @selector(refreshAllFolderIcons:))
	{
		return !self.connecting && !db.readOnly;
	}
	else if (theAction == @selector(renameFolder:))
	{
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		return folder && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(markAllSubscriptionsRead:))
	{
		return !db.readOnly && isMainWindowVisible && db.countOfUnread > 0;
	}
	else if (theAction == @selector(importSubscriptions:))
	{
		return !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(cancelAllRefreshes:))
	{
		return !db.readOnly && self.connecting;
	}
	else if ((theAction == @selector(viewSourceHomePage:)) || (theAction == @selector(viewSourceHomePageInAlternateBrowser:)))
	{
		Article * thisArticle = self.selectedArticle;
		Folder * folder = (thisArticle) ? [db folderFromID:thisArticle.folderId] : [db folderFromID:self.foldersTree.actualSelection];
		return folder && (thisArticle || folder.type == VNAFolderTypeRSS || folder.type == VNAFolderTypeOpenReader) && (folder.homePage && !folder.homePage.blank && isMainWindowVisible);
	}
	else if ((theAction == @selector(viewArticlePages:)) || (theAction == @selector(viewArticlePagesInAlternateBrowser:)))
	{
		Article * thisArticle = self.selectedArticle;
		if (thisArticle != nil)
			return (thisArticle.link && !thisArticle.link.blank && isMainWindowVisible);
		return NO;
	}
	else if (theAction == @selector(exportSubscriptions:))
	{
		return isMainWindowVisible;
	}
	else if (theAction == @selector(reindexDatabase:))
	{
		return !self.connecting && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(editFolder:))
	{
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		return folder && (folder.type == VNAFolderTypeSmart || folder.type == VNAFolderTypeRSS) && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(restoreMessage:))
	{
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		return folder.type == VNAFolderTypeTrash && self.selectedArticle != nil && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(deleteMessage:))
	{
		Folder * folder = [db folderFromID:self.foldersTree.actualSelection];
		return self.selectedArticle != nil && !db.readOnly && isMainWindowVisible && folder.type != VNAFolderTypeOpenReader;
	}
	else if (theAction == @selector(previousTab:))
	{
		return isMainWindowVisible && self.browserView.countOfTabs > 1;
	}
	else if (theAction == @selector(nextTab:))
	{
		return isMainWindowVisible && self.browserView.countOfTabs > 1;
	}
	else if (theAction == @selector(closeTab:))
	{
		return isMainWindowVisible && !isArticleView;
	}
	else if (theAction == @selector(closeAllTabs:))
	{
		return isMainWindowVisible && self.browserView.countOfTabs > 1;
	}
	else if (theAction == @selector(reloadPage:))
	{
		NSView<BaseView> * theView = self.browserView.activeTabItemView;
		return ([theView isKindOfClass:[BrowserPane class]]) && !((BrowserPane *)theView).loading;
	}
	else if (theAction == @selector(stopReloadingPage:))
	{
		NSView<BaseView> * theView = self.browserView.activeTabItemView;
		return ([theView isKindOfClass:[BrowserPane class]]) && ((BrowserPane *)theView).loading;
	}
	else if (theAction == @selector(keepFoldersArranged:))
	{
		Preferences * prefs = [Preferences standardPreferences];
		menuItem.state = (prefs.self.foldersTreeSortMethod == menuItem.tag) ? NSOnState : NSOffState;
		return isMainWindowVisible;
	}
	else if (theAction == @selector(setFocusToSearchField:))
	{
		return isMainWindowVisible;
	}
	else if (theAction == @selector(reportLayout:))
	{
		Preferences * prefs = [Preferences standardPreferences];
		menuItem.state = (prefs.layout == MA_Layout_Report) ? NSOnState : NSOffState;
		return isMainWindowVisible;
	}
	else if (theAction == @selector(condensedLayout:))
	{
		Preferences * prefs = [Preferences standardPreferences];
		menuItem.state = (prefs.layout == MA_Layout_Condensed) ? NSOnState : NSOffState;
		return isMainWindowVisible;
	}
	else if (theAction == @selector(unifiedLayout:))
	{
		Preferences * prefs = [Preferences standardPreferences];
		menuItem.state = (prefs.layout == MA_Layout_Unified) ? NSOnState : NSOffState;
		return isMainWindowVisible;
	}
	else if (theAction == @selector(markFlagged:))
	{
		Article * thisArticle = self.selectedArticle;
		if (thisArticle != nil)
		{
			if (thisArticle.flagged)
				[menuItem setTitle:NSLocalizedString(@"Mark Unflagged", nil)];
			else
				[menuItem setTitle:NSLocalizedString(@"Mark Flagged", nil)];
		}
		return (thisArticle != nil && !db.readOnly && isMainWindowVisible);
	}
	else if (theAction == @selector(markRead:))
	{
		Article * thisArticle = self.selectedArticle;
		return (thisArticle != nil && !db.readOnly && isMainWindowVisible);
	}
	else if (theAction == @selector(markUnread:))
	{
		Article * thisArticle = self.selectedArticle;
		return (thisArticle != nil && !db.readOnly && isMainWindowVisible);
	}
	else if (theAction == @selector(mailLinkToArticlePage:))
	{
        if (self.articleController.markedArticleRange.count > 1) {
			[menuItem setTitle:NSLocalizedString(@"Send Links", nil)];
        } else {
			[menuItem setTitle:NSLocalizedString(@"Send Link", nil)];
        }
		return flag;
	}
	else if (theAction == @selector(downloadEnclosure:))
	{
        if (self.articleController.markedArticleRange.count > 1) {
			[menuItem setTitle:NSLocalizedString(@"Download Enclosures", @"Title of a menu item")];
        } else {
			[menuItem setTitle:NSLocalizedString(@"Download Enclosure", @"Title of a menu item")];
        }
		return (self.selectedArticle.hasEnclosure && isMainWindowVisible);
	}
	else if (theAction == @selector(newTab:))
	{
		return isMainWindowVisible;
	}
	else if (theAction == @selector(setSearchMethod:))
	{
		Preferences * prefs = [Preferences standardPreferences];
		if ([prefs.searchMethod.friendlyName isEqualToString:[menuItem.representedObject friendlyName]])
			menuItem.state = NSOnState;
		else 
			menuItem.state = NSOffState;
		return YES;
	} else if (theAction == @selector(openVienna:)) {
        return self.mainWindow.isKeyWindow == false;
    }

	return YES;
}

#pragma mark Preferences

- (PreferencesWindowController *)preferencesWindowController {
    if (!_preferencesWindowController) {
        _preferencesWindowController = [PreferencesWindowController new];
    }

    return _preferencesWindowController;
}

- (IBAction)showPreferences:(id)sender {
    [self.preferencesWindowController showWindow:self];
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
 Toggle the visibility of the activity panel; show when hidden and close when
 visible.
 */
- (IBAction)toggleActivityViewer:(id)sender {
    if (!self.activityPanelController.window.visible) {
        [self.activityPanelController showWindow:self];
    } else {
        [self.activityPanelController.window performClose:self];
    }
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
                            forKeyPath:NSStringFromSelector(@selector(numberOfPlugins))];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
