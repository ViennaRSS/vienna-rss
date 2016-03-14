//
//  InfoWindow.m
//  Vienna
//
//  Created by Steve on 4/21/06.
//  Copyright (c) 2004-2006 Steve Palmer. All rights reserved.
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

#import "InfoWindow.h"
#import "Database.h"
#import "CalendarExtensions.h"
#import "StringExtensions.h"
#import "AppController.h"
#import "Folder.h"

@interface InfoWindow (private)
	-(instancetype)initWithFolder:(NSInteger)folderId;
	-(void)enableValidateButton;
	-(void)updateFolder;
@end

@implementation InfoWindowManager

/* infoWindowManager
 * Returns the shared instance of the InfoWindowManager
 */
+(InfoWindowManager *)infoWindowManager
{
	// Singleton controller for all info windows
	static InfoWindowManager * _infoWindowManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
			_infoWindowManager = [[InfoWindowManager alloc] init];
	});
	return _infoWindowManager;
}

/* copyWithZone
 * Override to return ourself.
 */
-(id)copyWithZone:(NSZone *)zone
{
    return self;
}


/* init
 * Inits the single instance of the info window manager.
 */
-(instancetype)init
{
	if ((self = [super init]) != nil)
	{
		controllerList = [[NSMutableDictionary alloc] initWithCapacity:10];
		
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleFolderDeleted:) name:@"MA_Notify_FolderDeleted" object:nil];
		[nc addObserver:self selector:@selector(handleFolderChange:) name:@"MA_Notify_FolderNameChanged" object:nil];
		[nc addObserver:self selector:@selector(handleFolderChange:) name:@"MA_Notify_FoldersUpdated" object:nil];
		[nc addObserver:self selector:@selector(handleFolderChange:) name:@"MA_Notify_LoadFullHTMLChange" object:nil];
	}
	return self;
}

/* dealloc
*/
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/* handleFolderDeleted
 * Deals with the case where a folder is deleted while its Info window is
 * open. We close the info window and remove it from the list.
 */
-(void)handleFolderDeleted:(NSNotification *)nc
{
	NSInteger folderId = ((NSNumber *)nc.object).integerValue;
	NSNumber * folderNumber = @(folderId);
	InfoWindow * infoWindow;
	
	infoWindow = controllerList[folderNumber];
	if (infoWindow != nil)
	{
		[infoWindow close];
		[controllerList removeObjectForKey:folderNumber];
	}
}

/* handleFolderChange
 * Deals with the case where a folder's information is changed while its Info
 * window is open. We send the window update folder message.
 */
-(void)handleFolderChange:(NSNotification *)nc
{
	NSInteger folderId = ((NSNumber *)nc.object).integerValue;
	NSNumber * folderNumber = @(folderId);
	InfoWindow * infoWindow;
	
	infoWindow = controllerList[folderNumber];
	if (infoWindow != nil)
		[infoWindow updateFolder];
}

/* showInfoWindowForFolder
 * If there's an active info window for the specified folder then it is activated
 * and brought to the front. Otherwise a new window is created for the folder.
 */
-(void)showInfoWindowForFolder:(NSInteger)folderId
{
	NSNumber * folderNumber = @(folderId);
	InfoWindow * infoWindow;

	infoWindow = controllerList[folderNumber];
	if (infoWindow == nil)
	{
		infoWindow = [[InfoWindow alloc] initWithFolder:folderId];
		controllerList[folderNumber] = infoWindow;
	}
	[infoWindow showWindow:NSApp.mainWindow];

}
@end

@implementation InfoWindow

/* init
 * Just init the Info window.
 */
-(instancetype)initWithFolder:(NSInteger)folderId
{
	if ((self = [super initWithWindowNibName:@"InfoWindow"]) != nil)
		infoFolderId = folderId;

	return self;
}

/* dealloc
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/* awakeFromNib
 * Called after the NIB is loaded.
 */
-(void)awakeFromNib
{
	[self updateFolder];
	[self enableValidateButton];
	self.window.initialFirstResponder = urlField;
	self.window.delegate = self;

	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleUrlTextDidChange:) name:NSControlTextDidChangeNotification object:urlField];
	[nc addObserver:self selector:@selector(handleFolderNameTextDidChange:) name:NSControlTextDidChangeNotification object:folderName];
	[folderName setEditable:YES];
}

/* updateFolder
 * Update the folder info in response to changes on the folder itself.
 */
