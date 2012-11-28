//
//  NewPreferencesController.m
//  Vienna
//
//  Created by Steve on 10/15/05.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
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

#import "NewPreferencesController.h"
#include <objc/runtime.h>

@interface NewPreferencesController (Private)
	-(void)selectPane:(NSString *)identifier;
@end

@interface NSToolbar (NSToolbarPrivate)
	-(NSView *)_toolbarView;
@end

@implementation NewPreferencesController

/* init
 * Initialises a new instance of the new PreferencesController object.
 */
-(id)init
{
	if ((self = [super initWithWindowNibName:@"NewPreferences"]) != nil)
	{
		prefsDict = nil;
		prefPanes = nil;
		prefsIdentifiers = nil;
		selectedIdentifier = nil;
	}
	return self;
}

/* awakeFromNib
 * Do the things that only make sense after the window file is loaded.
 */
-(void)awakeFromNib
{
	static BOOL isPrimaryNib = YES;
	
	// We get called for all view NIBs, so don't handle those or we'll stack overflow.
	if (!isPrimaryNib)
		return;
    
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleGoogleAuthFailed:) name:@"MA_Notify_GoogleAuthFailed" object:nil];
	
	// Load the NIBs using the plist to locate them and build the prefIdentifiersArray
	// array of identifiers.
	NSBundle * thisBundle = [NSBundle bundleForClass:[self class]];
	NSString * pathToPList = [thisBundle pathForResource:@"Preferences.plist" ofType:@""];
	NSAssert(pathToPList != nil, @"Missing Preferences.plist in build");

	// Load the dictionary and sort the keys by name to create the ordered
	// identifiers for each pane.
	prefsDict = [[NSDictionary dictionaryWithContentsOfFile:pathToPList] retain];
	prefsIdentifiers = [[[prefsDict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] retain];
	NSAssert([prefsIdentifiers count] > 0, @"Empty Preferences.plist file");

	// Set the title
	[prefWindow setTitle:NSLocalizedString(@"Preferences", nil)];

	// Create the toolbar
	NSToolbar * toolbar = [[NSToolbar alloc] initWithIdentifier:@"PrefsToolbar"];
	[toolbar setAllowsUserCustomization:NO];
	[toolbar setAutosavesConfiguration:NO];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	[toolbar setDelegate:self];
	[prefWindow setToolbar:toolbar];
	[toolbar release];

	// Hide the toolbar pill button
	[[prefWindow standardWindowButton:NSWindowToolbarButton] setFrame:NSZeroRect];

	// Create an empty view
	blankView = [[NSView alloc] initWithFrame:[[prefWindow contentView] frame]];
	
	// Array of pane objects
	prefPanes = [[NSMutableDictionary alloc] init];
	
	// Center the window
	[prefWindow center];
	
	// Primary NIB is done.
	isPrimaryNib = NO;
	
	// Select the first pane
	[self selectPane:[prefsIdentifiers objectAtIndex:0]];
}

-(void)handleGoogleAuthFailed:(NSNotification *)nc
{    
    if ([[self window] isVisible]) 
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Google Authentication Failed"];
        [alert setInformativeText:@"Please check your Google username and password in Vienna's preferences."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
    }
}

/* itemForItemIdentifier
 * Creates and returns an NSToolbarItem for the specified identifier.
 */
-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem * newItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
	NSDictionary * prefsItem = [prefsDict objectForKey:itemIdentifier];
	[newItem setLabel:NSLocalizedString([prefsItem valueForKey:@"Title"], nil)];
	[newItem setTarget:self];
	[newItem setAction:@selector(prefsPaneSelection:)];
	
	NSString * prefImage = [prefsItem valueForKey:@"Image"];
	if (prefImage != nil)
		[newItem setImage:[NSImage imageNamed:prefImage]];
	return newItem;
}

/* prefsPaneSelection
 * Change the preference pane.
 */
-(IBAction)prefsPaneSelection:(id)sender
{
	NSToolbar * toolbar = [prefWindow toolbar];
	[self selectPane:[toolbar selectedItemIdentifier]];
}

