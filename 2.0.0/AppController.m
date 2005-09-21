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
#import "PreferenceController.h"
#import "AboutController.h"
#import "FoldersTree.h"
#import "ArticleListView.h"
#import "Import.h"
#import "Export.h"
#import "RefreshManager.h"
#import "StringExtensions.h"
#import "SplitViewExtensions.h"
#import "BrowserView.h"
#import "CheckForUpdates.h"
#import "SearchFolder.h"
#import "NewSubscription.h"
#import "NewGroupFolder.h"
#import "ViennaApp.h"
#import "ActivityLog.h"
#import "Constants.h"
#import "ArticleView.h"
#import "BrowserPane.h"
#import "Preferences.h"
#import "HelperFunctions.h"
#import "WebKit/WebFrame.h"
#import "WebKit/WebUIDelegate.h"
#import "Growl/GrowlApplicationBridge.h"
#import "Growl/GrowlDefines.h"

@interface AppController (Private)
	-(void)handleTabChange:(NSNotification *)nc;
	-(void)handleFolderSelection:(NSNotification *)note;
	-(void)handleCheckFrequencyChange:(NSNotification *)note;
	-(void)handleFolderUpdate:(NSNotification *)nc;
	-(void)initSortMenu;
	-(void)initColumnsMenu;
	-(void)initStylesMenu;
	-(void)initScriptsMenu;
	-(void)startProgressIndicator;
	-(void)stopProgressIndicator;
	-(void)doEditFolder:(Folder *)folder;
	-(void)refreshOnTimer:(NSTimer *)aTimer;
	-(void)doConfirmedDelete:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
	-(void)runAppleScript:(NSString *)scriptName;
	-(void)setImageForMenuCommand:(NSImage *)image forAction:(SEL)sel;
	-(NSString *)appName;
	-(void)updateSearchPlaceholder;
	-(FoldersTree *)foldersTree;
	-(IBAction)endRenameFolder:(id)sender;
	-(IBAction)cancelRenameFolder:(id)sender;
	-(void)updateCloseCommands;
@end

// Static constant strings that are typically never tweaked
static NSString * GROWL_NOTIFICATION_DEFAULT = @"NotificationDefault";

static const int MA_Minimum_Folder_Pane_Width = 80;
static const int MA_Minimum_BrowserView_Pane_Width = 200;

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
		checkTimer = nil;
	}
	return self;
}

/* awakeFromNib
 * Do all the stuff that only makes sense after our NIB has been loaded and connected.
 */
-(void)awakeFromNib
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	[Preferences standardPreferences];

	// Find out who we are. The localised info in InfoStrings.plist allow
	// changing the app name if so desired.
	NSBundle * appBundle = [NSBundle mainBundle];
	appName = nil;
	if (appBundle != nil)
	{
		NSDictionary * fileAttributes = [appBundle localizedInfoDictionary];
		appName = [fileAttributes objectForKey:@"CFBundleName"];
	}
	if (appName == nil)
		appName = @"Vienna";

	// Set the primary view of the browser view
	BrowserTab * primaryTab = [browserView setPrimaryTabView:mainArticleView];
	[browserView setTabTitle:primaryTab title:NSLocalizedString(@"Articles", nil)];

	// Set the delegates and title
	[mainWindow setDelegate:self];
	[mainWindow setTitle:appName];
	[NSApp setDelegate:self];

	// Register a bunch of notifications
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleFolderSelection:) name:@"MA_Notify_FolderSelectionChange" object:nil];
	[nc addObserver:self selector:@selector(handleCheckFrequencyChange:) name:@"MA_Notify_CheckFrequencyChange" object:nil];
	[nc addObserver:self selector:@selector(handleFolderUpdate:) name:@"MA_Notify_FoldersUpdated" object:nil];
	[nc addObserver:self selector:@selector(checkForUpdatesComplete:) name:@"MA_Notify_UpdateCheckCompleted" object:nil];
	[nc addObserver:self selector:@selector(handleEditFolder:) name:@"MA_Notify_EditFolder" object:nil];
	[nc addObserver:self selector:@selector(handleRefreshStatusChange:) name:@"MA_Notify_RefreshStatus" object:nil];
	[nc addObserver:self selector:@selector(handleTabChange:) name:@"MA_Notify_TabChanged" object:nil];

	// Init the progress counter and status bar.
	[self setStatusMessage:nil persist:NO];

	// Initialize the database
	if ((db = [Database sharedDatabase]) == nil)
	{
		[NSApp terminate:nil];
		return;
	}

	// Preload dictionary of standard URLs
	NSString * pathToPList = [[NSBundle mainBundle] pathForResource:@"StandardURLs.plist" ofType:@""];
	if (pathToPList != nil)
		standardURLs = [[NSDictionary dictionaryWithContentsOfFile:pathToPList] retain];

	// Initialize the Styles, Sort By and Columns menu
	[self initSortMenu];
	[self initColumnsMenu];
	[self initStylesMenu];

	// Restore the splitview layout
	[splitView1 loadLayoutWithName:@"SplitView1Positions"];
	[splitView1 setDelegate:self];

	// Show the current unread count on the app icon
	originalIcon = [[NSApp applicationIconImage] copy];
	[self showUnreadCountOnApplicationIcon];

	// Create a menu for the search field
	// The menu title doesn't appear anywhere so we don't localise it. The titles of each
	// item is localised though.
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

    [[searchField cell] setSearchMenuTemplate:cellMenu];
	[cellMenu release];

	// Add Scripts menu if we have any scripts
	if ([defaults boolForKey:MAPref_ShowScriptsMenu] || !hasOSScriptsMenu())
		[self initScriptsMenu];

	// Use Growl if it is installed
	[GrowlApplicationBridge setGrowlDelegate:self];

	// Start the check timer
	[self handleCheckFrequencyChange:nil];

	// Assign the controller for the child views
	[foldersTree setController:self];
	[mainArticleView setController:self];

	// Fix up the Close commands
	[self updateCloseCommands];

	// Do safe initialisation.
	[self doSafeInitialisation];
}

