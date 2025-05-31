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

#import "ActionPlugin.h"
#import "AppController.h"
#import "Article.h"
#import "BlogEditorPlugin.h"
#import "FeedSourcePlugin.h"
#import "HelperFunctions.h"
#import "LinkPlugin.h"
#import "NSFileManager+Paths.h"
#import "Plugin.h"
#import "ScriptPlugin.h"
#import "SearchMethod.h"
#import "SearchPlugin.h"
#import "StringExtensions.h"
#import "SyncServerPlugin.h"
#import "Vienna-Swift.h"

NSString * const VNAPluginBundleExtension = @"viennaplugin";

static NSString * const VNAPluginsDirectoryName = @"Plugins";

@implementation PluginManager {
    NSMutableArray *allPlugins;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        allPlugins = [NSMutableArray new];
    }
    return self;
}

+ (NSURL *)pluginsDirectoryURL
{
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *appSupportURL = fileManager.vna_applicationSupportDirectory;
    NSString *pathComponent = VNAPluginsDirectoryName;
    return [appSupportURL URLByAppendingPathComponent:pathComponent
                                          isDirectory:YES];
}

+ (NSArray<Class> *)pluginTypes
{
    static NSArray *pluginTypes;
    if (!pluginTypes) {
        pluginTypes = @[
            [VNABlogEditorPlugin class],
            [VNAFeedSourcePlugin class],
            [VNALinkPlugin class],
            [VNAScriptPlugin class],
            [VNASearchPlugin class],
            [VNASyncServerPlugin class],
        ];
    }
    return pluginTypes;
}

- (void)resetPlugins
{
	[allPlugins removeAllObjects];

	NSMutableDictionary *pluginPaths = [NSMutableDictionary dictionary];

	NSString *path = [NSBundle.mainBundle.sharedSupportPath stringByAppendingPathComponent:VNAPluginsDirectoryName];
	loadMapFromPath(path, pluginPaths, YES, nil);

	path = PluginManager.pluginsDirectoryURL.path;
	loadMapFromPath(path, pluginPaths, YES, nil);

	for (NSString *pluginName in pluginPaths) {
		NSString *pluginPath = pluginPaths[pluginName];
		[self loadPlugin:pluginPath];
	}

    [allPlugins sortUsingDescriptors:@[
        [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(displayName))
                                      ascending:YES
                                       selector:@selector(localizedCaseInsensitiveCompare:)]
    ]];
}

- (void)loadPlugin:(NSString *)pluginPath
{
    VNAPlugin *plugin;
    NSBundle *bundle = [NSBundle bundleWithPath:pluginPath];
    for (Class pluginType in PluginManager.pluginTypes) {
        if (![pluginType canInitWithBundle:bundle]) {
            continue;
        }

        plugin = [[pluginType alloc] initWithBundle:bundle];
        break;
    }

    if (plugin) {
        [self willChangeValueForKey:NSStringFromSelector(@selector(numberOfPlugins))];
        [allPlugins addObject:plugin];
        [self didChangeValueForKey:NSStringFromSelector(@selector(numberOfPlugins))];
    } else {
        NSLog(@"Missing or corrupt info.plist in %@", pluginPath);
    }
}

- (NSUInteger)numberOfPlugins
{
    return allPlugins.count;
}

