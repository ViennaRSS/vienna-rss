//
//  EmptyTrashWarning.h
//  Vienna
//
//  Created by Jeffrey Johnson on 12/26/06.
//  Copyright (c) 2004-2006 Jeffrey Johnson. All rights reserved.
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

@interface EmptyTrashWarning : NSWindowController
{
	IBOutlet NSButton * doNotShowWarningAgain;
}

-(BOOL)shouldEmptyTrash;
-(IBAction)doNotEmptyTrash:(id)sender;
-(IBAction)emptyTrash:(id)sender;
@end
