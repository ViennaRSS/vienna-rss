//
//  SQLDatabase.h
//  An objective-c wrapper for the SQLite library
//  available at http://www.hwaci.com/sw/sqlite/
//
//  Created by Dustin Mierau on Tue Apr 02 2002.
//  Copyright (c) 2002 Blackhole Media, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "sqlite/sqlite3.h"

@class SQLResult;
@class SQLRow;

@interface SQLDatabase : NSObject 
{
	sqlite3 *	mDatabase;
	int			lastError;
	NSString *	mPath;
}

+ (id)databaseWithFile:(NSString*)inPath;
-(id)initWithFile:(NSString*)inPath;

-(int)lastError;

-(BOOL)open;
-(void)close;

+ (NSString*)prepareStringForQuery:(NSString*)inString;
-(SQLResult*)performQuery:(NSString*)inQuery;
-(SQLResult*)performQueryWithFormat:(NSString*)inFormat, ...;

-(int)lastInsertRowId;

@end

@interface SQLResult : NSObject
{
	char**	mTable;
	int		mRows;
	int		mColumns;
}

-(int)rowCount;
-(int)columnCount;

-(SQLRow*)rowAtIndex:(int)inIndex;
-(NSEnumerator*)rowEnumerator;

@end

@interface SQLRow : NSObject
{
	char**	mRowData;
	char**	mColumns;
	int		mColumnCount;
}

-(int)columnCount;

-(NSString*)stringForColumn:(NSString*)inColumnName;
-(NSString*)stringForColumnAtIndex:(int)inIndex;

@end