//
//  StdEnclosureView.m
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

#import "StdEnclosureView.h"
#import "Preferences.h"
#import "DownloadManager.h"

@implementation StdEnclosureView

/* initWithFrame
 * Initialise the standard enclosure view.
 */
-(id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		enclosureFilename = nil;
	}
	return self;
}

/* setEnclosureFile
 * Fill out the enclosure fields with the specified file. The image is set to the icon type image
 * for the file and the base filename is shown in the filename field.
 */
-(void)setEnclosureFile:(NSString *)newFilename
{
	[newFilename retain];
	[enclosureFilename release];
	enclosureFilename = newFilename;

	// TODO stevepa: For certain enclosure types, we should use Open to open in an
	// external application.
	[downloadButton setTitle:NSLocalizedString(@"Download", nil)];
	[filenameLabel setStringValue:NSLocalizedString(@"This article contains an enclosed file.", nil)];
	
	NSString * basename = [enclosureFilename lastPathComponent];
	NSImage * iconImage = [[NSWorkspace sharedWorkspace] iconForFileType:[basename pathExtension]];
	[fileImage setImage:iconImage];
	[filenameField setStringValue:basename];
}

/* downloadFile
 * Handle the download file button.
 */
-(IBAction)downloadFile:(id)sender
{
	NSString * theFilename = [enclosureFilename lastPathComponent];
	NSString * downloadPath = [[Preferences standardPreferences] downloadFolder];
	NSString * destPath = [[downloadPath stringByExpandingTildeInPath] stringByAppendingPathComponent:theFilename];
	
	[[DownloadManager sharedInstance] downloadFile:destPath fromURL:enclosureFilename];
}

/* drawRect
 * Paint the enclosure background.
 */
-(void)drawRect:(NSRect)rect
{
	[[NSColor colorWithDeviceRed:(110.0f/255.0f) green:(142.0f/255.0f) blue:(185.0f/255.0f) alpha:1.0f] set];
	NSRectFill(rect);
}

/* dealloc
 * Clean up when we exit.
 */
-(void)dealloc
{
	[enclosureFilename release];
	[super dealloc];
}
@end
