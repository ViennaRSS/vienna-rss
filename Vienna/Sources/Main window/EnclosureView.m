//
//  EnclosureView.m
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

#import "EnclosureView.h"

@import UniformTypeIdentifiers;

#import "Constants.h"
#import "DownloadManager.h"
#import "DSClickableURLTextField.h"
#import "NSWorkspace+OpenWithMenu.h"
#import "HelperFunctions.h"
#import "GeneratedAssetSymbols.h"

@interface EnclosureView ()

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *stackViewTrailingConstraint;

-(IBAction)openFile:(id)sender;

@end

@implementation EnclosureView {
    IBOutlet NSImageView *fileImage;
    IBOutlet NSTextField *filenameLabel;
    IBOutlet DSClickableURLTextField *filenameField;
    IBOutlet NSButton *downloadButton;
    NSString *enclosureURLString;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
		enclosureURLString = nil;

		// Register to be notified when a download completes.
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleDownloadCompleted:) name:MA_Notify_DownloadCompleted object:nil];
	}
	return self;
}

/* awakeFromNib
 * Configure our subviews upon awakening from nib storage.
 */
-(void)awakeFromNib
{
	[filenameField setCanCopyURLs:YES];

    if (@available(macOS 26, *)) {
        // Constrain the download button to the trailing layout margin.
        NSLayoutXAxisAnchor *marginAnchor = self.layoutMarginsGuide.trailingAnchor;
        NSLayoutXAxisAnchor *downloadButtonAnchor = downloadButton.trailingAnchor;
        [marginAnchor constraintEqualToAnchor:downloadButtonAnchor].active = YES;

        // Disable the existing layout constraint to avoid conflicts.
        self.stackViewTrailingConstraint.active = NO;
    }
}

/* handleDownloadCompleted
 * Called when a download completes. It might be the one showing in the view in which case we may
 * want to update the buttons.
 */
-(void)handleDownloadCompleted:(NSNotification *)notification
{
	if (enclosureURLString != nil) {
		[self setEnclosureFile:enclosureURLString];
	}
}

/* setEnclosureFile
 * Fill out the enclosure fields with the specified file. The image is set to the icon type image
 * for the file and the base filename is shown in the filename field.
 */
-(void)setEnclosureFile:(NSString *)newFilename
{

	// Keep this for the download/open
    NSURL *enclosureUrl = cleanedUpUrlFromString(newFilename);
    enclosureURLString = enclosureUrl.absoluteString;

	NSString * basename = enclosureUrl.lastPathComponent;
	if (basename==nil) {
		return;
	}

	// Find the file's likely location in Finder and see if it is already there.
	// We'll set the options in the pane based on whether the file is there or not.
	NSString * destPath = [DownloadManager fullDownloadPath:basename];
	if (![DownloadManager isFileDownloaded:destPath]) {
		[downloadButton setTitle:NSLocalizedString(@"Download", nil)];
		[downloadButton sizeToFit];
		downloadButton.action = @selector(downloadFile:);
		[filenameLabel setStringValue:NSLocalizedString(@"This article contains an enclosed file.", nil)];
	} else {
		NSString * appPath = [[NSWorkspace sharedWorkspace] vna_defaultHandlerApplicationForFile:destPath];
        NSString *displayName = [[[NSFileManager defaultManager] displayNameAtPath:appPath] stringByDeletingPathExtension];
        [downloadButton setTitle:[NSString stringWithFormat:NSLocalizedString(@"Open with %@", "Name the application which should open a file"), displayName]];
        [downloadButton sizeToFit];
        downloadButton.action = @selector(openFile:);
        [filenameLabel setStringValue:NSLocalizedString(@"Click the Open button to open this file.", nil)];
	}

    NSString *extension = basename.pathExtension;
    if (@available(macOS 11, *)) {
        UTType *type = [UTType typeWithFilenameExtension:extension];
        if (type) {
            fileImage.image = [NSWorkspace.sharedWorkspace iconForContentType:type];
        } else {
            fileImage.image = [NSWorkspace.sharedWorkspace iconForContentType:UTTypeItem];
        }
    } else {
        fileImage.image = [NSWorkspace.sharedWorkspace iconForFileType:extension];
    }
	NSDictionary *linkAttributes = @{
		NSLinkAttributeName: enclosureURLString,
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
	};
	NSAttributedString * link = [[NSAttributedString alloc] initWithString:basename attributes:linkAttributes];
	filenameField.attributedStringValue = link;
}

/* downloadFile
 * Download the enclosure.
 */
-(IBAction)downloadFile:(id)sender
{
	[[DownloadManager sharedInstance] downloadFileFromURL:enclosureURLString];
}

/* openFile
 * Open the enclosure in the host application.
 */
-(IBAction)openFile:(id)sender
{
	NSString * basename = [NSURL URLWithString:enclosureURLString].lastPathComponent;
	NSString * destPath = [DownloadManager fullDownloadPath:basename];

    NSURL *url = [NSURL fileURLWithPath:destPath];
    [NSWorkspace.sharedWorkspace openURL:url];
}

/* drawRect
 * Paint the enclosure background.
 */
- (void)drawRect:(NSRect)rect {
    [[NSColor colorNamed:ACColorNameAttachmentViewBackground] setFill];
    NSRectFill(self.bounds);
}

/* dealloc
 * Clean up when we exit.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	enclosureURLString=nil;
}
@end
