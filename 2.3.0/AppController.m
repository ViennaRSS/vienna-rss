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
#import "NewPreferencesController.h"
#import "FoldersTree.h"
#import "ArticleListView.h"
#import "UnifiedDisplayView.h"
#import "Import.h"
#import "Export.h"
#import "RefreshManager.h"
#import "StringExtensions.h"
#import "SplitViewExtensions.h"
#import "ViewExtensions.h"
#import "BrowserView.h"
#import "SearchFolder.h"
#import "NewSubscription.h"
#import "NewGroupFolder.h"
#import "ViennaApp.h"
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
#import <WebKit/WebFrame.h>
#import <WebKit/WebUIDelegate.h>
#import <Growl/GrowlDefines.h>
#include <mach/mach_port.h>
#include <mach/mach_interface.h>
#include <mach/mach_init.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>

@interface AppController (Private)
	-(NSMenu *)searchFieldMenu;
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
	-(void)initBlogWithMenu;
	-(void)initScriptsMenu;
	-(void)initFiltersMenu;
	-(NSMenu *)getStylesMenu;
	-(void)startProgressIndicator;
	-(void)stopProgressIndicator;
	-(void)doEditFolder:(Folder *)folder;
	-(void)refreshOnTimer:(NSTimer *)aTimer;
	-(void)setStatusBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate;
	-(void)setFilterBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate;
	-(void)setPersistedFilterBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate;
	-(void)doConfirmedDelete:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
	-(void)doConfirmedEmptyTrash:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
	-(void)runAppleScript:(NSString *)scriptName;
	-(void)setImageForMenuCommand:(NSImage *)image forAction:(SEL)sel;
	-(NSString *)appName;
	-(void)sendBlogEvent:(NSString *)externalEditorBundleIdentifier title:(NSString *)title url:(NSString *)url body:(NSString *)body author:(NSString *)author guid:(NSString *)guid;
	-(void)setLayout:(int)newLayout withRefresh:(BOOL)refreshFlag;
	-(void)updateAlternateMenuTitle;
	-(void)updateSearchPlaceholder;
	-(void)toggleOptionKeyButtonStates;
	-(FoldersTree *)foldersTree;
	-(void)updateCloseCommands;
	-(void)loadOpenTabs;
	-(BOOL)isFilterBarVisible;
	-(BOOL)isStatusBarVisible;
	-(NSDictionary *)registrationDictionaryForGrowl;
	-(NSTimer *)checkTimer;
	-(ToolbarItem *)toolbarItemWithIdentifier:(NSString *)theIdentifier;
	-(void)searchArticlesWithString:(NSString *)searchString;
@end

// Static constant strings that are typically never tweaked
static const int MA_Minimum_Folder_Pane_Width = 80;
static const int MA_Minimum_BrowserView_Pane_Width = 200;
static const int MA_StatusBarHeight = 22;

// Awake from sleep
static io_connect_t root_port;
static void MySleepCallBack(void * x, io_service_t y, natural_t messageType, void * messageArgument);

@implementation AppController

/* init
 * Class instance initialisation.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		scriptPathMappings = [[NSMutableDictionary alloc] init];
		progressCount = 0;
		persistedStatusText = nil;
		lastCountOfUnread = 0;
		growlAvailable = NO;
		appStatusItem = nil;
		scriptsMenuItem = nil;
		isStatusBarVisible = YES;
		checkTimer = nil;
		didCompleteInitialisation = NO;
		emptyTrashWarning = nil;
	}
	return self;
}

/* awakeFromNib
 * Do all the stuff that only makes sense after our NIB has been loaded and connected.
 */
