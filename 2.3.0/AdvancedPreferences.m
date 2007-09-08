//
//  AdvancedPreferences.m
//  Vienna
//
//  Created by Steve Palmer on 25/11/2006.
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

#import "AdvancedPreferences.h"
#import "Preferences.h"
#import "HelperFunctions.h"

// Private functions
@interface AdvancedPreferences (Private)
	-(void)initializePreferences;
@end

@implementation AdvancedPreferences

/* init
 * Initialize the class
 */
-(id)init
{
	return [super initWithWindowNibName:@"AdvancedPreferences"];
}

/* windowDidLoad
 * First time window load initialisation. Since preferences could potentially be
 * changed while the Preferences window is closed, initialise the controls in the
 * initializePreferences function instead.
 */
-(void)windowDidLoad
{
	[self initializePreferences];
}

/* showAdvancedHelp
 * Displays the Help page for the Advanced settings.
 */
-(IBAction)showAdvancedHelp:(id)sender
{
	GotoHelpPage((CFStringRef)@"advanced.html", (CFStringRef)@"");
}

/* initializePreferences
 * Set the preference settings from the user defaults.
 */
-(void)initializePreferences
{
	Preferences * prefs = [Preferences standardPreferences];

	// Show use JavaScript option
	[useJavaScriptButton setState:[prefs useJavaScript] ? NSOnState : NSOffState];
}

/* changeUseJavaScript
 * Toggle whether or not the webkit should use JavaScript.
 */
-(IBAction)changeUseJavaScript:(id)sender
{
	BOOL useJavaScript = [sender state] == NSOnState;
	[[Preferences standardPreferences] setUseJavaScript:useJavaScript];
}
@end
