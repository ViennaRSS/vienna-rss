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

#import "Constants.h"
#import "ArticleView.h"
#import "AppController.h"
#import "Preferences.h"
#import "HelperFunctions.h"
#import "StringExtensions.h"
#import <WebKit/WebKit.h>
#import "BrowserView.h"

@interface ArticleView (Private)
	-(BOOL)initForStyle:(NSString *)styleName;
	-(void)handleStyleChange:(NSNotificationCenter *)nc;
@end

// Styles path mappings is global across all instances
static NSMutableDictionary * stylePathMappings = nil;

@implementation ArticleView

/* initWithFrame
 * The designated instance initialiser.
 */
-(id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		// Init our vars
		htmlTemplate = nil;
		cssStylesheet = nil;
		jsScript = nil;
		currentHTML = nil;

		// Set up to be notified when style changes
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleStyleChange:) name:@"MA_Notify_StyleChange" object:nil];

		// Select the user's current style or revert back to the
		// default style otherwise.
		[self initForStyle:[[Preferences standardPreferences] displayStyle]];
	}
	return self;
}

/* handleStyleChange
 * Updates the article pane when the active display style has been changed.
 */
-(void)handleStyleChange:(NSNotificationCenter *)nc
{
	[self initForStyle:[[Preferences standardPreferences] displayStyle]];
}

/* performDragOperation
 * Don't accept stuff dragged into the article view. 
 */
-(BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{ 
	return NO;
}

/* stylesMap
 * Returns the article view styles map
 */
+(NSDictionary *)stylesMap
{
	return stylePathMappings;
}

/* loadStylesMap
 * Reinitialise the styles map from the styles folder.
 */
+(NSDictionary *)loadStylesMap
{
	if (stylePathMappings == nil)
		stylePathMappings = [[NSMutableDictionary alloc] init];
	
	NSString * path = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"Styles"];
	loadMapFromPath(path, stylePathMappings, YES, nil);
	
	path = [[Preferences standardPreferences] stylesFolder];
	loadMapFromPath(path, stylePathMappings, YES, nil);

	return stylePathMappings;
}

/* initForStyle
 * Initialise the template and stylesheet for the specified display style if it can be
 * found. Otherwise the existing template and stylesheet are not changed.
 */
-(BOOL)initForStyle:(NSString *)styleName
{
	if (stylePathMappings == nil)
		[ArticleView loadStylesMap];

	NSString * path = [stylePathMappings objectForKey:styleName];
	if (path != nil)
	{
		NSString * filePath = [path stringByAppendingPathComponent:@"template.html"];
		NSString * templateString = [NSString stringWithContentsOfFile:filePath usedEncoding:NULL error:NULL];
		// Sanity check the file. Obviously anything bigger than 0 bytes but smaller than a valid template
		// format is a problem but we'll worry about that later. There's only so much rope we can give.
		if (templateString != nil && [templateString length] > 0u)
		{
			[htmlTemplate release];
			[cssStylesheet release];
			[jsScript release];
			
			htmlTemplate = [templateString retain];
			cssStylesheet = [[@"file://localhost" stringByAppendingString:[path stringByAppendingPathComponent:@"stylesheet.css"]] retain];
			NSString * javaScriptPath = [path stringByAppendingPathComponent:@"script.js"];
			if ([[NSFileManager defaultManager] fileExistsAtPath:javaScriptPath])
				jsScript = [[@"file://localhost" stringByAppendingString:javaScriptPath] retain];
			else
				jsScript = nil;
			
			// Make sure the template is valid
			NSString * firstLine = [[htmlTemplate firstNonBlankLine] lowercaseString];
			if (![firstLine hasPrefix:@"<html>"] && ![firstLine hasPrefix:@"<!doctype"])
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_ArticleViewChange" object:nil];
				return YES;
			}
		}
	}
	
	// If the template is invalid, revert to the default style
	// which should ALWAYS be valid.
	NSAssert(![styleName isEqualToString:@"Default"], @"Default style is corrupted!");
	
	// Warn the user.
	NSString * titleText = [NSString stringWithFormat:NSLocalizedString(@"Invalid style title", nil), styleName];
	runOKAlertPanel(titleText, NSLocalizedString(@"Invalid style body", nil));

	// We need to reset the preferences without firing off a notification since we want the
	// style change to happen immediately.
	Preferences * prefs = [Preferences standardPreferences];
	[prefs setDisplayStyle:MA_DefaultStyleName withNotification:NO];
	return [self initForStyle:MA_DefaultStyleName];
}

