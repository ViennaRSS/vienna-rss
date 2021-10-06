//
//  ArticleCellView.h
//
//  Adapted from PXListView by Alex Rozanski
//  Modified by Barijaona Ramaholimihaso
//

@import Cocoa;

@class AppController;
@class ArticleConverter;
@protocol ArticleContentView;

@interface ArticleCellView : NSTableCellView <WKNavigationDelegate>
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
@property CGFloat fittingHeight;

@end
