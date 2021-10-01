//
//  SUUIBasedUpdateDriver.h
//  Sparkle
//
//  Created by Andy Matuschak on 5/5/08.
//  Copyright 2008 Andy Matuschak. All rights reserved.
//

#ifndef SUUIBASEDUPDATEDRIVER_H
#define SUUIBASEDUPDATEDRIVER_H

#import <Cocoa/Cocoa.h>
#import "SUBasicUpdateDriver.h"

@class SUStatusController;

@interface SUUIBasedUpdateDriver : SUBasicUpdateDriver
@property (assign) BOOL showErrors;

- (void)showAlert:(NSAlert *)alert;
- (IBAction)cancelDownload:(id)sender;
- (void)installAndRestart:(id)sender;
- (BOOL)shouldShowUpdateAlertForItem:(SUAppcastItem *)item;

@end

#endif