/* doSafeInitialisation
 * Do the stuff that requires that all NIBs are awoken. I can't find a notification
 * from Cocoa for this so we hack it.
 */
-(void)doSafeInitialisation
{
	[foldersTree initialiseFoldersTree];
	[mainArticleView initialiseArticleView];
}

/* applicationDidFinishLaunching
 * Handle post-load activities.
 */
-(void)applicationDidFinishLaunching:(NSNotification *)aNot
{
	Preferences * prefs = [Preferences standardPreferences];
	
	// Check for application updates silently
	if ([prefs checkForNewOnStartup])
	{
		if (!checkUpdates)
			checkUpdates = [[CheckForUpdates alloc] init];
		[checkUpdates checkForUpdate:mainWindow showUI:NO];
	}
	
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
	return YES;
}

/* applicationShouldTerminate
 * This function is called when the user wants to close Vienna. First we check to see
 * if a connection or import is running and that all articles are saved.
 */
-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if ([self isConnecting])
	{
		int returnCode;
		
		returnCode = NSRunAlertPanel(NSLocalizedString(@"Connect Running", nil),
									 NSLocalizedString(@"Connect Running text", nil),
									 NSLocalizedString(@"Quit", nil),
									 NSLocalizedString(@"Cancel", nil),
									 nil);
		if (returnCode == NSAlertAlternateReturn)
			return NSTerminateCancel;
	}
	return NSTerminateNow;
}

/* applicationWillTerminate
 * This is where we put the clean-up code.
 */
-(void)applicationWillTerminate:(NSNotification *)aNotification
{
	// Save the splitview layout
	[splitView1 storeLayoutWithName:@"SplitView1Positions"];
	
	// Close the activity window explicitly to force it to
	// save its split bar position to the preferences.
	NSWindow * activityWindow = [activityViewer window];
	[activityWindow performClose:self];
	
	// Put back the original app icon
	[NSApp setApplicationIconImage:originalIcon];
	
	// Remember the article list column position, sizes, etc.
	[mainArticleView saveTableSettings];
	[foldersTree saveFolderSettings];
	
	if ([mainArticleView currentFolderId] != -1)
		[db flushFolder:[mainArticleView currentFolderId]];
	[db close];
}

/* openFile [delegate]
 * Called when the user opens a data file associated with Vienna.
 */
-(BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	if ([[filename pathExtension] isEqualToString:@"viennastyle"])
	{
		NSString * path = [[[NSUserDefaults standardUserDefaults] objectForKey:MAPref_StylesFolder] stringByExpandingTildeInPath];
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
		if (![fileManager copyPath:filename toPath:fullPath handler:nil])
			[[Preferences standardPreferences] setDisplayStyle:styleName];
		else
		{
			[self initStylesMenu];
			[[Preferences standardPreferences] setDisplayStyle:styleName];
			runOKAlertPanel(@"New style title", @"New style body", styleName);
		}
		return YES;
	}
	return NO;
}

/* database
 */
-(Database *)database
{
	return db;
}

/* browserView
 */
-(BrowserView *)browserView
{
	return browserView;
}

/* foldersTree
 */
-(FoldersTree *)foldersTree
{
	return foldersTree;
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

/* readingPaneOnRight
 * Move the reading pane to the right of the article list.
 */
-(IBAction)readingPaneOnRight:(id)sender
{
	[[Preferences standardPreferences] setReadingPaneOnRight:YES];
}

/* readingPaneOnBottom
 * Move the reading pane to the bottom of the article list.
 */
-(IBAction)readingPaneOnBottom:(id)sender
{
	[[Preferences standardPreferences] setReadingPaneOnRight:NO];
}

/* applicationDockMenu
 * Return a menu with additional commands to be displayd on the application's
 * popup dock menu.
 */
-(NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	[appDockMenu release];
	appDockMenu = [[NSMenu alloc] initWithTitle:@"DockMenu"];
	
	// Refresh command
	NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Refresh All Subscriptions", nil)
													   action:@selector(refreshAllSubscriptions:)
												keyEquivalent:@""];
	[appDockMenu addItem:menuItem];
	[menuItem release];
	
	// Done
	return appDockMenu;
}

/* contextMenuItemsForElement
 * Creates a new context menu for our web pane.
 */
-(NSArray *)contextMenuItemsLink:(NSURL *)urlLink defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray * newDefaultMenu = [[NSMutableArray alloc] initWithArray:defaultMenuItems];
	int count = [newDefaultMenu count];
	int index;
	
	for (index = count - 1; index >= 0; --index)
	{
		NSMenuItem * menuItem = [newDefaultMenu objectAtIndex:index];
		switch ([menuItem tag])
		{
			case WebMenuItemTagOpenImageInNewWindow:
				[menuItem setTitle:NSLocalizedString(@"Open Image in New Tab", nil)];
				break;

			case WebMenuItemTagOpenFrameInNewWindow:
				[menuItem setTitle:NSLocalizedString(@"Open Frame in New Tab", nil)];
				break;

			case WebMenuItemTagOpenLinkInNewWindow: {
				[menuItem setTitle:NSLocalizedString(@"Open Link in New Tab", nil)];
				[menuItem setTarget:self];
				[menuItem setAction:@selector(openLinkInNewTab:)];
				[menuItem setRepresentedObject:urlLink];

				// Note: this is only safe to do if we're going from [count..0] when iterating
				// over newDefaultMenu. If we switch to the other direction, this will break.
				NSMenuItem * newMenuItem = [[NSMenuItem alloc] init];
				NSString * defaultBrowser = getDefaultBrowser();
				if (newMenuItem != nil && defaultBrowser != nil)
				{
					[newMenuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Open Link in %@", nil), defaultBrowser]];
					[newMenuItem setTarget:self];
					[newMenuItem setAction:@selector(openLinkInBrowser:)];
					[newMenuItem setRepresentedObject:urlLink];
					[newMenuItem setTag:WebMenuItemTagOther];
					[newDefaultMenu insertObject:newMenuItem atIndex:index + 1];
				}
				[newMenuItem release];
				break;
				}

			case WebMenuItemTagCopyLinkToClipboard:
				[menuItem setTitle:NSLocalizedString(@"Copy Link to Clipboard", nil)];
				break;
				
			case WebMenuItemTagDownloadLinkToDisk:
			case WebMenuItemTagDownloadImageToDisk:
				// We don't handle these yet. Eventually we will do but, for now, remove
				// these from the list.
				[newDefaultMenu removeObjectAtIndex:index];
				break;
		}
	}
	return [newDefaultMenu autorelease];
}

