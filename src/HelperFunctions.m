//
//  HelperFunctions.m
//  Vienna
//
//  Created by Steve on 8/28/05.
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
// 

#import "HelperFunctions.h"
#import <SystemConfiguration/SCNetworkReachability.h>
#import <Carbon/Carbon.h>
#import <WebKit/WebKit.h>

// Private functions
static OSStatus RegisterMyHelpBook(void);

/* hasOSScriptsMenu
 * Determines whether the OS script menu is present or not.
 */
BOOL hasOSScriptsMenu(void)
{
	NSString * pathToUIServerPlist = (@"~/Library/Preferences/com.apple.systemuiserver.plist").stringByExpandingTildeInPath;
	NSDictionary * properties = [NSDictionary dictionaryWithContentsOfFile:pathToUIServerPlist];
	NSArray * menuExtras = properties[@"menuExtras"];
	NSInteger index;

	for (index = 0; index < menuExtras.count; ++index)
	{
		if ([menuExtras[index] hasSuffix:@"Script Menu.menu"])
			return YES;
	}
	return NO;
}

/* getDefaultBrowser
 * Return the name of the default system browser.
 */
NSString * getDefaultBrowser(void)
{
	NSURL * testURL = [NSURL URLWithString:@"http://example.net"];
	NSString * registeredAppURL = nil;
	CFURLRef appURL = nil;

	if (LSGetApplicationForURL((__bridge CFURLRef)testURL, kLSRolesAll, NULL, &appURL) != kLSApplicationNotFoundErr)
		registeredAppURL = ((__bridge NSURL *)appURL).path;
	if (appURL != nil)
		CFRelease(appURL);
	return registeredAppURL.lastPathComponent.stringByDeletingPathExtension;
}

/* menuWithAction
 * Returns the first NSMenuItem that matches the one that implements the corresponding
 * action in the application main menu. Returns nil if no match is found.
 */
NSMenuItem * menuItemWithAction(SEL theSelector)
{
	NSArray * arrayOfMenus = NSApp.mainMenu.itemArray;
	NSInteger count = arrayOfMenus.count;
	NSInteger index;

	for (index = 0; index < count; ++index)
	{
		NSMenu * subMenu = [arrayOfMenus[index] submenu];
		NSInteger itemIndex = [subMenu indexOfItemWithTarget:NSApp.delegate andAction:theSelector];
		if (itemIndex >= 0)
			return [subMenu itemAtIndex:itemIndex];
	}
	return nil;
}

/* menuWithAction
 * Returns the first NSMenuItem that matches the one that implements the corresponding
 * action in the application main menu. Returns nil if no match is found.
 */
NSMenuItem * menuItemOfMenuWithAction(NSMenu * menu, SEL theSelector)
{
	NSArray * arrayOfMenus = menu.itemArray;
	NSInteger count = arrayOfMenus.count;
	NSInteger index;
	
	for (index = 0; index < count; ++index)
	{
		NSMenu * subMenu = [arrayOfMenus[index] submenu];
		NSInteger itemIndex = [subMenu indexOfItemWithTarget:NSApp.delegate andAction:theSelector];
		if (itemIndex >= 0)
			return [subMenu itemAtIndex:itemIndex];
	}
	return nil;
}

/* percentEscape
 * Escape invalid and reserved URL characters to make string suitable 
 * for embedding in mailto: URLs and custom app-specific schemes like papers://
 */ 
NSString * percentEscape(NSString *string)
{
	return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL,
												   
												   // RFC2368 says all URL reserved characters must be encoded
												   // these are all the reserved characters from RFC3986
												   CFSTR("/:?#[]@!$&'()*+,;="),	
												   
												   kCFStringEncodingUTF8));
}

/* cleanedUpAndEscapedUrlFromString
 * Uses WebKit to clean up user-entered URLs that might contain umlauts, diacritics and other
 * IDNA related stuff in the domain, or God knows what in filenames and arguments.
 */
NSURL * cleanedUpAndEscapedUrlFromString(NSString * theUrl)
{
	NSURL *urlToLoad = nil;
	NSPasteboard * pasteboard = [NSPasteboard pasteboardWithName:@"ViennaIDNURLPasteboard"];
	[pasteboard declareTypes:@[NSStringPboardType] owner:nil];
	@try
	{
		if ([pasteboard setString:theUrl forType:NSStringPboardType])
			urlToLoad = [WebView URLFromPasteboard:pasteboard];
	}
	@catch (NSException * exception)
	{
		urlToLoad = nil;
		{
			// TODO: present error message to user?
			NSBeep();
			NSLog(@"Can't create URL from string '%@'.", theUrl);
		}		
	}
	
	return urlToLoad;
}	

/* copyOfMenuItemWithAction
 * Returns an NSMenuItem that matches the one that implements the corresponding
 * action in the application main menu. Returns nil if no match is found.
 */
NSMenuItem * copyOfMenuItemWithAction(SEL theSelector)
{
	NSMenuItem * item = menuItemWithAction(theSelector);
	return (item) ? [[NSMenuItem alloc] initWithTitle:item.title action:theSelector keyEquivalent:@""] : nil;
}

/* menuWithTitleAndAction
 * Returns an NSMenuItem with the specified menu and action.
 */
