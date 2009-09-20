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

// Private functions
@interface StdEnclosureView (Private)
	-(IBAction)openFile:(id)sender;
@end

@implementation StdEnclosureView

/* initWithFrame
 * Initialise the standard enclosure view.
 */
-(id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		enclosureFilename = nil;
		isITunes = NO;

		// Register to be notified when a download completes.
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleDownloadCompleted:) name:@"MA_Notify_DownloadCompleted" object:nil];
	}
	return self;
}

/* handleDownloadCompleted
 * Called when a download completes. It might be the one showing in the view in which case we may
 * want to update the buttons.
 */
-(void)handleDownloadCompleted:(NSNotification *)notification
{
	if (enclosureFilename != nil)
		[self setEnclosureFile:enclosureFilename];
}

/* setEnclosureFile
 * Fill out the enclosure fields with the specified file. The image is set to the icon type image
 * for the file and the base filename is shown in the filename field.
 */
-(void)setEnclosureFile:(NSString *)newFilename
{
	CFURLRef appURL;
	FSRef appRef;

	// Keep this for the download/open
	[newFilename retain];
	[enclosureFilename release];
	enclosureFilename = newFilename;

	NSString * basename = [enclosureFilename lastPathComponent];
	NSString * ext = [basename pathExtension];

	// Find the file's likely location in Finder and see if it is already there.
	// We'll set the options in the pane based on whether the file is there or not.
	NSString * destPath = [DownloadManager fullDownloadPath:basename];
	if (![DownloadManager isFileDownloaded:destPath])
	{
		[downloadButton setTitle:NSLocalizedString(@"Download", nil)];
		[downloadButton setAction:@selector(downloadFile:)];
		[filenameLabel setStringValue:NSLocalizedString(@"This article contains an enclosed file.", nil)];
	}
	else
	{
		isITunes = NO;
		if (LSGetApplicationForInfo(kLSUnknownType, kLSUnknownCreator, (CFStringRef)ext, kLSRolesAll, &appRef, &appURL) != kLSApplicationNotFoundErr)
		{
			LSItemInfoRecord outItemInfo;
			
			LSCopyItemInfoForURL(appURL, kLSRequestTypeCreator, &outItemInfo);
			isITunes = [NSFileTypeForHFSTypeCode(outItemInfo.creator) isEqualToString:@"'hook'"];

			CFRelease(appURL);
		}

		// Open/Play is pretty much the same thing but we want to be a bit friendlier to iTunes
		// and make it clearer what will happen when the file is opened.
		if (isITunes)
		{
			[downloadButton setTitle:NSLocalizedString(@"Play", nil)];
			[downloadButton setAction:@selector(openFile:)];
			[filenameLabel setStringValue:NSLocalizedString(@"Click the Play button to play this enclosure in iTunes.", nil)];
		}
		else
		{
			[downloadButton setTitle:NSLocalizedString(@"Open", nil)];
			[downloadButton setAction:@selector(openFile:)];
			[filenameLabel setStringValue:NSLocalizedString(@"Click the Open button to open this file.", nil)];
		}
	}
	
	NSImage * iconImage = [[NSWorkspace sharedWorkspace] iconForFileType:ext];
	[fileImage setImage:iconImage];
	[filenameField setStringValue:basename];
}

/* downloadFile
 * Download the enclosure.
 */
-(IBAction)downloadFile:(id)sender
{
	NSString * theFilename = [enclosureFilename lastPathComponent];
	NSString * destPath = [DownloadManager fullDownloadPath:theFilename];
	
	[[DownloadManager sharedInstance] downloadFile:destPath fromURL:enclosureFilename];
}

/* openFile
 * Open the enclosure in the host application.
 */
-(IBAction)openFile:(id)sender
{
	NSString * theFilename = [enclosureFilename lastPathComponent];
	NSString * destPath = [DownloadManager fullDownloadPath:theFilename];

	[[NSWorkspace sharedWorkspace] openFile:destPath];
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
