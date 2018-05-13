//
//  WindowController.m
//  MMTabBarView Demo
//
//  Created by John Pannell on 4/6/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

@import MMTabBarView;

#import "DemoWindowController.h"
#import "DemoFakeModel.h"

@interface DemoWindowController (PRIVATE)
- (void)configureTabBarInitially;
@end

@interface DemoWindowController(ConfigActions)

// tab bar config
- (IBAction)configStyle:(id)sender;
- (IBAction)configOnlyShowCloseOnHover:(id)sender;
- (IBAction)configCanCloseOnlyTab:(id)sender;
- (IBAction)configDisableTabClose:(id)sender;
- (IBAction)configAllowBackgroundClosing:(id)sender;
- (IBAction)configHideForSingleTab:(id)sender;
- (IBAction)configAddTabButton:(id)sender;
- (IBAction)configTabMinWidth:(id)sender;
- (IBAction)configTabMaxWidth:(id)sender;
- (IBAction)configTabOptimumWidth:(id)sender;
- (IBAction)configTabSizeToFit:(id)sender;
- (IBAction)configTearOffStyle:(id)sender;
- (IBAction)configUseOverflowMenu:(id)sender;
- (IBAction)configAutomaticallyAnimates:(id)sender;
- (IBAction)configAllowsScrubbing:(id)sender;

@end

@implementation DemoWindowController

- (void)awakeFromNib {

	[[NSUserDefaults standardUserDefaults] registerDefaults:
	 [NSDictionary dictionaryWithObjectsAndKeys:
		  @"Card", @"Style",
		  @"Horizontal", @"Orientation",
		  @"Miniwindow", @"Tear-Off",
		  @"100", @"TabMinWidth",
		  @"280", @"TabMaxWidth",
		  @"130", @"TabOptimalWidth",
		  [NSNumber numberWithBool:YES], @"UseOverflowMenu",
          [NSNumber numberWithBool:YES], @"AllowBackgroundClosing",
		  nil]];

	// toolbar
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"DemoToolbar"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
    [toolbar setShowsBaselineSeparator:NO];
    
	[[self window] setToolbar:toolbar];

    [tabBar addObserver:self forKeyPath:@"orientation" options:NSKeyValueObservingOptionNew context:NULL];

	// remove any tabs present in the nib
    for (NSTabViewItem *item in [tabView tabViewItems]) {
		[tabView removeTabViewItem:item];
	}

    [self configureTabBarInitially];

	// open drawer
	[drawer toggle:self];
}

- (void)addNewTabWithTitle:(NSString *)aTitle {

	DemoFakeModel *newModel = [[DemoFakeModel alloc] init];
    [newModel setTitle:aTitle];
	NSTabViewItem *newItem = [[NSTabViewItem alloc] initWithIdentifier:newModel];
	[tabView addTabViewItem:newItem];
    [tabView selectTabViewItem:newItem];    
}

- (void)addDefaultTabs {

    [self addNewTabWithTitle:@"Tab"];
    [self addNewTabWithTitle:@"Bar"];
    [self addNewTabWithTitle:@"View"];           
}

- (IBAction)addNewTab:(id)sender {
    [self addNewTabWithTitle:@"Untitled"];
}

- (IBAction)closeTab:(id)sender {

    NSTabViewItem *tabViewItem = [tabView selectedTabViewItem];

    if (([tabBar delegate]) && ([[tabBar delegate] respondsToSelector:@selector(tabView:shouldCloseTabViewItem:)])) {
        if (![[tabBar delegate] tabView:tabView shouldCloseTabViewItem:tabViewItem]) {
            return;
        }
    }
    
    if (([tabBar delegate]) && ([[tabBar delegate] respondsToSelector:@selector(tabView:willCloseTabViewItem:)])) {
        [[tabBar delegate] tabView:tabView willCloseTabViewItem:tabViewItem];
    }
    
    [tabView removeTabViewItem:tabViewItem];
    
    if (([tabBar delegate]) && ([[tabBar delegate] respondsToSelector:@selector(tabView:didCloseTabViewItem:)])) {
        [[tabBar delegate] tabView:tabView didCloseTabViewItem:tabViewItem];
    }
}

