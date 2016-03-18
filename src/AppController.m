//
//  AppController.m
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
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

#import "AppController.h"

#import "MASPreferencesWindowController.h"
#import "GeneralPreferencesViewController.h"
#import "AppearancePreferencesViewController.h"
#import "SyncingPreferencesViewController.h"
#import "AdvancedPreferencesViewController.h"

#import "FoldersTree.h"
#import "Import.h"
#import "Export.h"
#import "RefreshManager.h"
#import "ArrayExtensions.h"
#import "StringExtensions.h"
#import "SplitViewExtensions.h"
#import "SquareWindow.h"
#import "ViewExtensions.h"
#import "BrowserView.h"
#import "SearchFolder.h"
#import "NewSubscription.h"
#import "NewGroupFolder.h"
#import "ViennaApp.h"
#import "XMLSourceWindow.h"
#import "ActivityLog.h"
#import "BrowserPaneTemplate.h"
#import "Constants.h"
#import "ArticleView.h"
#import "BrowserPane.h"
#import "EmptyTrashWarning.h"
#import "Preferences.h"
#import "InfoWindow.h"
#import "DownloadManager.h"
#import "HelperFunctions.h"
#import "ArticleFilter.h"
#import "ToolbarItem.h"
#import "ClickableProgressIndicator.h"
#import "SearchPanel.h"
#import "SearchMethod.h"
#import <Sparkle/Sparkle.h>
#import <WebKit/WebKit.h>
#include <mach/mach_port.h>
#include <mach/mach_interface.h>
#include <mach/mach_init.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>
#import "GoogleReader.h"
#import "VTPG_Common.h"
#import "Database.h"
#import "BJRWindowWithToolbar.h"
#import "NSURL+Utils.h"


@interface AppController (Private)
	@property (nonatomic, readonly, copy) NSMenu *searchFieldMenu;
	-(void)installSleepHandler;
	-(void)installScriptsFolderWatcher;
	-(void)handleTabChange:(NSNotification *)nc;
	-(void)handleFolderSelection:(NSNotification *)nc;
	-(void)handleCheckFrequencyChange:(NSNotification *)nc;
	-(void)handleFolderNameChange:(NSNotification *)nc;
	-(void)handleDidBecomeKeyWindow:(NSNotification *)nc;
	-(void)handleReloadPreferences:(NSNotification *)nc;
	-(void)handleShowAppInStatusBar:(NSNotification *)nc;
	-(void)handleShowStatusBar:(NSNotification *)nc;
	-(void)handleShowFilterBar:(NSNotification *)nc;
	-(void)setAppStatusBarIcon;
	-(void)localiseMenus:(NSArray *)arrayOfMenus;
	-(void)updateNewArticlesNotification;
	-(void)showAppInStatusBar;
	-(void)initSortMenu;
	-(void)initColumnsMenu;
	-(void)initScriptsMenu;
	-(void)initFiltersMenu;
	@property (nonatomic, getter=getStylesMenu, readonly, copy) NSMenu *stylesMenu;
	-(void)startProgressIndicator;
	-(void)stopProgressIndicator;
	-(void)doEditFolder:(Folder *)folder;
	-(void)refreshOnTimer:(NSTimer *)aTimer;
	-(BOOL)installFilename:(NSString *)srcFile toPath:(NSString *)path;
	-(void)setStatusBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate;
	-(void)setFilterBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate;
	-(void)setPersistedFilterBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate;
	-(void)doConfirmedDelete:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
	-(void)doConfirmedEmptyTrash:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
	-(void)runAppleScript:(NSString *)scriptName;
	@property (nonatomic, readonly, copy) NSString *appName;
	-(void)sendBlogEvent:(NSString *)externalEditorBundleIdentifier title:(NSString *)title url:(NSString *)url body:(NSString *)body author:(NSString *)author guid:(NSString *)guid;
	-(void)setLayout:(NSInteger)newLayout withRefresh:(BOOL)refreshFlag;
	-(void)updateAlternateMenuTitle;
	-(void)updateSearchPlaceholderAndSearchMethod;
	-(void)toggleOptionKeyButtonStates;
	@property (nonatomic, readonly, strong) FoldersTree *foldersTree;
	-(void)updateCloseCommands;
	@property (nonatomic, getter=isFilterBarVisible, readonly) BOOL filterBarVisible;
	@property (nonatomic, getter=isStatusBarVisible, readonly) BOOL statusBarVisible;
	@property (nonatomic, readonly, copy) NSDictionary *registrationDictionaryForGrowl;
	@property (nonatomic, readonly, strong) NSTimer *checkTimer;
	-(ToolbarItem *)toolbarItemWithIdentifier:(NSString *)theIdentifier;
	-(void)searchArticlesWithString:(NSString *)searchString;
	-(void)sourceWindowWillClose:(NSNotification *)notification;
	-(IBAction)cancelAllRefreshesToolbar:(id)sender;
@end

// Static constant strings that are typically never tweaked
static const CGFloat MA_Minimum_Folder_Pane_Width = 80.0;
static const CGFloat MA_Minimum_BrowserView_Pane_Width = 200.0;
static const CGFloat MA_StatusBarHeight = 23.0;

// Awake from sleep
static io_connect_t root_port;
static void MySleepCallBack(void * x, io_service_t y, natural_t messageType, void * messageArgument);

@implementation AppController

@synthesize rssFeed = _rssFeed;
@synthesize foldersTree;

/* init
 * Class instance initialisation.
 */
-(instancetype)init
{
	if ((self = [super init]) != nil)
	{
		scriptPathMappings = [[NSMutableDictionary alloc] init];
		progressCount = 0;
		persistedStatusText = nil;
		lastCountOfUnread = 0;
		appStatusItem = nil;
		scriptsMenuItem = nil;
		isStatusBarVisible = YES;
		checkTimer = nil;
		didCompleteInitialisation = NO;
		emptyTrashWarning = nil;
		searchString = nil;
	}
	return self;
}

/* awakeFromNib
 * Do all the stuff that only makes sense after our NIB has been loaded and connected.
 */
-(void)awakeFromNib
{

#if ( MAC_OS_X_VERSION_MAX_ALLOWED < 1070 && !defined(NSWindowCollectionBehaviorFullScreenPrimary) )
    enum {
        NSWindowCollectionBehaviorFullScreenPrimary = (1 << 7)
    };
#endif
	
    //Enable FullScreen Support if we are on Lion 10.7.x
    mainWindow.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
  	

	Preferences * prefs = [Preferences standardPreferences];
	
	// Restore the most recent layout
	[self setLayout:prefs.layout withRefresh:NO];
	
	// Localise the menus
	[self localiseMenus:NSApp.mainMenu.itemArray];
	
	// Set the delegates and title
	mainWindow.delegate = self;
	mainWindow.title = self.appName;
	[NSApplication sharedApplication].delegate = self;
	mainWindow.minSize = NSMakeSize(MA_Default_Main_Window_Min_Width, MA_Default_Main_Window_Min_Height);
    [mainWindow setAllowsConcurrentViewDrawing:YES];
	
	// Initialise the plugin manager now that the UI is ready
	pluginManager = [[PluginManager alloc] init];
	[pluginManager resetPlugins];
	
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

/* applicationDidResignActive
 * Do the things we need to do when Vienna becomes inactive, like greying out.
 */
-(void)applicationDidResignActive:(NSNotification *)aNotification
{
	[foldersTree setOutlineViewBackgroundColor: [NSColor colorWithCalibratedRed:0.91 green:0.91 blue:0.91 alpha:1.00]];
	statusText.textColor = [NSColor colorWithCalibratedRed:0.43 green:0.43 blue:0.43 alpha:1.00];
	currentFilterTextField.textColor = [NSColor colorWithCalibratedRed:0.43 green:0.43 blue:0.43 alpha:1.00];
	[filterIconInStatusBarButton setEnabled:NO];
}

/* applicationDidBecomeActive
 * Do the things we need to do when Vienna becomes active, like re-coloring view backgrounds.
 */
-(void)applicationDidBecomeActive:(NSNotification *)notification
{
	[foldersTree setOutlineViewBackgroundColor: [NSColor colorWithCalibratedRed:0.84 green:0.87 blue:0.90 alpha:1.00]];
	statusText.textColor = [NSColor blackColor];
	currentFilterTextField.textColor = [NSColor blackColor];
	[filterIconInStatusBarButton setEnabled:YES];
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
        
		[foldersTree initialiseFoldersTree];
		
		// If the statusbar is hidden, also hide the highlight line on its top and the filter button.
		if (!self.statusBarVisible)
		{
			if ([mainWindow respondsToSelector:@selector(setBottomCornerRounded:)])
				[mainWindow setBottomCornerRounded:NO];
			[cosmeticStatusBarHighlightLine setHidden:YES];
			[currentFilterTextField setHidden:YES];
			[filterIconInStatusBarButton setHidden:YES];
		}
		
		Preferences * prefs = [Preferences standardPreferences];
		// Set the initial filter bar state
		[self setFilterBarState:prefs.showFilterBar withAnimation:NO];
				
		// Make article list the first responder
		[mainWindow makeFirstResponder:[browserView primaryTabItemView].mainView];		
		
		// Select the folder and article from the last session
		NSInteger previousFolderId = [prefs integerForKey:MAPref_CachedFolderID];
		NSString * previousArticleGuid = [prefs stringForKey:MAPref_CachedArticleGUID];
		if (previousArticleGuid.blank)
			previousArticleGuid = nil;
		[articleController.mainArticleView selectFolderAndArticle:previousFolderId guid:previousArticleGuid];

		if (prefs.refreshOnStartup)
			[self refreshAllSubscriptions:self];

		// Start opening the old tabs once everything else has finished initializing and setting up
		NSArray * tabLinks = [prefs arrayForKey:MAPref_TabList];
		for (NSString * tabLink in tabLinks)
		{
			[self createNewTab:(tabLink.length ? [NSURL URLWithString:tabLink] : nil) inBackground:YES];
		}

		doneSafeInit = YES;
		
	}
	didCompleteInitialisation = YES;
}

/* localiseMenus
 * As of 2.0.1, the menu localisation is now done through the Localizable.strings file rather than
 * the NIB file due to the effort in managing localised NIBs for an increasing number of languages.
 * Also, note care is taken not to localise those commands that were added by the OS. If there is
 * no equivalent in the Localizable.strings file, we do nothing.
 */
