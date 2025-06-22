//
//  FoldersFilterable.h
//  Vienna
//
//  Created by wolf on 1/10/16.
//  Copyright © 2016 uk.co.opencommunity. All rights reserved.
//

@import Cocoa;

@interface FoldersFilterableDataSource : NSObject <NSOutlineViewDataSource> {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-interface-ivars"
@protected
    __unsafe_unretained id <NSOutlineViewDataSource> _dataSource;
#pragma clang diagnostic pop
}

- (instancetype)initWithDataSource:(id<NSOutlineViewDataSource>)dataSource
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@interface FoldersFilterableDataSourceImpl : FoldersFilterableDataSource
- (void)setFilterPredicate:(NSPredicate*)predicate outlineView:(NSOutlineView*)outlineView;
- (void)reloadData:(NSOutlineView*)outlineView;
@end

@interface NSOutlineView (MCStateSave)

@property (setter=vna_setSelectionState:, nonatomic) NSSet *vna_selectionState;
@property (setter=vna_setExpansionState:, nonatomic) NSArray *vna_expansionState;
@property (setter=vna_setScrollState:, nonatomic) NSDictionary *vna_scrollState;
@property (setter=vna_setState:, nonatomic) NSDictionary *vna_state;

@end
