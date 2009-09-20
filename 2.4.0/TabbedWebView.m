//
//  TabbedWebView.m
//  Vienna
//
//  Created by Steve on Tue Jul 05 2005.
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

#import "TabbedWebView.h"
#import "AppController.h"
#import "Preferences.h"
#import "DownloadManager.h"
#import "StringExtensions.h"

@interface NSObject (TabbedWebViewDelegate)
	-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(unsigned int)flags;
@end

@interface TabbedWebView (Private)
	-(BOOL)isDownloadFileType:(NSURL *)filename;
	-(void)loadMinimumFontSize;
	-(void)handleMinimumFontSizeChange:(NSNotification *)nc;
	-(void)loadUseJavaScript;
	-(void)handleUseJavaScript:(NSNotification *)nc;
@end

@implementation TabbedWebView

/* initWithFrame
 * The designated instance initialiser.
 */
-(id)initWithFrame:(NSRect)frameRect frameName:(NSString *)frameName groupName:(NSString *)groupName
{
	if ((self = [super initWithFrame:frameRect frameName:frameName groupName:groupName]) != nil)
		[self initTabbedWebView];
	return self;
}

/* initTabbedWebView
 * Do the internal web view initialisation.
 */
-(void)initTabbedWebView
{
	// Init our vars
	controller = nil;
	openLinksInNewBrowser = NO;
	isFeedRedirect = NO;
	isDownload = NO;
	
	// We'll be the webview policy handler.
	[self setPolicyDelegate:self];
	[self setDownloadDelegate:[DownloadManager sharedInstance]];
	
	// Set up to be notified of changes
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleMinimumFontSizeChange:) name:@"MA_Notify_MinimumFontSizeChange" object:nil];
	[nc addObserver:self selector:@selector(handleUseJavaScriptChange:) name:@"MA_Notify_UseJavaScriptChange" object:nil];
	
	// Handle minimum font size & using of JavaScript
	defaultWebPrefs = [[self preferences] retain];
	[defaultWebPrefs setStandardFontFamily:@"Arial"];
	[defaultWebPrefs setDefaultFontSize:12];
	[defaultWebPrefs setPrivateBrowsingEnabled:YES];
	[defaultWebPrefs setJavaScriptEnabled:NO];
	[self loadMinimumFontSize];
	[self loadUseJavaScript];
}

/* setController
 * Set the associated controller for this view
 */
-(void)setController:(AppController *)theController
{
	[theController retain];
	[controller release];
	controller = theController;
	[self setPolicyDelegate:self];
}

/* setOpenLinksInNewBrowser
 * Specify whether links are opened in a new browser by default.
 */
-(void)setOpenLinksInNewBrowser:(BOOL)flag
{
	openLinksInNewBrowser = flag;
}

/* setIsDownload
 * Specifies whether the current load is a file download.
 */
-(void)setIsDownload:(BOOL)flag
{
	isDownload = flag;
}

/* isDownload
 * Returns whether the current load is a file download.
 */
-(BOOL)isDownload
{
	return isDownload;
}

/* setIsFeedRedirect
 * Indicates that the current load has been redirected to a feed URL.
 */
-(void)setIsFeedRedirect:(BOOL)flag
{
	isFeedRedirect = flag;
}

/* isFeedRedirect
 * Specifies whether the current load was a redirect to a feed URL.
 */
-(BOOL)isFeedRedirect
{
	return isFeedRedirect;
}

/* isDownloadFileType
 * Given a URL, returns whether the URL represents a file that should be downloaded or
 * a link that should be displayed.
 */
-(BOOL)isDownloadFileType:(NSURL *)url
{
	NSString * newURLExtension = [[url path] pathExtension];
	return ([newURLExtension isEqualToString:@"dmg"] ||
			[newURLExtension isEqualToString:@"sit"] ||
			[newURLExtension isEqualToString:@"bin"] ||
			[newURLExtension isEqualToString:@"bz2"] ||
			[newURLExtension isEqualToString:@"exe"] ||
			[newURLExtension isEqualToString:@"sitx"] ||
			[newURLExtension isEqualToString:@"zip"] ||
			[newURLExtension isEqualToString:@"gz"] ||
			[newURLExtension isEqualToString:@"tar"]);
}