/* articleTextFromArray
 * Create an HTML string comprising all articles in the specified array formatted using
 * the currently selected template.
 */
-(NSString *)articleTextFromArray:(NSArray *)msgArray
{
	int index;
	
	NSMutableString * htmlText = [[NSMutableString alloc] initWithString:@"<html><head>"];
	if (cssStylesheet != nil)
	{
		[htmlText appendString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\""];
		[htmlText appendString:cssStylesheet];
		[htmlText appendString:@"\"/>"];
	}
	if (jsScript != nil)
	{
		[htmlText appendString:@"<script type=\"text/javascript\" src=\""];
		[htmlText appendString:jsScript];
		[htmlText appendString:@"\"/></script>"];
	}
	[htmlText appendString:@"<meta http-equiv=\"Pragma\" content=\"no-cache\">"];
	[htmlText appendString:@"</head><body>"];
	for (index = 0; index < [msgArray count]; ++index)
	{
		Article * theArticle = [msgArray objectAtIndex:index];
		
		// Load the selected HTML template for the current view style and plug in the current
		// article values and style sheet setting.
		NSMutableString * htmlArticle;
		if (htmlTemplate == nil)
		{
			NSMutableString * articleBody = [NSMutableString stringWithString:[theArticle body]];
			[articleBody fixupRelativeImgTags:SafeString([theArticle link])];
			htmlArticle = [[NSMutableString alloc] initWithString:articleBody];
		}
		else
		{
			htmlArticle = [[NSMutableString alloc] initWithString:@""];
			NSScanner * scanner = [NSScanner scannerWithString:htmlTemplate];
			NSString * theString = nil;
			BOOL stripIfEmpty = NO;

			// Handle conditional tag expansion. Sections in <!-- cond:noblank--> and <!--end-->
			// are stripped out if all the tags inside are blank.
			while(![scanner isAtEnd])
			{
				if ([scanner scanUpToString:@"<!--" intoString:&theString])
					[htmlArticle appendString:[theArticle expandTags:theString withConditional:stripIfEmpty]];
				if ([scanner scanString:@"<!--" intoString:nil])
				{
					NSString * commentTag = nil;

					if ([scanner scanUpToString:@"-->" intoString:&commentTag] && commentTag != nil)
					{
						commentTag = [commentTag trim];
						if ([commentTag isEqualToString:@"cond:noblank"])
							stripIfEmpty = YES;
						if ([commentTag isEqualToString:@"end"])
							stripIfEmpty = NO;
						[scanner scanString:@"-->" intoString:nil];
					}
				}
			}
		}
		
		// Separate each article with a horizontal divider line
		if (index > 0)
			[htmlText appendString:@"<hr><br />"];
		[htmlText appendString:htmlArticle];
		[htmlArticle release];
	}
	[htmlText appendString:@"</body></html>"];
	return [htmlText autorelease];
}

/* clearHTML
 * Loads the web view with the HTML text for a blank page.
 */
-(void)clearHTML
{
	// Reset current html string.
	if (currentHTML != nil)
		[currentHTML release];
	currentHTML = [[NSString alloc] initWithString: @"<HTML></HTML>"];
	
	// Load a blank HTML page.
	NSString * htmlText = [[NSString alloc] initWithString: @"<HTML></HTML>"];
	const char * utf8String = [htmlText UTF8String];
	[[self mainFrame] loadData:[NSData dataWithBytes:utf8String length:strlen(utf8String)]
					  MIMEType:@"text/html" 
			  textEncodingName:@"utf-8" 
					   baseURL:[NSURL URLWithString:@""]];
	[htmlText release];
}

/* setHTML
 * Loads the web view with the specified HTML text.
 */
