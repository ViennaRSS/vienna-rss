//
//  InfoWindow.h
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

#import <Cocoa/Cocoa.h>

@interface InfoWindowManager : NSObject {
	NSMutableDictionary * controllerList;
}

// Public functions
+(InfoWindowManager *)infoWindowManager;
-(void)showInfoWindowForFolder:(int)folderId;
@end

@interface InfoWindow : NSWindowController <NSWindowDelegate> {
	IBOutlet NSTextField * folderName;
	IBOutlet NSTextField * lastRefreshDate;
	IBOutlet NSImageView * folderImage;
	IBOutlet NSTextField * urlField;
	IBOutlet NSTextField * username;
	IBOutlet NSSecureTextField * password;
	IBOutlet NSTextField * folderSize;
	IBOutlet NSTextField * folderUnread;
	IBOutlet NSButton * isSubscribed;
	IBOutlet NSButton * loadFullHTML;
	IBOutlet NSTextField * folderDescription;
	IBOutlet NSButton * validateButton;
	int infoFolderId;
}

// Action handlers
-(IBAction)validateURL:(id)sender;
-(IBAction)urlFieldChanged:(id)sender;
-(IBAction)authenticationChanged:(id)sender;
-(IBAction)subscribedChanged:(id)sender;
-(IBAction)loadFullHTMLChanged:(id)sender;
@end
