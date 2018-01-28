//
//  AppController+Sparkle.m
//  Vienna
//
//  Copyright 2016-2017 Barijaona Ramaholimihaso
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "AppController+Sparkle.h"
#import "Preferences.h"

@implementation AppController (Sparkle)

// MARK: SUUpdaterDelegate methods

- (NSString *)feedURLStringForUpdater:(SUUpdater *)updater {
	NSString *urlString = NSBundle.mainBundle.infoDictionary[@"SUFeedURL"];

	if ([Preferences standardPreferences].alwaysAcceptBetas) {
		NSURL *referenceURL = [NSURL URLWithString:urlString];
		NSString *extension = referenceURL.pathExtension;
		NSURL *pathURL = referenceURL.URLByDeletingLastPathComponent;
		NSURL *newURL = [[pathURL URLByAppendingPathComponent:@"changelog_beta"] URLByAppendingPathExtension:extension];
		urlString = newURL.absoluteString;
	}

	return urlString;
}

- (void)updaterWillRelaunchApplication:(SUUpdater *)updater {
    [[Preferences standardPreferences] handleUpdateRestart];
}

@end
