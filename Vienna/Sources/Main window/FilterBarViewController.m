//
//  FilterBarViewController.m
//  Vienna
//
//  Copyright 2025 Eitot
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

#import "FilterBarViewController.h"

static NSNibName const VNAFilterBarViewControllerNibName = @"FilterBarViewController";

@interface VNAFilterBarViewController ()

@property (weak, nonatomic) IBOutlet NSSearchField *searchField;
@property (weak, nonatomic) IBOutlet NSPopUpButton *popUpButton;

@end

@implementation VNAFilterBarViewController

// MARK: Initialization

+ (VNAFilterBarViewController *)instantiateFromNib
{
    return [[VNAFilterBarViewController alloc] initWithNibName:VNAFilterBarViewControllerNibName
                                                        bundle:NSBundle.mainBundle];
}

// MARK: Filter configuration

- (NSString *)filterString
{
    return self.searchField.stringValue;
}

- (void)setFilterString:(NSString *)filterString
{
    self.searchField.stringValue = filterString;
}

- (NSString *)placeholderFilterString
{
    return self.searchField.placeholderString;
}

- (void)setPlaceholderFilterString:(NSString *)placeholderFilterString
{
    self.searchField.placeholderString = placeholderFilterString;
}

- (VNAFilterMode)filterMode
{
    return self.popUpButton.selectedTag;
}

- (void)setFilterMode:(VNAFilterMode)selectedFilter
{
    [self.popUpButton selectItemWithTag:selectedFilter];
}

// MARK: Filter bar presentation

- (BOOL)isCompact
{
    return self.popUpButton.pullsDown;
}

- (void)setCompact:(BOOL)compact
{
    NSPopUpButton *popUpButton = self.popUpButton;
    popUpButton.pullsDown = compact;
    // NSPopUpButton unhides the first menu item when the pullsDown property is
    // changed to NO. The first menu item is merely for presentational purposes
    // and should stay hidden. Unfortunately, NSPopUpButton does not update its
    // presentation correctly, so the cell's menu item must be updated too.
    if (popUpButton.pullsDown == NO) {
        popUpButton.itemArray.firstObject.hidden = YES;
        NSPopUpButtonCell *popUpButtonCell = popUpButton.cell;
        popUpButtonCell.menuItem = popUpButton.selectedItem;
    }
}

- (BOOL)isVisible
{
    return self.filterBarContainer.isFindBarVisible;
}

- (void)setVisible:(BOOL)visible
{
    if (!visible) {
        NSSearchField *searchField = self.searchField;
        [searchField abortEditing];
        searchField.stringValue = @"";
    }
    self.filterBarContainer.findBarVisible = visible;
}

- (void)setFilterBarContainer:(id<NSTextFinderBarContainer>)filterBarContainer
{
    if ([_filterBarContainer isEqual:filterBarContainer]) {
        _filterBarContainer.findBarView = nil;
    }
    _filterBarContainer = filterBarContainer;
    filterBarContainer.findBarView = self.view;
}

// MARK: Event handling

- (NSView *)nextKeyView
{
    return self.searchField.nextKeyView;
}

- (void)setNextKeyView:(NSView *)nextKeyView
{
    self.searchField.nextKeyView = nextKeyView;
}

- (void)beginInteraction
{
    [self.view.window makeFirstResponder:self.searchField];
}

@end
