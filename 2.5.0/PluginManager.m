//
//  PluginManager.m
//  Vienna
//
//  Created by Steve on 10/1/10.
//  Copyright (c) 2004-2010 Steve Palmer. All rights reserved.
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

#import "PluginManager.h"
#import "HelperFunctions.h"
#import "StringExtensions.h"
#import "AppController.h"
#import "Preferences.h"
#import "Message.h"
#import "BrowserView.h"
#import "BrowserPane.h"

@interface PluginManager (Private)
@end

@implementation PluginManager

/* init
 * Initialises the plugin manager.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		allPlugins = nil;
	}
	return self;
}

/* resetPlugins
 * Called to unload all existing plugins and load all new plugins from the
 * builtin cache and from the user directory.
 */
-(void)resetPlugins
{
	NSMutableDictionary * pluginPaths;
	NSString * pluginName;
	NSString * path;

	if (allPlugins == nil)
		allPlugins = [[NSMutableDictionary alloc] init];
	else
		[allPlugins removeAllObjects];
	
	pluginPaths = [[NSMutableDictionary alloc] init];
	
	path = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"Plugins"];
	loadMapFromPath(path, pluginPaths, YES, nil);

	path = [[Preferences standardPreferences] pluginsFolder];
	loadMapFromPath(path, pluginPaths, YES, nil);

	for (pluginName in pluginPaths)
	{
		NSString * pluginPath = [pluginPaths objectForKey:pluginName];
		NSString * listFile = [pluginPath stringByAppendingPathComponent:@"info.plist"];
		NSMutableDictionary * pluginInfo = [NSMutableDictionary dictionaryWithContentsOfFile:listFile];

		// If the info.plist is missing or corrupted, warn but then just move on and the user
		// will have to figure it out.
		if (pluginInfo == nil)
		{
			NSAssert1(false, @"Missing or corrupt info.plist in %@", pluginPath);
			continue;
		}

		// We need to save the path to the plugin in the plugin object for later access to other
		// resources in the plugin folder.
		[pluginInfo setObject:pluginPath forKey:@"Path"];
		[allPlugins setObject:pluginInfo forKey:pluginName];
	}
	
	[pluginPaths release];
}

/* toolbarItems
 * Returns an NSArray of names of any plugins which can be added to the toolbar.
 */
-(NSArray *)toolbarItems
{
	return [allPlugins allKeys];
}

/* defaultToolbarItems
 * Returns an NSArray of names of any plugins which should be on the default toolbar.
 */
-(NSArray *)defaultToolbarItems
{
	NSMutableArray * newArray = [NSMutableArray arrayWithCapacity:[allPlugins count]];
	NSString * pluginName;

	for (pluginName in allPlugins)
	{
		NSDictionary * onePlugin = [allPlugins objectForKey:pluginName];
		if ([[onePlugin objectForKey:@"Default"] intValue])
			[newArray addObject:pluginName];
	}
	return newArray;
}

/* toolbarItem
 * Defines handling the label and appearance of all plugin buttons.
 */
-(void)toolbarItem:(ToolbarItem *)item withIdentifier:(NSString *)itemIdentifier
{
	NSDictionary * pluginItem = [allPlugins objectForKey:itemIdentifier];
	if (pluginItem != nil)
	{
		[item setLabel:[pluginItem objectForKey:@"FriendlyName"]];
		[item setPaletteLabel:[item label]];
		[item compositeButtonImage:[pluginItem objectForKey:@"ButtonImage"] fromPath:[pluginItem objectForKey:@"Path"]];
		[item setTarget:self];
		[item setAction:@selector(pluginInvocator:)];
		[item setToolTip:[pluginItem objectForKey:@"Tooltip"]];
	}
}

/* pluginInvocator
 * Called when the user issues a command relating to a plugin.
 */
-(IBAction)pluginInvocator:(id)sender
{
	if (![sender isKindOfClass:[ToolbarButton class]])
	{
		NSAssert(false, @"Error: pluginInvocator called from an object other than ToolbarButton. Ignored.");
		return;
	}
	
	NSString * itemIdentifier = [sender itemIdentifier];
	NSDictionary * pluginItem = [allPlugins objectForKey:itemIdentifier];
	if (pluginItem != nil)
	{
		// This is a link plugin. There should be a URL field which we invoke and possibly
		// placeholders to be filled from the current article or website.

		NSString * itemType = [pluginItem objectForKey:@"Type"];
		if ([itemType isEqualToString:@"Link"])
		{
			NSMutableString * urlString  = [NSMutableString stringWithString:[pluginItem objectForKey:@"URL"]];
			if (urlString == nil)
				return;
			
			NSView<BaseView> * theView = [[[NSApp delegate] browserView] activeTabItemView];
			
			// In case the user is currently looking at a website:
			if ([theView isKindOfClass:[BrowserPane class]])
			{	
				NSLog(@"%@", [theView viewLink]);
				[urlString replaceString:@"$ArticleLink$" withString:[theView viewLink]];
				[urlString replaceString:@"$ArticleTitle$" withString:[theView viewTitle]];
			}
			
			// In case the user is currently looking at an article:
			else
			{
				// We can only work on one article... so ignore selection range.
				Article * currentMessage = [[NSApp delegate] selectedArticle];
				urlString = [NSMutableString stringWithString:[currentMessage expandTags:urlString withConditional:NO]];
			}
			
			if (urlString != nil)
			{
				// Let WebKit do the heavy lifting of cleaning up the URL, as there are lots of things
				// that can go wrong otherwise: International Domain Names, umlauts or diacritics in titles, etc. ...
				NSURL *urlToLoad = nil;
				NSPasteboard * pasteboard = [NSPasteboard pasteboardWithName:@"ViennaIDNURLPasteboard"];
				[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
				@try
				{
					if ([pasteboard setString:urlString forType:NSStringPboardType])
						urlToLoad = [WebView URLFromPasteboard:pasteboard];
				}
				@catch (NSException * exception)
				{
					urlToLoad = nil;
				}
				
				if (urlToLoad == nil)
					urlToLoad = [NSURL URLWithString:urlString];
				if (urlToLoad != nil)
				{
					[[NSApp delegate] openURL:urlToLoad inPreferredBrowser:YES];
				}
				else
				{
					// TODO: present error message to user?
					NSBeep();
					NSLog(@"Can't create URL from string '%@'.", urlString);
				}
				
			}
		}
		
		else if ([itemType isEqualToString:@"Script"])
		{
			// This is a script plugin. There should be a Script field which specifies the
			// filename of the script file in the same folder.
			NSString * pluginPath = [pluginItem objectForKey:@"Path"];
			NSString * scriptFile = [pluginPath stringByAppendingPathComponent:[pluginItem objectForKey:@"Script"]];
			if (scriptFile == nil)
				return;

			// Just run the script
			[[NSApp delegate] runAppleScript:scriptFile];
		}
	}
}

/* dealloc
 * Clean up after ourselves.
 */
-(void)dealloc
{
	[allPlugins release];
	[super dealloc];
}
@end
