//
//  SyncMerge.m
//  Vienna
//
//  Created by Adam Hartford on 8/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SyncMerge.h"
#import "Folder.h"
#import "AppController.h"

@implementation SyncMerge

@synthesize messageTextField;
@synthesize progressIndicator;
@synthesize session;
@synthesize running;

-(id)init
{
    return [super initWithWindowNibName:@"SyncMerge"];
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        operationQueue = [[NSOperationQueue alloc] init];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleGoogleAuthFailed:) name:@"MA_Notify_GoogleAuthFailed" object:nil];
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{
    // Tell the preferences controller we're not running. The prefs window will be responsible
    // for displaying an alert.
    running = NO;
}

-(IBAction)cancel:(id)sender
{
    [self close];
    [[NSApplication sharedApplication] endModalSession:session];
}

-(void)startSync {
	running = YES;
	[messageTextField setStringValue:NSLocalizedString(@"Fetching Google Reader Subscriptions...", nil)];
    [progressIndicator startAnimation:self];
	
	//TOFIX
	/*
	GRSSubscriptionOperation * op = [[GRSSubscriptionOperation alloc] init];
    [op setDelegate:self];
    [operationQueue addOperation:op];
    [op release];
	 */
}


-(void)beginMerge
{
    running = YES;
    
    [messageTextField setStringValue: NSLocalizedString(@"Fetching Google Reader data...", nil)];
    [progressIndicator startAnimation:self];
    
    NSArray * folders = [[NSApp delegate] folders];
    NSMutableArray * rssFolders = [NSMutableArray array];
    
    for ( Folder * f in folders)
        if (IsRSSFolder(f)) [rssFolders addObject:f];
    
	//TOFIX
	/*
    [GRSMergeOperation setFetchFlag:YES];
    GRSMergeOperation * op = [[GRSMergeOperation alloc] init];
    [op setDelegate:self];
    [op setFolders:rssFolders];
    [operationQueue addOperation:op];
    [op release];
	 */
}

-(void)mergeDidComplete
{
    if (self)
    {
        running = NO;
        [progressIndicator stopAnimation:self];
        [self close];
        [[NSApplication sharedApplication] endModalSession:session];
    }
}

-(void)statusMessageChanged:(NSString *)message
{
    [messageTextField setStringValue:message];
}

-(void)dealloc
{
    [messageTextField release];
    [progressIndicator release];
    [operationQueue release];
    [super dealloc];
}

@end
