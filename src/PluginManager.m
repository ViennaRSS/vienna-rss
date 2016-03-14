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
#import "Article.h"
#import "BrowserPane.h"
#import "BitlyAPIHelper.h"
#import "SearchMethod.h"

@interface PluginManager (Private)
	-(void)installPlugin:(NSDictionary *)onePlugin;
@end

@implementation PluginManager

/* init
 * Initialises the plugin manager.
 */
-(instancetype)init
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
	
	path = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"Plugins"];
	loadMapFromPath(path, pluginPaths, YES, nil);

	path = [[Preferences standardPreferences] pluginsFolder];
	loadMapFromPath(path, pluginPaths, YES, nil);

	for (pluginName in pluginPaths)
	{
		NSString * pluginPath = pluginPaths[pluginName];
		[self loadPlugin:pluginPath];
	}

}

/* loadPlugin
 * Load the plugin at the specified path.
 */
-(void)loadPlugin:(NSString *)pluginPath
{
	NSString * listFile = [pluginPath stringByAppendingPathComponent:@"info.plist"];
	NSString * pluginName = pluginPath.lastPathComponent;
	NSMutableDictionary * pluginInfo = [NSMutableDictionary dictionaryWithContentsOfFile:listFile];
	
	// If the info.plist is missing or corrupted, warn but then just move on and the user
	// will have to figure it out.
	if (pluginInfo == nil)
		NSLog(@"Missing or corrupt info.plist in %@", pluginPath);
	else
	{
		// We need to save the path to the plugin in the plugin object for later access to other
		// resources in the plugin folder.
		pluginInfo[@"Path"] = pluginPath;
		allPlugins[pluginName] = pluginInfo;
		
		// Pop it on the menu if needed
		[self installPlugin:pluginInfo];
	}
}

/* installPlugin
 * Installs one plugin to the menus.
 */
-(void)installPlugin:(NSDictionary *)onePlugin
{
	// If it's a blog editor plugin, don't show it in the menu 
	// if the app in question is not present on the system.
	if ([onePlugin[@"Type"] isEqualToString:@"BlogEditor"])
	{
		NSString * bundleIdentifier = onePlugin[@"BundleIdentifier"];
		
		if (![[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: bundleIdentifier])
			return;
	}
						
	NSString * pluginName = onePlugin[@"Name"];
	NSString * menuPath = onePlugin[@"MenuPath"];
	if (menuPath == nil)
		return;
	
	// The menu path can be specified as Menu/Title, where Menu is the
	// unlocalized name of the top level menu under which the plugin is
	// added and Title is the menu name representing the plugin. If the
	// Menu part is omitted, the plugin goes at the end of the Article menu by
	// default.
	NSScanner * scanner = [NSScanner scannerWithString:menuPath];
	NSString * topLevelMenu = nil;
	NSString * menuTitle = nil;
	
	[scanner scanUpToString:@"/" intoString:&topLevelMenu];
	if (scanner.atEnd || topLevelMenu == nil)
	{
		topLevelMenu = @"Article";
		menuTitle = menuPath;
	}
	else
	{
		[scanner scanString:@"/" intoString:nil];
		[scanner scanUpToString:@"" intoString:&menuTitle];
	}
		topLevelMenu = NSLocalizedString(topLevelMenu, nil);
	
	NSArray * menuArray = NSApp.mainMenu.itemArray;
	BOOL didInstall = NO;
	NSInteger c;
	
	for (c = 0; !didInstall && c < menuArray.count; ++c)
	{
		NSMenuItem * topMenu = menuArray[c];
		if ([topMenu.title isEqualToString:topLevelMenu])
		{
			// Parse off the shortcut key, if there is one. The format is a series of
			// control key specifiers: Cmd, Shift, Alt or Ctrl - specified in any
			// order and separated by '+', plus a single key character. If more than
			// one key character is given, the last one is used but generally that is
			// a bug in the MenuKey.
			NSString * menuKey = onePlugin[@"MenuKey"];
			NSUInteger keyMod = 0;
			NSString * keyChar = @"";
			
			if (menuKey != nil)
			{
				NSArray * keyArray = [menuKey componentsSeparatedByString:@"+"];
				NSString * oneKey;
				
				for (oneKey in keyArray)
				{
					if ([oneKey isEqualToString:@"Cmd"])
						keyMod |= NSCommandKeyMask;
					else if ([oneKey isEqualToString:@"Shift"])
						keyMod |= NSShiftKeyMask;
					else if ([oneKey isEqualToString:@"Alt"])
						keyMod |= NSAlternateKeyMask;
					else if ([oneKey isEqualToString:@"Ctrl"])
						keyMod |= NSControlKeyMask;
					else
					{
						if (![keyChar isBlank])
							NSLog(@"Warning: malformed MenuKey found in info.plist for plugin %@", pluginName);
						keyChar = oneKey;
					}
				}
			}

			// Keep the menus tidy. If the last menu item is not currently a plugin invocator then
			// add a separator.
			NSMenu * parentMenu = topMenu.submenu;
			NSInteger lastItem = parentMenu.numberOfItems - 1;
			
			if (lastItem >= 0 && [parentMenu itemAtIndex:lastItem].action != @selector(pluginInvocator:))
				[parentMenu addItem:[NSMenuItem separatorItem]];

			// Finally add the plugin to the end of the selected menu complete with
			// key equivalent and save the plugin object in the NSMenuItem so that we
			// can associate it in pluginInvocator.
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:menuTitle action:@selector(pluginInvocator:) keyEquivalent:keyChar];
			menuItem.target = self;
			menuItem.keyEquivalentModifierMask = keyMod;
			menuItem.representedObject = onePlugin;
			[parentMenu addItem:menuItem];
			
			didInstall = YES;
		}
	}

	// Warn if we failed to install a plugin
	if (!didInstall)
	{
		runOKAlertPanel(NSLocalizedString(@"Plugin could not be installed", nil), NSLocalizedString(@"Vienna failed to install the plugin.", nil), pluginName);
		NSLog(@"Warning: error in MenuPath (\"%@\") in info.plist for plugin %@", menuPath, pluginName);
	}
}