-(void)localiseMenus:(NSArray *)arrayOfMenus
{
	NSUInteger count = arrayOfMenus.count;
	
	for (NSUInteger index = 0; index < count; ++index)
	{
		NSMenuItem * menuItem = arrayOfMenus[index];
		if (menuItem != nil && !menuItem.separatorItem)
		{
			NSString * localisedMenuTitle = NSLocalizedString([menuItem title], nil);
			if (menuItem.submenu)
			{
				NSMenu * subMenu = menuItem.submenu;
				if (localisedMenuTitle != nil)
					subMenu.title = localisedMenuTitle;
				[self localiseMenus:subMenu.itemArray];
			}
			if (localisedMenuTitle != nil)
				menuItem.title = localisedMenuTitle;
		}
	}
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
                        if ([Preferences standardPreferences].syncGoogleReader)
                            [[GoogleReader sharedManager] getToken];
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
-(void)installScriptsFolderWatcher
{
	NSURL * path = [NSURL fileURLWithPath:[Preferences standardPreferences].scriptsFolder];
	_events = [[CDEvents alloc] initWithURLs:@[path]
                                       block:^(CDEvents *watcher, CDEvent *event) {
										   // triggers a refresh of the scripts.menu
                                           [self initScriptsMenu];
                                       }];
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
	
	Preferences * prefs = [Preferences standardPreferences];
	
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
	[nc addObserver:self selector:@selector(handleShowStatusBar:) name:@"MA_Notify_StatusBarChanged" object:nil];
	[nc addObserver:self selector:@selector(handleShowFilterBar:) name:@"MA_Notify_FilterBarChanged" object:nil];
	//Open Reader Notifications
    [nc addObserver:self selector:@selector(handleGoogleAuthFailed:) name:@"MA_Notify_GoogleAuthFailed" object:nil];
		
	// Init the progress counter and status bar.
	[self setStatusMessage:nil persist:NO];
	
	// Initialize the database
	if ((db = [Database sharedManager]) == nil)
	{
		[NSApp terminate:nil];
		return;
	}
	
	// Create the toolbar.
	NSToolbar * toolbar = [[NSToolbar alloc] initWithIdentifier:@"MA_Toolbar"];
	
	// Set the appropriate toolbar options. We are the delegate, customization is allowed,
	// changes made by the user are automatically saved and we start in icon mode.
	toolbar.delegate = self;
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES]; 
	toolbar.displayMode = NSToolbarDisplayModeIconOnly;
	[toolbar setShowsBaselineSeparator:NO];
	mainWindow.toolbar = toolbar;
	
	// Give the status bar and filter string an embossed look
	statusText.cell.backgroundStyle = NSBackgroundStyleRaised;
	currentFilterTextField.cell.backgroundStyle = NSBackgroundStyleRaised;
	currentFilterTextField.stringValue = @"";
	
	// Preload dictionary of standard URLs
	NSString * pathToPList = [[NSBundle mainBundle] pathForResource:@"StandardURLs.plist" ofType:@""];
	if (pathToPList != nil)
		standardURLs = [NSDictionary dictionaryWithContentsOfFile:pathToPList];
	
	// Initialize the Sort By and Columns menu
	[self initSortMenu];
	[self initColumnsMenu];
	[self initFiltersMenu];
	
	// Initialize the Styles menu.
	stylesMenu.submenu = self.stylesMenu;
	
	// Restore the splitview layout
	splitView1.layout = [[Preferences standardPreferences] objectForKey:@"SplitView1Positions"];	
	splitView1.delegate = self;
	
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
	((NSSearchFieldCell *)searchField.cell).searchMenuTemplate = self.searchFieldMenu;
	((NSSearchFieldCell *)filterSearchField.cell).searchMenuTemplate = self.searchFieldMenu;
	
	// Set the placeholder string for the global search field
	SearchMethod * currentSearchMethod = [Preferences standardPreferences].searchMethod;
	[searchField.cell setPlaceholderString:NSLocalizedString([currentSearchMethod friendlyName], nil)];
	
	// Add Scripts menu if we have any scripts
	if (!hasOSScriptsMenu())
		[self initScriptsMenu];
	
	// Show/hide the status bar based on the last session state
	[self setStatusBarState:prefs.showStatusBar withAnimation:NO];
	
	// Add the app to the status bar if needed.
	[self showAppInStatusBar];
	
	// Growl initialization
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSString *path = [mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"Growl.framework"];
	LOG_NS(@"path: %@", path);
	NSBundle *growlFramework = [NSBundle bundleWithPath:path];
	if([growlFramework load])
	{
		NSDictionary *infoDictionary = growlFramework.infoDictionary;
		LOG_NS(@"Using Growl.framework %@ (%@)",
			  infoDictionary[@"CFBundleShortVersionString"],
			  infoDictionary[(NSString *)kCFBundleVersionKey]);

		Class GAB = NSClassFromString(@"GrowlApplicationBridge");
		if([GAB respondsToSelector:@selector(setGrowlDelegate:)])
			[GAB performSelector:@selector(setGrowlDelegate:) withObject:self];
	}
	
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
	foldersTree.mainView.nextKeyView = [browserView primaryTabItemView].mainView;
	
    // Check if we have previously asked the user to send anonymous system profile
    if([[NSUserDefaults standardUserDefaults] objectForKey:MAPref_SendSystemProfileInfo] == nil) {
        [self showSystemProfileInfoAlert];
    }

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

/* updaterWillRelaunchApplication
 * This is a delegate for Sparkle.framwork
 */
- (void)updaterWillRelaunchApplication:(SUUpdater *)updater 
{
	[[Preferences standardPreferences] handleUpdateRestart];
	
}

/* applicationShouldTerminate
 * This function is called when the user wants to close Vienna. First we check to see
 * if a connection or import is running and that all articles are saved.
 */
-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	NSInteger returnCode;
	
	if ([DownloadManager sharedInstance].activeDownloads > 0)
	{
		returnCode = NSRunAlertPanel(NSLocalizedString(@"Downloads Running", nil),
									 NSLocalizedString(@"Downloads Running text", nil),
									 NSLocalizedString(@"Quit", nil),
									 NSLocalizedString(@"Cancel", nil),
									 nil);
		if (returnCode == NSAlertAlternateReturn)
			return NSTerminateCancel;
	}
	
	if (!didCompleteInitialisation)
	{
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
		// Save the splitview layout
		Preferences * prefs = [Preferences standardPreferences];
		[prefs setObject:splitView1.layout forKey:@"SplitView1Positions"];
		
		// Close the activity window explicitly to force it to
		// save its split bar position to the preferences.
		NSWindow * activityWindow = activityViewer.window;
		[activityWindow performClose:self];
		
		// Put back the original app icon
		[NSApp.dockTile setBadgeLabel:nil];
		
		// Save the open tabs
		[browserView saveOpenTabs];
		
		// Remember the article list column position, sizes, etc.
		[articleController saveTableSettings];
		[foldersTree saveFolderSettings];
		
		// Finally save preferences
		[prefs savePreferences];
		
	}
	[db close];
}

/* splitView:effectiveRect:forDrawnRect:ofDividerAtIndex [delegate]
 * Makes the dragable area around the SplitView divider larger, so that it is easier to grab.
 */
- (NSRect)splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
{
	if(splitView.vertical) {
		drawnRect.origin.x -= 4;
		drawnRect.size.width += 6;
		return drawnRect;
	}
	else
		return drawnRect;
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
			stylesMenu.submenu = self.stylesMenu;
			[[self toolbarItemWithIdentifier:@"Styles"] setPopup:@"stylesMenuButton" withMenu:self.stylesMenu];
			prefs.displayStyle = styleName;
			if ([prefs.displayStyle isEqualToString:styleName])
				runOKAlertPanel(NSLocalizedString(@"New style title", nil), NSLocalizedString(@"New style body", nil), styleName);
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
			[pluginManager loadPlugin:fullPath];
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
		BOOL returnCode = NSRunAlertPanel(NSLocalizedString(@"Import subscriptions from OPML file?", nil), NSLocalizedString(@"Do you really want to import the subscriptions from the specified OPML file?", nil), NSLocalizedString(@"Import", nil), NSLocalizedString(@"Cancel", nil), nil);
		if (returnCode == NSAlertAlternateReturn)
			return NO;
		[Import importFromFile:filename];
		return YES;
	}
    if ([filename.pathExtension isEqualToString:@"webloc"])
    {
        NSURL* url = [NSURL URLFromInetloc:filename];
        if (!mainWindow.visible)
        	[mainWindow makeKeyAndOrderFront:self];
        if (url != nil && !db.readOnly)
        {
            [self.rssFeed newSubscription:mainWindow underParent:foldersTree.groupParentSelection initialURL:url.absoluteString];
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
			runOKAlertPanel(NSLocalizedString(@"Cannot create folder title", nil), NSLocalizedString(@"Cannot create folder body", nil), path);
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
	NSMenu * cellMenu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
	
	NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recent Searches", nil) action:NULL keyEquivalent:@""];
	[item setTag:NSSearchFieldRecentsTitleMenuItemTag];
	[cellMenu insertItem:item atIndex:0];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recents", nil) action:NULL keyEquivalent:@""];
	[item setTag:NSSearchFieldRecentsMenuItemTag];
	[cellMenu insertItem:item atIndex:1];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear", nil) action:NULL keyEquivalent:@""];
	[item setTag:NSSearchFieldClearRecentsMenuItemTag];
	[cellMenu insertItem:item atIndex:2];
	
	SearchMethod * searchMethod;
	NSString * friendlyName;

	[cellMenu addItem: [NSMenuItem separatorItem]];

	// Add all built-in search methods to the menu. 
	for (searchMethod in [SearchMethod builtInSearchMethods])
	{
		friendlyName = searchMethod.friendlyName;
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(friendlyName, nil) action:@selector(setSearchMethod:) keyEquivalent:@""];
		item.representedObject = searchMethod;
		
		// Is this the currently set search method? If yes, mark it as such.
		if ( [friendlyName isEqualToString:[Preferences standardPreferences].searchMethod.friendlyName] )
			item.state = NSOnState;
		
		[cellMenu addItem:item];
	}
	
	// Add all available plugged-in search methods to the menu.
	NSMutableArray * searchMethods = [NSMutableArray arrayWithArray:pluginManager.searchMethods];
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
	cellMenu.delegate = self;
	return cellMenu;
}

/* setSearchMethod 
 */
-(void)setSearchMethod:(NSMenuItem *)sender
{
	[Preferences standardPreferences].searchMethod = sender.representedObject;
	((NSSearchFieldCell *)searchField.cell).placeholderString = sender.title;
}

/* standardURLs
 */
-(NSDictionary *)standardURLs
{
	return standardURLs;
}

/* browserView
 */
-(BrowserView *)browserView
{
	return browserView;
}

/* constrainMinCoordinate
 * Make sure the folder width isn't shrunk beyond a minimum width. Otherwise it looks
 * untidy.
 */
-(CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return (sender == splitView1 && offset == 0) ? MA_Minimum_Folder_Pane_Width : proposedMin;
}

/* constrainMaxCoordinate
 * Make sure that the browserview isn't shrunk beyond a minimum size otherwise the splitview
 * or controls within it start resizing odd.
 */
-(CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	if (sender == splitView1 && offset == 0)
	{
		NSRect mainFrame = splitView1.superview.frame;
		return mainFrame.size.width - MA_Minimum_BrowserView_Pane_Width;
	}
	return proposedMax;
}

/* resizeSubviewsWithOldSize
 * Constrain the folder pane to a fixed width.
 */
-(void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	CGFloat dividerThickness = sender.dividerThickness;
	id sv1 = sender.subviews[0];
	id sv2 = sender.subviews[1];
	NSRect leftFrame = [sv1 frame];
	NSRect rightFrame = [sv2 frame];
	NSRect newFrame = sender.frame;
	
	if (sender == splitView1)
	{
		leftFrame.size.height = newFrame.size.height;
		leftFrame.origin = NSMakePoint(0, 0);
		rightFrame.size.width = newFrame.size.width - leftFrame.size.width - dividerThickness;
		rightFrame.size.height = newFrame.size.height;
		rightFrame.origin.x = leftFrame.size.width + dividerThickness;
		
		[sv1 setFrame:leftFrame];
		[sv2 setFrame:rightFrame];
	}
}

/* folderMenu
 * Dynamically create the popup menu. This is one less thing to
 * explicitly localise in the NIB file.
 */
-(NSMenu *)folderMenu
{
	NSMenu * folderMenu = [[NSMenu alloc] init];
	[folderMenu addItem:copyOfMenuItemWithAction(@selector(refreshSelectedSubscriptions:))];
	[folderMenu addItem:[NSMenuItem separatorItem]];
	[folderMenu addItem:copyOfMenuItemWithAction(@selector(editFolder:))];
	[folderMenu addItem:copyOfMenuItemWithAction(@selector(deleteFolder:))];
	[folderMenu addItem:copyOfMenuItemWithAction(@selector(renameFolder:))];
	[folderMenu addItem:[NSMenuItem separatorItem]];
	[folderMenu addItem:copyOfMenuItemWithAction(@selector(markAllRead:))];
	[folderMenu addItem:[NSMenuItem separatorItem]];
	[folderMenu addItem:copyOfMenuItemWithAction(@selector(viewSourceHomePage:))];
	NSMenuItem * alternateItem = copyOfMenuItemWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	alternateItem.keyEquivalentModifierMask = NSAlternateKeyMask;
	[alternateItem setAlternate:YES];
	[folderMenu addItem:alternateItem];
	[folderMenu addItem:copyOfMenuItemWithAction(@selector(getInfo:))];
	[folderMenu addItem:copyOfMenuItemWithAction(@selector(showXMLSource:))];
	[folderMenu addItem:[NSMenuItem separatorItem]];
	[folderMenu addItem:copyOfMenuItemWithAction(@selector(forceRefreshSelectedSubscriptions:))];	
	return folderMenu;
}

/* exitVienna
 * Alias for the terminate command.
 */
-(IBAction)exitVienna:(id)sender
{
	[NSApp terminate:nil];
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
	BOOL visibleFilterBar = NO;
	// Turn off the filter bar when switching layouts. This is simpler than
	// trying to graft it onto the new layout.
	if (self.filterBarVisible)
		{ visibleFilterBar = YES;
		[self setPersistedFilterBarState:NO withAnimation:NO];
		}
	
	[articleController setLayout:newLayout];
    if (refreshFlag)
        [articleController.mainArticleView refreshFolder:MA_Refresh_RedrawList];
	[browserView setPrimaryTabItemView:articleController.mainArticleView];
	//restore filter bar state if necessary
	if (visibleFilterBar)
		[self setPersistedFilterBarState:YES withAnimation:NO];
	[self updateSearchPlaceholderAndSearchMethod];
	foldersTree.mainView.nextKeyView = [browserView primaryTabItemView].mainView;
}


/* getUrl
 * Handle http https URL Scheme passed to applicaton
 */
- (void)getUrl:(NSAppleEventDescriptor *)event
withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *urlStr = [event paramDescriptorForKeyword:keyDirectObject].stringValue;
    if(urlStr)
        [self.rssFeed newSubscription:mainWindow underParent:foldersTree.groupParentSelection initialURL:urlStr];
}

