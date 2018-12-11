//
//  Browser+WebUIDelegate.m
//  Vienna
//
//  Created by Tassilo Karge on 12.10.18.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

#import "Browser+WebUIDelegate.h"
#import "BrowserPane.h"
#import "TabbedWebView.h"
#import "RichXMLParser.h"
#import "AppController.h"

@implementation Browser (WebUIDelegate)

#pragma mark - WebUIDelegate

/* mouseDidMoveOverElement
 * Called from the webview when the user positions the mouse over an element. If it's a link
 * then echo the URL to the status bar like Safari does.
 */
- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation
  modifierFlags:(NSUInteger)modifierFlags {

    NSView *activeView = self.activeTab.view;
    if (!([activeView isKindOfClass:BrowserPane.class]
          && ((BrowserPane *)activeView).webView == sender)) {
        return;
    }
    BrowserPane *bp = (BrowserPane *)self.activeTab.view;

    NSURL *url = [elementInformation valueForKey:@"WebElementLinkURL"];
    [bp hoveredOverURL:url];
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
        [APPCONTROLLER openURL:request.URL inPreferredBrowser:YES];
        return nil;
    }
    else
        // a script or a plugin requests a new window
        // open a new tab and return its main webview
    {
        return [self newTab].webPane;
    }
}

/* runJavaScriptAlertPanelWithMessage
 * Called when the browser wants to display a JavaScript alert panel containing the specified message.
 */
- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
    //TODO: java script dialogs like this are used maliciously.
    //Make them go away when changing the tab and make them not blocking the remaining browser interface
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = NSLocalizedString(@"JavaScript", @"");
    alert.informativeText = message;
    [alert runModal];
}

/* runJavaScriptConfirmPanelWithMessage
 * Called when the browser wants to display a JavaScript confirmation panel with the specified message.
 */
- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
    //TODO: java script dialogs like this are used maliciously.
    //Make them go away when changing the tab and make them not blocking the remaining browser interface
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = NSLocalizedString(@"JavaScript", @"");
    alert.informativeText = message;
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"Title of a button on an alert")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Title of a button on an alert")];
    NSModalResponse alertResponse = [alert runModal];

    return alertResponse == NSAlertFirstButtonReturn;
}

- (void)webView:(WebView *)sender runOpenPanelForFileButtonWithResultListener:(id < WebOpenPanelResultListener >)resultListener
{
    // Create the File Open Dialog class.
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];

    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];

    // Enable the selection of directories in the dialog.
    [openDlg setCanChooseDirectories:NO];

    if ( [openDlg runModal] == NSFileHandlingPanelOKButton )
    {
        NSArray* files = [openDlg.URLs valueForKey:@"relativePath"];
        [resultListener chooseFilenames:files];
    }
}

/* setFrame
 * Trap this to stop scripts from resizing the main Vienna window.
 */
-(void)webView:(WebView *)sender setFrame:(NSRect)frame
{
}

/* contextMenuItemsForElement
 * Creates a new context menu for our web pane.
 */
-(NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{

    NSView *activeView = self.activeTab.view;
    if (!([activeView isKindOfClass:BrowserPane.class]
          && ((BrowserPane *)activeView).webView == sender)) {
        return @[];
    }
    BrowserPane *bp = (BrowserPane *)self.activeTab.view;

    NSURL * urlLink = [element valueForKey:WebElementLinkURLKey];
    if (urlLink != nil)
        return [APPCONTROLLER contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];

    WebFrame * frameKey = [element valueForKey:WebElementFrameKey];
    if (frameKey != nil && !bp.url.fileURL)
        return [APPCONTROLLER contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];

    return defaultMenuItems;
}

/* webViewClose
 * closes the tab on a javascript request (only if it is in foreground though)
 */
-(void)webViewClose:(WebView *)sender {
	NSView *activeView = self.activeTab.view;
	if (!([activeView isKindOfClass:BrowserPane.class]
		  && ((BrowserPane *)activeView).webView == sender)) {
		[self closeTab:self.activeTab];
	}
}

@end