- (void)setIconNamed:(id)sender {
	NSString *iconName = [sender titleOfSelectedItem];
	if ([iconName isEqualToString:@"None"]) {
		[[[tabView selectedTabViewItem] identifier] setValue:nil forKeyPath:@"icon"];
		[[[tabView selectedTabViewItem] identifier] setValue:@"None" forKeyPath:@"iconName"];
	} else {
		NSImage *newIcon = [NSImage imageNamed:iconName];
		[[[tabView selectedTabViewItem] identifier] setValue:newIcon forKeyPath:@"icon"];
		[[[tabView selectedTabViewItem] identifier] setValue:iconName forKeyPath:@"iconName"];
	}
}

- (void)setObjectCount:(id)sender {
	[[[tabView selectedTabViewItem] identifier] setValue:[NSNumber numberWithInteger:[sender integerValue]] forKeyPath:@"objectCount"];
}

- (void)setObjectCountColor:(id)sender {
	[[[tabView selectedTabViewItem] identifier] setValue:(id)[sender color] forKeyPath:@"objectCountColor"];
}

- (IBAction)showObjectCountAction:(id)sender {
	[[[tabView selectedTabViewItem] identifier] setValue:[NSNumber numberWithBool:[sender state]] forKeyPath:@"showObjectCount"];
}

- (IBAction)isProcessingAction:(id)sender {
	[[[tabView selectedTabViewItem] identifier] setValue:[NSNumber numberWithBool:[sender state]] forKeyPath:@"isProcessing"];
}

- (IBAction)isEditedAction:(id)sender {
	[[[tabView selectedTabViewItem] identifier] setValue:[NSNumber numberWithBool:[sender state]] forKeyPath:@"isEdited"];
}

- (IBAction)hasLargeImageAction:(id)sender {
    
    if ([sender state] == NSOnState) {
         [[[tabView selectedTabViewItem] identifier] setValue:[NSImage imageNamed:@"largeImage"] forKeyPath:@"largeImage"];
    } else {
        [[[tabView selectedTabViewItem] identifier] setValue:nil forKeyPath:@"largeImage"];
    }
}

- (IBAction)hasCloseButtonAction:(id)sender {
	[[[tabView selectedTabViewItem] identifier] setValue:[NSNumber numberWithBool:[sender state]] forKeyPath:@"hasCloseButton"];
}