#pragma mark Dock Menu

/* applicationDockMenu
 * Return a menu with additional commands to be displayd on the application's
 * popup dock menu.
 */
-(NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	appDockMenu = [[NSMenu alloc] initWithTitle:@"DockMenu"];
	[appDockMenu addItem:copyOfMenuItemWithAction(@selector(refreshAllSubscriptions:))];
	[appDockMenu addItem:copyOfMenuItemWithAction(@selector(markAllSubscriptionsRead:))];
	return appDockMenu;
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
- (void)openURLsInDefaultBrowser:(NSArray *)urlArray {
	Preferences * prefs = [Preferences standardPreferences];
	
	// This line is a workaround for OS X bug rdar://4450641
	if (prefs.openLinksInBackground)
		[mainWindow orderFront:self];
	
	// Launch in the foreground or background as needed
	NSWorkspaceLaunchOptions lOptions = prefs.openLinksInBackground ? (NSWorkspaceLaunchWithoutActivation | NSWorkspaceLaunchDefault) : (NSWorkspaceLaunchDefault | NSWorkspaceLaunchDefault);
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
	NSView<BaseView> * theView = browserView.activeTabItemView;
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
	NSView<BaseView> * theView = browserView.activeTabItemView;
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
		
		/* As Safari does, 'shift' inverts this behavior. Use GetCurrentKeyModifiers() because [NSApp currentEvent] was created
		 * when the current event began, which may be when the contexual menu opened.
		 */
		if (((GetCurrentKeyModifiers() & (shiftKey | rightShiftKey)) != 0))
			openInBackground = !openInBackground;
		
		[self createNewTab:item.representedObject inBackground:openInBackground];
	}
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
	NSView<BaseView> * theView = browserView.activeTabItemView;
	[self showMainWindow:self];
	if (![theView isKindOfClass:[BrowserPane class]])
	{
		[self createNewTab:nil inBackground:NO];
		theView = browserView.activeTabItemView;
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
		
		/* As Safari does, 'shift' inverts this behavior. Use GetCurrentKeyModifiers() because [NSApp currentEvent] was created
		 * when the current event began, which may be when the contexual menu opened.
		 */
		if (((GetCurrentKeyModifiers() & (shiftKey | rightShiftKey)) != 0))
			openInBackground = !openInBackground;
		
		for (NSURL * url in urls)
			[self createNewTab:url inBackground:openInBackground];
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

/* newTab
 * Create a new empty tab.
 */
-(IBAction)newTab:(id)sender
{
	// Create a new empty tab in the foreground.
	[self createNewTab:nil inBackground:NO];
	
	// Make the address bar first responder.
	NSView<BaseView> * theView = browserView.activeTabItemView;
	BrowserPane * browserPane = (BrowserPane *)theView;
	[browserPane activateAddressBar];
}

/* downloadEnclosure
 * Downloads the enclosures of the currently selected articles
 */
-(IBAction)downloadEnclosure:(id)sender
{
	for (Article * currentArticle in articleController.markedArticleRange)
	{
		if (currentArticle.hasEnclosure)
		{
			[[DownloadManager sharedInstance] downloadFileFromURL:currentArticle.enclosure];
		}
	}
}

/* createNewTab
 * Open the specified URL in a new tab.
 */
-(void)createNewTab:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag
{
	BrowserPaneTemplate * newBrowserTemplate = [[BrowserPaneTemplate alloc] init];
	if (newBrowserTemplate)
	{
		BrowserPane * newBrowserPane = newBrowserTemplate.mainView;
		
		[browserView createNewTabWithView:newBrowserPane makeKey:!openInBackgroundFlag];
		[newBrowserPane setController:self];
		if (url != nil)
			[newBrowserPane loadURL:url inBackground:openInBackgroundFlag];
		else
			[browserView setTabItemViewTitle:newBrowserPane title:NSLocalizedString(@"New Tab", nil)];
		
	}
	if (didCompleteInitialisation)
			[browserView performSelector:@selector(saveOpenTabs) withObject:nil afterDelay:3];
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
	[mainWindow makeKeyAndOrderFront:self];
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
    NSSavePanel * panel = [NSSavePanel savePanel];
    
    // If multiple selections in the folder list, default to selected folders
    // for simplicity.
    if (foldersTree.countOfSelectedFolders > 1)
    {
        exportSelected.state = NSOnState;
        exportAll.state = NSOffState;
    }
    else
    {
        exportSelected.state = NSOffState;
        exportAll.state = NSOnState;
    }
    
    // Localise the strings
    [exportAll setTitle:NSLocalizedString(@"Export all subscriptions", nil)];
    [exportSelected setTitle:NSLocalizedString(@"Export selected subscriptions", nil)];
    [exportWithGroups setTitle:NSLocalizedString(@"Preserve group folders in exported file", nil)];
    
    panel.accessoryView = exportSaveAccessory;
    panel.allowedFileTypes = @[@"opml"];
    [panel beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger returnCode) {
        if (returnCode == NSOKButton)
        {
            [panel orderOut:self];
            
            NSInteger countExported = [Export exportToFile:panel.URL.path fromFoldersTree:foldersTree selection:(exportSelected.state == NSOnState) withGroups:(exportWithGroups.state == NSOnState)];
            
            if (countExported < 0)
            {
                NSBeginCriticalAlertSheet(NSLocalizedString(@"Cannot open export file message", nil),
                                          NSLocalizedString(@"OK", nil),
                                          nil,
                                          nil, NSApp.mainWindow, self,
                                          nil, nil, nil,
                                          NSLocalizedString(@"Cannot open export file message text", nil));
            }
            else
            {
                // Announce how many we successfully imported
                NSRunAlertPanel(NSLocalizedString(@"RSS Subscription Export Title", nil), NSLocalizedString(@"%d subscriptions successfully exported", nil), NSLocalizedString(@"OK", nil), nil, nil, countExported);
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
    [panel beginSheetModalForWindow:mainWindow
                  completionHandler: ^(NSInteger returnCode) {
                      if (returnCode == NSOKButton)
                      {
                          [panel orderOut:self];
                          [Import importFromFile:panel.URL.path];
                      }
                  }];
    panel = nil;
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
	return filterView.superview != nil;
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{
    if (mainWindow.keyWindow) {
	NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:NSLocalizedString(@"Open Reader Authentication Failed",nil)];
    [alert setInformativeText:NSLocalizedString(@"Make sure the username and password needed to access the Open Reader server are correctly set in Vienna's preferences.\nAlso check your network access.",nil)];
    alert.alertStyle = NSWarningAlertStyle;
    [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
    }
}

-(void)handleGoogleDownloadSubscriptions:(NSNotification *)nc {
	[[GoogleReader sharedManager] loadSubscriptions:nil];
}





/* handleShowFilterBar
 * Respond to the filter bar being shown or hidden programmatically.
 */
-(void)handleShowFilterBar:(NSNotification *)nc
{
	if (browserView.activeTabItemView == [browserView primaryTabItemView])
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
		NSView * parentView = articleController.mainArticleView.subviews[0];
		NSRect filterBarRect;
		NSRect mainRect;
		
		mainRect = parentView.bounds;
		filterBarRect = filterView.bounds;
		filterBarRect.size.width = mainRect.size.width;
		filterBarRect.origin.y = mainRect.size.height - filterBarRect.size.height;
		mainRect.size.height -= filterBarRect.size.height;
		
		[parentView.superview addSubview:filterView];
		filterView.frame = filterBarRect;
		if (!doAnimate)
			parentView.frame = mainRect;
		else
			[parentView resizeViewWithAnimation:mainRect withTag:MA_ViewTag_Filterbar];
		[parentView display];
		
		// Hook up the Tab ordering so Tab from the search field goes to the
		// article view.
		foldersTree.mainView.nextKeyView = filterSearchField;
		filterSearchField.nextKeyView = [browserView primaryTabItemView].mainView;
		
		// Set focus only if this was user initiated
		if (doAnimate)
			[mainWindow makeFirstResponder:filterSearchField];
	}
	if (!isVisible && self.filterBarVisible)
	{
		NSView * parentView = articleController.mainArticleView.subviews[0];
		NSRect filterBarRect;
		NSRect mainRect;
		
		mainRect = parentView.bounds;
		filterBarRect = filterView.bounds;
		mainRect.size.height += filterBarRect.size.height;
		
		[filterView removeFromSuperview];
		if (!doAnimate)
			parentView.frame = mainRect;
		else
			[parentView resizeViewWithAnimation:mainRect withTag:MA_ViewTag_Filterbar];
		[parentView display];
		
		// Fix up the tab ordering
		foldersTree.mainView.nextKeyView = [browserView primaryTabItemView].mainView;
		
		// Clear the filter, otherwise we end up with no way remove it!
		self.filterString = @"";
		if (doAnimate)
		{
			[self searchUsingFilterField:self];
			
			// If the focus was originally on the filter bar then we should
			// move it to the message list
			if (mainWindow.firstResponder == mainWindow)
				[mainWindow makeFirstResponder:[browserView primaryTabItemView].mainView];
		}
	}
}

#pragma mark Growl Delegate

/* growlNotify
 * Sends out the specified notification event if Growl is installed and ready.
 */
-(void)growlNotify:(id)notifyContext title:(NSString *)title description:(NSString *)description notificationName:(NSString *)notificationName
{
	Class GAB = NSClassFromString(@"GrowlApplicationBridge");
	if([GAB respondsToSelector:@selector(notifyWithTitle:description:notificationName:iconData:priority:isSticky:clickContext:identifier:)])
					[GAB setShouldUseBuiltInNotifications:NO];
					[GAB		notifyWithTitle:title
									description:description
							   notificationName:notificationName
									   iconData:nil
									   priority:0
									   isSticky:NO
								   clickContext:notifyContext];
}

/* growlNotificationWasClicked
 * Called when the user clicked a Growl notification balloon.
 */
-(void)growlNotificationWasClicked:(id)clickContext
{
	NSDictionary * contextDict = (NSDictionary *)clickContext;
	NSInteger contextValue = [[contextDict valueForKey:@"ContextType"] integerValue];
	
	if (contextValue == MA_GrowlContext_RefreshCompleted)
	{
		[self openVienna:self];
		Folder * unreadArticles = [db folderFromName:NSLocalizedString(@"Unread Articles", nil)];
		if (unreadArticles != nil)
			[foldersTree selectFolder:unreadArticles.itemId];
		return;
	}
	
	// Successful download - show file in Finder. If we fail then we don't
	// care. Definitely don't want to be popping up an error dialog.
	if (contextValue == MA_GrowlContext_DownloadCompleted)
	{
		NSString * pathToFile = [contextDict valueForKey:@"ContextData"];
		[[NSWorkspace sharedWorkspace] selectFile:pathToFile inFileViewerRootedAtPath:@""];
		return;
	}
}

/* registrationDictionaryForGrowl
 * Called by Growl to request the notification dictionary.
 */
-(NSDictionary *)registrationDictionaryForGrowl
{
	
	NSDictionary *notificationsWithDescriptions = @{NSLocalizedString(@"Growl refresh completed", ""): @"Growl refresh completed",
		NSLocalizedString(@"Growl download completed", ""): @"Growl download completed",
		NSLocalizedString(@"Growl download failed", ""): @"Growl download failed"};

	NSArray *allNotesArray = notificationsWithDescriptions.allKeys;
	NSArray *defNotesArray = [allNotesArray copy];
	
	NSDictionary *regDict = @{GROWL_APP_NAME: self.appName, 
							 GROWL_NOTIFICATIONS_ALL: allNotesArray, 
							 GROWL_NOTIFICATIONS_DEFAULT: defNotesArray,
							 GROWL_NOTIFICATIONS_HUMAN_READABLE_NAMES: notificationsWithDescriptions};


	return regDict;
}

/* initSortMenu
 * Create the sort popup menu.
 */
-(void)initSortMenu
{
	NSMenu * sortSubmenu = [[NSMenu alloc] initWithTitle:@"Sort By"];
	
	// Add the fields which are sortable to the menu.
	for (Field * field in [db arrayOfFields])
	{
		// Filter out columns we don't sort on. Later we should have an attribute in the
		// field object itself based on which columns we can sort on.
		if (field.tag != MA_FieldID_Parent &&
			field.tag != MA_FieldID_GUID &&
			field.tag != MA_FieldID_Comments &&
			field.tag != MA_FieldID_Deleted &&
			field.tag != MA_FieldID_Headlines &&
			field.tag != MA_FieldID_Summary &&
			field.tag != MA_FieldID_Link &&
			field.tag != MA_FieldID_Text &&
			field.tag != MA_FieldID_EnclosureDownloaded &&
			field.tag != MA_FieldID_Enclosure)
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
	NSMenu * columnsSubMenu = [[NSMenu alloc] initWithTitle:@"Columns"];
	
	for (Field * field in [db arrayOfFields])
	{
		// Filter out columns we don't view in the article list. Later we should have an attribute in the
		// field object based on which columns are visible in the tableview.
		if (field.tag != MA_FieldID_Text && 
			field.tag != MA_FieldID_GUID &&
			field.tag != MA_FieldID_Comments &&
			field.tag != MA_FieldID_Deleted &&
			field.tag != MA_FieldID_Parent &&
			field.tag != MA_FieldID_Headlines &&
			field.tag != MA_FieldID_EnclosureDownloaded)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:field.displayName action:@selector(doViewColumn:) keyEquivalent:@""];
			menuItem.representedObject = field;
			[columnsSubMenu addItem:menuItem];
		}
	}
	columnsMenu.submenu = columnsSubMenu;
}

/* initScriptsMenu
 * Look in the Scripts folder and if there are any scripts, add a Scripts menu and populate
 * it with the names of the scripts we've found.
 *
 * Note that there are two places we look for scripts: inside the app resource for scripts that
 * are bundled with the application, and in the standard Mac OSX application script folder which
 * is where the sysem-wide script menu also looks.
 */
-(void)initScriptsMenu
{
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
	if (count > 0)
	{
		NSMenu * scriptsMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Scripts"];
		
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
		
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"More Scripts...", nil) action:@selector(moreScripts:) keyEquivalent:@""];
		[scriptsMenu addItem:menuItem];
		
		// If this is the first call to initScriptsMenu, create the scripts menu. Otherwise we just
		// update the one we have.
		if (scriptsMenuItem != nil)
		{
			[NSApp.mainMenu removeItem:scriptsMenuItem];
		}
		
		scriptsMenuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Scripts" action:NULL keyEquivalent:@""];
		scriptsMenuItem.image = [NSImage imageNamed:@"scriptMenu.tiff"];
		
		NSInteger helpMenuIndex = NSApp.mainMenu.numberOfItems - 1;
		[NSApp.mainMenu insertItem:scriptsMenuItem atIndex:helpMenuIndex];
		scriptsMenuItem.submenu = scriptsMenu;
		
	}
}

/* getStylesMenu
 * Returns a menu with a list of built-in and external styles. (Note that in the event of
 * duplicates the styles in the external Styles folder wins. This is intended to allow the user to
 * override the built-in styles if necessary).
 */
-(NSMenu *)getStylesMenu
{
	NSMenu * stylesSubMenu = [[NSMenu alloc] initWithTitle:@"Style"];
	
	// Reinitialise the styles map
	NSDictionary * stylesMap = [ArticleView loadStylesMap];
	
	// Add the contents of the stylesPathMappings dictionary keys to the menu sorted by key name.
	NSArray * sortedMenuItems = [stylesMap.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSInteger count = sortedMenuItems.count;
	NSInteger index;
	
	for (index = 0; index < count; ++index)
	{
		NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:sortedMenuItems[index] action:@selector(doSelectStyle:) keyEquivalent:@""];
		[stylesSubMenu addItem:menuItem];
	}
	
	// Append a link to More Styles...
	[stylesSubMenu addItem:[NSMenuItem separatorItem]];
	NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"More Styles...", nil) action:@selector(moreStyles:) keyEquivalent:@""];
	[stylesSubMenu addItem:menuItem];
	return stylesSubMenu;
}

