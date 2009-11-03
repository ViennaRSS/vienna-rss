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

@implementation XMLSourceWindow

/* init
 * Just init the "View Source" window.
 */
-(id)init
{
	if ((self = [super initWithWindowNibName:@"XMLSource"]) != nil)
	{
		xmlSource = nil;
	}
	return self;
}

/* setTitle
 * Sets the window title
 */
-(void)setTitle:(NSString *)theTitle
{
	NSString * prefix = NSLocalizedString(@"Source of ", nil);
	[[self window] setTitle:[prefix stringByAppendingString:theTitle]];
}

/* setXmlSource
 * Set the windows associated XML source code.
 */
-(void)setXmlSource:(NSString *)theSource
{
	[theSource retain];
	[xmlSource release];
	xmlSource = theSource;
	
	[self displayXmlSource];
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
			// TODO: Implement real error handling.
			if (xmlSource != nil)
				syntaxHighlighter = [syntaxHighlighter stringByReplacingOccurrencesOfString:@"$XMLSourceData" withString:xmlSource];
			else
				syntaxHighlighter = @"<html><body><br><br><br><center>No feed source to display.</center><body></html>";
				
			[[sourceWebView mainFrame] loadHTMLString:syntaxHighlighter baseURL:[NSURL fileURLWithPath:pathToSyntaxHighlighter isDirectory:NO]];
		}
	}	
	
}

/* xmlSource
 * Returns the associated XML source code.
 */
-(NSString *)xmlSource
{
	return xmlSource;
}

-(void)dealloc
{
	[xmlSource release];
	[super dealloc];
}

- (void)windowWillClose:(NSNotification *)notification
{
	// Post this for interested observers (namely, the AppController)
	[[NSNotificationCenter defaultCenter] postNotificationName:[notification name] object:self];
}

@end
