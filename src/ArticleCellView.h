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
	ArticleView *articleView;
	NSProgressIndicator * progressIndicator;
	BOOL inProgress;
	int folderId;
	NSUInteger articleRow;
	NSTableView *_listView;
}

@property (assign,readonly)ArticleView *articleView;
@property BOOL inProgress;
@property int folderId;
@property NSUInteger articleRow;
@property (nonatomic, assign) NSTableView *listView;

@end