/* initFiltersMenu
 * Populate both the Filters submenu on the View menu and the Filters popup menu on the Filter
 * button in the article list. We need separate menus since the latter is eventually configured
 * to use a smaller font than the former.
 */
-(void)initFiltersMenu
{
	NSMenu * filterSubMenu = [[NSMenu alloc] initWithTitle:@"Filter By"];
	NSMenu * filterPopupMenu = [[NSMenu alloc] initWithTitle:@""];
	
	NSArray * filtersArray = [ArticleFilter arrayOfFilters];
	NSInteger count = filtersArray.count;
	NSInteger index;
	
	for (index = 0; index < count; ++index)
	{
		ArticleFilter * filter = filtersArray[index];
		
		NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString([filter name], nil) action:@selector(changeFiltering:) keyEquivalent:@""];
		menuItem.tag = filter.tag;
		[filterSubMenu addItem:menuItem];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString([filter name], nil) action:@selector(changeFiltering:) keyEquivalent:@""];
		menuItem.tag = filter.tag;
		[filterPopupMenu addItem:menuItem];
	}
	
	// Add it to the Filters menu
	filtersMenu.submenu = filterSubMenu;
	filterViewPopUp.menu = filterPopupMenu;
	
	// Sync the popup selection with user preferences
	NSInteger indexOfDefaultItem = [filterViewPopUp indexOfItemWithTag:[Preferences standardPreferences].filterMode];
	if (indexOfDefaultItem != -1)
	{
		[filterViewPopUp selectItemAtIndex:indexOfDefaultItem];
		currentFilterTextField.stringValue = [filterViewPopUp itemAtIndex:indexOfDefaultItem].title;
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
		mainWindow.title = self.appName;
		return;	
	}	
	
	mainWindow.title = [NSString stringWithFormat:@"%@ (%li %@)", self.appName, (long)currentCountOfUnread, NSLocalizedString(@"Unread", nil)];
	
	// Exit now if we're not showing the unread count on the application icon
	if (([Preferences standardPreferences].newArticlesNotification
		& MA_NewArticlesNotification_Badge) ==0)
			return;
	
	NSString * countdown = [NSString stringWithFormat:@"%li", (long)currentCountOfUnread];
	NSApp.dockTile.badgeLabel = countdown;

	} // @synchronized
}

/* handleAbout
 * Display our About Vienna... window.
 */
-(IBAction)handleAbout:(id)sender
{
	NSDictionary * fileAttributes = [NSBundle mainBundle].infoDictionary;
	LOG_EXPR(fileAttributes);
	NSString * version = fileAttributes[@"CFBundleShortVersionString"];
	NSString * versionString = [NSString stringWithFormat:NSLocalizedString(@"Version %@", nil), version];
	NSDictionary * d = @{@"ApplicationVersion": versionString, @"Version": @""};
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanelWithOptions:d];
}

/* emptyTrash
 * Delete all articles from the Trash folder.
 */
-(IBAction)emptyTrash:(id)sender
{
	NSBeginCriticalAlertSheet(NSLocalizedString(@"Empty Trash message", nil),
							  NSLocalizedString(@"Empty", nil),
							  NSLocalizedString(@"Cancel", nil),
							  nil, NSApp.mainWindow, self,
							  @selector(doConfirmedEmptyTrash:returnCode:contextInfo:), nil, nil,
							  NSLocalizedString(@"Empty Trash message text", nil));
}

/* doConfirmedEmptyTrash
 * This function is called after the user has dismissed
 * the confirmation sheet.
 */
-(void)doConfirmedEmptyTrash:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn)
	{
		[self clearUndoStack];
		[db purgeDeletedArticles];
	}
}

/* keyboardShortcutsHelp
 * Display the Keyboard Shortcuts help page.
 */
-(IBAction)keyboardShortcutsHelp:(id)sender
{
	GotoHelpPage((CFStringRef)@"keyboard.html", NULL);
}

/* printDocument
 * Print the selected articles in the article window.
 */
-(IBAction)printDocument:(id)sender
{
	[browserView.activeTabItemView printDocument:sender];
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
	return articleController.selectedArticle;
}

/* currentFolderId
 * Return the ID of the currently selected folder whose articles are shown in
 * the article window.
 */
-(NSInteger)currentFolderId
{
	return articleController.currentFolderId;
}

/* selectFolder
 * Select the specified folder.
 */
-(void)selectFolder:(NSInteger)folderId
{
	[foldersTree selectFolder:folderId];
}

/* updateCloseCommands
 * Update the keystrokes assigned to the Close Tab and Close Window
 * commands depending on whether any tabs are opened.
 */
-(void)updateCloseCommands
{
	if (browserView.countOfTabs < 2 || !mainWindow.keyWindow)
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
		
		NSMenu * statusBarMenu = [[NSMenu alloc] initWithTitle:@"StatusBarMenu"];
		[statusBarMenu addItem:menuItemWithTitleAndAction(NSLocalizedString(@"Open Vienna", nil), @selector(openVienna:))];
		[statusBarMenu addItem:[NSMenuItem separatorItem]];
		[statusBarMenu addItem:copyOfMenuItemWithAction(@selector(refreshAllSubscriptions:))];
		[statusBarMenu addItem:copyOfMenuItemWithAction(@selector(markAllSubscriptionsRead:))];
		[statusBarMenu addItem:[NSMenuItem separatorItem]];
		[statusBarMenu addItem:copyOfMenuItemWithAction(@selector(showPreferencePanel:))];
		[statusBarMenu addItem:copyOfMenuItemWithAction(@selector(handleAbout:))];
		[statusBarMenu addItem:[NSMenuItem separatorItem]];
		[statusBarMenu addItem:copyOfMenuItemWithAction(@selector(exitVienna:))];
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
            NSImage *statusBarImage = [NSImage imageNamed:@"statusBarIcon.png"];
            [statusBarImage setTemplate:YES];
            appStatusItem.image = statusBarImage;
			[appStatusItem setTitle:nil];
		}
		else
		{
            NSImage *statusBarImage = [NSImage imageNamed:@"statusBarIconUnread.png"];
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
	[self createNewSubscription:linkPath underFolder:foldersTree.groupParentSelection afterChild:-1];
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
	Folder * folder = [db folderFromID:foldersTree.actualSelection];
	[self doEditFolder:folder];
}

/* doEditFolder
 * Handles an edit action on the specified folder.
 */
-(void)doEditFolder:(Folder *)folder
{
	if (IsRSSFolder(folder))
	{
		[self.rssFeed editSubscription:mainWindow folderId:folder.itemId];
	}
	else if (IsSmartFolder(folder))
	{
		if (!smartFolder)
			smartFolder = [[SmartFolder alloc] initWithDatabase:db];
		[smartFolder loadCriteria:mainWindow folderId:folder.itemId];
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
	[articleController displayFolder:newFolderId];
	[self updateSearchPlaceholderAndSearchMethod];
	
	// Make sure article viewer is active
	[browserView setActiveTabToPrimaryTab];
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
	[foldersTree updateAlternateMenuTitle];
	[articleController updateAlternateMenuTitle];
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
	[articleController updateVisibleColumns];
	[articleController saveTableSettings];
}

/* doSortColumn
 * Handle the user picking a sort column item from the Sort By submenu
 */
-(IBAction)doSortColumn:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	Field * field = menuItem.representedObject;
	
	NSAssert1(field, @"Somehow got a nil representedObject for Sort column sub-menu item '%@'", [menuItem title]);
	[articleController sortByIdentifier:field.name];
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
	[articleController sortAscending:ascending];
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
	if (newView == [browserView primaryTabItemView])
	{
		if (self.selectedArticle == nil)
			[mainWindow makeFirstResponder:foldersTree.mainView];
		else
			[mainWindow makeFirstResponder:[browserView primaryTabItemView].mainView];		
	}
	else
	{
		BrowserPane * webPane = (BrowserPane *)newView;
		[mainWindow makeFirstResponder:webPane.mainView];
	}
	[self updateStatusBarFilterButtonVisibility];
	[self updateSearchPlaceholderAndSearchMethod];
	[self setStatusMessage:nil persist:NO];
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
	if (folderId == articleController.currentFolderId)
		[self updateSearchPlaceholderAndSearchMethod];
}

/* handleRefreshStatusChange
 * Handle a change of the refresh status.
 */
