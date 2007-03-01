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

// Singleton controller for all info windows
static InfoWindowManager * _infoWindowManager = nil;

@interface InfoWindow (private)
	-(id)initWithFolder:(int)folderId;
	-(void)enableValidateButton;
	-(void)updateFolder;
@end

@implementation InfoWindowManager

/* infoWindowManager
 * Returns the shared instance of the InfoWindowManager
 */
+(InfoWindowManager *)infoWindowManager
{
	@synchronized(self)
	{
		if (_infoWindowManager == nil)
			_infoWindowManager = [[InfoWindowManager alloc] init];
	}
	return _infoWindowManager;
}

/* allocWithZone
 * Override to ensure that only one instance can be initialised.
 */
+(id)allocWithZone:(NSZone *)zone
{
	@synchronized(self)
	{
        if (_infoWindowManager == nil)
            return [super allocWithZone:zone];
    }
    return _infoWindowManager;
}

/* copyWithZone
 * Override to return ourself.
 */
-(id)copyWithZone:(NSZone *)zone
{
    return self;
}

/* retain
 * Override to return ourself.
 */
-(id)retain
{
    return self;
}

/* retainCount
 * Return UINT_MAX to denote an object that cannot be released.
 */
-(unsigned)retainCount
{
    return UINT_MAX;
}

/* release
 * Override to do nothing.
 */
-(void)release
{
}

/* autorelease
 * Override to return ourself
 */
-(id)autorelease
{
    return self;
}

/* init
 * Inits the single instance of the info window manager.
 */
-(id)init
{
	NSAssert(_infoWindowManager == nil, @"");
	if ((self = [super init]) != nil)
	{
		controllerList = [[NSMutableDictionary alloc] initWithCapacity:10];
		
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleFolderDeleted:) name:@"MA_Notify_FolderDeleted" object:nil];
		[nc addObserver:self selector:@selector(handleFolderNameChange:) name:@"MA_Notify_FolderNameChanged" object:nil];
	}
	return self;
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

/* handleFolderDeleted
 * Deals with the case where a folder is deleted while its Info window is
 * open. We close the info window and remove it from the list.
 */
-(void)handleFolderDeleted:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	NSNumber * folderNumber = [NSNumber numberWithInt:folderId];
	InfoWindow * infoWindow;
	
	infoWindow = [controllerList objectForKey:folderNumber];
	if (infoWindow != nil)
	{
		[infoWindow close];
		[controllerList removeObjectForKey:folderNumber];
	}
}

/* handleFolderNameChange
 * Deals with the case where a folder's name is changed while its Info
 * window is open. We send the window a name change message.
 */
-(void)handleFolderNameChange:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	NSNumber * folderNumber = [NSNumber numberWithInt:folderId];
	InfoWindow * infoWindow;
	
	infoWindow = [controllerList objectForKey:folderNumber];
	if (infoWindow != nil)
		[infoWindow updateFolder];
}

/* showInfoWindowForFolder
 * If there's an active info window for the specified folder then it is activated
 * and brought to the front. Otherwise a new window is created for the folder.
 */
-(void)showInfoWindowForFolder:(int)folderId
{
	NSNumber * folderNumber = [NSNumber numberWithInt:folderId];
	InfoWindow * infoWindow;

	infoWindow = [controllerList objectForKey:folderNumber];
	if (infoWindow == nil)
	{
		infoWindow = [[InfoWindow alloc] initWithFolder:folderId];
		[controllerList setObject:infoWindow forKey:folderNumber];
	}
	[infoWindow showWindow:[NSApp mainWindow]];
}
@end

@implementation InfoWindow

/* init
 * Just init the Info window.
 */
-(id)initWithFolder:(int)folderId
{
	if ((self = [super initWithWindowNibName:@"InfoWindow"]) != nil)
		infoFolderId = folderId;

	return self;
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

/* awakeFromNib
 * Called after the NIB is loaded.
 */
-(void)awakeFromNib
{
	[self updateFolder];
	[self enableValidateButton];
	[[self window] setInitialFirstResponder:urlField];

	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:urlField];
}

/* updateFolderName
 * Update the folder info in response to changes on the folder itself.
 */
-(void)updateFolder
{
	Folder * folder = [[Database sharedDatabase] folderFromID:infoFolderId];
	
	// Set the window caption
	NSString * caption = [NSString stringWithFormat:NSLocalizedString(@"%@ Info", nil), [folder name]];
	[[self window] setTitle:caption];

	// Set the header details
	[folderName setStringValue:[folder name]];
	[folderImage setImage:[folder image]]; 
	if ([[folder lastUpdate] isEqualToDate:[NSDate distantPast]])
		[lastRefreshDate setStringValue:NSLocalizedString(@"Never", nil)];
	else
		[lastRefreshDate setStringValue:[[[folder lastUpdate] dateWithCalendarFormat:nil timeZone:nil] friendlyDescription]];
	
	// Fill out the panels
	[urlField setStringValue:[folder feedURL]];
	[username setStringValue:[folder username]];
	[password setStringValue:[folder password]];
	[folderDescription setStringValue:[folder feedDescription]];
	[folderSize setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%u articles", nil), MAX(0, [folder countOfCachedArticles])]];
	[folderUnread setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%u unread", nil), [folder unreadCount]]];
	[isSubscribed setState:([folder flags] & MA_FFlag_Unsubscribed) ? NSOffState : NSOnState];
}

/* urlFieldChanged
 * Called when the URL field is changed.
 */
-(IBAction)urlFieldChanged:(id)sender
{
	NSString * newUrl = [[urlField stringValue] trim];
	[[Database sharedDatabase] setFolderFeedURL:infoFolderId newFeedURL:newUrl];
}

/* subscribedChanged
 * Called when the subscribe button is changed.
 */
-(IBAction)subscribedChanged:(id)sender
{
	if ([isSubscribed state] == NSOnState)
		[[Database sharedDatabase] clearFolderFlag:infoFolderId flagToClear:MA_FFlag_Unsubscribed];
	else
		[[Database sharedDatabase] setFolderFlag:infoFolderId flagToSet:MA_FFlag_Unsubscribed];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:infoFolderId]];
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of the url field is changed.
 * We disable the Subscribe button if the input fields are empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
	[self enableValidateButton];
}

/* enableValidateButton
 * Disable the Validate button if the URL field is empty.
 */
-(void)enableValidateButton
{
	[validateButton setEnabled:![[urlField stringValue] isBlank]];
}

/* validateURL
 * Validate the URL in the text field.
 */
-(IBAction)validateURL:(id)sender
{
	NSString * validatorPage = [[[NSApp delegate] standardURLs] valueForKey:@"FeedValidatorTemplate"];
	if (validatorPage != nil)
	{
		NSString * url = [[urlField stringValue] trim];
		NSString * validatorURL = [NSString stringWithFormat:validatorPage, url];
		[[NSApp delegate] openURLFromString:validatorURL inPreferredBrowser:YES];
	}
}

/* authenticationChanged
 * Update the authentication information for this feed when the Update button is
 * clicked.
 */
-(IBAction)authenticationChanged:(id)sender
{
	NSString * usernameString = [[username stringValue] trim];
	NSString * passwordString = [password stringValue];
	
	Database * db = [Database sharedDatabase];
	Folder * folder = [db folderFromID:infoFolderId];
	[db setFolderUsername:[folder itemId] newUsername:usernameString];
	[folder setPassword:passwordString];
}
@end
