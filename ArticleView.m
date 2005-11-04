//
//  ArticleView.m
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

#import "ArticleView.h"
#import "AppController.h"
#import "Preferences.h"
#import "DownloadManager.h"
#import "WebKit/WebFrame.h"
#import "WebKit/WebPreferences.h"
#import "WebKit/WebPolicyDelegate.h"

@interface NSObject (ArticleViewDelegate)
	-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(unsigned int)flags;
@end

@interface ArticleView (Private)
	-(void)initClass;
	-(BOOL)isDownloadFileType:(NSURL *)filename;
	-(void)loadMinimumFontSize;
	-(void)handleMinimumFontSizeChange:(NSNotification *)nc;
@end

@implementation ArticleView

/* initWithFrame
 * The designated instance initialiser.
 */
-(id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		// Init our vars
		controller = nil;
		openLinksInNewTab = NO;
		isFeedRedirect = NO;
		
		// We'll be the webview policy handler.
		[self setPolicyDelegate:self];
		[self setDownloadDelegate:[DownloadManager sharedInstance]];

		// Set up to be notified when minimum font size changes
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleMinimumFontSizeChange:) name:@"MA_Notify_MinimumFontSizeChange" object:nil];
		
		// Handle minimum font size
		defaultWebPrefs = [[self preferences] retain];
		[defaultWebPrefs setStandardFontFamily:@"Arial"];
		[defaultWebPrefs setDefaultFontSize:12];
		[self loadMinimumFontSize];
	}
	return self;
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

/* setOpenLinksInNewTab
 * Specify whether links are opened in a new tab by default.
 */
-(void)setOpenLinksInNewTab:(BOOL)flag
{
	openLinksInNewTab = flag;
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
	NSString * newURLExtension = [[url absoluteString] pathExtension];
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
	
	// Handle extensions that are masquerading as binary files due to a server
	// misconfiguration. Do this before we check the MIME type.
	if ([self isDownloadFileType:[request URL]])
	{
		[listener download];
		return;
	}

	// If this is a viewable MIME type, display it.
	if ([WebView canShowMIMEType:type])
	{
		[listener use];
		return;
	}

	// Anything else, download it.
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

		// For anything else, we open in a new tab.
		[listener ignore];
		[controller openURLInBrowserWithURL:[request URL]];
		return;
	}
	[listener use];
}

/* decidePolicyForNavigationAction
 * Called by the web view to get our policy on handling navigation actions. We want links clicked in the
 * web view to open in the same view unless the "open links in new tab" option is set or the Command key is held
 * down. If either of those cases are true, we open the link in a new tab or in the external browser.
 */
-(void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	int navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] intValue];
	NSNumber * modifierFlags = [actionInformation valueForKey:@"WebActionModifierFlagsKey"];

	if (navType == WebNavigationTypeLinkClicked && (openLinksInNewTab || ([modifierFlags intValue] & NSCommandKeyMask)))
	{
		[listener ignore];
		[controller openURLInBrowserWithURL:[request URL]];
		return;
	}
	[listener use];
}

/* handleMinimumFontSizeChange
 * Called when the minimum font size for articles is enabled or disabled, or changed.
 */
-(void)handleMinimumFontSizeChange:(NSNotification *)nc
{
	[self loadMinimumFontSize];
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

/* keyDown
 * Here is where we handle special keys when the article list view
 * has the focus so we can do custom things.
 */
-(void)keyDown:(NSEvent *)theEvent
{
	if ([[theEvent characters] length] == 1)
	{
		unichar keyChar = [[theEvent characters] characterAtIndex:0];
		if ([[NSApp delegate] handleKeyDown:keyChar withFlags:[theEvent modifierFlags]])
			return;
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

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
	[defaultWebPrefs release];
	[super dealloc];
}
@end