- (NSArray<NSMenuItem *> *)menuItems {
    NSMutableArray<NSMenuItem *> *plugins = [NSMutableArray array];

    for (VNAPlugin *plugin in allPlugins) {
        if (![plugin isKindOfClass:[VNAActionPlugin class]]) {
            continue;
        }
        VNAActionPlugin *actionPlugin = (VNAActionPlugin *)plugin;

        // If it's a blog editor plugin, don't show it in the menu
        // if the app in question is not present on the system.
        if ([plugin isKindOfClass:[VNABlogEditorPlugin class]]) {
            VNABlogEditorPlugin *blogEditorPlugin = (VNABlogEditorPlugin *)plugin;
            NSString *bundleIdentifier = blogEditorPlugin.targetBundleIdentifier;

            if (![NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:bundleIdentifier]) {
                continue;
            }
        }

        // Parse off the shortcut key, if there is one. The format is a series of
        // control key specifiers: Cmd, Shift, Alt or Ctrl - specified in any
        // order and separated by '+', plus a single key character. If more than
        // one key character is given, the last one is used but generally that is
        // a bug in the MenuKey.
        NSString *menuItemKeyEquivalent = actionPlugin.menuItemKeyEquivalent;
        NSUInteger keyMod = 0;
        NSString * keyChar = @"";

        if (menuItemKeyEquivalent) {
            NSArray *keyArray = [menuItemKeyEquivalent componentsSeparatedByString:@"+"];
            NSString * oneKey;

            for (oneKey in keyArray) {
                if ([oneKey isEqualToString:@"Cmd"]) {
                    keyMod |= NSEventModifierFlagCommand;
                } else if ([oneKey isEqualToString:@"Shift"]) {
                    keyMod |= NSEventModifierFlagShift;
                } else if ([oneKey isEqualToString:@"Alt"]) {
                    keyMod |= NSEventModifierFlagOption;
                } else if ([oneKey isEqualToString:@"Ctrl"]) {
                    keyMod |= NSEventModifierFlagControl;
                } else {
                    if (!keyChar.vna_isBlank) {
                        NSLog(@"Warning: malformed MenuKey found in info.plist for plugin %@", plugin.identifier);
                    }
                    keyChar = oneKey;
                }
            }
        }

        // Finally add the plugin to the end of the selected menu complete with
        // key equivalent and save the plugin object in the NSMenuItem so that we
        // can associate it in pluginInvocator.
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:actionPlugin.menuItemTitle
                                                          action:@selector(pluginInvocator:)
                                                   keyEquivalent:keyChar];
        menuItem.target = self;
        menuItem.keyEquivalentModifierMask = keyMod;
        menuItem.representedObject = plugin;
        [plugins addObject:menuItem];
    }

    // Sort the menu items alphabetically.
    [plugins sortUsingDescriptors:@[
        [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(title))
                                      ascending:YES
                                       selector:@selector(localizedCaseInsensitiveCompare:)]]];

    return [plugins copy];
}

/* searchMethods
 * Returns an NSArray of SearchMethods which can be added to the search-box menu.
 */
-(NSArray *)searchMethods
{
	NSMutableArray * searchMethods = [NSMutableArray arrayWithCapacity:allPlugins.count];
	for (VNAPlugin* plugin in allPlugins) {
		if ([plugin isKindOfClass:[VNASearchPlugin class]]) {
			VNASearchPlugin *searchPlugin = (VNASearchPlugin *)plugin;
			SearchMethod *method = [[SearchMethod alloc] initWithDisplayName:searchPlugin.displayName
																 queryString:searchPlugin.queryString];
			[searchMethods addObject:method];
		}
	}
	return [searchMethods copy];
}	

/* toolbarItems
 * Returns an NSArray of names of any plugins which can be added to the toolbar.
 */
-(NSArray *)toolbarItems
{
	NSMutableArray * toolbarKeys = [NSMutableArray arrayWithCapacity:allPlugins.count];
	for (VNAPlugin *plugin in allPlugins) {
		if ([plugin isKindOfClass:[VNAActionPlugin class]]) {
			[toolbarKeys addObject:plugin.identifier];
		}
	}
	return [toolbarKeys copy];
}

/* defaultToolbarItems
 * Returns an NSArray of names of any plugins which should be on the default toolbar.
 */
-(NSArray *)defaultToolbarItems
{
	NSMutableArray * newArray = [NSMutableArray arrayWithCapacity:allPlugins.count];
	for (VNAPlugin *plugin in allPlugins) {
		if ([plugin isKindOfClass:[VNAActionPlugin class]]) {
			VNAActionPlugin *actionPlugin = (VNAActionPlugin *)plugin;
			if (actionPlugin.isDefaultToolbarItem) {
				[newArray addObject:actionPlugin.identifier];
			}
		}
	}
	return [newArray copy];
}

- (nullable VNAActionPlugin *)actionPluginWithIdentifier:(NSString *)identifier
{
    for (VNAPlugin *plugin in allPlugins) {
        if ([plugin isKindOfClass:[VNAActionPlugin class]] &&
            [plugin.identifier isEqualToString:identifier]) {
            return (VNAActionPlugin *)plugin;
        }
    }
    return nil;
}

/* toolbarItem
 * Defines handling the label and appearance of all plugin buttons.
 */