- (IBAction)setTabLabel:(id)sender {

	[[[tabView selectedTabViewItem] identifier] setValue:[sender stringValue] forKeyPath:@"title"];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {

    SEL itemAction = [menuItem action];
    
	if (itemAction == @selector(closeTab:)) {
		if (![tabBar canCloseOnlyTab] && ([tabView numberOfTabViewItems] <= 1)) {
			return NO;
		}
    }

	return YES;
}

- (MMTabBarView *)tabBar {
	return tabBar;
}

- (void)windowWillClose:(NSNotification *)note {

    [tabBar removeObserver:self forKeyPath:@"orientation"];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {

    if (menu == [popUp_orientation menu]) {
    
        for (NSMenuItem *anItem in [menu itemArray]) {

            [anItem setEnabled:YES];
            
            if (![tabBar supportsOrientation:MMTabBarHorizontalOrientation] && [anItem tag] == 0)
                [anItem setEnabled:NO];
            
            if (![tabBar supportsOrientation:MMTabBarVerticalOrientation] && [anItem tag] == 1)
                [anItem setEnabled:NO];
        }
    }
}

-(void)_updateForOrientation:(MMTabBarOrientation)newOrientation {

	//change the frame of the tab bar according to the orientation
	NSRect tabBarFrame = [tabBar frame], tabViewFrame = [tabView frame];
	NSRect totalFrame = NSUnionRect(tabBarFrame, tabViewFrame);

    NSSize intrinsicTabBarContentSize = [tabBar intrinsicContentSize];

	if (newOrientation == MMTabBarHorizontalOrientation) {
        if (intrinsicTabBarContentSize.height == NSViewNoInstrinsicMetric)
            intrinsicTabBarContentSize.height = 22;
		tabBarFrame.size.height = [tabBar isTabBarHidden] ? 1 : intrinsicTabBarContentSize.height;
		tabBarFrame.size.width = totalFrame.size.width;
		tabBarFrame.origin.y = totalFrame.origin.y + totalFrame.size.height - tabBarFrame.size.height;
		tabViewFrame.origin.x = 13;
		tabViewFrame.size.width = totalFrame.size.width - 23;
		tabViewFrame.size.height = totalFrame.size.height - tabBarFrame.size.height - 2;
		[tabBar setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
	} else {
		tabBarFrame.size.height = totalFrame.size.height;
		tabBarFrame.size.width = [tabBar isTabBarHidden] ? 1 : 120;
		tabBarFrame.origin.y = totalFrame.origin.y;
		tabViewFrame.origin.x = tabBarFrame.origin.x + tabBarFrame.size.width;
		tabViewFrame.size.width = totalFrame.size.width - tabBarFrame.size.width;
		tabViewFrame.size.height = totalFrame.size.height;
		[tabBar setAutoresizingMask:NSViewHeightSizable];
	}

	tabBarFrame.origin.x = totalFrame.origin.x;
	tabViewFrame.origin.y = totalFrame.origin.y;

	[tabView setFrame:tabViewFrame];
	[tabBar setFrame:tabBarFrame];

    [popUp_orientation selectItemWithTag:newOrientation];
	[[self window] display];

    if (newOrientation == MMTabBarHorizontalOrientation) {
        [[NSUserDefaults standardUserDefaults] setObject:[[popUp_orientation itemAtIndex:0] title] forKey:@"Orientation"];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:[[popUp_orientation itemAtIndex:1] title] forKey:@"Orientation"];
    }
}

#pragma mark -
#pragma mark KVO 

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

    if (object == tabBar) {
        if ([keyPath isEqualToString:@"orientation"]) {
            [self _updateForOrientation:[[change objectForKey:NSKeyValueChangeNewKey] unsignedIntegerValue]];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -
#pragma mark ---- tab bar config ----

- (void)configStyle:(id)sender {

	[tabBar setStyleNamed:[sender titleOfSelectedItem]];
    
	[[NSUserDefaults standardUserDefaults] setObject:[sender titleOfSelectedItem]
	 forKey:@"Style"];
    
    [self _updateForOrientation:[tabBar orientation]];
}

- (void)configOnlyShowCloseOnHover:(id)sender {
	[tabBar setOnlyShowCloseOnHover:[sender state]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[sender state]]
	 forKey:@"OnlyShowCloserOnHover"];
}

- (void)configCanCloseOnlyTab:(id)sender {
	[tabBar setCanCloseOnlyTab:[sender state]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[sender state]]
	 forKey:@"CanCloseOnlyTab"];
}

- (void)configDisableTabClose:(id)sender {
	[tabBar setDisableTabClose:[sender state]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[sender state]]
	 forKey:@"DisableTabClose"];
}

- (void)configAllowBackgroundClosing:(id)sender {
	[tabBar setAllowsBackgroundTabClosing:[sender state]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[sender state]]
	 forKey:@"AllowBackgroundClosing"];
}

- (void)configHideForSingleTab:(id)sender {
	[tabBar setHideForSingleTab:[sender state]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[sender state]]
	 forKey:@"HideForSingleTab"];
}

