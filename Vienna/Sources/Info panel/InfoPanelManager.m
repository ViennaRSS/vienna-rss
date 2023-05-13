//
//  InfoPanelManager.m
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

#import "InfoPanelManager.h"

#import "AppController.h"
#import "Constants.h"
#import "Database.h"
#import "InfoPanelController.h"

@implementation InfoPanelManager {
    NSMutableDictionary *controllerList;
}

/* infoWindowManager
 * Returns the shared instance of the InfoWindowManager
 */
+(InfoPanelManager *)infoWindowManager
{
	// Singleton controller for all info windows
	static InfoPanelManager * _infoWindowManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
			_infoWindowManager = [[InfoPanelManager alloc] init];
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
	if ((self = [super init]) != nil) {
		controllerList = [[NSMutableDictionary alloc] initWithCapacity:10];
		
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleFolderDeleted:) name:VNADatabaseDidDeleteFolderNotification object:nil];
		[nc addObserver:self selector:@selector(handleFolderChange:) name:MA_Notify_FolderNameChanged object:nil];
		[nc addObserver:self selector:@selector(handleFolderChange:) name:MA_Notify_FoldersUpdated object:nil];
		[nc addObserver:self selector:@selector(handleFolderChange:) name:MA_Notify_LoadFullHTMLChange object:nil];
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
	InfoPanelController * infoWindow;
	
	infoWindow = controllerList[folderNumber];
	if (infoWindow != nil) {
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
	InfoPanelController * infoWindow;
	
	infoWindow = controllerList[folderNumber];
	if (infoWindow != nil) {
		[infoWindow updateFolder];
	}
}

/**
 If there's an active info window for the specified folder then it is activated
 and brought to the front. Otherwise a new window is created for the folder.

 @todo: Replace the block.
 */
-(void)showInfoWindowForFolder:(NSInteger)folderId block:(void (^)(InfoPanelController *infoPanelController))block
{
	NSNumber * folderNumber = @(folderId);
	InfoPanelController * infoWindow;

	infoWindow = controllerList[folderNumber];
	if (infoWindow == nil) {
		infoWindow = [[InfoPanelController alloc] initWithFolder:folderId];
        block(infoWindow);
		controllerList[folderNumber] = infoWindow;
	}
	[infoWindow showWindow:NSApp.mainWindow];

}
@end
