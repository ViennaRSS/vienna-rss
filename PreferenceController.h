//
//  PreferenceController.h
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

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

@interface PreferenceController : NSWindowController {
	IBOutlet NSPopUpButton * messageListFont;
	IBOutlet NSComboBox * messageListFontSize;
	IBOutlet NSPopUpButton * folderFont;
	IBOutlet NSComboBox * folderFontSize;
	IBOutlet NSPopUpButton * checkFrequency;
	IBOutlet NSPopUpButton * linksHandler;
	IBOutlet NSButton * checkForUpdates;
	IBOutlet NSButton * checkOnStartUp;
	IBOutlet NSButton * enableBloglines;
	IBOutlet NSButtonCell * markReadAfterNext;
	IBOutlet NSButtonCell * markReadAfterDelay;
	IBOutlet NSTextField * bloglinesEmailAddressLabel;
	IBOutlet NSTextField * bloglinesPasswordLabel;
	IBOutlet NSTextField * bloglinesEmailAddress;
	IBOutlet NSSecureTextField * bloglinesPassword;
	NSMutableDictionary * appToPathMap;
	ICInstance internetConfigHandler;
}

// Action functions
-(IBAction)changeFont:(id)sender;
-(IBAction)changeCheckFrequency:(id)sender;
-(IBAction)changeCheckOnStartUp:(id)sender;
-(IBAction)selectDefaultLinksHandler:(id)sender;
-(IBAction)changeCheckForUpdates:(id)sender;
-(IBAction)changeEnableBloglines:(id)sender;
-(IBAction)changeBloglinesEmailAddress:(id)sender;
-(IBAction)changeBloglinesPassword:(id)sender;
-(IBAction)changeMarkReadBehaviour:(id)sender;

// General functions
-(void)initializePreferences;
@end