/* decidePolicyForMIMEType
 * Handle clicks on RSS/Atom feed links and redirect to the appropriate feed handler instead of filling the
 * webview with XML strings.
 */
-(void)webView:(WebView *)sender decidePolicyForMIMEType:(NSString *)type request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	if ([type isEqualToString:@"application/rss+xml"] || [type isEqualToString:@"application/atom+xml"])
	{
		// Convert the link to a feed:// link so that the system will redirect it to the
		// appropriate handler. (We can't assume that we're the registered handler and it is
		// too much work for us to figure it out when the system can do it easily enough).
		NSScanner * scanner = [NSScanner scannerWithString:[[request URL] absoluteString]];
		[scanner scanString:@"http://" intoString:nil];
		[scanner scanString:@"https://" intoString:nil];
		[scanner scanString:@"feed://" intoString:nil];
		
		NSString * linkPath;
		[scanner scanUpToString:@"" intoString:&linkPath];

		// Indicate a redirect for a feed
		[self setIsFeedRedirect:YES];

		[controller openURLInDefaultBrowser:[NSURL URLWithString:[NSString stringWithFormat:@"feed://%@", linkPath]]];
		[listener ignore];
		return;
	}

	// Anything else is not a feed redirect.
	[self setIsFeedRedirect:NO];
	
	// If this is a viewable MIME type, display it.
	if ([WebView canShowMIMEType:type])
	{
		[listener use];
		return;
	}

	// Anything else, download it.
	[self setIsDownload:YES];
	[listener download];
}

/* decidePolicyForNewWindowAction
 * Called by the web view to get our policy on handling actions that would open a new window.
 */
-(void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
	int navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] intValue];
	if (navType == WebNavigationTypeLinkClicked)
	{
		NSDictionary * webElementKey = [actionInformation valueForKey:@"WebActionElementKey"];
		NSURL * newURL = [webElementKey valueForKey:@"WebElementLinkURL"];

		// This is kind of a hack. We look at the extension and try to infer whether we should display
		// in a new tab or download based on the extension. Part of the time we'll get it wrong but the
		// worst that will happen is that we'll look at the MIME type later in decidePolicyForMIMEType and
		// do the right thing there. By then we'll have opened a new tab or a blank browser window though.
		if ([self isDownloadFileType:newURL])
		{
			[listener download];
			return;
		}

		// For anything else, we open in a new tab or in the external browser.
		unsigned int modifierFlag = [[actionInformation valueForKey:WebActionModifierFlagsKey] unsignedIntValue];
		BOOL useAlternateBrowser = (modifierFlag & NSAlternateKeyMask) ? YES : NO; // This is to avoid problems in casting the value into BOOL
		[listener ignore];
		[controller openURL:[request URL] inPreferredBrowser:!useAlternateBrowser];
		return;
	}
	[listener use];
}

/* decidePolicyForNavigationAction
 * Called by the web view to get our policy on handling navigation actions. We want links clicked in the
 * web view to open in the same view unless the "open links in new browser" option is set or the Command key is held
 * down. If either of those cases are true, we open the link in a new tab or in the external browser.
 */
