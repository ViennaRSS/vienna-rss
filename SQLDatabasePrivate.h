//
//  SQLDatabasePrivate.h
//  SQLite Test
//
//  Created by Dustin Mierau on Tue Apr 02 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQLDatabase.h"

@interface SQLDatabase (Private)
@end

@interface SQLResult (Private)
-(id)initWithTable:(char**)inTable rows:(int)inRows columns:(int)inColumns;
@end

@interface SQLRowEnumerator : NSEnumerator
{
	SQLResult*	mResult;
	int			mPosition;
	IMP			mRowAtIndexMethod;
	int			(*mRowCountMethod)(SQLResult*, SEL);
}

-(id)initWithResult:(SQLResult*)inResult;

@end

@interface SQLRow (Private)
-(id)initWithColumns:(char**)inColumns rowData:(char**)inRowData columns:(int)inColumnCount;
-(BOOL)valid;
@end