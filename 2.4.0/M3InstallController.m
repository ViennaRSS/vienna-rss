/*****************************************************************
 M3InstallController.m
 
 Created by Martin Pilkington on 02/06/2007.
 
 Copyright (c) 2006-2009 M Cubed Software
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 *****************************************************************/

#import "M3InstallController.h"
#import "NSWorkspace_RBAdditions.h"


@implementation M3InstallController

- (id) init {
	if ((self = [super init])) {
		NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
		NSString *title = [NSString stringWithFormat:NSLocalizedString(@"%@ is currently running from a disk image", @"AppName is currently running from a disk image"), appName];
		NSString *body = [NSString stringWithFormat:NSLocalizedString(@"Would you like to install %@ in your applications folder before quitting?", @"Would you like to install App Name in your applications folder before quitting?"), appName];
		alert = [[NSAlert alertWithMessageText:title 
								 defaultButton:NSLocalizedString(@"Install", @"Install")
							   alternateButton:NSLocalizedString(@"Don't Install", @"Don't Install")
								   otherButton:nil
					 informativeTextWithFormat:body] retain];
		[alert setShowsSuppressionButton:YES];
	}
	return self;
}

- (void)displayInstaller {
	NSString *imageFilePath = [[[NSWorkspace sharedWorkspace] propertiesForPath:[[NSBundle mainBundle] bundlePath]] objectForKey:NSWorkspace_RBimagefilepath];
	if (imageFilePath && ![imageFilePath isEqualToString:[NSString stringWithFormat:@"/Users/.%@/%@.sparseimage", NSUserName(), NSUserName()]] && ![[NSUserDefaults standardUserDefaults] boolForKey:@"M3DontAskInstallAgain"]) {
		NSInteger returnValue = [alert runModal];
		if (returnValue == NSAlertDefaultReturn) {
			[self installApp];
		}
		if ([[alert suppressionButton] state] == NSOnState) {
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"M3DontAskInstallAgain"];
		}
	}
}

- (void)installApp {
	NSString *appsPath = [[NSString stringWithString:@"/Applications"] stringByAppendingPathComponent:[[[NSBundle mainBundle] bundlePath] lastPathComponent]];
	NSString *userAppsPath = [[[NSString stringWithString:@"~/Applications"] stringByAppendingPathComponent:[[[NSBundle mainBundle] bundlePath] lastPathComponent]] stringByExpandingTildeInPath];
	NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	
	//Delete the app that is installed
	if ([[NSFileManager defaultManager] fileExistsAtPath:appsPath]) {
		[[NSFileManager defaultManager] removeFileAtPath:appsPath handler:nil];
	}
	//Delete the app that is installed
	if ([[NSFileManager defaultManager] copyPath:[[NSBundle mainBundle] bundlePath] toPath:appsPath 
										  handler:nil]) {
		NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"%@ installed successfully", @"App Name installed successfully"), appName], 
						[NSString stringWithFormat:NSLocalizedString(@"%@ was installed in /Applications", @"App Name was installed in /Applications"), appName], 
						NSLocalizedString(@"Quit", @"Quit"), nil, nil);
	} else {
		if ([[NSFileManager defaultManager] fileExistsAtPath:userAppsPath]) {
			[[NSFileManager defaultManager] removeFileAtPath:userAppsPath handler:nil];
		}
		if ([[NSFileManager defaultManager] copyPath:[[NSBundle mainBundle] bundlePath] toPath:userAppsPath
												handler:nil]) {
		NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"%@ installed successfully", @"AppName installed successfully"), appName], 
				[NSString stringWithFormat:NSLocalizedString(@"%@ was installed in %@", @"App Name was installed in %@"), appName, [[NSString stringWithString:@"~/Applications"] stringByExpandingTildeInPath]], 
						NSLocalizedString(@"Quit", @"Quit"), nil, nil);
		} else {
			NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"Could not install %@", @"Could not install App Name"), appName], 
							NSLocalizedString(@"An error occurred when installing", @"An error occurred when installing"), NSLocalizedString(@"Quit", @"Quit"), nil, nil);
		}
	}
}

@end
