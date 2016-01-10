//
//  FoldersFilterable.h
//  Vienna
//
//  Created by wolf on 1/10/16.
//  Copyright © 2016 uk.co.opencommunity. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FoldersFilterableDataSource : NSObject <NSOutlineViewDataSource> {
@protected
__unsafe_unretained id <NSOutlineViewDataSource> _dataSource;
}

- (instancetype)initWithDataSource:(id<NSOutlineViewDataSource>)dataSource;

@end

@interface FoldersFilterableDataSourceImpl : FoldersFilterableDataSource
- (void)setFilterPredicate:(NSPredicate*)predicate outlineView:(NSOutlineView*)outlineView;
- (void)reloadData:(NSOutlineView*)outlineView;
@end

@interface NSOutlineView (MCStateSave)
@property (nonatomic) NSSet* selectionState;
@property (nonatomic) NSArray* expansionState;
@property (nonatomic) NSDictionary* scrollState;
@property (nonatomic) NSDictionary* state;
@end
