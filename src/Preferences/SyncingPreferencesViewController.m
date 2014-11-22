//
//  SyncingPreferencesViewController.m
//  Vienna
//
//  Created by Joshua Pore on 22/11/2014.
//  Copyright (c) 2014 uk.co.opencommunity. All rights reserved.
//

#import "SyncingPreferencesViewController.h"

@interface SyncingPreferencesViewController ()

@end

@implementation SyncingPreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (instancetype)init {
    return [super initWithNibName:@"SyncingPreferencesView" bundle:nil];
}

#pragma mark - MASPreferencesViewController

- (NSString *)identifier {
    return @"SyncingPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"sync"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Syncing", @"Toolbar item name for the Syncing preference pane");
}

@end