-(void)awakeFromNib
{
	Preferences * prefs = [Preferences standardPreferences];

	[self installCustomEventHandler];
	
	// Restore the most recent layout
	[self setLayout:[prefs layout] withRefresh:NO];

	// Localise the menus
	[self localiseMenus:[[NSApp mainMenu] itemArray]];

	// Set the delegates and title
	[mainWindow setDelegate:self];
	[mainWindow setTitle:[self appName]];
	[NSApp setDelegate:self];
	[mainWindow setMinSize: NSMakeSize(MA_Default_Main_Window_Min_Width, MA_Default_Main_Window_Min_Height)];

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

	// Init the progress counter and status bar.
	[self setStatusMessage:nil persist:NO];
	
	// Initialize the database
	if ((db = [Database sharedDatabase]) == nil)
	{
		[NSApp terminate:nil];
		return;
	}
	
	// Create the toolbar.
	NSToolbar * toolbar = [[[NSToolbar alloc] initWithIdentifier:@"MA_Toolbar"] autorelease];

	// Set the appropriate toolbar options. We are the delegate, customization is allowed,
	// changes made by the user are automatically saved and we start in icon mode.
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES]; 
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setShowsBaselineSeparator:NO];
	[mainWindow setToolbar:toolbar];

	// Run the auto-expire now
	[db purgeArticlesOlderThanDays:[prefs autoExpireDuration]];
	
	// Preload dictionary of standard URLs
	NSString * pathToPList = [[NSBundle mainBundle] pathForResource:@"StandardURLs.plist" ofType:@""];
	if (pathToPList != nil)
		standardURLs = [[NSDictionary dictionaryWithContentsOfFile:pathToPList] retain];
	
	// Initialize the Sort By and Columns menu
	[self initSortMenu];
	[self initColumnsMenu];
	[self initBlogWithMenu];
	[self initFiltersMenu];

	// Initialize the Styles menu.
	[stylesMenu setSubmenu:[self getStylesMenu]];

	// Restore the splitview layout
	[splitView1 setLayout:[[Preferences standardPreferences] objectForKey:@"SplitView1Positions"]];	
	[splitView1 setDelegate:self];
	
	// Show the current unread count on the app icon
	originalIcon = [[NSApp applicationIconImage] copy];
	[self showUnreadCountOnApplicationIconAndWindowTitle];
	
	// Set alternate in main menu for opening pages, and check for correct title of menu item
	// This is a hack, because Interface Builder refuses to set alternates with only the shift key as modifier.
	NSMenuItem * alternateItem = menuWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	if (alternateItem != nil)
	{
		[alternateItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
		[alternateItem setAlternate:YES];
	}
	alternateItem = menuWithAction(@selector(viewArticlePageInAlternateBrowser:));
	if (alternateItem != nil)
	{
		[alternateItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
		[alternateItem setAlternate:YES];
	}
	[self updateAlternateMenuTitle];
	
	// Create a menu for the search field
	// The menu title doesn't appear anywhere so we don't localise it. The titles of each
	// item is localised though.	
	[[searchField cell] setSearchMenuTemplate:[self searchFieldMenu]];
	[[filterSearchField cell] setSearchMenuTemplate:[self searchFieldMenu]];

	// Set the placeholder string for the global search field
	[[searchField cell] setPlaceholderString:NSLocalizedString(@"Search all articles", nil)];

	// Add Scripts menu if we have any scripts
	if (!hasOSScriptsMenu())
		[self initScriptsMenu];
	
	// Show/hide the status bar based on the last session state
	[self setStatusBarState:[prefs showStatusBar] withAnimation:NO];

	// Add the app to the status bar if needed.
	[self showAppInStatusBar];
	
	// Use Growl if it is installed
	[GrowlApplicationBridge setGrowlDelegate:self];
	
	// Start the check timer
	[self handleCheckFrequencyChange:nil];
	
	// Register to be informed when the system awakes from sleep
	[self installSleepHandler];
	
	// Register to be notified when the scripts folder changes.
	if (!hasOSScriptsMenu())
		[self installScriptsFolderWatcher];
	
	// Fix up the Close commands
	[self updateCloseCommands];

	// Do safe initialisation. 	 
	[self doSafeInitialisation];

	// Set the metal background texture
	backgroundColor = [NSColor colorWithPatternImage:[NSImage imageNamed:@"mainBackground.tiff"]];
	[mainWindow setBackgroundColor:backgroundColor];
	
	// Retain views which might be removed from the toolbar and therefore released;
	// we will need them if they are added back later.
	[spinner retain];
	[searchField retain];
}

/* installCustomEventHandler
 * This is our custom event handler that tells us when a modifier key is pressed
 * or released anywhere in the system. Needed for iTunes-like button. The other 
 * half of the magic happens in ViennaApp.
 */
-(void)installCustomEventHandler
{
	EventTypeSpec eventType;
	eventType.eventClass = kEventClassKeyboard;
	eventType.eventKind = kEventRawKeyModifiersChanged;

	EventHandlerUPP handlerFunction = NewEventHandlerUPP(keyPressed);
	InstallEventHandler(GetEventMonitorTarget(), handlerFunction, 1, &eventType, NULL, NULL);
}

/* doSafeInitialisation
 * Do the stuff that requires that all NIBs are awoken. I can't find a notification
 * from Cocoa for this so we hack it.
 */
-(void)doSafeInitialisation
{
	static BOOL doneSafeInit = NO;
	if (!doneSafeInit)
	{
		[foldersTree initialiseFoldersTree];
		[mainArticleView initialiseArticleView];

		// Select the folder and article from the last session
		Preferences * prefs = [Preferences standardPreferences];
		int previousFolderId = [prefs integerForKey:MAPref_CachedFolderID];
		NSString * previousArticleGuid = [prefs stringForKey:MAPref_CachedArticleGUID];
		if ([previousArticleGuid isBlank])
			previousArticleGuid = nil;
		[[articleController mainArticleView] selectFolderAndArticle:previousFolderId guid:previousArticleGuid];

		// Set the initial filter bar state
		[self setFilterBarState:[prefs showFilterBar] withAnimation:NO];
		
		// Make article list the first responder
		[mainWindow makeFirstResponder:[[browserView primaryTabItemView] mainView]];		

		// Start opening the old tabs once everything else has finished initializing and setting up
		[self performSelector:@selector(loadOpenTabs)
				   withObject:nil
				   afterDelay:0];
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
	int count = [arrayOfMenus count];
	int index;
	
	for (index = 0; index < count; ++index)
	{
		NSMenuItem * menuItem = [arrayOfMenus objectAtIndex:index];
		if (menuItem != nil && ![menuItem isSeparatorItem])
		{
			NSString * localisedMenuTitle = NSLocalizedString([menuItem title], nil);
			if ([menuItem submenu])
			{
				NSMenu * subMenu = [menuItem submenu];
				if (localisedMenuTitle != nil)
					[subMenu setTitle:localisedMenuTitle];
				[self localiseMenus:[subMenu itemArray]];
			}
			if (localisedMenuTitle != nil)
				[menuItem setTitle:localisedMenuTitle];
		}
	}
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
		AppController * app = (AppController *)[NSApp delegate];
		Preferences * prefs = [Preferences standardPreferences];
		int frequency = [prefs refreshFrequency];
		if (frequency > 0)
		{
			NSDate * lastRefresh = [prefs objectForKey:MAPref_LastRefreshDate];
			if ((lastRefresh == nil) || ([app checkTimer] == nil))
				[app handleCheckFrequencyChange:nil];
			else
			{
				// Wait at least 15 seconds after waking to avoid refresh errors.
				NSTimeInterval interval = -[lastRefresh timeIntervalSinceNow];
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
					[[app checkTimer] setFireDate:[NSDate dateWithTimeIntervalSinceNow:15.0 + frequency - interval]];
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
	
	root_port = IORegisterForSystemPower(self, &notify, MySleepCallBack, &anIterator);
	if (root_port != 0)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notify), kCFRunLoopCommonModes);
}

/* MyScriptsFolderWatcherCallBack
 * This is the callback function which is invoked when the file system detects changes in the Scripts
 * folder. We use this to trigger a refresh of the scripts menu.
 */
static void MyScriptsFolderWatcherCallBack(FNMessage message, OptionBits flags, void * refcon, FNSubscriptionRef subscription)
{
	AppController * app = (AppController *)refcon;
	[app initScriptsMenu];
}

/* installScriptsFolderWatcher
 * Install a handler to notify of changes in the scripts folder.
 */
-(void)installScriptsFolderWatcher
{
	NSString * path = [[Preferences standardPreferences] scriptsFolder];
	FNSubscriptionRef refCode;
	
	FNSubscribeByPath((const UInt8 *)[path UTF8String], MyScriptsFolderWatcherCallBack, self, kNilOptions, &refCode);
}

#pragma mark Application Delegate

/* applicationDidFinishLaunching
 * Handle post-load activities.
 */
-(void)applicationDidFinishLaunching:(NSNotification *)aNot
{
	Preferences * prefs = [Preferences standardPreferences];

	// Hook up the key sequence properly now that all NIBs are loaded.
	[[foldersTree mainView] setNextKeyView:[[browserView primaryTabItemView] mainView]];
	
	// Kick off an initial refresh
	if ([prefs refreshOnStartup])
		[self refreshAllSubscriptions:self];
}

/* applicationShouldHandleReopen
 * Handle the notification sent when the application is reopened such as when the dock icon
 * is clicked. If the main window was previously hidden, we show it again here.
 */
-(BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
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
	int returnCode;
	
	if ([[DownloadManager sharedInstance] activeDownloads] > 0)
	{
		returnCode = NSRunAlertPanel(NSLocalizedString(@"Downloads Running", nil),
									 NSLocalizedString(@"Downloads Running text", nil),
									 NSLocalizedString(@"Quit", nil),
									 NSLocalizedString(@"Cancel", nil),
									 nil);
		if (returnCode == NSAlertAlternateReturn)
			return NSTerminateCancel;
	}
	
	switch ([[Preferences standardPreferences] integerForKey:MAPref_EmptyTrashNotification])
	{
		case MA_EmptyTrash_None: break;
		
		case MA_EmptyTrash_WithoutWarning:
			if (![db isTrashEmpty])
			{
				[db purgeDeletedArticles];
			}
			break;
		
		case MA_EmptyTrash_WithWarning:
			if (![db isTrashEmpty])
			{
				if (emptyTrashWarning == nil)
					emptyTrashWarning = [[EmptyTrashWarning alloc] init];
				if ([emptyTrashWarning shouldEmptyTrash])
				{
					[db purgeDeletedArticles];
				}
				[emptyTrashWarning release];
				emptyTrashWarning = nil;
			}
			break;
		
		default: break;
	}
	
	return NSTerminateNow;
}

/* applicationWillTerminate
 * This is where we put the clean-up code.
 */
-(void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (didCompleteInitialisation)
	{
		// Save the splitview layout
		Preferences * prefs = [Preferences standardPreferences];
		[prefs setObject:[splitView1 layout] forKey:@"SplitView1Positions"];

		// Close the activity window explicitly to force it to
		// save its split bar position to the preferences.
		NSWindow * activityWindow = [activityViewer window];
		[activityWindow performClose:self];
		
		// Put back the original app icon
		[NSApp setApplicationIconImage:originalIcon];
		
		// Save the open tabs
		[browserView saveOpenTabs];

		// Remember the article list column position, sizes, etc.
		[mainArticleView saveTableSettings];
		[foldersTree saveFolderSettings];
		
		// Finally save preferences
		[prefs savePreferences];
	}
	[db close];
}

/* openFile [delegate]
 * Called when the user opens a data file associated with Vienna by clicking in the finder or dragging it onto the dock.
 */
-(BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	Preferences * prefs = [Preferences standardPreferences];
	if ([[filename pathExtension] isEqualToString:@"viennastyle"])
	{
		NSString * path = [prefs stylesFolder];
		NSString * styleName = [[filename lastPathComponent] stringByDeletingPathExtension];
		NSString * fullPath = [path stringByAppendingPathComponent:[filename lastPathComponent]];
		
		// Make sure we actually have a Styles folder.
		NSFileManager * fileManager = [NSFileManager defaultManager];
		BOOL isDir = NO;
		
		if (![fileManager fileExistsAtPath:path isDirectory:&isDir])
		{
			if (![fileManager createDirectoryAtPath:path attributes:NULL])
			{
				runOKAlertPanel(@"Cannot create style folder title", @"Cannot create style folder body", path);
				return NO;
			}
		}
		[fileManager removeFileAtPath:fullPath handler:nil];
		if (![fileManager copyPath:filename toPath:fullPath handler:nil])
			[[Preferences standardPreferences] setDisplayStyle:styleName];
		else
		{
			Preferences * prefs = [Preferences standardPreferences];
			[stylesMenu setSubmenu:[self getStylesMenu]];
			[[self toolbarItemWithIdentifier:@"Styles"] setPopup:@"stylesMenuButton" withMenu:[self getStylesMenu]];
			[prefs setDisplayStyle:styleName];
			if ([[prefs displayStyle] isEqualToString:styleName])
				runOKAlertPanel(@"New style title", @"New style body", styleName);
		}
		return YES;
	}
	if ([[filename pathExtension] isEqualToString:@"scpt"])
	{
		NSString * path = [prefs scriptsFolder];
		NSString * fullPath = [path stringByAppendingPathComponent:[filename lastPathComponent]];
		
		// Make sure we actually have a Scripts folder.
		NSFileManager * fileManager = [NSFileManager defaultManager];
		BOOL isDir = NO;
		
		if (![fileManager fileExistsAtPath:path isDirectory:&isDir])
		{
			if (![fileManager createDirectoryAtPath:path attributes:NULL])
			{
				runOKAlertPanel(@"Cannot create scripts folder title", @"Cannot create scripts folder body", path);
				return NO;
			}
		}
		[fileManager removeFileAtPath:fullPath handler:nil];
		if ([fileManager copyPath:filename toPath:fullPath handler:nil])
		{
			if (!hasOSScriptsMenu())
				[self initScriptsMenu];
		}
	}
	if ([[filename pathExtension] isEqualToString:@"opml"])
	{
		BOOL returnCode = NSRunAlertPanel(NSLocalizedString(@"Import subscriptions from OPML file?", nil), NSLocalizedString(@"Do you really want to import the subscriptions from the specified OPML file?", nil), NSLocalizedString(@"Import", nil), NSLocalizedString(@"Cancel", nil), nil);
		if (returnCode == NSAlertAlternateReturn)
			return NO;
		[self importFromFile:filename];
	}
	return NO;
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
	[item release];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recents", nil) action:NULL keyEquivalent:@""];
	[item setTag:NSSearchFieldRecentsMenuItemTag];
	[cellMenu insertItem:item atIndex:1];
	[item release];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear", nil) action:NULL keyEquivalent:@""];
	[item setTag:NSSearchFieldClearRecentsMenuItemTag];
	[cellMenu insertItem:item atIndex:2];
	[item release];
	
	return [cellMenu autorelease];
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
-(float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return (sender == splitView1 && offset == 0) ? MA_Minimum_Folder_Pane_Width : proposedMin;
}

/* constrainMaxCoordinate
 * Make sure that the browserview isn't shrunk beyond a minimum size otherwise the splitview
 * or controls within it start resizing odd.
 */
-(float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	if (sender == splitView1 && offset == 0)
	{
		NSRect mainFrame = [[splitView1 superview] frame];
		return mainFrame.size.width - MA_Minimum_BrowserView_Pane_Width;
	}
	return proposedMax;
}

/* resizeSubviewsWithOldSize
 * Constrain the folder pane to a fixed width.
 */
-(void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	float dividerThickness = [sender dividerThickness];
	id sv1 = [[sender subviews] objectAtIndex:0];
	id sv2 = [[sender subviews] objectAtIndex:1];
	NSRect leftFrame = [sv1 frame];
	NSRect rightFrame = [sv2 frame];
	NSRect newFrame = [sender frame];
	
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
	NSMenu * folderMenu = [[[NSMenu alloc] init] autorelease];
	[folderMenu addItem:copyOfMenuWithAction(@selector(refreshSelectedSubscriptions:))];
	[folderMenu addItem:[NSMenuItem separatorItem]];
	[folderMenu addItem:copyOfMenuWithAction(@selector(editFolder:))];
	[folderMenu addItem:copyOfMenuWithAction(@selector(deleteFolder:))];
	[folderMenu addItem:copyOfMenuWithAction(@selector(renameFolder:))];
	[folderMenu addItem:[NSMenuItem separatorItem]];
	[folderMenu addItem:copyOfMenuWithAction(@selector(markAllRead:))];
	[folderMenu addItem:[NSMenuItem separatorItem]];
	[folderMenu addItem:copyOfMenuWithAction(@selector(viewSourceHomePage:))];
	NSMenuItem * alternateItem = copyOfMenuWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	[alternateItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
	[alternateItem setAlternate:YES];
	[folderMenu addItem:alternateItem];
	[folderMenu addItem:copyOfMenuWithAction(@selector(getInfo:))];
	return folderMenu;
}

/* exitVienna
 * Alias for the terminate command.
 */
-(IBAction)exitVienna:(id)sender
{
	[NSApp terminate:nil];
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
-(void)setLayout:(int)newLayout withRefresh:(BOOL)refreshFlag
{
	// Turn off the filter bar when switching layouts. This is simpler than
	// trying to graft it onto the new layout.
	if ([self isFilterBarVisible])
		[self setPersistedFilterBarState:NO withAnimation:NO];

	switch (newLayout)
	{
	case MA_Layout_Report:
		[browserView setPrimaryTabItemView:mainArticleView];
		if (refreshFlag)
			[mainArticleView refreshFolder:MA_Refresh_RedrawList];
		[articleController setMainArticleView:mainArticleView];
		break;

	case MA_Layout_Condensed:
		[browserView setPrimaryTabItemView:mainArticleView];
		if (refreshFlag)
			[mainArticleView refreshFolder:MA_Refresh_RedrawList];
		[articleController setMainArticleView:mainArticleView];
		break;

	case MA_Layout_Unified:
		[browserView setPrimaryTabItemView:unifiedListView];
		if (refreshFlag)
			[unifiedListView refreshFolder:MA_Refresh_RedrawList];
		[articleController setMainArticleView:unifiedListView];
		break;
	}

	[browserView setTabItemViewTitle:[browserView primaryTabItemView] title:NSLocalizedString(@"Articles", nil)];

	[[Preferences standardPreferences] setLayout:newLayout];
	[self updateSearchPlaceholder];
	[[foldersTree mainView] setNextKeyView:[[browserView primaryTabItemView] mainView]];
}

#pragma mark Dock Menu

/* applicationDockMenu
 * Return a menu with additional commands to be displayd on the application's
 * popup dock menu.
 */
-(NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	[appDockMenu release];
	appDockMenu = [[NSMenu alloc] initWithTitle:@"DockMenu"];
	[appDockMenu addItem:copyOfMenuWithAction(@selector(refreshAllSubscriptions:))];
	[appDockMenu addItem:copyOfMenuWithAction(@selector(markAllSubscriptionsRead:))];
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
	int count = [newDefaultMenu count];
	int index;
	
	// Note: this is only safe to do if we're going from [count..0] when iterating
	// over newDefaultMenu. If we switch to the other direction, this will break.
	for (index = count - 1; index >= 0; --index)
	{
		NSMenuItem * menuItem = [newDefaultMenu objectAtIndex:index];
		switch ([menuItem tag])
		{
			case WebMenuItemTagOpenImageInNewWindow:
				imageURL = [element valueForKey:WebElementImageURLKey];
				if (imageURL != nil)
				{
					[menuItem setTitle:NSLocalizedString(@"Open Image in New Tab", nil)];
					[menuItem setTarget:self];
					[menuItem setAction:@selector(openWebElementInNewTab:)];
					[menuItem setRepresentedObject:imageURL];
					[menuItem setTag:WebMenuItemTagOther];
					newMenuItem = [[NSMenuItem alloc] init];
					if (newMenuItem != nil)
					{
						[newMenuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Open Image in %@", nil), defaultBrowser]];
						[newMenuItem setTarget:self];
						[newMenuItem setAction:@selector(openWebElementInDefaultBrowser:)];
						[newMenuItem setRepresentedObject:imageURL];
						[newMenuItem setTag:WebMenuItemTagOther];
						[newDefaultMenu insertObject:newMenuItem atIndex:index + 1];
					}
					[newMenuItem release];
				}
					break;
				
			case WebMenuItemTagOpenFrameInNewWindow:
				[menuItem setTitle:NSLocalizedString(@"Open Frame", nil)];
				break;
				
			case WebMenuItemTagOpenLinkInNewWindow:
				[menuItem setTitle:NSLocalizedString(@"Open Link in New Tab", nil)];
				[menuItem setTarget:self];
				[menuItem setAction:@selector(openWebElementInNewTab:)];
				[menuItem setRepresentedObject:urlLink];
				[menuItem setTag:WebMenuItemTagOther];
				newMenuItem = [[NSMenuItem alloc] init];
				if (newMenuItem != nil)
				{
					[newMenuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Open Link in %@", nil), defaultBrowser]];
					[newMenuItem setTarget:self];
					[newMenuItem setAction:@selector(openWebElementInDefaultBrowser:)];
					[newMenuItem setRepresentedObject:urlLink];
					[newMenuItem setTag:WebMenuItemTagOther];
					[newDefaultMenu insertObject:newMenuItem atIndex:index + 1];
				}
					[newMenuItem release];
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
		newMenuItem = [[NSMenuItem alloc] init];
		if (newMenuItem != nil)
		{
			[newMenuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Open Page in %@", nil), defaultBrowser]];
			[newMenuItem setTarget:self];
			[newMenuItem setAction:@selector(openPageInBrowser:)];
			[newMenuItem setTag:WebMenuItemTagOther];
			[newDefaultMenu addObject:newMenuItem];
		}
		[newMenuItem release];
		
		// Add command to copy the URL of the current page to the clipboard
		newMenuItem = [[NSMenuItem alloc] init];
		if (newMenuItem != nil)
		{
			[newMenuItem setTitle:NSLocalizedString(@"Copy Page Link to Clipboard", nil)];
			[newMenuItem setTarget:self];
			[newMenuItem setAction:@selector(copyPageURLToClipboard:)];
			[newMenuItem setTag:WebMenuItemTagOther];
			[newDefaultMenu addObject:newMenuItem];
		}
		[newMenuItem release];
	}
	
	return [newDefaultMenu autorelease];
}

/* openPageInBrowser
 * Open the current web page in the browser.
 */
-(IBAction)openPageInBrowser:(id)sender
{
	NSView<BaseView> * theView = [browserView activeTabItemView];
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		BrowserPane * webPane = (BrowserPane *)theView;
		NSURL * url = [webPane url];
		if (url != nil)
			[self openURLInDefaultBrowser:url];
	}
}

/* copyPageURLToClipboard
 * Copy the URL of the current web page to the clipboard.
 */
-(IBAction)copyPageURLToClipboard:(id)sender
{
	NSView<BaseView> * theView = [browserView activeTabItemView];
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		BrowserPane * webPane = (BrowserPane *)theView;
		NSURL * url = [webPane url];
		if (url != nil)
		{
			NSPasteboard * pboard = [NSPasteboard generalPasteboard];
			[pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NSURLPboardType, nil] owner:self];
			[url writeToPasteboard:pboard];
			[pboard setString:[url description] forType:NSStringPboardType];
		}
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

		BOOL openInBackground = [prefs openLinksInBackground];

		/* As Safari does, 'shift' inverts this behavior. Use GetCurrentKeyModifiers() because [NSApp currentEvent] was created
		 * when the current event began, which may be when the contexual menu opened.
		 */
		if (((GetCurrentKeyModifiers() & (shiftKey | rightShiftKey)) != 0))
			openInBackground = !openInBackground;

		[self createNewTab:[item representedObject] inBackground:openInBackground];
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
		[self openURLInDefaultBrowser:[item representedObject]];
	}
}

/* openWebLocation
 * Puts the focus in the address bar of the web browser tab. If one isn't open,
 * we create an empty one.
 */
-(IBAction)openWebLocation:(id)sender
{
	NSView<BaseView> * theView = [browserView activeTabItemView];
	[self showMainWindow:self];
	if (![theView isKindOfClass:[BrowserPane class]])
	{
		[self createNewTab:nil inBackground:NO];
		theView = [browserView activeTabItemView];
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
	[self openURL:[NSURL URLWithString:urlString] inPreferredBrowser:openInPreferredBrowserFlag];
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
	
	Preferences * prefs = [Preferences standardPreferences];
	BOOL openURLInVienna = [prefs openLinksInVienna];
	if (!openInPreferredBrowserFlag)
		openURLInVienna = (!openURLInVienna);
	if (openURLInVienna)
	{
		BOOL openInBackground = [prefs openLinksInBackground];

		/* As Safari does, 'shift' inverts this behavior. Use GetCurrentKeyModifiers() because [NSApp currentEvent] was created
		 * when the current event began, which may be when the contexual menu opened.
		 */
		if (((GetCurrentKeyModifiers() & (shiftKey | rightShiftKey)) != 0))
			openInBackground = !openInBackground;

		[self createNewTab:url inBackground:openInBackground];
	}
	else
		[self openURLInDefaultBrowser:url];
}

/* newTab
 * Create a new empty tab.
 */
-(IBAction)newTab:(id)sender
{
	// Create a new empty tab in the foreground.
	[self createNewTab:nil inBackground:NO];

	// Make the address bar first responder.
	NSView<BaseView> * theView = [browserView activeTabItemView];
	BrowserPane * browserPane = (BrowserPane *)theView;
	[browserPane activateAddressBar];
}

/* downloadEnclosure
 * Downloads the enclosures of the currently selected articles
 */
-(IBAction)downloadEnclosure:(id)sender
{
	NSArray * articleArray = [mainArticleView markedArticleRange];	
	if ([articleArray count] > 0) 
	{
		NSEnumerator *e = [articleArray objectEnumerator];
		id currentArticle;
		
		while ( (currentArticle = [e nextObject]) ) 
		{
			if ([currentArticle hasEnclosure])
			{
				NSString * filename = [[currentArticle enclosure] lastPathComponent];
				NSString * destPath = [DownloadManager fullDownloadPath:filename];
				[[DownloadManager sharedInstance] downloadFile:destPath fromURL:[currentArticle enclosure]];
			}
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
		BrowserPane * newBrowserPane = [newBrowserTemplate mainView];
		if (didCompleteInitialisation)
			[browserView saveOpenTabs];

		[browserView createNewTabWithView:newBrowserPane makeKey:!openInBackgroundFlag];
		[newBrowserPane setController:self];
		if (url != nil)
			[newBrowserPane loadURL:url inBackground:openInBackgroundFlag];
		else
			[browserView setTabItemViewTitle:newBrowserPane title:NSLocalizedString(@"New Tab", nil)];

		[newBrowserTemplate release];
	}
}

/* openURLInDefaultBrowser
 * Open the specified URL in whatever the user has registered as their
 * default system browser.
 */
-(void)openURLInDefaultBrowser:(NSURL *)url
{
	Preferences * prefs = [Preferences standardPreferences];
	
	// This line is a workaround for OS X bug rdar://4450641
	if ([prefs openLinksInBackground])
		[mainWindow orderFront:self];
	
	// Launch in the foreground or background as needed
	NSWorkspaceLaunchOptions lOptions = [prefs openLinksInBackground] ? NSWorkspaceLaunchWithoutActivation : NSWorkspaceLaunchDefault;
	[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url]
					withAppBundleIdentifier:NULL
									options:lOptions
			 additionalEventParamDescriptor:NULL
						  launchIdentifiers:NULL];
}

/* loadOpenTabs
 * Opens separate tabs for each of the URLs persisted to the TabList preference.
 */
-(void)loadOpenTabs
{
	NSArray * tabLinks = [[Preferences standardPreferences] arrayForKey:MAPref_TabList];
	NSEnumerator * enumerator = [tabLinks objectEnumerator];
	NSString * tabLink;
	
	while ((tabLink = [enumerator nextObject]) != nil) {
		[self createNewTab:([tabLink length] ? [NSURL URLWithString:tabLink] : nil) inBackground:YES];
	}
}

/* setImageForMenuCommand
 * Sets the image for a specified menu command.
 */
-(void)setImageForMenuCommand:(NSImage *)image forAction:(SEL)sel
{
	NSArray * arrayOfMenus = [[NSApp mainMenu] itemArray];
	int count = [arrayOfMenus count];
	int index;
	
	for (index = 0; index < count; ++index)
	{
		NSMenu * subMenu = [[arrayOfMenus objectAtIndex:index] submenu];
		int itemIndex = [subMenu indexOfItemWithTarget:self andAction:sel];
		if (itemIndex >= 0)
		{
			[[subMenu itemAtIndex:itemIndex] setImage:image];
			return;
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
	[mainWindow makeKeyAndOrderFront:self];
}

/* keepFoldersArranged
 * Toggle the arrangement of the folders list.
 */
-(IBAction)keepFoldersArranged:(id)sender
{
	[[Preferences standardPreferences] setFoldersTreeSortMethod:[sender tag]];
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
		NSString * baseScriptName = [[scriptName lastPathComponent] stringByDeletingPathExtension];
		runOKAlertPanel([NSString stringWithFormat:NSLocalizedString(@"Error loading script '%@'", nil), baseScriptName],
						[errorDictionary valueForKey:NSAppleScriptErrorMessage]);
	}
	else
	{
		NSAppleEventDescriptor * resultEvent = [appleScript executeAndReturnError:&errorDictionary];
		[appleScript release];
		if (resultEvent == nil)
		{
			NSString * baseScriptName = [[scriptName lastPathComponent] stringByDeletingPathExtension];
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
	return [filterView superview] != nil;
}

/* handleShowFilterBar
 * Respond to the filter bar being shown or hidden programmatically.
 */
-(void)handleShowFilterBar:(NSNotification *)nc
{
	if ([browserView activeTabItemView] == [browserView primaryTabItemView])
		[self setFilterBarState:[[Preferences standardPreferences] showFilterBar] withAnimation:YES];
}

/* showHideFilterBar
 * Toggle the filter bar on/off.
 */
-(IBAction)showHideFilterBar:(id)sender
{
	[self setPersistedFilterBarState:![self isFilterBarVisible] withAnimation:YES];
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
	[[Preferences standardPreferences] setShowFilterBar:isVisible];
}

/* setFilterBarState
 * Show or hide the filter bar. The withAnimation flag specifies whether or not we do the
 * animated show/hide. It should be set to NO for actions that are not user initiated as
 * otherwise the background rendering of the control can cause complications.
 */
-(void)setFilterBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate
{
	if (isVisible && ![self isFilterBarVisible])
	{
		NSView * parentView = [[[articleController mainArticleView] subviews] objectAtIndex:0];
		NSRect filterBarRect;
		NSRect mainRect;
	
		mainRect = [parentView bounds];
		filterBarRect = [filterView bounds];
		filterBarRect.size.width = mainRect.size.width;
		filterBarRect.origin.y = mainRect.size.height - filterBarRect.size.height;
		mainRect.size.height -= filterBarRect.size.height;
		
		[[parentView superview] addSubview:filterView];
		[filterView setFrame:filterBarRect];
		if (!doAnimate)
			[parentView setFrame:mainRect];
		else
			[parentView resizeViewWithAnimation:mainRect withTag:MA_ViewTag_Filterbar];
		[parentView display];

		// Hook up the Tab ordering so Tab from the search field goes to the
		// article view.
		[[foldersTree mainView] setNextKeyView:filterSearchField];
		[filterSearchField setNextKeyView:[[browserView primaryTabItemView] mainView]];

		// Set focus only if this was user initiated
		if (doAnimate)
			[mainWindow makeFirstResponder:filterSearchField];
	}
	if (!isVisible && [self isFilterBarVisible])
	{
		NSView * parentView = [[[articleController mainArticleView] subviews] objectAtIndex:0];
		NSRect filterBarRect;
		NSRect mainRect;

		mainRect = [parentView bounds];
		filterBarRect = [filterView bounds];
		mainRect.size.height += filterBarRect.size.height;

		[filterView removeFromSuperview];
		if (!doAnimate)
			[parentView setFrame:mainRect];
		else
			[parentView resizeViewWithAnimation:mainRect withTag:MA_ViewTag_Filterbar];
		[parentView setNeedsDisplay:YES];

		// Fix up the tab ordering
		[[foldersTree mainView] setNextKeyView:[[browserView primaryTabItemView] mainView]];

		// Clear the filter, otherwise we end up with no way remove it!
		[self setSearchString:@""];
		if (doAnimate)
		{
			[self searchUsingFilterField:self];

			// If the focus was originally on the filter bar then we should
			// move it to the message list
			if ([mainWindow firstResponder] == mainWindow)
				[mainWindow makeFirstResponder:[[browserView primaryTabItemView] mainView]];
		}
	}
}

#pragma mark Growl Delegate

/* growlNotify
 * Sends out the specified notification event if Growl is installed and ready.
 */
-(void)growlNotify:(id)notifyContext title:(NSString *)title description:(NSString *)description notificationName:(NSString *)notificationName
{
	if (growlAvailable)
		[GrowlApplicationBridge notifyWithTitle:title
									description:description
							   notificationName:notificationName
									   iconData:nil
									   priority:0.0
									   isSticky:NO
								   clickContext:notifyContext];
}

/* growlIsReady
 * Called by Growl when it is loaded. We use this as a trigger to acknowledge its existence.
 */
-(void)growlIsReady
{
	if (!growlAvailable)
	{
		[GrowlApplicationBridge setGrowlDelegate:self];
		growlAvailable = YES;
	}
}

/* growlNotificationWasClicked
 * Called when the user clicked a Growl notification balloon.
 */
-(void)growlNotificationWasClicked:(id)clickContext
{
	NSDictionary * contextDict = (NSDictionary *)clickContext;
	int contextValue = [[contextDict valueForKey:@"ContextType"] intValue];

	if (contextValue == MA_GrowlContext_RefreshCompleted)
	{
		[self openVienna:self];
		Folder * unreadArticles = [db folderFromName:NSLocalizedString(@"Unread Articles", nil)];
		if (unreadArticles != nil)
			[foldersTree selectFolder:[unreadArticles itemId]];
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
	NSMutableArray *defNotesArray = [NSMutableArray array];
	NSMutableArray *allNotesArray = [NSMutableArray array];

	[allNotesArray addObject:NSLocalizedString(@"Growl refresh completed", nil)];
	[allNotesArray addObject:NSLocalizedString(@"Growl download completed", nil)];
	[allNotesArray addObject:NSLocalizedString(@"Growl download failed", nil)];

	[defNotesArray addObject:NSLocalizedString(@"Growl refresh completed", nil)];
	[defNotesArray addObject:NSLocalizedString(@"Growl download completed", nil)];
	[defNotesArray addObject:NSLocalizedString(@"Growl download failed", nil)];
	
	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
		[self appName], GROWL_APP_NAME, 
		allNotesArray, GROWL_NOTIFICATIONS_ALL, 
		defNotesArray, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
	growlAvailable = YES;
	return regDict;
}

/* initSortMenu
 * Create the sort popup menu.
 */
-(void)initSortMenu
{
	NSMenu * sortMenu = [[[NSMenu alloc] initWithTitle:@"Sort By"] autorelease];
	NSArray * fields = [db arrayOfFields];
	NSEnumerator * enumerator = [fields objectEnumerator];
	Field * field;
	
	while ((field = [enumerator nextObject]) != nil)
	{
		// Filter out columns we don't sort on. Later we should have an attribute in the
		// field object itself based on which columns we can sort on.
		if ([field tag] != MA_FieldID_Parent &&
			[field tag] != MA_FieldID_GUID &&
			[field tag] != MA_FieldID_Comments &&
			[field tag] != MA_FieldID_Deleted &&
			[field tag] != MA_FieldID_Headlines &&
			[field tag] != MA_FieldID_Summary &&
			[field tag] != MA_FieldID_Link &&
			[field tag] != MA_FieldID_Text &&
			[field tag] != MA_FieldID_EnclosureDownloaded &&
			[field tag] != MA_FieldID_Enclosure)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[field displayName] action:@selector(doSortColumn:) keyEquivalent:@""];
			[menuItem setRepresentedObject:field];
			[sortMenu addItem:menuItem];
			[menuItem release];
		}
	}
	[sortByMenu setSubmenu:sortMenu];
}

/* initColumnsMenu
 * Create the columns popup menu.
 */
-(void)initColumnsMenu
{
	NSMenu * columnsSubMenu = [[[NSMenu alloc] initWithTitle:@"Columns"] autorelease];
	NSArray * fields = [db arrayOfFields];
	NSEnumerator * enumerator = [fields objectEnumerator];
	Field * field;
	
	while ((field = [enumerator nextObject]) != nil)
	{
		// Filter out columns we don't view in the article list. Later we should have an attribute in the
		// field object based on which columns are visible in the tableview.
		if ([field tag] != MA_FieldID_Text && 
			[field tag] != MA_FieldID_GUID &&
			[field tag] != MA_FieldID_Comments &&
			[field tag] != MA_FieldID_Deleted &&
			[field tag] != MA_FieldID_Parent &&
			[field tag] != MA_FieldID_Headlines &&
			[field tag] != MA_FieldID_EnclosureDownloaded)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[field displayName] action:@selector(doViewColumn:) keyEquivalent:@""];
			[menuItem setRepresentedObject:field];
			[columnsSubMenu addItem:menuItem];
			[menuItem release];
		}
	}
	[columnsMenu setSubmenu:columnsSubMenu];
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
	NSArray * exts = [NSArray arrayWithObjects:@"scpt", nil];
	
	// Dump the current mappings
	[scriptPathMappings removeAllObjects];
	
	// Add scripts within the app resource
	NSString * path = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"Scripts"];
	loadMapFromPath(path, scriptPathMappings, NO, exts);
	
	// Add scripts that the user created and stored in the scripts folder
	path = [[Preferences standardPreferences] scriptsFolder];
	loadMapFromPath(path, scriptPathMappings, NO, exts);
	
	// Add the contents of the scriptsPathMappings dictionary keys to the menu sorted
	// by key name.
	NSArray * sortedMenuItems = [[scriptPathMappings allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	int count = [sortedMenuItems count];
	
	// Insert the Scripts menu to the left of the Help menu only if
	// we actually have any scripts.
	if (count > 0)
	{
		NSMenu * scriptsMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Scripts"];
		
		int index;
		for (index = 0; index < count; ++index)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[sortedMenuItems objectAtIndex:index]
															   action:@selector(doSelectScript:)
														keyEquivalent:@""];
			[scriptsMenu addItem:menuItem];
			[menuItem release];
		}
		
		[scriptsMenu addItem:[NSMenuItem separatorItem]];
		NSMenuItem * menuItem;
		
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Scripts Folder", nil) action:@selector(doOpenScriptsFolder:) keyEquivalent:@""];
		[scriptsMenu addItem:menuItem];
		[menuItem release];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"More Scripts...", nil) action:@selector(moreScripts:) keyEquivalent:@""];
		[scriptsMenu addItem:menuItem];
		[menuItem release];
		
		// If this is the first call to initScriptsMenu, create the scripts menu. Otherwise we just
		// update the one we have.
		if (scriptsMenuItem != nil)
		{
			[[NSApp mainMenu] removeItem:scriptsMenuItem];
			[scriptsMenuItem release];
		}
		
		scriptsMenuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Scripts" action:NULL keyEquivalent:@""];
		[scriptsMenuItem setImage:[NSImage imageNamed:@"scriptMenu.tiff"]];
		
		int helpMenuIndex = [[NSApp mainMenu] numberOfItems] - 1;
		[[NSApp mainMenu] insertItem:scriptsMenuItem atIndex:helpMenuIndex];
		[scriptsMenuItem setSubmenu:scriptsMenu];
		
		[scriptsMenu release];
	}
}

/* getStylesMenu
 * Returns a menu with a list of built-in and external styles. (Note that in the event of
 * duplicates the styles in the external Styles folder wins. This is intended to allow the user to
 * override the built-in styles if necessary).
 */
-(NSMenu *)getStylesMenu
{
	NSMenu * stylesSubMenu = [[[NSMenu alloc] initWithTitle:@"Style"] autorelease];
	
	// Reinitialise the styles map
	NSDictionary * stylesMap = [ArticleView loadStylesMap];
	
	// Add the contents of the stylesPathMappings dictionary keys to the menu sorted by key name.
	NSArray * sortedMenuItems = [[stylesMap allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	int count = [sortedMenuItems count];
	int index;
	
	for (index = 0; index < count; ++index)
	{
		NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[sortedMenuItems objectAtIndex:index] action:@selector(doSelectStyle:) keyEquivalent:@""];
		[stylesSubMenu addItem:menuItem];
		[menuItem release];
	}

	// Append a link to More Styles...
	[stylesSubMenu addItem:[NSMenuItem separatorItem]];
	NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"More Styles...", nil) action:@selector(moreStyles:) keyEquivalent:@""];
	[stylesSubMenu addItem:menuItem];
	[menuItem release];
	return stylesSubMenu;
}

/* initFiltersMenu
 * Populate both the Filters submenu on the View menu and the Filters popup menu on the Filter
 * button in the article list. We need separate menus since the latter is eventually configured
 * to use a smaller font than the former.
 */
-(void)initFiltersMenu
{
	NSMenu * filterSubMenu = [[[NSMenu alloc] initWithTitle:@"Filter By"] autorelease];
	NSMenu * filterPopupMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];

	NSArray * filtersArray = [ArticleFilter arrayOfFilters];
	int count = [filtersArray count];
	int index;
	
	for (index = 0; index < count; ++index)
	{
		ArticleFilter * filter = [filtersArray objectAtIndex:index];

		NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString([filter name], nil) action:@selector(changeFiltering:) keyEquivalent:@""];
		[menuItem setTag:[filter tag]];
		[filterSubMenu addItem:menuItem];
		[menuItem release];

		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString([filter name], nil) action:@selector(changeFiltering:) keyEquivalent:@""];
		[menuItem setTag:[filter tag]];
		[filterPopupMenu addItem:menuItem];
		[menuItem release];
	}
	
	// Add it to the Filters menu
	[filtersMenu setSubmenu:filterSubMenu];
	[filterViewPopUp setMenu:filterPopupMenu];
	
	// Sync the popup selection with user preferences
	int indexOfDefaultItem = [filterViewPopUp indexOfItemWithTag:[[Preferences standardPreferences] filterMode]];
	if (indexOfDefaultItem != -1)
	{
		[filterViewPopUp selectItemAtIndex:indexOfDefaultItem];
	}
}