- (void)configAddTabButton:(id)sender {
	[tabBar setShowAddTabButton:[sender state]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[sender state]]
	 forKey:@"ShowAddTabButton"];
}

- (void)configTabMinWidth:(id)sender {
	if ([tabBar buttonOptimumWidth] < [sender integerValue]) {
		[tabBar setButtonMinWidth:[tabBar buttonOptimumWidth]];
		[sender setIntegerValue:[tabBar buttonOptimumWidth]];
		return;
	}

	[tabBar setButtonMinWidth:[sender integerValue]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:[sender integerValue]]
	 forKey:@"TabMinWidth"];
}

- (void)configTabMaxWidth:(id)sender {
	if ([tabBar buttonOptimumWidth] > [sender integerValue]) {
		[tabBar setButtonMaxWidth:[tabBar buttonOptimumWidth]];
		[sender setIntegerValue:[tabBar buttonOptimumWidth]];
		return;
	}

	[tabBar setButtonMaxWidth:[sender integerValue]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:[sender integerValue]]
	 forKey:@"TabMaxWidth"];
}

- (void)configTabOptimumWidth:(id)sender {
	if ([tabBar buttonMaxWidth] < [sender integerValue]) {
		[tabBar setButtonOptimumWidth:[tabBar buttonMaxWidth]];
		[sender setIntegerValue:[tabBar buttonMaxWidth]];
		return;
	}

	if ([tabBar buttonMinWidth] > [sender integerValue]) {
		[tabBar setButtonOptimumWidth:[tabBar buttonMinWidth]];
		[sender setIntegerValue:[tabBar buttonMinWidth]];
		return;
	}

	[tabBar setButtonOptimumWidth:[sender integerValue]];
}

- (void)configTabSizeToFit:(id)sender {
	[tabBar setSizeButtonsToFit:[sender state]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[sender integerValue]]
	 forKey:@"SizeToFit"];
}

- (void)configTearOffStyle:(id)sender {
	[tabBar setTearOffStyle:([sender indexOfSelectedItem] == 0) ? MMTabBarTearOffAlphaWindow : MMTabBarTearOffMiniwindow];

	[[NSUserDefaults standardUserDefaults] setObject:[sender title]
	 forKey:@"Tear-Off"];
}

- (void)configUseOverflowMenu:(id)sender {
	[tabBar setUseOverflowMenu:[sender state]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[sender integerValue]]
	 forKey:@"UseOverflowMenu"];
}

- (void)configAutomaticallyAnimates:(id)sender {
	[tabBar setAutomaticallyAnimates:[sender state]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[sender integerValue]]
	 forKey:@"AutomaticallyAnimates"];
}

- (void)configAllowsScrubbing:(id)sender {
	[tabBar setAllowsScrubbing:[sender state]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[sender integerValue]]
	 forKey:@"AllowScrubbing"];
}