-(void)setHTML:(NSString *)htmlText withBase:(NSString *)urlString
{
	// If the current HTML is the same as the new HTML then we don't need to
	// do anything here. This will stop the view from spurious redraws of the same
	// article after a refresh.
	if (currentHTML != nil && [currentHTML compare:htmlText] == NSOrderedSame)
		return;
	
	// Remember the current html string.
	if (currentHTML != nil)
		[currentHTML release];
	currentHTML = [[NSString alloc] initWithString: htmlText];
	
	// Replace feed:// with http:// if necessary
	if ([urlString hasPrefix:@"feed://"])
		urlString = [NSString stringWithFormat:@"http://%@", [urlString substringFromIndex:7]];
	
	const char * utf8String = [htmlText UTF8String];
	[[self mainFrame] loadData:[NSData dataWithBytes:utf8String length:strlen(utf8String)]
							 MIMEType:@"text/html" 
					 textEncodingName:@"utf-8" 
							  baseURL:[NSURL URLWithString:urlString]];
}

/* keyDown
 * Here is where we handle special keys when the article view
 * has the focus so we can do custom things.
 */
-(void)keyDown:(NSEvent *)theEvent
{
	if ([[theEvent characters] length] == 1)
	{
		unichar keyChar = [[theEvent characters] characterAtIndex:0];
		if ([[NSApp delegate] handleKeyDown:keyChar withFlags:[theEvent modifierFlags]])
			return;
		
		//Don't go back or forward in article view.
		if (([theEvent modifierFlags] & NSCommandKeyMask) &&
			((keyChar == NSLeftArrowFunctionKey) || (keyChar == NSRightArrowFunctionKey)))
			return;
	}
	[super keyDown:theEvent];
}

/* swipeWithEvent 
 * Enables "scroll to top"/"scroll to bottom" via vertical three-finger swipes as in Safari and other applications.
 * Also enables calling "viewNextUnread:" and "goBack:" via horizontal three-finger swipes.
 */
-(void)swipeWithEvent:(NSEvent *)event 
{	
	CGFloat deltaX = [event deltaX];
	CGFloat deltaY = [event deltaY];
		
	/* Check which is more likely to be what the user wanted: horizontal or vertical swipe?
	 * Thankfully, that's all the checking we need to do as built-in swipe detection is very solid. */
	if ( fabsf(deltaY) > fabsf(deltaX) )
	{
		if (deltaY != 0)
		{
			if (deltaY > 0)
				[self scrollToTop];
			else
				[self scrollToBottom];
		}
	}
	else 
	{
		if (deltaX != 0)
		{
			if (deltaX > 0)
				[controller goBack:self];
			else 
				[controller viewNextUnread:self];
		}
	}		
}

/* decidePolicyForNewWindowAction
 * Called by the web view to get our policy on handling actions that would open a new window.
 * When opening clicked links in the background or an external browser, we want the first responder to return to the article list.
 */
-(void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
	int navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] intValue];
	if ((navType == WebNavigationTypeLinkClicked) && ([[Preferences standardPreferences] openLinksInBackground] || ![[Preferences standardPreferences] openLinksInVienna]))
		[[NSApp mainWindow] makeFirstResponder:[[[[NSApp delegate] browserView] primaryTabItemView] mainView]];
	
	[super webView:sender decidePolicyForNewWindowAction:actionInformation request:request newFrameName:frameName decisionListener:listener];
}
		
/* decidePolicyForNavigationAction
 * Called by the web view to get our policy on handling navigation actions.
 * Relative URLs should open in the same view.
 * When opening clicked links in the background or an external browser, we want the first responder to return to the article list.
 */
-(void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	if ([[request URL] fragment] != nil)
	{
		NSURL * feedURL = [[[[self mainFrame] dataSource] initialRequest] URL];
		if ((feedURL != nil) && [[feedURL scheme] isEqualToString:[[request URL] scheme]] && [[feedURL host] isEqualToString:[[request URL] host]] && [[feedURL path] isEqualToString:[[request URL] path]])
		{
			[listener use];
			return;
		}
	}
	
	int navType = [[actionInformation valueForKey:WebActionNavigationTypeKey] intValue];
	if ((navType == WebNavigationTypeLinkClicked) && ([[Preferences standardPreferences] openLinksInBackground] || ![[Preferences standardPreferences] openLinksInVienna]))
		[[NSApp mainWindow] makeFirstResponder:[[[[NSApp delegate] browserView] primaryTabItemView] mainView]];
	
	[super webView:sender decidePolicyForNavigationAction:actionInformation request:request frame:frame decisionListener:listener];
}	

/* dealloc
 * Clean up behind ourself.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[cssStylesheet release];
	[htmlTemplate release];
	[currentHTML release];
	[super dealloc];
}
@end