/* updateNewArticlesNotification
 * Respond to a change in how we notify when new articles are retrieved.
 */
-(void)updateNewArticlesNotification
{
	switch ([[Preferences standardPreferences] newArticlesNotification])
	{
		case MA_NewArticlesNotification_Badge:
			lastCountOfUnread = -1;	// Force an update
			[self showUnreadCountOnApplicationIconAndWindowTitle];
			break;

		case MA_NewArticlesNotification_None:
		case MA_NewArticlesNotification_Bounce:
			// Remove the badge if there was one.
			if ([NSApp applicationIconImage] != originalIcon)
				[NSApp setApplicationIconImage:originalIcon];
			break;
	}
}

/* initBlogWithMenu
 * Implements auto-discovery of supported blogging tools for use with blogWithExternalEditor.
 * Creates a submenu with all known tools found on the system. The dictionary that describes all supported tools currently lives in info.plist.
 */
-(void)initBlogWithMenu
{
	NSMenu * blogWithSubMenu = [[[NSMenu alloc] initWithTitle:@"BlogWith"] autorelease];
	
	// Get bundle identifiers for supported editors from info.plist
	NSDictionary * supportedEditors = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SupportedEditorsBundleIdentifiers"];

	// Add the contents of the supportedEditors dictionary keys to the menu, sorted by key name.
	NSArray * sortedMenuItems = [[supportedEditors allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSEnumerator *e = [sortedMenuItems objectEnumerator];
	NSString * lastItem = nil;
	int countOfItems = 0;
	id currentItem;

	while ((currentItem = [e nextObject]) != nil) 
	{
		// Only add the item if the application is present on the system.
		if ( [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: [supportedEditors valueForKey:currentItem]] ) 
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:currentItem action:@selector(blogWith:) keyEquivalent:@""];
			[menuItem setRepresentedObject:currentItem];
			[blogWithSubMenu addItem:menuItem];
			[menuItem release];
			lastItem = currentItem;
			++countOfItems;
		}
	}
	
	// If no items, remove both the single and submenu blog items.
	// Otherwise if there's one item, set the title of the single item and remove the submenu.
	// Otherwise remove the single item.
	if (countOfItems == 0)
	{
		[[blogWithMenu menu] removeItem:blogWithMenu];
		[[blogWithOneMenu menu] removeItem:blogWithOneMenu];
	}
	else if (countOfItems == 1)
	{
		NSString * blogMenuItem = [NSString stringWithFormat:NSLocalizedString(@"Blog with %@", nil), lastItem];
		[blogWithOneMenu setTitle:blogMenuItem];
		[blogWithOneMenu setRepresentedObject:lastItem];
		[[blogWithMenu menu] removeItem:blogWithMenu];
	}
	else
	{
		[[blogWithOneMenu menu] removeItem:blogWithOneMenu];
		[blogWithMenu setSubmenu:blogWithSubMenu];
	}
}