/* openPageInBrowser
 * Open the current web page in the browser.
 */
-(IBAction)openPageInBrowser:(id)sender
{
	NSView<BaseView> * theView = [browserView activeTabView];
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
	NSView<BaseView> * theView = [browserView activeTabView];
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

/* openLinkInBrowser
 * Open the specified link in an external browser.
 */
-(IBAction)openLinkInBrowser:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]])
	{
		NSMenuItem * item = (NSMenuItem *)sender;
		[self openURLInDefaultBrowser:[item representedObject]];
	}
}

/* openLinkInNewTab
 * Open the specified link in a new tab.
 */
-(IBAction)openLinkInNewTab:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]])
	{
		NSMenuItem * item = (NSMenuItem *)sender;
		Preferences * prefs = [Preferences standardPreferences];
		[self openURLInNewTab:[item representedObject] inBackground:[prefs openLinksInBackground]];
	}
}

/* openURLInBrowser
 * Open a URL in either the internal Vienna browser or an external browser depending on
 * whatever the user has opted for.
 */
-(void)openURLInBrowser:(NSString *)urlString
{
	[self openURLInBrowserWithURL:[NSURL URLWithString:urlString]];
}

/* openURLInBrowserWithURL
 * Open a URL in either the internal Vienna browser or an external browser depending on
 * whatever the user has opted for.
 */
-(void)openURLInBrowserWithURL:(NSURL *)url
{
	Preferences * prefs = [Preferences standardPreferences];
	if ([prefs openLinksInVienna])
		[self openURLInNewTab:url inBackground:[prefs openLinksInBackground]];
	else
		[self openURLInDefaultBrowser:url];
}

/* openURLInNewTab
 * Open the specified URL in a new tab.
 */
-(void)openURLInNewTab:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag
{
	BrowserPane * newBrowserPane = [[BrowserPane alloc] init];
	BrowserTab * tab = [browserView createNewTabWithView:newBrowserPane makeKey:!openInBackgroundFlag];
	[newBrowserPane setController:self];
	[newBrowserPane setTab:tab];
	[newBrowserPane loadURL:url];
	[newBrowserPane release];
}

/* openURLInDefaultBrowser
 * Open the specified URL in whatever the user has registered as their
 * default system browser.
 */
-(void)openURLInDefaultBrowser:(NSURL *)url
{
	// Launch in the foreground or background as needed
	Preferences * prefs = [Preferences standardPreferences];
	NSWorkspaceLaunchOptions lOptions = [prefs openLinksInBackground] ? NSWorkspaceLaunchWithoutActivation : NSWorkspaceLaunchDefault;

	[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url]
					withAppBundleIdentifier:NULL
									options:lOptions
			 additionalEventParamDescriptor:NULL
						  launchIdentifiers:NULL];
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

/* showMainWindow
 * Display the main window.
 */
-(IBAction)showMainWindow:(id)sender
{
	[mainWindow makeKeyAndOrderFront:self];
}

/* closeMainWindow
 * Hide the main window.
 */
-(IBAction)closeMainWindow:(id)sender
{
	[mainWindow orderOut:self];
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
	Folder * unreadArticles = [db folderFromName:NSLocalizedString(@"Unread Articles", nil)];
	if (unreadArticles != nil)
		[mainArticleView selectFolderAndArticle:[unreadArticles itemId] guid:nil];
}

/* registrationDictionaryForGrowl
 * Called by Growl to request the notification dictionary.
 */
-(NSDictionary *)registrationDictionaryForGrowl
{
	NSMutableArray *defNotesArray = [NSMutableArray array];
	NSMutableArray *allNotesArray = [NSMutableArray array];
	
	[allNotesArray addObject:@"New Articles"];
	[defNotesArray addObject:@"New Articles"];
	
	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
		appName, GROWL_APP_NAME, 
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
	NSMenu * viewMenu = [[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"View", nil)] submenu];
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
			[field tag] != MA_FieldID_Deleted &&
			[field tag] != MA_FieldID_Text)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[field displayName] action:@selector(doSortColumn:) keyEquivalent:@""];
			[menuItem setRepresentedObject:field];
			[sortMenu addItem:menuItem];
			[menuItem release];
		}
	}
	[[viewMenu itemWithTitle:NSLocalizedString(@"Sort By", nil)] setSubmenu:sortMenu];
}

/* initColumnsMenu
 * Create the columns popup menu.
 */
