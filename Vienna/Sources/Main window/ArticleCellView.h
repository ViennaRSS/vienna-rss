//
//  ArticleCellView.h
//
//  Adapted from PXListView by Alex Rozanski
//  Modified by Barijaona Ramaholimihaso
//

@import Cocoa;

@class AppController;
@protocol ArticleContentView;

@interface ArticleCellView : NSTableCellView
{
	AppController * controller;
	BOOL inProgress;
	NSInteger folderId;
	NSUInteger articleRow;
	NSTableView *__weak _listView;
}

@property (readonly, strong) NSObject<ArticleContentView> *articleView;
@property (readonly, strong) ArticleConverter * articleConverter;
@property (readonly, strong)NSProgressIndicator * progressIndicator;
@property BOOL inProgress;
@property NSInteger folderId;
@property NSUInteger articleRow;
@property (nonatomic, weak) NSTableView *listView;

@end