/* showUnreadCountOnApplicationIconAndWindowTitle
 * Update the Vienna application icon to show the number of unread articles.
 */
-(void)showUnreadCountOnApplicationIconAndWindowTitle
{
	int currentCountOfUnread = [db countOfUnread];
	if (currentCountOfUnread == lastCountOfUnread)
		return;
	lastCountOfUnread = currentCountOfUnread;

	// Always update the app status icon first
	[self setAppStatusBarIcon];
	
	// Don't show a count if there are no unread articles
	if (currentCountOfUnread <= 0)
	{
		[NSApp setApplicationIconImage:originalIcon];
		[mainWindow setTitle:[self appName]];
		return;	
	}	

	[mainWindow setTitle:[[NSString stringWithFormat:@"%@ -", [self appName]]
		stringByAppendingString:[NSString stringWithFormat:
			NSLocalizedString(@" (%d unread)", nil), currentCountOfUnread]]];

	// Exit now if we're not showing the unread count on the application icon
	if ([[Preferences standardPreferences] newArticlesNotification] != MA_NewArticlesNotification_Badge)
		return;

	NSString * countdown = [NSString stringWithFormat:@"%i", currentCountOfUnread];
	NSImage * iconImageBuffer = [originalIcon copy];
	NSSize iconSize = [originalIcon size];
	
	// Create attributes for drawing the count. In our case, we're drawing using in
	// 26pt Helvetica bold white.
	NSDictionary * attributes = [[NSDictionary alloc] 
		initWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica-Bold" size:25], NSFontAttributeName,
		[NSColor whiteColor], NSForegroundColorAttributeName, nil];
	NSSize numSize = [countdown sizeWithAttributes:attributes];
	
	// Create a red circle in the icon large enough to hold the count.
	[iconImageBuffer lockFocus];
	[originalIcon drawAtPoint:NSMakePoint(0, 0)
					 fromRect:NSMakeRect(0, 0, iconSize.width, iconSize.height) 
					operation:NSCompositeSourceOver 
					 fraction:1.0f];
	
	float max = (numSize.width > numSize.height) ? numSize.width : numSize.height;
	max += 21;
	NSRect circleRect = NSMakeRect(iconSize.width - max, iconSize.height - max, max, max);
	
	// Draw the star image and scale it so the unread count will fit inside.
	NSImage * starImage = [NSImage imageNamed:@"unreadStar1.tiff"];
	[starImage setScalesWhenResized:YES];
	[starImage setSize:circleRect.size];
	[starImage compositeToPoint:circleRect.origin operation:NSCompositeSourceOver];
	
	// Draw the count in the red circle
	NSPoint point = NSMakePoint(NSMidX(circleRect) - numSize.width / 2.0f + 2.0f,  NSMidY(circleRect) - numSize.height / 2.0f + 2.0f);
	[countdown drawAtPoint:point withAttributes:attributes];
	
	// Now set the new app icon and clean up.
	[iconImageBuffer unlockFocus];
	[NSApp setApplicationIconImage:iconImageBuffer];
	[iconImageBuffer release];
	[attributes release];
}

/* handleAbout
 * Display our About Vienna... window.
 */
-(IBAction)handleAbout:(id)sender
{
	NSDictionary * fileAttributes = [[NSBundle mainBundle] infoDictionary];
	NSString * version = [fileAttributes objectForKey:@"CFBundleShortVersionString"];
	NSString * versionString = [NSString stringWithFormat:NSLocalizedString(@"Version %@", nil), version];
	NSDictionary * d = [NSDictionary dictionaryWithObjectsAndKeys:versionString, @"ApplicationVersion", @"", @"Version", nil, nil];
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
							  nil, [NSApp mainWindow], self,
							  @selector(doConfirmedEmptyTrash:returnCode:contextInfo:), nil, nil,
							  NSLocalizedString(@"Empty Trash message text", nil));
}

/* doConfirmedEmptyTrash
 * This function is called after the user has dismissed
 * the confirmation sheet.
 */
-(void)doConfirmedEmptyTrash:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
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
	GotoHelpPage((CFStringRef)@"keyboard.html", (CFStringRef)@"");
}

/* showPreferencePanel
 * Display the Preference Panel.
 */
-(IBAction)showPreferencePanel:(id)sender
{
	if (!preferenceController)
		preferenceController = [[NewPreferencesController alloc] init];
	[NSApp activateIgnoringOtherApps:YES];
	[preferenceController showWindow:self];
}

/* printDocument
 * Print the selected articles in the article window.
 */
-(IBAction)printDocument:(id)sender
{
	[[browserView activeTabItemView] printDocument:sender];
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
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
}

/* selectedArticle
 * Returns the current selected article in the article pane.
 */
-(Article *)selectedArticle
{
	return [articleController selectedArticle];
}

/* currentFolderId
 * Return the ID of the currently selected folder whose articles are shown in
 * the article window.
 */
-(int)currentFolderId
{
	return [articleController currentFolderId];
}

/* selectFolder
 * Select the specified folder.
 */
-(void)selectFolder:(int)folderId
{
	[foldersTree selectFolder:folderId];
}

/* updateCloseCommands
 * Update the keystrokes assigned to the Close Tab and Close Window
 * commands depending on whether any tabs are opened.
 */
-(void)updateCloseCommands
{
	if ([browserView countOfTabs] < 2 || ![mainWindow isKeyWindow])
	{
		[closeTabItem setKeyEquivalent:@""];
		[closeAllTabsItem setKeyEquivalent:@""];
		[closeWindowItem setKeyEquivalent:@"w"];
		[closeWindowItem setKeyEquivalentModifierMask:NSCommandKeyMask];
	}
	else
	{
		[closeTabItem setKeyEquivalent:@"w"];
		[closeTabItem setKeyEquivalentModifierMask:NSCommandKeyMask];
		[closeAllTabsItem setKeyEquivalent:@"w"];
		[closeAllTabsItem setKeyEquivalentModifierMask:NSCommandKeyMask|NSAlternateKeyMask];
		[closeWindowItem setKeyEquivalent:@"W"];
		[closeWindowItem setKeyEquivalentModifierMask:NSCommandKeyMask];
	}
}

