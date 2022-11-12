//
//  SearchPanel.m
//  Vienna
//
//  Created by Steve on Sat Jul 14 2007.
//  Copyright (c) 2004-2007 Steve Palmer. All rights reserved.
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

#import "SearchPanel.h"
#import "BrowserPane.h"
#import "AppController.h"
#import "Vienna-Swift.h"

@implementation SearchPanel

/* runSearchPanel
 * Show the search panel.
 */
-(void)runSearchPanel:(NSWindow *)window
{
	if (!searchPanelWindow)
	{
		NSArray * objects;
		[[NSBundle bundleForClass:[self class]] loadNibNamed:@"SearchPanel" owner:self topLevelObjects:&objects];
		self.topObjects = objects;
		((NSSearchFieldCell *)searchField.cell).searchMenuTemplate = APPCONTROLLER.searchFieldMenu;
	}
	[searchLabel setStringValue:NSLocalizedString(@"Search all articles or the current web page", nil)];
    [window beginSheet:searchPanelWindow completionHandler:nil];
}

/* newSearchString
 * Change the search string displayed in the search field.
 */
-(void)setSearchString:(NSString *)newSearchString
{
	searchField.stringValue = newSearchString;
}

/* searchStringChanged
 * This function is called when the user hits the Enter or Cancel key in the search
 * field. (Cancel blanks the searchField string value so searchArticlesWithString ends
 * up doing nothing.)
 */
-(IBAction)searchStringChanged:(id)sender
{
	APPCONTROLLER.searchString = searchField.stringValue;

    id<Tab> activeBrowserTab = APPCONTROLLER.browser.activeTab;
    if (activeBrowserTab) {
        [activeBrowserTab searchFor:APPCONTROLLER.searchString
                             action:NSFindPanelActionSetFindString];
        [APPCONTROLLER setFocusToSearchField:self];
    } else {
        [APPCONTROLLER searchArticlesWithString:searchField.stringValue];
    }

	[searchPanelWindow.sheetParent endSheet:searchPanelWindow];
	[searchPanelWindow orderOut:self];
}
@end
