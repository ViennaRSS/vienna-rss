//
//  StdEnclosureView.h
//  Vienna
//
//  Created by Steve on Sun Jun 24 2007.
//  Copyright (c) 2004-2007 Steve Palmer. All rights reserved.
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

@class DSClickableURLTextField;

@interface StdEnclosureView : NSView
{
	IBOutlet NSImageView * fileImage;
	IBOutlet NSTextField * filenameLabel;
	IBOutlet DSClickableURLTextField * filenameField;
	IBOutlet NSButton * downloadButton;
	NSString * enclosureURLString;
	BOOL isITunes;
}

// Public functions
-(IBAction)downloadFile:(id)sender;
-(void)setEnclosureFile:(NSString *)filename;
@end
