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
#import "SystemConfiguration/SCNetworkReachability.h"

/* loadMapFromPath
 * Iterates all files and folders in the specified path and adds them to the given mappings
 * dictionary. If foldersOnly is YES, only folders are added. If foldersOnly is NO then only
 * files are added.
 */
void loadMapFromPath(NSString * path, NSMutableDictionary * pathMappings, BOOL foldersOnly)
{
	NSFileManager * fileManager = [NSFileManager defaultManager];
	NSArray * arrayOfFiles = [fileManager directoryContentsAtPath:path];
	if (arrayOfFiles != nil)
	{
		NSEnumerator * enumerator = [arrayOfFiles objectEnumerator];
		NSString * fileName;
		
		while ((fileName = [enumerator nextObject]) != nil)
		{
			NSString * fullPath = [path stringByAppendingPathComponent:fileName];
			BOOL isDirectory;
			
			if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory] && (isDirectory == foldersOnly))
			{
				if (![fileName isEqualToString:@".DS_Store"])
					[pathMappings setValue:fullPath forKey:[fileName stringByDeletingPathExtension]];
			}
		}
	}
}

/* isAccessible
 * Returns whether the specified URL is immediately accessible.
 */
BOOL isAccessible(NSString * urlString)
{
	SCNetworkConnectionFlags flags;
	NSURL * url = [NSURL URLWithString:urlString];
	
	return (SCNetworkCheckReachabilityByName([[url host] cString], &flags) &&
			(flags & kSCNetworkFlagsReachable) &&
			!(flags & kSCNetworkFlagsConnectionRequired));
}

/* runOKAlertPanel
 * Displays an alert panel with just an OK button.
 */
void runOKAlertPanel(NSString * titleString, NSString * bodyText, ...)
{
	NSString * fullBodyText;
	va_list arguments;
	
	va_start(arguments, bodyText);
	fullBodyText = [[NSString alloc] initWithFormat:NSLocalizedString(bodyText, nil) arguments:arguments];
	NSRunAlertPanel(NSLocalizedString(titleString, nil), fullBodyText, NSLocalizedString(@"OK", nil), nil, nil);
	[fullBodyText release];
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
	fullBodyText = [[NSString alloc] initWithFormat:NSLocalizedString(bodyText, nil) arguments:arguments];
	NSBeginAlertSheet(NSLocalizedString(titleString, nil),
					  NSLocalizedString(@"OK", nil),
					  nil,
					  nil,
					  [NSApp mainWindow],
					  nil,
					  nil,
					  nil, nil,
					  fullBodyText);
	[fullBodyText release];
	va_end(arguments);
}
