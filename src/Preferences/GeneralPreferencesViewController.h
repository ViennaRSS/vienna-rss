//
//  GeneralPreferencesViewController.h
//  Vienna
//
//  Created by Joshua Pore on 22/11/2014.
//  Copyright (c) 2014 uk.co.opencommunity. All rights reserved.
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

#import "MASPreferencesViewController.h"

@interface GeneralPreferencesViewController : NSViewController <MASPreferencesViewController> {
    IBOutlet NSPopUpButton * checkFrequency;
    IBOutlet NSPopUpButton * linksHandler;
    IBOutlet NSPopUpButton * expireDuration;
    IBOutlet NSButton * checkForUpdates;
    IBOutlet NSButton * checkOnStartUp;
    IBOutlet NSButton * sendSystemSpecs;
    IBOutlet NSButton * openLinksInBackground;
    IBOutlet NSButton * openLinksInExternalBrowser;
    IBOutlet NSButton * showAppInMenuBar;
    IBOutlet NSPopUpButton * downloadFolder;
    IBOutlet NSButtonCell * newArticlesNotificationBadgeButton;
    IBOutlet NSButtonCell * newArticlesNotificationBounceButton;
    IBOutlet NSButtonCell * markReadAfterNext;
    IBOutlet NSButtonCell * markReadAfterDelay;
    IBOutlet NSButton * markUpdatedAsNew;
    NSMutableDictionary * appToPathMap;
}

// Action functions
-(IBAction)changeCheckFrequency:(id)sender;
-(IBAction)changeCheckOnStartUp:(id)sender;
-(IBAction)changeSendSystemSpecs:(id)sender;
-(IBAction)selectDefaultLinksHandler:(id)sender;
-(IBAction)changeCheckForUpdates:(id)sender;
-(IBAction)changeOpenLinksInBackground:(id)sender;
-(IBAction)changeOpenLinksInExternalBrowser:(id)sender;
-(IBAction)changeExpireDuration:(id)sender;
-(IBAction)changeDownloadFolder:(id)sender;
-(IBAction)changeNewArticlesNotificationBadge:(id)sender;
-(IBAction)changeNewArticlesNotificationBounce:(id)sender;
-(IBAction)changeMarkReadBehaviour:(id)sender;
-(IBAction)changeShowAppInMenuBar:(id)sender;
-(IBAction)changeMarkUpdatedAsNew:(id)sender;

@end
