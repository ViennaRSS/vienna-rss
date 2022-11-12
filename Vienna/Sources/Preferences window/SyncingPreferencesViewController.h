//
//  SyncingPreferencesViewController.h
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

@import Cocoa;

@interface SyncingPreferencesViewController : NSViewController <NSTextFieldDelegate> {
    IBOutlet NSPopUpButton * openReaderSource; //List of known service providers
    NSDictionary * sourcesDict;
    IBOutlet NSTextField * credentialsInfoText;
    IBOutlet NSTextField * openReaderHost;
    IBOutlet NSTextField * username;
    IBOutlet NSSecureTextField * password;
    IBOutlet NSButton *__weak syncButton;
}

@property (weak) IBOutlet NSButton *syncButton;

-(IBAction)changeSyncOpenReader:(id)sender;
-(IBAction)changeSource:(id)sender;
-(IBAction)visitWebsite:(id)sender;

@end