-(NSToolbarItem *)toolbarItemForIdentifier:(NSString *)itemIdentifier
{
    VNAActionPlugin *plugin = [self actionPluginWithIdentifier:itemIdentifier];
    if (!plugin) {
        return nil;
    }

    VNAPlugInToolbarItem *item = [[VNAPlugInToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    item.label = plugin.displayName;
    item.paletteLabel = item.label;
    item.image = plugin.toolbarItemImage;
    item.target = self;
    item.action = @selector(pluginInvocator:);
    item.toolTip = plugin.toolbarItemToolTip;
    item.menuFormRepresentation.representedObject = plugin;
    return item;
}

- (NSArray<VNAPlugin *> *)pluginsOfType:(Class)pluginType
{
    NSMutableArray *plugins = [NSMutableArray array];
    for (VNAPlugin *plugin in allPlugins) {
        if ([plugin isMemberOfClass:pluginType]) {
            [plugins addObject:plugin];
        }
    }
    return plugins;
}

/* validateToolbarItem
 * Check [theItem identifier] and return YES if the item is enabled, NO otherwise.
 */
-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    id<Tab> activeBrowserTab = APPCONTROLLER.browser.activeTab;

    if (activeBrowserTab) {
        return ((activeBrowserTab.tabUrl != nil) && NSApp.active);
    } else {
        Article * thisArticle = APPCONTROLLER.selectedArticle;
        return (thisArticle != nil && NSApp.active);
    }
}

/* validateMenuItem
 * Check [theItem identifier] and return YES if the item is enabled, NO otherwise.
 */
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    id<Tab> activeBrowserTab = APPCONTROLLER.browser.activeTab;

    if (activeBrowserTab) {
        return ((activeBrowserTab.tabUrl != nil) && NSApp.active);
    } else {
        Article * thisArticle = APPCONTROLLER.selectedArticle;
        return (thisArticle != nil && NSApp.active);
    }
}

/* pluginInvocator
 * Called when the user issues a command relating to a plugin.
 */
-(IBAction)pluginInvocator:(id)sender
{
    VNAActionPlugin *plugin;
    if ([sender isKindOfClass:[VNAPlugInToolbarItemButton class]]) {
        VNAPlugInToolbarItemButton *button = sender;
        plugin = [self actionPluginWithIdentifier:button.toolbarItem.itemIdentifier];
    } else {
		NSMenuItem * menuItem = (NSMenuItem *)sender;
		plugin = menuItem.representedObject;
	}
	
	if (plugin) {
		// This is a link plugin. There should be a URL field which we invoke and possibly
		// placeholders to be filled from the current article or website.
		if ([plugin isKindOfClass:[VNALinkPlugin class]]) {
			VNALinkPlugin *linkPlugin = (VNALinkPlugin *)plugin;
			NSMutableString *urlString = [linkPlugin.queryString mutableCopy];
            id<Tab> activeBrowserTab = APPCONTROLLER.browser.activeTab;

			// ...and do the following in case the user is currently looking at a website.
			if (activeBrowserTab) {
				[urlString vna_replaceString:@"$ArticleTitle$" withString:activeBrowserTab.title];
				[urlString vna_replaceString:@"$ArticleLink$" withString:[NSString vna_stringByCleaningURLString:activeBrowserTab.tabUrl.absoluteString]];
			// In case the user is currently looking at an article:
			} else {
				// We can only work on one article, so ignore selection range.
				Article * currentMessage = APPCONTROLLER.selectedArticle;
				[urlString vna_replaceString:@"$ArticleTitle$" withString: currentMessage.title];
                [urlString vna_replaceString:@"$ArticleLink$" withString:[NSString vna_stringByCleaningURLString:currentMessage.link]];
			}
						
			if (urlString != nil) {
				NSURL * urlToLoad = cleanedUpUrlFromString(urlString);				
				if (urlToLoad != nil) {
					(void)[APPCONTROLLER.browser createNewTab:urlToLoad inBackground:NO load:true];
				}
			} else {
				// TODO: Implement real error-handling. Don't know how to go about it, yet.
				NSBeep();
				NSLog(@"Creation of the sharing URL failed!");
			}
		} else if ([plugin isKindOfClass:[VNAScriptPlugin class]]) {
			VNAScriptPlugin *scriptPlugin = (VNAScriptPlugin *)plugin;
			// Just run the script
			[APPCONTROLLER runAppleScript:scriptPlugin.scriptFileURL.path];
		} else if ([plugin isKindOfClass:[VNABlogEditorPlugin class]]) {
			VNABlogEditorPlugin *blogEditorPlugin = (VNABlogEditorPlugin *)plugin;
			// This is a blog-editor plugin. Simply send the info to the application.
			[APPCONTROLLER blogWithExternalEditor:blogEditorPlugin.targetBundleIdentifier];
		}
	}
}

@end