-(void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	int navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] intValue];
	unsigned int modifierFlags = [[actionInformation valueForKey:WebActionModifierFlagsKey] unsignedIntValue];
	BOOL useAlternateBrowser = (modifierFlags & NSAlternateKeyMask) ? YES : NO; // This is to avoid problems in casting the value into BOOL
	
	if (navType == WebNavigationTypeLinkClicked)
	{
		if (openLinksInNewBrowser || (modifierFlags & NSCommandKeyMask))
		{
			[listener ignore];
			[controller openURL:[request URL] inPreferredBrowser:!useAlternateBrowser];
			return;
		}
		else
		{
			Preferences * prefs = [Preferences standardPreferences];
			if ([prefs openLinksInVienna] == useAlternateBrowser)
			{
				[listener ignore];
				[controller openURLInDefaultBrowser:[request URL]];
				return;
			}
		}
	}
	NSString * scheme = [[[request URL] scheme] lowercaseString];
	if (scheme == nil || [scheme isEqualToString:@""] || [scheme isEqualToString:@"applewebdata"] || [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"] || [scheme isEqualToString:@"feed"] || [scheme isEqualToString:@"file"])
	{
		[listener use];
	}
	else
	{
		[listener ignore];
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
	}
}

/* handleMinimumFontSizeChange
 * Called when the minimum font size for articles is enabled or disabled, or changed.
 */
-(void)handleMinimumFontSizeChange:(NSNotification *)nc
{
	[self loadMinimumFontSize];
}

/* handleUseJavaScriptChange
 * Called when the user changes the 'Use Javascript' setting.
 */
-(void)handleUseJavaScriptChange:(NSNotification *)nc
{
	[self loadUseJavaScript];
}

/* loadMinimumFontSize
 * Sets up the web preferences for a minimum font size.
 */
-(void)loadMinimumFontSize
{
	Preferences * prefs = [Preferences standardPreferences];
	if (![prefs enableMinimumFontSize])
		[defaultWebPrefs setMinimumFontSize:1];
	else
	{
		int size = [prefs minimumFontSize];
		[defaultWebPrefs setMinimumFontSize:size];
	}
}

/* loadUseJavaScript
 * Sets up the web preferences for using JavaScript.
 */
-(void)loadUseJavaScript
{
	Preferences * prefs = [Preferences standardPreferences];
	[defaultWebPrefs setJavaScriptEnabled:[prefs useJavaScript]];
}

/* keyDown
 * Here is where we handle special keys when the broswer view
 * has the focus so we can do custom things.
 */
-(void)keyDown:(NSEvent *)theEvent
{
	if ([[theEvent characters] length] == 1)
	{
		unichar keyChar = [[theEvent characters] characterAtIndex:0];
		if ((keyChar == NSLeftArrowFunctionKey) && ([theEvent modifierFlags] & NSCommandKeyMask))
		{
			[self goBack:self];
			return;
		}
		else if ((keyChar == NSRightArrowFunctionKey) && ([theEvent modifierFlags] & NSCommandKeyMask))
		{
			[self goForward:self];
			return;
		}
	}
	[super keyDown:theEvent];
}

/* printDocument
 * Print the active article.
 */
-(void)printDocument:(id)sender
{
	NSView * printView = [[[self mainFrame] frameView] documentView];
	NSPrintInfo * printInfo = [NSPrintInfo sharedPrintInfo];
	
	NSMutableDictionary * dict = [printInfo dictionary];
	[dict setObject:[NSNumber numberWithFloat:36.0f] forKey:NSPrintLeftMargin];
	[dict setObject:[NSNumber numberWithFloat:36.0f] forKey:NSPrintRightMargin];
	[dict setObject:[NSNumber numberWithFloat:36.0f] forKey:NSPrintTopMargin];
	[dict setObject:[NSNumber numberWithFloat:36.0f] forKey:NSPrintBottomMargin];
	
	[printInfo setVerticallyCentered:NO];
	[printView print:self];
}

/* maintainsInactiveSelection
 * Override WebView method to return YES.
 * This emulates the Safari behavior of maintaining the selection (e.g., text field) when switching back an forth from a tab.
 */
-(BOOL) maintainsInactiveSelection
{
	return YES;
}

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self setPolicyDelegate:nil];
	[self setDownloadDelegate:nil];
	[controller release];
	[defaultWebPrefs release];
	[super dealloc];
}
@end