#pragma mark -
#pragma mark ---- delegate ----

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	// need to update bound values to match the selected tab
	if ([[tabViewItem identifier] respondsToSelector:@selector(objectCount)]) {
		[objectCounterField setIntegerValue:[[tabViewItem identifier] objectCount]];
	}
    
	if ([[tabViewItem identifier] respondsToSelector:@selector(objectCountColor)]) {
        if ([[tabViewItem identifier] objectCountColor] != nil)
            [objectCounterColorWell setColor:[[tabViewItem identifier] objectCountColor]];
        else
            [objectCounterColorWell setColor:[MMTabBarButtonCell defaultObjectCountColor]];
	}    

	if ([[tabViewItem identifier] respondsToSelector:@selector(isProcessing)]) {
		[isProcessingButton setState:[[tabViewItem identifier] isProcessing]];
	}

	if ([[tabViewItem identifier] respondsToSelector:@selector(isEdited)]) {
		[isEditedButton setState:[[tabViewItem identifier] isEdited]];
	}

	if ([[tabViewItem identifier] respondsToSelector:@selector(hasCloseButton)]) {
		[hasCloserButton setState:[[tabViewItem identifier] hasCloseButton]];
	}

	if ([[tabViewItem identifier] respondsToSelector:@selector(showObjectCount)]) {
		[showObjectCountButton setState:[[tabViewItem identifier] showObjectCount]];
	}
    
	if ([[tabViewItem identifier] respondsToSelector:@selector(largeImage)]) {
		[hasLargeImageButton setState:[[tabViewItem identifier] largeImage] != nil];
	}

	if ([[tabViewItem identifier] respondsToSelector:@selector(iconName)]) {
		NSString *newName = [[tabViewItem identifier] iconName];
		if (newName) {
			[iconButton selectItem:[[iconButton menu] itemWithTitle:newName]];
		} else {
			[iconButton selectItem:[[iconButton menu] itemWithTitle:@"None"]];
		}
	}
    
    if ([[tabViewItem identifier] respondsToSelector:@selector(title)]) {
        [tabField setStringValue:[[tabViewItem identifier] title]];
    }
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem {
	if ([[tabViewItem label] isEqualToString:@"Drake"]) {
		NSAlert *drakeAlert = [NSAlert alertWithMessageText:@"No Way!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"I refuse to close a tab named \"Drake\""];
		[drakeAlert beginSheetModalForWindow:[NSApp keyWindow] modalDelegate:nil didEndSelector:nil contextInfo:nil];
		return NO;
	}
	return YES;
}

- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem {
	NSLog(@"didCloseTabViewItem: %@", [tabViewItem label]);
}

- (void)tabView:(NSTabView *)aTabView didMoveTabViewItem:(NSTabViewItem *)tabViewItem toIndex:(NSUInteger)index
{
    NSLog(@"tab view did move tab view item %@ to index:%ld",[tabViewItem label],index);
}

- (void)addNewTabToTabView:(NSTabView *)aTabView {
    [self addNewTab:aTabView];
}

- (NSArray *)allowedDraggedTypesForTabView:(NSTabView *)aTabView {
	return [NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil];
}

- (BOOL)tabView:(NSTabView *)aTabView acceptedDraggingInfo:(id <NSDraggingInfo>)draggingInfo onTabViewItem:(NSTabViewItem *)tabViewItem {
	NSLog(@"acceptedDraggingInfo: %@ onTabViewItem: %@", [[draggingInfo draggingPasteboard] stringForType:[[[draggingInfo draggingPasteboard] types] objectAtIndex:0]], [tabViewItem label]);
    return YES;
}

- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem {
	NSLog(@"menuForTabViewItem: %@", [tabViewItem label]);
	return nil;
}

- (BOOL)tabView:(NSTabView *)aTabView shouldAllowTabViewItem:(NSTabViewItem *)tabViewItem toLeaveTabBarView:(MMTabBarView *)tabBarView {
    return YES;
}

- (BOOL)tabView:(NSTabView*)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem inTabBarView:(MMTabBarView *)tabBarView {
	return YES;
}

- (NSDragOperation)tabView:(NSTabView*)aTabView validateDrop:(id<NSDraggingInfo>)sender proposedItem:(NSTabViewItem *)tabViewItem proposedIndex:(NSUInteger)proposedIndex inTabBarView:(MMTabBarView *)tabBarView {

    return NSDragOperationMove;
}

- (NSDragOperation)tabView:(NSTabView *)aTabView validateSlideOfProposedItem:(NSTabViewItem *)tabViewItem proposedIndex:(NSUInteger)proposedIndex inTabBarView:(MMTabBarView *)tabBarView {

    return NSDragOperationMove;
}

- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBarView:(MMTabBarView *)tabBarView {
	NSLog(@"didDropTabViewItem: %@ inTabBarView: %@", [tabViewItem label], tabBarView);
}

- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(NSUInteger *)styleMask {
	// grabs whole window image
	NSImage *viewImage = [[NSImage alloc] init];
	NSRect contentFrame = [[[self window] contentView] frame];
	[[[self window] contentView] lockFocus];
	NSBitmapImageRep *viewRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:contentFrame];
	[viewImage addRepresentation:viewRep];
	[[[self window] contentView] unlockFocus];

	// grabs snapshot of dragged tabViewItem's view (represents content being dragged)
	NSView *viewForImage = [tabViewItem view];
	NSRect viewRect = [viewForImage frame];
	NSImage *tabViewImage = [[NSImage alloc] initWithSize:viewRect.size];
	[tabViewImage lockFocus];
	[viewForImage drawRect:[viewForImage bounds]];
	[tabViewImage unlockFocus];

	[viewImage lockFocus];
	NSPoint tabOrigin = [tabView frame].origin;
	tabOrigin.x += 10;
	tabOrigin.y += 13;
    [tabViewImage drawAtPoint:tabOrigin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
//	[tabViewImage compositeToPoint:tabOrigin operation:NSCompositeSourceOver];
	[viewImage unlockFocus];

    MMTabBarView *tabBarView = (MMTabBarView *)[aTabView delegate];
    
	//draw over where the tab bar would usually be
	NSRect tabFrame = [tabBar frame];
	[viewImage lockFocus];
	[[NSColor windowBackgroundColor] set];
	NSRectFill(tabFrame);
	//draw the background flipped, which is actually the right way up
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform scaleXBy:1.0 yBy:-1.0];
	[transform concat];
	tabFrame.origin.y = -tabFrame.origin.y - tabFrame.size.height;
	[[tabBarView style] drawBezelOfTabBarView:tabBarView inRect:tabFrame];
	[transform invert];
	[transform concat];

	[viewImage unlockFocus];

	if ([tabBarView orientation] == MMTabBarHorizontalOrientation) {
		offset->width = [tabBarView leftMargin];
		offset->height = 22;
	} else {
		offset->width = 0;
		offset->height = 22 + [tabBarView topMargin];
	}

	if (styleMask) {
		*styleMask = NSTitledWindowMask | NSTexturedBackgroundWindowMask;
	}

	return viewImage;
}

- (MMTabBarView *)tabView:(NSTabView *)aTabView newTabBarViewForDraggedTabViewItem:(NSTabViewItem *)tabViewItem atPoint:(NSPoint)point {
	NSLog(@"newTabBarViewForDraggedTabViewItem: %@ atPoint: %@", [tabViewItem label], NSStringFromPoint(point));

	//create a new window controller with no tab items
	DemoWindowController *controller = [[DemoWindowController alloc] initWithWindowNibName:@"DemoWindow"];
    
    MMTabBarView *tabBarView = (MMTabBarView *)[aTabView delegate];
    
	id <MMTabStyle> style = [tabBarView style];

	NSRect windowFrame = [[controller window] frame];
	point.y += windowFrame.size.height - [[[controller window] contentView] frame].size.height;
	point.x -= [style leftMarginForTabBarView:tabBarView];

	[[controller window] setFrameTopLeftPoint:point];
	[[controller tabBar] setStyle:style];

	return [controller tabBar];
}

- (void)tabView:(NSTabView *)aTabView closeWindowForLastTabViewItem:(NSTabViewItem *)tabViewItem {
	NSLog(@"closeWindowForLastTabViewItem: %@", [tabViewItem label]);
	[[self window] close];
}

- (void)tabView:(NSTabView *)aTabView tabBarViewDidHide:(MMTabBarView *)tabBarView {
	NSLog(@"tabBarViewDidHide: %@", tabBarView);
}

- (void)tabView:(NSTabView *)aTabView tabBarViewDidUnhide:(MMTabBarView *)tabBarView {
	NSLog(@"tabBarViewDidUnhide: %@", tabBarView);
}

- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem {
	return [tabViewItem label];
}

- (NSString *)accessibilityStringForTabView:(NSTabView *)aTabView objectCount:(NSInteger)objectCount {
	return (objectCount == 1) ? @"item" : @"items";
}

#pragma mark -
#pragma mark ---- toolbar ----

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];

	if ([itemIdentifier isEqualToString:@"TabField"]) {
		[item setPaletteLabel:@"Tab Label"];
		[item setLabel:@"Tab Label"];
		[item setView:tabField];
		[item setMinSize:NSMakeSize(100, [tabField frame].size.height)];
		[item setMaxSize:NSMakeSize(500, [tabField frame].size.height)];
	} else if ([itemIdentifier isEqualToString:@"DrawerItem"]) {
		[item setPaletteLabel:@"Configuration"];
		[item setLabel:@"Configuration"];
		[item setToolTip:@"Configuration"];
		[item setImage:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
		[item setTarget:drawer];
		[item setAction:@selector(toggle:)];
	}

	return item;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
	return [NSArray arrayWithObjects:@"TabField",
			NSToolbarFlexibleSpaceItemIdentifier,
			@"DrawerItem",
			nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
	return [NSArray arrayWithObjects:@"TabField",
			NSToolbarFlexibleSpaceItemIdentifier,
			@"DrawerItem",
			nil];
}

- (IBAction)toggleToolbar:(id)sender {
	[[[self window] toolbar] setVisible:![[[self window] toolbar] isVisible]];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
	return YES;
}

- (void)configureTabBarInitially {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[popUp_style selectItemWithTitle:[defaults stringForKey:@"Style"]];
	[popUp_orientation selectItemWithTitle:[defaults stringForKey:@"Orientation"]];
	[popUp_tearOff selectItemWithTitle:[defaults stringForKey:@"Tear-Off"]];

	[button_onlyShowCloseOnHover setState:[defaults boolForKey:@"OnlyShowCloseOnHover"]];
	[button_canCloseOnlyTab setState:[defaults boolForKey:@"CanCloseOnlyTab"]];
	[button_disableTabClosing setState:[defaults boolForKey:@"DisableTabClosing"]];
    [button_allowBackgroundClosing setState:[defaults boolForKey:@"AllowBackgroundClosing"]];
	[button_hideForSingleTab setState:[defaults boolForKey:@"HideForSingleTab"]];
	[button_showAddTab setState:[defaults boolForKey:@"ShowAddTabButton"]];
	[button_sizeToFit setState:[defaults boolForKey:@"SizeToFit"]];
	[button_useOverflow setState:[defaults boolForKey:@"UseOverflowMenu"]];
	[button_automaticallyAnimate setState:[defaults boolForKey:@"AutomaticallyAnimates"]];
	[button_allowScrubbing setState:[defaults boolForKey:@"AllowScrubbing"]];

	[self configStyle:popUp_style];
    [tabBar setOrientation:[popUp_orientation selectedTag]];

    [self configOnlyShowCloseOnHover:button_onlyShowCloseOnHover];    
	[self configCanCloseOnlyTab:button_canCloseOnlyTab];
	[self configDisableTabClose:button_disableTabClosing];
	[self configAllowBackgroundClosing:button_allowBackgroundClosing];
	[self configHideForSingleTab:button_hideForSingleTab];
	[self configAddTabButton:button_showAddTab];
	[self configTabMinWidth:textField_minWidth];
	[self configTabMaxWidth:textField_maxWidth];
	[self configTabOptimumWidth:textField_optimumWidth];
	[self configTabSizeToFit:button_sizeToFit];
	[self configTearOffStyle:popUp_tearOff];
	[self configUseOverflowMenu:button_useOverflow];
	[self configAutomaticallyAnimates:button_automaticallyAnimate];
	[self configAllowsScrubbing:button_allowScrubbing];
}
@end
