//
//  ArticleCellView.h
//  PXListView
//
//  Adapted from PXListView by Alex Rozanski
//  Modified by Barijaona Ramaholimihaso
//

#import <Cocoa/Cocoa.h>

#import "PXListViewCell.h"
#import "ArticleView.h"


@interface ArticleCellView : PXListViewCell
{
	AppController * controller;
	ArticleView *articleView;
	NSProgressIndicator * progressIndicator;
	BOOL _inProgress;
	int folderId;
}

@property (nonatomic, retain) ArticleView *articleView;
@property BOOL inProgress;
@property int folderId;

// Public functions
-(id)initWithReusableIdentifier: (NSString*)identifier inFrame:(NSRect)frameRect;
@end
