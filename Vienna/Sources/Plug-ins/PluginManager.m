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
#import "SearchMethod.h"
#import "Browser.h"

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

	path = [Preferences standardPreferences].pluginsFolder;
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
        [self willChangeValueForKey:NSStringFromSelector(@selector(numberOfPlugins))];
		allPlugins[pluginName] = pluginInfo;
        [self didChangeValueForKey:NSStringFromSelector(@selector(numberOfPlugins))];
	}
}

- (NSUInteger)numberOfPlugins {
    return allPlugins.count;
}

- (NSArray<NSMenuItem *> *)menuItems {
    NSMutableArray<NSMenuItem *> *plugins = [NSMutableArray array];

    for (NSDictionary *onePlugin in allPlugins.allValues) {
        // If it's a blog editor plugin, don't show it in the menu
        // if the app in question is not present on the system.
        if ([onePlugin[@"Type"] isEqualToString:@"BlogEditor"])
        {
            NSString * bundleIdentifier = onePlugin[@"BundleIdentifier"];

            if (![[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: bundleIdentifier])
                continue;
        }

        NSString * pluginName = onePlugin[@"Name"];
        NSString * menuPath = onePlugin[@"MenuPath"];
        if (menuPath == nil)
            continue;

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
                    keyMod |= NSEventModifierFlagCommand;
                else if ([oneKey isEqualToString:@"Shift"])
                    keyMod |= NSEventModifierFlagShift;
                else if ([oneKey isEqualToString:@"Alt"])
                    keyMod |= NSEventModifierFlagOption;
                else if ([oneKey isEqualToString:@"Ctrl"])
                    keyMod |= NSEventModifierFlagControl;
                else
                {
                    if (!keyChar.blank)
                        NSLog(@"Warning: malformed MenuKey found in info.plist for plugin %@", pluginName);
                    keyChar = oneKey;
                }
            }
        }

        // Finally add the plugin to the end of the selected menu complete with
        // key equivalent and save the plugin object in the NSMenuItem so that we
        // can associate it in pluginInvocator.
        NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:menuPath action:@selector(pluginInvocator:) keyEquivalent:keyChar];
        menuItem.target = self;
        menuItem.keyEquivalentModifierMask = keyMod;
        menuItem.representedObject = onePlugin;
        [plugins addObject:menuItem];
    }

    // Sort the menu items alphabetically.
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"title"
                                                                 ascending:true
                                                                  selector:@selector(localizedCaseInsensitiveCompare:)];
    [plugins sortUsingDescriptors:@[descriptor]];

    return plugins;
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
-(NSToolbarItem *)toolbarItemForIdentifier:(NSString *)itemIdentifier
{
    NSDictionary *pluginItem = allPlugins[itemIdentifier];
    if (pluginItem) {
        PluginToolbarItem *item = [[PluginToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
		NSString * friendlyName = pluginItem[@"FriendlyName"];
		NSString * tooltip = pluginItem[@"Tooltip"];
        NSString *imagePath = [NSString stringWithFormat:@"%@/%@.tiff", pluginItem[@"Path"], pluginItem[@"ButtonImage"]];

		if (friendlyName == nil)
			friendlyName = itemIdentifier;
		if (tooltip == nil)
			tooltip = friendlyName;
		
        item.label = friendlyName;
        item.paletteLabel = item.label;
        item.image = [[NSImage alloc] initByReferencingFile:imagePath];
        item.target = self;
        item.action = @selector(pluginInvocator:);
		item.toolTip = tooltip;
        item.menuFormRepresentation.representedObject = pluginItem;

        return item;
    } else {
        return nil;
    }
}

/* validateToolbarItem
 * Check [theItem identifier] and return YES if the item is enabled, NO otherwise.
 */
-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    NSView<BaseView> * theView = ((NSView<BaseView> *)APPCONTROLLER.browser.activeTab.view);
    Article * thisArticle = APPCONTROLLER.selectedArticle;

    if ([theView isKindOfClass:[BrowserPane class]])
        return ((theView.viewLink != nil) && NSApp.active);
    else
        return (thisArticle != nil && NSApp.active);
}

/* validateMenuItem
 * Check [theItem identifier] and return YES if the item is enabled, NO otherwise.
 */
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    NSView<BaseView> * theView = ((NSView<BaseView> *)APPCONTROLLER.browser.activeTab.view);
    Article * thisArticle = APPCONTROLLER.selectedArticle;

    if ([theView isKindOfClass:[BrowserPane class]])
        return ((theView.viewLink != nil) && NSApp.active);
    else
        return (thisArticle != nil && NSApp.active);
}

/* pluginInvocator
 * Called when the user issues a command relating to a plugin.
 */
-(IBAction)pluginInvocator:(id)sender
{
	NSDictionary * pluginItem;

    if ([sender isKindOfClass:[PluginToolbarItemButton class]]) {
        PluginToolbarItemButton *button = sender;
        pluginItem = allPlugins[button.toolbarItem.itemIdentifier];
    } else {
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
			NSView<BaseView> * theView = ((NSView<BaseView> *)APPCONTROLLER.browser.activeTab.view);
			
			// ...and do the following in case the user is currently looking at a website.
			if ([theView isKindOfClass:[BrowserPane class]])
			{	
				[urlString replaceString:@"$ArticleTitle$" withString:theView.viewTitle];
				[urlString replaceString:@"$ArticleLink$" withString:[NSString stringByCleaningURLString:theView.viewLink]];
			}
			
			// In case the user is currently looking at an article:
			else
			{
				// We can only work on one article, so ignore selection range.
				Article * currentMessage = APPCONTROLLER.selectedArticle;
				[urlString replaceString:@"$ArticleTitle$" withString: currentMessage.title];
                [urlString replaceString:@"$ArticleLink$" withString:[NSString stringByCleaningURLString:currentMessage.link]];
			}
						
			if (urlString != nil)
			{
				NSURL * urlToLoad = cleanedUpUrlFromString(urlString);				
				if (urlToLoad != nil)
					[APPCONTROLLER.browser createNewTab:urlToLoad inBackground:NO load:true];
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

@end
