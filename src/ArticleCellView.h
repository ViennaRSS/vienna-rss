//
//  ArticleCellView.h
//
//  Adapted from PXListView by Alex Rozanski
//  Modified by Barijaona Ramaholimihaso
//

#import <Cocoa/Cocoa.h>

#import "ArticleView.h"


@interface ArticleCellView : NSTableCellView
{
	AppController * controller;
	BOOL inProgress;
	int folderId;
	NSUInteger articleRow;
	NSTableView *__weak _listView;
}

@property (readonly, strong)ArticleView *articleView;
@property (readonly, strong)NSProgressIndicator * progressIndicator;
@property BOOL inProgress;
@property int folderId;
@property NSUInteger articleRow;
@property (nonatomic, weak) NSTableView *listView;

@end