-(void)handleRefreshStatusChange:(NSNotification *)nc
{
	if (APP.refreshing)
	{
		// Save the date/time of this refresh so we do the right thing when
		// we apply the filter.
		[[Preferences standardPreferences] setObject:[NSCalendarDate date] forKey:MAPref_LastRefreshDate];
		
		// Toggle the refresh button
		ToolbarItem * item = [self toolbarItemWithIdentifier:@"Refresh"];
		item.action = @selector(cancelAllRefreshesToolbar:);
		[item setButtonImage:@"cancelRefreshButton"];
		
		[self startProgressIndicator];
	}
	else
	{
		// Run the auto-expire now
		Preferences * prefs = [Preferences standardPreferences];
		[db purgeArticlesOlderThanDays:prefs.autoExpireDuration];
		
		[self setStatusMessage:NSLocalizedString(@"Refresh completed", nil) persist:YES];
		[self stopProgressIndicator];
		
		// Toggle the refresh button
		ToolbarItem * item = [self toolbarItemWithIdentifier:@"Refresh"];
		item.action = @selector(refreshAllSubscriptions:);
		[item setButtonImage:@"refreshButton"];
		
		[self showUnreadCountOnApplicationIconAndWindowTitle];
		
		// Bounce the dock icon for 1 second if the bounce method has been selected.
		NSInteger newUnread = [RefreshManager sharedManager].countOfNewArticles + [GoogleReader sharedManager].countOfNewArticles;
		if (newUnread > 0 && ((prefs.newArticlesNotification & MA_NewArticlesNotification_Bounce) != 0))
			[NSApp requestUserAttention:NSInformationalRequest];
		
		// Growl notification
		if (newUnread > 0)
		{
			NSMutableDictionary * contextDict = [NSMutableDictionary dictionary];
			[contextDict setValue:@MA_GrowlContext_RefreshCompleted forKey:@"ContextType"];
			
			[self growlNotify:contextDict
						title:NSLocalizedString(@"New articles retrieved", nil)
				  description:[NSString stringWithFormat:NSLocalizedString(@"New unread articles retrieved", nil), newUnread]
			 notificationName:NSLocalizedString(@"Growl refresh completed", nil)];
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
	NSArray * articleArray = articleController.markedArticleRange;
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
		
		if (!db.readOnly)
            [articleController markReadByArray:articlesWithLinks readFlag:YES];
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
	[browserView.activeTabItemView handleGoForward:sender];
}

/* goBack
 * In article view, back track through the list of articles displayed. In 
 * web view, go to the previous web page.
 */
-(IBAction)goBack:(id)sender
{
	[browserView.activeTabItemView handleGoBack:sender];
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
			searchField.stringValue = APP.currentTextSelection;
			[searchPanel setSearchString:APP.currentTextSelection];
			break;
			
		case NSFindPanelActionShowFindPanel:
			[self setFocusToSearchField:self];
			break;
			
		default:
			[browserView.activeTabItemView performFindPanelAction:[sender tag]];
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
				if (mainWindow.firstResponder == [browserView primaryTabItemView].mainView)
				{
					[mainWindow makeFirstResponder:foldersTree.mainView];
					return YES;
				}
			}
			return NO;
			
		case NSRightArrowFunctionKey:
			if (flags & (NSCommandKeyMask | NSAlternateKeyMask))
				return NO;
			else
			{
				if (mainWindow.firstResponder == foldersTree.mainView)
				{
					[browserView setActiveTabToPrimaryTab];
					if (self.selectedArticle == nil)
						[articleController ensureSelectedArticle:NO];
					[mainWindow makeFirstResponder:(self.selectedArticle != nil) ? [browserView primaryTabItemView].mainView : foldersTree.mainView];
					return YES;
				}
			}
			return NO;
			
		case NSDeleteFunctionKey:
		case NSDeleteCharacter:
			if (mainWindow.firstResponder == foldersTree.mainView)
			{
				[self deleteFolder:self];
				return YES;
			}
			else if (mainWindow.firstResponder == (articleController.mainArticleView).mainView)
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
				[mainWindow makeFirstResponder:filterSearchField];
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
			if (mainWindow.firstResponder == foldersTree.mainView)
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
			WebView * view = browserView.activeTabItemView.webView;
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

/* toggleOptionKeyButtonStates
 * Toggles the appearance and function of the "Add" button while the option-key is pressed. 
 * Works and looks exactly as in the iApps. Currently only for toggling "Add Sub/Add Smart Folder", 
 * but of course it could be used for all other buttons as well.
 */
-(void)toggleOptionKeyButtonStates
{
	ToolbarItem * item = [self toolbarItemWithIdentifier:@"Subscribe"];
	
	if (!(NSApp.currentEvent.modifierFlags & NSAlternateKeyMask)) 
	{
		[item setButtonImage:@"subscribeButton"];
		item.action = @selector(newSubscription:);
	}
	else
	{
		[item setButtonImage:@"smartFolderButton"];
		item.action = @selector(newSmartFolder:);
	}
}

/* toolbarItemWithIdentifier
 * Returns the toolbar button that corresponds to the specified identifier.
 */
-(ToolbarItem *)toolbarItemWithIdentifier:(NSString *)theIdentifier
{
	for (ToolbarItem * theItem in mainWindow.toolbar.visibleItems)
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
	if (!db.readOnly)
		[articleController markAllReadByArray:arrayOfFolders withUndo:YES withRefresh:YES];
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
		//[browserView setActiveTabToPrimaryTab];
		//[foldersTree selectFolder:[folder itemId]];
		return;
	}
	
	// Create then select the new folder.
	NSInteger folderId = [db addGoogleReaderFolder:title
                                       underParent:parentId
                                        afterChild:predecessorId
                                   subscriptionURL:url];
		
	if (folderId != -1)
	{
		//		[foldersTree selectFolder:folderId];
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
		[browserView setActiveTabToPrimaryTab];
		[foldersTree selectFolder:folder.itemId];
		return;
	}
	
	// Create then select the new folder.
	if ([Preferences standardPreferences].syncGoogleReader && [Preferences standardPreferences].prefersGoogleNewSubscription)
	{	//creates in Google
		GoogleReader * myGoogle = [GoogleReader sharedManager];
		[myGoogle subscribeToFeed:urlString];
		NSString * folderName = [db folderFromID:parentId].name;
		if (folderName != nil)
			[myGoogle setFolderName:folderName forFeed:urlString set:TRUE];
		[myGoogle loadSubscriptions:nil];

	}
	else
	{ //creates locally
		NSInteger folderId = [db addRSSFolder:[Database untitledFeedFolderName]
                                  underParent:parentId
                                   afterChild:predecessorId
                              subscriptionURL:urlString];

		if (folderId != -1)
		{
			[foldersTree selectFolder:folderId];
            if (isAccessible(urlString))
			{
				Folder * folder = [db folderFromID:folderId];
				[[RefreshManager sharedManager] refreshSubscriptionsAfterSubscribe:@[folder] ignoringSubscriptionStatus:NO];
            } else if ([urlString hasPrefix:@"file"]) {
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
	[self.rssFeed newSubscription:mainWindow underParent:foldersTree.groupParentSelection initialURL:nil];
}

/* newSmartFolder
 * Create a new smart folder.
 */
-(IBAction)newSmartFolder:(id)sender
{
	if (!smartFolder)
		smartFolder = [[SmartFolder alloc] initWithDatabase:db];
	[smartFolder newCriteria:mainWindow underParent:foldersTree.groupParentSelection];
}

/* newGroupFolder
 * Display the pane for a new group folder.
 */
-(IBAction)newGroupFolder:(id)sender
{
	if (!groupFolder)
		groupFolder = [[NewGroupFolder alloc] init];
	[groupFolder newGroupFolder:mainWindow underParent:foldersTree.groupParentSelection];
}

/* restoreMessage
 * Restore a message in the Trash folder back to where it came from.
 */
-(IBAction)restoreMessage:(id)sender
{
	Folder * folder = [db folderFromID:articleController.currentFolderId];
	if (IsTrashFolder(folder) && self.selectedArticle != nil && !db.readOnly)
	{
		NSArray * articleArray = articleController.markedArticleRange;
		[articleController markDeletedByArray:articleArray deleteFlag:NO];
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
		Folder * folder = [db folderFromID:articleController.currentFolderId];
		if (!IsTrashFolder(folder))
		{
			NSArray * articleArray = articleController.markedArticleRange;
			[articleController markDeletedByArray:articleArray deleteFlag:YES];
		}
		else
		{
			NSBeginCriticalAlertSheet(NSLocalizedString(@"Delete selected message", nil),
									  NSLocalizedString(@"Delete", nil),
									  NSLocalizedString(@"Cancel", nil),
									  nil, NSApp.mainWindow, self,
									  @selector(doConfirmedDelete:returnCode:contextInfo:), nil, nil,
									  NSLocalizedString(@"Delete selected message text", nil));
		}
	}
}

/* doConfirmedDelete
 * This function is called after the user has dismissed
 * the confirmation sheet.
 */
-(void)doConfirmedDelete:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn)
	{
		NSArray * articleArray = articleController.markedArticleRange;
		[articleController deleteArticlesByArray:articleArray];
		
		// Blow away the undo stack here since undo actions may refer to
		// articles that have been deleted. This is a bit of a cop-out but
		// it's the easiest approach for now.
		[self clearUndoStack];
	}
}

/* sourceWindowWillClose
 * Called when the XML source window is about to close
 */
-(void)sourceWindowWillClose:(NSNotification *)notification
{
	XMLSourceWindow * sourceWindow = notification.object;
	[sourceWindows removeObject:sourceWindow];
}



/* showXMLSource
 * Show the Downloads window, bringing it to the front if necessary.
 */
-(IBAction)showXMLSource:(id)sender
{
	for (Folder * folder in foldersTree.selectedFolders)
	{
		if (folder.RSSFolder)
		{
			XMLSourceWindow * sourceWindow = [[XMLSourceWindow alloc] initWithFolder:folder];
			
			if (sourceWindow != nil)
			{
				if (sourceWindows == nil)
					sourceWindows = [[NSMutableArray alloc] init];
				[sourceWindows addObject:sourceWindow];
			}
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sourceWindowWillClose:) name:NSWindowWillCloseNotification object:sourceWindow];
			
			[sourceWindow showWindow:self];
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

/* toggleActivityViewer
 * Toggle display of the activity viewer windows.
 */
-(IBAction)toggleActivityViewer:(id)sender
{	
	if (activityViewer == nil)
		activityViewer = [[ActivityViewer alloc] init];
	if (activityViewer != nil)
	{
		NSWindow * activityWindow = activityViewer.window;
		if (!activityWindow.visible)
			[activityViewer showWindow:self];
		else
			[activityWindow performClose:self];
	}
}

/* viewFirstUnread
 * Moves the selection to the first unread article.
 */
-(IBAction)viewFirstUnread:(id)sender
{
	[browserView setActiveTabToPrimaryTab];
	if (db.countOfUnread > 0)
		[articleController displayFirstUnread];
	[mainWindow makeFirstResponder:(self.selectedArticle != nil) ? [browserView primaryTabItemView].mainView : foldersTree.mainView];
}

/* viewNextUnread
 * Moves the selection to the next unread article.
 */
-(IBAction)viewNextUnread:(id)sender
{
	[browserView setActiveTabToPrimaryTab];
	if (db.countOfUnread > 0)
		[articleController displayNextUnread];
	[mainWindow makeFirstResponder:(self.selectedArticle != nil) ? [browserView primaryTabItemView].mainView : foldersTree.mainView];
}

/* clearUndoStack
 * Clear the undo stack for instances when the last action invalidates
 * all previous undoable actions.
 */
-(void)clearUndoStack
{
	[mainWindow.undoManager removeAllActions];
}

/* skipFolder
 * Mark all articles in the current folder read then skip to the next folder with
 * unread articles.
 */
-(IBAction)skipFolder:(id)sender
{
	if (!db.readOnly)
	{
		[articleController markAllReadByArray:foldersTree.selectedFolders withUndo:YES withRefresh:YES];
		[self viewNextUnread:self];
	}
}

#pragma mark Marking Articles 

/* markAllRead
 * Mark all articles read in the selected folders.
 */
-(IBAction)markAllRead:(id)sender
{
	if (!db.readOnly)
		[articleController markAllReadByArray:foldersTree.selectedFolders withUndo:YES withRefresh:YES];
}

/* markAllSubscriptionsRead
 * Mark all subscriptions as read
 */
-(IBAction)markAllSubscriptionsRead:(id)sender
{
	if (!db.readOnly)
	{
		[articleController markAllReadByArray:[foldersTree folders:0] withUndo:YES withRefresh:YES];
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
		NSArray * articleArray = articleController.markedArticleRange;
		[articleController markReadByArray:articleArray readFlag:!theArticle.read];
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
		NSArray * articleArray = articleController.markedArticleRange;
		[articleController markReadByArray:articleArray readFlag:YES];
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
		NSArray * articleArray = articleController.markedArticleRange;
		[articleController markReadByArray:articleArray readFlag:NO];
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
		NSArray * articleArray = articleController.markedArticleRange;
		[articleController markFlaggedByArray:articleArray flagged:!theArticle.flagged];
	}
}

/* renameFolder
 * Renames the current folder
 */
-(IBAction)renameFolder:(id)sender
{
	[foldersTree renameFolder:foldersTree.actualSelection];
}

- (void)addFoldersIn:(Folder *)folder toArray:(NSMutableArray *)array 
{
    [array addObject:folder];
    if (IsGroupFolder(folder))
        for (Folder * f in [db arrayOfFolders:folder.itemId])
            [self addFoldersIn:f toArray:array];
}

/* deleteFolder
 * Delete the current folder.
 */
-(IBAction)deleteFolder:(id)sender
{
	NSMutableArray * selectedFolders = [NSMutableArray arrayWithArray:foldersTree.selectedFolders];
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
		if (IsSmartFolder(folder))
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete smart folder text", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete smart folder", nil);
		}
		else if (IsSearchFolder(folder))
			needPrompt = NO;
		else if (IsRSSFolder(folder))
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete RSS feed text", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete RSS feed", nil);
		}
		else if (IsGoogleReaderFolder(folder))
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete Open Reader RSS feed text", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete Open Reader RSS feed", nil);
		}
		else if (IsGroupFolder(folder))
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete group folder text", nil), folder.name];
			alertTitle = NSLocalizedString(@"Delete group folder", nil);
		}
		else if (IsTrashFolder(folder))
			return;
		else
			NSAssert1(false, @"Unhandled folder type in deleteFolder: %@", [folder name]);
	}
	else
	{
		alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete multiple folders text", nil), count];
		alertTitle = NSLocalizedString(@"Delete multiple folders", nil);
	}
	
	// Get confirmation first
	if (needPrompt)
	{
		// Security: folder name could contain formatting characters, so don't use alertBody as format string.
		NSInteger returnCode = NSRunAlertPanel(alertTitle, @"%@", NSLocalizedString(@"Delete", nil), NSLocalizedString(@"Cancel", nil), nil, alertBody);
		if (returnCode == NSAlertAlternateReturn)
			return;
	}
	

	if (smartFolder != nil)
		[smartFolder doCancel:nil];
	if ([(NSControl *)foldersTree.mainView abortEditing])
		[mainWindow makeFirstResponder:foldersTree.mainView];
	
	
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
		if (folder.itemId == articleController.currentFolderId && index < count - 1)
		{
			[selectedFolders insertObject:folder atIndex:count];
			++count;
			continue;
		}
		if (!IsTrashFolder(folder))
		{
			// Create a status string
			NSString * deleteStatusMsg = [NSString stringWithFormat:NSLocalizedString(@"Delete folder status", nil), folder.name];
			[self setStatusMessage:deleteStatusMsg persist:NO];
			
			// Now call the database to delete the folder.
			[db deleteFolder:folder.itemId];
            
			if (IsGoogleReaderFolder(folder)) {
				NSLog(@"Unsubscribe Open Reader folder");
				[[GoogleReader sharedManager] unsubscribeFromFeed:folder.feedURL];
			}
		}
	}
	
	// Unread count may have changed
	[self setStatusMessage:nil persist:NO];
	[self showUnreadCountOnApplicationIconAndWindowTitle];
}

