//
//  ArticleCellView.h
//
//  Adapted from PXListView by Alex Rozanski
//  Modified by Barijaona Ramaholimihaso
//

@import Cocoa;
@import WebKit;

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

@property (readonly) NSObject<ArticleContentView> *articleView;
@property (readonly) ArticleConverter * articleConverter;
@property (readonly)NSProgressIndicator * progressIndicator;
@property BOOL inProgress;
@property NSInteger folderId;
@property NSUInteger articleRow;
@property (nonatomic, weak) NSTableView *listView;
@property CGFloat fittingHeight;

@end