-(void)updateFolder
{
	Folder * folder = [[Database sharedManager] folderFromID:infoFolderId];
	
	// Set the window caption
	NSString * caption = [NSString stringWithFormat:NSLocalizedString(@"%@ Info", nil), folder.name];
	self.window.title = caption;

	// Set the header details
	folderName.stringValue = folder.name;
	folderImage.image = folder.image; 
	if ([folder.lastUpdate isEqualToDate:[NSDate distantPast]])
		[lastRefreshDate setStringValue:NSLocalizedString(@"Never", nil)];
	else
		lastRefreshDate.stringValue = [folder.lastUpdate dateWithCalendarFormat:nil timeZone:nil].friendlyDescription;
	
	// Fill out the panels
	urlField.stringValue = folder.feedURL;
	username.stringValue = folder.username;
	password.stringValue = folder.password;
	// for Google feeds, URL may not be changed and no authentication is supported
	if (IsGoogleReaderFolder(folder)) {
		//[urlField setSelectable:NO];
		[urlField setEditable:NO];
		urlField.textColor = [NSColor disabledControlTextColor];
		[username setEditable:NO];
		username.textColor = [NSColor disabledControlTextColor];
		[password setEditable:NO];
		password.textColor = [NSColor disabledControlTextColor];
	}
	folderDescription.stringValue = folder.feedDescription;
	folderSize.stringValue = [NSString stringWithFormat:NSLocalizedString(@"%u articles", nil), MAX(0, [folder countOfCachedArticles])];
	folderUnread.stringValue = [NSString stringWithFormat:NSLocalizedString(@"%u unread", nil), folder.unreadCount];
	isSubscribed.state = (folder.flags & MA_FFlag_Unsubscribed) ? NSOffState : NSOnState;
	loadFullHTML.state = (folder.flags & MA_FFlag_LoadFullHTML) ? NSOnState : NSOffState;
}

/* urlFieldChanged
 * Called when the URL field is changed.
 */
-(IBAction)urlFieldChanged:(id)sender
{
	NSString * newUrl = (urlField.stringValue).trim;
    [[Database sharedManager] setFeedURL:newUrl forFolder:infoFolderId];
}

/* subscribedChanged
 * Called when the subscribe button is changed.
 */
-(IBAction)subscribedChanged:(id)sender
{
    if (isSubscribed.state == NSOnState) {
        [[Database sharedManager] clearFlag:MA_FFlag_Unsubscribed forFolder:infoFolderId];
    }
    else {
		[[Database sharedManager] setFlag:MA_FFlag_Unsubscribed forFolder:infoFolderId];
    }
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated"
                                                        object:@(infoFolderId)];
}

/* loadFullHTMLChanged
 * Called when the loadFullHTML button is changed.
 */
-(IBAction)loadFullHTMLChanged:(id)sender
{
    if (loadFullHTML.state == NSOnState) {
        [[Database sharedManager] setFlag:MA_FFlag_LoadFullHTML forFolder:infoFolderId];
    }
    else {
		[[Database sharedManager] clearFlag:MA_FFlag_LoadFullHTML forFolder:infoFolderId];
    }
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_LoadFullHTMLChange"
                                                        object:@(infoFolderId)];
}

/* handleUrlTextDidChange [delegate]
 * This function is called when the contents of the url field is changed.
 * We disable the Subscribe button if the input fields are empty or enable it otherwise.
 */
-(void)handleUrlTextDidChange:(NSNotification *)aNotification
{
	[self enableValidateButton];
}

/* handleFolderNameTextDidChange [delegate]
 * This function is called when the contents of the folder name field is changed.
 * We update the folder's name.
 */
-(void)handleFolderNameTextDidChange:(NSNotification *)aNotification
{
    [[Database sharedManager] setName:folderName.stringValue forFolder:infoFolderId];
}

/* enableValidateButton
 * Disable the Validate button if the URL field is empty.
 */
-(void)enableValidateButton
{
	validateButton.enabled = !(urlField.stringValue).blank;
}

/* validateURL
 * Validate the URL in the text field.
 */
-(IBAction)validateURL:(id)sender
{
	NSString * validatorPage = [[APPCONTROLLER standardURLs] valueForKey:@"FeedValidatorTemplate"];
	if (validatorPage != nil)
	{
		NSString * url = (urlField.stringValue).trim;
		
		// Escape any special query characters in the URL, because the URL itself will be in a query.
		NSString * query = [NSURL URLWithString:url].query;
		if (query != nil)
		{
			NSMutableString * escapedQuery = [NSMutableString stringWithString:query];
			[escapedQuery replaceOccurrencesOfString:@"&" withString:@"%26" options:0u range:NSMakeRange(0u, escapedQuery.length)];
			[escapedQuery replaceOccurrencesOfString:@"=" withString:@"%3D" options:0u range:NSMakeRange(0u, escapedQuery.length)];
			if (![query isEqualToString:escapedQuery])
			{
				url = [[url substringToIndex:[url rangeOfString:query].location] stringByAppendingString:escapedQuery];
			}
		}
		
		NSString * validatorURL = [NSString stringWithFormat:validatorPage, url];
		[APPCONTROLLER openURLFromString:validatorURL inPreferredBrowser:YES];
	}
}

/* authenticationChanged
 * Update the authentication information for this feed when the Update button is
 * clicked.
 */
-(IBAction)authenticationChanged:(id)sender
{
	NSString * usernameString = (username.stringValue).trim;
	NSString * passwordString = password.stringValue;
	
	Database * db = [Database sharedManager];
	Folder * folder = [db folderFromID:infoFolderId];
	[db setFolderUsername:folder.itemId newUsername:usernameString];
	folder.password = passwordString;
}

/* windowShouldClose
 * Commit the window's current first responder before closing.
 */
- (BOOL)windowShouldClose:(id)sender
{
	// Set the first responder so any open edit fields get committed.
	[self.window makeFirstResponder:self.window];

	// Go ahead and close the window.
	return YES;
}


@end
