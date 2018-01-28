//
//  ViennaSparkleDelegate.m
//  Vienna
//
//  Created by Barijaona Ramaholimihaso on 03/05/2016.
//  Copyright © 2016 uk.co.opencommunity. All rights reserved.
//

#import "ViennaSparkleDelegate.h"
#import "Preferences.h"

@implementation ViennaSparkleDelegate

/* updaterWillRelaunchApplication
 * This is a delegate for Sparkle.framwork
 */
- (void)updaterWillRelaunchApplication:(SUUpdater *)updater
{
	[[Preferences standardPreferences] handleUpdateRestart];
}

/* feedURLStringForUpdater:
 * This is a delegate for Sparkle.framework
 */
-(NSString *)feedURLStringForUpdater:(SUUpdater *)updater
{
	// the default as it is defined in Info.plist
	NSString * URLstring = [NSBundle mainBundle].infoDictionary[@"SUFeedURL"];
	if ([[Preferences standardPreferences] alwaysAcceptBetas])
	{
		NSURL * referenceURL = [NSURL URLWithString:URLstring];
		NSString * extension = [referenceURL pathExtension];
		NSURL * pathURL = [referenceURL URLByDeletingLastPathComponent];
		// same extension and path, except name is "changelog_beta"
		NSURL * newURL = [[pathURL URLByAppendingPathComponent:@"changelog_beta"] URLByAppendingPathExtension:extension];
		URLstring = [newURL absoluteString];
	}
	return URLstring;
}

/*! showSystemProfileInfoAlert
 * displays an alert asking the user to opt-in to sending anonymous system profile throug Sparkle
 */
-(void)showSystemProfileInfoAlert {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
    [alert addButtonWithTitle:NSLocalizedString(@"No thanks", @"No thanks")];
    [alert setMessageText:NSLocalizedString(@"Include anonymous system profile when checking for updates?", @"Include anonymous system profile when checking for updates?")];
    [alert setInformativeText:NSLocalizedString(@"Include anonymous system profile when checking for updates text", @"This helps Vienna development by letting us know what versions of Mac OS X are most popular amongst our users.")];
    alert.alertStyle = NSInformationalAlertStyle;
    NSModalResponse buttonClicked = alert.runModal;
    NSLog(@"buttonClicked: %ld", (long)buttonClicked);
    switch (buttonClicked) {
        case NSAlertFirstButtonReturn:
            /* Agreed to send system profile. Uses preferences to set value otherwise
             the preference control is out of sync */
            [[Preferences standardPreferences] setSendSystemSpecs:YES];
            break;
        case NSAlertSecondButtonReturn:
            /* Declined to send system profile. Uses SUUpdater to set the value
             otherwise it stays nil instead of being set to 0 */
            [[SUUpdater sharedUpdater] setSendsSystemProfile:NO];
            break;
        default:
            break;
    }
}

@end
