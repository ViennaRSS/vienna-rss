//
//  ArticleCellView.h
//
//  Adapted from PXListView by Alex Rozanski
//  Modified by Barijaona Ramaholimihaso
//

@import Cocoa;
@import WebKit;

@class ArticleConverter;
@protocol ArticleContentView;

@interface ArticleCellView : NSTableCellView <WKNavigationDelegate>

@property (readonly) NSObject<ArticleContentView> *articleView;
@property (readonly) ArticleConverter * articleConverter;
@property (readonly)NSProgressIndicator * progressIndicator;
@property BOOL inProgress;
@property NSInteger folderId;
@property NSUInteger articleRow;
@property (nonatomic, weak) NSTableView *listView;
@property CGFloat fittingHeight;

@end
