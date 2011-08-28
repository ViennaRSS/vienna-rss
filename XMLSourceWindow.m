//
//  XMLSourceWindow.h
//  Vienna
//
//  Created by Michael on 02/11/09.
//  Copyright (c) 2009 Michael G. Stroeck. All rights reserved.
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

#import "XMLSourceWindow.h"
#import "AppController.h"
#import "Folder.h"

@implementation SourceWebView

/* performDragOperation
 * Don't accept stuff dragged into the source view for security reasons, since it has JavaScript turned on.
 */
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return NO;
}

@end

@implementation XMLSourceWindow

/* initWithFolder:
 * Just init the "View Source" window.
 */
-(id)initWithFolder:(Folder *)folder
{
	NSParameterAssert( folder != nil );
	
	if ((self = [super initWithWindowNibName:@"XMLSource"]) != nil)
	{
		sourceWindowTitle = [[NSString alloc] initWithFormat:@"%@ %i: %@", NSLocalizedString(@"Source of folder", nil), [folder itemId], [folder name]];
		feedSourceFilePath = [[folder feedSourceFilePath] copy];
	}
	return self;
}

/* displayXmlSource
 * Create the syntax highlighted HTML document from xmlSource. This works 
 * via the JavaScript in the resource XMLSyntaxHighlighter.html.
 */
-(void)displayXmlSource
{
	NSString * pathToSyntaxHighlighter = [[NSBundle bundleForClass:[self class]] pathForResource:@"XMLSyntaxHighlighter" ofType:@"html"];
	if (pathToSyntaxHighlighter != nil)
	{
		NSString *syntaxHighlighter = [NSString stringWithContentsOfFile:pathToSyntaxHighlighter encoding:NSUTF8StringEncoding error:NULL];
		if (syntaxHighlighter != nil)
		{
			NSString * errorDescription = nil;
			
			if (feedSourceFilePath == nil)
			{
				errorDescription = NSLocalizedString(@"No feed source to display.",nil);
			}
			else
			{
				NSStringEncoding encoding;
				NSError * error;
				NSString * xmlSource = [NSString stringWithContentsOfFile:feedSourceFilePath usedEncoding:&encoding error:&error];
				if (xmlSource != nil)
				{
					// Get rid of potential body, script, CDATA and other tags within the string that may cause a mess.
					xmlSource = [xmlSource stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
					xmlSource = [xmlSource stringByReplacingOccurrencesOfString:@"[" withString:@"&#91;"];
					xmlSource = [xmlSource stringByReplacingOccurrencesOfString:@"]" withString:@"&#93;"];
					xmlSource = [xmlSource stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
					xmlSource = [xmlSource stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
					
					syntaxHighlighter = [syntaxHighlighter stringByReplacingOccurrencesOfString:@"$XMLSourceData" withString:xmlSource];
				}
				else
					errorDescription = [error localizedDescription];
			}
			
			if (errorDescription != nil)
			{
				syntaxHighlighter = [NSString stringWithFormat:@"<html><body><br><br><br><center>%@</center><body></html>", errorDescription];
			}
				
			[[sourceWebView mainFrame] loadHTMLString:syntaxHighlighter baseURL:[NSURL fileURLWithPath:pathToSyntaxHighlighter isDirectory:NO]];
		}
	}	
}

/* windowDidLoad
 * When the window has finished loading, we make sure that the WebView's WebPreferences 
 * allow the execution of JavaScript. We need that for syntax coloring, and the user might
 * have turned it off in the user preferences.
 */
- (void)windowDidLoad
{
	static WebPreferences * sJavaScriptPreferences;
	
	if (sJavaScriptPreferences == nil)
	{
		sJavaScriptPreferences = [[WebPreferences alloc] initWithIdentifier:@"ViennaJavaScriptEnabled"];
		[sJavaScriptPreferences setAutosaves:NO];
		[sJavaScriptPreferences setJavaEnabled:NO];
		[sJavaScriptPreferences setJavaScriptCanOpenWindowsAutomatically:NO];
		[sJavaScriptPreferences setJavaScriptEnabled:YES];
		[sJavaScriptPreferences setLoadsImagesAutomatically:NO];
		[sJavaScriptPreferences setPlugInsEnabled:NO];
		[sJavaScriptPreferences setPrivateBrowsingEnabled:YES];
		[sJavaScriptPreferences setUsesPageCache:NO];
	}
	
	[[self window] setTitle:sourceWindowTitle];
	[sourceWebView setPreferencesIdentifier:@"ViennaJavaScriptEnabled"];
	[self displayXmlSource];
}

- (void)windowWillClose:(NSNotification *)notification
{
	// Post this for interested observers (namely, the AppController)
	[[NSNotificationCenter defaultCenter] postNotificationName:[notification name] object:self];
}

/*
 * webView: decidePolicyForNavigationAction: ....
 * Do not allow following of links inside this view for security reasons, as JavaScript is enabled here by default.
 * Links are opened in the way the user specifies in Preferences, respecting his security settings.
 */
- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{
	NSNumber * navigationTypeObject = [actionInformation objectForKey:WebActionNavigationTypeKey];
	if (navigationTypeObject != nil)
	{
		int navigationType = [navigationTypeObject intValue];
		if (navigationType == WebNavigationTypeLinkClicked)
		{
			[listener ignore];
			[[NSApp delegate] openURL:[request URL] inPreferredBrowser:YES];
			return;
		}
	}
	
	[listener use];
}

-(void)dealloc
{
	[feedSourceFilePath release];
	[sourceWindowTitle release];
	[super dealloc];
}

@end