-(void)initColumnsMenu
{
	NSMenu * viewMenu = [[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"View", nil)] submenu];
	NSMenu * columnsMenu = [[[NSMenu alloc] initWithTitle:@"Columns"] autorelease];
	NSArray * fields = [db arrayOfFields];
	NSEnumerator * enumerator = [fields objectEnumerator];
	Field * field;
	
	while ((field = [enumerator nextObject]) != nil)
	{
		// Filter out columns we don't view in the article list. Later we should have an attribute in the
		// field object based on which columns are visible in the tableview.
		if ([field tag] != MA_FieldID_Text && 
			[field tag] != MA_FieldID_GUID &&
			[field tag] != MA_FieldID_Deleted &&
			[field tag] != MA_FieldID_Parent &&
			[field tag] != MA_FieldID_Headlines)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[field displayName] action:@selector(doViewColumn:) keyEquivalent:@""];
			[menuItem setRepresentedObject:field];
			[columnsMenu addItem:menuItem];
			[menuItem release];
		}
	}
	[[viewMenu itemWithTitle:NSLocalizedString(@"Columns", nil)] setSubmenu:columnsMenu];
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
	NSMenu * scriptsMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Scripts"];
    NSMenuItem * scriptsMenuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Scripts" action:NULL keyEquivalent:@""];

	// Set menu image
	[scriptsMenuItem setImage:[NSImage imageNamed:@"scriptMenu.tiff"]];

	// Valid script file extensions
	NSArray * exts = [NSArray arrayWithObjects:@"scpt", nil];

	// Add scripts within the app resource
	NSString * path = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"Scripts"];
	loadMapFromPath(path, scriptPathMappings, NO, exts);

	// Add scripts that the user created and stored in the scripts folder
	path = [[[NSUserDefaults standardUserDefaults] objectForKey:MAPref_ScriptsFolder] stringByExpandingTildeInPath];
	loadMapFromPath(path, scriptPathMappings, NO, exts);

	// Add the contents of the scriptsPathMappings dictionary keys to the menu sorted
	// by key name.
	NSArray * sortedMenuItems = [[scriptPathMappings allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	int count = [sortedMenuItems count];
	int index;

	for (index = 0; index < count; ++index)
	{
		NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[sortedMenuItems objectAtIndex:index]
														   action:@selector(doSelectScript:)
													keyEquivalent:@""];
		[scriptsMenu addItem:menuItem];
		[menuItem release];
	}

	// Insert the Scripts menu to the left of the Help menu only if
	// we actually have any scripts.
	if (count > 0)
	{
		[scriptsMenu addItem:[NSMenuItem separatorItem]];
		NSMenuItem * menuItem;
		
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Scripts Folder", nil) action:@selector(doOpenScriptsFolder:) keyEquivalent:@""];
		[scriptsMenu addItem:menuItem];
		[menuItem release];

		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"More Scripts...", nil) action:@selector(moreScripts:) keyEquivalent:@""];
		[scriptsMenu addItem:menuItem];
		[menuItem release];
		
		// The Help menu is always assumed to be the last menu in the list. This is probably
		// the easiest, localisable, way to look for it.
		int helpMenuIndex = [[NSApp mainMenu] numberOfItems] - 1;
		[scriptsMenuItem setSubmenu:scriptsMenu];
		[[NSApp mainMenu] insertItem:scriptsMenuItem atIndex:helpMenuIndex];
	}
	[scriptsMenu release];
	[scriptsMenuItem release];
}

/* initStylesMenu
 * Populate the Styles menu with a list of built-in and external styles. (Note that in the event of
 * duplicates the styles in the external Styles folder wins. This is intended to allow the user to
 * override the built-in styles if necessary).
 */
-(void)initStylesMenu
{
	NSMenu * stylesMenu = [[[NSMenu alloc] initWithTitle:@"Style"] autorelease];

	// Reinitialise the styles map
	NSDictionary * stylesMap = [mainArticleView initStylesMap];
	
	// Add the contents of the stylesPathMappings dictionary keys to the menu sorted
	// by key name.
	NSArray * sortedMenuItems = [[stylesMap allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	int count = [sortedMenuItems count];
	int index;
	
	for (index = 0; index < count; ++index)
	{
		NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[sortedMenuItems objectAtIndex:index] action:@selector(doSelectStyle:) keyEquivalent:@""];
		[stylesMenu addItem:menuItem];
		[menuItem release];
	}

	// Append a link to More Styles...
	[stylesMenu addItem:[NSMenuItem separatorItem]];
	NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"More Styles...", nil) action:@selector(moreStyles:) keyEquivalent:@""];
	[stylesMenu addItem:menuItem];
	[menuItem release];
	
	NSMenu * viewMenu = [[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"View", nil)] submenu];
	[[viewMenu itemWithTitle:NSLocalizedString(@"Style", nil)] setSubmenu:stylesMenu];
}

/* showUnreadCountOnApplicationIcon
 * Update the Vienna application icon to show the number of unread articles.
 */
-(void)showUnreadCountOnApplicationIcon
{
	int currentCountOfUnread = [db countOfUnread];
	if (currentCountOfUnread != lastCountOfUnread)
	{
		if (currentCountOfUnread > 0)
		{
			NSString *countdown = [NSString stringWithFormat:@"%i", currentCountOfUnread];
			NSImage * iconImageBuffer = [originalIcon copy];
			NSSize iconSize = [originalIcon size];

			// Create attributes for drawing the count. In our case, we're drawing using in
			// 26pt Helvetica bold white.
			NSDictionary * attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica-Bold" size:26],
																					 NSFontAttributeName,
																					 [NSColor whiteColor],
																					 NSForegroundColorAttributeName,
																					 nil];
			NSSize numSize = [countdown sizeWithAttributes:attributes];

			// Create a red circle in the icon large enough to hold the count.
			[iconImageBuffer lockFocus];
			[originalIcon drawAtPoint:NSMakePoint(0, 0)
							 fromRect:NSMakeRect(0, 0, iconSize.width, iconSize.height) 
							operation:NSCompositeSourceOver 
							 fraction:1.0f];
			float max = (numSize.width > numSize.height) ? numSize.width : numSize.height;
			max += 16;
			NSRect circleRect = NSMakeRect(iconSize.width - max, 0, max, max);
			NSBezierPath * bp = [NSBezierPath bezierPathWithOvalInRect:circleRect];
			[[NSColor colorWithCalibratedRed:0.8f green:0.0f blue:0.0f alpha:1.0f] set];
			[bp fill];

			// Draw the count in the red circle
			NSPoint point = NSMakePoint(NSMidX(circleRect) - numSize.width / 2.0f,  NSMidY(circleRect) - numSize.height / 2.0f + 2.0f);
			[countdown drawAtPoint:point withAttributes:attributes];

			// Now set the new app icon and clean up.
			[iconImageBuffer unlockFocus];
			[NSApp setApplicationIconImage:iconImageBuffer];
			[iconImageBuffer release];
			[attributes release];
		}
		else
			[NSApp setApplicationIconImage:originalIcon];
		lastCountOfUnread = currentCountOfUnread;
	}
}

