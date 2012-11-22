//
//  AdvancedPreferences.h
//  Vienna
//
//  Created by Steve Palmer on 25/11/2006.
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

@interface AdvancedPreferences : NSWindowController
{
	IBOutlet NSButton * useJavaScriptButton;
	IBOutlet NSPopUpButton * concurrentDownloads;
}

// Action functions
-(IBAction)changeUseJavaScript:(id)sender;
-(IBAction)changeConcurrentDownloads:(id)sender;
-(IBAction)showAdvancedHelp:(id)sender;
@end