/* selectPane
 * Activate the preference pane with the given identifier. Resize the main
 * window to accommodate the pane contents.
 */
-(void)selectPane:(NSString *)identifier
{	
	NSDictionary * prefItem = [prefsDict objectForKey:identifier];
	NSAssert(prefItem != nil, @"Not a valid preference identifier");

	// Skip if we're already the selected pane
	if ([identifier isEqualToString:selectedIdentifier])
		return;
	
	// Make sure the associated class has been instantiated
	id prefPane = [prefPanes objectForKey:identifier];
	if (prefPane == nil)
	{
		NSString * className = [prefItem objectForKey:@"ClassName"];
		if (className == nil)
		{
			NSLog(@"Missing ClassName attribute from preference %@", identifier);
			return;
		}
		Class classObject = objc_getClass([className cStringUsingEncoding:NSASCIIStringEncoding]);
		if (classObject == nil)
		{
			NSLog(@"Cannot find class '%@' in preference %@", className, identifier);
			return;
		}
		prefPane = [[classObject alloc] init];
		if (prefPane == nil)
			return;

		// This is the only safe time to add the pane to the array
		[prefPanes setObject:prefPane forKey:identifier];
		[prefPane release];
	}

	// If we get this far, OK to select the new item. Otherwise we're staying
	// on the old one.
	NSToolbar * toolbar = [prefWindow toolbar];
	[toolbar setSelectedItemIdentifier:identifier];

	if (selectedIdentifier != nil)
	{
		// Restore the pref pane to its original window
		id oldPrefPane = [prefPanes objectForKey:selectedIdentifier];
		NSView * oldView = [[prefWindow contentView] retain];
		[prefWindow setContentView:nil];
		[[oldPrefPane window] setContentView:oldView];
		[oldView release];
	}
	
	// Now pull the new pane into view.
	[prefWindow setContentView:blankView];
	[prefWindow display];

	// retain here, release after setting contentView
	NSWindow * prefPaneWindow = [prefPane window];
	NSView * theView = [[prefPaneWindow contentView] retain];
	[prefPaneWindow setContentView:nil];

	// Compute the new frame window height and width
	NSRect windowFrame = [NSWindow contentRectForFrameRect:[prefWindow frame] styleMask:[prefWindow styleMask]];

	float newWindowHeight = NSHeight([theView frame]) + NSHeight([[toolbar _toolbarView] frame]);
	float newWindowWidth = NSWidth([theView frame]);

	NSRect newFrameRect = NSMakeRect(NSMinX(windowFrame), NSMaxY(windowFrame) - newWindowHeight, newWindowWidth, newWindowHeight);
	NSRect newWindowFrame = [NSWindow frameRectForContentRect:newFrameRect styleMask:[prefWindow styleMask]];
	[prefWindow setFrame:newWindowFrame display:YES animate:[prefWindow isVisible]];

	[prefWindow setContentView:theView];
	[theView release]; // balance the retain above

	// Remember this pane identifier.
	[selectedIdentifier release];
	selectedIdentifier = [identifier retain];
}

/* validateToolbarItem
 * Every single toolbar item should be enabled.
 */
-(BOOL)validateToolbarItem:(NSToolbarItem*)toolbarItem
{
	return YES;
}

/* toolbarAllowedItemIdentifiers
 * The allowed toolbar items. These are all preference items.
 */
-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return prefsIdentifiers;
}

/* toolbarSelectableItemIdentifiers
 * All the selectable toolbar items. This is everything, as usual.
 */
-(NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return prefsIdentifiers;
}

/* toolbarDefaultItemIdentifiers
 * The default toolbar items. These are all preference items.
 */
-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return prefsIdentifiers;
}

/* dealloc
 * Clean up behind ourselves.
 */
-(void)dealloc
{
	[selectedIdentifier release];
	[blankView release];
	[prefPanes release];
	[prefsIdentifiers release];
	[prefsDict release];
	[super dealloc];
}
@end