NSMenuItem * menuItemWithTitleAndAction(NSString * theTitle, SEL theSelector)
{
	return [[NSMenuItem alloc] initWithTitle:theTitle action:theSelector keyEquivalent:@""];
}

/* loadMapFromPath
 * Iterates all files and folders in the specified path and adds them to the given mappings
 * dictionary. If foldersOnly is YES, only folders are added. If foldersOnly is NO then only
 * files are added.
 */
void loadMapFromPath(NSString * path, NSMutableDictionary * pathMappings, BOOL foldersOnly, NSArray * validExtensions)
{
	NSFileManager * fileManager = [NSFileManager defaultManager];
	NSArray * arrayOfFiles = [fileManager contentsOfDirectoryAtPath:path error:nil];
	if (arrayOfFiles != nil)
	{
		if (validExtensions)
			arrayOfFiles = [arrayOfFiles pathsMatchingExtensions:validExtensions];
		
		for (NSString * fileName in arrayOfFiles)
		{
			NSString * fullPath = [path stringByAppendingPathComponent:fileName];
			BOOL isDirectory;
			
			if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory] && (isDirectory == foldersOnly))
			{
				if ([fileName isEqualToString:@".DS_Store"])
					continue;

				[pathMappings setValue:fullPath forKey:fileName.stringByDeletingPathExtension];
			}
		}
	}
}

/* isAccessible
 * Returns whether the specified URL is immediately accessible.
 */
BOOL isAccessible(NSString * urlString)
{
	SCNetworkReachabilityRef   target;
	SCNetworkReachabilityFlags flags = 0;
	Boolean                   ok;
	
	NSURL * url = [NSURL URLWithString:urlString];

	target = SCNetworkReachabilityCreateWithName(NULL, url.host.UTF8String);
    if (target!= nil)
    {
        ok = SCNetworkReachabilityGetFlags(target, &flags);
        CFRelease(target);

        if (!ok)
            return NO;
        return (flags & kSCNetworkReachabilityFlagsReachable) && !(flags & kSCNetworkReachabilityFlagsConnectionRequired);
    }
    else
        return NO;
}

/* runOKAlertPanel
 * Displays an alert panel with just an OK button.
 */
void runOKAlertPanel(NSString * titleString, NSString * bodyText, ...)
{
	NSString * fullBodyText;
	va_list arguments;
	
	va_start(arguments, bodyText);
	fullBodyText = [[NSString alloc] initWithFormat:bodyText arguments:arguments];
	// Security: arguments may contain formatting characters, so don't use fullBodyText as format string.
	NSRunAlertPanel(titleString, @"%@", NSLocalizedString(@"OK", nil), nil, nil, fullBodyText);
	va_end(arguments);
}

/* runOKAlertSheet
 * Displays an alert sheet with just an OK button.
 */
void runOKAlertSheet(NSString * titleString, NSString * bodyText, ...)
{
	NSString * fullBodyText;
	va_list arguments;
	
	va_start(arguments, bodyText);
	fullBodyText = [[NSString alloc] initWithFormat:bodyText arguments:arguments];
	// Security: arguments may contain formatting characters, so don't use fullBodyText as format string.
	NSBeginAlertSheet(titleString,
					  NSLocalizedString(@"OK", nil),
					  nil,
					  nil,
					  NSApp.mainWindow,
					  nil,
					  nil,
					  nil, nil,
					  @"%@",
					  fullBodyText);
	va_end(arguments);
}

/* RegisterMyHelpBook
 * Ensure that the help book is registered before GotoHelpPage can be used.
 */
static OSStatus RegisterMyHelpBook(void)
{
    OSStatus err = noErr;

    CFBundleRef myApplicationBundle = CFBundleGetMainBundle();
	if (myApplicationBundle == NULL)
		err = fnfErr;
	else
	{
		CFURLRef myBundleURL = CFBundleCopyBundleURL(myApplicationBundle);
		if (myBundleURL == NULL)
			err = fnfErr;
		else
		{
			FSRef myBundleRef;
			if (!CFURLGetFSRef(myBundleURL, &myBundleRef))
				err = fnfErr;
			if (err == noErr)
				err = AHRegisterHelpBook(&myBundleRef);
			CFRelease(myBundleURL);
		}
	}
	return err;
}

/* GotoHelpPage
 * Displays a specified page of the help file.
 */
OSStatus GotoHelpPage (CFStringRef pagePath, CFStringRef anchorName)
{
    CFBundleRef myApplicationBundle = NULL;
    CFStringRef myBookName = NULL;
    OSStatus err;

	err = RegisterMyHelpBook();
	if (err != noErr)
		return err;
    myApplicationBundle = CFBundleGetMainBundle();
	if (myApplicationBundle == NULL)
		err = fnfErr;
	else
	{
		myBookName = CFBundleGetValueForInfoDictionaryKey(myApplicationBundle, CFSTR("CFBundleHelpBookName"));
		if (myBookName == NULL)
			err = fnfErr;
		else
		{
			if (CFGetTypeID(myBookName) != CFStringGetTypeID())
				err = paramErr;
		}
	}
	if (err == noErr)
		err = AHGotoPage(myBookName, pagePath, anchorName);
	return err;
}
