//
//  Export.h
//  Vienna
//
//  Created by Steve on 5/27/05.
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

#import <Cocoa/Cocoa.h>
#import "Database.h"
#import "AppController.h"

@interface AppController (Export)
	-(IBAction)exportSubscriptions:(id)sender;
	-(int)exportToFile:(NSString *)exportFileName from:(NSArray *)foldersArray withGroups:(BOOL)groupFlag;
@end
