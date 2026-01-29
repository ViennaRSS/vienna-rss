//
//  SubscribeViewController.m
//  Vienna
//
//  Copyright 2004-2005 Steve Palmer, 2024 Eitot
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "SubscribeViewController.h"

#import "AppController.h"
#import "Database.h"
#import "FeedSourcePlugin.h"
#import "PluginManager.h"
#import "Preferences.h"
#import "StringExtensions.h"
#import "SubscriptionModel.h"

static NSStoryboardName const VNAStoryboardNameSubscribe = @"Subscribe";

@interface VNASubscribeViewController ()

@property (weak, nonatomic) NSMenuItem *webPageMenuItem;
@property (weak, nonatomic) NSMenuItem *localFileMenuItem;
@property BOOL openReaderOptionButton;

@end

@implementation VNASubscribeViewController {
    IBOutlet NSTextField *linkTitle;
    IBOutlet NSTextField *feedURL;
    IBOutlet NSPopUpButton *feedSource;
    IBOutlet NSButton *subscribeButton;
    IBOutlet NSButton *siteHomePageButton;
    Database *db;
}

// MARK: Initialization

+ (VNASubscribeViewController *)instantiateFromStoryboard
{
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:VNAStoryboardNameSubscribe
                                                         bundle:NSBundle.mainBundle];
    return [storyboard instantiateInitialController];
}

// MARK: Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSString *webPageMenuItemTitle = NSLocalizedString(@"URL", @"Title of a menu item");
    NSMenuItem *webPageMenuItem = [[NSMenuItem alloc] initWithTitle:webPageMenuItemTitle
                                                             action:NULL
                                                      keyEquivalent:@""];
    webPageMenuItem.representedObject =
        NSLocalizedString(@"Enter URL of RSS feed",
                          @"An instruction that will be shown above a text field.");
    [feedSource.menu addItem:webPageMenuItem];
    self.webPageMenuItem = webPageMenuItem;

    NSString *localFileMenuItemTitle = NSLocalizedString(@"Local file", @"Title of a menu item");
    NSMenuItem *localFileMenuItem = [[NSMenuItem alloc] initWithTitle:localFileMenuItemTitle
                                                               action:NULL
                                                        keyEquivalent:@""];
    localFileMenuItem.representedObject =
        NSLocalizedString(@"Enter the path under your home folder",
                          @"An instruction that will be shown above a text field.");
    [feedSource.menu addItem:localFileMenuItem];
    self.localFileMenuItem = localFileMenuItem;

    PluginManager *pluginManager = APPCONTROLLER.pluginManager;
    NSArray<VNAPlugin *> *plugins = [pluginManager pluginsOfType:[VNAFeedSourcePlugin class]];
    if (plugins.count > 0) {
        [feedSource.menu addItem:[NSMenuItem separatorItem]];
        for (VNAPlugin *plugin in plugins) {
            NSMenuItem *feedMenuItem = [[NSMenuItem alloc] initWithTitle:plugin.displayName
                                                                  action:NULL
                                                           keyEquivalent:@""];
            feedMenuItem.representedObject = plugin;
            [feedSource.menu addItem:feedMenuItem];
        }
    }

    feedURL.delegate = self;
}

- (void)viewWillAppear
{
    [super viewWillAppear];

    // Look on the pasteboard to see if there's an http:// url and, if so, prime the
    // URL field with it. A handy shortcut.
    NSString *candidateURL = self.initialURL.absoluteString;
    BOOL fromClipboard = NO;
    if (!candidateURL) {
        NSData *pboardData = [NSPasteboard.generalPasteboard dataForType:NSPasteboardTypeString];
        if (pboardData) {
            NSString *pasteString =
                [[NSString alloc] initWithData:pboardData
                                      encoding:NSASCIIStringEncoding]
                    .vna_trimmed;
            NSString *lowerCasePasteString = pasteString.lowercaseString;
            if (lowerCasePasteString &&
                ([lowerCasePasteString hasPrefix:@"http://"] ||
                 [lowerCasePasteString hasPrefix:@"https://"] ||
                 [lowerCasePasteString hasPrefix:@"feed://"])) {
                candidateURL = pasteString;
                fromClipboard = YES;
            }
        }
    }
    // Work around (wrong) duplicate schemes
    NSString *lowercaseURL = candidateURL.lowercaseString;
    if ([lowercaseURL hasPrefix:@"feed:http://"] ||
        [lowercaseURL hasPrefix:@"feed:https://"]) {
        candidateURL = [candidateURL substringFromIndex:@"feed:".length];
    }
    // populate the sheet's text field for URL
    if (candidateURL) {
        feedURL.stringValue = candidateURL;
    } else {
        feedURL.stringValue = @"";
    }
    if (fromClipboard) {
        [feedURL selectText:self];
    }

    [self enableSubscribeButton];
    [self setLinkTitle];
    // restore from preferences, if it can be done ; otherwise, uncheck this option
    self.openReaderOptionButton =
        Preferences.standardPreferences.syncOpenReader &&
        Preferences.standardPreferences.prefersOpenReaderNewSubscription;

    [self.view.window makeFirstResponder:feedURL];
}

