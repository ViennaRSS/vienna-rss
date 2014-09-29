//
//  BrowserPane.m
//  Vienna
//
//  Created by Steve on 9/7/05.
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

#import "ViennaApp.h"
#import "BrowserPane.h"
#import "TabbedWebView.h"
#import "Constants.h"
#import "AppController.h"
#import "Preferences.h"
#import "HelperFunctions.h"
#import "StringExtensions.h"
#import "AddressBarCell.h"
#import <WebKit/WebKit.h>
#import "RichXMLParser.h"

@implementation BrowserPaneButtonCell

-(BOOL)isOpaque
{
	return NO;
}

-(NSColor *)highlightColorInView:(NSView *)controlView
{
	return nil;
} 
@end

@implementation BrowserPaneButton

-(BOOL)isOpaque
{
	return NO;
}

+(Class)cellClass
{
	return [BrowserPaneButtonCell class];
}

-(NSColor *)highlightColorInView:(NSView *)controlView
{
	return nil;
} 
@end

@interface BrowserPane (Private)
	-(void)endFrameLoad;
	-(void)showRssPageButton:(BOOL)showButton;
	-(void)setError:(NSError *)newError;
@end

@implementation BrowserPane
@synthesize webPane;

+ (void)load
{
    @autoreleasepool {
        if (self == [BrowserPane class]) {
            //These are synonyms
            [self exposeBinding:@"isLoading"];
            [self exposeBinding:@"isProcessing"];
        }
    }
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
	{
	    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	    
	    if ([key isEqualToString:@"isProcessing"]) {
	        NSSet *affectingKeys = [NSSet setWithObjects:@"isLoading", nil];
	        keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
	    }
	    
	    return keyPaths;
	}

/* initWithFrame
 * Initialise our view.
 */
-(id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
		controller = nil;
		[self willChangeValueForKey:@"isLoading"];
		isLoading = NO;
		[self didChangeValueForKey:@"isLoading"];
		isLocalFile = NO;
		viewTitle = nil;
		openURLInBackground = NO;
		pageFilename = nil;
		lastError = nil;
		rssPageURL = nil;
    }
    return self;
}

/* awakeFromNib
 * Do things that only make sense once the NIB is loaded.
 */