/* searchMethods
 * Returns an NSArray of SearchMethods which can be added to the search-box menu.
 */
-(NSArray *)searchMethods
{
	NSMutableArray * searchMethods = [NSMutableArray arrayWithCapacity:allPlugins.count];
	for (NSDictionary * plugin in allPlugins.allValues)
	{
		if ([[plugin valueForKey:@"Type"] isEqualToString:@"SearchEngine"])
		{
			SearchMethod * method = [[SearchMethod alloc] initWithDictionary:plugin];
			[searchMethods addObject:method];
		}
	}
	return searchMethods;
}	

/* toolbarItems
 * Returns an NSArray of names of any plugins which can be added to the toolbar.
 */
-(NSArray *)toolbarItems
{
	NSMutableArray * toolbarKeys = [NSMutableArray arrayWithCapacity:allPlugins.count];
	NSString * pluginName;
	NSString * pluginType;	
	for (pluginName in allPlugins)
	{
		NSDictionary * onePlugin = allPlugins[pluginName];
		pluginType = onePlugin[@"Type"];
		if (![pluginType isEqualToString:@"SearchEngine"])
			[toolbarKeys addObject:pluginName];
	}
	return toolbarKeys;
}

/* defaultToolbarItems
 * Returns an NSArray of names of any plugins which should be on the default toolbar.
 */
-(NSArray *)defaultToolbarItems
{
	NSMutableArray * newArray = [NSMutableArray arrayWithCapacity:allPlugins.count];
	NSString * pluginName;

	for (pluginName in allPlugins)
	{
		NSDictionary * onePlugin = allPlugins[pluginName];
		if ([onePlugin[@"Default"] integerValue])
			[newArray addObject:pluginName];
	}
	return newArray;
}

/* toolbarItem
 * Defines handling the label and appearance of all plugin buttons.
 */
-(void)toolbarItem:(ToolbarItem *)item withIdentifier:(NSString *)itemIdentifier
{
	NSDictionary * pluginItem = allPlugins[itemIdentifier];
	if (pluginItem != nil)
	{
		NSString * friendlyName = pluginItem[@"FriendlyName"];
		NSString * tooltip = pluginItem[@"Tooltip"];

		if (friendlyName == nil)
			friendlyName = itemIdentifier;
		if (tooltip == nil)
			tooltip = friendlyName;
		
		item.label = friendlyName;
		item.paletteLabel = item.label;
		[item compositeButtonImage:pluginItem[@"ButtonImage"] fromPath:pluginItem[@"Path"]];
		item.target = self;
		item.action = @selector(pluginInvocator:);
		item.toolTip = tooltip;
	}
}

/* validateToolbarItem
 * Check [theItem identifier] and return YES if the item is enabled, NO otherwise.
 */
