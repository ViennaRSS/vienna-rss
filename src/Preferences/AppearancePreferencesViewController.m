//
//  AppearancePreferencesViewController.m
//  Vienna
//
//  Created by Joshua Pore on 22/11/2014.
//  Copyright (c) 2014 uk.co.opencommunity. All rights reserved.
//

#import "AppearancePreferencesViewController.h"

@interface AppearancePreferencesViewController ()

@end

@implementation AppearancePreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (instancetype)init {
    return [super initWithNibName:@"AppearancePreferencesView" bundle:nil];
}

#pragma mark - MASPreferencesViewController

- (NSString *)identifier {
    return @"AppearancePreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"appearancePrefImage"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Appearance", @"Toolbar item name for the Appearance preference pane");
}

@end
