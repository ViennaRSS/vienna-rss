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
#import "ViennaApp.h"
#import "Constants.h"

@interface NSObject (TabbedWebViewDelegate)
	-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger)flags;
@end

@interface TabbedWebView ()

+(NSArray *)acceptedSchemes;
+(NSArray *)downloadableExtensions;
-(BOOL)isDownloadFileType:(NSURL *)filename;
-(void)loadMinimumFontSize;
-(void)handleMinimumFontSizeChange:(NSNotification *)nc;

@end

static NSString * _userAgent ;

@implementation TabbedWebView

+(NSString *)userAgent
{
    if (!_userAgent) {
        NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
        NSString *osVersion = [NSString stringWithFormat:@"%ld_%ld_%ld", version.majorVersion, version.minorVersion, version.patchVersion];
        NSString *webkitVersion = [NSBundle bundleWithIdentifier:@"com.apple.WebKit"].infoDictionary[@"CFBundleVersion"];
        if (!webkitVersion) {
            webkitVersion = @"536.30";
        }
        NSString *shortSafariVersion = [NSBundle bundleWithPath:@"/Applications/Safari.app"].infoDictionary[@"CFBundleShortVersionString"];
        if (!shortSafariVersion) {
            shortSafariVersion = @"6.0";
        }
        _userAgent =
            [NSString stringWithFormat:MA_BrowserUserAgentString, osVersion, webkitVersion, shortSafariVersion,
             ((ViennaApp *)NSApp).applicationVersion.firstWord];
    }
    return _userAgent;
}

/* acceptedSchemes
 * schemes listener objects are able to handle directly
 */
+(NSArray *)acceptedSchemes
{
    return @[@"http", @"https", @"feed", @"file", @"data", @"applewebdata", @"about"];
}

/* downloadableExtensions
 * file extensions which are deemed to be downloaded
 */
+(NSArray *)downloadableExtensions
{
    return @[@"dmg",  @"zip", @"gz", @"tgz", @"7z", @"rar", @"tar", @"bin", @"bz2", @"exe", @"sit", @"sitx"];
}

+(WebPreferences *)defaultWebPrefs
{
    // Singleton
    static WebPreferences * _webPrefs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _webPrefs = [[WebPreferences alloc] initWithIdentifier:@"VNAStandardWebPrefs"];
        // Make web preferences 16pt Arial to match Safari
        _webPrefs.standardFontFamily = @"Arial";
        _webPrefs.defaultFontSize = 16;
        _webPrefs.privateBrowsingEnabled = NO;
    });
    return _webPrefs;
}

+(WebPreferences *)withJavaScriptWebPrefs
{
    // Singleton
    static WebPreferences * _webPrefs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _webPrefs = [[WebPreferences alloc] initWithIdentifier:@"VNAForceJavaScriptWebPrefs"];
        _webPrefs.standardFontFamily = @"Arial";
        _webPrefs.defaultFontSize = 16;
        _webPrefs.privateBrowsingEnabled = NO;
        _webPrefs.javaScriptEnabled = YES;
    });
    return _webPrefs;
}

+(WebPreferences *)passiveWebPrefs
{
    // Singleton
    static WebPreferences * _webPrefs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _webPrefs = [[WebPreferences alloc] initWithIdentifier:@"VNAPassiveWebPrefs"];
        _webPrefs.standardFontFamily = @"Arial";
        _webPrefs.defaultFontSize = 16;
        _webPrefs.privateBrowsingEnabled = NO;
        _webPrefs.javaScriptEnabled = NO;
        _webPrefs.plugInsEnabled = NO;
    });
    return _webPrefs;
}

/* initWithFrame
 * The designated instance initialiser.
 */