/* getInfo
 * Display the Info panel for the selected feeds.
 */
-(IBAction)getInfo:(id)sender
{
	NSInteger folderId = foldersTree.actualSelection;
	if (folderId > 0)
		[[InfoWindowManager infoWindowManager] showInfoWindowForFolder:folderId];
}

/* unsubscribeFeed
 * Subscribe or re-subscribe to a feed.
 */
-(IBAction)unsubscribeFeed:(id)sender
{
	NSArray * selectedFolders = [NSArray arrayWithArray:foldersTree.selectedFolders];
	NSInteger count = selectedFolders.count;
	NSInteger index;
	
	for (index = 0; index < count; ++index)
	{
		Folder * folder = selectedFolders[index];
        
        if (IsUnsubscribed(folder)) {
            // Currently unsubscribed, so re-subscribe locally
            [[Database sharedManager] clearFlag:MA_FFlag_Unsubscribed forFolder:folder.itemId];
        } else {
            // Currently subscribed, so unsubscribe locally
            [[Database sharedManager] setFlag:MA_FFlag_Unsubscribed forFolder:folder.itemId];
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
	NSMutableArray * selectedFolders = [NSMutableArray arrayWithArray:foldersTree.selectedFolders];
	NSInteger count = selectedFolders.count;
	NSInteger index;
	
	for (index = 0; index < count; ++index)
	{
		Folder * folder = selectedFolders[index];
		NSInteger folderID = folder.itemId;
		
		if (loadFullHTMLPages)
		{
			[folder setFlag:MA_FFlag_LoadFullHTML];
            [[Database sharedManager] setFlag:MA_FFlag_LoadFullHTML forFolder:folderID];
		}
		else
		{
			[folder clearFlag:MA_FFlag_LoadFullHTML];
            [[Database sharedManager] clearFlag:MA_FFlag_LoadFullHTML forFolder:folderID];
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
	Folder * folder = (thisArticle) ? [db folderFromID:thisArticle.folderId] : [db folderFromID:foldersTree.actualSelection];
	if (thisArticle || IsRSSFolder(folder) || IsGoogleReaderFolder(folder))
		[self openURLFromString:folder.homePage inPreferredBrowser:YES];
}

/* viewSourceHomePageInAlternateBrowser
 * Display the web site associated with this feed, if there is one, in non-preferred browser.
 */
-(IBAction)viewSourceHomePageInAlternateBrowser:(id)sender
{
	Article * thisArticle = self.selectedArticle;
	Folder * folder = (thisArticle) ? [db folderFromID:thisArticle.folderId] : [db folderFromID:foldersTree.actualSelection];
	if (thisArticle || IsRSSFolder(folder) || IsGoogleReaderFolder(folder))
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

/* showAcknowledgements
 * Display the acknowledgements document in a new tab.
 */
-(IBAction)showAcknowledgements:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
	NSString * pathToAckFile = [thisBundle pathForResource:@"Acknowledgements" ofType:@"html"];
	if (pathToAckFile != nil)
	{
		[self createNewTab:[NSURL fileURLWithPath:pathToAckFile isDirectory:NO] inBackground:NO];
	}
}

#pragma mark Tabs

/* previousTab
 * Display the previous tab, if there is one.
 */
-(IBAction)previousTab:(id)sender
{
	[browserView showPreviousTab];
}

/* nextTab
 * Display the next tab, if there is one.
 */
-(IBAction)nextTab:(id)sender
{
	[browserView showNextTab];
}

/* closeAllTabs
 * Closes all tab windows.
 */
-(IBAction)closeAllTabs:(id)sender
{
	[browserView closeAllTabs];
}

/* closeTab
 * Close the active tab unless it's the primary view.
 */
-(IBAction)closeTab:(id)sender
{
	[browserView closeTabItemView:browserView.activeTabItemView];
}

/* reloadPage
 * Reload the web page.
 */
-(IBAction)reloadPage:(id)sender
{
	NSView<BaseView> * theView = browserView.activeTabItemView;
	if ([theView isKindOfClass:[BrowserPane class]])
		[theView performSelector:@selector(handleReload:)];
}

/* stopReloadingPage
 * Cancel current reloading of a web page.
 */
-(IBAction)stopReloadingPage:(id)sender
{
	NSView<BaseView> * theView = browserView.activeTabItemView;
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
	NSView<BaseView> * theView = browserView.activeTabItemView;
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		[currentFilterTextField setHidden: YES];
		[filterIconInStatusBarButton setHidden: YES];
	}
	else {
		[currentFilterTextField setHidden: NO];
		[filterIconInStatusBarButton setHidden: NO];
	}
}

/* updateSearchPlaceholder
 * Update the search placeholder string in the search field depending on the view in
 * the active tab.
 */
-(void)updateSearchPlaceholderAndSearchMethod
{
	NSView<BaseView> * theView = browserView.activeTabItemView;
	Preferences * prefs = [Preferences standardPreferences];
	
	// START of rather verbose implementation of switching between "Search all articles" and "Search current web page".
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		// If the current view is a browser view and "Search all articles" is the current SearchMethod, switch to "Search current webpage"
		if ([prefs.searchMethod.friendlyName isEqualToString:[SearchMethod searchAllArticlesMethod].friendlyName])
		{
			for (NSMenuItem * menuItem in ((NSSearchFieldCell *)searchField.cell).searchMenuTemplate.itemArray)
			{
				if ([[menuItem.representedObject friendlyName] isEqualToString:[SearchMethod searchCurrentWebPageMethod].friendlyName])
				{
					[searchField.cell setPlaceholderString:NSLocalizedString([[SearchMethod searchCurrentWebPageMethod] friendlyName], nil)];
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
			for (NSMenuItem * menuItem in ((NSSearchFieldCell *)searchField.cell).searchMenuTemplate.itemArray)
			{
				if ([[menuItem.representedObject friendlyName] isEqualToString:[SearchMethod searchAllArticlesMethod].friendlyName])
				{
					[searchField.cell setPlaceholderString:NSLocalizedString([[SearchMethod searchAllArticlesMethod] friendlyName], nil)];
					[Preferences standardPreferences].searchMethod = menuItem.representedObject;
				}
			}
		}
		else
		{
			[searchField.cell setPlaceholderString:NSLocalizedString([[prefs searchMethod] friendlyName], nil)];
		}
	// END of switching between "Search all articles" and "Search current web page".
	}
	
	if ([Preferences standardPreferences].layout == MA_Layout_Unified)
	{
		[filterSearchField.cell setSendsWholeSearchString:YES];
		((NSSearchFieldCell *)filterSearchField.cell).placeholderString = articleController.searchPlaceholderString;
	}
	else
	{
		[filterSearchField.cell setSendsWholeSearchString:NO];
		((NSSearchFieldCell *)filterSearchField.cell).placeholderString = articleController.searchPlaceholderString;
	}
}

#pragma mark Searching

/* setFocusToSearchField
 * Put the input focus on the search field.
 */
-(IBAction)setFocusToSearchField:(id)sender
{
	if (mainWindow.toolbar.visible && [self toolbarItemWithIdentifier:@"SearchItem"] && mainWindow.toolbar.displayMode != NSToolbarDisplayModeLabelOnly)
		[mainWindow makeFirstResponder:searchField];
	else
	{
		if (!searchPanel)
			searchPanel = [[SearchPanel alloc] init];
		[searchPanel runSearchPanel:mainWindow];
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
	filterSearchField.stringValue = newFilterString;
}

/* filterString
 * Return the contents of the filter bar's search field.
 */
-(NSString *)filterString
{
	return filterSearchField.stringValue;
}

/* searchUsingFilterField
 * Executes a search using the filter control.
 */
-(IBAction)searchUsingFilterField:(id)sender
{
	[browserView.activeTabItemView performFindPanelAction:NSFindPanelActionNext];
}

- (IBAction)searchUsingTreeFilter:(NSSearchField* )field
{
    NSString* f = field.stringValue;
    [foldersTree setSearch:f];
}

/* searchUsingToolbarTextField
 * Executes a search using the search field on the toolbar.
 */
-(IBAction)searchUsingToolbarTextField:(id)sender
{
	self.searchString = searchField.stringValue;
	SearchMethod * currentSearchMethod = [Preferences standardPreferences].searchMethod;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[self performSelector:currentSearchMethod.handler withObject: currentSearchMethod];
#pragma clang diagnostic pop
}

/* performAllArticlesSearch
 * Searches for the current searchString in all articles.
 */
-(void)performAllArticlesSearch
{
	[self searchArticlesWithString:searchField.stringValue];
}

/* performAllArticlesSearch
 * Performs a web-search with the defined query URL. This is usually called by plugged-in SearchMethods.
 */
-(void)performWebSearch:(SearchMethod *)searchMethod
{
	[self createNewTab:[searchMethod queryURLforSearchString:searchString] inBackground:NO];
}

/* performWebPageSearch
 * Performs a search for searchString within the currently displayed web page in our bult-in browser.
 */
-(void)performWebPageSearch
{
	NSView<BaseView> * theView = browserView.activeTabItemView;
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
		[db setSearchString:theSearchString];
		if (foldersTree.actualSelection != db.searchFolderId)
			[foldersTree selectFolder:db.searchFolderId];
		else
			[articleController.mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
	}
}

#pragma mark Refresh Subscriptions

/* refreshAllFolderIcons
 * Get new favicons from all subscriptions.
 */
-(IBAction)refreshAllFolderIcons:(id)sender
{
	LOG_EXPR([foldersTree folders:0]);
	if (!self.connecting)
		[[RefreshManager sharedManager] refreshFolderIconCacheForSubscriptions:[foldersTree folders:0]];
}

/* refreshAllSubscriptions
 * Get new articles from all subscriptions.
 */
-(IBAction)refreshAllSubscriptions:(id)sender
{
	static NSInteger waitNumber = 20;
	// Check the Open Reader status
	if ([Preferences standardPreferences].syncGoogleReader && ![GoogleReader sharedManager].ready) {
		LLog(@"Waiting until Google Auth is done...");
		waitNumber-- ;
		if (![sender isKindOfClass:[NSTimer class]]) {
			LLog(@"Create a timer...");
			[[GoogleReader sharedManager] authenticate];
			[NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(refreshAllSubscriptions:) userInfo:nil repeats:YES];
		}
		// if we have tried for 1 minute, there is probably a serious problem with logging in...
		// don't insist any further for now regarding Open Reader
		if (waitNumber<=0) {
			[[GoogleReader sharedManager] clearAuthentication];
			if ([sender isKindOfClass:[NSTimer class]]) {
				[(NSTimer*)sender invalidate];
				sender = nil;
				waitNumber = 20;
			}
		}
		else
			return;
	} else {
		[self setStatusMessage:nil persist:NO];
		if ([sender isKindOfClass:[NSTimer class]]) {
			[(NSTimer*)sender invalidate];
			sender = nil;
			waitNumber = 20;
		}
	}
	
	// Reset the refresh timer
	[self handleCheckFrequencyChange:nil];
	
	// Kick off an initial refresh	
	if (!self.connecting) 
		[[RefreshManager sharedManager] refreshSubscriptionsAfterRefreshAll:[foldersTree folders:0] ignoringSubscriptionStatus:NO];		
	
}

-(IBAction)forceRefreshSelectedSubscriptions:(id)sender {
	NSLog(@"Force Refresh");
	[[RefreshManager sharedManager] forceRefreshSubscriptionForFolders:foldersTree.selectedFolders];		
}

-(IBAction)updateRemoteSubscriptions:(id)sender {
	[[GoogleReader sharedManager] loadSubscriptions:nil];
}


/* refreshSelectedSubscriptions
 * Refresh one or more subscriptions selected from the folders list. The selection we obtain
 * may include non-RSS folders so these have to be trimmed out first.
 */
-(IBAction)refreshSelectedSubscriptions:(id)sender
{
	[[RefreshManager sharedManager] refreshSubscriptionsAfterRefresh:foldersTree.selectedFolders ignoringSubscriptionStatus:YES];
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
	NSView<BaseView> * theView = browserView.activeTabItemView;
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		NSString * viewLink = theView.viewLink;
		if (viewLink != nil)
		{
			title = percentEscape([browserView tabItemViewTitle:theView]);
			link = percentEscape(viewLink);
			mailtoLink = [NSMutableString stringWithFormat:@"mailto:?subject=%@&body=%@", title, link];
		}
	}
	else
	{
		// ... otherwise, iterate over the currently selected articles.
		NSArray * articleArray = articleController.markedArticleRange;
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
	NSView<BaseView> * activeView = browserView.activeTabItemView;
	[activeView.webView makeTextSmaller:sender];
}

/* makeTextLarger
 * Make text size larger in the article pane.
 * In the future, we may want this to make text size larger in the article list instead.
 */
-(IBAction)makeTextLarger:(id)sender
{
	NSView<BaseView> * activeView = browserView.activeTabItemView;
	[activeView.webView makeTextLarger:sender];
}

/* changeFiltering
 * Refresh the filtering of articles.
 */
-(IBAction)changeFiltering:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	[Preferences standardPreferences].filterMode = menuItem.tag;
	currentFilterTextField.stringValue = menuItem.title;
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
	NSView<BaseView> * theView = browserView.activeTabItemView;
	if ([theView isKindOfClass:[BrowserPane class]])
		[self sendBlogEvent:externalEditorBundleIdentifier title:[browserView tabItemViewTitle:browserView.activeTabItemView] url:theView.viewLink body:APP.currentTextSelection author:@"" guid:@""];
	else
	{
		// Get the currently selected articles from the ArticleView and iterate over them.
		for (Article * currentArticle in articleController.markedArticleRange)
			[self sendBlogEvent:externalEditorBundleIdentifier title:currentArticle.title url:currentArticle.link body:APP.currentTextSelection author:currentArticle.author guid:currentArticle.guid];
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

#pragma mark Progress Indicator 

/* startProgressIndicator
 * Gets the progress indicator on the info bar running. Because this can be called
 * nested, we use progressCount to make sure we remove it at the right time.
 */
-(void)startProgressIndicator
{
	if (progressCount++ == 0)
		[spinner startAnimation:self];
}

/* stopProgressIndicator
 * Stops the progress indicator on the info bar running
 */
-(void)stopProgressIndicator
{
	NSAssert(progressCount > 0, @"Called stopProgressIndicator without a matching startProgressIndicator");
	if (--progressCount < 1)
	{
		[spinner stopAnimation:self];
		progressCount = 0;
	}
}

#pragma mark Status Bar

/* isStatusBarVisible
 * Simple function that returns whether or not the status bar is visible.
 */
-(BOOL)isStatusBarVisible
{
	Preferences * prefs = [Preferences standardPreferences];
	return prefs.showStatusBar;
}

/* handleShowStatusBar
 * Respond to the status bar state being changed programmatically.
 */
-(void)handleShowStatusBar:(NSNotification *)nc
{
	[self setStatusBarState:[Preferences standardPreferences].showStatusBar withAnimation:YES];
}

/* showHideStatusBar
 * Toggle the status bar on/off. When off, expand the article area to fill the space.
 */
-(IBAction)showHideStatusBar:(id)sender
{
	BOOL newState = !self.statusBarVisible;
	
	[self setStatusBarState:newState withAnimation:YES];
	[Preferences standardPreferences].showStatusBar = newState;
}

/* setStatusBarState
 * Show or hide the status bar state. Does not persist the state - use showHideStatusBar for this.
 */
-(void)setStatusBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate
{
	NSRect viewSize = splitView1.frame;
	if (isStatusBarVisible && !isVisible)
	{
		viewSize.size.height += MA_StatusBarHeight;
		viewSize.origin.y -= MA_StatusBarHeight;
	}
	else if (!isStatusBarVisible && isVisible)
	{
		viewSize.size.height -= MA_StatusBarHeight;
		viewSize.origin.y += MA_StatusBarHeight;
	}
	if (isStatusBarVisible != isVisible)
	{
		if (!doAnimate)
		{
			statusText.hidden = !isVisible;
			splitView1.frame = viewSize;
		}
		else
		{
			if (!isVisible)
			{
				// When hiding the status bar, hide these controls BEFORE
				// we start hiding the view. Looks cleaner.
				[statusText setHidden:YES];
				[currentFilterTextField setHidden:YES];
				[filterIconInStatusBarButton setHidden:YES];
				[cosmeticStatusBarHighlightLine setHidden:YES];
				if ([mainWindow respondsToSelector:@selector(setBottomCornerRounded:)])
				{
					[mainWindow setBottomCornerRounded:NO];
				}
			}
			[splitView1 resizeViewWithAnimation:viewSize withTag:MA_ViewTag_Statusbar];
		}
		[mainWindow display];
		isStatusBarVisible = isVisible;
	}
}

/* setStatusMessage
 * Sets a new status message for the status bar then updates the view. To remove
 * any existing status message, pass nil as the value.
 */
-(void)setStatusMessage:(NSString *)newStatusText persist:(BOOL)persistenceFlag
{
	@synchronized(persistedStatusText){
		if (persistenceFlag)
		{
			persistedStatusText = newStatusText;
		}
		if (newStatusText == nil || newStatusText.blank)
			newStatusText = persistedStatusText;
		statusText.stringValue = (newStatusText ? newStatusText : @"");
	}
}

/* viewAnimationCompleted
 * Called when animation of the specified view completes.
 */
-(void)viewAnimationCompleted:(NSView *)theView withTag:(NSInteger)viewTag
{
	if (viewTag == MA_ViewTag_Statusbar && self.statusBarVisible)
	{
		// When showing the status bar, show these controls AFTER
		// we have made the view visible. Again, looks cleaner.
		[statusText setHidden:NO];
		[currentFilterTextField setHidden:NO];
		[filterIconInStatusBarButton setHidden:NO];
		[cosmeticStatusBarHighlightLine setHidden:NO];
		if ([mainWindow respondsToSelector:@selector(setBottomCornerRounded:)])
		{
			[mainWindow setBottomCornerRounded:YES];
		}
		return;
	}
	if (viewTag == MA_ViewTag_Filterbar && self.filterBarVisible)
	{
		[filterView display];
		return;
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
	BOOL isMainWindowVisible = mainWindow.visible;
	BOOL isAnyArticleView = browserView.activeTabItemView == [browserView primaryTabItemView];
	
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
	if (theAction == @selector(showXMLSource:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		*validateFlag = isMainWindowVisible && folder != nil && folder.hasFeedSource;
		return YES;
	}	
	if (theAction == @selector(getInfo:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		*validateFlag = (IsRSSFolder(folder) || IsGoogleReaderFolder(folder)) && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(forceRefreshSelectedSubscriptions:)) {
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		*validateFlag = IsGoogleReaderFolder(folder);
		return YES;
	}
	if (theAction == @selector(viewNextUnread:))
	{
		*validateFlag = db.countOfUnread > 0;
		return YES;
	}
	if (theAction == @selector(goBack:))
	{
		*validateFlag = browserView.activeTabItemView.canGoBack && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(mailLinkToArticlePage:))
	{
		NSView<BaseView> * theView = browserView.activeTabItemView;
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
-(BOOL)validateToolbarItem:(ToolbarItem *)toolbarItem
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
	BOOL isMainWindowVisible = mainWindow.visible;
	BOOL isAnyArticleView = browserView.activeTabItemView == [browserView primaryTabItemView];
	BOOL isArticleView = browserView.activeTabItemView == articleController.mainArticleView;
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
			NSView<BaseView> * theView = browserView.activeTabItemView;
			return theView != nil && [theView isKindOfClass:[BrowserPane class]] && !((BrowserPane *)theView).loading;
		}
	}
	else if (theAction == @selector(goForward:))
	{
		return browserView.activeTabItemView.canGoForward && isMainWindowVisible;
	}
	else if (theAction == @selector(newGroupFolder:))
	{
		return !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(showHideStatusBar:))
	{
		if (self.statusBarVisible)
			[menuItem setTitle:NSLocalizedString(@"Hide Status Bar", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Show Status Bar", nil)];
		return isMainWindowVisible;
	}
	else if (theAction == @selector(showHideFilterBar:))
	{
		if (self.filterBarVisible)
			[menuItem setTitle:NSLocalizedString(@"Hide Filter Bar", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Show Filter Bar", nil)];
		return isMainWindowVisible && isAnyArticleView;
	}
	else if (theAction == @selector(makeTextLarger:))
	{
		return browserView.activeTabItemView.webView.canMakeTextLarger && isMainWindowVisible;
	}
	else if (theAction == @selector(makeTextSmaller:))
	{
		return browserView.activeTabItemView.webView.canMakeTextSmaller && isMainWindowVisible;
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
		if ([field.name isEqualToString:articleController.sortColumnIdentifier])
			menuItem.state = NSOnState;
		else
			menuItem.state = NSOffState;
		return isMainWindowVisible && isAnyArticleView;
	}
	else if (theAction == @selector(doSortDirection:))
	{
		NSNumber * ascendingNumber = menuItem.representedObject;
		BOOL ascending = ascendingNumber.integerValue;
		if (ascending == articleController.sortIsAscending)
			menuItem.state = NSOnState;
		else
			menuItem.state = NSOffState;
		return isMainWindowVisible && isAnyArticleView;
	}
	else if (theAction == @selector(unsubscribeFeed:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		if (folder)
		{
			if (IsUnsubscribed(folder))
				[menuItem setTitle:NSLocalizedString(@"Resubscribe", nil)];
			else
				[menuItem setTitle:NSLocalizedString(@"Unsubscribe", nil)];
		}
		return folder && (IsRSSFolder(folder) || IsGoogleReaderFolder(folder)) && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(useCurrentStyleForArticles:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		if (folder && (IsRSSFolder(folder) || IsGoogleReaderFolder(folder)) && !folder.loadsFullHTML)
			menuItem.state = NSOnState;
		else
			menuItem.state = NSOffState;
		return folder && (IsRSSFolder(folder) || IsGoogleReaderFolder(folder)) && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(useWebPageForArticles:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		if (folder && (IsRSSFolder(folder) || IsGoogleReaderFolder(folder)) && folder.loadsFullHTML)
			menuItem.state = NSOnState;
		else
			menuItem.state = NSOffState;
		return folder && (IsRSSFolder(folder) || IsGoogleReaderFolder(folder)) && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(deleteFolder:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		if (IsSearchFolder(folder))
			[menuItem setTitle:NSLocalizedString(@"Delete", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Delete…", nil)];
		return folder && !IsTrashFolder(folder) && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(refreshSelectedSubscriptions:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		return folder && (IsRSSFolder(folder) || IsGroupFolder(folder) || IsGoogleReaderFolder(folder)) && !db.readOnly;
	}
	else if (theAction == @selector(refreshAllFolderIcons:))
	{
		return !self.connecting && !db.readOnly;
	}
	else if (theAction == @selector(renameFolder:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		return folder && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(markAllRead:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		return folder && !IsTrashFolder(folder) && !db.readOnly && isMainWindowVisible && db.countOfUnread > 0;
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
		Folder * folder = (thisArticle) ? [db folderFromID:thisArticle.folderId] : [db folderFromID:foldersTree.actualSelection];
		return folder && (thisArticle || IsRSSFolder(folder) || IsGoogleReaderFolder(folder)) && (folder.homePage && !folder.homePage.blank && isMainWindowVisible);
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
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		return folder && (IsSmartFolder(folder) || IsRSSFolder(folder)) && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(restoreMessage:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		return IsTrashFolder(folder) && self.selectedArticle != nil && !db.readOnly && isMainWindowVisible;
	}
	else if (theAction == @selector(deleteMessage:))
	{
		Folder * folder = [db folderFromID:foldersTree.actualSelection];
		return self.selectedArticle != nil && !db.readOnly && isMainWindowVisible &&!IsGoogleReaderFolder(folder);
	}
	else if (theAction == @selector(previousTab:))
	{
		return isMainWindowVisible && browserView.countOfTabs > 1;
	}
	else if (theAction == @selector(nextTab:))
	{
		return isMainWindowVisible && browserView.countOfTabs > 1;
	}
	else if (theAction == @selector(closeTab:))
	{
		return isMainWindowVisible && !isArticleView;
	}
	else if (theAction == @selector(closeAllTabs:))
	{
		return isMainWindowVisible && browserView.countOfTabs > 1;
	}
	else if (theAction == @selector(reloadPage:))
	{
		NSView<BaseView> * theView = browserView.activeTabItemView;
		return ([theView isKindOfClass:[BrowserPane class]]) && !((BrowserPane *)theView).loading;
	}
	else if (theAction == @selector(stopReloadingPage:))
	{
		NSView<BaseView> * theView = browserView.activeTabItemView;
		return ([theView isKindOfClass:[BrowserPane class]]) && ((BrowserPane *)theView).loading;
	}
	else if (theAction == @selector(changeFiltering:))
	{
		menuItem.state = (menuItem.tag == [Preferences standardPreferences].filterMode) ? NSOnState : NSOffState;
		return isMainWindowVisible;
	}
	else if (theAction == @selector(keepFoldersArranged:))
	{
		Preferences * prefs = [Preferences standardPreferences];
		menuItem.state = (prefs.foldersTreeSortMethod == menuItem.tag) ? NSOnState : NSOffState;
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
		if (articleController.markedArticleRange.count > 1)
			[menuItem setTitle:NSLocalizedString(@"Send Links", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Send Link", nil)];
		return flag;
	}
	else if (theAction == @selector(downloadEnclosure:))
	{
		if (articleController.markedArticleRange.count > 1)
			[menuItem setTitle:NSLocalizedString(@"Download Enclosures", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Download Enclosure", nil)];
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
	}
	return YES;
}

/* itemForItemIdentifier
 * This method is required of NSToolbar delegates.  It takes an identifier, and returns the matching ToolbarItem.
 * It also takes a parameter telling whether this toolbar item is going into an actual toolbar, or whether it's
 * going to be displayed in a customization palette.
 */
-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)willBeInserted
{
	ToolbarItem *item = [[ToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	if ([itemIdentifier isEqualToString:@"SearchItem"])
	{
		[item setView:searchField];
		[item setLabel:NSLocalizedString(@"Search Articles", nil)];
		item.paletteLabel = item.label;
		item.target = self;
		item.action = @selector(searchUsingToolbarTextField:);
		[item setToolTip:NSLocalizedString(@"Search Articles", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"Subscribe"])
	{
		[item setLabel:NSLocalizedString(@"Subscribe", nil)];
		item.paletteLabel = item.label;
		[item setButtonImage:@"subscribeButton"];
		item.target = self;
		item.action = @selector(newSubscription:);
		[item setToolTip:NSLocalizedString(@"Create a new subscription", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"PreviousButton"])
	{
		[item setLabel:NSLocalizedString(@"Back", nil)];
		item.paletteLabel = item.label;
		[item setButtonImage:@"previousButton"];
		item.target = self;
		item.action = @selector(goBack:);
		[item setToolTip:NSLocalizedString(@"Back", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"NextButton"])
	{
		[item setLabel:NSLocalizedString(@"Next Unread", nil)];
		item.paletteLabel = item.label;
		[item setButtonImage:@"nextButton"];
		item.target = self;
		item.action = @selector(viewNextUnread:);
		[item setToolTip:NSLocalizedString(@"Next Unread", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"SkipFolder"])
	{
		[item setLabel:NSLocalizedString(@"Skip Folder", nil)];
		item.paletteLabel = item.label;
		[item setButtonImage:@"skipFolderButton"];
		item.target = self;
		item.action = @selector(skipFolder:);
		[item setToolTip:NSLocalizedString(@"Skip Folder", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"Refresh"])
	{
		[item setLabel:NSLocalizedString(@"Refresh", nil)];
		item.paletteLabel = item.label;
		[item setButtonImage:@"refreshButton"];
		item.target = self;
		item.action = @selector(refreshAllSubscriptions:);
		[item setToolTip:NSLocalizedString(@"Refresh all your subscriptions", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"MailLink"])
	{
		[item setLabel:NSLocalizedString(@"Send Link", nil)];
		item.paletteLabel = item.label;
		[item setButtonImage:@"mailLinkButton"];
		item.target = self;
		item.action = @selector(mailLinkToArticlePage:);
		[item setToolTip:NSLocalizedString(@"Email a link to the current article or website", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"EmptyTrash"])
	{
		[item setLabel:NSLocalizedString(@"Empty Trash", nil)];
		item.paletteLabel = item.label;
		[item setButtonImage:@"emptyTrashButton"];
		item.target = self;
		item.action = @selector(emptyTrash:);
		[item setToolTip:NSLocalizedString(@"Delete all articles in the trash", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"GetInfo"])
	{
		[item setLabel:NSLocalizedString(@"Get Info", nil)];
		item.paletteLabel = item.label;
		[item setButtonImage:@"getInfoButton"];
		item.target = self;
		item.action = @selector(getInfo:);
		[item setToolTip:NSLocalizedString(@"See information about the selected subscription", nil)];
	}
	else if ([itemIdentifier isEqualToString: @"Spinner"])
	{
		item.label = @"";
		[item setPaletteLabel:NSLocalizedString(@"Progress", nil)];
		//Only have the spinner hide when stopped for the real window, not for the customization pane
		if (willBeInserted)
		{
			[item setView:spinner];
			[spinner setDisplayedWhenStopped:NO];
			[spinner setTarget:self];
			[spinner setAction:@selector(toggleActivityViewer:)];
			[spinner setHidden:NO];
			
			//Ensure the spinner has the proper state; it may be added while we're refreshing
			if (APP.refreshing)
				[spinner startAnimation:self];
		}
		else
		{
			NSProgressIndicator *customizationPaletteSpinner = [[NSProgressIndicator alloc] initWithFrame:spinner.frame];
			customizationPaletteSpinner.controlSize = spinner.controlSize;
			customizationPaletteSpinner.controlTint = spinner.controlTint;
			customizationPaletteSpinner.indeterminate = spinner.indeterminate;
			customizationPaletteSpinner.style = spinner.style;
			
			[item setView:customizationPaletteSpinner];
		}
		
		item.minSize = NSMakeSize(NSWidth(spinner.frame), NSHeight(spinner.frame));
		item.maxSize = NSMakeSize(NSWidth(spinner.frame), NSHeight(spinner.frame));
	}
	else if ([itemIdentifier isEqualToString: @"Styles"])
	{
		[item setPopup:@"stylesMenuButton" withMenu:(willBeInserted ? self.stylesMenu : nil)];
		[item setLabel:NSLocalizedString(@"Style", nil)];
		item.paletteLabel = item.label;
		[item setToolTip:NSLocalizedString(@"Display the list of available styles", nil)];
	}
	else if ([itemIdentifier isEqualToString: @"Action"])
	{
		[item setPopup:@"popupMenuButton" withMenu:(willBeInserted ? self.folderMenu : nil)];
		[item setLabel:NSLocalizedString(@"Action", nil)];
		item.paletteLabel = item.label;
		[item setToolTip:NSLocalizedString(@"Additional actions for the selected folder", nil)];
	}
	else
	{
		[pluginManager toolbarItem:item withIdentifier:itemIdentifier];
	}
	return item;
}

/* toolbarDefaultItemIdentifiers
 * This method is required of NSToolbar delegates.  It returns an array holding identifiers for the default
 * set of toolbar items.  It can also be called by the customization palette to display the default toolbar.
 */
-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [[@[@"Subscribe",
			 @"SkipFolder",
			 @"Action",
			 @"Refresh"]
			 arrayByAddingObjectsFromArray:[pluginManager defaultToolbarItems]]
			 arrayByAddingObjectsFromArray:@[NSToolbarFlexibleSpaceItemIdentifier,
			 @"SearchItem"]
			 ];
}

/* toolbarAllowedItemIdentifiers
 * This method is required of NSToolbar delegates.  It returns an array holding identifiers for all allowed
 * toolbar items in this toolbar.  Any not listed here will not be available in the customization palette.
 */
-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [@[NSToolbarSeparatorItemIdentifier,
			 NSToolbarSpaceItemIdentifier,
			 NSToolbarFlexibleSpaceItemIdentifier,
			 @"Refresh",
			 @"Subscribe",
			 @"SkipFolder",
			 @"EmptyTrash",
			 @"Action",
			 @"SearchItem",
			 @"Spinner",
			 @"MailLink",
			 @"GetInfo",
			 @"Styles",
			 @"PreviousButton",
			 @"NextButton"]
			 arrayByAddingObjectsFromArray:pluginManager.toolbarItems
			 ];
}

/*! showSystemProfileInfoAlert
 * displays an alert asking the user to opt-in to sending anonymous system profile throug Sparkle
 */
-(void)showSystemProfileInfoAlert {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
    [alert addButtonWithTitle:NSLocalizedString(@"No thanks", @"No thanks")];
    [alert setMessageText:NSLocalizedString(@"Include anonymous system profile when checking for updates?", @"Include anonymous system profile when checking for updates?")];
    [alert setInformativeText:NSLocalizedString(@"Include anonymous system profile when checking for updates text", @"This helps Vienna development by letting us know what versions of Mac OS X are most popular amongst our users.")];
    alert.alertStyle = NSInformationalAlertStyle;
    NSModalResponse buttonClicked = alert.runModal;
    NSLog(@"buttonClicked: %ld", (long)buttonClicked);
    switch (buttonClicked) {
        case NSAlertFirstButtonReturn:
            /* Agreed to send system profile. Uses preferences to set value otherwise 
             the preference control is out of sync */
            [[Preferences standardPreferences] setSendSystemSpecs:YES];
            break;
        case NSAlertSecondButtonReturn:
            /* Declined to send system profile. Uses SUUpdater to set the value
             otherwise it stays nil instead of being set to 0 */
            [[SUUpdater sharedUpdater] setSendsSystemProfile:NO];
            break;
        default:
            break;
    }
}


#pragma mark - MASPreferences

- (NSWindowController *)preferencesWindowController
{
    if (_preferencesWindowController == nil)
    {
        NSViewController *generalViewController = [[GeneralPreferencesViewController alloc] init];
        NSViewController *appearanceViewController = [[AppearancePreferencesViewController alloc] init];
        NSViewController *syncingViewController = [[SyncingPreferencesViewController alloc] init];
        NSViewController *advancedViewController = [[AdvancedPreferencesViewController alloc] init];
        NSArray *controllers = @[generalViewController, appearanceViewController, syncingViewController, advancedViewController];
        
        // To add a flexible space between General and Advanced preference panes insert [NSNull null]:
        //     NSArray *controllers = [[NSArray alloc] initWithObjects:generalViewController, [NSNull null], advancedViewController, nil];
        
        
        NSString *title = NSLocalizedString(@"Preferences", @"Common title for Preferences window");
        _preferencesWindowController = [[MASPreferencesWindowController alloc] initWithViewControllers:controllers title:title];
    }
    return _preferencesWindowController;
}

#pragma mark - MASPreferences Actions

- (IBAction)showPreferencePanel:(id)sender
{
    [self.preferencesWindowController showWindow:nil];
}

NSString *const kFocusedAdvancedControlIndex = @"FocusedAdvancedControlIndex";

- (NSInteger)focusedAdvancedControlIndex
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:kFocusedAdvancedControlIndex];
}

- (void)setFocusedAdvancedControlIndex:(NSInteger)focusedAdvancedControlIndex
{
    [[NSUserDefaults standardUserDefaults] setInteger:focusedAdvancedControlIndex forKey:kFocusedAdvancedControlIndex];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[mainWindow setDelegate:nil];
	[splitView1 setDelegate:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