/* handleAbout
 * Display our About Vienna... window.
 */
-(IBAction)handleAbout:(id)sender
{
	if (!aboutController)
		aboutController = [[AboutController alloc] init];
	[aboutController showWindow:self];
}

/* emptyTrash
 * Delete all articles from the Trash folder.
 */
-(IBAction)emptyTrash:(id)sender
{
	[db purgeDeletedArticles];
}

/* showPreferencePanel
 * Display the Preference Panel.
 */
-(IBAction)showPreferencePanel:(id)sender
{
	if (!preferenceController)
		preferenceController = [[PreferenceController alloc] init];
	[preferenceController showWindow:self];
}

/* printDocument
 * Print the selected articles in the article window.
 */
-(IBAction)printDocument:(id)sender
{
	[[browserView activeTabView] printDocument:sender];
}

/* folders
 * Return the array of folders.
 */
-(NSArray *)folders
{
	return [foldersTree folders:MA_Root_Folder];
}

/* appName
 * Returns's the application friendly (localized) name.
 */
-(NSString *)appName
{
	return appName;
}

/* selectedArticle
 * Returns the current selected article in the article pane.
 */
-(Article *)selectedArticle
{
	return [mainArticleView selectedArticle];
}

/* currentFolderId
 * Return the ID of the currently selected folder whose articles are shown in
 * the article window.
 */
-(int)currentFolderId
{
	return [mainArticleView currentFolderId];
}

/* selectFolder
 * Select the specified folder.
 */
-(BOOL)selectFolder:(int)folderId
{
	return [mainArticleView selectFolderAndArticle:folderId guid:nil];
}

/* updateCloseCommands
 * Update the keystrokes assigned to the Close Tab and Close Window
 * commands depending on whether any tabs are opened.
 */
-(void)updateCloseCommands
{
	if ([browserView countOfTabs] < 2)
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

/* handleRSSLink
 * Handle feed://<rss> links. If we're already subscribed to the link then make the folder
 * active. Otherwise offer to subscribe to the link.
 */
-(void)handleRSSLink:(NSString *)linkPath
{
	Folder * folder = [db folderFromFeedURL:linkPath];
	if (folder != nil)
		[foldersTree selectFolder:[folder itemId]];
	else
		[self createNewSubscription:linkPath underFolder:MA_Root_Folder];
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
			smartFolder = [[SearchFolder alloc] initWithDatabase:db];
		[smartFolder loadCriteria:mainWindow folderId:[folder itemId]];
	}
}

/* handleFolderUpdate
 * Called if a folder content has changed.
 */
-(void)handleFolderUpdate:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	if (folderId == [mainArticleView currentFolderId])
	{
		[mainArticleView refreshFolder:YES];
		[self updateSearchPlaceholder];
	}
}

/* handleFolderSelection
 * Called when the selection changes in the folder pane.
 */
-(void)handleFolderSelection:(NSNotification *)note
{
	TreeNode * node = (TreeNode *)[note object];
	int newFolderId = [node nodeId];

	// We only care if the selection really changed
	if ([mainArticleView currentFolderId] != newFolderId && newFolderId != 0)
	{
		// Make sure article viewer is active
		[browserView setActiveTabToPrimaryTab];

		// Blank out the search field
		[searchField setStringValue:@""];
		[mainArticleView selectFolderWithFilter:newFolderId];
		[self updateSearchPlaceholder];
		[[NSUserDefaults standardUserDefaults] setInteger:[mainArticleView currentFolderId] forKey:MAPref_CachedFolderID];
	}
}

/* handleCheckFrequencyChange
 * Called when the refresh frequency is changed.
 */
-(void)handleCheckFrequencyChange:(NSNotification *)note
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
													  repeats:YES] retain];
	}
}

/* doViewColumn
 * Toggle whether or not a specified column is visible.
 */
-(IBAction)doViewColumn:(id)sender;
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	Field * field = [menuItem representedObject];

	[field setVisible:![field visible]];
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
	[mainArticleView sortByIdentifier:[field name]];
}

/* doOpenScriptsFolder
 * Open the standard Vienna scripts folder.
 */
-(IBAction)doOpenScriptsFolder:(id)sender
{
	NSString * path = [[[NSUserDefaults standardUserDefaults] objectForKey:MAPref_ScriptsFolder] stringByExpandingTildeInPath];
	[[NSWorkspace sharedWorkspace] openFile:path];
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
	if (newView == mainArticleView)
		[mainWindow makeFirstResponder:[mainArticleView mainView]];
	else
	{
		BrowserPane * webPane = (BrowserPane *)newView;
		[mainWindow makeFirstResponder:[webPane mainView]];
	}
	[self updateCloseCommands];
	[self updateSearchPlaceholder];
}

/* handleRefreshStatusChange
 * Handle a change of the refresh status.
 */
