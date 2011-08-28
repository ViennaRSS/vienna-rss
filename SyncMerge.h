//
//  SyncMerge.h
//  Vienna
//
//  Created by Adam Hartford on 8/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GRSMergeOperation.h"

@interface SyncMerge : NSWindowController <GRSMergeDelegate>
{
    IBOutlet NSTextField * messageTextField;
    IBOutlet NSProgressIndicator * progressIndicator;
    
    NSOperationQueue * operationQueue;
    NSModalSession session;
    
    BOOL running;
}

-(IBAction)cancel:(id)sender;

-(void)beginMerge;

@property (assign) NSTextField * messageTextField;
@property (assign) NSProgressIndicator * progressIndicator;
@property (assign) NSModalSession session;
@property (readonly) BOOL running;

@end
