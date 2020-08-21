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

	[NSUserDefaults.standardUserDefaults registerDefaults:
	 [NSDictionary<NSString*, id> dictionaryWithObjectsAndKeys:
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
    
	[self.window setToolbar:toolbar];

    [tabBar addObserver:self forKeyPath:@"orientation" options:NSKeyValueObservingOptionNew context:NULL];

	// remove any tabs present in the nib
    for (NSTabViewItem *item in tabView.tabViewItems) {
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

    NSTabViewItem *tabViewItem = tabView.selectedTabViewItem;

    if ((tabBar.delegate) && ([tabBar.delegate respondsToSelector:@selector(tabView:shouldCloseTabViewItem:)])) {
        if (![tabBar.delegate tabView:tabView shouldCloseTabViewItem:tabViewItem]) {
            return;
        }
    }
    
    if ((tabBar.delegate) && ([tabBar.delegate respondsToSelector:@selector(tabView:willCloseTabViewItem:)])) {
        [tabBar.delegate tabView:tabView willCloseTabViewItem:tabViewItem];
    }
    
    [tabView removeTabViewItem:tabViewItem];
    
    if ((tabBar.delegate) && ([tabBar.delegate respondsToSelector:@selector(tabView:didCloseTabViewItem:)])) {
        [tabBar.delegate tabView:tabView didCloseTabViewItem:tabViewItem];
    }
}

- (void)setIconNamed:(id)sender {
	NSString *iconName = [(NSPopUpButton*) sender titleOfSelectedItem];
	if ([iconName isEqualToString:@"None"]) {
		DemoFakeModel* const tabBarItem = tabView.selectedTabViewItem.identifier;
		tabBarItem.icon = nil;
		tabBarItem.iconName = @"None";
	} else {
		DemoFakeModel* const tabBarItem = tabView.selectedTabViewItem.identifier;
		NSImage *newIcon = [NSImage imageNamed:iconName];
		tabBarItem.icon = newIcon;
		tabBarItem.iconName = iconName;
	}
}

- (void)setObjectCount:(id)sender {
	DemoFakeModel* const tabBarItem = tabView.selectedTabViewItem.identifier;
	[tabBarItem setValue:[NSNumber numberWithInteger:[(NSControl*) sender integerValue]] forKeyPath:@"objectCount"];
}

- (void)setObjectCountColor:(id)sender {
	DemoFakeModel* const tabBarItem = tabView.selectedTabViewItem.identifier;
	[tabBarItem setValue:(id)[(NSColorWell*) sender color] forKeyPath:@"objectCountColor"];
}

- (IBAction)showObjectCountAction:(id)sender {
	DemoFakeModel* const tabBarItem = tabView.selectedTabViewItem.identifier;
	[tabBarItem setValue:[NSNumber numberWithBool:[(NSButton*) sender state]] forKeyPath:@"showObjectCount"];
}

- (IBAction)isProcessingAction:(id)sender {
	DemoFakeModel* const tabBarItem = tabView.selectedTabViewItem.identifier;
	[tabBarItem setValue:[NSNumber numberWithBool:[(NSButton*) sender state]] forKeyPath:@"isProcessing"];
}

- (IBAction)isEditedAction:(id)sender {
	DemoFakeModel* const tabBarItem = tabView.selectedTabViewItem.identifier;
	[tabBarItem setValue:[NSNumber numberWithBool:[(NSButton*) sender state]] forKeyPath:@"isEdited"];
}

- (IBAction)hasLargeImageAction:(id)sender {
    
	DemoFakeModel* const tabBarItem = tabView.selectedTabViewItem.identifier;
    if ([(NSButton*) sender state] == NSOnState) {
         [tabBarItem setValue:[NSImage imageNamed:@"largeImage"] forKeyPath:@"largeImage"];
    } else {
        [tabBarItem setValue:nil forKeyPath:@"largeImage"];
    }
}

- (IBAction)hasCloseButtonAction:(id)sender {
	DemoFakeModel* const tabBarItem = tabView.selectedTabViewItem.identifier;
	[tabBarItem setValue:[NSNumber numberWithBool:[(NSButton*) sender state]] forKeyPath:@"hasCloseButton"];
}

- (IBAction)setTabLabel:(id)sender {

	DemoFakeModel* const tabBarItem = tabView.selectedTabViewItem.identifier;
	[tabBarItem setValue:[(NSControl*) sender stringValue] forKeyPath:@"title"];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {

    SEL itemAction = menuItem.action;
    
	if (itemAction == @selector(closeTab:)) {
		if (!tabBar.canCloseOnlyTab && (tabView.numberOfTabViewItems <= 1)) {
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

    if (menu == popUp_orientation.menu) {
    
        for (NSMenuItem *anItem in menu.itemArray) {

            [anItem setEnabled:YES];
            
            if (![tabBar supportsOrientation:MMTabBarHorizontalOrientation] && anItem.tag == 0)
                [anItem setEnabled:NO];
            
            if (![tabBar supportsOrientation:MMTabBarVerticalOrientation] && anItem.tag == 1)
                [anItem setEnabled:NO];
        }
    }
}

-(void)_updateForOrientation:(MMTabBarOrientation)newOrientation {

	//change the frame of the tab bar according to the orientation
	NSRect tabBarFrame = tabBar.frame, tabViewFrame = tabView.frame;
	NSRect totalFrame = NSUnionRect(tabBarFrame, tabViewFrame);

    NSSize intrinsicTabBarContentSize = tabBar.intrinsicContentSize;

	if (newOrientation == MMTabBarHorizontalOrientation) {
        if (intrinsicTabBarContentSize.height == NSViewNoInstrinsicMetric)
            intrinsicTabBarContentSize.height = 22;
		tabBarFrame.size.height = tabBar.isTabBarHidden ? 1 : intrinsicTabBarContentSize.height;
		tabBarFrame.size.width = totalFrame.size.width;
		tabBarFrame.origin.y = totalFrame.origin.y + totalFrame.size.height - tabBarFrame.size.height;
		tabViewFrame.origin.x = 13;
		tabViewFrame.size.width = totalFrame.size.width - 23;
		tabViewFrame.size.height = totalFrame.size.height - tabBarFrame.size.height - 2;
		[tabBar setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
	} else {
		tabBarFrame.size.height = totalFrame.size.height;
		tabBarFrame.size.width = tabBar.isTabBarHidden ? 1 : 120;
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
	[self.window display];

    if (newOrientation == MMTabBarHorizontalOrientation) {
        [NSUserDefaults.standardUserDefaults setObject:[[popUp_orientation itemAtIndex:0] title] forKey:@"Orientation"];
    } else {
        [NSUserDefaults.standardUserDefaults setObject:[[popUp_orientation itemAtIndex:1] title] forKey:@"Orientation"];
    }
}

#pragma mark -
#pragma mark KVO 

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {

    if (object == tabBar) {
        if ([keyPath isEqualToString:@"orientation"]) {
            [self _updateForOrientation:[(NSNumber*) [change objectForKey:NSKeyValueChangeNewKey] unsignedIntegerValue]];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -
#pragma mark ---- tab bar config ----

- (void)configStyle:(id)sender {
	NSString* const string = [(NSPopUpButton*) sender titleOfSelectedItem];
	if (string == nil) {
		return;
	}

	[tabBar setStyleNamed:string];
    
	[NSUserDefaults.standardUserDefaults setObject:string
	 forKey:@"Style"];
    
    [self _updateForOrientation:tabBar.orientation];
}

- (void)configOnlyShowCloseOnHover:(id)sender {
	NSControlStateValue const state = [(NSButton*) sender state];

	[tabBar setOnlyShowCloseOnHover:state];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:state]
	 forKey:@"OnlyShowCloserOnHover"];
}

- (void)configCanCloseOnlyTab:(id)sender {
	NSControlStateValue const state = [(NSButton*) sender state];

	[tabBar setCanCloseOnlyTab:state];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:state]
	 forKey:@"CanCloseOnlyTab"];
}

- (void)configDisableTabClose:(id)sender {
	NSControlStateValue const state = [(NSButton*) sender state];

	[tabBar setDisableTabClose:state];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:state]
	 forKey:@"DisableTabClose"];
}

- (void)configAllowBackgroundClosing:(id)sender {
	NSControlStateValue const state = [(NSButton*) sender state];

	[tabBar setAllowsBackgroundTabClosing:state];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:state]
	 forKey:@"AllowBackgroundClosing"];
}

- (void)configHideForSingleTab:(id)sender {
	NSControlStateValue const state = [(NSButton*) sender state];

	[tabBar setHideForSingleTab:state];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:state]
	 forKey:@"HideForSingleTab"];
}