// MARK: Subscribing

// Handle the URL subscription button.
- (IBAction)doSubscribe:(id)sender
{
    NSString *feedURLString = feedURL.stringValue.vna_trimmed;
    // Replace feed:// with http:// if necessary
    if ([feedURLString hasPrefix:@"feed://"]) {
        feedURLString = [NSString stringWithFormat:@"http://%@",
                                                   [feedURLString substringFromIndex:7]];
    }

    // Format the URL based on the selected feed source.
    NSMenuItem *selectedItem = feedSource.selectedItem;
    NSURL *rssFeedURL = nil;
    if ([selectedItem isEqual:self.webPageMenuItem]) {
        rssFeedURL = [NSURL URLWithString:feedURLString];
    } else if ([selectedItem isEqual:self.localFileMenuItem]) {
        rssFeedURL = [NSURL fileURLWithPath:feedURLString.stringByExpandingTildeInPath];
    } else if ([selectedItem.representedObject isKindOfClass:[VNAFeedSourcePlugin class]]) {
        VNAFeedSourcePlugin *plugin = selectedItem.representedObject;
        NSString *linkTemplate = plugin.queryString;
        if (linkTemplate.length > 0) {
            rssFeedURL = [NSURL URLWithString:[NSString stringWithFormat:linkTemplate,
                                                                         feedURLString]];
        }
    }

    // Validate the subscription, possibly replacing the feedURLString with a real one if
    // it originally pointed to a web page.
    rssFeedURL = [[[SubscriptionModel alloc] init] verifiedFeedURLFromURL:rssFeedURL];
    NSAssert(rssFeedURL, @"No valid URL verified to attempt subscription !");

    // Check if we have already subscribed to this feed by seeing if a folder exists in the db
    if ([db folderFromFeedURL:rssFeedURL.absoluteString]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Error", @"Already subscribed title");
        alert.informativeText = NSLocalizedString(@"You are already subscribed to that feed",
                                                  @"You are already subscribed to that feed");
        [alert runModal];
    }

    // call the controller to create the new subscription
    // or select the existing one if it already exists
    [APPCONTROLLER createSubscriptionInCurrentLocationForUrl:rssFeedURL];

    // Close the window
    [self dismissController:sender];
}

// Called when the user changes the selection in the popup menu.
- (IBAction)doLinkSourceChanged:(id)sender
{
    [self setLinkTitle];
}

// Action called by the Open Reader checkbox
// Memorizes the setting in preferences
- (IBAction)doOpenReaderOption:(id)sender
{
    Preferences.standardPreferences.prefersOpenReaderNewSubscription =
        ([sender state] == NSControlStateValueOn);
}

// Set the text of the label that prompts for the link based on the source
// that the user selected from the popup menu.
- (void)setLinkTitle
{
    NSMenuItem *feedSourceItem = feedSource.selectedItem;
    NSString *linkTitleString = nil;
    BOOL showButton = NO;
    if (feedSourceItem) {
        id representedObject = feedSourceItem.representedObject;
        if ([representedObject isKindOfClass:[NSString class]]) {
            linkTitleString = representedObject;
            showButton = NO;
        } else if ([representedObject isKindOfClass:[VNAFeedSourcePlugin class]]) {
            VNAFeedSourcePlugin *plugin = representedObject;
            linkTitleString = plugin.hintLabel;
            showButton = plugin.homePageURL != nil;
        }
    }
    if (!linkTitleString) {
        linkTitleString = @"Link";
    }
    linkTitle.stringValue = [NSString stringWithFormat:@"%@:", linkTitleString];
    siteHomePageButton.hidden = !showButton;
}

- (IBAction)doShowSiteHomePage:(id)sender
{
    id representedObject = feedSource.selectedItem.representedObject;
    if ([representedObject isKindOfClass:[VNAFeedSourcePlugin class]]) {
        VNAFeedSourcePlugin *plugin = representedObject;
        [NSWorkspace.sharedWorkspace openURL:plugin.homePageURL];
    }
}

// Enable or disable the Subscribe button depending on whether or not there is a non-blank
// string in the input fields.
- (void)enableSubscribeButton
{
    NSString *feedURLString = feedURL.stringValue;
    subscribeButton.enabled = !feedURLString.vna_isBlank;
}

// MARK: - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)obj
{
    if ([obj.object isEqual:feedURL]) {
        [self enableSubscribeButton];
    }
}

@end