/* showAppInStatusBar
 * Add or remove the app icon from the system status bar.
 */
-(void)showAppInStatusBar
{
	Preferences * prefs = [Preferences standardPreferences];
	if ([prefs showAppInStatusBar] && appStatusItem == nil)
	{
		appStatusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
		[self setAppStatusBarIcon];
		[appStatusItem setHighlightMode:YES];

		NSMenu * statusBarMenu = [[NSMenu alloc] initWithTitle:@"StatusBarMenu"];
		[statusBarMenu addItem:menuWithTitleAndAction(NSLocalizedString(@"Open Vienna", nil), @selector(openVienna:))];
		[statusBarMenu addItem:[NSMenuItem separatorItem]];
		[statusBarMenu addItem:copyOfMenuWithAction(@selector(refreshAllSubscriptions:))];
		[statusBarMenu addItem:copyOfMenuWithAction(@selector(markAllSubscriptionsRead:))];
		[statusBarMenu addItem:[NSMenuItem separatorItem]];
		[statusBarMenu addItem:copyOfMenuWithAction(@selector(showPreferencePanel:))];
		[statusBarMenu addItem:copyOfMenuWithAction(@selector(handleAbout:))];
		[statusBarMenu addItem:[NSMenuItem separatorItem]];
		[statusBarMenu addItem:copyOfMenuWithAction(@selector(exitVienna:))];
		[appStatusItem setMenu:statusBarMenu];
		[statusBarMenu release];
	}
	else if (![prefs showAppInStatusBar] && appStatusItem != nil)
	{
		[[NSStatusBar systemStatusBar] removeStatusItem:appStatusItem];
		[appStatusItem release];
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
			[appStatusItem setImage:[NSImage imageNamed:@"statusBarIcon.tiff"]];
			[appStatusItem setTitle:nil];
		}
		else
		{
			[appStatusItem setImage:[NSImage imageNamed:@"statusBarIconUnread.tiff"]];
			[appStatusItem setTitle:[NSString stringWithFormat:@"%u", lastCountOfUnread]];
		}
	}
}

/* handleRSSLink
 * Handle feed://<rss> links. If we're already subscribed to the link then make the folder
 * active. Otherwise offer to subscribe to the link.
 */
-(void)handleRSSLink:(NSString *)linkPath
{
	[self createNewSubscription:linkPath underFolder:[foldersTree groupParentSelection] afterChild:-1];
}

/* handleEditFolder
 * Respond to an edit folder notification.
 */
-(void)handleEditFolder:(NSNotification *)nc
{
	TreeNode * node = (TreeNode *)[nc object];
	Folder * folder = [db folderFromID:[node nodeId]];
	[self doEditFolder:folder];
}

/* editFolder
 * Handles the Edit command
 */
-(IBAction)editFolder:(id)sender
{
	Folder * folder = [db folderFromID:[foldersTree actualSelection]];
	[self doEditFolder:folder];
}

/* doEditFolder
 * Handles an edit action on the specified folder.
 */
-(void)doEditFolder:(Folder *)folder
{
	if (IsRSSFolder(folder))
	{
		if (!rssFeed)
			rssFeed = [[NewSubscription alloc] initWithDatabase:db];
		[rssFeed editSubscription:mainWindow folderId:[folder itemId]];
	}
	else if (IsSmartFolder(folder))
	{
		if (!smartFolder)
			smartFolder = [[SmartFolder alloc] initWithDatabase:db];
		[smartFolder loadCriteria:mainWindow folderId:[folder itemId]];
	}
}

/* handleFolderSelection
 * Called when the selection changes in the folder pane.
 */
-(void)handleFolderSelection:(NSNotification *)nc
{
	TreeNode * node = (TreeNode *)[nc object];
	int newFolderId = [node nodeId];

	// We don't filter when we switch folders.
	[self setSearchString:@""];

	// Call through the controller to display the new folder.
	[articleController displayFolder:newFolderId];
	[self updateSearchPlaceholder];
	
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
	[mainArticleView updateAlternateMenuTitle];
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
	int newFrequency = [[Preferences standardPreferences] refreshFrequency];
	
	[checkTimer invalidate];
	[checkTimer release];
	checkTimer = nil;
	if (newFrequency > 0)
	{
		checkTimer = [[NSTimer scheduledTimerWithTimeInterval:newFrequency
													   target:self
													 selector:@selector(refreshOnTimer:)
													 userInfo:nil
													  repeats:NO] retain];
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
	Field * field = [menuItem representedObject];
	
	[field setVisible:![field visible]];
	if ([[field name] isEqualToString:MA_Field_Summary] && [field visible])
		[articleController createArticleSummaries];
	[mainArticleView updateVisibleColumns];
	[mainArticleView saveTableSettings];
}

/* doSortColumn
 * Handle the user picking an item from the Sort By submenu
 */
-(IBAction)doSortColumn:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	Field * field = [menuItem representedObject];
	
	NSAssert1(field, @"Somehow got a nil representedObject for Sort sub-menu item '%@'", [menuItem title]);
	[articleController sortByIdentifier:[field name]];
}

/* doOpenScriptsFolder
 * Open the standard Vienna scripts folder.
 */
-(IBAction)doOpenScriptsFolder:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:[[Preferences standardPreferences] scriptsFolder]];
}

/* doSelectScript
 * Run a script selected from the Script menu.
 */
-(IBAction)doSelectScript:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	NSString * scriptPath = [scriptPathMappings valueForKey:[menuItem title]];
	if (scriptPath != nil)
		[self runAppleScript:scriptPath];
}

/* doSelectStyle
 * Handle a selection from the Style menu.
 */
-(IBAction)doSelectStyle:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	[[Preferences standardPreferences] setDisplayStyle:[menuItem title]];
}

/* handleTabChange
 * Handle a change in the active tab field.
 */
-(void)handleTabChange:(NSNotification *)nc
{
	NSView<BaseView> * newView = [nc object];
	if (newView == [browserView primaryTabItemView])
	{
		if ([self selectedArticle] == nil)
			[mainWindow makeFirstResponder:[foldersTree mainView]];
		else
			[mainWindow makeFirstResponder:[[browserView primaryTabItemView] mainView]];		
	}
	else
	{
		BrowserPane * webPane = (BrowserPane *)newView;
		[mainWindow makeFirstResponder:[webPane mainView]];
	}
	[self updateSearchPlaceholder];
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
	int folderId = [(NSNumber *)[nc object] intValue];
	if (folderId == [articleController currentFolderId])
		[self updateSearchPlaceholder];
}

/* handleRefreshStatusChange
 * Handle a change of the refresh status.
 */