-(void)handleRefreshStatusChange:(NSNotification *)nc
{
	if ([NSApp isRefreshing])
	{
		[self startProgressIndicator];
		[self setStatusMessage:NSLocalizedString(@"Refreshing subscriptions...", nil) persist:YES];
	}
	else
	{
		[self setStatusMessage:NSLocalizedString(@"Refresh completed", nil) persist:YES];
		[self stopProgressIndicator];

		[self showUnreadCountOnApplicationIcon];

		int newUnread = [[RefreshManager sharedManager] countOfNewArticles];
		if (growlAvailable && newUnread > 0)
		{
			NSNumber * defaultValue = [NSNumber numberWithBool:YES];
			NSNumber * stickyValue = [NSNumber numberWithBool:NO];
			NSString * msgText = [NSString stringWithFormat:NSLocalizedString(@"Growl description", nil), newUnread];
			
			NSDictionary *aNuDict = [NSDictionary dictionaryWithObjectsAndKeys:
				NSLocalizedString(@"Growl notification name", nil), GROWL_NOTIFICATION_NAME,
				NSLocalizedString(@"Growl notification title", nil), GROWL_NOTIFICATION_TITLE,
				msgText, GROWL_NOTIFICATION_DESCRIPTION,
				appName, GROWL_APP_NAME,
				defaultValue, GROWL_NOTIFICATION_DEFAULT,
				stickyValue, GROWL_NOTIFICATION_STICKY,
				[NSNumber numberWithInt:newUnread], GROWL_NOTIFICATION_CLICK_CONTEXT,
				nil];
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION 
																		   object:nil 
																		 userInfo:aNuDict
															   deliverImmediately:YES];
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
	NSString * stylesPage = [standardURLs valueForKey:@"ViennaMoreScriptsPage"];
	if (stylesPage != nil)
		[self openURLInDefaultBrowser:[NSURL URLWithString:stylesPage]];
}

/* viewArticlePage
 * Display the article in the browser.
 */
-(IBAction)viewArticlePage:(id)sender
{
	Article * theArticle = [self selectedArticle];
	if (theArticle && ![[theArticle link] isBlank])
		[self openURLInBrowser:[theArticle link]];
}

/* goForward
 * In article view, forward track through the list of articles displayed. In 
 * web view, go to the next web page.
 */
-(IBAction)goForward:(id)sender
{
	[[browserView activeTabView] handleGoForward];
}

/* goBack
 * In article view, back track through the list of articles displayed. In 
 * web view, go to the previous web page.
 */
-(IBAction)goBack:(id)sender
{
	[[browserView activeTabView] handleGoBack];
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
	case NSFindPanelActionShowFindPanel:
		[mainWindow makeFirstResponder:searchField];
		break;
	}
}

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(unsigned int)flags
{
	switch (keyChar)
	{
		case NSLeftArrowFunctionKey:
			if (!(flags & NSCommandKeyMask))
				if ([mainWindow firstResponder] == [mainArticleView mainView])
				{
					[mainWindow makeFirstResponder:[foldersTree mainView]];
					return YES;
				}
			return NO;

		case NSRightArrowFunctionKey:
			if (!(flags & NSCommandKeyMask))
				if ([mainWindow firstResponder] == [foldersTree mainView])
				{
					[mainWindow makeFirstResponder:[mainArticleView mainView]];
					return YES;
				}
			return NO;
			
		case 'f':
		case 'F':
			[mainWindow makeFirstResponder:searchField];
			return YES;

		case '>':
			[self goForward:self];
			return YES;

		case '<':
			[self goBack:self];
			return YES;

		case 'm':
		case 'M':
			[self markFlagged:self];
			return YES;

		case 'r':
		case 'R':
			[self markRead:self];
			return YES;

		case '\r': //ENTER
			[self viewArticlePage:self];
			return YES;
	}
	return [[browserView activeTabView] handleKeyDown:keyChar withFlags:flags];
}

/* isConnecting
 * Returns whether or not 
 */
-(BOOL)isConnecting
{
	return [[RefreshManager sharedManager] totalConnections] > 0;
}

/* refreshOnTimer
 * Each time the check timer fires, we see if a connect is not
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
		[mainArticleView markAllReadByArray:arrayOfFolders];
}

/* createNewSubscription
 * Create a new subscription for the specified URL under the given parent folder.
 */
