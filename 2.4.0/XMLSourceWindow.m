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
#import "Folder.h"

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
			NSStringEncoding encoding;
			NSError * error;
			NSString * xmlSource = (feedSourceFilePath != nil) ? [NSString stringWithContentsOfFile:feedSourceFilePath usedEncoding:&encoding error:&error] : nil;
			
			// TODO: Implement real error handling.
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
				syntaxHighlighter = [NSString stringWithFormat:@"<html><body><br><br><br><center>%@</center><body></html>", NSLocalizedString(@"No feed source to display.",nil)];
			
			WebPreferences *jsEnabledPrefs = [[[WebPreferences alloc] initWithIdentifier:@"jsEnabledPrefs"] autorelease];
			[jsEnabledPrefs setJavaScriptEnabled:YES];
			[sourceWebView setPreferences:jsEnabledPrefs];
			[[sourceWebView mainFrame] loadHTMLString:syntaxHighlighter baseURL:[NSURL fileURLWithPath:pathToSyntaxHighlighter isDirectory:NO]];
		}
	}	
}

-(void)dealloc
{
	[feedSourceFilePath release];
	[sourceWindowTitle release];
	[super dealloc];
}

- (void)windowDidLoad
{
	[[self window] setTitle:sourceWindowTitle];
	[self displayXmlSource];
}

- (void)windowWillClose:(NSNotification *)notification
{
	// Post this for interested observers (namely, the AppController)
	[[NSNotificationCenter defaultCenter] postNotificationName:[notification name] object:self];
}

@end