- (void)configAddTabButton:(id)sender {
	NSControlStateValue const state = [(NSButton*) sender state];

	[tabBar setShowAddTabButton:state];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:state]
	 forKey:@"ShowAddTabButton"];
}

- (void)configTabMinWidth:(id)sender {
	NSInteger const value = [(NSControl*) sender integerValue];
	if (tabBar.buttonOptimumWidth < value) {
		[tabBar setButtonMinWidth:tabBar.buttonOptimumWidth];
		[(NSControl*) sender setIntegerValue:tabBar.buttonOptimumWidth];
		return;
	}

	[tabBar setButtonMinWidth:value];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithInteger:value]
	 forKey:@"TabMinWidth"];
}

- (void)configTabMaxWidth:(id)sender {
	NSInteger const value = [(NSControl*) sender integerValue];
	if (tabBar.buttonOptimumWidth > value) {
		[tabBar setButtonMaxWidth:tabBar.buttonOptimumWidth];
		[(NSControl*) sender setIntegerValue:tabBar.buttonOptimumWidth];
		return;
	}

	[tabBar setButtonMaxWidth:value];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithInteger:value]
	 forKey:@"TabMaxWidth"];
}

- (void)configTabOptimumWidth:(id)sender {
	NSInteger const value = [(NSControl*) sender integerValue];
	if (tabBar.buttonMaxWidth < value) {
		[tabBar setButtonOptimumWidth:tabBar.buttonMaxWidth];
		[(NSControl*) sender setIntegerValue:tabBar.buttonMaxWidth];
		return;
	}

	if (tabBar.buttonMinWidth > value) {
		[tabBar setButtonOptimumWidth:tabBar.buttonMinWidth];
		[(NSControl*) sender setIntegerValue:tabBar.buttonMinWidth];
		return;
	}

	[tabBar setButtonOptimumWidth:value];
}