-(void)awakeFromNib
{
	// Create our webview
	[webPane initTabbedWebView];
	[webPane setUIDelegate:self];
	[webPane setFrameLoadDelegate:self];
	NSString * safariVersion = [[[NSBundle bundleWithPath:@"/Applications/Safari.app"] infoDictionary] objectForKey:@"CFBundleVersion"];
	if (safariVersion)
		safariVersion = [safariVersion substringFromIndex:1];
	else
		safariVersion = @"532.22";
	[webPane setApplicationNameForUserAgent:[NSString stringWithFormat:MA_BrowserUserAgentString, [[((ViennaApp *)NSApp) applicationVersion] firstWord], safariVersion]];
	
	// Make web preferences 16pt Arial to match Safari
	[[webPane preferences] setStandardFontFamily:@"Arial"];
	[[webPane preferences] setDefaultFontSize:16];
	
	// Use an AddressBarCell for the address field which allows space for the
	// web page image and an optional lock icon for secure pages.
	AddressBarCell * cell = [[[AddressBarCell alloc] init] autorelease];
	[cell setEditable:YES];
	[cell setDrawsBackground:YES];
	[cell setBordered:YES];
	[cell setBezeled:YES];
	[cell setScrollable:YES];
	[cell setTarget:self];
	[cell setAction:@selector(handleAddress:)];
	[cell setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
	[addressField setCell:cell];

	// Initialise address field
	[addressField setStringValue:@""];

	// The RSS page button is hidden by default
	[self showRssPageButton:NO];

	// Set tooltips
	[addressField setToolTip:NSLocalizedString(@"Enter the URL here", nil)];
	[[addressField cell] accessibilitySetOverrideValue:NSLocalizedString(@"Enter the URL here", nil) forAttribute:NSAccessibilityTitleAttribute];
	[refreshButton setToolTip:NSLocalizedString(@"Refresh the current page", nil)];
	[[refreshButton cell] accessibilitySetOverrideValue:NSLocalizedString(@"Refresh the current page", nil) forAttribute:NSAccessibilityTitleAttribute];
	[backButton setToolTip:NSLocalizedString(@"Return to the previous page", nil)];
	[[backButton cell] accessibilitySetOverrideValue:NSLocalizedString(@"Return to the previous page", nil) forAttribute:NSAccessibilityTitleAttribute];
	[forwardButton setToolTip:NSLocalizedString(@"Go forward to the next page", nil)];
	[[forwardButton cell] accessibilitySetOverrideValue:NSLocalizedString(@"Go forward to the next page", nil) forAttribute:NSAccessibilityTitleAttribute];
	[rssPageButton setToolTip:NSLocalizedString(@"Subscribe to the feed for this page", nil)];
	[[rssPageButton cell] accessibilitySetOverrideValue:NSLocalizedString(@"Subscribe to the feed for this page", nil) forAttribute:NSAccessibilityTitleAttribute];
}

/* setController
 * Sets the controller used by this view.
 */
-(void)setController:(AppController *)theController
{
	controller = theController;
	[self.webPane setController:controller];
}

/* viewLink
 * Return the URL being displayed as a string.
 */
-(NSString *)viewLink
{
	if ([[[self.webPane mainFrame] dataSource] unreachableURL])
		return [[[[self.webPane mainFrame] dataSource] unreachableURL] absoluteString];
	return [[self url] absoluteString];
}

/* showRssPageButton
 * Conditionally show or hide the RSS page button.
 */
-(void)showRssPageButton:(BOOL)showButton
{
	[rssPageButton setEnabled:showButton];
}

/* setError
 * Save the most recent error instance.
 */
-(void)setError:(NSError *)newError
{
	[newError retain];
	[lastError release];
	lastError = newError;
}

/* handleAddress
 * Called when the user hits Enter on the address bar.
 */
-(IBAction)handleAddress:(id)sender
{
	NSString * theURL = [addressField stringValue];
	// If no '.' appears in the string, wrap it with 'www' and 'com'
	if (![theURL hasCharacter:'.']) 
		theURL = [NSString stringWithFormat:@"www.%@.com", theURL];

	// If no schema, prefix http://
	if ([theURL rangeOfString:@"://"].location == NSNotFound)
		theURL = [NSString stringWithFormat:@"http://%@", theURL];

	// cleanUpUrl is a hack to handle Internationalized Domain Names. WebKit handles them automatically, so we tap into that.
	NSURL *urlToLoad = cleanedUpAndEscapedUrlFromString(theURL);
	if (urlToLoad != nil)
		[self loadURL:urlToLoad inBackground:NO];
	else
		[self activateAddressBar];
}

-(void)setViewTitle:(NSString *) newTitle
{
	[newTitle retain];
	[viewTitle release];
	viewTitle = newTitle;
}

/* activateAddressBar
 * Put the focus on the address bar.
 */
-(void)activateAddressBar
{
	[[NSApp mainWindow] makeFirstResponder:addressField];
}

/* loadURL
 * Load the specified URL into the web frame.
 */
-(void)loadURL:(NSURL *)url inBackground:(BOOL)openInBackgroundFlag
{
	[self setViewTitle:@""];
	openURLInBackground = openInBackgroundFlag;
	isLocalFile = [url isFileURL];

	[pageFilename release];
	pageFilename = [[[[url path] lastPathComponent] stringByDeletingPathExtension] retain];
	
	[addressField setStringValue:[url absoluteString]];
	[self retain];
	if ([self.webPane isLoading])
	{
		[self willChangeValueForKey:@"isLoading"];
		[self.webPane stopLoading:self];
		[self didChangeValueForKey:@"isLoading"];
	}
	[[self.webPane mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
	[self release];
}

/* setStatusText
 * Called from the webview when some JavaScript writes status text. Echo this to
 * our status bar.
 */
-(void)webView:(WebView *)sender setStatusText:(NSString *)text
{
	if ([[controller browserView] activeTabItemView] == self)
		[controller setStatusMessage:text persist:NO];
}

/* mouseDidMoveOverElement
 * Called from the webview when the user positions the mouse over an element. If it's a link
 * then echo the URL to the status bar like Safari does.
 */
-(void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(NSUInteger )modifierFlags
{
	NSURL * url = [elementInformation valueForKey:@"WebElementLinkURL"];
	[controller setStatusMessage:(url ? [url absoluteString] : @"") persist:NO];
}

/* didStartProvisionalLoadForFrame
 * Invoked when a new client request is made by sender to load a provisional data source for frame.
 */
-(void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
	if (frame == [self.webPane mainFrame])
	{
		[[controller browserView] setTabItemViewTitle:self title:NSLocalizedString(@"Loading...", nil)];
		[self showRssPageButton:NO];
		[self setError:nil];
		[self setViewTitle:@""];
		[self retain];
	}

}

/* didCommitLoadForFrame
 * Invoked when data source of frame has started to receive data.
 */
-(void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
	if (frame == [self.webPane mainFrame])
	{
		if (!isLoading)
		{
			[self willChangeValueForKey:@"isLoading"];
			isLoading = YES;
			[self didChangeValueForKey:@"isLoading"];
		}
		
		if (!openURLInBackground)
			[[sender window] makeFirstResponder:sender];

		// Show or hide the lock icon depending on whether this is a secure
		// web page. Also shade the address bar a nice light yellow colour as
		// Camino does.
		NSURL * theURL = [[[frame dataSource] request] URL];
		if ([[theURL scheme] isEqualToString:@"https"])
		{
			[[addressField cell] setHasSecureImage:YES];
			[addressField setBackgroundColor:[NSColor colorWithDeviceRed:1.0 green:1.0 blue:0.777 alpha:1.0]];
			[lockIconImage setHidden:NO];
		}
		else
		{
			[[addressField cell] setHasSecureImage:NO];
			[addressField setBackgroundColor:[NSColor whiteColor]];
			[lockIconImage setHidden:YES];
		}
		
		if (![[frame dataSource] unreachableURL])
			[addressField setStringValue:[theURL absoluteString]];
		else 
			[addressField setStringValue:[[[frame dataSource] unreachableURL] absoluteString]];

	}
}

/* didFailProvisionalLoadWithError
 * Invoked when a location request for frame has failed to load.
 */
-(void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	if (frame == [self.webPane mainFrame])
	{
		// Was this a feed redirect? If so, this isn't an error:
		if (![self.webPane isFeedRedirect] && ![self.webPane isDownload])
		{
			[self setError:error];
			
			// Use a warning sign as favicon
			[iconImage setImage:[NSImage imageNamed:@"folderError.tiff"]];
			
			// Load the localized verion of the error page
			NSString * pathToErrorPage = [[NSBundle bundleForClass:[self class]] pathForResource:@"errorpage" ofType:@"html"];
			if (pathToErrorPage != nil)
			{
				NSString *errorMessage = [NSString stringWithContentsOfFile:pathToErrorPage encoding:NSUTF8StringEncoding error:NULL];
				errorMessage = [errorMessage stringByReplacingOccurrencesOfString: @"$ErrorInformation" withString: [error localizedDescription]];
				if (errorMessage != nil)
				{
					[frame loadAlternateHTMLString:errorMessage baseURL:[NSURL fileURLWithPath:pathToErrorPage isDirectory:NO] forUnreachableURL:[[[frame provisionalDataSource] request] URL]];
				}
				NSString *unreachableURL = [[[frame provisionalDataSource] unreachableURL] absoluteString];
				if (unreachableURL != nil)
					[addressField setStringValue: [[[frame provisionalDataSource] unreachableURL] absoluteString]];
			}	
		}
		[self endFrameLoad];
	}
}

/* endFrameLoad
 * Handle the end of a load whether or not it completed and whether or not an error
 * occurred. The error variable is nil for no error or it contains the most recent
 * NSError incident.
 */
-(void)endFrameLoad
{
	if ([viewTitle isEqualToString:@""])
	{
		if (lastError == nil)
			[[controller browserView] setTabItemViewTitle:self title:pageFilename];
	}
	
	[self willChangeValueForKey:@"isLoading"];
	isLoading = NO;
	[self didChangeValueForKey:@"isLoading"];
	
	openURLInBackground = NO;
	[self release];
}

/* didFailLoadWithError
 * Invoked when a location request for frame has failed to load.
 */
-(void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	if (frame == [self.webPane mainFrame])
	{
		// Not really an error. A plugin is grabbing the URL and will handle it
		// by itself.
		if (!([[error domain] isEqualToString:WebKitErrorDomain] && [error code] == WebKitErrorPlugInWillHandleLoad))
		{
			[self setError:error];
			
			// Use a warning sign as favicon
			[iconImage setImage:[NSImage imageNamed:@"folderError.tiff"]];
			
			// Load the localized verion of the error page
			NSString * pathToErrorPage = [[NSBundle bundleForClass:[self class]] pathForResource:@"errorpage" ofType:@"html"];
			if (pathToErrorPage != nil)
			{
				NSString *errorMessage = [NSString stringWithContentsOfFile:pathToErrorPage encoding:NSUTF8StringEncoding error:NULL];
				errorMessage = [errorMessage stringByReplacingOccurrencesOfString: @"$ErrorInformation" withString: [error localizedDescription]];
				if (errorMessage != nil)
				{
					[frame loadAlternateHTMLString:errorMessage baseURL:[NSURL fileURLWithPath:pathToErrorPage isDirectory:NO] forUnreachableURL:[[[frame dataSource] request] URL]];
				}
			}		
		}
		[self endFrameLoad];
	}
}

/* didFinishLoadForFrame
 * Invoked when a location request for frame has successfully; that is, when all the resources are done loading.
 */
-(void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if (frame == [self.webPane mainFrame])
	{
		// Once the frame is loaded, trawl the source for possible links to RSS
		// pages.
		NSData * webSrc = [[frame dataSource] data];
		NSMutableArray * arrayOfLinks = [NSMutableArray array];
		
		if ([RichXMLParser extractFeeds:webSrc toArray:arrayOfLinks])
		{
			[rssPageURL release];
			rssPageURL = [arrayOfLinks objectAtIndex:0];
			if (![rssPageURL hasPrefix:@"http:"] && ![rssPageURL hasPrefix:@"https:"])
				rssPageURL = [[self viewLink] stringByAppendingString:rssPageURL];
			[rssPageURL retain];
			[self showRssPageButton:YES];
		}
		[self endFrameLoad];
	}
}

/* didReceiveTitle
 * Invoked when the page title arrives. We use this to set the tab title.
 */
-(void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
	if (frame == [self.webPane mainFrame])
	{
		[[controller browserView] setTabItemViewTitle:self title:title];
		[self setViewTitle:title];
	}
}

/* didReceiveIcon
 * Invoked when we get the page icon.
 */
-(void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame
{
	if (frame == [self.webPane mainFrame])
	{
		[image setSize:NSMakeSize(14, 14)];
		[iconImage setImage:image];
	}
}

/* createWebViewWithRequest
 * Called when the browser wants to create a new webview.
 */
-(WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	if (request != nil)
	// Request made through a click on an HTML link
	// Change this to handle modifier key?
	// Is this covered by the webView policy?
	{
		[controller openURL:[request URL] inPreferredBrowser:YES];
		return nil;
	}
	else
	// a script or a plugin requests a new window
	// open a new tab and return its main webview
	{
		[controller newTab:nil];
		NSView<BaseView> * theView = [[controller browserView] activeTabItemView];
		BrowserPane * browserPane = (BrowserPane *)theView;
		return [browserPane webPane];
	}
}

/* runJavaScriptAlertPanelWithMessage
 * Called when the browser wants to display a JavaScript alert panel containing the specified message.
 */
- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
	NSRunInformationalAlertPanel(NSLocalizedString(@"JavaScript", @""),	// title
		@"%@",	// message placeholder
		NSLocalizedString(@"OK", @""),	// default button
		nil,	// alt button
		nil,	// other button
		message);
}

/* runJavaScriptConfirmPanelWithMessage
 * Called when the browser wants to display a JavaScript confirmation panel with the specified message.
 */
- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
	NSInteger result = NSRunInformationalAlertPanel(NSLocalizedString(@"JavaScript", @""),	// title
		@"%@",	// message placeholder
		NSLocalizedString(@"OK", @""),	// default button
		NSLocalizedString(@"Cancel", @""),	// alt button
		nil,
		message);
	return NSAlertDefaultReturn == result;
}

- (void)webView:(WebView *)sender runOpenPanelForFileButtonWithResultListener:(id < WebOpenPanelResultListener >)resultListener
{
	// Create the File Open Dialog class.
	NSOpenPanel* openDlg = [NSOpenPanel openPanel];

	// Enable the selection of files in the dialog.
	[openDlg setCanChooseFiles:YES];

	// Enable the selection of directories in the dialog.
	[openDlg setCanChooseDirectories:NO];

	if ( [openDlg runModal] == NSOKButton )
	{
		NSArray* files = [[openDlg URLs]valueForKey:@"relativePath"];
		[resultListener chooseFilenames:files];
	}
}

/* setFrame
 * Trap this to stop scripts from resizing the main Vienna window.
 */
-(void)webView:(WebView *)sender setFrame:(NSRect)frame
{
}

/* webViewClose
 * Handle scripting closing a window by just closing the tab.
 */
-(void)webViewClose:(WebView *)sender
{
	[self handleStopLoading:self];
	[[controller browserView] closeTabItemView:self];
}

/* contextMenuItemsForElement
 * Creates a new context menu for our web pane.
 */
-(NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSURL * urlLink = [element valueForKey:WebElementLinkURLKey];
	if (urlLink != nil) 
		return [controller contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
	
	WebFrame * frameKey = [element valueForKey:WebElementFrameKey];
	if (frameKey != nil && !isLocalFile)
		return [controller contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
	
	return defaultMenuItems;
}

/* printDocument
 * Print the web page.
 */
-(void)printDocument:(id)sender
{
	[self.webPane printDocument:sender];
}

/* mainView
 * Return the view that typically receives focus
 */
-(NSView *)mainView
{
	return self.webPane;
}

/* webView
 * Return the web view of this view.
 */
-(WebView *)webView
{
	return self.webPane;
}

/* performFindPanelAction
 * Implement the search action. Search the web page for the specified
 * text.
 */
-(void)performFindPanelAction:(int)actionTag
{
	switch (actionTag)
	{
		case NSFindPanelActionSetFindString:
		{			
			[self.webPane searchFor:[controller searchString] direction:YES caseSensitive:NO wrap:YES];
			break;
		}
			
		case NSFindPanelActionNext:
			[self.webPane searchFor:[controller searchString] direction:YES caseSensitive:NO wrap:YES];
			break;
			
		case NSFindPanelActionPrevious:
			[self.webPane searchFor:[controller searchString] direction:NO caseSensitive:NO wrap:YES];
			break;
	}
}

/* url
 * Return the URL of the page being displayed.
 */
-(NSURL *)url
{
	NSURL * theURL = nil;
	WebDataSource * dataSource = [[self.webPane mainFrame] dataSource];
	if (dataSource != nil)
	{
		theURL = [[dataSource request] URL];
	}
	else
	{
		NSString * urlString = [addressField stringValue];
		if (urlString != nil)
			theURL = [NSURL URLWithString:urlString];
	}
	return theURL;
}

-(NSString *)viewTitle
{
	return viewTitle;
}

/* canGoForward
 * Return TRUE if we can go forward to a web page.
 */
-(BOOL)canGoForward
{
	return [self.webPane canGoForward];
}

/* canGoBack
 * Return TRUE if we can go to a previous web page.
 */
-(BOOL)canGoBack
{
	return [self.webPane canGoBack];
}

/* handleGoForward
 * Go to the next web page.
 */
-(IBAction)handleGoForward:(id)sender
{
	[self.webPane goForward];
}

/* handleGoBack
 * Go to the previous web page.
 */
-(IBAction)handleGoBack:(id)sender
{
	[self.webPane goBack];
}

/* swipeWithEvent 
 * Enables "back"/"forward" and "scroll to top"/"scroll to bottom" via three-finger swipes as in Safari and other applications.
 */
-(void)swipeWithEvent:(NSEvent *)event 
{	
	CGFloat deltaX = [event deltaX];
	CGFloat deltaY = [event deltaY];

	// If the horizontal component of the swipe is larger, the user wants to go back or forward...
	if (fabsf(deltaX) > fabsf(deltaY))
	{
		if (deltaX != 0)
		{
			if (deltaX > 0)
				[self handleGoBack:self];
			else 
				[self handleGoForward:self];
		}
	}
	// Otherwise, she wants to go to the top/bottom of the page.
	else 
	{
		if (deltaY != 0)
		{
			if (deltaY > 0)
				[self.webPane scrollToTop];
			else 
				[self.webPane scrollToBottom];
		}
	}
}

/* handleReload
 * Reload the current web page.
 */
-(IBAction)handleReload:(id)sender
{
	if ([[self.webPane mainFrame] dataSource] != nil)
		[self.webPane reload:self];
	else
		[self handleAddress:self];
}

/* handleStopLoading webview
 * Stop loading the current web page.
 */
-(void)handleStopLoading:(id)sender
{
	[self willChangeValueForKey:@"isLoading"];
	[self.webPane stopLoading:self];
	[self didChangeValueForKey:@"isLoading"];
	[[self.webPane mainFrame] loadHTMLString:@"" baseURL:nil];
}

/* handleRSSPage
 * Open the RSS feed for the current page.
 */
-(IBAction)handleRSSPage:(id)sender
{
	if (rssPageURL != nil)
	{
		Folder * currentFolder = [NSApp currentFolder];
		int currentFolderId = [currentFolder itemId];
		int parentFolderId = [currentFolder parentId];
		if ([currentFolder firstChildId] > 0)
		{
			parentFolderId = currentFolderId;
			currentFolderId = 0;
		}
		[[NSApp delegate] createNewSubscription:rssPageURL underFolder:parentFolderId afterChild:currentFolderId];
	}
}

/* isLoading
 * Returns whether the current web page is in the process of being loaded.
 */
-(BOOL)isLoading
{
	return isLoading;
}

/* isProcessing
 * Synonymous function that enables the progress indicator on the active tab.
 */
-(BOOL)isProcessing
{
	return [self isLoading];
}

/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger )flags
{
	return NO;
}

/* dealloc
 * Clean up when the view is being deleted.
 */
-(void)dealloc
{
	[viewTitle release];
	viewTitle=nil;
	[rssPageURL release];
	rssPageURL=nil;
	[self handleStopLoading:nil];
	[webPane setFrameLoadDelegate:nil];
	[webPane setUIDelegate:nil];
	[webPane close];
	[lastError release];
	lastError=nil;
	[pageFilename release];
	pageFilename=nil;
	[webPane release];
	webPane = nil;
	[super dealloc];
}
@end