-(void)handleRefreshStatusChange:(NSNotification *)nc
{
	if ([NSApp isRefreshing])
	{
		// Save the date/time of this refresh so we do the right thing when
		// we apply the filter.
		[[Preferences standardPreferences] setObject:[NSCalendarDate date] forKey:MAPref_LastRefreshDate];
		
		// Toggle the refresh button
		ToolbarItem * item = [self toolbarItemWithIdentifier:@"Refresh"];
		[item setAction:@selector(cancelAllRefreshes:)];
		[item setButtonImage:@"cancelRefreshButton"];

		[self startProgressIndicator];
		[self setStatusMessage:[[RefreshManager sharedManager] statusMessageDuringRefresh] persist:YES];
	}
	else
	{
		// Run the auto-expire now
		Preferences * prefs = [Preferences standardPreferences];
		[db purgeArticlesOlderThanDays:[prefs autoExpireDuration]];
		
		[self setStatusMessage:NSLocalizedString(@"Refresh completed", nil) persist:YES];
		[self stopProgressIndicator];
		
		// Toggle the refresh button
		ToolbarItem * item = [self toolbarItemWithIdentifier:@"Refresh"];
		[item setAction:@selector(refreshAllSubscriptions:)];
		[item setButtonImage:@"refreshButton"];

		[self showUnreadCountOnApplicationIconAndWindowTitle];
		
		// Refresh the current folder.
		[articleController refreshCurrentFolder];
		
		// Bounce the dock icon for 1 second if the bounce method has been selected.
		int newUnread = [[RefreshManager sharedManager] countOfNewArticles];
		if (newUnread > 0 && [prefs newArticlesNotification] == MA_NewArticlesNotification_Bounce)
			[NSApp requestUserAttention:NSInformationalRequest];

		// Growl notification
		if (newUnread > 0)
		{
			NSMutableDictionary * contextDict = [NSMutableDictionary dictionary];
			[contextDict setValue:[NSNumber numberWithInt:MA_GrowlContext_RefreshCompleted] forKey:@"ContextType"];

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

/* viewArticlePage
 * Display the article in the browser.
 */
-(IBAction)viewArticlePage:(id)sender
{
	Article * theArticle = [self selectedArticle];
	if (theArticle && ![[theArticle link] isBlank])
		[self openURLFromString:[theArticle link] inPreferredBrowser:YES];
}

/* viewArticlePageInAlternateBrowser
 * Display the article in the non-preferred browser.
 */
-(IBAction)viewArticlePageInAlternateBrowser:(id)sender
{
	Article * theArticle = [self selectedArticle];
	if (theArticle && ![[theArticle link] isBlank])
		[self openURLFromString:[theArticle link] inPreferredBrowser:NO];
}

/* goForward
 * In article view, forward track through the list of articles displayed. In 
* web view, go to the next web page.
 */
-(IBAction)goForward:(id)sender
{
	[[browserView activeTabItemView] handleGoForward:sender];
}

/* goBack
 * In article view, back track through the list of articles displayed. In 
 * web view, go to the previous web page.
 */
-(IBAction)goBack:(id)sender
{
	[[browserView activeTabItemView] handleGoBack:sender];
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
		[searchField setStringValue:[NSApp currentSelection]];
		[searchPanel setSearchString:[NSApp currentSelection]];
		break;

	case NSFindPanelActionShowFindPanel:
		[self setFocusToSearchField:self];
		break;
		
	default:
		[[browserView activeTabItemView] performFindPanelAction:[sender tag]];
		break;
	}
}

#pragma mark Key Listener

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(unsigned int)flags
{
	if (keyChar >= '0' && keyChar <= '9' && (flags & NSControlKeyMask))
	{
		int layoutStyle = MA_Layout_Report + (keyChar - '0');
		[self setLayout:layoutStyle withRefresh:YES];
		return YES;
	}
	switch (keyChar)
	{
		case NSLeftArrowFunctionKey:
			if (flags & NSCommandKeyMask)
				return NO;
			else
			{
				if ([mainWindow firstResponder] == [[browserView primaryTabItemView] mainView])
				{
					[mainWindow makeFirstResponder:[foldersTree mainView]];
					return YES;
				}
			}
			return NO;
			
		case NSRightArrowFunctionKey:
			if (flags & NSCommandKeyMask)
				return NO;
			else
			{
				if ([mainWindow firstResponder] == [foldersTree mainView])
				{
					[browserView setActiveTabToPrimaryTab];
					if ([self selectedArticle] == nil)
						[articleController ensureSelectedArticle:NO];
					[mainWindow makeFirstResponder:([self selectedArticle] != nil) ? [[browserView primaryTabItemView] mainView] : [foldersTree mainView]];
					return YES;
				}
			}
			return NO;
			
		case NSDeleteFunctionKey:
		case NSDeleteCharacter:
			if ([mainWindow firstResponder] == [foldersTree mainView])
			{
				[self deleteFolder:self];
				return YES;
			}
			else if ([mainWindow firstResponder] == [mainArticleView mainView])
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
			if (![self isFilterBarVisible])
				[self setPersistedFilterBarState:YES withAnimation:YES];
			else
				[mainWindow makeFirstResponder:filterSearchField];
			return YES;
			
		case '>':
			[self goForward:self];
			return YES;
			
		case '<':
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
			
		case 'n':
		case 'N':
			[self viewNextUnread:self];
			return YES;
			
		case 'u':
		case 'U':
		case 'r':
		case 'R':
			[self markRead:self];
			return YES;
			
		case 's':
		case 'S':
			[self skipFolder:self];
			return YES;
			
		case NSEnterCharacter:
		case NSCarriageReturnCharacter:
			if ([mainWindow firstResponder] == [foldersTree mainView])
			{
				if (flags & NSAlternateKeyMask)
					[self viewSourceHomePageInAlternateBrowser:self];
				else
					[self viewSourceHomePage:self];
				return YES;
			}
			else if ([mainWindow firstResponder] == [mainArticleView mainView])
			{
				if (flags & NSAlternateKeyMask)
					[self viewArticlePageInAlternateBrowser:self];
				else
					[self viewArticlePage:self];
				return YES;
			}
			return NO;

		case ' ': //SPACE
		{
			WebView * view = [[browserView activeTabItemView] webView];
			NSView * theView = [[[view mainFrame] frameView] documentView];

			if (theView == nil)
				[self viewNextUnread:self];
			else
			{
				NSRect visibleRect = [theView visibleRect];
				if (flags & NSShiftKeyMask)
				{
					if (visibleRect.origin.y < 2)
						[self goBack:self];
					else
						[view scrollPageUp:self];
				}
				else
				{
					if (visibleRect.origin.y + visibleRect.size.height >= [theView frame].size.height - 2)
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

	if (!([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)) 
	{
		[item setButtonImage:@"subscribeButton"];
		[item setAction:@selector(newSubscription:)];
	}
	else
	{
		[item setButtonImage:@"smartFolderButton"];
		[item setAction:@selector(newSmartFolder:)];
	}
}

/* toolbarItemWithIdentifier
 * Returns the toolbar button that corresponds to the specified identifier.
 */
-(ToolbarItem *)toolbarItemWithIdentifier:(NSString *)theIdentifier
{
	NSArray * toolbarButtons = [[mainWindow toolbar] visibleItems];
	NSEnumerator * theEnumerator = [toolbarButtons objectEnumerator];
	ToolbarItem * theItem;
	
	while ((theItem = [theEnumerator nextObject]) != nil)
	{
		if ([[theItem itemIdentifier] isEqualToString:theIdentifier])
			return theItem;
	}
	return nil;
}

/* isConnecting
 * Returns whether or not 
 */
-(BOOL)isConnecting
{
	return [[RefreshManager sharedManager] totalConnections] > 0;
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
	if (![db readOnly])
		[articleController markAllReadByArray:arrayOfFolders withUndo:YES withRefresh:YES];
}

/* createNewSubscription
 * Create a new subscription for the specified URL under the given parent folder.
 */
-(void)createNewSubscription:(NSString *)urlString underFolder:(int)parentId afterChild:(int)predecessorId
{
	// Replace feed:// with http:// if necessary
	if ([urlString hasPrefix:@"feed://"])
		urlString = [NSString stringWithFormat:@"http://%@", [urlString substringFromIndex:7]];
	
	// If the folder already exists, just select it.
	Folder * folder = [db folderFromFeedURL:urlString];
	if (folder != nil)
	{
		[browserView setActiveTabToPrimaryTab];
		[foldersTree selectFolder:[folder itemId]];
		return;
	}
	
	// Create then select the new folder.
	[db beginTransaction];
	int folderId = [db addRSSFolder:[Database untitledFeedFolderName] underParent:parentId afterChild:predecessorId subscriptionURL:urlString];
	[db commitTransaction];
	
	if (folderId != -1)
	{
		[foldersTree selectFolder:folderId];
		if (isAccessible(urlString))
		{
			Folder * folder = [db folderFromID:folderId];
			[[RefreshManager sharedManager] refreshSubscriptions:[NSArray arrayWithObject:folder] ignoringSubscriptionStatus:NO];
		}
	}
}

/* newSubscription
 * Display the pane for a new RSS subscription.
 */
-(IBAction)newSubscription:(id)sender
{
	if (!rssFeed)
		rssFeed = [[NewSubscription alloc] initWithDatabase:db];
	[rssFeed newSubscription:mainWindow underParent:[foldersTree groupParentSelection] initialURL:nil];
}

/* newSmartFolder
 * Create a new smart folder.
 */
-(IBAction)newSmartFolder:(id)sender
{
	if (!smartFolder)
		smartFolder = [[SmartFolder alloc] initWithDatabase:db];
	[smartFolder newCriteria:mainWindow underParent:[foldersTree groupParentSelection]];
}

/* newGroupFolder
 * Display the pane for a new group folder.
 */
-(IBAction)newGroupFolder:(id)sender
{
	if (!groupFolder)
		groupFolder = [[NewGroupFolder alloc] init];
	[groupFolder newGroupFolder:mainWindow underParent:[foldersTree groupParentSelection]];
}

/* restoreMessage
 * Restore a message in the Trash folder back to where it came from.
 */
-(IBAction)restoreMessage:(id)sender
{
	Folder * folder = [db folderFromID:[articleController currentFolderId]];
	if (IsTrashFolder(folder) && [self selectedArticle] != nil && ![db readOnly])
	{
		NSArray * articleArray = [mainArticleView markedArticleRange];
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
	if ([self selectedArticle] != nil && ![db readOnly])
	{
		Folder * folder = [db folderFromID:[articleController currentFolderId]];
		if (!IsTrashFolder(folder))
		{
			NSArray * articleArray = [mainArticleView markedArticleRange];
			[articleController markDeletedByArray:articleArray deleteFlag:YES];
		}
		else
		{
			NSBeginCriticalAlertSheet(NSLocalizedString(@"Delete selected message", nil),
									  NSLocalizedString(@"Delete", nil),
									  NSLocalizedString(@"Cancel", nil),
									  nil, [NSApp mainWindow], self,
									  @selector(doConfirmedDelete:returnCode:contextInfo:), nil, nil,
									  NSLocalizedString(@"Delete selected message text", nil));
		}
	}
}

/* doConfirmedDelete
 * This function is called after the user has dismissed
 * the confirmation sheet.
 */
-(void)doConfirmedDelete:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn)
	{
		NSArray * articleArray = [mainArticleView markedArticleRange];
		[articleController deleteArticlesByArray:articleArray];

		// Blow away the undo stack here since undo actions may refer to
		// articles that have been deleted. This is a bit of a cop-out but
		// it's the easiest approach for now.
		[self clearUndoStack];
	}
}

/* showDownloadsWindow
 * Show the Downloads window, bringing it to the front if necessary.
 */
-(IBAction)showDownloadsWindow:(id)sender
{
	if (downloadWindow == nil)
		downloadWindow = [[DownloadWindow alloc] init];
	[[downloadWindow window] makeKeyAndOrderFront:sender];
}

/* conditionalShowDownloadsWindow
 * Make the Downloads window visible only if it hasn't been shown.
 */
-(IBAction)conditionalShowDownloadsWindow:(id)sender
{
	if (downloadWindow == nil)
		downloadWindow = [[DownloadWindow alloc] init];
	if (![[downloadWindow window] isVisible])
		[[downloadWindow window] makeKeyAndOrderFront:sender];
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
		NSWindow * activityWindow = [activityViewer window];
		if (![activityWindow isVisible])
			[activityViewer showWindow:self];
		else
			[activityWindow performClose:self];
	}
}

/* viewNextUnread
 * Moves the selection to the next unread article.
 */
-(IBAction)viewNextUnread:(id)sender
{
	[browserView setActiveTabToPrimaryTab];
	if ([db countOfUnread] > 0)
		[articleController displayNextUnread];
	[mainWindow makeFirstResponder:([self selectedArticle] != nil) ? [[browserView primaryTabItemView] mainView] : [foldersTree mainView]];
}

/* clearUndoStack
 * Clear the undo stack for instances when the last action invalidates
 * all previous undoable actions.
 */
-(void)clearUndoStack
{
	[[mainWindow undoManager] removeAllActions];
}

/* skipFolder
 * Mark all articles in the current folder read then skip to the next folder with
 * unread articles.
 */
-(IBAction)skipFolder:(id)sender
{
	if (![db readOnly])
	{
		[articleController markAllReadByArray:[foldersTree selectedFolders] withUndo:YES withRefresh:YES];
		[self viewNextUnread:self];
	}
}

#pragma mark Marking Articles 

/* markAllRead
 * Mark all articles read in the selected folders.
 */
-(IBAction)markAllRead:(id)sender
{
	if (![db readOnly])
		[articleController markAllReadByArray:[foldersTree selectedFolders] withUndo:YES withRefresh:YES];
}

/* markAllSubscriptionsRead
 * Mark all subscriptions as read
 */
-(IBAction)markAllSubscriptionsRead:(id)sender
{
	if (![db readOnly])
	{
		[articleController markAllReadByArray:[foldersTree folders:0] withUndo:NO withRefresh:YES];
		[self clearUndoStack];
	}
}

/* markRead
 * Toggle the read/unread state of the selected articles
 */
-(IBAction)markRead:(id)sender
{
	Article * theArticle = [self selectedArticle];
	if (theArticle != nil && ![db readOnly])
	{
		NSArray * articleArray = [mainArticleView markedArticleRange];
		[articleController markReadByArray:articleArray readFlag:![theArticle isRead]];
	}
}

/* markFlagged
 * Toggle the flagged/unflagged state of the selected article
 */
-(IBAction)markFlagged:(id)sender
{
	Article * theArticle = [self selectedArticle];
	if (theArticle != nil && ![db readOnly])
	{
		NSArray * articleArray = [mainArticleView markedArticleRange];
		[articleController markFlaggedByArray:articleArray flagged:![theArticle isFlagged]];
	}
}

/* unsubscribeFeed
 * Subscribe or re-subscribe to a feed.
 */
-(IBAction)unsubscribeFeed:(id)sender
{
	NSMutableArray * selectedFolders = [NSMutableArray arrayWithArray:[foldersTree selectedFolders]];
	int count = [selectedFolders count];
	BOOL doSubscribe = NO;
	int index;

	if (count > 0)
		doSubscribe = IsUnsubscribed([selectedFolders objectAtIndex:0]);
	for (index = 0; index < count; ++index)
	{
		Folder * folder = [selectedFolders objectAtIndex:index];
		int infoFolderId = [folder itemId];

		if (doSubscribe)
			[[Database sharedDatabase] clearFolderFlag:infoFolderId flagToClear:MA_FFlag_Unsubscribed];
		else
			[[Database sharedDatabase] setFolderFlag:infoFolderId flagToSet:MA_FFlag_Unsubscribed];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:infoFolderId]];
	}
}

/* renameFolder
 * Renames the current folder
 */
-(IBAction)renameFolder:(id)sender
{
	[foldersTree renameFolder:[foldersTree actualSelection]];
}

/* deleteFolder
 * Delete the current folder.
 */
-(IBAction)deleteFolder:(id)sender
{
	NSMutableArray * selectedFolders = [NSMutableArray arrayWithArray:[foldersTree selectedFolders]];
	int count = [selectedFolders count];
	int index;
	
	// Show a different prompt depending on whether we're deleting one folder or a
	// collection of them.
	NSString * alertBody = nil;
	NSString * alertTitle = nil;
	BOOL needPrompt = YES;
	
	if (count == 1)
	{
		Folder * folder = [selectedFolders objectAtIndex:0];
		if (IsSmartFolder(folder))
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete smart folder text", nil), [folder name]];
			alertTitle = NSLocalizedString(@"Delete smart folder", nil);
		}
		else if (IsSearchFolder(folder))
			needPrompt = NO;
		else if (IsRSSFolder(folder))
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete RSS feed text", nil), [folder name]];
			alertTitle = NSLocalizedString(@"Delete RSS feed", nil);
		}
		else if (IsGroupFolder(folder))
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete group folder text", nil), [folder name]];
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
		int returnCode;
		returnCode = NSRunAlertPanel(alertTitle, alertBody, NSLocalizedString(@"Delete", nil), NSLocalizedString(@"Cancel", nil), nil);
		if (returnCode == NSAlertAlternateReturn)
			return;
	}
	
	// End any editing
	if (rssFeed != nil)
		[rssFeed doEditCancel:nil];
	if (smartFolder != nil)
		[smartFolder doCancel:nil];
	if ([(NSControl *)[foldersTree mainView] abortEditing])
		[mainWindow makeFirstResponder:[foldersTree mainView]];
	

	// Clear undo stack for this action
	[self clearUndoStack];
	
	// Prompt for each folder for now
	for (index = 0; index < count; ++index)
	{
		Folder * folder = [selectedFolders objectAtIndex:index];
		
		// This little hack is so if we're deleting the folder currently being displayed
		// and there's more than one folder being deleted, we delete the folder currently
		// being displayed last so that the MA_Notify_FolderDeleted handlers that only
		// refresh the display if the current folder is being deleted only trips once.
		if ([folder itemId] == [articleController currentFolderId] && index < count - 1)
		{
			[selectedFolders insertObject:folder atIndex:count];
			++count;
			continue;
		}
		if (!IsTrashFolder(folder))
		{
			// Create a status string
			NSString * deleteStatusMsg = [NSString stringWithFormat:NSLocalizedString(@"Delete folder status", nil), [folder name]];
			[self setStatusMessage:deleteStatusMsg persist:NO];
			
			// Now call the database to delete the folder.
			[db deleteFolder:[folder itemId]];
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
	int folderId = [foldersTree actualSelection];
	if (folderId > 0)
		[[InfoWindowManager infoWindowManager] showInfoWindowForFolder:folderId];
}

/* viewSourceHomePage
 * Display the web site associated with this feed, if there is one.
 */
-(IBAction)viewSourceHomePage:(id)sender
{
	Article * thisArticle = [self selectedArticle];
	Folder * folder = (thisArticle) ? [db folderFromID:[thisArticle folderId]] : [db folderFromID:[foldersTree actualSelection]];
	if (thisArticle || IsRSSFolder(folder))
		[self openURLFromString:[folder homePage] inPreferredBrowser:YES];
}

/* viewSourceHomePageInAlternateBrowser
 * Display the web site associated with this feed, if there is one, in non-preferred browser.
 */
-(IBAction)viewSourceHomePageInAlternateBrowser:(id)sender
{
	Article * thisArticle = [self selectedArticle];
	Folder * folder = (thisArticle) ? [db folderFromID:[thisArticle folderId]] : [db folderFromID:[foldersTree actualSelection]];
	if (thisArticle || IsRSSFolder(folder))
		[self openURLFromString:[folder homePage] inPreferredBrowser:NO];
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
		[self createNewTab:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@", pathToAckFile]] inBackground:NO];
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
	[browserView closeTabItemView:[browserView activeTabItemView]];
}

/* reloadPage
 * Reload the web page.
 */
-(IBAction)reloadPage:(id)sender
{
	NSView<BaseView> * theView = [browserView activeTabItemView];
	if ([theView isKindOfClass:[BrowserPane class]])
		[theView performSelector:@selector(handleReload:)];
}

/* stopReloadingPage
 * Cancel current reloading of a web page.
 */
-(IBAction)stopReloadingPage:(id)sender
{
	NSView<BaseView> * theView = [browserView activeTabItemView];
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
	if ([prefs openLinksInVienna])
	{
		alternateLocation = getDefaultBrowser();
		if (alternateLocation == nil)
			alternateLocation = NSLocalizedString(@"External Browser", nil);
	}
	else
		alternateLocation = [self appName];
	NSMenuItem * item = menuWithAction(@selector(viewSourceHomePageInAlternateBrowser:));
	if (item != nil)
	{
		[item setTitle:[NSString stringWithFormat:NSLocalizedString(@"Open Subscription Home Page in %@", nil), alternateLocation]];
	}
	item = menuWithAction(@selector(viewArticlePageInAlternateBrowser:));
	if (item != nil)
		[item setTitle:[NSString stringWithFormat:NSLocalizedString(@"Open Article Page in %@", nil), alternateLocation]];
}

/* updateSearchPlaceholder
 * Update the search placeholder string in the search field depending on the view in
 * the active tab.
 */
-(void)updateSearchPlaceholder
{
	if ([[Preferences standardPreferences] layout] == MA_Layout_Unified)
	{
		[[filterSearchField cell] setSendsWholeSearchString:YES];
		[[filterSearchField cell] setPlaceholderString:[articleController searchPlaceholderString]];
	}
	else
	{
		[[filterSearchField cell] setSendsWholeSearchString:NO];
		[[filterSearchField cell] setPlaceholderString:[articleController searchPlaceholderString]];
	}
}

#pragma mark Searching

/* setFocusToSearchField
 * Put the input focus on the search field.
 */
-(IBAction)setFocusToSearchField:(id)sender
{
	if ([[mainWindow toolbar] isVisible] && [self toolbarItemWithIdentifier:@"SearchItem"] && [[mainWindow toolbar] displayMode] != NSToolbarDisplayModeLabelOnly)
		[mainWindow makeFirstResponder:searchField];
	else
	{
		if (!searchPanel)
			searchPanel = [[SearchPanel alloc] init];
		[searchPanel runSearchPanel:mainWindow];
	}
}

/* setSearchString
 * Sets the filter bar's search string.
 */
-(void)setSearchString:(NSString *)newSearchString
{
	[filterSearchField setStringValue:newSearchString];
}

/* searchString
 * Return the contents of the search field.
 */
-(NSString *)searchString
{
	return [filterSearchField stringValue];
}

/* searchUsingFilterField
 * Executes a search using the filter control.
 */
-(IBAction)searchUsingFilterField:(id)sender
{
	[[browserView activeTabItemView] performFindPanelAction:NSFindPanelActionNext];
}

/* searchUsingToolbarTextField
 * Executes a search using the search field on the toolbar.
 */
-(IBAction)searchUsingToolbarTextField:(id)sender
{
	[self searchArticlesWithString:[searchField stringValue]];
}

/* searchArticlesWithString
 * Do the actual article search. The database is called to set the search string
 * and then we make sure the search folder is selected so that the subsequent
 * reload will be scoped by the search string.
 */
-(void)searchArticlesWithString:(NSString *)searchString
{
	if (![searchString isBlank])
	{
		[db setSearchString:searchString];
		if ([foldersTree actualSelection] != [db searchFolderId])
			[foldersTree selectFolder:[db searchFolderId]];
		else
			[mainArticleView refreshFolder:MA_Refresh_ReloadFromDatabase];
	}
}

#pragma mark Refresh Subscriptions

/* refreshAllFolderIcons
 * Get new favicons from all subscriptions.
 */
-(IBAction)refreshAllFolderIcons:(id)sender
{
	if (![self isConnecting])
		[[RefreshManager sharedManager] refreshFolderIconCacheForSubscriptions:[foldersTree folders:0]];
}

/* refreshAllSubscriptions
 * Get new articles from all subscriptions.
 */
-(IBAction)refreshAllSubscriptions:(id)sender
{
	// Reset the refresh timer
	[self handleCheckFrequencyChange:nil];

	if (![self isConnecting])
		[[RefreshManager sharedManager] refreshSubscriptions:[foldersTree folders:0] ignoringSubscriptionStatus:NO];		
}

/* refreshSelectedSubscriptions
 * Refresh one or more subscriptions selected from the folders list. The selection we obtain
 * may include non-RSS folders so these have to be trimmed out first.
 */
-(IBAction)refreshSelectedSubscriptions:(id)sender
{
	[[RefreshManager sharedManager] refreshSubscriptions:[foldersTree selectedFolders] ignoringSubscriptionStatus:YES];
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
	NSMutableString * mailtoLink = [NSMutableString stringWithFormat:@"mailto:?subject=&body="];
	NSString * mailtoLineBreak = @"%0D%0A"; // necessary linebreak characters according to RFC
	
	// If the active tab is a web view, mail the URL ...
	NSView<BaseView> * theView = [browserView activeTabItemView];
	if ([theView isKindOfClass:[BrowserPane class]])
	{
		NSString * viewLink = [theView viewLink];
		if (viewLink != nil)
		{
			[mailtoLink appendString:viewLink];
			[self openURLInDefaultBrowser:[NSURL URLWithString: mailtoLink]];
		}
	}
	else
	// ... otherwise, iterate over the currently selected articles.
	{
		NSArray * articleArray = [mainArticleView markedArticleRange];	
		if ([articleArray count] > 0) 
		{
			NSEnumerator *e = [articleArray objectEnumerator];
			id currentArticle;
			
			while ( (currentArticle = [e nextObject]) ) {
				[mailtoLink appendFormat: @"%@%@", [currentArticle link], mailtoLineBreak];
			}
			[self openURLInDefaultBrowser:[NSURL URLWithString: mailtoLink]];
		}
	}
}

/* makeTextSmaller
 * Make text size smaller in the article pane.
 * In the future, we may want this to make text size smaller in the article list instead.
 */
-(IBAction)makeTextSmaller:(id)sender
{
	NSView<BaseView> * activeView = [browserView activeTabItemView];
	[[activeView webView] makeTextSmaller:sender];
}

/* makeTextLarger
 * Make text size larger in the article pane.
 * In the future, we may want this to make text size larger in the article list instead.
 */
-(IBAction)makeTextLarger:(id)sender
{
	NSView<BaseView> * activeView = [browserView activeTabItemView];
	[[activeView webView] makeTextLarger:sender];
}

/* changeFiltering
 * Refresh the filtering of articles.
 */
-(IBAction)changeFiltering:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	[[Preferences standardPreferences] setFilterMode:[menuItem tag]];
}

#pragma mark Blogging

/* blogWith
 * Calls the function which creates an Apple Event for external editor integration.
 */
-(IBAction)blogWith:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]])
	{
		NSDictionary * supportedEditors = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SupportedEditorsBundleIdentifiers"];
		[self blogWithExternalEditor:[supportedEditors objectForKey:[sender representedObject]]];
	}
}