-(BOOL)validateToolbarItem:(ToolbarItem *)toolbarItem
{	
	NSView<BaseView> * theView = [[APPCONTROLLER browserView] activeTabItemView];
	Article * thisArticle = [APPCONTROLLER selectedArticle];
	
	if ([theView isKindOfClass:[BrowserPane class]])
		return (([theView viewLink] != nil) && NSApp.active);
	else
		return (thisArticle != nil && NSApp.active);
}

/* pluginInvocator
 * Called when the user issues a command relating to a plugin.
 */
-(IBAction)pluginInvocator:(id)sender
{
	NSDictionary * pluginItem;

	if ([sender isKindOfClass:[ToolbarButton class]])
		pluginItem = allPlugins[[sender itemIdentifier]];
	else
	{
		NSMenuItem * menuItem = (NSMenuItem *)sender;
		pluginItem = menuItem.representedObject;
	}
	
	if (pluginItem != nil)
	{
		// This is a link plugin. There should be a URL field which we invoke and possibly
		// placeholders to be filled from the current article or website.

		NSString * itemType = pluginItem[@"Type"];
		if ([itemType isEqualToString:@"Link"])
		{
			NSMutableString * urlString  = [NSMutableString stringWithString:pluginItem[@"URL"]];
			if (urlString == nil)
				return;
			
			// Get the view that the user is currently looking at...
			NSView<BaseView> * theView = [[APPCONTROLLER browserView] activeTabItemView];
			
			// ...and do the following in case the user is currently looking at a website.
			if ([theView isKindOfClass:[BrowserPane class]])
			{	
				[urlString replaceString:@"$ArticleTitle$" withString:[theView viewTitle]];
				
				// If ShortenURLs is true in the plugin's info.plist, we attempt to shorten it via the bit.ly service.
				if ([pluginItem[@"ShortenURLs"] boolValue])
				{
					BitlyAPIHelper * bitlyHelper = [[BitlyAPIHelper alloc] initWithLogin:@"viennarss" andAPIKey:@"R_852929122e82d2af45fe9e238f1012d3"];
					NSString * shortURL = [bitlyHelper shortenURL:[theView viewLink]];
					
					[urlString replaceString:@"$ArticleLink$" withString:shortURL];
				}
				else 
				{
					[urlString replaceString:@"$ArticleLink$" withString:[[theView viewLink] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
				}

			}
			
			// In case the user is currently looking at an article:
			else
			{
				// We can only work on one article, so ignore selection range.
				Article * currentMessage = [APPCONTROLLER selectedArticle];
				[urlString replaceString:@"$ArticleTitle$" withString: [currentMessage title]];
				
				// URL shortening again, as above...
				if ([pluginItem[@"ShortenURLs"] boolValue])
				{
					BitlyAPIHelper * bitlyHelper = [[BitlyAPIHelper alloc] initWithLogin:@"viennarss" andAPIKey:@"R_852929122e82d2af45fe9e238f1012d3"];
					NSString * shortURL = [bitlyHelper shortenURL:[currentMessage link]];
					
					// If URL shortening fails, we fall back to the long URL.
					[urlString replaceString:@"$ArticleLink$" withString:(shortURL ? shortURL : [[[currentMessage link] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding])];
				}
				else 
				{
					[urlString replaceString:@"$ArticleLink$" withString: [[[currentMessage link] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
				}
			}
						
			if (urlString != nil)
			{
				NSURL * urlToLoad = cleanedUpAndEscapedUrlFromString(urlString);				
				if (urlToLoad != nil)
					[APPCONTROLLER createNewTab:urlToLoad inBackground:NO];
			}
			else
			{
				// TODO: Implement real error-handling. Don't know how to go about it, yet.
				NSBeep();
				NSLog(@"Creation of the sharing URL failed!");
			}
		}
		
		else if ([itemType isEqualToString:@"Script"])
		{
			// This is a script plugin. There should be a Script field which specifies the
			// filename of the script file in the same folder.
			NSString * pluginPath = pluginItem[@"Path"];
			NSString * scriptFile = [pluginPath stringByAppendingPathComponent:pluginItem[@"Script"]];
			if (scriptFile == nil)
				return;

			// Just run the script
			[APPCONTROLLER runAppleScript:scriptFile];
		}

		else if ([itemType isEqualToString:@"BlogEditor"])
		{
			// This is a blog-editor plugin. Simply send the info to the application.
			[APPCONTROLLER blogWithExternalEditor:pluginItem[@"BundleIdentifier"]];
		}
	}
}

/* dealloc
 * Clean up after ourselves.
 */
-(void)dealloc
{
	allPlugins=nil;
}
@end
