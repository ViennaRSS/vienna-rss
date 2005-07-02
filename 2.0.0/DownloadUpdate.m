//
//  DownloadUpdate.m
//  Vienna
//
//  Created by Steve on Wed Apr 09 2004.
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

#import "DownloadUpdate.h"

@implementation DownloadUpdate

/* download
 */
-(void)download:(NSWindow *)window fromURL:(NSString *)fromURL toFilename:(NSString *)toFilename
{
	// Initialize UI
	if (!updateWindow)
		[NSBundle loadNibNamed:@"DownloadPanel" owner:self];
	[NSApp beginSheet:updateWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
	[progressBar startAnimation:self];

	// Set the title
	NSString * title = [NSString stringWithFormat:NSLocalizedString(@"Downloading %@", nil), [toFilename lastPathComponent]];
	[titleString setStringValue:title];
	
	// Enter a tight loop until the user cancels or the
	// import completes.
	NSURLRequest * theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:fromURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
	theDownload = [[NSURLDownload alloc] initWithRequest:theRequest delegate:self];	
	if (theDownload)
		[theDownload setDestination:toFilename allowOverwrite:YES];
}

/* commonDownloadComplete
 */
-(void)commonDownloadComplete
{
	[progressBar stopAnimation:self];
	[NSApp endSheet:updateWindow];
	[updateWindow orderOut:self];
}

/* cancelButton
 * Called when the user clicks the Cancel button. We stop the download and
 * end the dialog.
 */
-(IBAction)cancelButton:(id)sender
{
	[theDownload cancel];
	[self commonDownloadComplete];
}

/* downloadDidBegin
 * Called when the download starts.
 */
-(void)downloadDidBegin:(NSURLDownload *)download
{
	[progressString setStringValue:NSLocalizedString(@"Starting...", nil)];
}

/* didReceiveResponse
 * Called once after we have the initial response from the server. This is a good
 * time to cache the expectedLength if it is known and to make the progress bar
 * into a determinate state since we're able to compute % completed.
 */
-(void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response
{
	bytesReceived = 0;
	expectedLength = [response expectedContentLength];
	if (expectedLength != NSURLResponseUnknownLength)
		[progressBar setIndeterminate:NO];
}

/* didReceiveDataOfLength
 * Called when a block of data is received from the server.
 */
-(void)download:(NSURLDownload *)download didReceiveDataOfLength:(unsigned)length
{
	NSString * unitString;
	double unitsValue;
	
	bytesReceived += length;
	if (bytesReceived < 1024)
	{
		unitsValue = bytesReceived;
		unitString = @" bytes";
	}
	else if (bytesReceived < 1024 * 1024)
	{
		unitsValue = bytesReceived / 1024;
		unitString = @"K";
	}
	else
	{
		unitsValue = (double)bytesReceived / (1024 * 1024);
		unitString = @"MB";
	}
	if (expectedLength != NSURLResponseUnknownLength)
	{
		float percentComplete = (bytesReceived / (float)expectedLength) * 100.0;
		NSString * progress = [NSString stringWithFormat:NSLocalizedString(@"Full download progress", nil), unitsValue, unitString, (int)percentComplete];
		[progressString setStringValue:progress];
		[progressBar setDoubleValue:percentComplete];
	}
	else
	{
		NSString * progress = [NSString stringWithFormat:NSLocalizedString(@"Simple download progress", nil), unitsValue, unitString];
		[progressString setStringValue:progress];
	}
}

/* shouldDecodeSourceDataOfMIMEType
 */
-(BOOL)download:(NSURLDownload *)download shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType;
{
	BOOL shouldDecode = NO;
	if ([encodingType isEqual:@"application/macbinary"])
		shouldDecode = YES;
	else if ([encodingType isEqual:@"application/binhex"])
		shouldDecode = YES;
	else if ([encodingType isEqual:@"application/gzip"])
		shouldDecode = NO;
	return shouldDecode;
}

/* didFailWithError
 * This delegate is called if an error occurred.
 */
-(void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	[self commonDownloadComplete];

	NSString * errorDescription = [error localizedDescription];
	if (!errorDescription)
		errorDescription = NSLocalizedString(@"An error occured during download.", nil);
	else
		errorDescription = [NSString stringWithFormat:@"The download failed because: %@.", [error localizedDescription]];
	NSBeginAlertSheet(NSLocalizedString(@"Download Failed", nil), nil, nil, nil, [self window], nil, nil, nil, nil, errorDescription);

	[download release];
}

/* downloadDidFinish
 * Called when the download completes.
 */
-(void)downloadDidFinish:(NSURLDownload *)download
{
	[download release];
	[self commonDownloadComplete];
}
@end