- (void)configTabSizeToFit:(id)sender {
	NSControlStateValue const state = [(NSButton*) sender state];

	[tabBar setSizeButtonsToFit:state];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:state]
	 forKey:@"SizeToFit"];
}

- (void)configTearOffStyle:(id)sender {
	NSPopUpButton* const popupButton = sender;
	[tabBar setTearOffStyle:(popupButton.indexOfSelectedItem == 0) ? MMTabBarTearOffAlphaWindow : MMTabBarTearOffMiniwindow];

	[NSUserDefaults.standardUserDefaults setObject:popupButton.title
	 forKey:@"Tear-Off"];
}

- (void)configUseOverflowMenu:(id)sender {
	NSControlStateValue const state = [(NSButton*) sender state];

	[tabBar setUseOverflowMenu:state];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:state]
	 forKey:@"UseOverflowMenu"];
}

- (void)configAutomaticallyAnimates:(id)sender {
	NSControlStateValue const state = [(NSButton*) sender state];

	[tabBar setAutomaticallyAnimates:state];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:state]
	 forKey:@"AutomaticallyAnimates"];
}

- (void)configAllowsScrubbing:(id)sender {
	NSControlStateValue const state = [(NSButton*) sender state];

	[tabBar setAllowsScrubbing:state];

	[NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:state]
	 forKey:@"AllowScrubbing"];
}

