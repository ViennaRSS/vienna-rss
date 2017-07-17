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

@end