-(instancetype)initWithFrame:(NSRect)frameRect frameName:(NSString *)frameName groupName:(NSString *)groupName
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
	openLinksInNewBrowser = NO;
	isFeedRedirect = NO;
	isDownload = NO;
		
	// Set a host window so that plugins can keep active while not in the front-most tab.
	self.hostWindow = NSApp.mainWindow;
	
	// We'll be the webview policy handler.
	self.policyDelegate = self;
	self.downloadDelegate = [DownloadManager sharedInstance];
	
	// Set up to be notified of changes
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleMinimumFontSizeChange:)
               name:kMA_Notify_MinimumFontSizeChange object:nil];
	[nc addObserver:self selector:@selector(handleUseJavaScriptChange:)
               name:kMA_Notify_UseJavaScriptChange object:nil];
    [nc addObserver:self selector:@selector(handleUseWebPluginsChange:)
               name:kMA_Notify_UseWebPluginsChange object:nil];
	
    // handle UserAgent
    self.customUserAgent = [TabbedWebView userAgent];
	// Handle minimum font size, use of JavaScript, and use of plugins
	self.preferences = [TabbedWebView defaultWebPrefs];
	[self loadMinimumFontSize];
	[self loadUseJavaScript];
    [self loadUseWebPlugins];
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
	NSString * newURLExtension = url.path.pathExtension;
	return ([[TabbedWebView downloadableExtensions] containsObject:newURLExtension]);
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
		NSScanner * scanner = [NSScanner scannerWithString:request.URL.absoluteString];
		[scanner scanString:@"http://" intoString:nil];
		[scanner scanString:@"https://" intoString:nil];
		[scanner scanString:@"feed://" intoString:nil];
		
		NSString * linkPath;
		[scanner scanUpToString:@"" intoString:&linkPath];

		// Indicate a redirect for a feed
		[self setIsFeedRedirect:YES];

        [APPCONTROLLER openURLInDefaultBrowser:[NSURL URLWithString:[NSString stringWithFormat:@"feed://%@", linkPath]]];
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
	NSInteger navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] integerValue];
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
		NSUInteger  modifierFlag = [[actionInformation valueForKey:WebActionModifierFlagsKey] unsignedIntegerValue];
        BOOL useAlternateBrowser = (modifierFlag & NSEventModifierFlagOption) ? YES : NO; // This is to avoid problems in casting the value into BOOL
		[listener ignore];
		[APPCONTROLLER openURL:request.URL inPreferredBrowser:!useAlternateBrowser];
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
	NSInteger navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] integerValue];
	NSString * scheme = request.URL.scheme.lowercaseString;
	if (navType == WebNavigationTypeLinkClicked)
	{
		if ([scheme isEqualToString:@"file"] && [request.URL.resourceSpecifier hasPrefix:@"/#"])
		// clicked a link to an anchor in the same webview
		{
			[listener use];
			return;
		}
	    NSUInteger modifierFlags = [[actionInformation valueForKey:WebActionModifierFlagsKey] unsignedIntegerValue];
        BOOL useAlternateBrowser = (modifierFlags & NSEventModifierFlagOption) ? YES : NO; // This is to avoid problems in casting the value into BOOL
        if (openLinksInNewBrowser || (modifierFlags & NSEventModifierFlagCommand))
		{
			[listener ignore];
			[APPCONTROLLER openURL:request.URL inPreferredBrowser:!useAlternateBrowser];
			return;
		}
		else
		{
			Preferences * prefs = [Preferences standardPreferences];
			if (prefs.openLinksInVienna == useAlternateBrowser)
			{
				[listener ignore];
				[APPCONTROLLER openURLInDefaultBrowser:request.URL];
				return;
			}
		}
	}
	if (scheme == nil || [[TabbedWebView acceptedSchemes] containsObject:scheme])
	{
		[listener use];
	}
	else
	{
		[listener ignore];
		[[NSWorkspace sharedWorkspace] openURL:request.URL];
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

/* handleUseWebPluginsChange
 * Called when the user changes the 'Use Javascript' setting.
 */
-(void)handleUseWebPluginsChange:(NSNotification *)nc
{
    [self loadUseWebPlugins];
}

/* loadMinimumFontSize
 * Sets up the web preferences for a minimum font size.
 */
-(void)loadMinimumFontSize
{
	Preferences * prefs = [Preferences standardPreferences];
	if (!prefs.enableMinimumFontSize)
		[TabbedWebView defaultWebPrefs].minimumFontSize = [TabbedWebView passiveWebPrefs].minimumFontSize = [TabbedWebView withJavaScriptWebPrefs].minimumFontSize= 1;
	else
	{
		NSInteger size = prefs.minimumFontSize;
		[TabbedWebView defaultWebPrefs].minimumFontSize = [TabbedWebView passiveWebPrefs].minimumFontSize = [TabbedWebView withJavaScriptWebPrefs].minimumFontSize = (int)size;
	}
}

/* scrollToBottom
 * Scrolls to the bottom of the TabbedWebView.
 */
-(void)scrollToBottom
{
    NSPoint newScrollOrigin;
	NSScrollView * myScrollView;
	
	myScrollView = self.mainFrame.frameView.documentView.enclosingScrollView;
	
    if ((myScrollView.documentView).flipped) 
        newScrollOrigin = NSMakePoint(0.0,NSMaxY((myScrollView.documentView).frame)-NSHeight(myScrollView.contentView.bounds));
	else 
		newScrollOrigin = NSMakePoint(0.0,0.0);
	
    [myScrollView.documentView scrollPoint: newScrollOrigin];	

    if (myScrollView.verticalScroller.knobProportion < 0.05)
    	myScrollView.verticalScroller.knobProportion = 0.05;
}

/* scrollToTop
 * Scrolls to the top of the TabbedWebView.
 */
-(void)scrollToTop
{
	// nothing different from scrollToBottom
	[self scrollToBottom];
}

/* loadUseJavaScript
 * Sets up the web preferences for using JavaScript.
 */
-(void)loadUseJavaScript
{
	Preferences * prefs = [Preferences standardPreferences];
	[TabbedWebView defaultWebPrefs].javaScriptEnabled = prefs.useJavaScript;
}

/* loadUseWebPlugins
 * Sets up the web preferences for using WebPlugins.
 */
-(void)loadUseWebPlugins
{
    Preferences * prefs = [Preferences standardPreferences];
    [TabbedWebView defaultWebPrefs].plugInsEnabled = prefs.useWebPlugins;
}

/* abortJavascriptAndPlugIns
 * Sets up the web preferences to stop JavaScript and WebPlugins
 */
-(void)abortJavascriptAndPlugIns
{
    self.preferences = [TabbedWebView passiveWebPrefs];
}

/* useUserPrefsForJavascriptAndPlugIns
 * Sets up the web preferences to use JavaScript and WebPlugins as defined by user preferences
 */
-(void)useUserPrefsForJavascriptAndPlugIns
{
    self.preferences = [TabbedWebView defaultWebPrefs];
}

/* forceJavascript
 * Sets up the web preferences to use JavaScript (without WebPlugins)
 */
-(void)forceJavascript
{
    self.preferences = [TabbedWebView withJavaScriptWebPrefs];
}

/* keyDown
 * Here is where we handle special keys when the broswer view
 * has the focus so we can do custom things.
 */
-(void)keyDown:(NSEvent *)theEvent
{
	if (theEvent.characters.length == 1)
	{
		unichar keyChar = [theEvent.characters characterAtIndex:0];
        if ((keyChar == NSLeftArrowFunctionKey) && (theEvent.modifierFlags & NSEventModifierFlagCommand))
		{
			[self goBack:self];
			return;
		}
        else if ((keyChar == NSRightArrowFunctionKey) && (theEvent.modifierFlags & NSEventModifierFlagCommand))
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
	NSView * printView = self.mainFrame.frameView.documentView;
	NSPrintInfo * printInfo = [NSPrintInfo sharedPrintInfo];
	
	NSMutableDictionary * dict = [printInfo dictionary];
	dict[NSPrintLeftMargin] = @36.0;
	dict[NSPrintRightMargin] = @36.0;
	dict[NSPrintTopMargin] = @36.0;
	dict[NSPrintBottomMargin] = @36.0;
	
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
	[self setHostWindow:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self setPolicyDelegate:nil];
	[self setDownloadDelegate:nil];
	[self removeFromSuperviewWithoutNeedingDisplay];
}
@end