#pragma mark -
#pragma mark ---- delegate ----

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	// need to update bound values to match the selected tab
	DemoFakeModel* const tabBarItem = tabViewItem.identifier;
	if ([tabBarItem respondsToSelector:@selector(objectCount)]) {
		[objectCounterField setIntegerValue:tabBarItem.objectCount];
	}
    
	if ([tabBarItem respondsToSelector:@selector(objectCountColor)]) {
        if (tabBarItem.objectCountColor != nil)
            [objectCounterColorWell setColor:tabBarItem.objectCountColor];
        else
            [objectCounterColorWell setColor:MMTabBarButtonCell.defaultObjectCountColor];
	}    

	if ([tabBarItem respondsToSelector:@selector(isProcessing)]) {
		[isProcessingButton setState:tabBarItem.isProcessing];
	}

	if ([tabBarItem respondsToSelector:@selector(isEdited)]) {
		[isEditedButton setState:tabBarItem.isEdited];
	}

	if ([tabBarItem respondsToSelector:@selector(hasCloseButton)]) {
		[hasCloserButton setState:tabBarItem.hasCloseButton];
	}

	if ([tabBarItem respondsToSelector:@selector(showObjectCount)]) {
		[showObjectCountButton setState:tabBarItem.showObjectCount];
	}
    
	if ([tabBarItem respondsToSelector:@selector(largeImage)]) {
		[hasLargeImageButton setState:tabBarItem.largeImage != nil];
	}

	if ([tabBarItem respondsToSelector:@selector(iconName)]) {
		NSString *newName = tabBarItem.iconName;
		if (newName) {
			[iconButton selectItem:[iconButton.menu itemWithTitle:newName]];
		} else {
			[iconButton selectItem:[iconButton.menu itemWithTitle:@"None"]];
		}
	}
    
    if ([tabBarItem respondsToSelector:@selector(title)]) {
        [tabField setStringValue:tabBarItem.title];
    }
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem {
	NSWindow* const window = NSApp.keyWindow;
	if (window == nil) {
		return NO;
	}
	if ([tabViewItem.label isEqualToString:@"Drake"]) {
        NSAlert *drakeAlert = [[NSAlert alloc] init];
        [drakeAlert setMessageText:@"No Way!"];
        [drakeAlert setInformativeText:@"I refuse to close a tab named \"Drake\""];
        [drakeAlert addButtonWithTitle:@"OK"];
        [drakeAlert beginSheetModalForWindow:window completionHandler:nil];
		return NO;
	}
	return YES;
}

- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem {
	NSLog(@"didCloseTabViewItem: %@", tabViewItem.label);
}

- (void)tabView:(NSTabView *)aTabView didMoveTabViewItem:(NSTabViewItem *)tabViewItem toIndex:(NSUInteger)index
{
    NSLog(@"tab view did move tab view item %@ to index:%ld",tabViewItem.label,index);
}

- (void)addNewTabToTabView:(NSTabView *)aTabView {
    [self addNewTab:aTabView];
}

- (NSArray<NSPasteboardType> *)allowedDraggedTypesForTabView:(NSTabView *)aTabView {
	return @[NSFilenamesPboardType, NSStringPboardType];
}

- (BOOL)tabView:(NSTabView *)aTabView acceptedDraggingInfo:(id <NSDraggingInfo>)draggingInfo onTabViewItem:(NSTabViewItem *)tabViewItem {
	NSPasteboardType const pasteboardType = draggingInfo.draggingPasteboard.types[0];
	if (pasteboardType == nil) {
		return NO;
	}
	NSLog(@"acceptedDraggingInfo: %@ onTabViewItem: %@", [draggingInfo.draggingPasteboard stringForType:pasteboardType], tabViewItem.label);
    return YES;
}

- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem {
	NSLog(@"menuForTabViewItem: %@", tabViewItem.label);
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
	NSLog(@"didDropTabViewItem: %@ inTabBarView: %@", tabViewItem.label, tabBarView);
}

- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(NSUInteger *)styleMask {
	// grabs whole window image
	NSImage *viewImage = [[NSImage alloc] init];
	NSBitmapImageRep *viewRep;
	if (@available(macOS 10.14, *)) {
		NSView *contentView=self.window.contentView;
		NSRect rect=contentView.visibleRect;
		viewRep=[contentView bitmapImageRepForCachingDisplayInRect:rect];
		[contentView cacheDisplayInRect:rect toBitmapImageRep:viewRep];
	}
	else {
		NSRect contentFrame = self.window.contentView.frame;
		[self.window.contentView lockFocus];
		viewRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:contentFrame];
		[self.window.contentView unlockFocus];
	}
	[viewImage addRepresentation:viewRep];

	// grabs snapshot of dragged tabViewItem's view (represents content being dragged)
	NSView *viewForImage = tabViewItem.view;
	NSRect viewRect = viewForImage.frame;
	NSImage *tabViewImage = [[NSImage alloc] initWithSize:viewRect.size];
	[tabViewImage lockFocus];
	[viewForImage drawRect:viewForImage.bounds];
	[tabViewImage unlockFocus];

	[viewImage lockFocus];
	NSPoint tabOrigin = tabView.frame.origin;
	tabOrigin.x += 10;
	tabOrigin.y += 13;
    [tabViewImage drawAtPoint:tabOrigin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
//	[tabViewImage compositeToPoint:tabOrigin operation:NSCompositeSourceOver];
	[viewImage unlockFocus];

    MMTabBarView *tabBarView = (MMTabBarView *)aTabView.delegate;
    
	//draw over where the tab bar would usually be
	NSRect tabFrame = tabBar.frame;
	[viewImage lockFocus];
	[NSColor.windowBackgroundColor set];
	NSRectFill(tabFrame);
	//draw the background flipped, which is actually the right way up
	NSAffineTransform *transform = NSAffineTransform.transform;
	[transform scaleXBy:1.0 yBy:-1.0];
	[transform concat];
	tabFrame.origin.y = -tabFrame.origin.y - tabFrame.size.height;
	[tabBarView.style drawBezelOfTabBarView:tabBarView inRect:tabFrame];
	[transform invert];
	[transform concat];

	[viewImage unlockFocus];

	if (tabBarView.orientation == MMTabBarHorizontalOrientation) {
		offset->width = tabBarView.leftMargin;
		offset->height = 22;
	} else {
		offset->width = 0;
		offset->height = 22 + tabBarView.topMargin;
	}

	if (styleMask) {
		*styleMask = NSTitledWindowMask | NSTexturedBackgroundWindowMask;
	}

	return viewImage;
}

- (MMTabBarView *)tabView:(NSTabView *)aTabView newTabBarViewForDraggedTabViewItem:(NSTabViewItem *)tabViewItem atPoint:(NSPoint)point {
	NSLog(@"newTabBarViewForDraggedTabViewItem: %@ atPoint: %@", tabViewItem.label, NSStringFromPoint(point));

	//create a new window controller with no tab items
	DemoWindowController *controller = [[DemoWindowController alloc] initWithWindowNibName:@"DemoWindow"];
    
    MMTabBarView *tabBarView = (MMTabBarView *)aTabView.delegate;
    
	id <MMTabStyle> style = tabBarView.style;

	NSRect windowFrame = controller.window.frame;
	point.y += windowFrame.size.height - controller.window.contentView.frame.size.height;
	point.x -= [style leftMarginForTabBarView:tabBarView];

	[controller.window setFrameTopLeftPoint:point];
	[controller.tabBar setStyle:style];

	return controller.tabBar;
}

- (void)tabView:(NSTabView *)aTabView closeWindowForLastTabViewItem:(NSTabViewItem *)tabViewItem {
	NSLog(@"closeWindowForLastTabViewItem: %@", tabViewItem.label);
	[self.window close];
}

- (void)tabView:(NSTabView *)aTabView tabBarViewDidHide:(MMTabBarView *)tabBarView {
	NSLog(@"tabBarViewDidHide: %@", tabBarView);
}

- (void)tabView:(NSTabView *)aTabView tabBarViewDidUnhide:(MMTabBarView *)tabBarView {
	NSLog(@"tabBarViewDidUnhide: %@", tabBarView);
}

- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem {
	return tabViewItem.label;
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
		[item setMinSize:NSMakeSize(100, tabField.frame.size.height)];
		[item setMaxSize:NSMakeSize(500, tabField.frame.size.height)];
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

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
	return @[@"TabField", NSToolbarFlexibleSpaceItemIdentifier, @"DrawerItem"];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
	return @[@"TabField", NSToolbarFlexibleSpaceItemIdentifier, @"DrawerItem"];
}

- (IBAction)toggleToolbar:(id)sender {
	[self.window.toolbar setVisible:!self.window.toolbar.isVisible];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
	return YES;
}

- (void)configureTabBarInitially {
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	NSString* const style = [defaults stringForKey:@"Style"];
	[popUp_style selectItemWithTitle:style != nil ? style : @"Metal"];
	NSString* const orientation = [defaults stringForKey:@"Orientation"];
	[popUp_orientation selectItemWithTitle:orientation != nil ? orientation : @"Horizontal"];
	NSString* const tearOff = [defaults stringForKey:@"Tear-Off"];
	[popUp_tearOff selectItemWithTitle:tearOff != nil ? tearOff : @"Miniwindow"];

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
    [tabBar setOrientation:popUp_orientation.selectedTag];

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
