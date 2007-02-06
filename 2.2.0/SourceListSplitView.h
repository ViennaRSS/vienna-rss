//
//  SourceListSplitView.h
//  Vienna
//
//  Created by Michael Stroeck on 06.02.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KFSplitView.h"

@interface SourceListSplitView : KFSplitView 
{
	id leftSubview;
	id rightSubview;
}

@end