/* blogWithExternalEditor
 * Builds and sends an Apple Event with info from the currently selected articles to the application specified by the bundle identifier that is passed.
 * Iterates over all currently selected articles and consecutively sends Apple Events to the specified app.
 */
-(void)blogWithExternalEditor:(NSString *)externalEditorBundleIdentifier;
{
	// Is our target application running? If not, we'll launch it.
	if (![[[[NSWorkspace sharedWorkspace] launchedApplications] valueForKey:@"NSApplicationBundleIdentifier"] containsObject:externalEditorBundleIdentifier])
	{
		[[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:externalEditorBundleIdentifier
															 options:NSWorkspaceLaunchWithoutActivation
									  additionalEventParamDescriptor:NULL
													launchIdentifier:nil];
	}
	
	// If the active tab is a web view, blog the URL
	NSView<BaseView> * theView = [browserView activeTabItemView];
	if ([theView isKindOfClass:[BrowserPane class]])
		[self sendBlogEvent:externalEditorBundleIdentifier title:[browserView tabItemViewTitle:[browserView activeTabItemView]] url:[theView viewLink] body:[NSApp currentSelection] author:@"" guid:@""];
	else
	{
		// Get the currently selected articles from the ArticleView ...
		NSArray * articleArray = [mainArticleView markedArticleRange];
		NSEnumerator * e = [articleArray objectEnumerator];
		id currentArticle;
		
		// ... and iterate over them.
		while ((currentArticle = [e nextObject]) != nil) 
			[self sendBlogEvent:externalEditorBundleIdentifier title:[currentArticle title] url:[currentArticle link] body:[NSApp currentSelection] author:[currentArticle author] guid:[currentArticle guid]];
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
	OSStatus err = AESendMessage([event aeDesc], NULL, kAENoReply | kAEDontReconnect | kAENeverInteract | kAEDontRecord, kAEDefaultTimeout);
	if (err != noErr) 
		NSLog(@"Error sending Apple Event: %d", err);
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
	return [prefs showStatusBar];
}

/* handleShowStatusBar
 * Respond to the status bar state being changed programmatically.
 */
-(void)handleShowStatusBar:(NSNotification *)nc
{
	[self setStatusBarState:[[Preferences standardPreferences] showStatusBar] withAnimation:YES];
}

/* showHideStatusBar
 * Toggle the status bar on/off. When off, expand the article area to fill the space.
 */
-(IBAction)showHideStatusBar:(id)sender
{
	BOOL newState = ![self isStatusBarVisible];

	[self setStatusBarState:newState withAnimation:YES];
	[[Preferences standardPreferences] setShowStatusBar:newState];
}

/* setStatusBarState
 * Show or hide the status bar state. Does not persist the state - use showHideStatusBar for this.
 */
-(void)setStatusBarState:(BOOL)isVisible withAnimation:(BOOL)doAnimate
{
	NSRect viewSize = [splitView1 frame];
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
			[statusText setHidden:!isVisible];
			[splitView1 setFrame:viewSize];
		}
		else
		{
			if (!isVisible)
			{
				// When hiding the status bar, hide these controls BEFORE
				// we start hiding the view. Looks cleaner.
				[statusText setHidden:YES];
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
	if (persistenceFlag)
	{
		[newStatusText retain];
		[persistedStatusText release];
		persistedStatusText = newStatusText;
	}
	if (newStatusText == nil || [newStatusText isBlank])
		newStatusText = persistedStatusText;
	[statusText setStringValue:(newStatusText ? newStatusText : @"")];
}

/* viewAnimationCompleted
 * Called when animation of the specified view completes.
 */
-(void)viewAnimationCompleted:(NSView *)theView withTag:(int)viewTag
{
	if (viewTag == MA_ViewTag_Statusbar && [self isStatusBarVisible])
	{
		// When showing the status bar, show these controls AFTER
		// we have made the view visible. Again, looks cleaner.
		[statusText setHidden:NO];
		return;
	}
	if (viewTag == MA_ViewTag_Filterbar && [self isFilterBarVisible])
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
	BOOL isMainWindowVisible = [mainWindow isVisible];
	BOOL isAnyArticleView = [browserView activeTabItemView] == [browserView primaryTabItemView];

	if (theAction == @selector(refreshAllSubscriptions:) || theAction == @selector(cancelAllRefreshes:))
	{
		*validateFlag = ![db readOnly];
		return YES;
	}
	if (theAction == @selector(newSubscription:))
	{
		*validateFlag = ![db readOnly] && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(newSmartFolder:))
	{
		*validateFlag = ![db readOnly] && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(skipFolder:))
	{
		*validateFlag = ![db readOnly] && isAnyArticleView && isMainWindowVisible && [db countOfUnread] > 0;
		return YES;
	}
	if (theAction == @selector(getInfo:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		*validateFlag = IsRSSFolder(folder) && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(viewNextUnread:))
	{
		*validateFlag = [db countOfUnread] > 0;
		return YES;
	}
	if (theAction == @selector(goBack:))
	{
		*validateFlag = [[browserView activeTabItemView] canGoBack] && isMainWindowVisible;
		return YES;
	}
	if (theAction == @selector(mailLinkToArticlePage:))
	{
		NSView<BaseView> * theView = [browserView activeTabItemView];
		BOOL isArticleView = [browserView activeTabItemView] == mainArticleView;
		Article * thisArticle = [self selectedArticle];

		if ([theView isKindOfClass:[BrowserPane class]])
			*validateFlag = ([theView viewLink] != nil);
		else
			*validateFlag = (thisArticle != nil && isMainWindowVisible && isArticleView);
		return NO; // Give the menu handler a chance too.
	}
	if (theAction == @selector(emptyTrash:))
	{
		*validateFlag = ![db readOnly];
		return YES;
	}
	if (theAction == @selector(setLayoutFromToolbar:))
	{
		*validateFlag = isMainWindowVisible;
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
	[self validateCommonToolbarAndMenuItems:[toolbarItem action] validateFlag:&flag];
	return flag;
}

/* validateMenuItem
 * This is our override where we handle item validation for the
 * commands that we own.
 */
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL	theAction = [menuItem action];
	BOOL isMainWindowVisible = [mainWindow isVisible];
	BOOL isAnyArticleView = [browserView activeTabItemView] == [browserView primaryTabItemView];
	BOOL isArticleView = [browserView activeTabItemView] == mainArticleView;
	BOOL flag;
	
	if ([self validateCommonToolbarAndMenuItems:theAction validateFlag:&flag])
	{
		return flag;
	}
	if (theAction == @selector(printDocument:))
	{
		return ([self selectedArticle] != nil && isMainWindowVisible);
	}
	else if (theAction == @selector(goForward:))
	{
		return [[browserView activeTabItemView] canGoForward] && isMainWindowVisible;
	}
	else if (theAction == @selector(newGroupFolder:))
	{
		return ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(showHideStatusBar:))
	{
		if ([self isStatusBarVisible])
			[menuItem setTitle:NSLocalizedString(@"Hide Status Bar", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Show Status Bar", nil)];
		return isMainWindowVisible;
	}
	else if (theAction == @selector(showHideFilterBar:))
	{
		if ([self isFilterBarVisible])
			[menuItem setTitle:NSLocalizedString(@"Hide Filter Bar", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Show Filter Bar", nil)];
		return isMainWindowVisible && isAnyArticleView;
	}
	else if (theAction == @selector(makeTextLarger:))
	{
		return [[[browserView activeTabItemView] webView] canMakeTextLarger] && isMainWindowVisible;
	}
	else if (theAction == @selector(makeTextSmaller:))
	{
		return [[[browserView activeTabItemView] webView] canMakeTextSmaller] && isMainWindowVisible;
	}
	else if (theAction == @selector(doViewColumn:))
	{
		Field * field = [menuItem representedObject];
		[menuItem setState:[field visible] ? NSOnState : NSOffState];
		return isMainWindowVisible && isArticleView;
	}
	else if (theAction == @selector(doSelectStyle:))
	{
		NSString * styleName = [menuItem title];
		[menuItem setState:[styleName isEqualToString:[[Preferences standardPreferences] displayStyle]] ? NSOnState : NSOffState];
		return isMainWindowVisible && isAnyArticleView;
	}
	else if (theAction == @selector(doSortColumn:))
	{
		Field * field = [menuItem representedObject];
		if ([[field name] isEqualToString:[articleController sortColumnIdentifier]])
			[menuItem setState:NSOnState];
		else
			[menuItem setState:NSOffState];
		return isMainWindowVisible && isAnyArticleView;
	}
	else if (theAction == @selector(unsubscribeFeed:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		if (folder)
		{
			if (IsUnsubscribed(folder))
				[menuItem setTitle:NSLocalizedString(@"Resubscribe", nil)];
			else
				[menuItem setTitle:NSLocalizedString(@"Unsubscribe", nil)];
		}
		return folder && IsRSSFolder(folder) && ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(deleteFolder:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		if (IsSearchFolder(folder))
			[menuItem setTitle:NSLocalizedString(@"Delete", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Delete...", nil)];
		return folder && !IsTrashFolder(folder) && ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(refreshSelectedSubscriptions:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return folder && (IsRSSFolder(folder) || IsGroupFolder(folder)) && ![db readOnly];
	}
	else if (theAction == @selector(refreshAllFolderIcons:))
	{
		return ![self isConnecting] && ![db readOnly];
	}
	else if (theAction == @selector(renameFolder:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return folder && ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(markAllRead:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return folder && !IsTrashFolder(folder) && ![db readOnly] && isArticleView && isMainWindowVisible && [db countOfUnread] > 0;
	}
	else if (theAction == @selector(markAllSubscriptionsRead:))
	{
		return ![db readOnly] && isMainWindowVisible && [db countOfUnread] > 0;
	}
	else if (theAction == @selector(importSubscriptions:))
	{
		return ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(cancelAllRefreshes:))
	{
		return [self isConnecting];
	}
	else if ((theAction == @selector(viewSourceHomePage:)) || (theAction == @selector(viewSourceHomePageInAlternateBrowser:)))
	{
		Article * thisArticle = [self selectedArticle];
		Folder * folder = (thisArticle) ? [db folderFromID:[thisArticle folderId]] : [db folderFromID:[foldersTree actualSelection]];
		return folder && (thisArticle || IsRSSFolder(folder)) && ([folder homePage] && ![[folder homePage] isBlank] && isMainWindowVisible && isArticleView);
	}
	else if ((theAction == @selector(viewArticlePage:)) || (theAction == @selector(viewArticlePageInAlternateBrowser:)))
	{
		Article * thisArticle = [self selectedArticle];
		if (thisArticle != nil)
			return ([thisArticle link] && ![[thisArticle link] isBlank] && isMainWindowVisible && isArticleView);
		return NO;
	}
	else if (theAction == @selector(exportSubscriptions:))
	{
		return isMainWindowVisible;
	}
	else if (theAction == @selector(compactDatabase:))
	{
		return ![self isConnecting] && ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(editFolder:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return folder && (IsSmartFolder(folder) || IsRSSFolder(folder)) && ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(restoreMessage:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return IsTrashFolder(folder) && [self selectedArticle] != nil && ![db readOnly] && isMainWindowVisible && isArticleView;
	}
	else if (theAction == @selector(deleteMessage:))
	{
		return [self selectedArticle] != nil && ![db readOnly] && isMainWindowVisible && isArticleView;
	}
	else if (theAction == @selector(previousTab:))
	{
		return isMainWindowVisible && [browserView countOfTabs] > 1;
	}
	else if (theAction == @selector(nextTab:))
	{
		return isMainWindowVisible && [browserView countOfTabs] > 1;
	}
	else if (theAction == @selector(closeTab:))
	{
		return isMainWindowVisible && !isArticleView;
	}
	else if (theAction == @selector(closeAllTabs:))
	{
		return isMainWindowVisible && [browserView countOfTabs] > 1;
	}
	else if (theAction == @selector(reloadPage:))
	{
		NSView<BaseView> * theView = [browserView activeTabItemView];
		return ([theView isKindOfClass:[BrowserPane class]]) && ![(BrowserPane *)theView isLoading];
	}
	else if (theAction == @selector(stopReloadingPage:))
	{
		NSView<BaseView> * theView = [browserView activeTabItemView];
		return ([theView isKindOfClass:[BrowserPane class]]) && [(BrowserPane *)theView isLoading];
	}
	else if (theAction == @selector(changeFiltering:))
	{
		[menuItem setState:([menuItem tag] == [[Preferences standardPreferences] filterMode]) ? NSOnState : NSOffState];
		return isMainWindowVisible;
	}
	else if (theAction == @selector(keepFoldersArranged:))
	{
		Preferences * prefs = [Preferences standardPreferences];
		[menuItem setState:([prefs foldersTreeSortMethod] == [menuItem tag]) ? NSOnState : NSOffState];
		return isMainWindowVisible;
	}
	else if (theAction == @selector(setFocusToSearchField:))
	{
		return isMainWindowVisible;
	}
	else if (theAction == @selector(reportLayout:))
	{
		Preferences * prefs = [Preferences standardPreferences];
		[menuItem setState:([prefs layout] == MA_Layout_Report) ? NSOnState : NSOffState];
		return isMainWindowVisible;
	}
	else if (theAction == @selector(condensedLayout:))
	{
		Preferences * prefs = [Preferences standardPreferences];
		[menuItem setState:([prefs layout] == MA_Layout_Condensed) ? NSOnState : NSOffState];
		return isMainWindowVisible;
	}
	else if (theAction == @selector(unifiedLayout:))
	{
		Preferences * prefs = [Preferences standardPreferences];
		[menuItem setState:([prefs layout] == MA_Layout_Unified) ? NSOnState : NSOffState];
		return isMainWindowVisible;
	}
	else if (theAction == @selector(markFlagged:))
	{
		Article * thisArticle = [self selectedArticle];
		if (thisArticle != nil)
		{
			if ([thisArticle isFlagged])
				[menuItem setTitle:NSLocalizedString(@"Mark Unflagged", nil)];
			else
				[menuItem setTitle:NSLocalizedString(@"Mark Flagged", nil)];
		}
		return (thisArticle != nil && ![db readOnly] && isMainWindowVisible && isArticleView);
	}
	else if (theAction == @selector(markRead:))
	{
		Article * thisArticle = [self selectedArticle];
		if (thisArticle != nil)
		{
			if ([thisArticle isRead])
				[menuItem setTitle:NSLocalizedString(@"Mark Unread", nil)];
			else
				[menuItem setTitle:NSLocalizedString(@"Mark Read", nil)];
		}
		return (thisArticle != nil && ![db readOnly] && isMainWindowVisible && isArticleView);
	}
	else if (theAction == @selector(mailLinkToArticlePage:))
	{
		if ([[mainArticleView markedArticleRange] count] > 1)
			[menuItem setTitle:NSLocalizedString(@"Send Links", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Send Link", nil)];
		return flag;
	}
	else if (theAction == @selector(downloadEnclosure:))
	{
		if ([[mainArticleView markedArticleRange] count] > 1)
			[menuItem setTitle:NSLocalizedString(@"Download Enclosures", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Download Enclosure", nil)];
		return ([[self selectedArticle] hasEnclosure] && isMainWindowVisible);
	}
	else if (theAction == @selector(newTab:))
	{
		return isMainWindowVisible;
	}	
	return YES;
}

/* itemForItemIdentifier
 * This method is required of NSToolbar delegates.  It takes an identifier, and returns the matching ToolbarItem.
 * It also takes a parameter telling whether this toolbar item is going into an actual toolbar, or whether it's
 * going to be displayed in a customization palette.
 */
-(ToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)willBeInserted
{
	ToolbarItem *item = [[ToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	if ([itemIdentifier isEqualToString:@"SearchItem"])
	{
		[item setView:searchField];
		[item setLabel:NSLocalizedString(@"Search Articles", nil)];
		[item setPaletteLabel:[item label]];
		[item setTarget:self];
		[item setAction:@selector(searchUsingToolbarTextField:)];
		[item setToolTip:NSLocalizedString(@"Search Articles", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"Subscribe"])
	{
		[item setLabel:NSLocalizedString(@"Subscribe", nil)];
		[item setPaletteLabel:[item label]];
		[item setButtonImage:@"subscribeButton"];
		[item setTarget:self];
		[item setAction:@selector(newSubscription:)];
		[item setToolTip:NSLocalizedString(@"Create a new subscription", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"PreviousButton"])
	{
		[item setLabel:NSLocalizedString(@"Back", nil)];
		[item setPaletteLabel:[item label]];
		[item setButtonImage:@"previousButton"];
		[item setTarget:self];
		[item setAction:@selector(goBack:)];
		[item setToolTip:NSLocalizedString(@"Back", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"NextButton"])
	{
		[item setLabel:NSLocalizedString(@"Next Unread", nil)];
		[item setPaletteLabel:[item label]];
		[item setButtonImage:@"nextButton"];
		[item setTarget:self];
		[item setAction:@selector(viewNextUnread:)];
		[item setToolTip:NSLocalizedString(@"Next Unread", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"SkipFolder"])
	{
		[item setLabel:NSLocalizedString(@"Skip Folder", nil)];
		[item setPaletteLabel:[item label]];
		[item setButtonImage:@"skipFolderButton"];
		[item setTarget:self];
		[item setAction:@selector(skipFolder:)];
		[item setToolTip:NSLocalizedString(@"Skip Folder", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"Refresh"])
	{
		[item setLabel:NSLocalizedString(@"Refresh", nil)];
		[item setPaletteLabel:[item label]];
		[item setButtonImage:@"refreshButton"];
		[item setTarget:self];
		[item setAction:@selector(refreshAllSubscriptions:)];
		[item setToolTip:NSLocalizedString(@"Refresh all your subscriptions", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"MailLink"])
	{
		[item setLabel:NSLocalizedString(@"Send Link", nil)];
		[item setPaletteLabel:[item label]];
		[item setButtonImage:@"mailLinkButton"];
		[item setTarget:self];
		[item setAction:@selector(mailLinkToArticlePage:)];
		[item setToolTip:NSLocalizedString(@"Email a link to the current article or website", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"EmptyTrash"])
	{
		[item setLabel:NSLocalizedString(@"Empty Trash", nil)];
		[item setPaletteLabel:[item label]];
		[item setButtonImage:@"emptyTrashButton"];
		[item setTarget:self];
		[item setAction:@selector(emptyTrash:)];
		[item setToolTip:NSLocalizedString(@"Delete all articles in the trash", nil)];
	}
	else if ([itemIdentifier isEqualToString:@"GetInfo"])
	{
		[item setLabel:NSLocalizedString(@"Get Info", nil)];
		[item setPaletteLabel:[item label]];
		[item setButtonImage:@"getInfoButton"];
		[item setTarget:self];
		[item setAction:@selector(getInfo:)];
		[item setToolTip:NSLocalizedString(@"See information about the selected subscription", nil)];
	}
	else if ([itemIdentifier isEqualToString: @"Spinner"])
	{
		[item setLabel:nil];
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
			if ([NSApp isRefreshing])
				[spinner startAnimation:self];
		}
		else
		{
			NSProgressIndicator *customizationPaletteSpinner = [[NSProgressIndicator alloc] initWithFrame:[spinner frame]];
			[customizationPaletteSpinner setControlSize:[spinner controlSize]];
			[customizationPaletteSpinner setControlTint:[spinner controlTint]];
			[customizationPaletteSpinner setIndeterminate:[spinner isIndeterminate]];
			[customizationPaletteSpinner setStyle:[spinner style]];

			[item setView:customizationPaletteSpinner];
			[customizationPaletteSpinner release];
		}

		[item setMinSize:NSMakeSize(NSWidth([spinner frame]), NSHeight([spinner frame]))];
		[item setMaxSize:NSMakeSize(NSWidth([spinner frame]), NSHeight([spinner frame]))];
	}
	else if ([itemIdentifier isEqualToString: @"Styles"])
	{
		[item setPopup:@"stylesMenuButton" withMenu:[self getStylesMenu]];
		[item setLabel:NSLocalizedString(@"Style", nil)];
		[item setPaletteLabel:[item label]];
		[item setToolTip:NSLocalizedString(@"Display the list of available styles", nil)];
	}
	else if ([itemIdentifier isEqualToString: @"Action"])
	{
		[item setPopup:@"popupMenuButton" withMenu:[self folderMenu]];
		[item setLabel:NSLocalizedString(@"Actions", nil)];
		[item setPaletteLabel:[item label]];
		[item setToolTip:NSLocalizedString(@"Additional actions for the selected folder", nil)];
	}
	return [item autorelease];
}

/* toolbarDefaultItemIdentifiers
 * This method is required of NSToolbar delegates.  It returns an array holding identifiers for the default
 * set of toolbar items.  It can also be called by the customization palette to display the default toolbar.
 */
-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:
		@"Subscribe",
		@"SkipFolder",
		@"Action",
		@"Refresh",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"SearchItem",
		NSToolbarFlexibleSpaceItemIdentifier,
		nil];
}

/* toolbarAllowedItemIdentifiers
 * This method is required of NSToolbar delegates.  It returns an array holding identifiers for all allowed
 * toolbar items in this toolbar.  Any not listed here will not be available in the customization palette.
 */
-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:
		NSToolbarSeparatorItemIdentifier,
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
		@"NextButton",
		nil];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[scriptsMenuItem release];
	[standardURLs release];
	[downloadWindow release];
	[persistedStatusText release];
	[scriptPathMappings release];
	[originalIcon release];
	[smartFolder release];
	[rssFeed release];
	[groupFolder release];
	[preferenceController release];
	[activityViewer release];
	[checkTimer release];
	[appDockMenu release];
	[appStatusItem release];
	[backgroundColor release];
	[db release];
	[spinner release];
	[searchField release];
	[super dealloc];
}
@end