-(void)createNewSubscription:(NSString *)urlString underFolder:(int)parentId
{
	// Replace feed:// with http:// if necessary
	if ([urlString hasPrefix:@"feed://"])
		urlString = [NSString stringWithFormat:@"http://%@", [urlString substringFromIndex:7]];

	// Create then select the new folder.
	int folderId = [db addRSSFolder:[db untitledFeedFolderName] underParent:parentId subscriptionURL:urlString];
	[mainArticleView selectFolderAndArticle:folderId guid:nil];

	if (isAccessible(urlString))
	{
		Folder * folder = [db folderFromID:folderId];
		[[RefreshManager sharedManager] refreshSubscriptions:[NSArray arrayWithObject:folder]];
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
		smartFolder = [[SearchFolder alloc] initWithDatabase:db];
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
	Folder * folder = [db folderFromID:[mainArticleView currentFolderId]];
	if (IsTrashFolder(folder) && [self selectedArticle] != nil && ![db readOnly])
	{
		NSArray * articleArray = [mainArticleView markedArticleRange];
		[mainArticleView markDeletedByArray:articleArray deleteFlag:NO];
		[articleArray release];
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
		Folder * folder = [db folderFromID:[mainArticleView currentFolderId]];
		if (!IsTrashFolder(folder))
		{
			NSArray * articleArray = [mainArticleView markedArticleRange];
			[mainArticleView markDeletedByArray:articleArray deleteFlag:YES];
			[articleArray release];
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
		[mainArticleView deleteSelectedArticles];
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
	[mainArticleView displayNextUnread];
}

/* clearUndoStack
 * Clear the undo stack for instances when the last action invalidates
 * all previous undoable actions.
 */
-(void)clearUndoStack
{
	[[mainWindow undoManager] removeAllActions];
}

/* markAllRead
 * Mark all articles read in the selected folders.
 */
-(IBAction)markAllRead:(id)sender
{
	if (![db readOnly])
		[mainArticleView markAllReadByArray:[foldersTree selectedFolders]];
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
		[mainArticleView markReadByArray:articleArray readFlag:![theArticle isRead]];
		[articleArray release];
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
		[mainArticleView markFlaggedByArray:articleArray flagged:![theArticle isFlagged]];
		[articleArray release];
	}
}

/* renameFolder
 * Renames the current folder
 */
-(IBAction)renameFolder:(id)sender
{
	Folder * folder = [db folderFromID:[foldersTree actualSelection]];

	// Initialise field
	[renameField setStringValue:[folder name]];
	[renameWindow makeFirstResponder:renameField];

	[NSApp beginSheet:renameWindow
	   modalForWindow:mainWindow 
		modalDelegate:self 
	   didEndSelector:nil 
		  contextInfo:nil];
}

/* renameUndo
 * Undo a folder rename action. Also create a redo action to reapply the original
 * change back again.
 */
-(void)renameUndo:(id)anObject
{
	NSDictionary * undoAttributes = (NSDictionary *)anObject;
	Folder * folder = [undoAttributes objectForKey:@"Folder"];
	NSString * oldName = [undoAttributes objectForKey:@"Name"];

	NSMutableDictionary * redoAttributes = [NSMutableDictionary dictionary];

	[redoAttributes setValue:[folder name] forKey:@"Name"];
	[redoAttributes setValue:folder forKey:@"Folder"];

	NSUndoManager * undoManager = [mainWindow undoManager];
	[undoManager registerUndoWithTarget:self selector:@selector(renameUndo:) object:redoAttributes];
	[undoManager setActionName:NSLocalizedString(@"Rename", nil)];

	[db setFolderName:[folder itemId] newName:oldName];
}

/* endRenameFolder
 * Called when the user OK's the Rename Folder sheet
 */
-(IBAction)endRenameFolder:(id)sender
{
	NSString * newName = [[renameField stringValue] trim];
	if ([db folderFromName:newName] != nil)
		runOKAlertPanel(@"Cannot rename folder", @"A folder with that name already exists");
	else
	{
		[renameWindow orderOut:sender];
		[NSApp endSheet:renameWindow returnCode:1];
		
		Folder * folder = [db folderFromID:[mainArticleView currentFolderId]];
		NSMutableDictionary * renameAttributes = [NSMutableDictionary dictionary];
		
		[renameAttributes setValue:[folder name] forKey:@"Name"];
		[renameAttributes setValue:folder forKey:@"Folder"];
		
		NSUndoManager * undoManager = [mainWindow undoManager];
		[undoManager registerUndoWithTarget:self selector:@selector(renameUndo:) object:renameAttributes];
		[undoManager setActionName:NSLocalizedString(@"Rename", nil)];
		
		[db setFolderName:[mainArticleView currentFolderId] newName:newName];
	}
}

/* cancelRenameFolder
 * Called when the user cancels the Rename Folder sheet
 */
-(IBAction)cancelRenameFolder:(id)sender
{
	[renameWindow orderOut:sender];
	[NSApp endSheet:renameWindow returnCode:0];
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

	if (count == 1)
	{
		Folder * folder = [selectedFolders objectAtIndex:0];
		if (IsSmartFolder(folder))
		{
			alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete smart folder text", nil), [folder name]];
			alertTitle = NSLocalizedString(@"Delete smart folder", nil);
		}
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
		else
			NSAssert1(false, @"Unhandled folder type in deleteFolder: %@", [folder name]);
	}
	else
	{
		alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete multiple folders text", nil), count];
		alertTitle = NSLocalizedString(@"Delete multiple folders", nil);
	}

	// Get confirmation first
	int returnCode;
	returnCode = NSRunAlertPanel(alertTitle, alertBody, NSLocalizedString(@"Delete", nil), NSLocalizedString(@"Cancel", nil), nil);
	if (returnCode == NSAlertAlternateReturn)
		return;

	// Clear undo stack for this action
	[self clearUndoStack];

	// Prompt for each folder for now
	for (index = 0; index < count; ++index)
	{
		Folder * folder = [selectedFolders objectAtIndex:index];
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
	[self showUnreadCountOnApplicationIcon];
}

/* validateFeed
 * Call the feed validator on the selected subscription feed.
 */
-(IBAction)validateFeed:(id)sender
{
	int folderId = [foldersTree actualSelection];
	Folder * folder = [db folderFromID:folderId];

	if (IsRSSFolder(folder))
	{
		NSString * validatorPage = [standardURLs valueForKey:@"FeedValidatorTemplate"];
		if (validatorPage != nil)
		{
			NSString * validatorURL = [NSString stringWithFormat:validatorPage, [folder feedURL]];
			[self openURLInBrowser:validatorURL];
		}
	}
}

/* viewSourceHomePage
 * Display the web site associated with this feed, if there is one.
 */
-(IBAction)viewSourceHomePage:(id)sender
{
	Article * thisArticle = [self selectedArticle];
	if (thisArticle != nil)
	{
		Folder * folder = [db folderFromID:[thisArticle folderId]];
		[self openURLInBrowser:[folder homePage]];
	}
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
	NSString * pathToAckFile = [thisBundle pathForResource:@"Acknowledgements.rtf" ofType:@""];
	if (pathToAckFile != nil)
		[self openURLInNewTab:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@", pathToAckFile]] inBackground:NO];
}

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
	[browserView closeTab:[browserView activeTab]];
}

/* reloadPage
 * Reload the web page.
 */
-(IBAction)reloadPage:(id)sender
{
	NSView<BaseView> * theView = [browserView activeTabView];
	if ([theView isKindOfClass:[BrowserPane class]])
		[theView performSelector:@selector(handleReload:)];
}

/* stopReloadingPage
 * Cancel current reloading of a web page.
 */
-(IBAction)stopReloadingPage:(id)sender
{
	NSView<BaseView> * theView = [browserView activeTabView];
	if ([theView isKindOfClass:[BrowserPane class]])
		[theView performSelector:@selector(handleStopLoading:)];
}

/* updateSearchPlaceholder
 * Update the search placeholder string in the search field depending on the view in
 * the active tab.
 */
-(void)updateSearchPlaceholder
{
	[[searchField cell] setSendsWholeSearchString:[browserView activeTabView] != mainArticleView];
	[[searchField cell] setPlaceholderString:[[browserView activeTabView] searchPlaceholderString]];
}

/* searchString
 * Return the contents of the search field.
 */
-(NSString *)searchString
{
	return [searchField stringValue];
}

/* searchUsingToolbarTextField
 * Executes a search using the search field on the toolbar.
 */
-(IBAction)searchUsingToolbarTextField:(id)sender
{
	[[browserView activeTabView] search];
}

/* refreshAllSubscriptions
 * Get new articles from all subscriptions.
 */
-(IBAction)refreshAllSubscriptions:(id)sender
{
	if (![self isConnecting])
		[[RefreshManager sharedManager] refreshSubscriptions:[db arrayOfRSSFolders]];
}

/* refreshSelectedSubscriptions
 * Refresh one or more subscriptions selected from the folders list. The selection we obtain
 * may include non-RSS folders so these have to be trimmed out first.
 */
-(IBAction)refreshSelectedSubscriptions:(id)sender
{
	[[RefreshManager sharedManager] refreshSubscriptions:[foldersTree selectedFolders]];
}

/* cancelAllRefreshes
 * Used to kill all active refresh connections and empty the queue of folders due to
 * be refreshed.
 */
-(IBAction)cancelAllRefreshes:(id)sender
{
	[[RefreshManager sharedManager] cancelAll];
}

/* setStatusMessage
 * Sets a new status message for the info bar then updates the view. To remove
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

/* validateMenuItem
 * This is our override where we handle item validation for the
 * commands that we own.
 */
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL	theAction = [menuItem action];
	BOOL isMainWindowVisible = [mainWindow isVisible];
	BOOL isArticleView = [browserView activeTabView] == mainArticleView;

	if (theAction == @selector(printDocument:))
	{
		return ([self selectedArticle] != nil && isMainWindowVisible);
	}
	else if (theAction == @selector(goBack:))
	{
		return [[browserView activeTabView] canGoBack] && isMainWindowVisible;
	}
	else if (theAction == @selector(goForward:))
	{
		return [[browserView activeTabView] canGoForward] && isMainWindowVisible;
	}
	else if (theAction == @selector(newSubscription:))
	{
		return ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(newSmartFolder:))
	{
		return ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(newGroupFolder:))
	{
		return ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(viewNextUnread:))
	{
		return [db countOfUnread] > 0;
	}
	else if (theAction == @selector(refreshAllSubscriptions:))
	{
		return ![self isConnecting] && ![db readOnly];
	}
	else if (theAction == @selector(doViewColumn:))
	{
		Field * field = [menuItem representedObject];
		[menuItem setState:[field visible] ? NSOnState : NSOffState];
		return isMainWindowVisible && ([mainArticleView tableLayout] == MA_Table_Layout) && isArticleView;
	}
	else if (theAction == @selector(doSelectStyle:))
	{
		NSString * styleName = [menuItem title];
		[menuItem setState:[styleName isEqualToString:[[Preferences standardPreferences] displayStyle]] ? NSOnState : NSOffState];
		return isMainWindowVisible && isArticleView;
	}
	else if (theAction == @selector(doSortColumn:))
	{
		Field * field = [menuItem representedObject];
		if ([[field name] isEqualToString:[mainArticleView sortColumnIdentifier]])
			[menuItem setState:NSOnState];
		else
			[menuItem setState:NSOffState];
		return isMainWindowVisible && isArticleView;
	}
	else if (theAction == @selector(deleteFolder:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return folder && !IsTrashFolder(folder) && ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(refreshSelectedSubscriptions:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return folder && (IsRSSFolder(folder) || IsGroupFolder(folder)) && ![db readOnly];
	}
	else if (theAction == @selector(renameFolder:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return folder && ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(markAllRead:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return folder && !IsTrashFolder(folder) && ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(importSubscriptions:))
	{
		return ![db readOnly] && isMainWindowVisible;
	}
	else if (theAction == @selector(cancelAllRefreshes:))
	{
		return [self isConnecting];
	}
	else if (theAction == @selector(viewSourceHomePage:))
	{
		Article * thisArticle = [self selectedArticle];
		if (thisArticle != nil)
		{
			Folder * folder = [db folderFromID:[thisArticle folderId]];
			return folder && ([folder homePage] && ![[folder homePage] isBlank] && isMainWindowVisible);
		}
		return NO;
	}
	else if (theAction == @selector(viewArticlePage:))
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
	else if (theAction == @selector(validateFeed:))
	{
		int folderId = [foldersTree actualSelection];
		Folder * folder = [db folderFromID:folderId];
		return IsRSSFolder(folder) && isMainWindowVisible;
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
	else if (theAction == @selector(emptyTrash:))
	{
		return ![db readOnly];
	}
	else if (theAction == @selector(closeMainWindow:))
	{
		return isMainWindowVisible;
	}
	else if (theAction == @selector(readingPaneOnRight:))
	{
		[menuItem setState:([[Preferences standardPreferences] readingPaneOnRight] ? NSOnState : NSOffState)];
		return isMainWindowVisible && isArticleView;
	}
	else if (theAction == @selector(readingPaneOnBottom:))
	{
		[menuItem setState:([[Preferences standardPreferences] readingPaneOnRight] ? NSOffState : NSOnState)];
		return isMainWindowVisible && isArticleView;
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
		return isMainWindowVisible && [browserView activeTabView] != mainArticleView;
	}
	else if (theAction == @selector(closeAllTabs:))
	{
		return isMainWindowVisible && [browserView countOfTabs] > 1;
	}
	else if (theAction == @selector(reloadPage:))
	{
		NSView<BaseView> * theView = [browserView activeTabView];
		return ([theView isKindOfClass:[BrowserPane class]]) && ![(BrowserPane *)theView isLoading];
	}
	else if (theAction == @selector(stopReloadingPage:))
	{
		NSView<BaseView> * theView = [browserView activeTabView];
		return ([theView isKindOfClass:[BrowserPane class]]) && [(BrowserPane *)theView isLoading];
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
	return YES;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[standardURLs release];
	[persistedStatusText release];
	[scriptPathMappings release];
	[originalIcon release];
	[smartFolder release];
	[rssFeed release];
	[groupFolder release];
	[checkUpdates release];
	[preferenceController release];
	[activityViewer release];
	[checkTimer release];
	[appDockMenu release];
	[db release];
	[super dealloc];
}
@end
